#!/usr/bin/env bash
#
# up.sh — Deploy FiveStep to YOUR AWS account, end to end, with one command:
#   bootstrap remote state -> Terraform (VPC/EKS/ECR) -> build & push image ->
#   deploy to Kubernetes -> port-forward to http://localhost:8080
#
# Prerequisites: aws cli, terraform, kubectl, docker (with buildx), and a
# configured AWS profile. Copy .env.example to .env and fill it in first.
#
# Usage:  ./scripts/up.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log() { printf "\n==> %s\n" "$1"; }

# ---- Load config ----
if [ ! -f "$ROOT/.env" ]; then
  echo "ERROR: no .env file. Run:  cp .env.example .env  and fill in your values."
  exit 1
fi
set -a; . "$ROOT/.env"; set +a
: "${AWS_PROFILE:?set AWS_PROFILE in .env}"
: "${AWS_REGION:?set AWS_REGION in .env}"
: "${TF_STATE_BUCKET:?set TF_STATE_BUCKET in .env}"
IMAGE_TAG="${IMAGE_TAG:-v1}"
export AWS_PROFILE AWS_REGION

# ---- Detect the caller's own account (portable — no hardcoded ID) ----
log "Checking AWS identity"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Deploying into AWS account: $ACCOUNT_ID  (region $AWS_REGION)"
ECR_REPO="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/fivestep"
export IMAGE_URI="${ECR_REPO}:${IMAGE_TAG}"
CLUSTER="fivestep-eks"

# ---- 1. Bootstrap remote state (S3 bucket + DynamoDB lock), idempotent ----
log "Bootstrapping Terraform remote state"
cd "$ROOT/terraform/bootstrap"
terraform init -input=false
terraform apply -auto-approve \
  -var "aws_profile=${AWS_PROFILE}" \
  -var "region=${AWS_REGION}" \
  -var "state_bucket=${TF_STATE_BUCKET}"

# ---- 2. Terraform: build the cluster + ECR (backend config passed in) ----
log "Terraform apply (VPC, EKS, ECR) — takes ~15 min"
cd "$ROOT/terraform"
terraform init -input=false -reconfigure \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="profile=${AWS_PROFILE}"
terraform apply -auto-approve \
  -var "aws_profile=${AWS_PROFILE}" \
  -var "region=${AWS_REGION}"

# ---- 3. Point kubectl at the new cluster ----
log "Configuring kubectl for $CLUSTER"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER"

# ---- 4. Build & push the app image (amd64 for the x86 nodes) ----
log "Logging Docker in to ECR"
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

log "Building & pushing ${IMAGE_URI} (linux/amd64)"
docker buildx build --platform linux/amd64 --provenance=false --sbom=false \
  -t "${IMAGE_URI}" --push "$ROOT"

# ---- 5. Deploy to Kubernetes (render the image into the manifest) ----
log "Deploying app to the cluster"
# Substitute the image URI without requiring envsubst (portable sed).
sed "s|\${IMAGE_URI}|${IMAGE_URI}|g" "$ROOT/k8s/deployment.yaml" | kubectl apply -f -
kubectl apply -f "$ROOT/k8s/service.yaml"

log "Waiting for pods to be ready"
kubectl rollout status deployment/fivestep --timeout=180s

# ---- 6. Show status + port-forward ----
kubectl get pods
cat <<'EOF'

FiveStep is UP. Port-forwarding to http://localhost:8080
(Press Ctrl-C to stop the forward; the app keeps running in the cluster.)
When finished for the day, run ./scripts/down.sh to stop AWS charges.
EOF
kubectl port-forward svc/fivestep 8080:80

#!/usr/bin/env bash
#
# down.sh — Tear down FiveStep to stop AWS charges.
# Destroys the EKS cluster, nodes, VPC, NAT, and ECR via Terraform.
# Leaves the remote-state backend (S3 + DynamoDB) in place for next time.
#
# Usage:  ./scripts/down.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log() { printf "\n==> %s\n" "$1"; }

if [ ! -f "$ROOT/.env" ]; then
  echo "ERROR: no .env file found."
  exit 1
fi
set -a; . "$ROOT/.env"; set +a
: "${AWS_PROFILE:?set AWS_PROFILE in .env}"
: "${AWS_REGION:?set AWS_REGION in .env}"
: "${TF_STATE_BUCKET:?set TF_STATE_BUCKET in .env}"
export AWS_PROFILE AWS_REGION

log "Terraform destroy (EKS, nodes, VPC, NAT, ECR) — takes ~10-15 min"
cd "$ROOT/terraform"
terraform init -input=false -reconfigure \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="profile=${AWS_PROFILE}"
terraform destroy -auto-approve \
  -var "aws_profile=${AWS_PROFILE}" \
  -var "region=${AWS_REGION}"

log "Done. Compute is destroyed; you are no longer billed for the cluster."
echo "Remote-state backend (S3 + DynamoDB) is preserved."
echo "To bring everything back: ./scripts/up.sh"

output "region" {
  value = var.region
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "ecr_repository_url" {
  description = "ECR image URI for Kubernetes deployments."
  value       = aws_ecr_repository.app.repository_url
}

output "configure_kubectl" {
  description = "Run this to point kubectl at the cluster."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name} --profile ${var.aws_profile}"
}

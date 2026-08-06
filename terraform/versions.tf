terraform {
  required_version = ">= 1.5.0"

  # Partial backend config: bucket/region/profile are supplied at init time
  # via -backend-config flags (see scripts/up.sh), so this repo isn't tied
  # to one person's AWS account.
  backend "s3" {
    key     = "eks/terraform.tfstate"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project   = "fivestep"
      ManagedBy = "terraform"
    }
  }
}

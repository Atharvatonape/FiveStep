terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "fivestep-tfstate-024001640841"
    key            = "eks/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "fivestep-tflock"
    encrypt        = true
    profile        = "fivestep-personal"
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
      Owner     = "fivestep-personal"
    }
  }
}

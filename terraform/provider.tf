terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment the backend block below after creating the S3 bucket
  # To use local state (for quick start), comment out or remove this backend block
  
  # COMMENTED OUT FOR QUICK START - Uncomment after creating S3 bucket
  backend "s3" {
    bucket         = "vk-terraform-state-733bf40e"
    key            = "ecs-fargate/terraform.tfstate"
    region         = "us-east-1"  # Must match where bucket is created
    encrypt        = true
    # dynamodb_table = "terraform-state-lock"  # Uncomment after creating DynamoDB table
  }
}

provider "aws" {
  region = var.aws_region
}

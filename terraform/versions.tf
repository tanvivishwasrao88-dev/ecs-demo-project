terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state - S3 + DynamoDB lock table
  # NOTE: create the bucket + table first (see backend-bootstrap.tf),
  # then uncomment this block and run `terraform init` again to migrate state.
  # backend "s3" {
  #   bucket         = "CHANGE-ME-your-unique-tf-state-bucket"
  #   key            = "ecs-demo/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region
}

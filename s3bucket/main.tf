# ------------------------------------------------------------------------------
# Author:      nekwebdev
# Company:     monkeylab  
# License:     GPLv3
# Description: creates an s3 bucket and dynamodb table to store terraform state
# ------------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  shared_credentials_files = ["./credentials"]
  profile = var.aws_profile
  region = var.aws_region
}

# s3 bucket configuration for terraform state storage
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.aws_state_bucket_name
  
  # prevent accidental deletion of this s3 bucket
  lifecycle {
    prevent_destroy = true
  }
  
  tags = merge(
    var.aws_common_tags,
    {
      Name = "Terraform State"
    }
  )
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# dynamodb table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.aws_dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
  
  tags = merge(
    var.aws_common_tags,
    {
      Name = "Terraform State Locks"
    }
  )
}

# output values
output "aws_region" {
  value       = aws_s3_bucket.terraform_state.region
  description = "The region of the AWS account"
}

output "aws_profile" {
  value       = var.aws_profile
  description = "The profile of the AWS account"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.terraform_state.id
  description = "The name of the S3 bucket"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.terraform_locks.id
  description = "The name of the DynamoDB table"
}

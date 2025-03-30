# ------------------------------------------------------------------------------
# Author:      nekwebdev
# Company:     monkeylab  
# License:     GPLv3
# Description: variables for terraform state storage infrastructure
# ------------------------------------------------------------------------------

# aws region
variable "aws_region" {
  description = "aws region to use"
  type        = string
  default     = "us-east-1"
}

# aws profile
variable "aws_profile" {
  description = "aws profile to use"
  type        = string
  default     = "default"
}

# s3 bucket name
variable "aws_state_bucket_name" {
  description = "name of the s3 bucket for storing terraform state"
  type        = string
  default     = "bucket-name"
}

# dynamodb table name
variable "aws_dynamodb_table_name" {
  description = "name of the dynamodb table for state locking"
  type        = string
  default     = "terraform-state-locks"
}

# tagging
variable "aws_common_tags" {
  description = "common tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Production"
    ManagedBy   = "Terraform"
    Project     = "Infrastructure"
  }
} 
# S3 Bucket Terraform Remote State Backend Setup

This Terraform configuration creates an S3 bucket and DynamoDB table for storing Terraform state files remotely. Using a remote state backend is a best practice for team environments and provides:

- Secure state storage with encryption
- State locking to prevent concurrent modifications
- State versioning for history and recovery

## Prerequisites

- AWS account
- AWS CLI installed (optional but recommended)
- Terraform installed (v0.13+)

## AWS Account Setup

Follow these steps to prepare your AWS account before running this Terraform code:

### 1. Create IAM Policy for Terraform

1. Log in to AWS Management Console with your root account
2. Go to IAM → Policies → Create policy
3. Switch to the JSON tab and paste the following policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:CreateBucket",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning",
        "s3:GetBucketPolicy",
        "s3:PutBucketPolicy",
        "s3:GetEncryptionConfiguration",
        "s3:PutEncryptionConfiguration",
        "s3:GetBucketPublicAccessBlock",
        "s3:PutBucketPublicAccessBlock",
        "s3:GetBucketTagging",
        "s3:PutBucketTagging",
        "s3:GetBucketACL",
        "s3:GetBucketCors",
        "s3:GetBucketWebsite",
        "s3:GetAccelerateConfiguration",
        "s3:GetBucketRequestPayment",
        "s3:GetBucketLogging",
        "s3:GetLifecycleConfiguration",
        "s3:GetReplicationConfiguration",
        "s3:GetBucketObjectLockConfiguration"        
      ],
      "Resource": [
        "arn:aws:s3:::*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:CreateTable",
        "dynamodb:DescribeTable",
        "dynamodb:DeleteTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:TagResource",
        "dynamodb:UntagResource",
        "dynamodb:ListTagsOfResource",
        "dynamodb:UpdateTable",
        "dynamodb:UpdateItem",
        "dynamodb:DescribeContinuousBackups",
        "dynamodb:DescribeTimeToLive"
      ],
      "Resource": [
        "arn:aws:dynamodb:*:*:table/*"
      ]
    }
  ]
}
```

4. Name it `TerraformStateBackendAccess` and click "Create policy"

### 2. Create IAM User for Terraform

1. Go to IAM → Users → Add users
2. Name the user `terraform-admin`
3. Select only "Access key - Programmatic access" (do NOT enable console access)
4. Click "Next: Permissions"
5. Under "Attach existing policies directly", search for and select the `TerraformStateBackendAccess` policy
6. Click through the remaining steps and create the user
7. Select the new user and select "Security Credentials"
8. Select "Access keys" and create a "Local code" access key
9. IMPORTANT: Download or copy the Access Key ID and Secret Access Key - these will only be shown once

### 3. Configure AWS

If using this terraform configuration with this project follow the instructions in the [root README.md file](../README.md).

If stand alone create a `credentials` file in the s3bucket directory with the following content:

```
[default]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
```

## Running Terraform

1. Initialize Terraform:

Navigate to the s3bucket directory:

```bash
cd ./s3bucket
```

Initialize Terraform with backend-config arguments or use environment variables:

```bash
terraform init
```

3. Review the planned changes:

```bash
terraform plan \
  -var "aws_profile=default" \
  -var "aws_region=us-east-1" \
  -var "aws_state_bucket_name=bucket-name" \
  -var "aws_dynamodb_table_name=terraform-state-locks" \
  -out=plan.tfplan
```

4. Apply the changes:

```bash
terraform apply plan.tfplan
```

5. Confirm by typing `yes` when prompted

## Using This S3 Bucket for Remote State Backend in Other Terraform Projects

After creating the S3 bucket and DynamoDB table, add the following to other Terraform configurations:

```tf
terraform {
  backend "s3" {
    bucket                   = "bucket-name"
    key                      = "path/to/your/terraform.tfstate"
    region                   = "us-east-1" # change to match your region
    use_lockfile             = true
    encrypt                  = true
    shared_credentials_files = ["backend/aws/credentials"] # or access_key/secret_key
  }
}
```

## Security Considerations

- Never commit AWS credentials to version control
- Rotate IAM user access keys periodically
- Consider using more restrictive IAM policies in production
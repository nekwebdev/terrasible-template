# ------------------------------------------------------------------------------
# author:      nekwebdev
# company:     monkeylab  
# license:     GPLv3
# description: Multiple backend options for state management:
#              - AWS S3 backend for remote state storage and locking
#              - Terraform Cloud (terraform.io) for team collaboration
#              - tfstate.dev for GitHub-based state management
# ------------------------------------------------------------------------------
terraform {
  # choose one backend solution and remove the others for clarity
  
  # option 1: aws s3 backend (currently active)
  backend "s3" {
    shared_credentials_files = ["backend/aws/credentials"]
    use_lockfile            = true
    encrypt                 = true
  }

  # option 2: terraform.io backend
  # backend "remote" {
  # }

  # option 3: tfstate.dev backend: https://tfstate.dev/
  # backend "http" {
  #   address        = "https://api.tfstate.dev/github/v1"
  #   lock_address   = "https://api.tfstate.dev/github/v1/lock"
  #   unlock_address = "https://api.tfstate.dev/github/v1/lock"
  #   lock_method    = "PUT"
  #   unlock_method  = "DELETE"
  # }
  
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 2"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
}

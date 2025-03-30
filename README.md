# MonkeyLab Infrastructure as Code WIP

This repository contains the Infrastructure as Code (IaC) for deploying a K3s Kubernetes cluster on Linode using Terraform and Ansible. The infrastructure provides an automated, secure, and scalable Kubernetes deployment with VPC networking, load balancing via NodeBalancer, and Cloudflare DNS integration.

## 📄 Project Documentation

- [S3 Bucket Remote State Backend Documentation](s3bucket/README.md) - Guide for setting up and using S3 buckets for Terraform remote state backend

## 🏗️ Terraform Infrastructure

The Terraform code in this repository deploys:

- Linode virtual machines running Alpine Linux
- VPC for secure private network communication
- Linode firewall
- Cloudflare DNS integration

### Prerequisites

Before deploying the infrastructure, ensure you have:

- Linode API token with read/write permissions
- Cloudflare API token with DNS edit permissions
- Cloudflare-managed domain and Zone ID
- SSH public keys for admin and services access

### Configuration

1. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in your configuration:

```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Edit the `terraform.tfvars` file with your specific values:
   - Linode API token
   - Cloudflare API token and Zone ID
   - Domain name
   - SSH public keys
   - Instance configurations

### Backend Configuration

This project supports three different backend options for storing Terraform state files. Configuration files for each backend are located in the `/backend` directory.

***Warining: Only S3 bucket is fully tested with the current setup and instructions here, other 2 works but readme will be lacking on these options.***

#### 1. AWS S3 Backend (Default)

The S3 backend stores state in an Amazon S3 bucket with locking provided by DynamoDB.

Make sure to follow the instructions in the [S3 Bucket Remote State Backend Documentation](s3bucket/README.md) to create the AWS account and user with the necessary permissions.

**Configuration Files:**
- `backend/aws/credentials`: AWS access credentials
- `backend/aws/bucket-config`: S3 bucket and DynamoDB configuration

**Setup Steps:**
1. Copy the example files:
   ```bash
   cp backend/aws/credentials.example backend/aws/credentials
   cp backend/aws/bucket-config.example backend/aws/bucket-config
   ```

2. Edit `backend/aws/credentials`:
   ```
   [default]
   aws_access_key_id = YOUR_AWS_ACCESS_KEY_ID
   aws_secret_access_key = YOUR_AWS_SECRET_ACCESS_KEY
   ```

3. Edit `backend/aws/bucket-config`:
   ```
   [default]
   region = us-west-1
   bucket = your-bucket-name
   dynamodb = terraform-state-locks
   key = monkeylab/terraform.tfstate
   environment = default
   project = myproject
   ```

   You can also define multiple profiles (staging, production) with different bucket configurations.

#### 2. Terraform Cloud Backend

[Terraform Cloud](https://app.terraform.io/) is a managed service that provides state storage, version control integration, and collaborative features.

**Configuration Files:**
- `backend/terraformio/config`: Terraform Cloud configuration

**Setup Steps:**
1. Copy the example file:
   ```bash
   cp backend/terraformio/config.example backend/terraformio/config
   ```

2. Edit `backend/terraformio/config`:
   ```
   TERRAFORM_HOST=app.terraform.io
   TERRAFORM_ORGANIZATION=your_organization
   TERRAFORM_WORKSPACE=your_workspace
   ```

3. Ensure you're authenticated with Terraform Cloud by running `terraform login` before using this backend.

#### 3. HTTP Backend (TFState.dev)

[TFState.dev](https://tfstate.dev/) provides a simple HTTP backend for storing Terraform state, suitable for individuals or small teams.

**Configuration Files:**
- `backend/tfstate/config`: HTTP backend configuration

**Setup Steps:**
1. Copy the example file:
   ```bash
   cp backend/tfstate/config.example backend/tfstate/config
   ```

2. Edit `backend/tfstate/config`:
   ```
   USERNAME=github_username/github_repo
   ```

3. This will use the TFState.dev service, which authenticates through GitHub.

### Remote State Setup

This project uses remote state management for team environments. Before deploying the main infrastructure:

1. Set up the S3 bucket remote state backend:

```bash
./create_s3_bucket.sh
```

This script creates an S3 bucket and DynamoDB table for Terraform remote state.

**Usage:**
```bash
./create_s3_bucket.sh [profile]
```

**Arguments:**
- `profile`: The configuration profile to use (default: "default")
  - Options: "default", "staging", "production" (as defined in backend/aws/bucket-config)

**Examples:**
```bash
# Create S3 bucket using default profile
./create_s3_bucket.sh

# Create S3 bucket using production profile
./create_s3_bucket.sh production
```

2. This will create an S3 bucket and DynamoDB table for state locking according to your configuration.

### Backend Initialization

Initialize the Terraform backend:

```bash
./init_backend.sh
```

This script will:
1. Configure the appropriate backend (S3, Terraform Cloud, or HTTP)
2. Initialize Terraform
3. Set up a containerized environment for both Terraform and Ansible operations

**Usage:**
```bash
./init_backend.sh [backend_type] [profile]
```

**Arguments:**
- `backend_type`: The backend to use (default: "s3")
  - Options: "s3", "terraform", "http"
- `profile`: The configuration profile to use (default: "default")
  - Options: "default", "staging", "production" (as defined in your backend config)

**Examples:**
```bash
# Use S3 backend with default profile
./init_backend.sh s3 default

# Use Terraform Cloud backend
./init_backend.sh terraform

# Use HTTP backend
./init_backend.sh http

# Use S3 backend with production profile
./init_backend.sh s3 production
```

## 🐳 Local Development Environment

This project uses Docker containers for local development to ensure consistent environments across team members.

### Docker Aliases

Load the provided aliases for easy access to Terraform and Ansible commands:

```bash
source aliases
```

Or add them to your shell configuration file (`~/.bashrc` or `~/.zshrc`).

The aliases provide:

- `terraform` - Runs Terraform commands in a containerized environment
- `ansible-playbook` - Runs Ansible playbooks in a containerized environment
- `ansible` - Runs Ansible commands in a containerized environment
- `ansible-lint` - Runs Ansible linting in a containerized environment

## 📜 Available Scripts

The repository includes several utility scripts:

- **`init_backend.sh`**: Initializes the Terraform backend and configures the containerized environment
- **`create_s3_bucket.sh`**: Creates an S3 bucket and DynamoDB table for Terraform remote state storage

### Using the Scripts

All scripts are executable. Run them as follows:

```bash
./init_backend.sh
./create_s3_bucket.sh
```

## 🛠️ Ansible Configuration

After deploying the infrastructure with Terraform, Ansible is used for configuration management:

1. The Terraform output generates an Ansible inventory file in `ansible/inventory/hosts.ini`
2. Run the Ansible playbook to configure the servers:

```bash
ansible-playbook ansible/site.yaml
```

## 🚀 Running the Project

Complete deployment workflow if using the S3 bucket remote state backend:

1. **Set up the remote state backend:**
   ```bash
   ./create_s3_bucket.sh
   ```

2. **Initialize Terraform:**
   ```bash
   ./init_backend.sh
   ```

3. **Apply the Terraform configuration:**
   ```bash
   terraform apply
   ```

4. **Configure the servers with Ansible:**
   ```bash
   cd ansible
   ansible-playbook site.yaml
   ```

## 📝 License

This project is licensed under the GPL v3 License - see the LICENSE file for details.

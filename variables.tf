# ------------------------------------------------------------------------------
# author:      nekwebdev
# company:     monkeylab  
# license:     GPLv3
# description: variables for terraform k3s cluster
# ------------------------------------------------------------------------------

# project information
variable "project_name" {
  description = "Name prefix used for all resources [OPTIONAL]"
  type        = string
  default     = "k3s-cluster"
}

variable "server_count" {
  description = "Number of servers to create for the cluster [OPTIONAL]"
  type        = number
  default     = 1
  
  validation {
    condition     = var.server_count > 0
    error_message = "Server count must be greater than 0."
  }
}

variable "linode_region" {
  description = "Linode region for deployment, see https://api.linode.com/v4/regions [OPTIONAL]"
  type        = string
  default     = "us-lax"
}

variable "server_type" {
  description = "Linode instance type, see https://www.linode.com/pricing/ [OPTIONAL]"
  type        = string
  default     = "g6-nanode-1"
}

variable "server_image" {
  description = "Linode image to use for the servers [OPTIONAL]"
  type        = string
  default     = "linode/debian12"
}

variable "domain_name" {
  description = "Domain name for the cluster [REQUIRED]"
  type        = string
  
  validation {
    condition     = length(var.domain_name) > 0
    error_message = "Domain name must be provided."
  }
}

variable "system_timezone" {
  description = "Timezone for cluster nodes [OPTIONAL]"
  type        = string
  default     = "America/Los_Angeles"
}

variable "vpc_subnet" {
  description = "VPC subnet prefix (x.x.x), will be used as x.x.x.0/24 [OPTIONAL]"
  type        = string
  default     = "10.10.10"
  
  validation {
    condition     = can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", var.vpc_subnet))
    error_message = "VPC subnet must be in the format of x.x.x (e.g., 10.10.10)."
  }
}

# api credentials - all required
variable "linode_token" {
  description = "Linode API token with read/write access [REQUIRED]"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.linode_token) > 0
    error_message = "Linode API token must be provided."
  }
}

variable "cloudflare_token" {
  description = "Cloudflare API token with DNS edit permissions [REQUIRED]"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.cloudflare_token) > 0
    error_message = "Cloudflare API token must be provided."
  }
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for the domain (found in domain overview) [REQUIRED]"
  type        = string
  
  validation {
    condition     = length(var.cloudflare_zone_id) > 0
    error_message = "Cloudflare Zone ID must be provided."
  }
}

# ssh access configuration
variable "root_password" {
  description = "Root password for Linode instances (REQUIRED if not using random passwords)"
  type        = string
  sensitive   = true
  default     = null
}

variable "admin_user" {
  description = "Username for Ansible management user [OPTIONAL]"
  type        = string
  default     = "ansible"
}

variable "ssh_admin_key" {
  description = "Admin SSH Public Key for admin login [REQUIRED]"
  type        = string
  
  validation {
    condition     = length(var.ssh_admin_key) > 0
    error_message = "Admin SSH Public Key must be provided."
  }
}

variable "ssh_services_key" {
  description = "SSH Public Key for Ansible user [REQUIRED]"
  type        = string
  
  validation {
    condition     = length(var.ssh_services_key) > 0
    error_message = "Ansible SSH Public Key must be provided."
  }
}

variable "ssh_port" {
  description = "SSH port for server access [OPTIONAL]"
  type        = number
  default     = 22
  
  validation {
    condition     = var.ssh_port > 0 && var.ssh_port < 65536
    error_message = "SSH port must be between 1 and 65535."
  }
}

variable "ansible_python_interpreter" {
  description = "Path to Python interpreter on target hosts [OPTIONAL]"
  type        = string
  default     = "/usr/bin/python3"
}

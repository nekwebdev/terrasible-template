# ------------------------------------------------------------------------------
# author:      nekwebdev
# company:     monkeylab  
# license:     GPLv3
# description: creates servers cluster on linode with vpc networking,
#              linode firewall, and cloudflare dns integration.
#              outputs ansible hosts file for configuration management.
# ------------------------------------------------------------------------------
provider "linode" {
  token = var.linode_token
}

provider "cloudflare" {
  api_token = var.cloudflare_token
}

resource "random_password" "passwords" {
  count   = var.server_count
  length  = 16
  special = true
}

# vpc for private network communication
resource "linode_vpc" "servers_vpc" {
  label       = var.project_name
  region      = var.linode_region
  description = "VPC for servers cluster"
}

# create a subnet within the vpc
resource "linode_vpc_subnet" "servers_subnet" {
  vpc_id = linode_vpc.servers_vpc.id
  label  = "${var.project_name}-subnet"
  ipv4   = "${var.vpc_subnet}.0/24"
}

# linode instances
resource "linode_instance" "servers_nodes" {
  count       = var.server_count
  region      = var.linode_region
  image       = "linode/alpine3.20"
  type        = var.server_type
  label       = "${var.project_name}-${count.index + 1}"
  tags        = ["terraform", "${var.project_name}"]
  # set a root password if you need to
  # root_pass   = var.root_password
  root_pass   = random_password.passwords[count.index].result
  private_ip  = true

  interface {
    purpose   = "vpc"
    # primary = true
    subnet_id = linode_vpc_subnet.servers_subnet.id
    ipv4 {
      vpc = "${var.vpc_subnet}.1${count.index}"
      nat_1_1 = "any"
    }
  }

  interface {
    purpose = "public"
  }

  metadata {
    user_data = base64encode(templatefile("cloud-init.tpl", {
      admin_user       = var.admin_user
      ssh_admin_key    = var.ssh_admin_key
      ssh_services_key = var.ssh_services_key
      ssh_port         = var.ssh_port
    }))
  }
}

# linode firewall
resource "linode_firewall" "servers_firewall" {
  label = "${var.project_name}_firewall"
  tags  = ["terraform", var.project_name]

  inbound {
    label    = "allow-api"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "6443,6444"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  inbound {
    label    = "allow-http"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "80"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  inbound {
    label    = "allow-https"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "443"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  inbound {
    label    = "allow-ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "${var.ssh_port}"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  inbound {
    label    = "allow-internal"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4     = ["${var.vpc_subnet}.0/24"]
  }

  inbound {
    label    = "allow-arp"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4     = ["${var.vpc_subnet}.0/24"]
  }
  
  inbound_policy = "DROP"
  outbound_policy = "ACCEPT"

  linodes = linode_instance.servers_nodes.*.id
}

# cloudflare dns records
resource "cloudflare_dns_record" "domain" {
  zone_id = var.cloudflare_zone_id
  comment = "terraform: domain to linode nodebalancer"
  content = linode_instance.servers_nodes[0].ip_address
  name    = "@"
  proxied = true
  ttl     = 1
  type    = "A"
}

resource "cloudflare_dns_record" "wildcard" {
  zone_id = var.cloudflare_zone_id
  comment = "terraform: subdomain wildcard to linode nodebalancer"
  content = linode_instance.servers_nodes[0].ip_address
  name    = "*"
  proxied = true
  ttl     = 1
  type    = "A"
}

# generate ansible inventory file
resource "local_file" "ansible_inventory_hosts" {
  content = templatefile("${path.module}/ansible/inventory/templates/hosts.yaml.tftpl", {
    servers                    = linode_instance.servers_nodes,
    admin_user                 = var.admin_user,
    ansible_port               = var.ssh_port,
    ansible_python_interpreter = var.ansible_python_interpreter,
    domain_name                = var.domain_name,
    system_timezone            = var.system_timezone,
  })
  filename = "${path.module}/ansible/inventory/hosts.yaml"
}

# generate credentials.json file with server information
resource "local_file" "credentials" {
  content = jsonencode({
    for idx, server in linode_instance.servers_nodes : server.label => {
      region      = server.region
      image       = server.image
      type        = server.type
      label       = server.label
      domain_name = var.domain_name
      public_ip   = server.ip_address
      ssh_port    = var.ssh_port
      admin_user  = var.admin_user
      private_ip  = server.private_ip_address
      vpc_ip      = server.interface[0].ipv4[0].vpc
      root_pwd    = random_password.passwords[idx].result
    }
  })
  filename = "${path.module}/credentials.json"
}

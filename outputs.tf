# ------------------------------------------------------------------------------
# author:      nekwebdev
# company:     monkeylab  
# license:     GPLv3
# description: outputs for the terraform resources
# ------------------------------------------------------------------------------

# infrastructure outputs
output "servers" {
  description = "details of the servers server nodes"
  value       = {
    for k, v in linode_instance.servers_nodes : v.id => {
      "label"      = v.label,
      "type"       = v.type,
      "region"     = v.region,
      "vcpus"      = v.specs.0.vcpus,
      "memory"     = v.specs.0.memory,
      "storage"    = v.specs.0.disk,
      "user"       = var.admin_user,
      "public_ip"  = v.ip_address,
      "private_ip" = v.private_ip,
      "vpc_ip"     = v.interface[0].ipv4[0].vpc,
      "ssh_port"   = var.ssh_port
    }
  }
}

output "vpc" {
  description = "details of the vpc network"
  value       = {
    "id"      = linode_vpc.servers_vpc.id,
    "label"   = linode_vpc.servers_vpc.label,
    "region"  = linode_vpc.servers_vpc.region,
    "subnet"  = {
      "id"    = linode_vpc_subnet.servers_subnet.id,
      "label" = linode_vpc_subnet.servers_subnet.label,
      "ipv4"  = linode_vpc_subnet.servers_subnet.ipv4
    }
  }
}

output "firewall" {
  description = "details of the servers firewall configuration"
  value       = {
    "id"              = linode_firewall.servers_firewall.id,
    "label"           = linode_firewall.servers_firewall.label,
    "tags"            = linode_firewall.servers_firewall.tags,
    "inbound_policy"  = linode_firewall.servers_firewall.inbound_policy,
    "outbound_policy" = linode_firewall.servers_firewall.outbound_policy,
    "linodes"         = linode_firewall.servers_firewall.linodes,
    "inbound_rules"   = [
      for rule in linode_firewall.servers_firewall.inbound : {
        "label"    = rule.label,
        "action"   = rule.action,
        "protocol" = rule.protocol,
        "ports"    = rule.ports,
        "ipv4"     = rule.ipv4,
        "ipv6"     = rule.ipv6
      }
    ]
  }
}

# dns outputs
output "cloudflare_dns" {
  description = "details of the dns configuration for the cluster"
  value       = {
    "domain" = {
      "id"      = cloudflare_dns_record.domain.id,
      "name"    = cloudflare_dns_record.domain.name,
      "type"    = cloudflare_dns_record.domain.type,
      "content" = cloudflare_dns_record.domain.content,
      "proxied" = cloudflare_dns_record.domain.proxied,
      "ttl"     = cloudflare_dns_record.domain.ttl
    },
    "wildcard" = {
      "id"      = cloudflare_dns_record.wildcard.id,
      "name"    = cloudflare_dns_record.wildcard.name,
      "type"    = cloudflare_dns_record.wildcard.type,
      "content" = cloudflare_dns_record.wildcard.content,
      "proxied" = cloudflare_dns_record.wildcard.proxied,
      "ttl"     = cloudflare_dns_record.wildcard.ttl
    }
  }
}

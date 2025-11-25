# Cloudflare Tunnel Module Outputs

output "tunnel_id" {
  description = "ID of the created Cloudflare Tunnel"
  value       = cloudflare_zero_trust_tunnel_cloudflared.this.id
}

output "tunnel_name" {
  description = "Name of the created Cloudflare Tunnel"
  value       = cloudflare_zero_trust_tunnel_cloudflared.this.name
}

output "tunnel_cname" {
  description = "CNAME target for the tunnel"
  value       = "${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com"
}

output "tunnel_token" {
  description = "Tunnel token for cloudflared to connect (sensitive)"
  value       = cloudflare_zero_trust_tunnel_cloudflared.this.tunnel_secret
  sensitive   = true
}

output "account_id" {
  description = "Cloudflare Account ID"
  value       = var.account_id
}

output "dns_records" {
  description = "Created DNS records"
  value = {
    for k, v in cloudflare_dns_record.tunnel_cname : k => {
      name    = v.name
      content = v.content
      type    = v.type
      proxied = v.proxied
      ttl     = v.ttl
    }
  }
}

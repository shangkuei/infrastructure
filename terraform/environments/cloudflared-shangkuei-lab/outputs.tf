# Cloudflared-shangkuei-lab Outputs

output "tunnel_id" {
  description = "ID of the created Cloudflare Tunnel"
  value       = module.shangkuei_lab_tunnel.tunnel_id
}

output "tunnel_name" {
  description = "Name of the created Cloudflare Tunnel"
  value       = module.shangkuei_lab_tunnel.tunnel_name
}

output "tunnel_token" {
  description = "Tunnel token for cloudflared connector (sensitive)"
  value       = module.shangkuei_lab_tunnel.tunnel_token
  sensitive   = true
}

output "dns_records" {
  description = "Created DNS records"
  value       = module.shangkuei_lab_tunnel.dns_records
}

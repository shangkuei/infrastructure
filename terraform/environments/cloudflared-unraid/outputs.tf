# Salary Mailman Environment Outputs

output "tunnel_id" {
  description = "Cloudflare Tunnel ID for salary-mailman"
  value       = module.edatw_tunnel.tunnel_id
}

output "tunnel_name" {
  description = "Cloudflare Tunnel name"
  value       = module.edatw_tunnel.tunnel_name
}

output "tunnel_cname" {
  description = "CNAME target for the tunnel"
  value       = module.edatw_tunnel.tunnel_cname
}

output "tunnel_token" {
  description = "Tunnel token for cloudflared (use in Kubernetes secret)"
  value       = module.edatw_tunnel.tunnel_token
  sensitive   = true
}

output "dns_records" {
  description = "Created DNS records"
  value       = module.edatw_tunnel.dns_records
}

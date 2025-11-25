# Cloudflare Tunnel Module
# Creates a Cloudflare Tunnel with optional DNS records and routes

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Generate a random secret for the tunnel
resource "random_password" "tunnel_secret" {
  length  = 64
  special = false
}

# Create the Cloudflare Tunnel
# In v5, we use config_src = "local" to manage configuration via Terraform
resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  account_id    = var.account_id
  name          = var.tunnel_name
  tunnel_secret = base64sha256(random_password.tunnel_secret.result)
  config_src    = "local"
}

# Create tunnel configuration
# Manages ingress rules locally via Terraform
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  count      = var.config_enabled ? 1 : 0
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id
  source     = "local"

  config = {
    ingress = concat(
      # User-defined ingress rules
      [
        for rule in var.ingress_rules : {
          hostname = rule.hostname
          service  = rule.service
          path     = try(rule.path, null)
          origin_request = try(rule.origin_request, null) != null ? {
            connect_timeout          = try(rule.origin_request.connect_timeout, null)
            tls_timeout              = try(rule.origin_request.tls_timeout, null)
            tcp_keep_alive           = try(rule.origin_request.tcp_keep_alive, null)
            no_happy_eyeballs        = try(rule.origin_request.no_happy_eyeballs, null)
            keep_alive_connections   = try(rule.origin_request.keep_alive_connections, null)
            keep_alive_timeout       = try(rule.origin_request.keep_alive_timeout, null)
            http_host_header         = try(rule.origin_request.http_host_header, null)
            origin_server_name       = try(rule.origin_request.origin_server_name, null)
            ca_pool                  = try(rule.origin_request.ca_pool, null)
            no_tls_verify            = try(rule.origin_request.no_tls_verify, null)
            disable_chunked_encoding = try(rule.origin_request.disable_chunked_encoding, null)
          } : null
        }
      ],
      # Default catch-all rule (required) - must be last
      [
        {
          service = var.default_service
        }
      ]
    )
  }
}

# Create DNS records for the tunnel (optional)
resource "cloudflare_dns_record" "tunnel_cname" {
  for_each = var.dns_records

  zone_id = var.zone_id
  name    = each.value.name
  content = "${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = try(each.value.proxied, true)
  ttl     = try(each.value.ttl, 1) # 1 = automatic
  comment = try(each.value.comment, "Managed by Terraform - Cloudflare Tunnel: ${var.tunnel_name}")
}

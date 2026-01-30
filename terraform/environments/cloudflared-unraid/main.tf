# Cloudflare Tunnel Infrastructure for Unraid Services
# Deploys Cloudflare Tunnel with direct service access (non-VPN mode)

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Deploy Unraid Cloudflare Tunnel
module "unraid_tunnel" {
  source = "../../modules/cloudflared"

  account_id  = var.cloudflare_account_id
  tunnel_name = "shangkuei-unraid"

  ingress_rules = [
    {
      hostname = "gitea.shangkuei.xyz"
      path     = "/-/admin/*"
      service  = "http_status:403"
      origin_request = {
        connect_timeout  = "30"
        http_host_header = "gitea.shangkuei.xyz"
      }
    },
    {
      hostname = "gitea.shangkuei.xyz"
      service  = "http://gitea:3000"
      origin_request = {
        connect_timeout  = "300"
        http_host_header = "gitea.shangkuei.xyz"
      }
    },
    {
      hostname = "vaultwarden.shangkuei.xyz"
      path     = "/admin/*"
      service  = "http_status:403"
      origin_request = {
        connect_timeout  = "30"
        http_host_header = "vaultwarden.shangkuei.xyz"
      }
    },
    {
      hostname = "vaultwarden.shangkuei.xyz"
      service  = "http://vaultwarden:80"
      origin_request = {
        connect_timeout  = "300"
        http_host_header = "vaultwarden.shangkuei.xyz"
      }
    },
    {
      hostname = "immich.shangkuei.xyz"
      path     = "/admin/*"
      service  = "http_status:403"
      origin_request = {
        connect_timeout  = "30"
        http_host_header = "immich.shangkuei.xyz"
      }
    },
    {
      hostname = "immich.shangkuei.xyz"
      service  = "http://immich-server:2283"
      origin_request = {
        connect_timeout  = "300"
        http_host_header = "immich.shangkuei.xyz"
      }
    },
    {
      hostname = "code.shangkuei.xyz"
      service  = "http://code-server:8443"
      origin_request = {
        connect_timeout  = "300"
        http_host_header = "code.shangkuei.xyz"
      }
    },
  ]

  zone_id = var.cloudflare_zone_id
  dns_records = {
    "gitea" = {
      name    = "gitea"
      proxied = true
      comment = "Unraid docker-compose hosted gitea (direct tunnel access)"
    }
    "vaultwarden" = {
      name    = "vaultwarden"
      proxied = true
      comment = "Unraid docker-compose hosted vaultwarden (direct tunnel access)"
    }
    "immich" = {
      name    = "immich"
      proxied = true
      comment = "Unraid docker-compose hosted immich (direct tunnel access)"
    }
    "code" = {
      name    = "code"
      proxied = true
      comment = "Unraid docker-compose hosted code-server (direct tunnel access)"
    }
  }
}

moved {
  from = module.edatw_tunnel
  to   = module.unraid_tunnel
}

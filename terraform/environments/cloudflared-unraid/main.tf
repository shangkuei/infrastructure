# Salary Mailman Application Infrastructure
# Deploys Cloudflare Tunnel and DNS for salary-mailman application

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

# Deploy salary-mailman Cloudflare Tunnel
module "edatw_tunnel" {
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
      service  = "https://gitea.vimba-char.ts.net"
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
      service  = "https://vaultwarden.vimba-char.ts.net"
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
      service  = "https://immich.vimba-char.ts.net"
      origin_request = {
        connect_timeout  = "300"
        http_host_header = "immich.shangkuei.xyz"
      }
    },
    {
      hostname = "code.shangkuei.xyz"
      service  = "https://code-server.vimba-char.ts.net"
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
      comment = "Unraid docker-compose hosted gitea through TailScale"
    }
    "vaultwarden" = {
      name    = "vaultwarden"
      proxied = true
      comment = "Unraid docker-compose hosted vaultwarden through TailScale"
    }
    "immich" = {
      name    = "immich"
      proxied = true
      comment = "Unraid docker-compose hosted immich through TailScale"
    }
    "code" = {
      name    = "code"
      proxied = true
      comment = "Unraid docker-compose hosted code-server through TailScale"
    }
  }
}

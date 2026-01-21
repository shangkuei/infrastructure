# Cloudflared Tunnel for shangkuei-lab Kubernetes cluster
# Exposes Grafana via Cloudflare Tunnel at grafana.shangkuei.xyz

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

# Deploy shangkuei-lab Cloudflare Tunnel
module "shangkuei_lab_tunnel" {
  source = "../../modules/cloudflared"

  account_id  = var.cloudflare_account_id
  tunnel_name = "shangkuei-lab"

  # Ingress rules managed via Terraform
  config_enabled = true

  ingress_rules = [
    {
      hostname = "grafana.shangkuei.xyz"
      service  = "http://grafana-cluster-service.monitoring.svc.cluster.local:3000"
      origin_request = {
        connect_timeout  = "30"
        http_host_header = "grafana.shangkuei.xyz"
      }
    },
  ]

  zone_id = var.cloudflare_zone_id
  dns_records = {
    "grafana" = {
      name    = "grafana"
      proxied = true
      comment = "shangkuei-lab Kubernetes Grafana via Cloudflare Tunnel"
    }
  }
}

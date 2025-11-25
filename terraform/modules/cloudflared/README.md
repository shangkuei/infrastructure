# Cloudflared Terraform Module

Creates and configures a Cloudflare Tunnel (Zero Trust) with ingress rules and optional DNS records.

## ⚠️ Version 5.0 Update

This module has been updated to use Cloudflare Terraform Provider v5. Key changes:

- Uses locally-managed tunnel configuration (`config_src = "local"` with `source = "local"`)
- Generates tunnel secret using `base64sha256` hash
- Resource names changed to `cloudflare_zero_trust_tunnel_cloudflared`
- Configuration syntax updated to object/list format
- DNS records use `cloudflare_dns_record` with `content` attribute

See [Migration from v4](#migration-from-v4) for upgrade instructions.

## Features

- Creates a Cloudflare Zero Trust Tunnel with Terraform-managed configuration
- Configures ingress rules to route hostnames to services
- Optionally creates DNS CNAME records pointing to the tunnel
- Outputs sensitive tunnel token for use with cloudflared

## Usage

### Basic Example

```hcl
module "tunnel" {
  source = "../../modules/cloudflared"

  account_id  = var.cloudflare_account_id
  tunnel_name = "tunnel"

  ingress_rules = [
    {
      hostname = "example.com"
      service  = "http://tunnel.example.svc.cluster.local:8080"
    }
  ]

  zone_id = var.cloudflare_zone_id
  dns_records = {
    "tunnel" = {
      name = "tunnel"
    }
  }
}

# Output the tunnel token for Kubernetes secret
output "tunnel_token" {
  value     = module.tunnel.tunnel_token
  sensitive = true
}
```

### Advanced Example with Origin Request Configuration

```hcl
module "app_tunnel" {
  source = "../../modules/cloudflared"

  account_id  = var.cloudflare_account_id
  tunnel_name = "my-app"

  ingress_rules = [
    {
      hostname = "app.example.com"
      service  = "http://app-service.default.svc.cluster.local:8080"
      origin_request = {
        connect_timeout    = "30s"
        tls_timeout        = "10s"
        tcp_keep_alive     = "30s"
        no_tls_verify      = false
        http_host_header   = "app.example.com"
      }
    }
  ]

  default_service = "http_status:404"

  zone_id = var.cloudflare_zone_id
  dns_records = {
    "app" = {
      name    = "app"
      proxied = true
      comment = "Application tunnel endpoint"
    }
  }
}
```

### Multiple Hostnames

```hcl
module "multi_app_tunnel" {
  source = "../../modules/cloudflared"

  account_id  = var.cloudflare_account_id
  tunnel_name = "multi-app"

  ingress_rules = [
    {
      hostname = "app1.example.com"
      service  = "http://app1.default.svc.cluster.local:8080"
    },
    {
      hostname = "app2.example.com"
      service  = "http://app2.default.svc.cluster.local:8080"
    },
    {
      hostname = "api.example.com"
      path     = "/v1"
      service  = "http://api.default.svc.cluster.local:3000"
    }
  ]

  zone_id = var.cloudflare_zone_id
  dns_records = {
    "app1" = { name = "app1" }
    "app2" = { name = "app2" }
    "api"  = { name = "api" }
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| account_id | Cloudflare Account ID | `string` | n/a | yes |
| tunnel_name | Name of the Cloudflare Tunnel | `string` | n/a | yes |
| config_enabled | Enable tunnel configuration (ingress rules) | `bool` | `true` | no |
| ingress_rules | List of ingress rules for the tunnel | `list(object)` | `[]` | no |
| default_service | Default service for catch-all ingress rule | `string` | `"http_status:404"` | no |
| zone_id | Cloudflare Zone ID for DNS records | `string` | `""` | no |
| dns_records | DNS records to create for the tunnel | `map(object)` | `{}` | no |

### Ingress Rule Object

```hcl
{
  hostname = string           # Hostname to route (e.g., "app.example.com")
  service  = string           # Target service (e.g., "http://service:8080")
  path     = optional(string) # Optional path prefix
  origin_request = optional(object({
    connect_timeout          = optional(string)
    tls_timeout              = optional(string)
    tcp_keep_alive           = optional(string)
    no_happy_eyeballs        = optional(bool)
    keep_alive_connections   = optional(number)
    keep_alive_timeout       = optional(string)
    http_host_header         = optional(string)
    origin_server_name       = optional(string)
    ca_pool                  = optional(string)
    no_tls_verify            = optional(bool)
    disable_chunked_encoding = optional(bool)
  }))
}
```

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| tunnel_id | ID of the created Cloudflare Tunnel | no |
| tunnel_name | Name of the created Cloudflare Tunnel | no |
| tunnel_cname | CNAME target for the tunnel | no |
| tunnel_token | Tunnel token for cloudflared to connect | yes |
| account_id | Cloudflare Account ID | no |
| dns_records | Created DNS records | no |

## Using the Tunnel Token

The `tunnel_token` output is sensitive and should be stored securely. Use it to configure cloudflared:

### In Kubernetes with SOPS

```bash
# Get the tunnel token from Terraform output
terraform output -raw tunnel_token

# Update your Kubernetes secret
# overlays/cluster/secret-cloudflared.yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloudflared-credentials
  namespace: app-namespace
type: Opaque
stringData:
  tunnel-token: <TUNNEL_TOKEN_FROM_TERRAFORM>

# Encrypt with SOPS
sops -e -i secret-cloudflared.yaml
```

### In Docker/Podman

```bash
docker run cloudflare/cloudflared:latest tunnel \
  --no-autoupdate run \
  --token $(terraform output -raw tunnel_token)
```

## Requirements

- Terraform >= 1.5.0
- Cloudflare Provider ~> 5.0
- Valid Cloudflare API token with permissions:
  - Account Settings: Read
  - Account Cloudflare Tunnel: Edit
  - Zone DNS: Edit (if using dns_records)

## Migration from v4

If you're upgrading from Cloudflare provider v4, you'll need to update your Terraform state:

### State Migration

```bash
# Update provider version in your configuration
# Then run terraform init to upgrade the provider
terraform init -upgrade

# Import existing tunnels to new resource type
terraform import 'module.tunnel.cloudflare_zero_trust_tunnel_cloudflared.this' <account-id>/<tunnel-id>
terraform import 'module.tunnel.cloudflare_zero_trust_tunnel_cloudflared_config.this[0]' <account-id>/<tunnel-id>

# Remove old resources from state
terraform state rm 'module.tunnel.cloudflare_tunnel.this'
terraform state rm 'module.tunnel.cloudflare_tunnel_config.this[0]'
terraform state rm 'module.tunnel.random_password.tunnel_secret'

# Verify the plan shows no changes
terraform plan
```

### Breaking Changes

1. **Resource Names**:
   - `cloudflare_tunnel` → `cloudflare_zero_trust_tunnel_cloudflared`
   - `cloudflare_tunnel_config` → `cloudflare_zero_trust_tunnel_cloudflared_config`
   - `cloudflare_record` → `cloudflare_dns_record`

2. **DNS Record Attributes**:
   - `value` attribute renamed to `content`

3. **Configuration Structure**: Config now uses object syntax instead of blocks:

   ```hcl
   # v4 syntax
   config {
     ingress_rule {
       hostname = "example.com"
       service  = "http://localhost:8080"
     }
   }

   # v5 syntax
   config = {
     ingress = [
       {
         hostname = "example.com"
         service  = "http://localhost:8080"
       }
     ]
   }
   ```

4. **Secret Management**: Tunnels now use `tunnel_secret` with `base64sha256` hash instead of `base64encode`. Configuration uses `config_src = "local"` and `source = "local"` to manage via Terraform.

## Notes

- Tunnels use locally-managed configuration (Terraform-managed)
- Tunnel secret is generated using `random_password` with `base64sha256` hash
- DNS records are created as CNAME pointing to `<tunnel-id>.cfargotunnel.com`
- The default service (`http_status:404`) is required as a catch-all
- Tunnel token is available via outputs for cloudflared authentication

## References

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [Cloudflare Terraform Provider v5 Upgrade Guide](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/guides/version-5-upgrade)
- [Deploy Tunnels with Terraform](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deploy-tunnels/deployment-guides/terraform/)
- [Cloudflare Zero Trust Tunnel (Cloudflared)](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_tunnel_cloudflared)
- [Cloudflare Zero Trust Tunnel Config](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_tunnel_cloudflared_config)
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 5.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | 5.13.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [cloudflare_dns_record.tunnel_cname](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |
| [cloudflare_zero_trust_tunnel_cloudflared.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_tunnel_cloudflared) | resource |
| [cloudflare_zero_trust_tunnel_cloudflared_config.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_tunnel_cloudflared_config) | resource |
| [random_password.tunnel_secret](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Cloudflare Account ID | `string` | n/a | yes |
| <a name="input_config_enabled"></a> [config\_enabled](#input\_config\_enabled) | Enable tunnel configuration (ingress rules). Set to false if managing config elsewhere. | `bool` | `true` | no |
| <a name="input_default_service"></a> [default\_service](#input\_default\_service) | Default service for catch-all ingress rule (required) | `string` | `"http_status:404"` | no |
| <a name="input_dns_records"></a> [dns\_records](#input\_dns\_records) | DNS records to create for the tunnel (CNAME to tunnel endpoint) | <pre>map(object({<br/>    name    = string<br/>    proxied = optional(bool, true)<br/>    ttl     = optional(number, 1)<br/>    comment = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_ingress_rules"></a> [ingress\_rules](#input\_ingress\_rules) | List of ingress rules for the tunnel. Each rule routes a hostname to a service. | <pre>list(object({<br/>    hostname = string<br/>    service  = string<br/>    path     = optional(string)<br/>    origin_request = optional(object({<br/>      connect_timeout          = optional(string)<br/>      tls_timeout              = optional(string)<br/>      tcp_keep_alive           = optional(string)<br/>      no_happy_eyeballs        = optional(bool)<br/>      keep_alive_connections   = optional(number)<br/>      keep_alive_timeout       = optional(string)<br/>      http_host_header         = optional(string)<br/>      origin_server_name       = optional(string)<br/>      ca_pool                  = optional(string)<br/>      no_tls_verify            = optional(bool)<br/>      disable_chunked_encoding = optional(bool)<br/>    }))<br/>  }))</pre> | `[]` | no |
| <a name="input_tunnel_name"></a> [tunnel\_name](#input\_tunnel\_name) | Name of the Cloudflare Tunnel | `string` | n/a | yes |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Cloudflare Zone ID for DNS records (optional, required if dns\_records is set) | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_account_id"></a> [account\_id](#output\_account\_id) | Cloudflare Account ID |
| <a name="output_dns_records"></a> [dns\_records](#output\_dns\_records) | Created DNS records |
| <a name="output_tunnel_cname"></a> [tunnel\_cname](#output\_tunnel\_cname) | CNAME target for the tunnel |
| <a name="output_tunnel_id"></a> [tunnel\_id](#output\_tunnel\_id) | ID of the created Cloudflare Tunnel |
| <a name="output_tunnel_name"></a> [tunnel\_name](#output\_tunnel\_name) | Name of the created Cloudflare Tunnel |
| <a name="output_tunnel_token"></a> [tunnel\_token](#output\_tunnel\_token) | Tunnel token for cloudflared to connect (sensitive) |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

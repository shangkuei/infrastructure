# cloudflared-shangkuei-lab

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 5.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_shangkuei_lab_tunnel"></a> [shangkuei\_lab\_tunnel](#module\_shangkuei\_lab\_tunnel) | ../../modules/cloudflared | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudflare_account_id"></a> [cloudflare\_account\_id](#input\_cloudflare\_account\_id) | Cloudflare Account ID | `string` | n/a | yes |
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | Cloudflare API token with Zone:Read and Tunnel:Edit permissions | `string` | n/a | yes |
| <a name="input_cloudflare_zone_id"></a> [cloudflare\_zone\_id](#input\_cloudflare\_zone\_id) | Cloudflare Zone ID for shangkuei.xyz | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dns_records"></a> [dns\_records](#output\_dns\_records) | Created DNS records |
| <a name="output_tunnel_id"></a> [tunnel\_id](#output\_tunnel\_id) | ID of the created Cloudflare Tunnel |
| <a name="output_tunnel_name"></a> [tunnel\_name](#output\_tunnel\_name) | Name of the created Cloudflare Tunnel |
| <a name="output_tunnel_token"></a> [tunnel\_token](#output\_tunnel\_token) | Tunnel token for cloudflared connector (sensitive) |
<!-- END_TF_DOCS -->

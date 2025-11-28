# Salary Mailman Environment Variables

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:Read and Tunnel:Edit permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for shangkuei.xyz"
  type        = string
}

# Variables for State Backend Environment

variable "cloudflare_api_token" {
  description = "Cloudflare API token for authentication (stored encrypted in tfvars.enc)"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID for R2 bucket"
  type        = string
  sensitive   = true
}

variable "bucket_name" {
  description = "Name of the R2 bucket for Terraform state storage"
  type        = string
  default     = "r2-terraform-state"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be 3-63 characters, lowercase letters, numbers, and hyphens only."
  }
}

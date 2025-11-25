# Cloudflare Tunnel Module Variables

variable "account_id" {
  description = "Cloudflare Account ID"
  type        = string
}

variable "tunnel_name" {
  description = "Name of the Cloudflare Tunnel"
  type        = string
}

variable "config_enabled" {
  description = "Enable tunnel configuration (ingress rules). Set to false if managing config elsewhere."
  type        = bool
  default     = true
}

variable "ingress_rules" {
  description = "List of ingress rules for the tunnel. Each rule routes a hostname to a service."
  type = list(object({
    hostname = string
    service  = string
    path     = optional(string)
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
  }))
  default = []
}

variable "default_service" {
  description = "Default service for catch-all ingress rule (required)"
  type        = string
  default     = "http_status:404"
}

variable "zone_id" {
  description = "Cloudflare Zone ID for DNS records (optional, required if dns_records is set)"
  type        = string
  default     = ""
}

variable "dns_records" {
  description = "DNS records to create for the tunnel (CNAME to tunnel endpoint)"
  type = map(object({
    name    = string
    proxied = optional(bool, true)
    ttl     = optional(number, 1)
    comment = optional(string)
  }))
  default = {}
}

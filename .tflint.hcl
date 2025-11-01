# TFLint configuration for Terraform validation
# https://github.com/terraform-linters/tflint

config {
  call_module_type = "all"
  force            = false
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = false
  version = "0.29.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# DigitalOcean plugin disabled - uncomment and update version if needed
# plugin "digitalocean" {
#   enabled = true
#   version = "0.36.0"
#   source  = "github.com/terraform-linters/tflint-ruleset-digitalocean"
# }

# Rules for best practices
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_deprecated_index" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_module_pinned_source" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_standard_module_structure" {
  enabled = true
}

rule "terraform_workspace_remote" {
  enabled = true
}

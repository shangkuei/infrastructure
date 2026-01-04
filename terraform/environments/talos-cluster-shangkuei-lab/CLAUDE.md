# CLAUDE.md - Talos Cluster Environment

This file provides guidance for AI assistants working in this Terraform environment.

## Important: Use Make Commands

This environment uses encrypted secrets with SOPS. **Always use Make commands instead of running terraform directly.**

### Common Workflows

| Task | Command | Notes |
|------|---------|-------|
| Generate configs | `make apply` | Decrypts secrets, runs terraform, encrypts outputs |
| Apply to nodes | `make talos-apply` | Apply configs to Talos nodes |
| Apply to single node | `make talos-apply NODE=worker-01` | Target specific node |
| Check cluster health | `make health` | Verify cluster status |
| List nodes | `make nodes` | Show Kubernetes nodes |
| View Talos dashboard | `make dashboard NODE=<ip>` | Open node dashboard |

### File Structure

- `terraform.enc.tfvars` - Encrypted variables (actual config)
- `terraform.tfvars` - Decrypted during make apply (temporary)
- `generated/` - Output configs (talosconfig, kubeconfig, node configs)

### Configuration Changes

1. Decrypt: `make sops-decrypt`
2. Edit: `terraform.tfvars`
3. Encrypt: `make sops-encrypt`
4. Apply: `make apply`

### Worker Node Configs

Worker node configurations are stored encrypted. The `worker_nodes` variable in `terraform.enc.tfvars` contains the actual node definitions.

### Never Run Directly

Avoid running these commands directly:

- `terraform plan` - Use `make plan`
- `terraform apply` - Use `make apply`

Direct terraform commands skip SOPS decryption and may use incomplete/empty configs.

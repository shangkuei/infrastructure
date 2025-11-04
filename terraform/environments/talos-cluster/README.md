# Talos Cluster Environment - Tailscale-Native Kubernetes

Terraform environment for generating Talos Linux Kubernetes cluster configurations with Tailscale mesh networking as the primary network.

## Overview

This environment generates machine configurations for a Talos Kubernetes cluster built entirely on Tailscale network:

- **Talos Linux**: Immutable, secure, minimal Linux distribution for Kubernetes
- **Tailscale Network**: Zero-config VPN mesh network (primary cluster network)
- **Terraform**: Configuration generation (not cluster deployment)
- **Manual Apply**: Generated scripts for applying configurations to nodes

### Key Features

- ✅ **Tailscale-Native**: Cluster built entirely on Tailscale mesh network (100.64.0.0/10)
- ✅ **Config Generation**: Terraform generates configurations, not deploys them
- ✅ **Makefile Automation**: Comprehensive Makefile for deployment, management, and operations
- ✅ **Heterogeneous Nodes**: Support for different machines with different hardware
- ✅ **KubePrism Load Balancer**: Built-in HA API load balancer over Tailscale (no external LB needed)
- ✅ **SOPS Integration**: Secure secret management with age encryption
- ✅ **High Availability**: Support for 1-node dev or 3+ node HA production setups
- ✅ **GitOps Ready**: Full configuration stored in version control

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  Tailscale Mesh Network                      │
│                    (100.64.0.0/10)                          │
│                  PRIMARY CLUSTER NETWORK                     │
└─────────────────────────────────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────▼────────┐   ┌───────▼────────┐   ┌──────▼──────┐
│ Control Plane  │   │ Worker Node 01 │   │   Laptop    │
│  (Talos VM)    │   │  (Talos VM)    │   │ (Developer) │
│                │   │                │   │             │
│ Tailscale:     │   │ Tailscale:     │   │ Tailscale:  │
│ 100.64.0.10 ◄──┼───┼─► 100.64.0.20  │   │ 100.64.1.50 │
│ (PRIMARY)      │   │  (PRIMARY)     │   │             │
│                │   │                │   │  kubectl    │
│ Physical:      │   │ Physical:      │   │  talosctl   │
│ 192.168.1.100  │   │ 192.168.1.110  │   │  access via │
│ (bootstrap)    │   │ (bootstrap)    │   │  Tailscale  │
│                │   │                │   │             │
│ KubePrism:7445 │   │ KubePrism:7445 │   │             │
│   ↓ (LB)       │   │   ↓ (LB)       │   │             │
│ K8s API :6443  │   │ Kubelet        │   │             │
└────────────────┘   └────────────────┘   └─────────────┘
        │                    │
        └────────────────────┘
          Pod CIDR: 10.244.0.0/16
       Service CIDR: 10.96.0.0/12
       ALL TRAFFIC VIA TAILSCALE

KubePrism: Local load balancer (127.0.0.1:7445)
  → Load balances to all control plane nodes via Tailscale IPs
  → Provides HA without external load balancer
```

### KubePrism Load Balancer

**KubePrism** is Talos's built-in local load balancer that provides high-availability API access:

- **Local Endpoint**: `https://127.0.0.1:7445` on every node
- **Backend Pool**: All control plane Tailscale IPs (e.g., 100.64.0.10, 100.64.0.11, 100.64.0.12)
- **Health Checks**: Automatic health checking and failover
- **No External LB**: No need for HAProxy, Nginx, or cloud load balancers
- **Works Everywhere**: Same configuration works on all nodes (workers and control planes)

**Benefits with Tailscale**:

1. **Simplified HA**: No external load balancer setup required
2. **Automatic Discovery**: KubePrism discovers all control plane nodes via Kubernetes discovery
3. **Resilient**: Survives control plane node failures automatically
4. **Consistent**: Same endpoint (`127.0.0.1:7445`) works on all nodes
5. **Secure**: All traffic encrypted via Tailscale mesh network
6. **Connect Anywhere**: Access cluster from any node's Tailscale IP - all route through KubePrism

**Certificate Management**:

- **Tailscale-Only SANs**: Certificates include only Tailscale IPs + MagicDNS + localhost
- **MagicDNS Support**: Optional Tailscale MagicDNS hostnames (e.g., `talos-cp-01.example-org.ts.net`)
- **Simplified Trust**: Single source of truth for node identity via Tailscale network
- **Easy Maintenance**: No need to track both physical and Tailscale IPs in certificates
- **Physical IPs**: Only used during initial bootstrap to apply first configuration

**How it Works**:

```
Application/Kubelet
        ↓
127.0.0.1:7445 (KubePrism local LB)
        ↓
    Round-robin to healthy control planes:
        - 100.64.0.10:6443 (CP-01)
        - 100.64.0.11:6443 (CP-02)
        - 100.64.0.12:6443 (CP-03)
        ↓
Kubernetes API Server
```

### Workflow

```
┌──────────────┐      ┌──────────────────┐      ┌─────────────────┐
│   Terraform  │─────▶│ Generate Configs │─────▶│    Makefile     │
│   Variables  │      │  Per Node        │      │  Commands       │
└──────────────┘      └──────────────────┘      │  make apply     │
                                                 │  make bootstrap │
                                                 └─────────────────┘
                                                          │
                                                          ▼
                                                 ┌─────────────────┐
                                                 │ Apply Configs & │
                                                 │ Bootstrap Nodes │
                                                 └─────────────────┘
```

## Prerequisites

### Required Tools

```bash
# Install Terraform
brew install terraform  # macOS
# or download from: https://www.terraform.io/downloads

# Install talosctl
brew install siderolabs/tap/talosctl  # macOS
# or: curl -sL https://talos.dev/install | sh

# Install kubectl
brew install kubectl  # macOS
# or: https://kubernetes.io/docs/tasks/tools/

# Install Tailscale
brew install tailscale  # macOS
# or: https://tailscale.com/download
```

### Infrastructure Requirements

- **Virtual Machines** (Unraid, Proxmox, VMware, etc.) or bare metal servers
- **Network Access**: VMs must be able to reach internet for Talos/Kubernetes downloads
- **Tailscale Account**: Free account at [tailscale.com](https://tailscale.com/)

### Node Requirements

| Component | Control Plane | Worker Node |
|-----------|--------------|-------------|
| vCPU      | 2 cores      | 4 cores     |
| Memory    | 4 GB         | 8 GB        |
| Disk      | 50 GB        | 100 GB      |
| Network   | 1 Gbps       | 1 Gbps      |

## Quick Start

### 1. Prepare Node Infrastructure

**For Unraid**:

1. Download Talos ISO: https://github.com/siderolabs/talos/releases
2. Create VMs with specifications above
3. Boot VMs from Talos ISO
4. Note the physical IP addresses (for initial bootstrapping)

**For Other Platforms**:

- Follow platform-specific VM creation steps
- Boot from Talos ISO
- Record VM IP addresses (temporary, for bootstrapping)

### 2. Setup Tailscale Network

```bash
# Join your device to Tailscale
sudo tailscale up --accept-routes

# Generate reusable auth key for cluster nodes
# Visit: https://login.tailscale.com/admin/settings/keys
# - Check "Reusable"
# - Add tags: tag:talos
# - Set expiry: 90 days
# - Copy the auth key (tskey-auth-...)
```

### 3. Configure Terraform

Terraform will automatically generate complete machine configurations including Tailscale extension setup:

```bash
# Clone repository
cd terraform/environments/talos-cluster

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit configuration
vim terraform.tfvars
```

**Example configuration**:

```hcl
# terraform.tfvars
cluster_name = "homelab-k8s"
environment  = "prod"

# Cluster endpoint auto-generated from first control plane
cluster_endpoint = ""  # Leave empty for auto-generation

# Control plane nodes (physical IPs for initial config application)
control_plane_nodes = {
  cp-01 = {
    tailscale_ip = "auto-assigned-after-boot"  # Will be assigned by Tailscale
    physical_ip  = "192.168.1.100"            # Physical network for initial config
    install_disk = "/dev/sda"
    hostname     = "talos-cp-01"
    interface    = "eth0"  # Physical interface (use DHCP)
  }
}

# Worker nodes
worker_nodes = {
  worker-01 = {
    tailscale_ip = "auto-assigned-after-boot"
    physical_ip  = "192.168.1.110"
    install_disk = "/dev/sda"
    hostname     = "talos-worker-01"
    interface    = "eth0"
  }
}

# Tailscale configuration
tailscale_auth_key          = "tskey-auth-xxxxxxxxxxxxx"  # From Tailscale admin
tailscale_accept_routes     = true      # Accept routes from other nodes
```

### 4. Generate Configurations

Terraform automatically generates complete machine configurations with:

- **Base machine config**: Talos system configuration with Tailscale extension
- **Node-specific patches**: Hostname, disk, network interface
- **Tailscale extension config**: Auto-join Tailscale on boot

```bash
# Initialize and generate configs
make init
make apply

# Review generated files in generated/ directory:
# - control-plane-<name>.yaml (base config with Tailscale extension)
# - control-plane-<name>-patch.yaml (node-specific settings)
# - control-plane-<name>-tailscale.yaml (Tailscale extension environment)
# - apply-configs.sh (deployment script)
# - bootstrap-cluster.sh (cluster bootstrap script)
# - talosconfig (cluster management credentials)
```

### 5. Apply Configurations to Nodes

Apply the generated configurations to your VMs using physical IPs. The configurations include Tailscale extension that will auto-join the tailnet on first boot:

```bash
# Apply configs to all nodes (automated)
make apply-configs

# Nodes will:
# 1. Apply the machine configuration
# 2. Install Talos with Tailscale system extension
# 3. Boot and automatically join your Tailscale network
# 4. Become accessible via Tailscale IPs (100.64.x.x)
```

**Wait for Tailscale Registration** (1-2 minutes):

```bash
# Check Tailscale admin console or from your machine:
tailscale status

# You should see your nodes appear:
# 100.64.0.10  talos-cp-01      tagged-devices
# 100.64.0.20  talos-worker-01  tagged-devices
```

### 6. Update Terraform with Tailscale IPs

Once nodes have joined Tailscale and received their IPs, update your configuration:

```bash
# Edit terraform.tfvars with actual Tailscale IPs
vim terraform.tfvars

# Update tailscale_ip values with real IPs from `tailscale status`:
control_plane_nodes = {
  cp-01 = {
    tailscale_ip = "100.64.0.10"  # Real Tailscale IP from network
    physical_ip  = "192.168.1.100"
    install_disk = "/dev/sda"
    hostname     = "talos-cp-01"
    interface    = "eth0"
  }
}

# Regenerate configurations with real Tailscale IPs
make apply

# Re-apply configs (now using Tailscale IPs)
make apply-configs
```

### 7. Bootstrap Kubernetes Cluster

```bash
# Bootstrap the cluster (initializes etcd and control plane)
make bootstrap

# Check cluster health
make health
make nodes
make pods
```

### 8. Access Cluster

```bash
# Get environment variable exports
make env

# Then export the credentials:
export TALOSCONFIG=$(pwd)/generated/talosconfig
export KUBECONFIG=$(pwd)/generated/kubeconfig

# Verify cluster
make nodes             # List nodes
make pods              # List all pods
make status            # Complete cluster status
```

## SOPS Secret Management

This environment uses SOPS (Secrets OPerationS) with age encryption to protect sensitive data in version control.

### Why SOPS?

- **GitOps-friendly**: Encrypted secrets can be safely committed to Git
- **Selective encryption**: Only values are encrypted, keys remain readable
- **Easy collaboration**: Team members decrypt with their age keys
- **Zero cost**: Free and open source

### Quick Start with SOPS

#### 1. Generate Age Encryption Key

```bash
# Generate age key for this environment
make age-keygen

# This creates:
# - ~/.config/sops/age/talos-cluster-key.txt (private key - keep secure!)
# - ~/.config/sops/age/talos-cluster-key.txt.pub (public key - for encryption)
```

**Important**: Backup the private key in your password manager!

#### 2. Update .sops.yaml with Public Key

```bash
# Get your public key
cat ~/.config/sops/age/talos-cluster-key.txt.pub

# Replace placeholder in .sops.yaml
sed -i '' "s/age1TALOS_KEY_PLACEHOLDER_REPLACE_WITH_TALOS_AGE_PUBLIC_KEY_XXXXXXXXXXXXXXX/$(cat ~/.config/sops/age/talos-cluster-key.txt.pub)/g" .sops.yaml

# Verify replacement
grep "age1" .sops.yaml
```

#### 3. Store Private Key in GitHub Secrets

```bash
# For CI/CD access, store private key in GitHub Secrets
gh secret set SOPS_AGE_KEY_TALOS_CLUSTER < ~/.config/sops/age/talos-cluster-key.txt

# Verify
gh secret list | grep SOPS_AGE_KEY_TALOS_CLUSTER
```

#### 4. Encrypt terraform.tfvars

```bash
# Copy example and fill in secrets
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Add your actual credentials

# Encrypt the file
make encrypt-tfvars

# Remove plaintext version
rm terraform.tfvars

# The encrypted terraform.tfvars.enc is now safe to commit
git add terraform.tfvars.enc
```

#### 5. Setup Backend with R2 (Optional)

If using Cloudflare R2 for Terraform state storage:

```bash
# Copy example backend config
cp backend.hcl.example backend.hcl

# Fill in your R2 credentials
vim backend.hcl
# - Replace account ID in endpoint URL
# - Add R2 access_key and secret_key

# Encrypt backend config
make encrypt-backend

# Remove plaintext version
rm backend.hcl

# Initialize with encrypted backend
make init
```

### Daily Workflow with SOPS

```bash
# Edit encrypted terraform.tfvars (SOPS handles decryption/encryption)
sops terraform.tfvars.enc

# Edit encrypted backend config
sops backend.hcl.enc

# Run terraform commands (Makefile handles decryption automatically)
make plan
make apply
```

### File Structure

**Committed to Git (safe)**:

- `.sops.yaml` - SOPS configuration with age public key
- `terraform.tfvars.enc` - Encrypted variables
- `terraform.tfvars.example` - Template with placeholders
- `backend.hcl.enc` - Encrypted backend config (optional)
- `backend.hcl.example` - Backend template

**Gitignored (never commit)**:

- `terraform.tfvars` - Plaintext variables (temporary)
- `backend.hcl` - Plaintext backend config (temporary)
- `~/.config/sops/age/talos-cluster-key.txt` - Private age key

### Security Best Practices

✅ **Do**:

- Store private key in password manager
- Backup private key in secure location
- Use `make encrypt-tfvars` and `make encrypt-backend` commands
- Commit only encrypted `.enc` files
- Store private key in GitHub Secrets for CI/CD

❌ **Don't**:

- Never commit plaintext `terraform.tfvars` or `backend.hcl`
- Never commit private age key
- Never share private key via email or chat
- Never skip encryption step

### Troubleshooting

**Cannot decrypt files**:

```bash
# Verify age key exists
ls -la ~/.config/sops/age/talos-cluster-key.txt

# Check public key matches .sops.yaml
age-keygen -y ~/.config/sops/age/talos-cluster-key.txt
grep "age1" .sops.yaml
```

**SOPS not found**:

```bash
# Install SOPS
brew install sops  # macOS
# Or see: https://github.com/mozilla/sops/releases
```

**Age not found**:

```bash
# Install age
brew install age  # macOS
# Or see: https://age-encryption.org/
```

### Related Documentation

- [ADR-0008: Secret Management Strategy](../../../docs/decisions/0008-secret-management.md)
- [Runbook: SOPS Secret Management](../../../docs/runbooks/0008-sops-secret-management.md)
- [SOPS Documentation](https://github.com/getsops/sops)
- [age Encryption](https://age-encryption.org/)

## Deployment Workflow Summary

The complete deployment process:

```
1. Prepare VMs        → Boot VMs from Talos ISO
2. Configure Terraform → Set node details, Tailscale auth key
3. Generate Configs   → make apply (includes Tailscale extension)
4. Apply to Nodes     → make apply-configs INSECURE=true (initial setup with physical IPs)
5. Wait for Tailscale → Nodes auto-join tailnet (~1-2 min)
6. Update Tailscale IPs → Edit terraform.tfvars with real IPs
7. Regenerate Configs → make apply (with real Tailscale IPs)
8. Reapply Configs    → make apply-configs (secure mode via Tailscale)
9. Bootstrap Cluster  → make bootstrap
10. Get Kubeconfig    → talosctl kubeconfig --nodes <node-ip> --force
11. Verify            → make health, make nodes, make pods
```

**Key Points**:

- **Tailscale Extension**: Automatically included in generated configs
- **Two-Phase Application**: First with physical IPs (insecure mode), then with Tailscale IPs (secure mode)
- **Security**: Use `INSECURE=true` only for initial node setup before certificates are established
- **Auto-Join**: Nodes join Tailscale network automatically on boot
- **No Manual Bootstrap**: The old bootstrap-config.yaml workflow is replaced by Terraform generation
- **Kubeconfig Retrieval**: Must be retrieved AFTER cluster bootstrap (requires running Kubernetes API)

## Makefile Commands

The environment includes a comprehensive Makefile for common operations:

```bash
# Show all available commands
make help

# Terraform operations
make init              # Initialize Terraform
make plan              # Show execution plan
make apply             # Generate configurations
make validate          # Validate configuration
make format            # Format Terraform files

# Deployment
make apply-configs     # Apply configs to nodes
make bootstrap         # Bootstrap cluster

# Cluster status
make health            # Check cluster health
make nodes             # List nodes
make pods              # List pods
make status            # Complete status

# Maintenance
make upgrade-k8s VERSION=v1.34.1            # Upgrade Kubernetes
make upgrade-talos VERSION=v1.11.3 NODE=...  # Upgrade Talos
make dashboard NODE=100.64.0.10             # Open dashboard
make logs NODE=100.64.0.10 SERVICE=kubelet  # View logs

# Cleanup
make clean             # Remove generated files
make destroy           # Destroy configurations
```

## Configuration Options

### Cluster Sizing

**Single-Node Development**:

```hcl
control_plane_nodes = {
  cp-01 = {
    tailscale_ip = "100.64.0.10"
    install_disk = "/dev/sda"
  }
}
worker_nodes = {}  # Control plane can run workloads
```

**Production HA (3+ control planes)**:

```hcl
control_plane_nodes = {
  cp-01 = {
    tailscale_ip = "100.64.0.10"
    physical_ip  = "192.168.1.100"  # Optional
    install_disk = "/dev/sda"
  }
  cp-02 = {
    tailscale_ip = "100.64.0.11"
    physical_ip  = "192.168.1.101"
    install_disk = "/dev/sda"
  }
  cp-03 = {
    tailscale_ip = "100.64.0.12"
    physical_ip  = "192.168.1.102"
    install_disk = "/dev/sda"
  }
}
worker_nodes = {
  worker-01 = {
    tailscale_ip = "100.64.0.20"
    install_disk = "/dev/sda"
  }
  worker-02 = {
    tailscale_ip = "100.64.0.21"
    install_disk = "/dev/sda"
  }
}
```

### CNI Selection

```hcl
cni_name = "cilium"   # Default: Advanced features, network policies, observability
# cni_name = "flannel"  # Simple overlay network
# cni_name = "calico"   # Network policies, BGP routing
# cni_name = "none"     # Install custom CNI
```

**Cilium CNI Deployment**:

When using Cilium as the CNI, the Talos machine configuration automatically:

- Sets CNI to "none" (Cilium installed via Helm)
- Disables kube-proxy (Cilium handles this with `kubeProxyReplacement`)

Customize the deployment using the `cilium_helm_values` variable:

```hcl
cilium_helm_values = {
  # Enable Hubble for network observability
  hubble = {
    enabled = true
    relay = {
      enabled = true
    }
    ui = {
      enabled = true
    }
  }
  # Enable IPv6 support
  ipv6 = {
    enabled = true
  }
  # Custom Kubernetes API endpoint
  k8sServiceHost = "localhost"
  k8sServicePort = 6443
  # kube-proxy replacement (required - already enabled by default)
  kubeProxyReplacement = "true"
}
```

Deploy Cilium after cluster bootstrap:

```bash
# Generate Cilium values file
make apply

# Deploy Cilium using Helm
make deploy-cilium

# Verify Cilium deployment
kubectl -n kube-system get pods -l k8s-app=cilium
kubectl -n kube-system exec -it ds/cilium -- cilium status
```

For full list of Cilium Helm values, see: https://github.com/cilium/cilium/blob/main/install/kubernetes/cilium/values.yaml

### Kubernetes Versions

```hcl
talos_version      = "v1.11.3"  # Latest stable Talos (Nov 2025)
kubernetes_version = "v1.34.1"  # Latest stable Kubernetes (default with Talos 1.11.3)
```

## Operations

### Accessing the Cluster

**Via kubectl** (from any Tailscale device):

```bash
export KUBECONFIG=/path/to/generated/kubeconfig
kubectl get nodes
```

**Via talosctl** (cluster management):

```bash
export TALOSCONFIG=/path/to/generated/talosconfig
talosctl health
talosctl dashboard
```

### Cluster Health

```bash
# Check Talos health
talosctl health --wait-timeout=10m

# Check Kubernetes health
kubectl get nodes
kubectl get pods -A
kubectl top nodes
```

### Updating Kubernetes

```bash
# Update Kubernetes version in terraform.tfvars
kubernetes_version = "v1.34.1"

# Regenerate configurations
terraform apply

# Apply updated configs to nodes
./generated/apply-configs.sh

# Or use talosctl to upgrade directly
talosctl upgrade-k8s --to v1.34.1
```

### Updating Talos

```bash
# Update Talos version in terraform.tfvars
talos_version = "v1.11.3"

# Regenerate configurations
terraform apply

# Apply updated configs or upgrade directly
talosctl upgrade --nodes <node-tailscale-ip> \
  --image ghcr.io/siderolabs/installer:v1.11.3
```

### Adding Worker Nodes

```bash
# 1. Create new VM and boot from Talos ISO
# 2. Join node to Tailscale and get its Tailscale IP

# 3. Add worker node to terraform.tfvars
worker_nodes = {
  # ... existing workers ...
  worker-03 = {
    tailscale_ip = "100.64.0.22"
    physical_ip  = "192.168.1.112"  # Optional
    install_disk = "/dev/sda"
  }
}

# 4. Regenerate configurations
terraform apply

# 5. Apply new node configuration
talosctl apply-config --insecure \
  --nodes 100.64.0.22 \
  --file generated/worker-worker-03.yaml \
  --config-patch @generated/worker-worker-03-patch.yaml

# 6. Verify new node joined
kubectl get nodes
```

### Scaling Down

```bash
# 1. Drain node first
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
kubectl delete node <node-name>

# 2. Remove node from terraform.tfvars
# 3. Regenerate configurations
terraform apply

# Note: Node configurations are removed but VMs are not destroyed
# Manually power off/delete VMs if needed
```

## Troubleshooting

### Cluster Not Bootstrapping

```bash
# Check Talos service status (use Tailscale IP)
talosctl -n 100.64.0.10 services

# View kubelet logs
talosctl -n 100.64.0.10 logs kubelet

# View etcd logs (control plane)
talosctl -n 100.64.0.10 logs etcd

# Check if nodes can reach each other via Tailscale
talosctl -n 100.64.0.10 get members
```

### Nodes Not on Tailscale Network

If nodes don't have Tailscale IPs yet:

```bash
# Option 1: Use physical IP temporarily to check status
talosctl -n 192.168.1.100 version

# Option 2: Check Tailscale status from your machine
tailscale status
# Look for node hostnames in the list

# If nodes aren't showing up, they may need Tailscale configured
# Ensure tailscale_auth_key is correct in terraform.tfvars
```

### API Server Not Accessible

```bash
# Check control plane is running (use Tailscale IP)
talosctl -n 100.64.0.10 get members

# Verify cert SANs include Tailscale IP
talosctl -n 100.64.0.10 get certificates

# Test connectivity via Tailscale IP
curl -k https://100.64.0.10:6443/healthz

# Verify kubeconfig has correct endpoint
grep server: generated/kubeconfig
```

### Configuration Not Applied

```bash
# Check if config files were generated
ls -la generated/

# Verify talosconfig is correct
export TALOSCONFIG=$(pwd)/generated/talosconfig
talosctl version

# Try applying config again with verbose output
talosctl apply-config --insecure \
  --nodes 100.64.0.10 \
  --file generated/control-plane-cp-01.yaml \
  --config-patch @generated/control-plane-cp-01-patch.yaml \
  --debug
```

### Pod Network Issues

```bash
# Check CNI pods are running
kubectl -n kube-system get pods -l k8s-app=<cni-name>

# View CNI logs
kubectl -n kube-system logs -l k8s-app=<cni-name>

# Test pod-to-pod connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- ping <pod-ip>
```

## Cleanup

### Remove Generated Configurations

```bash
# Terraform only generates configs, it doesn't manage cluster lifecycle
# To clean up generated files:
terraform destroy

# This removes:
# - generated/ directory with all configs and scripts
# - Terraform state files
```

### Destroy Cluster Nodes

```bash
# 1. Wipe disks on nodes (use Tailscale IPs)
talosctl -n 100.64.0.10 reset --graceful=false --reboot

# 2. Power off and delete VMs
# This is platform-specific (Unraid, Proxmox, etc.)

# 3. Remove nodes from Tailscale
# Visit: https://login.tailscale.com/admin/machines
# Delete each cluster node
```

## Security Considerations

### Secrets Management

This repository uses **SOPS** (Secrets OPerationS) for encrypting sensitive configuration files.

**Workflow**:

```bash
# 1. Create terraform.tfvars with sensitive values
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your actual values

# 2. Encrypt with SOPS (uses age encryption)
sops -e terraform.tfvars > terraform.tfvars.enc

# 3. Decrypt and apply (when needed)
sops -d terraform.tfvars.enc > terraform.tfvars
terraform apply
rm terraform.tfvars  # Clean up decrypted file

# 4. Commit encrypted version
git add terraform.tfvars.enc
git commit -m "chore: update encrypted terraform.tfvars"
```

**Important**:

- **Never commit** unencrypted `terraform.tfvars` (contains Tailscale auth keys)
- **Always commit** encrypted `terraform.tfvars.enc` to version control
- `.gitignore` is configured to prevent committing unencrypted secrets
- See [ADR-0002](../../../docs/decisions/0002-sops-secret-management.md) for SOPS implementation details

### Tailscale ACLs

Configure ACLs in Tailscale admin console to restrict access:

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["tag:admin"],
      "dst": ["tag:k8s:6443"]
    }
  ]
}
```

### Network Policies

With Cilium CNI, enforce network policies:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

## State Management

### Local State (Default)

State stored locally in `terraform.tfstate` (not suitable for teams).

### Remote State (Recommended)

```bash
# Deploy R2 state backend first
cd ../r2-terraform-state
terraform init
terraform apply

# Get backend configuration
terraform output -raw setup_instructions

# Update backend.tf in this directory
# Uncomment and configure backend block

# Migrate state
terraform init -migrate-state
```

See: [terraform/environments/r2-terraform-state/README.md](../r2-terraform-state/README.md)

## Advanced Configuration

### Custom Machine Config Patches

Add custom Talos configuration via patches:

```hcl
additional_control_plane_patches = [
  yamlencode({
    cluster = {
      apiServer = {
        extraArgs = {
          "enable-admission-plugins" = "PodSecurity,NodeRestriction"
        }
      }
    }
  })
]
```

### Node Labels

```hcl
node_labels = {
  "environment" = "production"
  "location"    = "homelab"
  "zone"        = "us-west"
}
```

### Custom DNS

```hcl
dns_servers = ["1.1.1.1", "1.0.0.1"]  # Cloudflare DNS
```

## Summary

This Talos cluster environment provides a **config-generation workflow** for building Kubernetes clusters on Tailscale mesh networks:

### What This Environment Does

✅ **Generates Machine Configurations**: Per-node Talos configurations with Tailscale network settings
✅ **Provides Makefile Automation**: Comprehensive Makefile for deployment, management, and operations
✅ **Manages Secrets**: Secure handling of Talos secrets and Tailscale auth keys with SOPS
✅ **Supports Heterogeneous Nodes**: Different hardware, different configurations, no problem
✅ **Enables KubePrism**: Built-in HA load balancing for the Kubernetes API
✅ **Tailscale-Native**: Cluster built entirely on Tailscale mesh network (100.64.0.0/10)

### What This Environment Does NOT Do

❌ **Does not deploy VMs**: You create and manage VMs yourself
❌ **Does not apply configs**: You use Makefile commands to apply generated configs to nodes
❌ **Does not bootstrap cluster**: You use Makefile commands to bootstrap the cluster
❌ **Does not manage running cluster**: Cluster lifecycle is managed via talosctl/kubectl

### Key Architectural Decisions

1. **Tailscale as Primary Network**: All cluster communication via Tailscale IPs
2. **Physical IPs Optional**: Only needed for initial bootstrapping, if at all
3. **Makefile-Driven Workflow**: Comprehensive task automation for deployment and operations
4. **Config Generation Only**: Terraform generates configs, Makefile manages application workflow

### Typical Workflow

```
1. make apply               → Generate configs (terraform apply)
2. make apply-configs       → Apply configs to nodes
3. make bootstrap           → Initialize cluster
4. kubectl/talosctl         → Manage cluster (make nodes, make pods)
```

## Related Documentation

- [Talos Cluster Specification](../../../specs/talos/talos-cluster-specification.md)
- [Tailscale Mesh Network Specification](../../../specs/network/tailscale-mesh-network.md)
- [Talos Linux Documentation](https://www.talos.dev/)
- [Tailscale Documentation](https://tailscale.com/kb/)
- [Terraform Talos Provider](https://registry.terraform.io/providers/siderolabs/talos/)

## Support

For issues and questions:

- **Talos**: [Talos GitHub Issues](https://github.com/siderolabs/talos/issues)
- **Tailscale**: [Tailscale Support](https://tailscale.com/contact/support)
- **This Repository**: [GitHub Issues](../../issues)

## License

See repository [LICENSE](../../../LICENSE) file.
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.0.0 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | >= 0.7.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_local"></a> [local](#provider\_local) | 2.5.3 |
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.9.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [local_file.cilium_values](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.control_plane_config](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.control_plane_patches](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.control_plane_tailscale_extension](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.talosconfig](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.worker_config](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.worker_patches](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.worker_tailscale_extension](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [talos_image_factory_schematic.nodes](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/image_factory_schematic) | resource |
| [talos_machine_secrets.cluster](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_secrets) | resource |
| [talos_client_configuration.cluster](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/client_configuration) | data source |
| [talos_machine_configuration.control_plane](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration) | data source |
| [talos_machine_configuration.worker](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_control_plane_patches"></a> [additional\_control\_plane\_patches](#input\_additional\_control\_plane\_patches) | Additional YAML patches to apply to control plane nodes (merged with Tailscale patches) | `list(string)` | `[]` | no |
| <a name="input_additional_worker_patches"></a> [additional\_worker\_patches](#input\_additional\_worker\_patches) | Additional YAML patches to apply to worker nodes (merged with Tailscale patches) | `list(string)` | `[]` | no |
| <a name="input_cert_sans"></a> [cert\_sans](#input\_cert\_sans) | Additional Subject Alternative Names (SANs) for API server certificate (Tailscale IPs will be added automatically) | `list(string)` | `[]` | no |
| <a name="input_cilium_helm_values"></a> [cilium\_helm\_values](#input\_cilium\_helm\_values) | Helm values for Cilium CNI deployment (only used when cni\_name = 'cilium'). Map of values to customize Cilium installation. | `any` | <pre>{<br/>  "hubble": {<br/>    "enabled": false,<br/>    "relay": {<br/>      "enabled": false<br/>    },<br/>    "ui": {<br/>      "enabled": false<br/>    }<br/>  },<br/>  "ipv6": {<br/>    "enabled": false<br/>  },<br/>  "k8sServiceHost": "localhost",<br/>  "k8sServicePort": 6443,<br/>  "kubeProxyReplacement": "true",<br/>  "operator": {<br/>    "replicas": 1<br/>  }<br/>}</pre> | no |
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | Kubernetes API endpoint using Tailscale IP (e.g., https://100.64.0.10:6443). Set to first control plane's Tailscale IP. | `string` | `""` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the Kubernetes cluster | `string` | n/a | yes |
| <a name="input_cni_name"></a> [cni\_name](#input\_cni\_name) | CNI plugin name (flannel, cilium, calico, or none) | `string` | `"flannel"` | no |
| <a name="input_control_plane_nodes"></a> [control\_plane\_nodes](#input\_control\_plane\_nodes) | Map of control plane nodes with their configuration (using Tailscale IPs) | <pre>map(object({<br/>    tailscale_ipv4 = string           # Tailscale IPv4 address (100.64.0.0/10 range)<br/>    tailscale_ipv6 = optional(string) # Tailscale IPv6 address (fd7a:115c:a1e0::/48 range)<br/>    physical_ip    = optional(string) # Physical IP (for initial bootstrapping only)<br/>    install_disk   = string<br/>    hostname       = optional(string)<br/>    interface      = optional(string, "tailscale0")<br/>    platform       = optional(string, "metal")                        # Platform type: metal, metal-arm64, metal-secureboot, aws, gcp, azure, etc.<br/>    extensions     = optional(list(string), ["siderolabs/tailscale"]) # Talos system extensions (default: Tailscale only)<br/>    # Kubernetes topology and node labels<br/>    region      = optional(string)          # topology.kubernetes.io/region<br/>    zone        = optional(string)          # topology.kubernetes.io/zone<br/>    arch        = optional(string)          # kubernetes.io/arch (e.g., amd64, arm64)<br/>    os          = optional(string)          # kubernetes.io/os (e.g., linux)<br/>    node_labels = optional(map(string), {}) # Additional node-specific labels<br/>  }))</pre> | n/a | yes |
| <a name="input_dns_domain"></a> [dns\_domain](#input\_dns\_domain) | Kubernetes DNS domain | `string` | `"cluster.local"` | no |
| <a name="input_enable_kubeprism"></a> [enable\_kubeprism](#input\_enable\_kubeprism) | Enable KubePrism for high-availability Kubernetes API access | `bool` | `true` | no |
| <a name="input_kubeprism_port"></a> [kubeprism\_port](#input\_kubeprism\_port) | Port for KubePrism local load balancer | `number` | `7445` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version (e.g., v1.31.0) | `string` | `"v1.31.0"` | no |
| <a name="input_node_labels"></a> [node\_labels](#input\_node\_labels) | Additional Kubernetes node labels to apply to all nodes | `map(string)` | `{}` | no |
| <a name="input_pod_cidr"></a> [pod\_cidr](#input\_pod\_cidr) | Pod network CIDR block | `string` | `"10.244.0.0/16"` | no |
| <a name="input_service_cidr"></a> [service\_cidr](#input\_service\_cidr) | Service network CIDR block | `string` | `"10.96.0.0/12"` | no |
| <a name="input_tailscale_auth_key"></a> [tailscale\_auth\_key](#input\_tailscale\_auth\_key) | Tailscale authentication key for joining the tailnet (use reusable, tagged key) | `string` | `""` | no |
| <a name="input_tailscale_tailnet"></a> [tailscale\_tailnet](#input\_tailscale\_tailnet) | Tailscale tailnet name for MagicDNS hostnames (e.g., 'example-org' for example-org.ts.net). Leave empty to skip MagicDNS hostname generation. | `string` | `""` | no |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | Talos Linux version (e.g., v1.8.0) | `string` | `"v1.8.0"` | no |
| <a name="input_use_dhcp_for_physical_interface"></a> [use\_dhcp\_for\_physical\_interface](#input\_use\_dhcp\_for\_physical\_interface) | Use DHCP for physical network interface configuration | `bool` | `true` | no |
| <a name="input_wipe_install_disk"></a> [wipe\_install\_disk](#input\_wipe\_install\_disk) | Wipe the installation disk before installing Talos | `bool` | `false` | no |
| <a name="input_worker_nodes"></a> [worker\_nodes](#input\_worker\_nodes) | Map of worker nodes with their configuration (using Tailscale IPs) | <pre>map(object({<br/>    tailscale_ipv4 = string           # Tailscale IPv4 address (100.64.0.0/10 range)<br/>    tailscale_ipv6 = optional(string) # Tailscale IPv6 address (fd7a:115c:a1e0::/48 range)<br/>    physical_ip    = optional(string) # Physical IP (for initial bootstrapping only)<br/>    install_disk   = string<br/>    hostname       = optional(string)<br/>    interface      = optional(string, "tailscale0")<br/>    platform       = optional(string, "metal")                        # Platform type: metal, metal-arm64, metal-secureboot, aws, gcp, azure, etc.<br/>    extensions     = optional(list(string), ["siderolabs/tailscale"]) # Talos system extensions (default: Tailscale only)<br/>    # Kubernetes topology and node labels<br/>    region      = optional(string)          # topology.kubernetes.io/region<br/>    zone        = optional(string)          # topology.kubernetes.io/zone<br/>    arch        = optional(string)          # kubernetes.io/arch (e.g., amd64, arm64)<br/>    os          = optional(string)          # kubernetes.io/os (e.g., linux)<br/>    node_labels = optional(map(string), {}) # Additional node-specific labels<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_client_configs"></a> [client\_configs](#output\_client\_configs) | Client configuration files for cluster access |
| <a name="output_cluster_info"></a> [cluster\_info](#output\_cluster\_info) | Cluster configuration summary |
| <a name="output_deployment_commands"></a> [deployment\_commands](#output\_deployment\_commands) | Makefile commands for cluster deployment |
| <a name="output_deployment_workflow"></a> [deployment\_workflow](#output\_deployment\_workflow) | Step-by-step deployment instructions |
| <a name="output_generated_configs"></a> [generated\_configs](#output\_generated\_configs) | Paths to all generated machine configuration files |
| <a name="output_node_summary"></a> [node\_summary](#output\_node\_summary) | Summary of cluster nodes |
| <a name="output_tailscale_config"></a> [tailscale\_config](#output\_tailscale\_config) | Tailscale network configuration |
| <a name="output_troubleshooting"></a> [troubleshooting](#output\_troubleshooting) | Common troubleshooting commands |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

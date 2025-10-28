# Technical Specification: Tailscale Mesh Network

Version: 1.0
Date: 2025-10-21
Status: Approved
Owner: Infrastructure Team

## Overview

This specification defines the implementation of Tailscale as the mesh networking solution for
hybrid cloud infrastructure, providing secure connectivity between AWS, Azure, GCP, DigitalOcean,
and on-premise resources.

## Architecture

### Network Topology

```
┌────────────────────────────────────────────────────────────────┐
│                 Tailscale Control Plane                         │
│              (tailscale.com coordination)                       │
│                                                                  │
│  • Node registration & authentication (GitHub SSO)             │
│  • WireGuard key exchange coordination                         │
│  • ACL policy distribution                                     │
│  • MagicDNS configuration                                      │
└────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS (443)
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
┌───────▼────────┐    ┌──────▼───────┐    ┌───────▼────────┐
│   AWS VPCs     │    │  Azure VNets │    │ On-Premise DC  │
│                │    │              │    │                │
│ ┌────────────┐ │    │ ┌──────────┐ │    │ ┌────────────┐ │
│ │ Tailscale  │ │    │ │Tailscale │ │    │ │ Tailscale  │ │
│ │Subnet Router│◄├────┤►│  Subnet  │◄├────┤►│   Subnet   │ │
│ │  (Primary) │ │    │ │  Router  │ │    │ │   Router   │ │
│ └────────────┘ │    │ └──────────┘ │    │ └────────────┘ │
│       │        │    │      │       │    │       │        │
│ ┌────────────┐ │    │ ┌──────────┐ │    │ ┌────────────┐ │
│ │ Tailscale  │ │    │ │Tailscale │ │    │ │ Tailscale  │ │
│ │Subnet Router│ │    │ │  Subnet  │ │    │ │   Subnet   │ │
│ │ (Secondary)│ │    │ │  Router  │ │    │ │   Router   │ │
│ └────────────┘ │    │ │(Secondary│ │    │ │ (Secondary)│ │
│                │    │ └──────────┘ │    │ └────────────┘ │
│  Advertises:   │    │ Advertises:  │    │  Advertises:   │
│  10.0.0.0/8    │    │10.128.0.0/9  │    │192.168.0.0/16  │
└────────────────┘    └──────────────┘    └────────────────┘
         ▲                    ▲                    ▲
         │                    │                    │
         └────────────────────┴────────────────────┘
           WireGuard encrypted mesh (UDP 41641)
           Direct P2P connections when possible
           DERP relay fallback when NAT traversal fails
```

### IP Address Allocation

| Network Segment | CIDR Range | Tailscale Range | Purpose |
|-----------------|------------|-----------------|---------|
| **Tailscale Network** | 100.64.0.0/10 | 100.64.0.1 - 100.127.255.254 | Carrier-grade NAT (CGNAT) range for Tailscale IPs |
| **AWS VPC** | 10.0.0.0/8 | Via subnet routing | Cloud workloads (dev, staging, prod) |
| **Azure VNet** | 10.128.0.0/9 | Via subnet routing | Cloud workloads (dev, staging, prod) |
| **GCP VPC** | 10.64.0.0/10 | Via subnet routing | Cloud workloads (dev, staging, prod) |
| **DigitalOcean VPC** | 10.240.0.0/16 | Via subnet routing | Development and testing |
| **On-Premise** | 192.168.0.0/16 | Via subnet routing | Physical data center |

**Note**: Tailscale assigns IP addresses from 100.64.0.0/10 range to all nodes. Private subnets are accessed via subnet routing, not direct Tailscale assignment.

### DNS Configuration

#### MagicDNS

- **Tailnet Name**: `tail-abc123.ts.net` (Tailscale assigns unique tailnet name)
- **Node Naming**: `{hostname}.tail-abc123.ts.net`
- **MagicDNS**: Enabled for all nodes
- **Override DNS**: Disabled (use default DNS for non-Tailscale queries)

#### Example DNS Records

```
# Subnet routers
aws-router-primary.tail-abc123.ts.net     → 100.64.0.10
aws-router-secondary.tail-abc123.ts.net   → 100.64.0.11
azure-router-primary.tail-abc123.ts.net   → 100.64.0.20
onprem-router-primary.tail-abc123.ts.net  → 100.64.0.30

# Developer machines
alice-laptop.tail-abc123.ts.net           → 100.64.1.50
bob-workstation.tail-abc123.ts.net        → 100.64.1.51

# Kubernetes nodes (optional, if Tailscale deployed per-node)
k8s-prod-node-01.tail-abc123.ts.net       → 100.64.2.100
k8s-prod-node-02.tail-abc123.ts.net       → 100.64.2.101
```

## Component Specifications

### Subnet Router Instances

Subnet routers are Linux VMs running Tailscale that advertise access to entire subnets.

#### Requirements

- **OS**: Ubuntu 22.04 LTS or later
- **vCPU**: 2 vCPU (minimum), 4 vCPU (recommended for high throughput)
- **Memory**: 2 GB RAM (minimum), 4 GB RAM (recommended)
- **Network**: 1 Gbps network interface (minimum)
- **Storage**: 20 GB SSD
- **High Availability**: Deploy 2 subnet routers per environment for redundancy

#### Installation

```bash
#!/bin/bash
# Install Tailscale on subnet router

# Add Tailscale package repository
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list

# Install Tailscale
sudo apt-get update
sudo apt-get install -y tailscale

# Enable IP forwarding (required for subnet routing)
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf

# Start Tailscale and authenticate
# Use auth key from Tailscale admin console (reusable, tagged key)
sudo tailscale up --auth-key=tskey-auth-XXXXX \
  --advertise-routes=10.0.0.0/16 \
  --accept-routes \
  --ssh

# Verify subnet routing
tailscale status
ip route show table 52
```

#### Configuration

**Environment-Specific Subnet Advertisements**:

| Environment | Location | Advertised Routes | Tags |
|-------------|----------|-------------------|------|
| **AWS Dev** | us-east-1 | 10.0.0.0/16 | `tag:aws`, `tag:dev` |
| **AWS Staging** | us-east-1 | 10.1.0.0/16 | `tag:aws`, `tag:staging` |
| **AWS Prod** | us-east-1, us-west-2 | 10.2.0.0/16 | `tag:aws`, `tag:production` |
| **Azure Dev** | eastus | 10.128.0.0/16 | `tag:azure`, `tag:dev` |
| **Azure Prod** | eastus | 10.129.0.0/16 | `tag:azure`, `tag:production` |
| **On-Premise** | Physical DC | 192.168.0.0/16 | `tag:onprem`, `tag:production` |

#### Redundancy and High Availability

- **Primary/Secondary**: Deploy 2 subnet routers per environment
- **Active-Active**: Both routers advertise the same routes
- **Automatic Failover**: Tailscale automatically routes through available routers
- **Health Checks**: Monitor router status via Tailscale API
- **Split-Brain Prevention**: No manual intervention required, Tailscale handles routing

#### Monitoring

```bash
# Install Tailscale Prometheus exporter
wget https://github.com/tailscale/tailscale/releases/download/v1.x.x/tailscale_exporter
chmod +x tailscale_exporter
sudo mv tailscale_exporter /usr/local/bin/

# Run exporter (systemd service)
sudo tailscale_exporter --listen=:9090
```

**Metrics to Monitor**:

- `tailscale_peer_status{peer}` - Peer connection status (1=connected, 0=disconnected)
- `tailscale_peer_rx_bytes{peer}` - Bytes received from peer
- `tailscale_peer_tx_bytes{peer}` - Bytes transmitted to peer
- `tailscale_peer_latency_seconds{peer}` - Round-trip latency to peer
- `tailscale_node_update_available` - Software update available

### Access Control Lists (ACLs)

ACLs are defined in JSON format and managed via GitOps workflow.

#### ACL Structure

```json
{
  "tagOwners": {
    "tag:aws": ["group:sre"],
    "tag:azure": ["group:sre"],
    "tag:onprem": ["group:sre"],
    "tag:dev": ["group:developers"],
    "tag:staging": ["group:developers", "group:sre"],
    "tag:production": ["group:sre"]
  },
  "groups": {
    "group:sre": [
      "alice@github",
      "bob@github",
      "charlie@github"
    ],
    "group:developers": [
      "dev1@github",
      "dev2@github",
      "dev3@github"
    ],
    "group:data": [
      "analyst1@github",
      "analyst2@github"
    ]
  },
  "hosts": {
    "aws-prod-db": "10.2.10.50",
    "azure-prod-api": "10.129.20.100",
    "onprem-ldap": "192.168.10.10"
  },
  "acls": [
    // Development environment - developers have full access
    {
      "action": "accept",
      "src": ["group:developers", "group:sre"],
      "dst": ["tag:dev:*"]
    },

    // Staging environment - developers and SRE
    {
      "action": "accept",
      "src": ["group:developers", "group:sre"],
      "dst": ["tag:staging:*"]
    },

    // Production environment - SRE only, restricted ports
    {
      "action": "accept",
      "src": ["group:sre"],
      "dst": [
        "tag:production:22",   // SSH
        "tag:production:443",  // HTTPS
        "tag:production:6443", // Kubernetes API
        "tag:production:9090"  // Prometheus
      ]
    },

    // Database access - SRE and data team, specific hosts only
    {
      "action": "accept",
      "src": ["group:sre", "group:data"],
      "dst": [
        "aws-prod-db:5432",     // PostgreSQL
        "aws-prod-db:6379"      // Redis
      ]
    },

    // Subnet routers - allow all to advertise routes
    {
      "action": "accept",
      "src": ["tag:aws", "tag:azure", "tag:onprem"],
      "dst": ["*:*"]
    },

    // SSH access via Tailscale SSH
    {
      "action": "accept",
      "src": ["group:sre"],
      "dst": ["tag:production:*"],
      "ports": ["22:22"]
    }
  ],
  "ssh": [
    {
      "action": "accept",
      "src": ["group:sre"],
      "dst": ["tag:production"],
      "users": ["ubuntu", "root"]
    },
    {
      "action": "accept",
      "src": ["group:developers"],
      "dst": ["tag:dev", "tag:staging"],
      "users": ["ubuntu"]
    }
  ]
}
```

#### ACL Management Workflow

1. **Edit ACL**: Modify `tailscale-acl.json` in repository
2. **Validate**: Test ACL syntax using Tailscale ACL validator
3. **Review**: Create pull request for team review
4. **Apply**: Merge to main branch triggers automated deployment
5. **Monitor**: Check audit logs for unexpected denials

```bash
# Validate ACL locally
tailscale configure acl validate --file tailscale-acl.json

# Apply ACL (after merge)
tailscale configure acl set --file tailscale-acl.json
```

### Authentication and Authorization

#### SSO Integration

- **Provider**: GitHub
- **Organization**: `shangkuei` (GitHub organization)
- **MFA Requirement**: Enabled (enforce 2FA for all users)
- **Session Duration**: 30 days (re-authentication required)
- **Device Authorization**: Manual approval for new devices

#### Auth Keys for Automation

Auth keys are used for subnet routers and automated deployments.

**Key Types**:

- **Reusable**: Can be used multiple times (for subnet routers)
- **Ephemeral**: Single-use, node removed when disconnected (for CI/CD)
- **Tagged**: Pre-tagged with environment and provider tags

**Key Management**:

```bash
# Generate reusable auth key for AWS production subnet router
# Tag: aws, production
# Expiry: 90 days
tailscale generate auth-key --reusable --tag tag:aws,tag:production --expiry 90d

# Generate ephemeral key for CI/CD testing
tailscale generate auth-key --ephemeral --tag tag:ci
```

**Storage**: Auth keys stored in HashiCorp Vault (see [ADR-0008](../../docs/decisions/0008-secret-management.md))

### Tailscale SSH

Enable SSH access through Tailscale for secure, audited connections.

#### Benefits

- **No public SSH**: Servers don't need public SSH ports (port 22 closed to internet)
- **Audited**: All SSH sessions logged and auditable
- **ACL-controlled**: SSH access controlled by Tailscale ACLs
- **No SSH keys**: SSH authentication via Tailscale identity
- **Session recording**: Optional session recording for compliance

#### Configuration

```bash
# Enable Tailscale SSH on subnet router
sudo tailscale up --ssh

# SSH to server via Tailscale
ssh ubuntu@aws-router-primary.tail-abc123.ts.net
```

#### ACL for SSH

See ACL section above for SSH-specific rules.

## Deployment Procedures

### Initial Setup

#### 1. Create Tailscale Account

```bash
# Sign up at https://login.tailscale.com/start
# Choose "GitHub" as SSO provider
# Connect to "shangkuei" organization
```

#### 2. Configure Tailnet Settings

**Admin Console** → **Settings**:

- **Tailnet Name**: `shangkuei-infra` (or auto-assigned)
- **MagicDNS**: ✅ Enabled
- **HTTPS Certificates**: ❌ Disabled (using Cloudflare)
- **Key Expiry**: 180 days
- **Device Authorization**: Manual approval for production

#### 3. Define ACL Policies

Upload initial ACL configuration (see ACL section above).

#### 4. Generate Auth Keys

Generate tagged, reusable auth keys for each environment:

```bash
# AWS Development
tailscale generate auth-key --reusable --tag tag:aws,tag:dev --expiry 90d

# AWS Production
tailscale generate auth-key --reusable --tag tag:aws,tag:production --expiry 90d

# Azure Production
tailscale generate auth-key --reusable --tag tag:azure,tag:production --expiry 90d

# On-Premise
tailscale generate auth-key --reusable --tag tag:onprem,tag:production --expiry 180d
```

Store keys in HashiCorp Vault.

### Subnet Router Deployment

#### AWS (Terraform)

```hcl
# terraform/modules/tailscale-router/main.tf

resource "aws_instance" "tailscale_router" {
  ami           = data.aws_ami.ubuntu_22_04.id
  instance_type = "t3.medium"
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [aws_security_group.tailscale_router.id]

  iam_instance_profile = aws_iam_instance_profile.tailscale_router.name

  user_data = templatefile("${path.module}/user_data.sh", {
    tailscale_auth_key = var.tailscale_auth_key
    advertise_routes   = var.advertise_routes
  })

  tags = {
    Name        = "${var.environment}-tailscale-router-${var.az}"
    Environment = var.environment
    Role        = "tailscale-subnet-router"
  }
}

resource "aws_security_group" "tailscale_router" {
  name_description = "${var.environment}-tailscale-router"
  vpc_id           = var.vpc_id

  # Allow Tailscale UDP traffic
  ingress {
    from_port   = 41641
    to_port     = 41641
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Tailscale WireGuard"
  }

  # Allow HTTPS for control plane
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Tailscale control plane"
  }

  # Allow all traffic within VPC (for subnet routing)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
    description = "VPC internal traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }
}
```

**User Data Script** (`user_data.sh`):

```bash
#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install Tailscale
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list
apt-get update
apt-get install -y tailscale

# Enable IP forwarding
cat <<EOF > /etc/sysctl.d/99-tailscale.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sysctl -p /etc/sysctl.d/99-tailscale.conf

# Start Tailscale with subnet routing
tailscale up \
  --auth-key=${tailscale_auth_key} \
  --advertise-routes=${advertise_routes} \
  --accept-routes \
  --ssh \
  --hostname=$(hostname)-$(ec2-metadata --instance-id | cut -d' ' -f2)

# Install monitoring
apt-get install -y prometheus-node-exporter

# Configure systemd to restart Tailscale on failure
systemctl enable tailscaled
systemctl start tailscaled
```

#### Ansible Playbook (On-Premise)

```yaml
# ansible/playbooks/tailscale/deploy_router.yml

---
- name: Deploy Tailscale Subnet Router
  hosts: tailscale_routers
  become: yes

  vars:
    advertise_routes: "{{ lookup('env', 'ADVERTISE_ROUTES') }}"
    auth_key: "{{ lookup('hashi_vault', 'secret=secret/tailscale/auth_key:value') }}"

  tasks:
    - name: Add Tailscale GPG key
      apt_key:
        url: https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg
        state: present

    - name: Add Tailscale repository
      apt_repository:
        repo: deb https://pkgs.tailscale.com/stable/ubuntu jammy main
        state: present

    - name: Install Tailscale
      apt:
        name: tailscale
        state: present
        update_cache: yes

    - name: Enable IP forwarding
      sysctl:
        name: "{{ item }}"
        value: '1'
        state: present
        reload: yes
      loop:
        - net.ipv4.ip_forward
        - net.ipv6.conf.all.forwarding

    - name: Start Tailscale
      command: >
        tailscale up
        --auth-key={{ auth_key }}
        --advertise-routes={{ advertise_routes }}
        --accept-routes
        --ssh
        --hostname={{ inventory_hostname }}
      args:
        creates: /var/lib/tailscale/tailscaled.state

    - name: Enable Tailscale service
      systemd:
        name: tailscaled
        enabled: yes
        state: started
```

### Developer Onboarding

#### Installation Instructions

**macOS**:

```bash
# Install via Homebrew
brew install tailscale

# Start Tailscale
sudo tailscale up --accept-routes

# Authenticate via browser (GitHub SSO)
```

**Linux**:

```bash
# Install from package repository
curl -fsSL https://tailscale.com/install.sh | sh

# Start Tailscale
sudo tailscale up --accept-routes
```

**Windows**:

```powershell
# Download installer from https://tailscale.com/download/windows
# Run installer
# Click "Connect" and authenticate via GitHub
```

#### Access Verification

```bash
# Check Tailscale status
tailscale status

# Verify subnet routes
tailscale status --json | jq '.Peer[] | select(.PrimaryRoutes != null) | {hostname: .HostName, routes: .PrimaryRoutes}'

# Test connectivity to AWS development VPC
ping 10.0.10.100  # Example AWS instance

# SSH to subnet router
ssh ubuntu@aws-router-primary.tail-abc123.ts.net

# Access internal service
curl https://api.internal.example.com
```

## Operations and Maintenance

### Regular Maintenance Tasks

#### Weekly

- **Monitor Connection Status**: Check that all subnet routers are connected
- **Review ACL Denials**: Analyze denied connections in audit logs
- **Check Node Inventory**: Verify expected nodes are online

#### Monthly

- **ACL Review**: Review and update ACL policies for least privilege
- **Key Rotation**: Rotate expiring auth keys
- **Performance Review**: Analyze latency and throughput metrics
- **Cost Review**: Review Tailscale billing and user count

#### Quarterly

- **Access Audit**: Audit user access and remove inactive users
- **Security Review**: Review ACLs, SSH access, and audit logs
- **Capacity Planning**: Evaluate subnet router sizing and redundancy
- **Disaster Recovery Test**: Simulate subnet router failures

### Troubleshooting

#### Connectivity Issues

**Problem**: Node cannot connect to Tailscale network

```bash
# Check Tailscale status
tailscale status

# Check if logged in
tailscale status --json | jq '.BackendState'

# Re-authenticate
sudo tailscale up

# Check network connectivity to control plane
ping controlplane.tailscale.com
curl -v https://controlplane.tailscale.com
```

**Problem**: Cannot reach subnet via Tailscale

```bash
# Verify subnet routes are advertised
tailscale status

# Check if subnet router is accepting routes
tailscale status --json | jq '.Peer[] | select(.PrimaryRoutes != null)'

# Verify routing table
ip route show table 52  # Linux
netstat -rn              # macOS/Windows

# Test connectivity to subnet router directly
ping aws-router-primary.tail-abc123.ts.net

# Trace route to subnet
traceroute 10.0.10.100
```

**Problem**: High latency or packet loss

```bash
# Check connection type (direct vs. DERP relay)
tailscale status

# If using DERP relay, check why direct connection failed
tailscale netcheck

# Test latency to subnet router
ping -c 10 aws-router-primary.tail-abc123.ts.net

# Test bandwidth
iperf3 -c aws-router-primary.tail-abc123.ts.net
```

#### ACL Issues

**Problem**: Access denied by ACL

```bash
# Check current ACL
tailscale configure acl get

# Validate ACL syntax
tailscale configure acl validate --file tailscale-acl.json

# Check audit logs (Admin Console)
# Navigate to Admin Console → Logs → Access Logs
```

### Monitoring and Alerting

#### Prometheus Metrics

```yaml
# prometheus/tailscale-exporter.yml

scrape_configs:
  - job_name: 'tailscale-routers'
    static_configs:
      - targets:
          - 'aws-router-primary.tail-abc123.ts.net:9090'
          - 'aws-router-secondary.tail-abc123.ts.net:9090'
          - 'azure-router-primary.tail-abc123.ts.net:9090'
          - 'onprem-router-primary.tail-abc123.ts.net:9090'
```

#### Grafana Dashboard

**Key Panels**:

- Connection status per node (up/down)
- Network throughput (Mbps)
- Latency heatmap (ms)
- DERP relay usage percentage
- Subnet router CPU/memory usage

#### Alerts

```yaml
# prometheus/alerts/tailscale.yml

groups:
  - name: tailscale
    interval: 30s
    rules:
      - alert: TailscaleRouterDown
        expr: up{job="tailscale-routers"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Tailscale subnet router {{ $labels.instance }} is down"

      - alert: TailscaleHighLatency
        expr: tailscale_peer_latency_seconds > 0.1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High latency to Tailscale peer {{ $labels.peer }}"

      - alert: TailscaleDERPRelayUsage
        expr: (sum(tailscale_derp_relay_connections) / sum(tailscale_total_connections)) > 0.2
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "More than 20% of connections using DERP relay (NAT traversal issues)"
```

### Backup and Disaster Recovery

#### ACL Backup

ACLs are stored in Git repository, automatically backed up.

**Recovery**:

```bash
# Restore ACL from Git
git checkout main -- tailscale-acl.json
tailscale configure acl set --file tailscale-acl.json
```

#### Node Configuration Backup

Tailscale node configuration stored in Tailscale control plane (cloud).

**Recovery**:

- Redeploy subnet router from Terraform/Ansible (infrastructure as code)
- Authenticate with same auth key (if reusable) or generate new key
- Node automatically rejoins network and advertises routes

#### Subnet Router Failover

**Automatic Failover**:

- Deploy primary and secondary subnet routers per environment
- Both routers advertise the same routes
- Tailscale automatically routes through available router
- No manual intervention required

**Manual Failover**:

```bash
# If primary router down, verify secondary is active
tailscale status

# Check routes are still advertised
ip route show table 52

# If secondary also down, deploy new router from Terraform
terraform apply -target=module.tailscale_router.aws_instance.tailscale_router
```

## Security Hardening

### Subnet Router Hardening

```bash
# Disable password authentication
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# Enable unattended upgrades
sudo apt-get install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# Configure firewall (ufw)
sudo ufw allow 41641/udp  # Tailscale
sudo ufw allow 443/tcp    # HTTPS
sudo ufw allow from 100.64.0.0/10 to any port 22  # SSH from Tailscale only
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable

# Disable unused services
sudo systemctl disable bluetooth
sudo systemctl disable cups

# Enable audit logging
sudo apt-get install -y auditd
sudo systemctl enable auditd
```

### ACL Best Practices

1. **Least Privilege**: Grant minimum necessary access
2. **Explicit Deny**: Use explicit deny rules where appropriate
3. **Tag-Based**: Use tags for scalable, maintainable policies
4. **Port Restrictions**: Specify exact ports, avoid wildcards in production
5. **Regular Audits**: Review and update ACLs quarterly
6. **Version Control**: Store ACLs in Git with full history

### Compliance

**Audit Logging**:

- All connections logged in Tailscale Admin Console
- Export logs to SIEM for compliance (Splunk, Datadog)
- Retain logs for 1 year minimum

**Access Reviews**:

- Quarterly access review for all users
- Remove inactive users and devices
- Verify ACL policies align with current requirements

## Performance Optimization

### Subnet Router Sizing

**Small Environment** (< 50 nodes):

- 2 vCPU, 2 GB RAM
- 1 Gbps network
- Estimated throughput: 500 Mbps

**Medium Environment** (50-200 nodes):

- 4 vCPU, 4 GB RAM
- 5 Gbps network
- Estimated throughput: 1-2 Gbps

**Large Environment** (200+ nodes):

- 8 vCPU, 8 GB RAM
- 10 Gbps network
- Estimated throughput: 3-5 Gbps

### Latency Optimization

**Direct Connections**:

- Ensure UDP port 41641 is not blocked by firewalls
- Configure security groups to allow UDP from 0.0.0.0/0
- Use low-latency network interfaces (enhanced networking on AWS)

**DERP Relay Fallback**:

- If >10% connections using DERP relay, investigate NAT/firewall issues
- Check `tailscale netcheck` for NAT traversal problems
- Consider manual port forwarding if direct connections fail

### Throughput Optimization

```bash
# Increase network buffer sizes on subnet routers
sudo sysctl -w net.core.rmem_max=134217728
sudo sysctl -w net.core.wmem_max=134217728
sudo sysctl -w net.ipv4.tcp_rmem='4096 87380 67108864'
sudo sysctl -w net.ipv4.tcp_wmem='4096 65536 67108864'

# Enable TCP BBR congestion control
sudo sysctl -w net.core.default_qdisc=fq
sudo sysctl -w net.ipv4.tcp_congestion_control=bbr

# Persist changes
echo "net.core.rmem_max=134217728" | sudo tee -a /etc/sysctl.conf
echo "net.core.wmem_max=134217728" | sudo tee -a /etc/sysctl.conf
# ... (add all changes)
sudo sysctl -p
```

## Cost Optimization

### Licensing

- **Free Tier**: 20 devices, 1 user (suitable for personal use)
- **Personal Pro**: $48/year, 100 devices, 1 user
- **Team**: $6/user/month, unlimited devices
- **Enterprise**: Custom pricing, advanced features

**Recommendation**: Start with Team plan, ~100 users = $600/month

### Infrastructure Costs

**AWS Subnet Routers** (t3.medium):

- Instance cost: $0.0416/hour × 720 hours = ~$30/month per router
- Data transfer: Free within same region, $0.01/GB cross-region
- Estimated: $60/month for 2 routers per environment × 3 environments = $180/month

**Total Monthly Cost**: ~$780/month (Tailscale subscription + infrastructure)

**Cost Savings**:

- Eliminated AWS VPN Gateway: $36/month per gateway × 3 = $108/month saved
- Eliminated OpenVPN licensing: $1,500/month saved
- Reduced operational overhead: ~19 hours/month × $100/hour = $1,900/month saved

**Net Savings**: ~$1,228/month or $14,736/year

## Testing and Validation

### Functional Testing

```bash
#!/bin/bash
# Test Tailscale connectivity

# Test 1: Verify Tailscale is running
tailscale status || { echo "Tailscale not running"; exit 1; }

# Test 2: Check subnet routes are advertised
routes=$(tailscale status --json | jq -r '.Peer[] | select(.PrimaryRoutes != null) | .PrimaryRoutes[]')
echo "Advertised routes: $routes"

# Test 3: Ping subnet router
ping -c 3 aws-router-primary.tail-abc123.ts.net || { echo "Cannot reach subnet router"; exit 1; }

# Test 4: Test connectivity to subnet
ping -c 3 10.0.10.100 || { echo "Cannot reach subnet"; exit 1; }

# Test 5: Test MagicDNS resolution
nslookup aws-router-primary.tail-abc123.ts.net || { echo "MagicDNS not working"; exit 1; }

# Test 6: SSH via Tailscale
ssh -o ConnectTimeout=5 ubuntu@aws-router-primary.tail-abc123.ts.net "echo 'SSH test successful'"

echo "All tests passed!"
```

### Performance Testing

```bash
#!/bin/bash
# Performance test between Tailscale nodes

# Latency test
echo "Latency test:"
ping -c 100 aws-router-primary.tail-abc123.ts.net | tail -1

# Throughput test (requires iperf3 on both ends)
echo "Throughput test:"
iperf3 -c aws-router-primary.tail-abc123.ts.net -t 30 -P 4

# Packet loss test
echo "Packet loss test:"
ping -c 1000 -i 0.01 aws-router-primary.tail-abc123.ts.net | grep "packet loss"
```

### Load Testing

```bash
# Simulate 100 concurrent connections through subnet router
for i in {1..100}; do
  curl -s http://10.0.10.100 &
done
wait

# Monitor subnet router CPU and network during load
ssh ubuntu@aws-router-primary.tail-abc123.ts.net "top -b -n 1 | head -20"
```

## Related Documentation

- [ADR-0009: Tailscale for Hybrid Cloud Networking](../../docs/decisions/0009-tailscale-hybrid-networking.md)
- [Research: Tailscale Evaluation](../../docs/research/0017-tailscale-evaluation.md)
- [Research: Hybrid Cloud Networking](../../docs/research/0007-hybrid-cloud-networking.md)
- [Runbook: Cloudflare Operations](../../docs/runbooks/0001-cloudflare-operations.md)
- [Network Specifications](README.md)
- [ADR-0008: Secret Management](../../docs/decisions/0008-secret-management.md)

## Changelog

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-21 | Infrastructure Team | Initial specification |

## Approvals

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Infrastructure Lead | | | |
| Security Lead | | | |
| Network Architect | | | |

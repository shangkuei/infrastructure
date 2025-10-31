# Oracle Cloud Infrastructure Operations Runbook

**Document Version**: 1.0
**Last Updated**: 2025-10-28
**Audience**: DevOps Engineers, SREs, Infrastructure Administrators
**Prerequisites**: Oracle Cloud account with Always Free tier resources provisioned

## Overview

This runbook provides operational procedures for managing Oracle Cloud Infrastructure (OCI) resources, specifically
focused on Oracle Kubernetes Engine (OKE) clusters running on the Always Free tier using Ampere A1 (Arm) compute
instances.

## Table of Contents

- [Prerequisites and Setup](#prerequisites-and-setup)
- [OCI CLI Configuration](#oci-cli-configuration)
- [OKE Cluster Operations](#oke-cluster-operations)
- [Compute Instance Management](#compute-instance-management)
- [Networking Operations](#networking-operations)
- [Storage Management](#storage-management)
- [Monitoring and Observability](#monitoring-and-observability)
- [Cost Monitoring](#cost-monitoring)
- [Troubleshooting](#troubleshooting)
- [Disaster Recovery](#disaster-recovery)

## Prerequisites and Setup

### Requirements

- OCI account with Always Free tier access
- OCI CLI version 3.30.0 or later
- kubectl 1.28.0 or later
- Terraform 1.6.0 or later (for infrastructure changes)
- SSH key pair for instance access

### OCI CLI Installation

**macOS**:

```bash
brew install oci-cli
```

**Linux**:

```bash
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
```

**Verify Installation**:

```bash
oci --version
# Expected output: oci-cli version 3.30.0+
```

## OCI CLI Configuration

### Initial Setup

**Interactive Configuration**:

```bash
oci setup config

# Follow prompts:
# 1. Enter config file location (default: ~/.oci/config)
# 2. Enter user OCID (from OCI Console → User Settings)
# 3. Enter tenancy OCID (from OCI Console → Tenancy Details)
# 4. Enter region (us-phoenix-1 or us-ashburn-1 for Always Free Arm)
# 5. Generate new API key pair (Y/n)
```

**Configuration File Location**: `~/.oci/config`

**Example Configuration**:

```ini
[DEFAULT]
user=ocid1.user.oc1..aaaaaaaxxxxx
fingerprint=xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx
tenancy=ocid1.tenancy.oc1..aaaaaaaxxxxx
region=us-phoenix-1
key_file=~/.oci/oci_api_key.pem
```

### Upload API Public Key to OCI Console

1. Navigate to **User Settings** → **API Keys**
2. Click **Add API Key**
3. Upload or paste public key from `~/.oci/oci_api_key_public.pem`
4. Note the fingerprint (must match config file)

### Verify Configuration

```bash
# Test connection
oci iam region list

# View current user
oci iam user get --user-id <your-user-ocid>

# List compartments
oci iam compartment list --compartment-id-in-subtree true
```

## OKE Cluster Operations

### Get Cluster Information

**List All Clusters**:

```bash
oci ce cluster list --compartment-id <compartment-ocid> --lifecycle-state ACTIVE
```

**Get Cluster Details**:

```bash
# Get cluster OCID
export CLUSTER_ID=$(oci ce cluster list \
  --compartment-id <compartment-ocid> \
  --lifecycle-state ACTIVE \
  --query 'data[0].id' \
  --raw-output)

# View cluster details
oci ce cluster get --cluster-id $CLUSTER_ID
```

### Configure kubectl Access

**Download kubeconfig**:

```bash
# Create kubeconfig for cluster
oci ce cluster create-kubeconfig \
  --cluster-id $CLUSTER_ID \
  --file ~/.kube/config-oke \
  --region us-phoenix-1 \
  --token-version 2.0.0 \
  --kube-endpoint PUBLIC_ENDPOINT

# Merge with existing kubeconfig
export KUBECONFIG=~/.kube/config:~/.kube/config-oke
kubectl config view --flatten > ~/.kube/config-merged
mv ~/.kube/config-merged ~/.kube/config

# Test access
kubectl get nodes
kubectl get pods --all-namespaces
```

**Set Default Context**:

```bash
kubectl config get-contexts
kubectl config use-context <oke-cluster-context>
```

### Node Pool Management

**List Node Pools**:

```bash
oci ce node-pool list --compartment-id <compartment-ocid> --cluster-id $CLUSTER_ID
```

**Get Node Pool Details**:

```bash
export NODE_POOL_ID=$(oci ce node-pool list \
  --compartment-id <compartment-ocid> \
  --cluster-id $CLUSTER_ID \
  --query 'data[0].id' \
  --raw-output)

oci ce node-pool get --node-pool-id $NODE_POOL_ID
```

**Scale Node Pool** (within Always Free limits):

```bash
# WARNING: Ensure total OCPUs ≤ 4 and memory ≤ 24GB
oci ce node-pool update \
  --node-pool-id $NODE_POOL_ID \
  --quantity-per-subnet 2  # Number of nodes
```

### Cluster Upgrades

**List Available Kubernetes Versions**:

```bash
oci ce cluster-options get --cluster-option-id all --compartment-id <compartment-ocid>
```

**Upgrade Cluster** (control plane):

```bash
oci ce cluster update \
  --cluster-id $CLUSTER_ID \
  --kubernetes-version v1.28.2
```

**Upgrade Node Pool** (worker nodes):

```bash
oci ce node-pool update \
  --node-pool-id $NODE_POOL_ID \
  --kubernetes-version v1.28.2
```

## Compute Instance Management

### List Compute Instances

```bash
oci compute instance list \
  --compartment-id <compartment-ocid> \
  --lifecycle-state RUNNING
```

### View Instance Details

```bash
export INSTANCE_ID="ocid1.instance.oc1.phx.xxx"

oci compute instance get --instance-id $INSTANCE_ID
```

### Connect to Instance via SSH

```bash
# Get instance public IP
export INSTANCE_IP=$(oci compute instance list-vnics \
  --instance-id $INSTANCE_ID \
  --query 'data[0]."public-ip"' \
  --raw-output)

# SSH into instance (OKE nodes)
ssh -i ~/.ssh/id_rsa opc@$INSTANCE_IP

# For Ubuntu instances
ssh -i ~/.ssh/id_rsa ubuntu@$INSTANCE_IP
```

### Stop/Start Instances

**Stop Instance** (to save Always Free hours if needed):

```bash
oci compute instance action --action STOP --instance-id $INSTANCE_ID
```

**Start Instance**:

```bash
oci compute instance action --action START --instance-id $INSTANCE_ID
```

**Reboot Instance**:

```bash
oci compute instance action --action RESET --instance-id $INSTANCE_ID
```

## Networking Operations

### VCN (Virtual Cloud Network) Operations

**List VCNs**:

```bash
oci network vcn list --compartment-id <compartment-ocid>
```

**View VCN Details**:

```bash
export VCN_ID="ocid1.vcn.oc1.phx.xxx"

oci network vcn get --vcn-id $VCN_ID
```

### Subnet Management

**List Subnets**:

```bash
oci network subnet list --compartment-id <compartment-ocid> --vcn-id $VCN_ID
```

**View Subnet Details**:

```bash
export SUBNET_ID="ocid1.subnet.oc1.phx.xxx"

oci network subnet get --subnet-id $SUBNET_ID
```

### Security List Management

**List Security Lists**:

```bash
oci network security-list list --compartment-id <compartment-ocid> --vcn-id $VCN_ID
```

**Add Ingress Rule** (emergency access):

```bash
export SECURITY_LIST_ID="ocid1.securitylist.oc1.phx.xxx"

oci network security-list update \
  --security-list-id $SECURITY_LIST_ID \
  --ingress-security-rules '[{
    "source": "YOUR_IP/32",
    "protocol": "6",
    "tcpOptions": {"destinationPortRange": {"min": 22, "max": 22}},
    "isStateless": false
  }]'
```

### Load Balancer Operations

**List Load Balancers**:

```bash
oci lb load-balancer list --compartment-id <compartment-ocid>
```

**View Load Balancer Health**:

```bash
export LB_ID="ocid1.loadbalancer.oc1.phx.xxx"

oci lb load-balancer-health get --load-balancer-id $LB_ID
```

## Storage Management

### Block Volume Operations

**List Block Volumes**:

```bash
oci bv volume list --compartment-id <compartment-ocid>
```

**View Volume Details**:

```bash
export VOLUME_ID="ocid1.volume.oc1.phx.xxx"

oci bv volume get --volume-id $VOLUME_ID
```

**Check Total Storage Usage** (Always Free limit: 200GB):

```bash
oci bv volume list \
  --compartment-id <compartment-ocid> \
  --query 'sum(data[*]."size-in-gbs")' \
  --raw-output
```

### Object Storage Operations

**List Buckets**:

```bash
oci os bucket list --compartment-id <compartment-ocid> --namespace <namespace>
```

**View Bucket Details**:

```bash
oci os bucket get --bucket-name <bucket-name> --namespace <namespace>
```

**Upload File to Object Storage**:

```bash
oci os object put \
  --bucket-name <bucket-name> \
  --namespace <namespace> \
  --file /path/to/local/file \
  --name remote-filename
```

**Check Storage Usage** (Always Free limit: 20GB):

```bash
oci os bucket list \
  --compartment-id <compartment-ocid> \
  --namespace <namespace> \
  --fields approximateSize

# Sum manually or use jq
oci os bucket list \
  --compartment-id <compartment-ocid> \
  --namespace <namespace> \
  --query 'sum(data[*]."approximate-size")' \
  --raw-output
```

## Monitoring and Observability

### OCI Monitoring (Free Tier)

**View Compute Metrics**:

```bash
# CPU utilization
oci monitoring metric-data summarize-metrics-data \
  --namespace oci_computeagent \
  --query-text 'CpuUtilization[1m]{resourceId = "<instance-ocid>"}.mean()' \
  --start-time 2025-10-28T00:00:00Z \
  --end-time 2025-10-28T23:59:59Z
```

**View OKE Cluster Metrics**:

```bash
# Node status
kubectl get nodes

# Pod status
kubectl get pods --all-namespaces

# Resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```

### OCI Logging

**List Logs**:

```bash
oci logging log list --log-group-id <log-group-ocid>
```

**View Audit Logs**:

```bash
oci audit event list \
  --compartment-id <compartment-ocid> \
  --start-time 2025-10-28T00:00:00Z \
  --end-time 2025-10-28T23:59:59Z
```

## Cost Monitoring

### Check Always Free Tier Usage

**View Current Resource Usage**:

```bash
# Compute OCPUs (limit: 4)
oci compute instance list \
  --compartment-id <compartment-ocid> \
  --lifecycle-state RUNNING \
  --query 'data[*].{name:"display-name", shape:"shape", ocpus:"shape-config.ocpus", memory:"shape-config"."memory-in-gbs"}' \
  --output table

# Block storage (limit: 200GB)
oci bv volume list \
  --compartment-id <compartment-ocid> \
  --query 'sum(data[*]."size-in-gbs")' \
  --raw-output

# Object storage (limit: 20GB)
oci os bucket list \
  --compartment-id <compartment-ocid> \
  --namespace <namespace> \
  --fields approximateSize
```

**Set Up Budget Alerts**:

```bash
# Create budget (even for $0 usage, good for monitoring)
oci budgets budget create \
  --compartment-id <compartment-ocid> \
  --amount 5 \
  --reset-period MONTHLY \
  --target-type COMPARTMENT \
  --targets '["<compartment-ocid>"]' \
  --display-name "Always Free Budget Alert"
```

### Monitor Unexpected Charges

**View Cost Analysis**:

```bash
oci usage-api usage-summary request-summarized-usages \
  --tenant-id <tenancy-ocid> \
  --time-usage-started 2025-10-01T00:00:00Z \
  --time-usage-ended 2025-10-31T23:59:59Z \
  --granularity MONTHLY
```

## Troubleshooting

### Common Issues

#### 1. Cannot Provision Ampere A1 Instances

**Problem**: "Out of host capacity" error when creating Always Free Arm instances

**Solution**:

```bash
# Try different availability domains
oci iam availability-domain list --compartment-id <tenancy-ocid>

# Try different regions
# us-phoenix-1, us-ashburn-1, eu-frankfurt-1 typically have capacity
```

#### 2. OKE Cluster Nodes NotReady

**Diagnosis**:

```bash
kubectl get nodes
kubectl describe node <node-name>
```

**Common Causes**:

- Network security list blocking traffic
- CNI plugin issues
- Insufficient resources

**Resolution**:

```bash
# Check node logs
kubectl logs -n kube-system <cni-pod-name>

# Restart node (if needed)
oci compute instance action --action RESET --instance-id $INSTANCE_ID

# Wait for node to rejoin
watch kubectl get nodes
```

#### 3. Exceeding Always Free Limits

**Check Limits**:

```bash
# Script to check all limits
#!/bin/bash
echo "=== Always Free Tier Usage ==="
echo ""
echo "Compute OCPUs (limit: 4):"
oci compute instance list \
  --compartment-id <compartment-ocid> \
  --lifecycle-state RUNNING \
  --query 'sum(data[*]."shape-config".ocpus)' \
  --raw-output

echo ""
echo "Memory GB (limit: 24):"
oci compute instance list \
  --compartment-id <compartment-ocid> \
  --lifecycle-state RUNNING \
  --query 'sum(data[*]."shape-config"."memory-in-gbs")' \
  --raw-output

echo ""
echo "Block Storage GB (limit: 200):"
oci bv volume list \
  --compartment-id <compartment-ocid> \
  --query 'sum(data[*]."size-in-gbs")' \
  --raw-output
```

#### 4. kubectl Access Issues

**Problem**: Cannot connect to OKE cluster

**Solution**:

```bash
# Regenerate kubeconfig
oci ce cluster create-kubeconfig \
  --cluster-id $CLUSTER_ID \
  --file ~/.kube/config \
  --region us-phoenix-1 \
  --token-version 2.0.0 \
  --kube-endpoint PUBLIC_ENDPOINT \
  --overwrite

# Test connection
kubectl cluster-info
kubectl get nodes
```

#### 5. Network Connectivity Issues

**Problem**: Pods cannot reach external services

**Diagnosis**:

```bash
# Test from pod
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
# Inside pod:
nslookup google.com
wget -O- http://google.com
```

**Check**:

- Security lists allow outbound traffic
- Route table has default route to Internet Gateway
- Service Gateway configured for OCI services

## Disaster Recovery

### Backup Procedures

**Velero Backup** (OKE cluster state):

```bash
# Install Velero with OCI Object Storage backend
velero backup create cluster-backup-$(date +%Y%m%d) \
  --include-namespaces '*'

# Verify backup
velero backup describe cluster-backup-$(date +%Y%m%d)
```

**Manual Database Backup** (if using Autonomous DB):

```bash
# Autonomous DB has automatic backups (60 days retention)
# Manual backup:
oci db autonomous-database create-backup \
  --autonomous-database-id <adb-ocid> \
  --display-name "manual-backup-$(date +%Y%m%d)"
```

### Restore Procedures

**Cluster Restore from Velero**:

```bash
# List backups
velero backup get

# Restore from backup
velero restore create --from-backup cluster-backup-20251028

# Monitor restore
velero restore describe <restore-name>
```

### Failover to DigitalOcean

**Prerequisites**:

- DigitalOcean DOKS cluster provisioned
- Cloudflare DNS configured with health checks

**Procedure**:

1. Verify DigitalOcean cluster ready: `kubectl --context=digitalocean-cluster get nodes`
2. Update Cloudflare DNS to point to DO load balancer
3. Monitor traffic shift via Cloudflare analytics
4. Verify application health in DO environment

## Security Operations

### Rotate API Keys

```bash
# Generate new key pair
openssl genrsa -out ~/.oci/oci_api_key_new.pem 2048
openssl rsa -pubout -in ~/.oci/oci_api_key_new.pem -out ~/.oci/oci_api_key_new_public.pem

# Upload new public key to OCI Console → User Settings → API Keys
# Update ~/.oci/config with new key file and fingerprint
# Test with: oci iam region list
# Delete old key from OCI Console after verification
```

### Review Security Lists

```bash
# List all security lists in VCN
oci network security-list list \
  --compartment-id <compartment-ocid> \
  --vcn-id $VCN_ID \
  --query 'data[*].{id:id, name:"display-name"}' \
  --output table

# Review rules
oci network security-list get --security-list-id <security-list-ocid>
```

## References

- [OCI CLI Command Reference](https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/)
- [OKE Documentation](https://docs.oracle.com/en-us/iaas/Content/ContEng/home.htm)
- [Always Free Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- [ADR-0015: Oracle Cloud as Primary Provider](../decisions/0015-oracle-cloud-primary.md)
- [Oracle Cloud Infrastructure Specification](../../specs/oracle/oracle-cloud-infrastructure.md)

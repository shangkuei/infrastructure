# Runbook: DigitalOcean Operations

## Overview

This runbook provides operational procedures for managing DigitalOcean infrastructure including
DOKS (Kubernetes), Droplets, Databases, Spaces, and networking. All operations follow
infrastructure-as-code principles using Terraform where possible, with manual procedures
documented for emergency situations.

## Prerequisites

- DigitalOcean account with appropriate permissions
- `doctl` CLI installed and configured
- `kubectl` configured for DOKS cluster access
- Terraform installed for infrastructure changes
- Access to GitHub repository with Terraform code

## Authentication Setup

### Install and Configure doctl

```bash
# Install doctl (macOS)
brew install doctl

# Install doctl (Linux)
cd ~
wget https://github.com/digitalocean/doctl/releases/download/v1.98.1/doctl-1.98.1-linux-amd64.tar.gz
tar xf doctl-1.98.1-linux-amd64.tar.gz
sudo mv doctl /usr/local/bin

# Authenticate
doctl auth init
# Enter API token when prompted

# Verify authentication
doctl account get

# Set default context
doctl auth list
```

### Configure kubectl for DOKS

```bash
# Get cluster credentials
doctl kubernetes cluster kubeconfig save production-cluster-nyc3

# Verify access
kubectl cluster-info
kubectl get nodes

# Switch context if needed
kubectl config get-contexts
kubectl config use-context do-nyc3-production-cluster-nyc3
```

## Common Operations

### 1. Deploy or Update DOKS Cluster

**Objective**: Create a new DOKS cluster or update existing cluster configuration.

**Procedure**:

1. **Update Terraform configuration**:

   ```bash
   cd terraform/digitalocean/kubernetes

   # Edit cluster configuration
   vim main.tf
   ```

2. **Review changes**:

   ```bash
   terraform plan -out=tfplan

   # Review output carefully
   # Check for any unexpected changes
   ```

3. **Apply changes**:

   ```bash
   terraform apply tfplan

   # Monitor apply progress
   # Cluster creation takes 5-10 minutes
   # Updates may cause brief disruptions
   ```

4. **Update kubeconfig**:

   ```bash
   doctl kubernetes cluster kubeconfig save production-cluster-nyc3

   # Verify access
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```

5. **Verify cluster health**:

   ```bash
   # Check node status
   kubectl get nodes -o wide

   # Check system pods
   kubectl get pods -n kube-system

   # Check cluster version
   kubectl version
   ```

**Verification**:

- All nodes show `Ready` status
- System pods (coredns, cilium, etc.) running
- Applications remain accessible
- No error logs in cluster events

**Rollback**:

```bash
# If issues occur, rollback Terraform
terraform plan -destroy -target=digitalocean_kubernetes_cluster.production
# Review carefully before applying

# Or revert Git commit and re-apply
git revert HEAD
terraform plan -out=tfplan
terraform apply tfplan
```

---

### 2. Scale Kubernetes Node Pool

**Objective**: Add or remove nodes from the cluster to handle load changes.

**Procedure**:

1. **Update node count in Terraform**:

   ```hcl
   # Edit terraform/digitalocean/kubernetes/main.tf
   resource "digitalocean_kubernetes_cluster" "production" {
     # ... other config ...

     node_pool {
       name       = "production-pool"
       size       = "s-2vcpu-2gb"
       node_count = 5  # Changed from 3 to 5
       # ... other config ...
     }
   }
   ```

2. **Apply changes**:

   ```bash
   terraform plan -out=tfplan
   # Verify only node_count is changing

   terraform apply tfplan
   # Scaling takes 3-5 minutes per node
   ```

3. **Monitor scaling**:

   ```bash
   # Watch nodes being added
   watch kubectl get nodes

   # Check pod distribution
   kubectl get pods -A -o wide

   # Verify new nodes are ready
   kubectl describe node <new-node-name>
   ```

**Verification**:

```bash
# Verify node count
kubectl get nodes | wc -l

# Check node resources
kubectl top nodes

# Verify pod distribution across nodes
kubectl get pods -A -o wide | grep <new-node-name>
```

**Best Practices**:

- Scale up during low-traffic periods
- Scale down gradually (1 node at a time)
- Ensure PodDisruptionBudgets are configured
- Monitor application performance after scaling

**Rollback**:

```bash
# Scale back down by reverting node_count
# Kubernetes will drain nodes gracefully
terraform apply -auto-approve
```

---

### 3. Upgrade Kubernetes Cluster Version

**Objective**: Upgrade DOKS cluster to a newer Kubernetes version.

**Procedure**:

1. **Check available versions**:

   ```bash
   doctl kubernetes options versions
   ```

2. **Review upgrade path**:

   ```bash
   # Check current version
   kubectl version --short

   # Review Kubernetes changelog
   # Ensure applications are compatible with new version
   ```

3. **Update Terraform configuration**:

   ```hcl
   resource "digitalocean_kubernetes_cluster" "production" {
     version = "1.29.1-do.0"  # Updated version
     # ... other config ...
   }
   ```

4. **Plan and apply**:

   ```bash
   terraform plan -out=tfplan
   # Review changes carefully

   terraform apply tfplan
   # Upgrade is rolling, takes 15-30 minutes
   ```

5. **Monitor upgrade**:

   ```bash
   # Watch nodes during upgrade
   watch kubectl get nodes

   # Check pod disruptions
   kubectl get events --all-namespaces --watch

   # Verify system components
   kubectl get pods -n kube-system
   ```

6. **Verify applications**:

   ```bash
   # Check application pods
   kubectl get pods -A

   # Test critical endpoints
   curl -I https://example.com

   # Review logs for errors
   kubectl logs -n production deployment/app
   ```

**Verification**:

- All nodes on new version
- All pods running correctly
- Applications accessible
- No errors in logs

**Rollback**:

- Kubernetes upgrades cannot be easily rolled back
- Restore from backup if critical issues
- Plan carefully and test in staging first

**Best Practices**:

- Upgrade during maintenance window
- Test in non-production environment first
- Review breaking changes in Kubernetes release notes
- Backup cluster state before upgrade (Velero)
- Notify team of upgrade schedule

---

### 4. Manage Database Cluster

**Objective**: Create, configure, and maintain DigitalOcean managed PostgreSQL database.

**Procedure**:

#### Create Database Cluster

```bash
# Via Terraform (recommended)
cd terraform/digitalocean/database

vim main.tf
# Configure database settings

terraform plan -out=tfplan
terraform apply tfplan
```

#### Scale Database (Vertical Scaling)

```bash
# Update database size in Terraform
resource "digitalocean_database_cluster" "postgres" {
  size = "db-s-2vcpu-2gb"  # Upgraded from db-s-1vcpu-1gb
  # ... other config ...
}

terraform apply
# Scaling causes brief connection interruption
```

#### Add Read Replica (Horizontal Scaling)

```bash
# Update Terraform configuration
resource "digitalocean_database_cluster" "postgres" {
  node_count = 2  # Adds standby/replica
  # ... other config ...
}

terraform apply
```

#### Configure Connection Pool

```bash
# Connection pooling is built-in (PgBouncer)
# Access via pool connection string

# Get connection details
doctl databases connection production-postgres

# Use pool string in application
# Format: postgresql://user:pass@host:port/db?sslmode=require
```

#### Backup and Restore

```bash
# Automated backups are enabled by default

# List backups
doctl databases backups list production-postgres

# Restore from backup (creates new cluster)
doctl databases restore production-postgres --backup-id <backup-id>

# Manual backup (snapshot)
doctl databases backup production-postgres
```

#### Database Maintenance

```bash
# View maintenance window
doctl databases maintenance-window get production-postgres

# Update maintenance window
doctl databases maintenance-window update production-postgres \
  --day tuesday \
  --hour 03:00

# Pending maintenance (view)
doctl databases maintenance-window get production-postgres
```

**Verification**:

```bash
# Test connection
psql "postgresql://user:pass@host:25060/db?sslmode=require"

# Check database size
SELECT pg_size_pretty(pg_database_size('your_database'));

# Check connection count
SELECT count(*) FROM pg_stat_activity;

# Verify replication (if HA enabled)
SELECT * FROM pg_stat_replication;
```

**Troubleshooting**:

- **Connection timeout**: Check firewall rules, VPC configuration
- **Too many connections**: Use connection pooling, increase max connections
- **Slow queries**: Review query performance, add indexes
- **High CPU**: Consider scaling up, optimize queries

---

### 5. Manage Spaces (Object Storage)

**Objective**: Create and manage S3-compatible object storage for state files, backups, and application data.

**Procedure**:

#### Create Space

```bash
# Via Terraform (recommended)
resource "digitalocean_spaces_bucket" "example" {
  name   = "example-bucket-nyc3"
  region = "nyc3"
  acl    = "private"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    enabled = true
    expiration {
      days = 90
    }
  }
}
```

#### Upload Files

```bash
# Using s3cmd
s3cmd put file.txt s3://example-bucket-nyc3/

# Using AWS CLI (with DO endpoint)
aws s3 cp file.txt s3://example-bucket-nyc3/ \
  --endpoint-url https://nyc3.digitaloceanspaces.com

# Sync directory
aws s3 sync ./local-dir s3://example-bucket-nyc3/remote-dir/ \
  --endpoint-url https://nyc3.digitaloceanspaces.com
```

#### Configure CORS

```bash
# Via Terraform
resource "digitalocean_spaces_bucket" "example" {
  # ... other config ...

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["https://example.com"]
    max_age_seconds = 3600
  }
}
```

#### Enable CDN

```bash
# Via Terraform
resource "digitalocean_cdn" "example" {
  origin = digitalocean_spaces_bucket.example.bucket_domain_name
}

# Get CDN endpoint
output "cdn_endpoint" {
  value = digitalocean_cdn.example.endpoint
}
```

#### Lifecycle Management

```bash
# Configure lifecycle rules in Terraform
lifecycle_rule {
  enabled = true

  # Delete old versions after 30 days
  noncurrent_version_expiration {
    days = 30
  }

  # Move to glacier after 90 days (not available on DO)
  # Delete after 365 days
  expiration {
    days = 365
  }
}
```

#### Access Control

```bash
# Generate access key
doctl compute spaces access create

# Revoke access key
doctl compute spaces access revoke <access-key-id>

# List access keys
doctl compute spaces access list
```

**Verification**:

```bash
# List buckets
aws s3 ls --endpoint-url https://nyc3.digitaloceanspaces.com

# Check bucket size
aws s3 ls s3://example-bucket-nyc3/ --recursive --summarize \
  --endpoint-url https://nyc3.digitaloceanspaces.com

# Test public access (if ACL is public)
curl -I https://example-bucket-nyc3.nyc3.digitaloceanspaces.com/test.txt
```

---

### 6. Manage Load Balancers

**Objective**: Configure and manage DigitalOcean Load Balancers for Kubernetes services.

**Procedure**:

#### Create Load Balancer (via Kubernetes)

```yaml
# Load balancer created automatically with Service type: LoadBalancer
apiVersion: v1
kind: Service
metadata:
  name: web-service
  annotations:
    service.beta.kubernetes.io/do-loadbalancer-protocol: "http"
    service.beta.kubernetes.io/do-loadbalancer-algorithm: "round_robin"
    service.beta.kubernetes.io/do-loadbalancer-healthcheck-port: "80"
    service.beta.kubernetes.io/do-loadbalancer-healthcheck-protocol: "http"
    service.beta.kubernetes.io/do-loadbalancer-healthcheck-path: "/health"
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 8080
  selector:
    app: web
```

#### Configure SSL/TLS Termination

```yaml
# Add annotations for SSL termination
annotations:
  service.beta.kubernetes.io/do-loadbalancer-protocol: "http"
  service.beta.kubernetes.io/do-loadbalancer-tls-ports: "443"
  service.beta.kubernetes.io/do-loadbalancer-certificate-id: "cert-id-from-do"
  service.beta.kubernetes.io/do-loadbalancer-redirect-http-to-https: "true"
```

#### Enable Proxy Protocol

```yaml
annotations:
  service.beta.kubernetes.io/do-loadbalancer-enable-proxy-protocol: "true"
```

#### Configure Health Checks

```yaml
annotations:
  service.beta.kubernetes.io/do-loadbalancer-healthcheck-protocol: "http"
  service.beta.kubernetes.io/do-loadbalancer-healthcheck-port: "80"
  service.beta.kubernetes.io/do-loadbalancer-healthcheck-path: "/healthz"
  service.beta.kubernetes.io/do-loadbalancer-healthcheck-interval-seconds: "10"
  service.beta.kubernetes.io/do-loadbalancer-healthcheck-timeout-seconds: "5"
  service.beta.kubernetes.io/do-loadbalancer-healthcheck-unhealthy-threshold: "3"
  service.beta.kubernetes.io/do-loadbalancer-healthcheck-healthy-threshold: "2"
```

#### View Load Balancer Details

```bash
# List load balancers
doctl compute load-balancer list

# Get load balancer details
doctl compute load-balancer get <lb-id>

# Check load balancer health
kubectl get svc web-service

# View load balancer IP
kubectl get svc web-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

**Verification**:

```bash
# Test load balancer
LB_IP=$(kubectl get svc web-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$LB_IP

# Check health status
doctl compute load-balancer get <lb-id> --format Status

# Verify SSL (if configured)
curl -I https://$LB_IP
```

**Troubleshooting**:

- **No external IP**: Check service type is LoadBalancer
- **Health check failing**: Verify health endpoint returns 200 OK
- **SSL errors**: Verify certificate ID is correct
- **Connection timeout**: Check firewall rules, security groups

---

### 7. Configure VPC and Networking

**Objective**: Set up and manage Virtual Private Cloud for private networking.

**Procedure**:

#### Create VPC

```bash
# Via Terraform (recommended)
resource "digitalocean_vpc" "production" {
  name     = "production-vpc-nyc3"
  region   = "nyc3"
  ip_range = "10.100.0.0/16"
}

terraform apply
```

#### Assign Resources to VPC

```bash
# DOKS cluster
resource "digitalocean_kubernetes_cluster" "production" {
  # ... other config ...
  vpc_uuid = digitalocean_vpc.production.id
}

# Database
resource "digitalocean_database_cluster" "postgres" {
  # ... other config ...
  private_network_uuid = digitalocean_vpc.production.id
}
```

#### View VPC Details

```bash
# List VPCs
doctl vpcs list

# Get VPC details
doctl vpcs get <vpc-id>

# List resources in VPC
doctl vpcs members <vpc-id>
```

**Verification**:

```bash
# Test private network connectivity
# From a pod in the cluster
kubectl run test-pod --rm -it --image=busybox -- sh
# Inside pod:
ping <database-private-ip>
```

---

### 8. Manage Firewall Rules

**Objective**: Configure Cloud Firewalls to control network access.

**Procedure**:

#### Create Firewall

```bash
# Via Terraform
resource "digitalocean_firewall" "kubernetes" {
  name = "kubernetes-firewall"

  tags = ["kubernetes"]

  # Allow HTTP/HTTPS from anywhere
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Allow SSH from specific IPs only
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["YOUR_IP/32"]
  }

  # Allow Kubernetes node-to-node traffic
  inbound_rule {
    protocol    = "tcp"
    port_range  = "1-65535"
    source_tags = ["kubernetes"]
  }

  # Allow all outbound
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
```

#### Update Firewall Rules

```bash
# Edit Terraform configuration
# Add or modify inbound_rule or outbound_rule blocks

terraform plan
terraform apply

# Changes are applied immediately
```

#### View Firewall Rules

```bash
# List firewalls
doctl compute firewall list

# Get firewall details
doctl compute firewall get <firewall-id>

# List resources protected by firewall
doctl compute firewall get <firewall-id> --format Droplets,Tags
```

**Verification**:

```bash
# Test allowed traffic
curl http://<droplet-ip>

# Test blocked traffic (should timeout)
telnet <droplet-ip> 3306

# Check firewall logs (if enabled)
doctl compute firewall list-records <firewall-id>
```

---

### 9. Monitor and Troubleshoot

**Objective**: Monitor DigitalOcean infrastructure health and troubleshoot issues.

**Monitoring Commands**:

```bash
# Check cluster health
kubectl get nodes
kubectl get pods -A
kubectl top nodes
kubectl top pods -A

# Check database health
doctl databases get production-postgres
doctl databases connection production-postgres

# Check load balancer health
doctl compute load-balancer list

# Check Spaces usage
aws s3 ls --endpoint-url https://nyc3.digitaloceanspaces.com \
  --recursive --summarize

# View account usage
doctl account get

# Check billing
doctl invoice list
```

**Common Issues**:

| Issue | Diagnosis | Solution |
|-------|-----------|----------|
| **Node NotReady** | `kubectl describe node` | Check node events, restart if needed |
| **Pod CrashLoopBackOff** | `kubectl logs <pod>` | Fix application error, check resource limits |
| **Database connection failed** | Check firewall, VPC | Verify database is in same VPC, firewall allows traffic |
| **LoadBalancer pending** | `kubectl describe svc` | Check for errors, verify cluster has capacity |
| **High costs** | Review billing | Check for unused resources, optimize node sizes |
| **Slow performance** | `kubectl top nodes/pods` | Scale up, optimize applications |

**Debug Commands**:

```bash
# Get cluster events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Check pod logs
kubectl logs <pod-name> -n <namespace> --tail=100

# Describe pod for details
kubectl describe pod <pod-name> -n <namespace>

# Check database logs
doctl databases logs production-postgres

# Check load balancer forwarding rules
doctl compute load-balancer get <lb-id> --format ForwardingRules

# Test database connection
psql "postgresql://user:pass@host:25060/db?sslmode=require" -c "SELECT version();"
```

---

## Emergency Procedures

### Cluster Failure

**Scenario**: DOKS cluster is unresponsive or unhealthy.

**Procedure**:

1. **Check DigitalOcean status page**:

   ```bash
   # Visit https://status.digitalocean.com/
   ```

2. **Verify cluster access**:

   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```

3. **Check node health**:

   ```bash
   doctl kubernetes cluster list
   doctl kubernetes cluster get production-cluster-nyc3
   ```

4. **If nodes are down, check events**:

   ```bash
   kubectl get events -A --sort-by='.lastTimestamp'
   ```

5. **Restart unhealthy nodes** (if needed):

   ```bash
   # Via DigitalOcean console or API
   doctl compute droplet-action reboot <droplet-id>
   ```

6. **If cluster is completely down, restore from backup**:

   ```bash
   # See disaster recovery runbook
   ```

7. **Failover to on-premise cluster** (if configured):

   ```bash
   # Update Cloudflare DNS to point to on-premise
   # See hybrid failover runbook
   ```

### Database Failure

**Scenario**: PostgreSQL database is down or inaccessible.

**Procedure**:

1. **Check database status**:

   ```bash
   doctl databases get production-postgres
   ```

2. **Check connection**:

   ```bash
   psql "postgresql://user:pass@host:25060/db?sslmode=require"
   ```

3. **If HA enabled, check failover status**:

   ```bash
   doctl databases get production-postgres --format Status,NumNodes
   ```

4. **Review database logs**:

   ```bash
   doctl databases logs production-postgres
   ```

5. **If database is corrupted, restore from backup**:

   ```bash
   doctl databases backups list production-postgres
   doctl databases restore production-postgres --backup-id <backup-id>
   ```

6. **Update application connection string** (if restored to new cluster):

   ```bash
   kubectl edit secret database-credentials -n production
   ```

### High Costs Alert

**Scenario**: Unexpected increase in DigitalOcean costs.

**Procedure**:

1. **Review current month costs**:

   ```bash
   doctl invoice list
   doctl invoice get <invoice-id>
   ```

2. **Check resource usage**:

   ```bash
   # List all droplets
   doctl compute droplet list

   # List all load balancers
   doctl compute load-balancer list

   # List all databases
   doctl databases list

   # Check Spaces usage
   doctl compute spaces list
   ```

3. **Identify expensive resources**:

   ```bash
   # Look for:
   # - Unused load balancers
   # - Over-sized droplets/databases
   # - Excessive bandwidth usage
   # - Large Spaces storage
   ```

4. **Take corrective action**:

   ```bash
   # Scale down resources
   # Delete unused resources
   # Optimize Spaces storage (lifecycle policies)
   ```

5. **Set up billing alerts**:

   ```bash
   # Configure alerts in DigitalOcean console
   # Settings > Billing > Alerts
   ```

---

## Maintenance Procedures

### Regular Maintenance (Monthly)

- [ ] Review and optimize resource usage
- [ ] Check for available Kubernetes upgrades
- [ ] Review database performance metrics
- [ ] Clean up old Spaces objects (if not automated)
- [ ] Review firewall rules for accuracy
- [ ] Check backup success rate
- [ ] Review access logs for anomalies

### Quarterly Maintenance

- [ ] Rotate API tokens and credentials
- [ ] Review and update documentation
- [ ] Test disaster recovery procedures
- [ ] Audit cost optimization opportunities
- [ ] Review security configurations
- [ ] Update runbooks based on lessons learned

### Annual Maintenance

- [ ] Comprehensive security audit
- [ ] Review and renew SSL certificates (if manual)
- [ ] Evaluate new DigitalOcean features
- [ ] Review architecture for improvements
- [ ] Update disaster recovery plan

---

## References

- [DigitalOcean Documentation](https://docs.digitalocean.com/)
- [doctl CLI Reference](https://docs.digitalocean.com/reference/doctl/)
- [DOKS Documentation](https://docs.digitalocean.com/products/kubernetes/)
- [Managed Databases](https://docs.digitalocean.com/products/databases/)
- [Spaces Documentation](https://docs.digitalocean.com/products/spaces/)
- [Load Balancer Documentation](https://docs.digitalocean.com/products/networking/load-balancers/)
- [ADR-0013: DigitalOcean as Primary Cloud Provider](../decisions/0013-digitalocean-primary-cloud.md)
- [Architecture: DigitalOcean Infrastructure](../architecture/0002-digitalocean-infrastructure.md)

---

**Last Updated**: 2025-10-21
**Maintained By**: Infrastructure Team
**Review Frequency**: Quarterly

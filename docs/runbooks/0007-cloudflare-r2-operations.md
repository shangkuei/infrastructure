# Runbook: Cloudflare R2 Operations

**Version**: 1.0
**Last Updated**: 2025-10-28
**Owner**: Infrastructure Team
**Purpose**: Operational procedures for Cloudflare R2 Terraform state storage

## Overview

This runbook covers operational procedures for managing Terraform state storage in Cloudflare R2, including setup, backup, recovery, and troubleshooting.

**Service**: Cloudflare R2 Object Storage
**Primary Use**: Terraform state file storage with native locking
**Backend Type**: S3-compatible with `use_lockfile` parameter

## Prerequisites

- Cloudflare account with R2 access
- Terraform v1.11 or later installed
- AWS CLI or S3-compatible CLI tool (optional, for manual operations)
- Access to GitHub repository secrets (for CI/CD)

## Initial Setup

### Step 1: Create R2 Bucket

**Via Cloudflare Dashboard**:

1. Log in to Cloudflare Dashboard
2. Navigate to R2 Object Storage
3. Click "Create bucket"
4. **Bucket name**: `terraform-state`
5. **Location**: Automatic (global distribution)
6. **Public access**: Disabled (keep private)
7. Click "Create bucket"

**Via Wrangler CLI** (alternative):

```bash
# Install Wrangler
npm install -g wrangler

# Authenticate
wrangler login

# Create bucket
wrangler r2 bucket create terraform-state
```

### Step 2: Enable Versioning

**Via Cloudflare Dashboard**:

1. Navigate to R2 → terraform-state bucket
2. Settings → Versioning
3. Enable versioning
4. Configure retention: 90 days (or as needed)

**Note**: Versioning is enabled by default for R2 buckets.

### Step 3: Generate R2 API Tokens

**Via Cloudflare Dashboard**:

1. Navigate to R2 → Manage R2 API Tokens
2. Click "Create API token"
3. **Token name**: `terraform-state-access`
4. **Permissions**:
   - Object Read
   - Object Write
5. **TTL**: No expiration (rotate manually quarterly)
6. **Bucket restrictions**: terraform-state only
7. Click "Create API Token"
8. **Save credentials** (shown only once):
   - Access Key ID
   - Secret Access Key
   - Endpoint URL

### Step 4: Configure Local Environment

**Set environment variables**:

```bash
# Add to ~/.bashrc or ~/.zshrc
export AWS_ACCESS_KEY_ID="<R2_ACCESS_KEY_ID>"
export AWS_SECRET_ACCESS_KEY="<R2_SECRET_ACCESS_KEY>"
export AWS_ENDPOINT_URL_S3="https://<ACCOUNT_ID>.r2.cloudflarestorage.com"

# Or create a secure credential file
mkdir -p ~/.aws
cat > ~/.aws/credentials << EOF
[r2]
aws_access_key_id = <R2_ACCESS_KEY_ID>
aws_secret_access_key = <R2_SECRET_ACCESS_KEY>
EOF
```

### Step 5: Configure GitHub Secrets

**For CI/CD pipelines**:

```bash
# Set GitHub repository secrets
gh secret set R2_ACCESS_KEY_ID
gh secret set R2_SECRET_ACCESS_KEY
gh secret set R2_ACCOUNT_ID  # For endpoint construction
```

### Step 6: Create Backend Configuration

**Create `backend.tf`** in each environment directory:

```hcl
# environments/dev/backend.tf
terraform {
  required_version = "~> 1.11"

  backend "s3" {
    endpoints = {
      s3 = "https://<ACCOUNT_ID>.r2.cloudflarestorage.com"
    }

    bucket = "terraform-state"
    key    = "environments/dev/terraform.tfstate"
    region = "auto"

    use_lockfile = true

    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
```

### Step 7: Initialize Terraform

```bash
# Navigate to environment directory
cd environments/dev

# Initialize with new backend
terraform init

# Verify backend configuration
terraform show

# Test state locking
terraform plan
```

## Migration from Local State

### Pre-Migration Checklist

- [ ] Backup local state file: `cp terraform.tfstate terraform.tfstate.backup`
- [ ] Verify R2 bucket is created and accessible
- [ ] Confirm environment variables are set correctly
- [ ] No pending Terraform operations in progress
- [ ] Team members notified of migration window

### Migration Procedure

**Step 1: Backup current state**

```bash
# Create timestamped backup
cp terraform.tfstate terraform.tfstate.$(date +%Y%m%d_%H%M%S)

# Verify backup
ls -lh terraform.tfstate*
```

**Step 2: Add backend configuration**

```bash
# Add backend.tf with R2 configuration (see above)
vim backend.tf
```

**Step 3: Initialize and migrate**

```bash
# Initialize with backend migration
terraform init -migrate-state

# Terraform will prompt:
# "Do you want to copy existing state to the new backend?"
# Type: yes

# Verify migration
terraform state list
```

**Step 4: Verify remote state**

```bash
# Check state is in R2
aws s3 ls s3://terraform-state/environments/dev/ \
  --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com

# Pull state to verify
terraform state pull > /tmp/verify-state.json
cat /tmp/verify-state.json | jq '.version'
rm /tmp/verify-state.json
```

**Step 5: Test state locking**

```bash
# Terminal 1: Start a long-running operation
terraform plan

# Terminal 2: Try to run concurrent operation
terraform plan
# Should see: "Error: Error acquiring the state lock"

# Verify lock file created
aws s3 ls s3://terraform-state/environments/dev/ \
  --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com
```

**Step 6: Cleanup local state**

```bash
# Archive local state (do not delete immediately)
mkdir -p ~/.terraform-state-backups/$(date +%Y%m)
mv terraform.tfstate* ~/.terraform-state-backups/$(date +%Y%m)/

# Update .gitignore to ensure state files never committed
echo "terraform.tfstate*" >> .gitignore
```

## Backup and Recovery

### Automated Backup Strategy

**Daily State Export** (recommended):

```bash
#!/bin/bash
# scripts/backup-terraform-state.sh

BACKUP_DIR="/backup/terraform-state"
DATE=$(date +%Y%m%d)
ENVIRONMENTS=("dev" "staging" "production")

for env in "${ENVIRONMENTS[@]}"; do
  echo "Backing up $env state..."

  cd "environments/$env"
  terraform state pull > "$BACKUP_DIR/$env-$DATE.tfstate"

  # Compress and encrypt
  gzip "$BACKUP_DIR/$env-$DATE.tfstate"

  # Optional: Upload to secondary backup location
  # aws s3 cp "$BACKUP_DIR/$env-$DATE.tfstate.gz" \
  #   s3://backup-bucket/terraform-state/$env/
done

# Cleanup old backups (keep 90 days)
find "$BACKUP_DIR" -name "*.tfstate.gz" -mtime +90 -delete
```

**Schedule via cron**:

```bash
# Run daily at 2 AM
0 2 * * * /path/to/scripts/backup-terraform-state.sh
```

### Manual Backup

**Export current state**:

```bash
# Pull and save state
terraform state pull > terraform.tfstate.$(date +%Y%m%d_%H%M%S)

# Verify backup
ls -lh terraform.tfstate.*
```

**Export all state versions from R2**:

```bash
# List all versions
aws s3api list-object-versions \
  --bucket terraform-state \
  --prefix environments/production/terraform.tfstate \
  --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com

# Download specific version
aws s3api get-object \
  --bucket terraform-state \
  --key environments/production/terraform.tfstate \
  --version-id <VERSION_ID> \
  --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com \
  terraform.tfstate.version-<VERSION_ID>
```

### Recovery Procedures

**Scenario 1: Recover from accidental deletion**

```bash
# List recent versions
aws s3api list-object-versions \
  --bucket terraform-state \
  --prefix environments/production/terraform.tfstate \
  --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com \
  --max-items 10

# Restore specific version (copy over current)
aws s3api copy-object \
  --bucket terraform-state \
  --copy-source terraform-state/environments/production/terraform.tfstate?versionId=<VERSION_ID> \
  --key environments/production/terraform.tfstate \
  --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com

# Verify restoration
terraform state pull | head -20
```

**Scenario 2: Restore from daily backup**

```bash
# Find appropriate backup
ls -lt /backup/terraform-state/production-*.tfstate.gz | head -5

# Extract backup
gunzip /backup/terraform-state/production-20251027.tfstate.gz

# Push to R2 (careful!)
terraform state push /backup/terraform-state/production-20251027.tfstate

# Verify restoration
terraform state list
```

**Scenario 3: Rebuild state from infrastructure**

```bash
# Only as last resort when no backups available
# Import existing resources one by one

# Example: Import VPC
terraform import digitalocean_vpc.main <vpc-id>

# Example: Import Kubernetes cluster
terraform import digitalocean_kubernetes_cluster.main <cluster-id>

# Verify imported resources
terraform plan  # Should show minimal or no changes
```

## Monitoring and Maintenance

### Health Checks

**Daily health check script**:

```bash
#!/bin/bash
# scripts/check-r2-health.sh

# Check bucket accessibility
aws s3 ls s3://terraform-state/ \
  --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com > /dev/null

if [ $? -eq 0 ]; then
  echo "✓ R2 bucket accessible"
else
  echo "✗ R2 bucket inaccessible"
  # Send alert
fi

# Check state file sizes
ENVS=("dev" "staging" "production")
for env in "${ENVS[@]}"; do
  SIZE=$(aws s3 ls s3://terraform-state/environments/$env/terraform.tfstate \
    --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com | awk '{print $3}')
  echo "$env state size: $SIZE bytes"

  # Alert if state file too large (>10MB)
  if [ "$SIZE" -gt 10485760 ]; then
    echo "⚠ Warning: $env state file larger than 10MB"
  fi
done
```

### Metrics to Monitor

**Storage Metrics**:

- State file sizes (should be <1MB typically)
- Total storage usage (should be well under 10GB free tier)
- Number of state files

**Operation Metrics**:

- State read operations per month
- State write operations per month
- Lock acquisition failures
- Average state pull/push latency

**Access Logs**: Review in Cloudflare Dashboard → R2 → terraform-state → Logs

### Maintenance Tasks

**Monthly**:

- Review state file sizes for anomalies
- Check backup automation is running
- Verify state locking is working
- Review access logs for unusual activity

**Quarterly**:

- Rotate R2 API tokens
- Review and cleanup old state versions (if not auto-expired)
- Test disaster recovery procedures
- Update documentation

**Annually**:

- Review R2 usage vs. free tier limits
- Evaluate cost optimization opportunities
- Update runbook based on operational experience

## Troubleshooting

### Issue: State Lock Timeout

**Symptoms**:

```
Error: Error acquiring the state lock
Lock Info:
  ID: <lock-id>
  Path: environments/dev/terraform.tfstate
  Operation: OperationTypePlan
  Who: user@hostname
  Version: 1.11.0
  Created: 2025-10-28 10:30:00
```

**Root Causes**:

- Previous Terraform operation crashed or was interrupted
- Lock file not properly released
- Concurrent operations attempted

**Resolution**:

```bash
# 1. Check if lock is stale (older than expected)
aws s3api head-object \
  --bucket terraform-state \
  --key environments/dev/.terraform.tfstate.lock \
  --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com

# 2. Verify no active Terraform operations
ps aux | grep terraform

# 3. Force unlock if confirmed stale
terraform force-unlock <lock-id>

# 4. Verify lock removed
terraform plan
```

### Issue: State File Not Found

**Symptoms**:

```
Error: Failed to get existing workspaces: no such bucket
```

**Root Causes**:

- Incorrect bucket name
- Wrong R2 endpoint
- Invalid credentials
- Bucket not created

**Resolution**:

```bash
# 1. Verify bucket exists
aws s3 ls --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com

# 2. Check credentials
env | grep AWS

# 3. Verify endpoint URL
echo $AWS_ENDPOINT_URL_S3

# 4. Test S3 access
aws s3 ls s3://terraform-state/ \
  --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com

# 5. Re-initialize if needed
terraform init -reconfigure
```

### Issue: State Divergence

**Symptoms**:

- Terraform plan shows unexpected changes
- Resources show as needing replacement
- State doesn't match actual infrastructure

**Root Causes**:

- Manual infrastructure changes outside Terraform
- State corruption
- Incorrect state file restored

**Resolution**:

```bash
# 1. Compare state to actual infrastructure
terraform plan -detailed-exitcode

# 2. Refresh state from actual infrastructure
terraform apply -refresh-only

# 3. If severe divergence, import missing resources
terraform import <resource-type>.<resource-name> <resource-id>

# 4. Consider restoring from known good backup
# (see Recovery Procedures above)
```

### Issue: Slow State Operations

**Symptoms**:

- terraform plan/apply takes unusually long to start
- State pull/push slow (>5 seconds)

**Root Causes**:

- Network latency to R2
- Large state file size
- R2 service degradation

**Resolution**:

```bash
# 1. Check network connectivity
ping <ACCOUNT_ID>.r2.cloudflarestorage.com

# 2. Check state file size
aws s3 ls s3://terraform-state/environments/production/ \
  --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com \
  --human-readable

# 3. If state file too large (>10MB), consider splitting
# - Use separate state files per major component
# - Use Terraform workspaces
# - Use remote state data sources

# 4. Check Cloudflare status
curl https://www.cloudflarestatus.com/api/v2/status.json | jq
```

### Issue: Access Denied

**Symptoms**:

```
Error: error configuring S3 Backend: AccessDenied
```

**Root Causes**:

- Invalid credentials
- Expired R2 API token
- Insufficient permissions
- Incorrect endpoint

**Resolution**:

```bash
# 1. Verify credentials are set
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY  # Should show masked

# 2. Test credentials directly
aws s3 ls s3://terraform-state/ \
  --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com

# 3. Regenerate R2 API token (see Setup Step 3)

# 4. Update GitHub Secrets if using CI/CD
gh secret set R2_ACCESS_KEY_ID
gh secret set R2_SECRET_ACCESS_KEY
```

## Security Procedures

### Token Rotation

**Quarterly rotation**:

1. Generate new R2 API token (see Setup Step 3)
2. Update local environment variables
3. Update GitHub Secrets
4. Test access with new credentials
5. Delete old API token in Cloudflare dashboard
6. Document rotation in change log

### Incident Response

**If credentials compromised**:

1. **Immediately revoke** compromised API token in Cloudflare dashboard
2. **Generate new** R2 API token
3. **Update** all environments (local + CI/CD)
4. **Review** R2 access logs for suspicious activity
5. **Verify** state file integrity
6. **Document** incident and remediation

**If unauthorized state changes detected**:

1. **Stop** all Terraform operations
2. **Restore** state from last known good backup
3. **Investigate** access logs
4. **Rotate** API tokens
5. **Review** IAM and access controls
6. **Update** security procedures

## Related Documentation

- [ADR-0014: Cloudflare R2 for Terraform State Storage](../decisions/0014-cloudflare-r2-terraform-state.md)
- [Cloudflare Services Specification](../../specs/cloudflare/cloudflare-services.md)
- [Terraform README](../../terraform/README.md)
- [Research-0018: Terraform State Management](../research/0018-terraform-state-management.md)
- [Disaster Recovery Runbook](0003-disaster-recovery.md)

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-28 | Infrastructure Team | Initial R2 operations runbook |

# 14. Cloudflare R2 for Terraform State Storage

Date: 2025-10-28

## Status

Accepted

## Context

Following [ADR-0002: Terraform as Primary IaC Tool](0002-terraform-primary-tool.md), we need to select a remote backend for storing Terraform state files that enables team collaboration and state locking.

[Research-0018: Terraform State Management](../research/0018-terraform-state-management.md) evaluated multiple options including DigitalOcean Spaces, Cloudflare R2, Terraform Cloud, and AWS S3+DynamoDB.

For a small company infrastructure project, we need a state backend that is:

- **Cost-effective**: Minimal or zero cost for small-scale use
- **Secure**: Encryption at rest and in transit
- **Collaborative**: Supports state locking to prevent conflicts
- **Reliable**: High durability and availability
- **Simple**: Easy to set up and maintain
- **S3-compatible**: Standard Terraform S3 backend

## Decision

We will use **Cloudflare R2** as our Terraform state backend for all environments.

Specifically:

- Terraform state will be stored in Cloudflare R2 buckets
- Native state locking via `use_lockfile` parameter (Terraform v1.10+)
- Separate state files for each environment (dev/staging/production)
- Versioning enabled for state recovery
- R2 API tokens with least-privilege access
- State files organized by environment: `environments/{env}/terraform.tfstate`

### Configuration Example

```hcl
# backend.tf
terraform {
  required_version = "~> 1.11"

  backend "s3" {
    # Cloudflare R2 endpoint
    endpoints = {
      s3 = "https://<ACCOUNT_ID>.r2.cloudflarestorage.com"
    }

    bucket = "terraform-state"
    key    = "environments/production/terraform.tfstate"
    region = "auto"  # Required but ignored by R2

    # Enable native state locking (Terraform v1.10+)
    use_lockfile = true

    # Disable AWS-specific features
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
```

## Consequences

### Positive

- **Zero cost**: R2 free tier (10GB storage) covers all state files
- **Zero egress fees**: Unlimited data transfer at no cost
- **Native state locking**: Prevents concurrent modifications without DynamoDB
- **High reliability**: Built on Cloudflare's global network
- **Simple setup**: Single service for state storage and locking
- **Versioning included**: State history and rollback capability
- **Encryption included**: At rest and in transit
- **Global performance**: Fast access from anywhere via Cloudflare's edge network
- **No resource limits**: Unlike Terraform Cloud free tier (500 resources)
- **Cloudflare alignment**: Complements existing Cloudflare DNS/CDN usage

### Negative

- **Multi-cloud dependency**: Introduces Cloudflare in addition to DigitalOcean
- **Best effort S3 compatibility**: Not officially tested by HashiCorp (same as DO Spaces)
- **Requires Terraform 1.10+**: For native locking support
- **Less ecosystem alignment**: Not DigitalOcean-native like Spaces would be
- **Community support**: Fewer documented examples than AWS S3 or Terraform Cloud

### Mitigation Strategies

**Multi-cloud dependency**:

- Acceptable trade-off for zero cost and zero egress
- We already use Cloudflare for DNS and CDN services
- State files are small and can be migrated to another backend if needed

**S3 compatibility concerns**:

- R2 conditional writes confirmed working with Terraform 1.10+
- Tested configuration available in community documentation
- Fallback to DigitalOcean Spaces or Terraform Cloud if issues arise

**Version requirement**:

- Pin Terraform to 1.11+ in all environments
- Enforce version in CI/CD pipelines
- Document version requirement in setup guides

## Alternatives Considered

### DigitalOcean Spaces

**Description**: S3-compatible object storage from DigitalOcean

**Why not chosen**:

- Cost: $5/month flat rate vs. free for R2
- Ecosystem alignment advantage doesn't outweigh cost savings
- R2 offers zero egress fees (DO Spaces charges after 1TB)
- Similar "best effort" S3 compatibility status

**Trade-offs**: Ecosystem alignment vs. cost optimization

### Terraform Cloud (Free Tier)

**Description**: HashiCorp's managed Terraform service

**Why not chosen**:

- Free tier limited to 500 resources (restrictive)
- Vendor lock-in to HashiCorp ecosystem
- Remote execution overhead adds latency
- Requires internet connectivity for all operations
- We prefer self-managed solution with more control

**Trade-offs**: Managed service convenience vs. control and cost flexibility

### AWS S3 + DynamoDB

**Description**: AWS native state backend with DynamoDB locking

**Why not chosen**:

- Requires AWS account (additional cloud provider)
- Monthly cost: ~$1-2/month for minimal usage
- More complex setup (two services to manage)
- Not suitable for DigitalOcean-first infrastructure
- R2 offers same functionality at zero cost

**Trade-offs**: AWS native integration vs. cost and simplicity

### Local State

**Description**: State files stored locally in repository

**Why not chosen**:

- No team collaboration support
- No state locking (conflict risk)
- Risk of state file loss
- Security risk (sensitive data in version control)
- Manual state file sharing required

**Trade-offs**: Simplicity vs. collaboration and safety

## Implementation Notes

### Migration Path

**Phase 1: Initial Setup** (Week 1)

1. Create Cloudflare R2 bucket for Terraform state
2. Enable versioning on R2 bucket
3. Generate R2 API tokens with appropriate permissions
4. Configure backend in development environment
5. Test state locking with concurrent operations

**Phase 2: Environment Migration** (Week 2)

1. Migrate development environment state
2. Migrate staging environment state
3. Migrate production environment state (with team coordination)
4. Verify state integrity after each migration

**Phase 3: Documentation and Automation** (Week 3)

1. Document R2 setup procedures
2. Update CI/CD pipelines with R2 credentials
3. Create runbook for R2 operations
4. Train team on new state backend

### State Organization

```
terraform-state/
├── environments/
│   ├── dev/
│   │   └── terraform.tfstate
│   ├── staging/
│   │   └── terraform.tfstate
│   └── production/
│       └── terraform.tfstate
├── modules/
│   └── (optional module state files)
└── .tflock files (created automatically)
```

### Security Configuration

**R2 API Token Permissions**:

- Object Read (for state pull)
- Object Write (for state push)
- Scope: Limited to `terraform-state` bucket only

**Access Control**:

- Store R2 credentials in GitHub Secrets for CI/CD
- Use environment variables locally: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- Rotate API tokens quarterly
- Audit access logs in Cloudflare dashboard

**Encryption**:

- R2 encrypts data at rest by default
- TLS 1.2+ for data in transit
- State files may contain sensitive data (passwords, keys)
- Consider additional encryption layer for highly sensitive infrastructure

### Backup and Recovery

**Backup Strategy**:

- R2 versioning enabled (automatic)
- Daily state file exports to separate storage
- Retention: 90 days of state history
- Version control for Terraform configurations

**Recovery Procedures**:

- Restore from R2 version history (most recent)
- Restore from daily backup exports (older versions)
- Rebuild state from actual infrastructure (last resort)

**RTO/RPO**:

- Recovery Time Objective: < 15 minutes
- Recovery Point Objective: < 24 hours (daily backups)

### Cost Monitoring

**Current Usage** (estimated):

- State files: ~5MB total across all environments
- Requests: ~500/month (plan/apply operations)
- Storage cost: $0 (well within 10GB free tier)
- Egress cost: $0 (R2 has zero egress fees)

**Scaling Considerations**:

- Free tier sufficient for 2000+ state files
- If exceeding 10GB: $0.015/GB/month ($0.18/year per GB)
- Request costs minimal even at scale

## Validation and Testing

**Pre-deployment Testing**:

- [ ] Verify R2 bucket creation and configuration
- [ ] Test state locking with concurrent `terraform apply`
- [ ] Validate state file encryption
- [ ] Confirm version history functionality
- [ ] Test state recovery from previous versions

**Post-deployment Validation**:

- [ ] Successful state migration from local to R2
- [ ] State locking prevents concurrent modifications
- [ ] Team members can access state
- [ ] CI/CD pipelines successfully authenticate
- [ ] State backup automation functional

## References

- [Research-0018: Terraform State Management](../research/0018-terraform-state-management.md)
- [Cloudflare R2 Documentation](https://developers.cloudflare.com/r2/)
- [Cloudflare R2 S3 API Compatibility](https://developers.cloudflare.com/r2/api/s3/api/)
- [Terraform S3 Backend Documentation](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [Terraform S3 Native State Locking](https://www.terraform.io/docs/language/settings/backends/s3.html#use_lockfile)
- [Cloudflare Services Specification](../../specs/cloudflare/cloudflare-services.md)
- [ADR-0002: Terraform as Primary IaC Tool](0002-terraform-primary-tool.md)
- [ADR-0004: Cloudflare DNS and Services](0004-cloudflare-dns-services.md)

## Supersedes

This decision supersedes the placeholder state backend configuration in ADR-0002, which suggested DigitalOcean Spaces as the remote backend.

## Related Decisions

- [ADR-0002: Terraform as Primary IaC Tool](0002-terraform-primary-tool.md) - Established need for remote state
- [ADR-0004: Cloudflare DNS and Services](0004-cloudflare-dns-services.md) - Existing Cloudflare integration
- [ADR-0013: DigitalOcean as Primary Cloud](0013-digitalocean-primary-cloud.md) - Cloud provider strategy

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-28 | Infrastructure Team | Initial decision for R2 state backend |

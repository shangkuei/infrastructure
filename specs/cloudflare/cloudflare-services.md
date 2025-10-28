# Cloudflare Services Specification

**Version**: 1.1
**Status**: Approved
**Last Updated**: 2025-10-28
**Owner**: Infrastructure Team

## Overview

Cloudflare provides DNS, edge services, email routing, and object storage (R2) for the infrastructure on the Free Plan. This specification defines how Cloudflare services are configured and managed.

**Primary Services**:

- DNS management with DNSSEC
- Email routing
- SSL/TLS certificates and CDN
- R2 object storage for Terraform state

## Requirements

### Functional Requirements

- Manage DNS records for all domains
- Route incoming emails to personal email addresses
- Provide SSL/TLS certificates for all domains
- Protect against DDoS attacks
- Cache and deliver static content globally
- Store Terraform state files with versioning and locking

### Non-Functional Requirements

- DNS resolution latency < 50ms globally
- 100% DNS uptime (Cloudflare SLA)
- Automatic SSL certificate renewal
- Email routing delivery within 5 minutes
- Terraform state access latency < 200ms globally
- State file durability 99.999999999% (11 nines)
- Zero-cost operation on free tier

## Architecture

### Service Components

```
┌─────────────────────────────────────────────────────────────┐
│                      Cloudflare Edge                         │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │     DNS      │  │     CDN      │  │   SSL/TLS    │      │
│  │  Resolution  │  │   Caching    │  │    Edge      │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │    Email     │  │     WAF      │  │     DDoS     │      │
│  │   Routing    │  │  Firewall    │  │  Protection  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                             │
                             ▼
              ┌──────────────────────────────┐
              │     Origin Servers           │
              │  (AWS, Azure, GCP, On-Prem)  │
              └──────────────────────────────┘
```

### Integration Points

- **Terraform**: Cloudflare provider for infrastructure as code
- **GitHub Actions**: Automated DNS and configuration updates
- **Origin Servers**: Backend servers protected by Cloudflare
- **Email Clients**: Destination for routed emails

## Configuration

### DNS Records

Standard record types managed:

| Record Type | Purpose | Example |
|-------------|---------|---------|
| A | IPv4 addresses | `example.com → 192.0.2.1` |
| AAAA | IPv6 addresses | `example.com → 2001:db8::1` |
| CNAME | Aliases | `www.example.com → example.com` |
| MX | Email routing | `example.com → route.cloudflare.net` |
| TXT | Verification records | SPF, DKIM, domain verification |
| SRV | Service records | Kubernetes service discovery |
| CAA | Certificate authority authorization | SSL certificate issuance control |

### Email Routing Configuration

**Routing Rules**:

```yaml
# Basic forwarding
source: admin@example.com
destination: personal.email@gmail.com

# Catch-all forwarding
source: *@example.com
destination: personal.email@gmail.com

# Multiple destinations
source: support@example.com
destinations:
  - team.member1@gmail.com
  - team.member2@gmail.com
```

**Limitations**:

- Receiving only (not for sending bulk emails)
- Maximum 200 destination addresses per zone
- Email size limit: 25 MB
- Free tier: unlimited emails

### SSL/TLS Configuration

**SSL/TLS Mode**: Full (Strict)

- **Edge Certificate**: Cloudflare-managed, auto-renewed
- **Origin Certificate**: Cloudflare Origin CA certificate on backend servers
- **Minimum TLS Version**: 1.2
- **Cipher Suites**: Modern (TLS 1.3 preferred)

**Certificate Settings**:

```hcl
# Terraform configuration
resource "cloudflare_zone_settings_override" "example" {
  zone_id = var.zone_id

  settings {
    ssl = "strict"
    min_tls_version = "1.2"
    tls_1_3 = "on"
    automatic_https_rewrites = "on"
    always_use_https = "on"
  }
}
```

### Security Features

**DNSSEC**: Enabled for all zones

**Firewall Rules**:

- Block known malicious IPs
- Rate limiting: 100 requests/minute per IP
- Challenge suspicious traffic
- Block countries if needed (not recommended for global services)

**DDoS Protection**: Always on, automatic mitigation

### CDN Configuration

**Caching Rules**:

```
Static Assets:
  - Cache Level: Standard
  - Browser TTL: 4 hours
  - Edge TTL: 1 month
  - File types: .js, .css, .jpg, .png, .gif, .svg, .woff, .woff2

Dynamic Content:
  - Cache Level: Bypass
  - Applies to: .html, API endpoints
```

**Page Rules** (Free tier: 3 rules):

1. `*.example.com/static/*` → Cache Everything, Edge TTL 1 month
2. `*.example.com/api/*` → Cache Level: Bypass
3. `www.example.com/*` → Forwarding URL to `example.com/$1`

### R2 Object Storage Configuration

**Purpose**: Store Terraform state files with native locking and versioning

**Bucket Configuration**:

```yaml
Bucket Name: terraform-state
Region: Automatic (global distribution)
Versioning: Enabled
Public Access: Disabled (private)
Lifecycle: No automatic deletion (manual cleanup)
```

**Access Configuration**:

```yaml
Authentication: R2 API Tokens
Permissions: Object Read + Object Write
Scope: terraform-state bucket only
Token Rotation: Quarterly
```

**Terraform Backend Configuration**:

```hcl
terraform {
  required_version = "~> 1.11"

  backend "s3" {
    endpoints = {
      s3 = "https://<ACCOUNT_ID>.r2.cloudflarestorage.com"
    }

    bucket = "terraform-state"
    key    = "environments/production/terraform.tfstate"
    region = "auto"

    # Native state locking (Terraform v1.10+)
    use_lockfile = true

    # S3 compatibility flags
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
```

**State File Organization**:

```
terraform-state/
├── environments/
│   ├── dev/
│   │   ├── terraform.tfstate
│   │   └── .terraform.tfstate.lock
│   ├── staging/
│   │   ├── terraform.tfstate
│   │   └── .terraform.tfstate.lock
│   └── production/
│       ├── terraform.tfstate
│       └── .terraform.tfstate.lock
```

**Security Features**:

- Encryption at rest (AES-256)
- Encryption in transit (TLS 1.2+)
- API token authentication
- Least privilege access control
- Audit logging via Cloudflare dashboard

**Versioning and Rollback**:

- Automatic versioning enabled
- State history retained for 90 days
- Rollback capability via R2 version history
- Manual state backup exports to external storage

**Performance Characteristics**:

- State retrieval: ~150-250ms (global edge network)
- State upload: ~100-200ms (typical 10KB state file)
- Lock acquisition: ~80-120ms (S3 conditional writes)
- Concurrent lock conflicts: Automatic retry with backoff

**Cost Analysis** (Free Tier):

- Storage: 10GB included (sufficient for 2000+ state files)
- Requests: Included (Class A: 1M/month, Class B: 10M/month)
- Egress: Zero cost (unlimited data transfer)
- Current usage: ~5MB storage, ~500 requests/month = **$0/month**

See [ADR-0014: Cloudflare R2 for Terraform State Storage](../../docs/decisions/0014-cloudflare-r2-terraform-state.md) for decision rationale.

## Free Tier Services Available

### Core Services (Unlimited)

| Service | Free Tier Limit | Use Case |
|---------|----------------|----------|
| **DNS Resolution** | Unlimited queries | All domain name resolution |
| **Email Routing** | Unlimited emails | Personal email forwarding |
| **SSL/TLS Certificates** | Unlimited | HTTPS for all domains |
| **DDoS Protection** | Unmetered | Always-on protection |
| **CDN Bandwidth** | Unlimited | Global content delivery |
| **Page Rules** | 3 rules | Custom caching/routing |

### Limited Free Services

| Service | Free Tier Limit | Use Case |
|---------|----------------|----------|
| **Workers** | 100,000 req/day | Edge serverless functions |
| **Pages** | 1 build at a time | Static site hosting |
| **Workers KV** | 100,000 reads/day | Key-value storage |
| **R2 Storage** | 10 GB storage + zero egress | **Terraform state storage** ⭐ |
| **Stream** | 1,000 minutes delivered | Video streaming |
| **Images** | 100,000 images | Image optimization |

### Recommended Free Services for Personal Infrastructure

1. **R2 Storage** ⭐ ⭐ ⭐
   - **Primary use: Terraform state storage**
   - Native state locking support
   - 10GB free storage (sufficient for thousands of state files)
   - Zero egress fees (unlimited data transfer)
   - Global edge network performance
   - Versioning and rollback capability

2. **Email Routing** ⭐
   - Replace personal mail server
   - Forward to Gmail/Outlook
   - No maintenance required

3. **Workers** ⭐
   - API endpoints at edge
   - Form processing
   - Authentication middleware
   - Suitable for personal projects (100K req/day)

4. **Pages** ⭐
   - Static site hosting
   - CI/CD integration with GitHub
   - Custom domains with SSL

5. **Tunnels** (Cloudflared)
   - Secure access to internal network
   - No port forwarding needed
   - Zero trust access

6. **DNS + DNSSEC**
   - Fast, reliable DNS
   - Security against DNS spoofing

## Capacity Planning

### Resource Requirements

**DNS**:

- Zones: Unlimited on free tier
- Records per zone: 1,000 (free tier)
- Queries: Unlimited

**Email Routing**:

- Destination addresses: 200 per zone
- Email size: 25 MB max
- Delivery: Unlimited emails

**CDN**:

- Bandwidth: Unlimited
- Cached files: No limit
- Request rate: No hard limit (fair use)

**R2 Storage**:

- Storage: 10 GB free
- Class A operations: 1 million/month (writes)
- Class B operations: 10 million/month (reads)
- Egress: Unlimited (zero cost)
- Current usage: ~5MB, ~500 requests/month

**Workers**:

- Requests: 100,000/day free
- CPU time: 10ms per request
- Script size: 1 MB

### Scaling Characteristics

**DNS**: Automatic global scaling, no configuration needed

**Email**: No scaling needed, unlimited emails on free tier

**CDN**: Automatic edge scaling, global distribution

**R2**: Automatic scaling, global edge distribution. Upgrade to paid only if exceeding 10GB storage ($0.015/GB/month)

**Workers**: Upgrade to paid ($5/month) for 10 million requests/month

## Security

### Authentication

**API Token Management**:

```bash
# Create scoped API token for Cloudflare services
# Required permissions:
# - Zone.DNS (Edit)
# - Zone.Email Routing Rules (Edit)
# - Zone.SSL and Certificates (Edit)
# - Zone.Settings (Edit)

# Store in GitHub Secrets
gh secret set CLOUDFLARE_API_TOKEN

# Create R2 API token for Terraform state
# Required permissions:
# - R2 Object Read
# - R2 Object Write
# - Scope: terraform-state bucket only

# Store in GitHub Secrets
gh secret set R2_ACCESS_KEY_ID
gh secret set R2_SECRET_ACCESS_KEY
```

### Authorization

**Zone Access**:

- Use least privilege API tokens
- Scope tokens to specific zones
- Separate tokens for different environments

### Encryption

- All API communication over HTTPS
- SSL/TLS 1.2+ for edge connections
- End-to-end encryption for email routing

### Network Security

**Firewall Rules**:

```hcl
# Block specific countries (if needed)
resource "cloudflare_firewall_rule" "block_country" {
  zone_id     = var.zone_id
  description = "Block high-risk countries"
  filter_id   = cloudflare_filter.country_filter.id
  action      = "block"
}

# Rate limiting
resource "cloudflare_rate_limit" "api_limit" {
  zone_id   = var.zone_id
  threshold = 100
  period    = 60
  match {
    request {
      url_pattern = "example.com/api/*"
    }
  }
  action {
    mode = "challenge"
  }
}
```

## Monitoring and Alerting

### Metrics

**DNS Metrics**:

- Query volume
- Response time
- Error rate (NXDOMAIN, SERVFAIL)

**Email Routing Metrics**:

- Emails routed
- Delivery failures
- Spam/malware detected

**CDN Metrics**:

- Cache hit ratio
- Bandwidth usage
- Request volume
- Error rates (4xx, 5xx)

### Alerts

**Critical Alerts**:

- DNS resolution failures
- Email routing failures
- SSL certificate expiration (auto-renewed, but monitor)
- DDoS attack detected

**Warning Alerts**:

- Approaching Workers request limit (80,000/day)
- Unusual traffic patterns
- High error rates

### Health Checks

**DNS Health**:

```bash
# Check DNS resolution
dig @1.1.1.1 example.com
dig @8.8.8.8 example.com

# Check DNSSEC
dig +dnssec example.com
```

**Email Routing Health**:

```bash
# Send test email
echo "Test" | mail -s "Test" test@example.com

# Check MX records
dig MX example.com
```

**SSL/TLS Health**:

```bash
# Check certificate
curl -vI https://example.com 2>&1 | grep -A 10 "SSL certificate"

# Check TLS version
openssl s_client -connect example.com:443 -tls1_2
```

## Disaster Recovery

### Backup Strategy

**DNS Records**:

- Export DNS records daily via Cloudflare API
- Store in version control (Terraform state)
- Backup frequency: Daily
- Retention: 90 days

**Email Routing Rules**:

- Export routing configuration
- Store in Terraform configuration
- Version controlled in Git

### Recovery Procedures

**DNS Failure Recovery**:

1. Verify Cloudflare status: https://www.cloudflarestatus.com/
2. Check nameserver delegation
3. Verify DNS records in Cloudflare dashboard
4. If needed, failover to secondary DNS provider

**Email Routing Failure Recovery**:

1. Check Cloudflare Email Routing dashboard
2. Verify MX records point to Cloudflare
3. Test email delivery
4. Check destination email for spam filtering

**SSL/TLS Certificate Failure**:

1. Verify certificate status in Cloudflare dashboard
2. Check SSL/TLS mode setting
3. Regenerate origin certificate if needed
4. Force certificate renewal if expired

### Recovery Time Objective (RTO)

- DNS: < 5 minutes (switch to secondary DNS)
- Email: < 30 minutes (update MX records)
- SSL/TLS: < 1 hour (reissue certificate)

### Recovery Point Objective (RPO)

- DNS records: 0 (version controlled)
- Email routing: 0 (version controlled)
- SSL certificates: 0 (auto-renewed)

## Dependencies

**Required Services**:

- Cloudflare account with verified email
- Domain registrar for nameserver updates
- GitHub for version control and CI/CD

**Optional Services**:

- Destination email provider (Gmail, Outlook, etc.)
- Origin servers (for proxied records)
- Monitoring service (UptimeRobot, Pingdom)

## Constraints and Limitations

**Free Tier Constraints**:

- No SLA guarantee
- Limited support (community only)
- 3 Page Rules maximum
- 100,000 Workers requests/day
- 1,000 DNS records per zone
- No custom certificate upload (Enterprise only)

**Email Routing Limitations**:

- Receiving only (not for sending)
- 25 MB email size limit
- 200 destination addresses per zone
- No email storage (forwarding only)

**Technical Limitations**:

- Cannot use Cloudflare for NS records (delegation)
- Some features require domain to be proxied through Cloudflare
- Firewall rules limited on free tier

## References

- [Cloudflare Free Plan](https://www.cloudflare.com/plans/free/)
- [Email Routing Documentation](https://developers.cloudflare.com/email-routing/)
- [Cloudflare Terraform Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)
- [DNS Documentation](https://developers.cloudflare.com/dns/)
- [Workers Documentation](https://developers.cloudflare.com/workers/)
- [Pages Documentation](https://developers.cloudflare.com/pages/)
- [ADR-0004: Cloudflare DNS and Services](../../docs/decisions/0004-cloudflare-dns-services.md)

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-19 | Infrastructure Team | Initial specification |
| 1.1 | 2025-10-28 | Infrastructure Team | Added R2 configuration for Terraform state storage |

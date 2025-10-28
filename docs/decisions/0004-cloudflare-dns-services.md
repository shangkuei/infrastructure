# 4. Cloudflare for DNS and Edge Services

Date: 2025-10-19

## Status

Accepted

## Context

Managing DNS and email infrastructure traditionally requires:

- **DNS Hosting**: Reliable, globally distributed DNS resolution
- **Email Server**: Complex mail server setup, maintenance, and security
- **SSL/TLS Certificates**: Certificate management and renewal
- **DDoS Protection**: Protection against distributed denial of service attacks
- **CDN**: Content delivery for static assets

These requirements typically involve:

- Multiple vendors and service subscriptions
- Complex configuration and maintenance
- Security vulnerabilities if not properly managed
- Significant operational overhead
- Cost for email servers, DNS hosting, and CDN

We need a solution that:

- Provides reliable DNS management
- Offers simple email sending for personal/transactional use
- Includes security features (SSL/TLS, DDoS protection)
- Has a free tier suitable for personal infrastructure
- Integrates well with Infrastructure as Code tools
- Reduces operational complexity

## Decision

We will use **Cloudflare Free Plan** as our primary DNS and edge services provider.

### Core Services Used

1. **DNS Management** (Free)
   - Authoritative DNS for all domains
   - Fast global DNS resolution
   - DNSSEC support
   - API-based management via Terraform

2. **Email Routing** (Free)
   - Forward emails to personal email addresses
   - No need to run dedicated mail servers
   - Simple routing rules
   - Suitable for personal and transactional email

3. **SSL/TLS Certificates** (Free)
   - Universal SSL certificates
   - Automatic certificate renewal
   - Edge certificates for custom domains

4. **DDoS Protection** (Free)
   - Unmetered DDoS mitigation
   - Web Application Firewall (WAF) basic rules
   - Rate limiting

5. **CDN** (Free)
   - Global content delivery network
   - Caching for static assets
   - Bandwidth not metered on free plan

### Additional Free Features We May Use

- **Page Rules**: Custom caching and routing rules
- **Analytics**: Basic traffic analytics
- **Workers** (Limited): Serverless functions at edge (100,000 requests/day free)
- **Pages**: Static site hosting
- **Tunnels**: Secure access to internal services

### Terraform Integration

Cloudflare provider will be used to manage:

```hcl
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
```

## Consequences

### Positive

- **Cost Effective**: Free tier covers personal infrastructure needs
- **Simplified Email**: No mail server maintenance, just email routing
- **Global DNS**: Fast, reliable DNS resolution worldwide
- **Security Included**: DDoS protection and SSL/TLS at no cost
- **IaC Compatible**: Full Terraform provider support
- **Reduced Complexity**: Single vendor for multiple services
- **No Bandwidth Charges**: Unlimited bandwidth on free tier
- **Easy Migration**: Simple to migrate domains to Cloudflare

### Negative

- **Vendor Dependency**: Tied to Cloudflare for DNS and email routing
- **Email Limitations**: Email Routing is for receiving only, not sending bulk emails
- **Free Tier Limits**:
  - Workers limited to 100,000 requests/day
  - No SLA on free tier
  - Limited support
- **Privacy Considerations**: Traffic proxied through Cloudflare
- **Configuration Complexity**: Some features require careful configuration
- **Migration Effort**: Need to update nameservers for existing domains

### Trade-offs

- **Simplicity vs. Control**: Less control over email infrastructure but much simpler
- **Cost vs. Features**: Free tier sufficient for personal use, paid tier needed for enterprise features
- **Convenience vs. Privacy**: Email routing is convenient but requires trust in Cloudflare

## Alternatives Considered

### Self-Hosted DNS (BIND/PowerDNS)

**Why not chosen**:

- Requires dedicated servers
- Complex maintenance and security updates
- No built-in DDoS protection
- Operational overhead too high for personal infrastructure

### AWS Route 53

**Why not chosen**:

- Costs $0.50/hosted zone/month
- DNS queries are metered ($0.40/million for first billion)
- No free tier for DNS
- No email routing equivalent

### Self-Hosted Email Server (Postfix/Dovecot)

**Why not chosen**:

- Complex setup and maintenance
- Security challenges (spam, malware filtering)
- Deliverability issues (IP reputation)
- Server costs and management overhead
- Significant time investment

### Google Workspace / Microsoft 365

**Why not chosen**:

- Minimum $6-12/user/month
- Overkill for simple email routing needs
- Not Infrastructure as Code friendly
- Vendor lock-in with less flexibility

### Mailgun / SendGrid (Email Services)

**Why not chosen**:

- Focused on sending emails, not receiving/routing
- Free tiers are limited
- Separate from DNS management
- Additional vendor to manage

## Implementation Plan

1. **Domain Migration**:
   - Update nameservers to Cloudflare
   - Verify DNS records are correctly imported
   - Test DNS resolution

2. **Email Routing Setup**:
   - Configure email routing rules in Cloudflare
   - Add destination email addresses
   - Test email forwarding

3. **Terraform Configuration**:
   - Add Cloudflare provider to `terraform/providers/cloudflare/`
   - Create DNS zone resources
   - Define email routing rules as code

4. **SSL/TLS Configuration**:
   - Enable Universal SSL
   - Configure SSL/TLS mode (Flexible, Full, Full Strict)
   - Set up edge certificates if needed

5. **Security Hardening**:
   - Enable DNSSEC
   - Configure firewall rules
   - Set up rate limiting

6. **Documentation**:
   - Create runbook for Cloudflare operations
   - Document email routing patterns
   - Add troubleshooting guide

## Success Metrics

- All domains resolving correctly via Cloudflare DNS
- Email routing working for all configured addresses
- SSL/TLS certificates automatically renewed
- No DNS-related downtime
- Reduced operational overhead compared to self-hosted solutions

## Security Considerations

- Store Cloudflare API token in GitHub Secrets
- Use scoped API tokens with minimal permissions
- Enable 2FA on Cloudflare account
- Regularly audit DNS records and email routing rules
- Monitor Cloudflare analytics for suspicious activity

## Future Considerations

- Evaluate Cloudflare Workers for edge computing needs
- Consider Cloudflare Tunnels for secure access to on-premise services
- Explore Cloudflare Pages for static site hosting
- Monitor usage and upgrade to paid tier if needed

## References

- [Cloudflare Free Plan Features](https://www.cloudflare.com/plans/free/)
- [Cloudflare Email Routing](https://developers.cloudflare.com/email-routing/)
- [Cloudflare Terraform Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)
- [Cloudflare DNS Documentation](https://developers.cloudflare.com/dns/)
- [Cloudflare Security Features](https://www.cloudflare.com/application-services/products/security/)

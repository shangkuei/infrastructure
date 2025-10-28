# Runbook: Cloudflare Operations

## Overview

This runbook provides operational procedures for managing Cloudflare DNS, email routing, and edge services.
Cloudflare is used on the Free Plan for DNS management, email routing,
SSL/TLS certificates, and CDN services.

## Prerequisites

- Cloudflare account with domain(s) added
- Cloudflare API token with appropriate permissions
- Access to domain registrar for nameserver updates
- Terraform installed for infrastructure as code management

## Common Operations

### 1. Add a New Domain to Cloudflare

**Objective**: Register a new domain with Cloudflare for DNS and edge services.

**Procedure**:

1. **Add domain via Cloudflare dashboard**:

   ```bash
   # Or use Terraform
   cat > /tmp/add-domain.tf <<'EOF'
   resource "cloudflare_zone" "new_domain" {
     zone = "newdomain.com"
     plan = "free"
   }
   EOF
   ```

2. **Update nameservers at registrar**:
   - Get Cloudflare nameservers from dashboard or Terraform output
   - Typical format: `name1.cloudflare.com`, `name2.cloudflare.com`
   - Login to domain registrar
   - Update nameservers to Cloudflare's

3. **Wait for DNS propagation**:

   ```bash
   # Check nameserver delegation
   dig NS newdomain.com

   # Should show Cloudflare nameservers
   # Propagation typically takes 2-48 hours
   ```

4. **Verify domain activation**:

   ```bash
   # Check domain status
   curl -X GET "https://api.cloudflare.com/client/v4/zones?name=newdomain.com" \
     -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
     -H "Content-Type: application/json"

   # Look for "status": "active"
   ```

**Verification**:

- Domain shows as "Active" in Cloudflare dashboard
- DNS queries resolve through Cloudflare nameservers
- SSL certificate issued (may take a few minutes)

**Rollback**:

- Update nameservers back to original DNS provider
- Wait for DNS propagation
- Remove zone from Cloudflare

---

### 2. Configure Email Routing

**Objective**: Set up email forwarding to personal email addresses without running a mail server.

**Procedure**:

1. **Enable Email Routing**:

   ```bash
   # Via Terraform
   cat > /tmp/email-routing.tf <<'EOF'
   resource "cloudflare_email_routing_settings" "domain" {
     zone_id = var.zone_id
     enabled = true
   }
   EOF
   ```

2. **Add destination email address**:

   ```bash
   # Cloudflare will send verification email
   # Click verification link in email
   ```

3. **Create routingrules**:

   ```bash
   # Via Terraform
   cat > /tmp/email-rules.tf <<'EOF'
   # Forward specific address
   resource "cloudflare_email_routing_rule" "admin" {
     zone_id = var.zone_id
     name    = "Admin email routing"
     enabled = true

     matcher {
       type  = "literal"
       field = "to"
       value = "admin@example.com"
     }

     action {
       type  = "forward"
       value = ["your.email@gmail.com"]
     }
   }

   # Catch-all rule
   resource "cloudflare_email_routing_rule" "catchall" {
     zone_id = var.zone_id
     name    = "Catch all"
     enabled = true

     matcher {
       type  = "all"
     }

     action {
       type  = "forward"
       value = ["your.email@gmail.com"]
     }
   }
   EOF
   ```

4. **Update MX records** (automatic when using Terraform, or manual):

   ```bash
   # MX records should point to Cloudflare
   dig MX example.com

   # Should show:
   # example.com. IN MX 10 route1.mx.cloudflare.net.
   # example.com. IN MX 20 route2.mx.cloudflare.net.
   # example.com. IN MX 30 route3.mx.cloudflare.net.
   ```

**Verification**:

```bash
# Send test email
echo "Test email body" | mail -s "Test Subject" test@example.com

# Check destination inbox for forwarded email
# Delivery typically within 5 minutes
```

**Troubleshooting**:

- Verify destination email is confirmed
- Check MX records are pointing to Cloudflare
- Check spam folder at destination
- Review Email Routing logs in Cloudflare dashboard

**Rollback**:

- Disable email routing in settings
- Update MX records to point to original mail server
- Remove routing rules

---

### 3. Add or Update DNS Records

**Objective**: Manage DNS records for services and infrastructure.

**Procedure**:

1. **Create DNS record via Terraform**:

   ```hcl
   # A record for IPv4
   resource "cloudflare_record" "web" {
     zone_id = var.zone_id
     name    = "www"
     value   = "192.0.2.1"
     type    = "A"
     proxied = true  # Enable Cloudflare CDN and protection
     ttl     = 1     # Auto TTL when proxied
   }

   # CNAME record
   resource "cloudflare_record" "app" {
     zone_id = var.zone_id
     name    = "app"
     value   = "example.herokuapp.com"
     type    = "CNAME"
     proxied = false  # Direct DNS, no proxy
     ttl     = 3600
   }

   # TXT record for verification
   resource "cloudflare_record" "verification" {
     zone_id = var.zone_id
     name    = "@"
     value   = "google-site-verification=abcdefg"
     type    = "TXT"
     ttl     = 3600
   }
   ```

2. **Apply changes**:

   ```bash
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

3. **Verify DNS propagation**:

   ```bash
   # Query Cloudflare DNS directly
   dig @1.1.1.1 www.example.com

   # Query public DNS (may take a few minutes)
   dig www.example.com

   # Check from multiple locations
   nslookup www.example.com 8.8.8.8
   ```

**Verification**:

- DNS query returns expected value
- TTL matches configuration
- Proxied status correct (orange cloud in dashboard)

**Common Record Types**:

| Type | Use Case | Example |
|------|----------|---------|
| A | IPv4 address | `192.0.2.1` |
| AAAA | IPv6 address | `2001:db8::1` |
| CNAME | Alias to another domain | `app.herokuapp.com` |
| MX | Email routing | `route.cloudflare.net` |
| TXT | Verification, SPF, DKIM | `v=spf1 include:_spf.google.com ~all` |
| SRV | Service discovery | `10 5 5060 sipserver.example.com` |
| CAA | Certificate authority | `0 issue "letsencrypt.org"` |

**Troubleshooting**:

- DNS not resolving: Check nameserver delegation
- Wrong value: Verify Terraform configuration
- Slow propagation: Wait, check TTL values
- Proxied record issues: Toggle proxy status

---

### 4. Enable and Configure SSL/TLS

**Objective**: Ensure HTTPS is enabled for all domains with proper SSL/TLS configuration.

**Procedure**:

1. **Configure SSL/TLS mode**:

   ```hcl
   resource "cloudflare_zone_settings_override" "ssl" {
     zone_id = var.zone_id

     settings {
       ssl                      = "strict"        # Full (Strict)
       min_tls_version          = "1.2"
       tls_1_3                  = "on"
       automatic_https_rewrites = "on"
       always_use_https         = "on"
       opportunistic_encryption = "on"
     }
   }
   ```

2. **SSL/TLS modes explained**:
   - **Off**: No HTTPS (not recommended)
   - **Flexible**: HTTPS from client to Cloudflare, HTTP to origin
   - **Full**: HTTPS end-to-end, accepts self-signed certs
   - **Full (Strict)**: HTTPS end-to-end, requires valid cert on origin ⭐ Recommended

3. **Install origin certificate** (if using Full Strict):

   ```bash
   # Generate origin certificate in Cloudflare dashboard
   # SSL/TLS > Origin Server > Create Certificate
   # Download certificate and private key
   # Install on origin server (web server, load balancer)
   ```

4. **Verify SSL/TLS**:

   ```bash
   # Check SSL certificate
   curl -vI https://example.com 2>&1 | grep -A 10 "SSL certificate"

   # Check TLS version
   openssl s_client -connect example.com:443 -tls1_2

   # Check certificate chain
   openssl s_client -connect example.com:443 -showcerts
   ```

**Verification**:

- HTTPS loads without warnings
- Certificate shows "Cloudflare" in issuer
- TLS 1.2+ is used
- HTTP redirects to HTTPS

**Troubleshooting**:

- "Too many redirects": Check SSL/TLS mode and origin server config
- "Certificate error": Verify origin certificate installation
- "Mixed content": Enable automatic HTTPS rewrites

---

### 5. Configure CDN Caching

**Objective**: Optimize content delivery and reduce origin load through caching.

**Procedure**:

1. **Configure page rules** (Free tier: 3 rules max):

   ```hcl
   # Cache static assets
   resource "cloudflare_page_rule" "static_cache" {
     zone_id  = var.zone_id
     target   = "example.com/static/*"
     priority = 1

     actions {
       cache_level         = "cache_everything"
       edge_cache_ttl      = 2592000  # 30 days
       browser_cache_ttl   = 14400    # 4 hours
     }
   }

   # Bypass cache for API
   resource "cloudflare_page_rule" "api_bypass" {
     zone_id  = var.zone_id
     target   = "example.com/api/*"
     priority = 2

     actions {
       cache_level = "bypass"
     }
   }

   # WWW to apex redirect
   resource "cloudflare_page_rule" "www_redirect" {
     zone_id  = var.zone_id
     target   = "www.example.com/*"
     priority = 3

     actions {
       forwarding_url {
         url         = "https://example.com/$1"
         status_code = 301
       }
     }
   }
   ```

2. **Apply configuration**:

   ```bash
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

3. **Purge cache if needed**:

   ```bash
   # Purge everything
   curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/purge_cache" \
     -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
     -H "Content-Type: application/json" \
     --data '{"purge_everything":true}'

   # Purge specific URLs
   curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/purge_cache" \
     -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
     -H "Content-Type: application/json" \
     --data '{"files":["https://example.com/style.css","https://example.com/app.js"]}'
   ```

**Verification**:

```bash
# Check cache status
curl -I https://example.com/static/image.png | grep -i "cf-cache-status"

# Status values:
# HIT: Served from cache
# MISS: Not in cache, fetched from origin
# EXPIRED: Cache expired, revalidating
# BYPASS: Caching bypassed
# DYNAMIC: Dynamic content, not cached
```

**Best Practices**:

- Use page rules wisely (only 3 on free tier)
- Cache static assets aggressively
- Bypass cache for dynamic/personalized content
- Set appropriate TTLs (longer for static, shorter for changing content)

---

### 6. Enable DNSSEC

**Objective**: Protect against DNS spoofing and cache poisoning attacks.

**Procedure**:

1. **Enable DNSSEC in Cloudflare**:

   ```bash
   # Via dashboard: DNS > Settings > DNSSEC > Enable
   # Or via Terraform
   cat > /tmp/dnssec.tf <<'EOF'
   resource "cloudflare_zone_dnssec" "example" {
     zone_id = var.zone_id
   }
   EOF
   ```

2. **Get DS records**:

   ```bash
   # Retrieve from Cloudflare dashboard or API
   # Example DS record format:
   # 2371 13 2 <digest>
   ```

3. **Add DS records to domain registrar**:
   - Login to domain registrar
   - Find DNSSEC settings
   - Add DS records provided by Cloudflare
   - Save changes

4. **Wait for propagation** (24-48 hours)

**Verification**:

```bash
# Check DNSSEC validation
dig +dnssec example.com

# Should see RRSIG records
# Verify with online tools:
# https://dnssec-debugger.verisignlabs.com/
```

**Troubleshooting**:

- DNSSEC validation failed: Verify DS records at registrar
- Delegation issues: Check parent zone delegation
- Propagation delays: Wait 48 hours before troubleshooting

---

### 7. Configure Firewall Rules and Security

**Objective**: Protect infrastructure with Web Application Firewall and rate limiting.

**Procedure**:

1. **Create firewall rules**:

   ```hcl
   # Block specific countries (use sparingly)
   resource "cloudflare_filter" "block_country" {
     zone_id     = var.zone_id
     description = "Filter for high-risk countries"
     expression  = "(ip.geoip.country in {\"CN\" \"RU\"})"
   }

   resource "cloudflare_firewall_rule" "block_country" {
     zone_id     = var.zone_id
     description = "Block high-risk countries"
     filter_id   = cloudflare_filter.block_country.id
     action      = "block"
   }

   # Challenge suspicious traffic
   resource "cloudflare_filter" "challenge_bots" {
     zone_id     = var.zone_id
     description = "Challenge potential bots"
     expression  = "(cf.threat_score gt 30)"
   }

   resource "cloudflare_firewall_rule" "challenge_bots" {
     zone_id     = var.zone_id
     description = "Challenge suspicious requests"
     filter_id   = cloudflare_filter.challenge_bots.id
     action      = "challenge"
   }
   ```

2. **Configure rate limiting**:

   ```hcl
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
       mode    = "challenge"
       timeout = 600
     }
   }
   ```

3. **Apply security settings**:

   ```hcl
   resource "cloudflare_zone_settings_override" "security" {
     zone_id = var.zone_id

     settings {
       security_level         = "medium"
       challenge_ttl          = 1800
       browser_check          = "on"
       hotlink_protection     = "off"
       ip_geolocation         = "on"
       email_obfuscation      = "on"
       server_side_exclude    = "on"
       privacy_pass           = "on"
     }
   }
   ```

**Verification**:

- Test from different IPs/locations
- Check firewall events in Analytics > Security
- Verify rate limits trigger correctly

**Troubleshooting**:

- False positives: Adjust threat score threshold
- Legitimate traffic blocked: Whitelist IPs
- Rate limit too strict: Increase threshold or period

---

### 8. Monitor and Troubleshoot

**Objective**: Monitor Cloudflare services and troubleshoot issues.

**Monitoring**:

```bash
# Check Cloudflare status
curl https://www.cloudflarestatus.com/api/v2/status.json

# View analytics
# Cloudflare Dashboard > Analytics

# Check DNS resolution
dig @1.1.1.1 example.com

# Check SSL certificate
curl -vI https://example.com 2>&1 | grep -i certificate

# Test email routing
echo "Test" | mail -s "Test" test@example.com
```

**Common Issues**:

| Issue | Diagnosis | Solution |
|-------|-----------|----------|
| DNS not resolving | Check nameservers | Verify delegation at registrar |
| Too many redirects | SSL/TLS mode mismatch | Check SSL mode and origin config |
| Email not routing | MX records incorrect | Verify MX points to Cloudflare |
| Slow site load | Cache not working | Check page rules and cache settings |
| 520/521/522 errors | Origin server down | Check origin server health |
| DNSSEC validation | DS records wrong | Verify DS records at registrar |

**Debug Commands**:

```bash
# Trace DNS resolution
dig +trace example.com

# Check cache status
curl -I https://example.com | grep -i cf-cache

# View security events
# Cloudflare Dashboard > Analytics > Security Events

# Test from different locations
# https://www.whatsmydns.net/
```

---

## Emergency Procedures

### SSL Certificate Issues

1. Check certificate status in dashboard
2. Verify SSL/TLS mode is appropriate
3. Regenerate origin certificate if needed
4. Check origin server certificate installation
5. Disable Universal SSL and re-enable if needed

### Email Routing Failure

1. Verify Email Routing is enabled
2. Check MX records point to Cloudflare
3. Confirm destination email is verified
4. Review Email Routing logs
5. Send test email and check spam folder

### DNS Resolution Failure

1. Check Cloudflare status page
2. Verify nameservers at registrar
3. Check DNS records in Cloudflare
4. Try direct query: `dig @1.1.1.1 example.com`
5. Consider failover to secondary DNS if critical

### DDoS Attack Response

1. Check Analytics > Security for attack patterns
2. Enable "Under Attack Mode" if needed
3. Review and tighten firewall rules
4. Enable additional rate limiting
5. Consider upgrading plan for advanced DDoS protection

---

## References

- [Cloudflare Dashboard](https://dash.cloudflare.com/)
- [Cloudflare Status](https://www.cloudflarestatus.com/)
- [Cloudflare Documentation](https://developers.cloudflare.com/)
- [Cloudflare Terraform Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)
- [ADR-0004: Cloudflare DNS and Services](../decisions/0004-cloudflare-dns-services.md)
- [Cloudflare Services Specification](../../specs/cloudflare/cloudflare-services.md)

---

**Last Updated**: 2025-10-19
**Maintained By**: Infrastructure Team
**Review Frequency**: Quarterly

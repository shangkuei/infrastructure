# Research: Cloud Provider Evaluation

Date: 2025-10-17
Author: Infrastructure Team
Status: Completed

## Objective

Evaluate cloud providers (DigitalOcean, AWS, Azure, GCP) for hybrid cloud infrastructure, focusing on cost-effectiveness, simplicity, and suitability for small companies.

## Scope

Comparison of IaaS providers for VMs, Kubernetes, storage, and networking.

## Methodology

- Created test infrastructure on each provider
- Measured cost for typical workload (3-node K8s cluster)
- Evaluated documentation quality and learning curve
- Tested Terraform provider maturity

## Findings

| Provider | Monthly Cost* | Free Tier | Learning Curve | Best For |
|----------|---------------|-----------|----------------|----------|
| **DigitalOcean** | $58 | $200/60d | Low | Small companies, learning |
| **AWS** | $150 | 12 months | High | Enterprise, complex workloads |
| **Azure** | $68 | $200/30d | Medium | Microsoft stack, Windows |
| **GCP** | $60 | $300/90d | Medium | Data/ML, Google services |

\*3-node K8s cluster + LB + storage

## Recommendations

**Primary: DigitalOcean**

- Free control plane for Kubernetes
- Simple, predictable pricing
- Excellent documentation
- Good for learning and small production

**Secondary: AWS/Azure/GCP**

- Use when specific services needed
- Evaluate after proving infrastructure patterns
- Migration path exists via Terraform

## Outcome

Led to [ADR-0001 (Infrastructure as Code)](../decisions/0001-infrastructure-as-code.md) and
[ADR-0013 (DigitalOcean as Primary Cloud Provider)](../decisions/0013-digitalocean-primary-cloud.md)
for initial implementation.

**Selected**: DigitalOcean chosen as the primary cloud provider based on cost-effectiveness, simplicity, and suitability for small companies and personal infrastructure.

## References

- [DigitalOcean Pricing](https://www.digitalocean.com/pricing)
- [Cloud Provider Comparison 2024](https://www.cloudzero.com/blog/cloud-cost-comparison)

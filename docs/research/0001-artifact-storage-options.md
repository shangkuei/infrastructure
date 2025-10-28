# Research: Artifact Storage Options

Date: 2025-10-19
Author: Infrastructure Team
Status: Completed
Decision: ADR-0010 - GitHub Container Registry

## Objective

Evaluate artifact and container registry options for storing Docker images, Helm charts, and build artifacts.

## Scope

- Container registries (Docker Hub, GitHub Container Registry, DigitalOcean Registry)
- Helm chart repositories
- Generic artifact storage
- Cost and bandwidth limits

## Methodology

Testing push/pull performance, evaluating pricing, measuring bandwidth usage for typical workflows.

## Preliminary Findings

| Registry | Cost | Bandwidth | Private Repos | Best For |
|----------|------|-----------|---------------|----------|
| **Docker Hub** | Free (1 repo) | Unlimited | 1 free | Public images |
| **GitHub Container Registry** | Free | Unlimited | Unlimited | GitHub users |
| **DO Container Registry** | $20/month | 1TB | Unlimited | DO integration |
| **Harbor** | Infrastructure | Unlimited | Unlimited | Self-hosted |

**Recommendation**: GitHub Container Registry

- Free unlimited private repos
- Integrates with GitHub Actions
- Good performance
- No bandwidth limits

## Final Decision

✅ **GitHub Container Registry** has been selected as our artifact storage solution.

See [ADR-0010: GitHub Container Registry](../decisions/0010-github-container-registry.md) for the complete decision rationale, implementation plan, and integration details.

## Implementation Next Steps

See ADR-0010 for the complete migration plan. Key actions:

- [ ] Configure GitHub Container Registry access and authentication
- [ ] Update GitHub Actions workflows for automated image builds
- [ ] Implement security scanning with Trivy
- [ ] Create Kubernetes ImagePullSecrets
- [ ] Update deployment manifests to use ghcr.io images
- [ ] Set up retention policies and cleanup automation
- [ ] Document usage patterns and tagging conventions

## References

- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [DigitalOcean Container Registry](https://www.digitalocean.com/products/container-registry)

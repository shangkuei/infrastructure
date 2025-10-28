# Research: Security Scanning Tools

Date: 2025-10-18
Author: Infrastructure Team
Status: Completed

## Objective

Evaluate security scanning tools for infrastructure code, containers, and Kubernetes manifests.

## Findings

**IaC Scanning**:

- **tfsec**: Terraform security scanner (fast, free)
- **Checkov**: Multi-tool IaC scanner (Terraform, K8s, Docker)
- **Trivy**: Container + IaC scanning (comprehensive)

**Container Scanning**:

- **Trivy**: Best all-around (free, fast, accurate)
- **Grype**: Anchore's scanner (good accuracy)
- **Docker Scout**: Docker Desktop integration

**Kubernetes**:

- **kubesec**: Manifest security scoring
- **Polaris**: Best practices checking

## Recommendation

**Use Trivy for everything**:

```bash
# Scan Terraform
trivy config terraform/

# Scan Docker image
trivy image myapp:latest

# Scan Kubernetes manifests
trivy k8s deployment.yaml
```

Free, fast, accurate, single tool for all needs.

## Outcome

Integrated into CI/CD pipeline for automated security scanning.

## References

- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [tfsec](https://github.com/aquasecurity/tfsec)

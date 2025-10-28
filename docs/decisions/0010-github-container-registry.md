# 10. GitHub Container Registry for Artifact Storage

Date: 2025-10-21

## Status

Accepted

## Context

We need a container registry to store Docker images, Helm charts, and build artifacts for our Kubernetes-based infrastructure.

For a small company using GitHub for version control and GitHub Actions for CI/CD, we need an artifact storage solution that:

- **Container image storage**: Docker images for application deployments
- **Helm chart hosting**: Package and distribute Kubernetes applications
- **Free tier available**: Cost-effective for small-scale usage
- **Unlimited private repositories**: No restrictions on private artifacts
- **No bandwidth limits**: Avoid unexpected costs from pull operations
- **Integrated with GitHub**: Minimal setup and seamless CI/CD integration
- **Security scanning**: Built-in vulnerability detection
- **No infrastructure overhead**: Fully managed service

## Decision

We will use **GitHub Container Registry (ghcr.io)** as our primary artifact storage solution for Docker images and container-based artifacts.

Specifically:

- GitHub Container Registry will store all Docker container images
- Helm charts will be stored as OCI artifacts in GHCR
- Images will be built and pushed via GitHub Actions workflows
- Container scanning will use GitHub's built-in security features
- Images will follow semantic versioning and tagging conventions
- Public images will use `ghcr.io/{org}/{image}:{tag}` format
- Authentication will use GitHub Personal Access Tokens or GITHUB_TOKEN

## Consequences

### Positive

- **Zero cost**: Unlimited private repositories with unlimited bandwidth
- **Native integration**: Deep GitHub integration with Actions, Packages, and security scanning
- **No bandwidth charges**: Unlimited pulls without additional costs
- **Built-in security**: Automatic vulnerability scanning and Dependabot alerts
- **Simple authentication**: Use existing GitHub credentials and tokens
- **OCI compliance**: Supports Docker images and OCI artifacts (Helm charts)
- **Easy to learn**: Simple push/pull workflow similar to Docker Hub
- **Automatic cleanup**: Configurable retention policies for old images
- **Fine-grained access**: Per-package permissions and team access control
- **Public/private flexibility**: Easy to switch visibility per package

### Negative

- **Vendor lock-in**: Tied to GitHub platform
- **GitHub dependency**: Requires GitHub organization for best features
- **Limited multi-cloud**: Less ideal if moving away from GitHub
- **Ecosystem maturity**: Newer than Docker Hub, fewer third-party integrations
- **No geographic replication**: Single region storage (may affect pull speeds)

### Trade-offs

- **Free vs. Features**: Free unlimited storage but tied to GitHub ecosystem
- **Simplicity vs. Control**: Easy to use but less control than self-hosted Harbor
- **Integration vs. Flexibility**: Perfect GitHub integration but limited multi-platform support

## Alternatives Considered

### Docker Hub

**Description**: Most popular public container registry with free tier

**Why not chosen**:

- Free tier limited to 1 private repository
- Rate limiting on pulls (200 pulls per 6 hours for free users)
- Paid plans required for team collaboration ($7/user/month)
- No Helm chart OCI support
- Separate authentication from GitHub

**Trade-offs**: Ecosystem maturity vs. cost and rate limits

**When to reconsider**: If we need to publish widely-used public images to the most popular registry

### DigitalOcean Container Registry

**Description**: Managed container registry integrated with DigitalOcean cloud

**Why not chosen**:

- Costs $20/month for basic tier (500GB storage, 1TB bandwidth)
- Additional costs if bandwidth exceeded
- Requires separate authentication from GitHub
- Less integrated with GitHub Actions workflows
- Extra vendor to manage beyond GitHub

**Trade-offs**: Cloud provider integration vs. additional cost and complexity

**When to reconsider**: If we standardize heavily on DigitalOcean and need geographic replication

### Harbor (Self-Hosted)

**Description**: Open-source container registry with advanced features

**Why not chosen**:

- Requires infrastructure to host and maintain (VMs, storage, backups)
- Additional operational overhead (updates, security, monitoring)
- More complex setup and configuration
- Overkill for small company needs
- Team time better spent on applications than registry maintenance

**Trade-offs**: Maximum control and features vs. zero maintenance

**When to reconsider**: If we need advanced features like image replication, project quotas, or air-gapped deployments

### GitLab Container Registry

**Description**: GitLab's integrated container registry

**Why not chosen**:

- Would require migrating from GitHub to GitLab
- Similar capabilities to GitHub Container Registry
- No compelling reason to change version control platform
- Team already familiar with GitHub

**Trade-offs**: Similar features but requires platform migration

### AWS ECR / Google GCR / Azure ACR

**Description**: Cloud provider-managed container registries

**Why not chosen**:

- Additional cost per cloud provider (varies by usage)
- Requires cloud provider account and credentials
- Less integrated with GitHub Actions
- Overkill for hybrid cloud setup
- Extra vendors to manage

**Trade-offs**: Cloud-native features vs. additional cost and complexity

**When to reconsider**: If we standardize on a single cloud provider for all infrastructure

## Implementation Notes

### Small Company Considerations

**Free Tier Benefits**:

- **Storage**: Unlimited private repositories and storage (within reasonable use)
- **Bandwidth**: Unlimited pulls with no bandwidth charges
- **Team access**: Free for all organization members
- **Security scanning**: Built-in vulnerability detection at no cost
- **Retention policies**: Automatic cleanup of old images to save space

**Image Organization Strategy**:

```
ghcr.io/{organization}/{application}:{tag}

Examples:
  ghcr.io/mycompany/web-app:v1.2.3
  ghcr.io/mycompany/api-server:latest
  ghcr.io/mycompany/worker:main-abc123def
```

**Tagging Conventions**:

1. **Semantic versioning**: `v1.2.3` for releases
2. **Git-based tags**: `main-{commit-sha}` for commits
3. **Environment tags**: `staging`, `production` (updated on deploy)
4. **Latest tag**: `latest` pointing to newest stable release
5. **Branch tags**: `{branch-name}` for feature branches

**Helm Chart Storage** (as OCI artifacts):

```bash
# Package Helm chart
helm package ./charts/myapp

# Push to GHCR as OCI artifact
helm push myapp-1.0.0.tgz oci://ghcr.io/mycompany/charts

# Pull Helm chart
helm pull oci://ghcr.io/mycompany/charts/myapp --version 1.0.0
```

### GitHub Actions Integration

**Building and Pushing Images**:

```yaml
name: Build and Push Container

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=ref,event=branch
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix={{branch}}-

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

**Security Scanning**:

```yaml
- name: Scan for vulnerabilities
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ghcr.io/${{ github.repository }}:${{ github.sha }}
    format: 'sarif'
    output: 'trivy-results.sarif'

- name: Upload scan results
  uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: 'trivy-results.sarif'
```

### Authentication Setup

**For GitHub Actions** (recommended):

```yaml
# Uses built-in GITHUB_TOKEN - no setup required
- name: Log in to GHCR
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

**For Kubernetes Clusters**:

```bash
# Create GitHub Personal Access Token with `read:packages` scope
# Then create Kubernetes secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_PAT_TOKEN \
  --docker-email=YOUR_EMAIL
```

**For Local Development**:

```bash
# Authenticate with GitHub CLI
gh auth login

# Or use personal access token
echo $GITHUB_PAT | docker login ghcr.io -u USERNAME --password-stdin
```

### Package Visibility and Permissions

**Repository Visibility**:

- **Private**: Default for organization repositories
- **Public**: Can be made public for open-source images
- **Internal**: Visible to all organization members (GitHub Enterprise)

**Access Control**:

```
Repository Settings → Packages → Package Settings
- Manage teams and collaborators access
- Set fine-grained permissions per package
- Inherit repository permissions or customize
```

### Retention Policies

**Automatic Cleanup Strategy**:

```yaml
# .github/workflows/cleanup-old-images.yml
name: Clean up old container images

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - name: Delete old images
        uses: actions/delete-package-versions@v4
        with:
          package-name: 'myapp'
          package-type: 'container'
          min-versions-to-keep: 10
          delete-only-untagged-versions: true
```

**Manual Retention Configuration**:

- Keep last 10 versions of tagged releases
- Delete untagged images older than 30 days
- Keep all tagged images with semantic versions
- Remove feature branch images after merge

### Image Optimization

**Best Practices**:

1. **Multi-stage builds**: Reduce image size
2. **Layer caching**: Speed up builds
3. **Minimal base images**: Use Alpine or distroless
4. **Vulnerability scanning**: Run Trivy/Grype in CI
5. **Signed images**: Use Cosign for image signing
6. **SBOM generation**: Create software bill of materials

## Integration with Kubernetes

**ImagePullSecrets in Deployments**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
      - name: app
        image: ghcr.io/mycompany/myapp:v1.2.3
      imagePullSecrets:
      - name: ghcr-secret
```

**Helm Chart values.yaml**:

```yaml
image:
  repository: ghcr.io/mycompany/myapp
  tag: v1.2.3
  pullPolicy: IfNotPresent
  pullSecrets:
    - ghcr-secret
```

## Migration Plan

1. **Phase 1: Setup** (Week 1)
   - [ ] Configure GitHub Container Registry access
   - [ ] Create authentication tokens and secrets
   - [ ] Test push/pull workflows

2. **Phase 2: CI/CD Integration** (Week 1-2)
   - [ ] Update GitHub Actions workflows to build and push images
   - [ ] Implement security scanning with Trivy
   - [ ] Set up automatic tagging conventions

3. **Phase 3: Kubernetes Integration** (Week 2)
   - [ ] Create ImagePullSecrets in Kubernetes clusters
   - [ ] Update deployment manifests to use GHCR images
   - [ ] Test image pulls from clusters

4. **Phase 4: Documentation and Cleanup** (Week 3)
   - [ ] Document usage patterns and conventions
   - [ ] Set up retention policies
   - [ ] Remove old Docker Hub dependencies

## References

- [GitHub Container Registry Documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [GitHub Actions and Packages](https://docs.github.com/en/packages/managing-github-packages-using-github-actions-workflows/publishing-and-installing-a-package-with-github-actions)
- [Helm OCI Support](https://helm.sh/docs/topics/registries/)
- [Container Image Security Best Practices](https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/about-supply-chain-security)
- [Trivy Vulnerability Scanner](https://github.com/aquasecurity/trivy)

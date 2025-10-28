# 6. GitHub Actions for CI/CD

Date: 2025-10-19

## Status

Accepted

## Context

We need a CI/CD platform to automate infrastructure deployments, testing, and operations workflows.

For a small company using GitHub for version control, we need a CI/CD platform that:

- **Integrated with GitHub**: Minimal setup and configuration
- **Free tier available**: Cost-effective for small-scale usage
- **Easy to learn**: Simple YAML syntax and good documentation
- **Flexible**: Supports infrastructure automation (Terraform, Ansible, Kubernetes)
- **Secure**: Built-in secrets management and security scanning
- **No infrastructure overhead**: Fully managed, no servers to maintain

## Decision

We will use **GitHub Actions** as our primary CI/CD platform for automating infrastructure deployments and operational workflows.

Specifically:

- GitHub Actions will orchestrate Terraform plan/apply workflows
- GitHub Actions will run Ansible playbooks for configuration and deployment
- GitHub Actions will perform validation, linting, and security scanning
- GitHub Secrets will store sensitive credentials
- Workflow files will be version-controlled in `.github/workflows/`
- Self-hosted runners will be used only when necessary (cloud provider access)

## Consequences

### Positive

- **Zero infrastructure**: No Jenkins servers or agents to maintain
- **Free tier**: 2,000 minutes/month for private repos, unlimited for public
- **Native integration**: Deep GitHub integration (PRs, issues, releases)
- **Easy to learn**: Simple YAML syntax, extensive marketplace
- **Fast setup**: Workflows active immediately after commit
- **Built-in secrets**: Encrypted secret storage per repository
- **Matrix builds**: Test across multiple environments easily
- **Marketplace**: Thousands of pre-built actions
- **Audit trail**: Full history of workflow runs and changes

### Negative

- **Vendor lock-in**: Tied to GitHub platform
- **Minute limits**: Free tier may be insufficient for heavy usage
- **Limited self-hosted**: Self-hosted runners require maintenance
- **Less flexibility**: Not as powerful as Jenkins for complex pipelines
- **Debugging difficulty**: Cannot easily reproduce runs locally
- **Marketplace quality**: Variable quality of community actions

### Trade-offs

- **Simplicity vs. Power**: Easier to use but less flexible than Jenkins
- **Managed vs. Self-hosted**: No maintenance but tied to GitHub
- **Free minutes vs. Cost**: Free tier may require careful workflow optimization

## Alternatives Considered

### Jenkins

**Description**: Self-hosted CI/CD server with extensive plugin ecosystem

**Why not chosen**:

- Requires server infrastructure to host and maintain
- More complex setup and configuration
- Overkill for small company
- Team time better spent on infrastructure than CI/CD maintenance

**Trade-offs**: Maximum flexibility vs. zero maintenance

**When to reconsider**: If we need very complex pipelines or hit GitHub Actions limits

### GitLab CI/CD

**Description**: GitLab's integrated CI/CD platform

**Why not chosen**:

- Would require migrating from GitHub to GitLab
- Similar capabilities to GitHub Actions
- No compelling reason to change version control platform
- Team already familiar with GitHub

**Trade-offs**: Similar features but requires platform migration

### CircleCI / Travis CI

**Description**: Third-party CI/CD services

**Why not chosen**:

- Extra account and integration setup
- Additional cost beyond GitHub
- No advantage over GitHub Actions for our use case
- One less vendor to manage

**Trade-offs**: Specialized CI/CD vs. integrated platform

### Self-hosted Runners Only

**Description**: Use only self-hosted GitHub Actions runners

**Why not chosen**:

- Requires infrastructure and maintenance
- Loses benefit of managed service
- Only use self-hosted when cloud provider access required

**Trade-offs**: Full control vs. zero maintenance

## Implementation Notes

### Small Company Considerations

**Free Tier Management**:

- **Public repositories**: Unlimited minutes (consider making non-sensitive repos public)
- **Private repositories**: 2,000 minutes/month free
- **Minute usage**:
  - Linux runners: 1x multiplier (2,000 minutes)
  - Windows runners: 2x multiplier (1,000 minutes)
  - macOS runners: 10x multiplier (200 minutes)
- **Strategy**: Use Linux runners, optimize workflows, cache dependencies

**Workflow Organization**:

```yaml
.github/
└── workflows/
    ├── terraform-plan.yml       # Terraform plan on PR
    ├── terraform-apply.yml      # Terraform apply on main merge
    ├── ansible-lint.yml         # Ansible syntax and lint checks
    ├── security-scan.yml        # Security scanning (tfsec, checkov)
    ├── pr-validation.yml        # PR checks (format, validate)
    └── destroy-dev.yml          # Cleanup dev environments (scheduled)
```

**Best Practices**:

1. **Terraform Workflows**:
   - Run `terraform plan` on every PR
   - Require manual approval for `terraform apply`
   - Store Terraform state in remote backend
   - Use GitHub Secrets for cloud credentials

2. **Ansible Workflows**:
   - Lint and syntax check on PR
   - Run in check mode before actual deployment
   - Use GitHub Secrets for SSH keys and vault passwords

3. **Security Scanning**:
   - Run tfsec and checkov on every Terraform change
   - Run ansible-lint on every Ansible change
   - Fail builds on high-severity issues

4. **Environment Protection**:
   - Use GitHub Environments for staging/production
   - Require manual approval for production deployments
   - Use environment-specific secrets

5. **Cost Optimization**:
   - Cache dependencies (Terraform providers, Ansible collections)
   - Use `paths` filters to only run relevant workflows
   - Use `concurrency` to cancel duplicate runs
   - Schedule cleanup jobs for dev environments

**Example Terraform Workflow**:

```yaml
name: Terraform Plan

on:
  pull_request:
    paths:
      - 'terraform/**'
      - '.github/workflows/terraform-plan.yml'

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.0

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Init
        run: terraform init
        working-directory: ./terraform/environments/dev

      - name: Terraform Validate
        run: terraform validate
        working-directory: ./terraform/environments/dev

      - name: Terraform Plan
        run: terraform plan -out=tfplan
        working-directory: ./terraform/environments/dev
        env:
          DIGITALOCEAN_TOKEN: ${{ secrets.DIGITALOCEAN_TOKEN }}

      - name: Security Scan
        uses: aquasecurity/tfsec-action@v1.0.0
        with:
          working_directory: ./terraform/environments/dev
```

**Self-Hosted Runners** (only when needed):

- Use for accessing on-premise infrastructure
- Use when cloud provider networking requires private access
- Consider cost: self-hosted runner maintenance vs. GitHub-hosted minutes
- Secure properly: dedicated runner machines, regular updates

**Secrets Management**:

- Store cloud credentials in GitHub Secrets (repository or organization level)
- Use GitHub Environments for environment-specific secrets
- Rotate secrets regularly
- Use DigitalOcean API tokens with limited scopes for security

## Integration with GitOps

GitHub Actions serves as the automation engine for GitOps workflows (see [ADR-0007](0007-gitops-workflow.md)):

1. **Infrastructure Changes**: Terraform workflow runs on PR → apply on merge
2. **Configuration Changes**: Ansible workflow runs on PR → apply on merge
3. **Application Deployment**: Kubernetes manifests → deploy to cluster
4. **Validation**: All changes validated in CI before deployment

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Actions Marketplace](https://github.com/marketplace?type=actions)
- [GitHub Actions Pricing](https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions)
- [Terraform GitHub Actions](https://github.com/hashicorp/setup-terraform)
- [Security Hardening for GitHub Actions](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)

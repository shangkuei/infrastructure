# 7. GitOps Workflow

Date: 2025-10-19

## Status

Accepted

## Context

We need a deployment workflow that ensures all infrastructure and application changes are:

- **Version controlled**: All changes tracked in Git
- **Auditable**: Clear history of who changed what and why
- **Reviewable**: Changes reviewed before deployment
- **Automated**: Deployments triggered by Git operations
- **Consistent**: Same process for all environments

For a small company, we need a workflow that is:

- **Simple to understand**: Easy for small teams to follow
- **Low overhead**: Minimal tools and processes
- **Safe**: Built-in safety checks and rollback capability
- **Scalable**: Can grow with the team and infrastructure

## Decision

We will adopt **GitOps workflow** where Git is the single source of truth for infrastructure and application state.

Specifically:

- **All changes through Git**: Infrastructure and configuration changes made via Git commits
- **Pull request workflow**: Changes reviewed and approved via PRs
- **Automated deployment**: GitHub Actions automatically applies approved changes
- **Environment parity**: Same workflow for dev, staging, and production
- **Declarative configuration**: All infrastructure and apps defined declaratively
- **Immutable artifacts**: Changes create new versions, not in-place modifications

## Consequences

### Positive

- **Single source of truth**: Git repository contains complete infrastructure state
- **Audit trail**: Full history of all changes with commit messages
- **Code review**: All changes reviewed before deployment
- **Rollback capability**: Git revert provides easy rollback
- **Collaboration**: Team members can propose and review changes
- **Automation**: Deployment happens automatically on merge
- **Documentation**: Git history documents decisions and evolution
- **Disaster recovery**: Can rebuild infrastructure from Git

### Negative

- **Git discipline required**: Team must follow Git workflows consistently
- **Learning curve**: New team members need to learn GitOps concepts
- **Initial setup**: Requires CI/CD pipeline configuration
- **Secrets management**: Need secure way to handle sensitive data
- **Debug difficulty**: Cannot make manual changes for quick fixes
- **State drift**: Manual changes outside Git create inconsistency

### Trade-offs

- **Discipline vs. Speed**: Can't make quick manual changes but gain reliability
- **Automation vs. Control**: Less direct control but more consistency
- **Overhead vs. Safety**: More process but fewer production incidents

## Alternatives Considered

### Manual Deployments

**Description**: Operators run Terraform/Ansible commands manually

**Why not chosen**:

- No audit trail of who changed what
- Easy to forget steps or make mistakes
- Difficult to review changes before deployment
- No consistency between environments
- Hard to rollback failed changes

**Trade-offs**: Maximum flexibility vs. reliability and auditability

### ClickOps (Console-based Management)

**Description**: Make changes through cloud provider web consoles

**Why not chosen**:

- No version control or automation
- Configuration drift inevitable
- No code review process
- Impossible to replicate environments
- Violates Infrastructure as Code principles (ADR-0001)

**Trade-offs**: Immediate changes vs. all IaC benefits

### Continuous Deployment (CD) to Production

**Description**: Auto-deploy to production on every commit without approval

**Why not chosen**:

- Too risky for infrastructure changes
- No safety gate before production
- Appropriate for mature applications, not infrastructure
- Manual approval adds important safety check

**Trade-offs**: Speed vs. production safety

### Separate Tools (Flux, ArgoCD)

**Description**: Use dedicated GitOps tools for Kubernetes deployments

**Why not chosen for now**:

- Additional complexity and learning curve
- GitHub Actions sufficient for current scale
- Can add Flux/ArgoCD later for Kubernetes-specific GitOps
- Keep tooling simple initially

**Trade-offs**: Specialized features vs. simplicity

**When to reconsider**: When managing many Kubernetes applications across clusters

## Implementation Notes

### Small Company GitOps Workflow

**Branch Strategy**:

```text
main (production)
  ↑
  └── Pull Request ← feature/add-redis-cluster
  ↑
  └── Pull Request ← fix/update-security-group
```

**Workflow Steps**:

1. **Create feature branch**:

   ```bash
   git checkout -b feature/add-monitoring
   ```

2. **Make changes**:
   - Update Terraform/Ansible code
   - Update documentation (ADR, specs, runbooks)
   - Add tests

3. **Push and create PR**:

   ```bash
   git push origin feature/add-monitoring
   gh pr create --title "Add monitoring stack" --body "Implements ADR-0013"
   ```

4. **Automated checks run** (GitHub Actions):
   - `terraform fmt -check`
   - `terraform validate`
   - `terraform plan` (preview changes)
   - `tfsec` / `checkov` (security scan)
   - `ansible-lint` (if Ansible changes)

5. **Code review**:
   - Team reviews PR
   - Discusses Terraform plan output
   - Approves changes

6. **Merge to main**:
   - PR merged (requires approval)
   - GitHub Actions runs automatically
   - Applies Terraform/Ansible changes
   - Reports success/failure

7. **Rollback if needed**:

   ```bash
   git revert <commit-hash>
   git push origin main
   # GitHub Actions auto-applies rollback
   ```

**Environment Strategy**:

**Dev Environment**:

- Auto-deploy on merge to `main`
- No manual approval required
- Quick iteration and testing

**Staging Environment**:

- Auto-deploy on merge to `main`
- Manual approval for sensitive changes
- Pre-production validation

**Production Environment**:

- Manual approval required (GitHub Environment protection)
- Deploy after staging validation
- Scheduled deployment windows for major changes

**Directory Structure**:

```text
infrastructure/
├── terraform/
│   └── environments/
│       ├── dev/           # Auto-deploy
│       ├── staging/       # Auto-deploy with approval
│       └── production/    # Manual approval required
├── ansible/
│   └── inventory/
│       ├── dev.yml
│       ├── staging.yml
│       └── production.yml
└── .github/
    └── workflows/
        ├── terraform-plan.yml       # On PR: plan all envs
        ├── terraform-apply-dev.yml  # On merge: auto-apply dev
        ├── terraform-apply-stg.yml  # On merge: auto-apply staging
        └── terraform-apply-prd.yml  # On merge: manual approval + apply
```

**Safety Mechanisms**:

1. **Branch Protection**:
   - Require PR reviews before merge
   - Require status checks to pass
   - No direct commits to `main`

2. **Environment Protection**:
   - Production requires manual approval
   - Use GitHub Environments feature
   - Limit who can approve production deployments

3. **Validation Gates**:
   - All PRs must pass validation checks
   - Security scans must pass
   - Terraform plan must be reviewed

4. **Concurrency Control**:
   - Prevent concurrent deployments to same environment
   - Use GitHub Actions concurrency groups
   - Queue deployments if needed

**Example GitHub Actions Workflow**:

```yaml
name: Terraform Apply Production

on:
  push:
    branches: [main]
    paths:
      - 'terraform/environments/production/**'

concurrency:
  group: terraform-production
  cancel-in-progress: false

jobs:
  apply:
    runs-on: ubuntu-latest
    environment:
      name: production
      # Manual approval required

    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Apply
        run: |
          terraform init
          terraform apply -auto-approve
        working-directory: ./terraform/environments/production
        env:
          DIGITALOCEAN_TOKEN: ${{ secrets.DIGITALOCEAN_TOKEN }}

      - name: Notify on Failure
        if: failure()
        run: echo "Deployment failed - rollback required"
```

### Handling Secrets in GitOps

**Never commit secrets to Git**:

- Use GitHub Secrets for credentials
- Use Terraform variables marked as sensitive
- Use Ansible Vault for encrypted values
- Reference secrets, don't embed them

**Secret Storage**:

- **GitHub Secrets**: CI/CD credentials
- **Terraform Variables**: Infrastructure secrets (referenced, not stored)
- **Ansible Vault**: Configuration secrets (encrypted in Git)
- **Cloud KMS**: Production secrets (referenced from cloud)

### Disaster Recovery

**Complete infrastructure rebuild**:

```bash
# 1. Clone repository
git clone https://github.com/company/infrastructure.git

# 2. Retrieve secrets from secure storage
# (GitHub Secrets, password manager, etc.)

# 3. Initialize Terraform
cd terraform/environments/production
terraform init

# 4. Rebuild infrastructure
terraform apply

# 5. Configure with Ansible
cd ../../../ansible
ansible-playbook -i inventory/production.yml playbooks/configure-all.yml

# 6. Deploy applications
kubectl apply -f kubernetes/manifests/
```

## References

- [GitOps Principles](https://opengitops.dev/)
- [GitOps with GitHub Actions](https://github.com/features/actions)
- [Terraform GitOps Workflow](https://www.terraform.io/docs/cloud/guides/recommended-practices/part3.html)
- [ArgoCD](https://argo-cd.readthedocs.io/) (future consideration for Kubernetes)
- [Flux](https://fluxcd.io/) (future consideration for Kubernetes)
- [The GitOps Toolkit](https://fluxcd.io/flux/components/)

# AGENTS.md - AI Assistant Guidance for Infrastructure Project

This document provides guidance to AI assistants (Claude Code, GitHub Copilot, Cursor, etc.)
when working with this hybrid cloud Kubernetes infrastructure repository.
This is the **primary reference** designed to prevent vendor lock-in.

## Documentation Philosophy

**CRITICAL**: Avoid duplication between documentation files:

- **README.md**: Human-readable project overview, quick start, and common operations
- **AGENTS.md** (this file): AI-specific workflows, mandatory rules, and automation guidance
- **CLAUDE.md**: Claude Code-specific tool integration (references AGENTS.md)

**Guideline**: When content is suitable for human users, place it in README.md and reference it from AGENTS.md. Do not duplicate.

## Repository Overview

See [README.md](README.md) for:

- Complete project overview and architecture diagrams
- Quick start guide and prerequisites
- Repository structure details
- Common operations and troubleshooting

**Key Technologies**: Terraform (infrastructure provisioning), Ansible (configuration management),
GitHub Actions (CI/CD), Flux CD (Kubernetes GitOps), Kubernetes (container orchestration),
Cloudflare (edge services)

## AI Assistant Principles

### Infrastructure as Code (IaC) Fundamentals

- **Declarative Configuration**: All infrastructure defined in version-controlled code
- **Immutable Infrastructure**: Prefer replacement over modification
- **Idempotency**: Operations can be safely repeated without side effects
- **Vendor Neutrality**: Avoid cloud provider lock-in where possible
- **Security by Default**: Secrets management, least privilege, encryption at rest/transit

### AI Development Approach

- **Evidence-Based Decisions**: Reference documentation and research before suggesting changes
- **Documentation First**: Update docs/specs before implementation (Rule 1)
- **Test Before Apply**: Validate infrastructure changes in dev/staging before production
- **Security-First Mindset**: Never compromise on security fundamentals
- **Continuous Validation**: Use automated checks throughout development

## AI Assistant Mandatory Rules

**CRITICAL**: These rules must be followed for all infrastructure changes:

### Rule 1: Documentation Before Implementation

**Always update documentation BEFORE writing infrastructure code**:

1. **Review Existing**: Check `docs/` and `specs/` for current architecture
2. **Decision Documentation**: Create or update ADR in `docs/decisions/` explaining WHY
3. **Technical Specification**: Create or update spec in `specs/` defining WHAT and HOW
4. **Runbook Planning**: Plan operational procedures for `docs/runbooks/`
5. **Implementation**: Only then write Terraform/Ansible code
6. **README Update**: Update README.md if user-facing changes
7. **Validation**: Verify documentation matches implementation

**Example Workflow**:

```bash
# CORRECT: Documentation first, then code
1. Create docs/decisions/20241019-add-redis-cache.md
2. Create specs/compute/redis-cluster.md
3. Write terraform/modules/redis/main.tf
4. Create docs/runbooks/redis-maintenance.md

# WRONG: Code without documentation
1. Write terraform/modules/redis/main.tf  # ❌ NO!
```

**Rationale**: Decisions and specs serve as blueprints, prevent rework, ensure knowledge transfer, and catch design issues before implementation.

### Rule 2: Temporary Scripts Location

**All temporary, experimental, or one-off scripts MUST be written to `/tmp`**:

- ✅ **Correct**: `/tmp/test-connection.sh`, `/tmp/debug-ansible.py`
- ❌ **Wrong**: `scripts/temp.sh`, `scripts/test.py`

**scripts/ directory is ONLY for**:

- Production-ready automation scripts
- Version-controlled and maintained scripts
- Scripts that are part of the infrastructure workflow
- Scripts referenced in runbooks or documentation

**Rationale**: Keeps repository clean, prevents accidental commits of experimental code, clear separation between production and temporary code.

### Rule 3: Documentation Update Validation

Before any PR or commit, verify:

1. **ADR exists** for architectural decisions
2. **Spec is updated** with current configuration
3. **README updated** if new components added
4. **Runbook created/updated** for operational tasks
5. **Comments in code** reference documentation

**Enforcement**: AI assistants should refuse to write infrastructure code without documentation, prompt user to create ADR and spec first, and always write temporary scripts to `/tmp`.

### Rule 4: Markdown Lint Compliance

**All Markdown files MUST pass markdown lint validation**:

- **Immediately after creating or editing** any `.md` file, run `markdownlint <file>` to verify compliance
- **Common lint rules**:
  - MD022: Headings must be surrounded by blank lines
  - MD032: Lists must be surrounded by blank lines
  - Consistent header styles and proper list formatting
  - No trailing spaces or unnecessary blank lines
- **Fix all lint errors** immediately after file changes
- **Validate all documentation**: ADRs, specs, runbooks, README files, and architecture docs

**Validation Command**:

```bash
# Validate single file
markdownlint docs/architecture/infrastructure-overview.md

# Validate all markdown files
markdownlint '**/*.md'
```

**Rationale**: Ensures consistent documentation quality, readability, and maintainability across the project.

## Key Workflows and Commands

For basic Terraform, Ansible, and GitHub Actions commands, see [README.md - Common Operations](README.md#common-operations).

### Validation Before Changes

**Always validate before suggesting infrastructure changes**:

```bash
# Format check
terraform fmt -check -recursive

# Validate syntax
terraform validate

# Ansible syntax check
ansible-playbook playbooks/deploy/app.yml --syntax-check

# Lint Ansible
ansible-lint playbooks/
```

### Security Scanning

**Run security scans before committing**:

```bash
# Terraform security scanning
tfsec terraform/
checkov -d terraform/

# Ansible security scanning
ansible-lint --strict ansible/
```

### Testing Workflows

**Test infrastructure changes in dry-run mode**:

```bash
# Terraform plan
terraform plan -out=tfplan

# Ansible check mode with diff
ansible-playbook playbooks/deploy/app.yml --check --diff
```

### Flux GitOps Workflows

**Flux CD manages Kubernetes resources in `kube-system` and `kube-addons` namespaces** (see [ADR-0018](docs/decisions/0018-flux-kubernetes-gitops.md)).

**Workflow for Kubernetes manifests**:

```bash
# 1. Add/modify Kubernetes manifests
# Place in kubernetes/base/kube-system/ or kubernetes/base/kube-addons/

# 2. Validate Kubernetes manifests
kubectl apply --dry-run=server -k kubernetes/base/kube-system/

# 3. Validate Kustomize build
kustomize build kubernetes/base/kube-system/

# 4. Commit and push (Flux will reconcile automatically)
git add kubernetes/
git commit -m "feat(k8s): add monitoring stack to kube-addons"
git push

# 5. Monitor Flux reconciliation
flux get kustomizations
flux logs --level=info

# 6. Force immediate reconciliation (don't wait for interval)
flux reconcile kustomization kube-addons --with-source
```

**Check Flux status**:

```bash
# Overall Flux status
flux check

# Get all Flux resources
flux get all

# Check specific Kustomization
flux get kustomization kube-system

# View Flux logs
flux logs --level=error

# Suspend/Resume reconciliation (for maintenance)
flux suspend kustomization kube-addons
flux resume kustomization kube-addons
```

**Key Principles**:

- **No kubectl apply in CI/CD**: Flux manages Kubernetes resources, not GitHub Actions
- **Continuous reconciliation**: Flux syncs every 5 minutes (configurable)
- **Drift detection**: Manual changes are automatically reverted by Flux
- **Health checks**: Flux verifies resources are healthy before marking as ready
- **Dependencies**: Use Flux Kustomization dependencies for ordered deployment

### Git Commit Convention

Follow Conventional Commits format:

```text
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**: `feat` (new infrastructure), `fix` (bug fix), `docs` (documentation), `refactor` (code restructuring), `test` (adding tests), `chore` (maintenance)

**Examples**:

```bash
feat(terraform): add EKS cluster module
fix(ansible): correct kubernetes version in playbook
docs(specs): update network architecture
chore(deps): update terraform provider versions
```

See [README.md - Contributing](README.md#contributing) for branch strategy and PR process.

## Security & Secrets

### Secrets Management

- **GitHub Secrets**: Store sensitive credentials for CI/CD
- **Terraform Variables**: Use encrypted `.tfvars` files (gitignored)
- **Ansible Vault**: Encrypt sensitive playbook variables
- **External Secrets Operator**: Kubernetes-based secrets management

### Security Best Practices

- **Never commit secrets** to version control
- **Rotate credentials** regularly
- **Use least privilege** access policies
- **Encrypt at rest** using appropriate tools
- **Audit secret access** via logging
- **Network segmentation**: Isolate workloads using VPCs/VNets
- **Enable encryption**: At-rest and in-transit for all sensitive data
- **Patch management**: Regular updates via Ansible
- **Compliance**: Follow CIS benchmarks and industry standards

### Working with Secrets

```bash
# GitHub Secrets (via CLI)
gh secret set AWS_ACCESS_KEY_ID < aws_key.txt

# Ansible Vault
ansible-vault create ansible/group_vars/production/vault.yml
ansible-vault encrypt_string 'secret_password' --name 'db_password'

# Terraform sensitive variables (create terraform.tfvars - gitignored)
cat > terraform/environments/production/terraform.tfvars <<EOF
db_password = "changeme"
api_key     = "secret"
EOF
```

## Development Guidelines

For detailed conventions, see:

- **Terraform**: [terraform/README.md](terraform/README.md) - Module structure, naming, state management, versioning
- **Ansible**: [ansible/README.md](ansible/README.md) - YAML formatting, idempotency, tags, error handling
- **GitHub Actions**: Workflow naming, job dependencies, concurrency control, environment protection

### AI-Specific Guidance

When suggesting infrastructure changes:

1. **Read Context First**: Review relevant ADRs and specs before suggesting changes
2. **Follow Conventions**: Adhere to tool-specific naming, formatting, and structural guidelines
3. **Validate Before Commit**: Run formatters, linters, and security scans
4. **Security First**: Never commit secrets; use proper secret management
5. **Explain Trade-offs**: Discuss pros/cons of different approaches
6. **Reference Documentation**: Link to official documentation for recommendations
7. **Version Awareness**: Check compatibility with pinned versions in tool READMEs
8. **Cross-Platform**: Consider multi-cloud and hybrid cloud scenarios
9. **Idempotency**: Ensure all operations are safe to repeat
10. **Test Before Apply**: Use dry-run mode to preview changes

## Quick Reference

### Documentation Locations

- **Project overview and common operations**: [README.md](README.md)
- **Infrastructure decisions**: [docs/decisions/](docs/decisions/)
- **Service specifications**: [specs/](specs/)
- **Operational procedures**: [docs/runbooks/](docs/runbooks/)
- **Terraform conventions**: [terraform/README.md](terraform/README.md)
- **Ansible conventions**: [ansible/README.md](ansible/README.md)
- **Claude Code integration**: [CLAUDE.md](CLAUDE.md)

### Essential Commands

```bash
# Validation
terraform validate && terraform fmt -check
ansible-playbook playbooks/deploy.yml --syntax-check

# Security Scanning
tfsec terraform/ && checkov -d terraform/
ansible-lint --strict ansible/

# Testing
terraform plan -out=tfplan
ansible-playbook playbooks/deploy.yml --check --diff
```

### External Resources

- **Terraform**: <https://www.terraform.io/docs>
- **Ansible**: <https://docs.ansible.com/>
- **GitHub Actions**: <https://docs.github.com/en/actions>
- **Kubernetes**: <https://kubernetes.io/docs/>
- **Cloudflare**: <https://developers.cloudflare.com/>
- **CIS Benchmarks**: <https://www.cisecurity.org/cis-benchmarks/>

## Contributing

See [README.md - Contributing](README.md#contributing) for the contribution workflow, branch strategy, and PR process.

## License

See [LICENSE](LICENSE) for licensing information.

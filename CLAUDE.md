# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with this hybrid cloud Kubernetes infrastructure repository.

## Primary Reference

**IMPORTANT**: See [AGENTS.md](AGENTS.md) for the primary, vendor-neutral AI assistant guidance. This document only contains Claude Code-specific extensions.

## Claude Code-Specific Features

### File References

When referencing files or code locations in responses, use markdown link syntax for clickable references:

- Files: `[filename.tf](terraform/modules/network/main.tf)`
- Lines: `[filename.yml:42](ansible/playbooks/deploy/app.yml#L42)`
- Ranges: `[requirements.md:10-25](specs/network/requirements.md#L10-L25)`
- Directories: `[docs/decisions/](docs/decisions/)`

### Tool Usage Patterns

**Infrastructure Analysis**:

1. **Glob** for finding files: `**/*.tf`, `**/*.yml`, `**/*.yaml`
2. **Grep** for searching patterns: `resource "aws_`, `- name:`, `module "`
3. **Read** for examining configurations
4. **Task** (subagent_type=Explore) for open-ended codebase exploration

**Making Changes**:

1. **Always Read before Edit/Write** - Required for existing files
2. **TodoWrite** - Structure multi-step infrastructure changes
3. **Bash** - Validate with `terraform validate`, `ansible-lint`
4. **Bash** - Test with `terraform plan`, `ansible-playbook --check`

### Task Management for Infrastructure

Use TodoWrite for complex infrastructure operations:

```text
1. Plan phase: Document decision (ADR) and create spec
2. Implementation: Write Terraform/Ansible code
3. Testing: Validate, lint, security scan
4. Review: Terraform plan review
5. Documentation: Update README and runbooks
```

### Workflow Integration

For validation commands, security scanning, and git commit conventions, see [AGENTS.md - Key Workflows and Commands](AGENTS.md#key-workflows-and-commands).

**Claude Code Specific**: Use TodoWrite tool to track multi-step validation workflows.

### Environment-Specific Guidance

| Environment | Location | Auto-Deploy | Approval | Use Case |
|-------------|----------|-------------|----------|----------|
| Development | `terraform/environments/dev/` | Yes (on merge) | No | Testing |
| Staging | `terraform/environments/staging/` | Manual trigger | Team lead | Pre-prod validation |
| Production | `terraform/environments/production/` | Manual only | Multiple reviewers | Live workloads |

### Quick Reference

For complete documentation on:

- **Validation workflows**: See [AGENTS.md - Validation Before Changes](AGENTS.md#validation-before-changes)
- **Security scanning**: See [AGENTS.md - Security Scanning](AGENTS.md#security-scanning)
- **Git commit convention**: See [AGENTS.md - Git Commit Convention](AGENTS.md#git-commit-convention)
- **Repository structure**: See [AGENTS.md - Repository Structure](AGENTS.md#repository-structure)
- **Secrets management**: See [AGENTS.md - Secrets Management](AGENTS.md#secrets-management)
- **Development guidelines**: See [AGENTS.md - Development Guidelines](AGENTS.md#development-guidelines)
- **Testing strategy**: See [AGENTS.md - Testing Strategy](AGENTS.md#testing-strategy)
- **AI workflows**: See [AGENTS.md - AI Workflow for Infrastructure Changes](AGENTS.md#ai-workflow-for-infrastructure-changes)
- **Security considerations**: See [AGENTS.md - Security Considerations](AGENTS.md#security-considerations)

### Additional Context

- **Project overview**: [README.md](README.md)
- **Terraform guide**: [terraform/README.md](terraform/README.md)
- **Ansible guide**: [ansible/README.md](ansible/README.md)
- **Documentation standards**: [docs/README.md](docs/README.md)
- **Technical specifications**: [specs/README.md](specs/README.md)

# Architectural Decision Records

This directory contains Architectural Decision Records (ADRs) documenting significant infrastructure and design decisions for this project.

## What is an ADR?

An Architectural Decision Record captures an important architectural decision made along with its context and consequences. ADRs help teams:

- Understand why decisions were made
- Avoid rehashing old discussions
- Onboard new team members
- Track the evolution of the architecture

## ADR Format

Each ADR follows this structure:

```markdown
# {Number}. {Title}

Date: YYYY-MM-DD

## Status
{Proposed | Accepted | Deprecated | Superseded by ADR-XXXX}

## Context
What is the issue that we're seeing that is motivating this decision or change?

## Decision
What is the change that we're proposing and/or doing?

## Consequences
What becomes easier or more difficult to do because of this change?

## Alternatives Considered
What other options were evaluated and why were they not chosen?
```

## Naming Convention

ADRs are named: `YYYYMMDD-short-kebab-case-description.md`

Example: `20241019-use-terraform-for-infrastructure.md`

## Status Definitions

- **Proposed**: Under discussion, not yet decided
- **Accepted**: Decision made and implemented
- **Deprecated**: No longer relevant but kept for historical context
- **Superseded**: Replaced by a newer decision (reference the new ADR)

## Index of Decisions

### Infrastructure Tooling

- [0001 - Infrastructure as Code Approach](0001-infrastructure-as-code.md) - Accepted
- [0002 - Terraform as Primary IaC Tool](0002-terraform-primary-tool.md) - Accepted
- [0003 - Ansible for Configuration Management](0003-ansible-configuration-management.md) - Accepted
- [0014 - Cloudflare R2 for Terraform State Storage](0014-cloudflare-r2-terraform-state.md) - Accepted

### Cloud & Edge Services

- [0004 - Cloudflare DNS and Edge Services](0004-cloudflare-dns-services.md) - Accepted
- [0005 - Kubernetes as Container Platform](0005-kubernetes-container-platform.md) - Accepted
- [0013 - DigitalOcean as Primary Cloud Provider](0013-digitalocean-primary-cloud.md) - Accepted

### CI/CD & GitOps

- [0006 - GitHub Actions for CI/CD](0006-github-actions-cicd.md) - Accepted
- [0007 - GitOps Workflow](0007-gitops-workflow.md) - Accepted
- [0010 - GitHub Container Registry](0010-github-container-registry.md) - Accepted

### Networking

- [0009 - Tailscale for Hybrid Cloud Networking](0009-tailscale-hybrid-networking.md) - Accepted

### Security

- [0008 - Secret Management Strategy](0008-secret-management.md) - Accepted

## Creating a New ADR

1. **Identify the need**: Recognize a decision that needs documentation
2. **Research alternatives**: Evaluate different options
3. **Draft the ADR**: Use the template above
4. **Status: Proposed**: Mark as proposed for discussion
5. **Review and discuss**: Get team feedback
6. **Status: Accepted**: Mark as accepted when consensus is reached
7. **Implement**: Put the decision into practice
8. **Reference**: Link to the ADR in related code and documentation

## Superseding an ADR

When a decision is replaced:

1. Update the old ADR status to `Superseded by ADR-XXXX`
2. Create a new ADR with status `Superseded ADR-YYYY`
3. Explain why the old decision no longer applies
4. Keep both ADRs for historical context

## Best Practices

- **Write ADRs when the decision is made**, not after
- **Keep ADRs concise** but complete
- **Be honest about trade-offs** and consequences
- **Document alternatives** that were considered
- **Link related ADRs** for context
- **Don't delete ADRs** - mark them as deprecated or superseded
- **Update status** as decisions evolve
- **Reference ADRs** in code comments and pull requests

## Template

Copy this template for new ADRs:

```markdown
# {Number}. {Title}

Date: YYYY-MM-DD

## Status
Proposed

## Context
Describe the forces at play, including technological, political, social, and
project-specific. The context should be neutral and factual, not argumentative.

## Decision
State the decision and key rationale. Be specific about what is being decided
and why this particular option was chosen.

## Consequences
Describe the resulting context after applying the decision. Include both
positive and negative consequences. Be specific about trade-offs.

## Alternatives Considered
List other options that were evaluated. For each, briefly explain:
- What the alternative was
- Why it was not chosen
- Key trade-offs compared to the chosen decision
```

## Further Reading

- [Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) by Michael Nygard
- [ADR GitHub Organization](https://adr.github.io/)
- [Architecture Decision Records](https://docs.aws.amazon.com/prescriptive-guidance/latest/architectural-decision-records/welcome.html) - AWS Guide

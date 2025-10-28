# 2. Terraform as Primary IaC Tool

Date: 2025-10-19

## Status

Accepted

## Context

Following [ADR-0001](0001-infrastructure-as-code.md), we need to select a specific Infrastructure as Code tool for provisioning cloud resources across our hybrid environment.

For a small company, we need a tool that is:

- **Multi-cloud capable**: Works across DigitalOcean and on-premise, with future AWS/Azure/GCP support
- **Free and open source**: No licensing costs for small-scale use
- **Well-documented**: Strong community support and learning resources
- **Declarative**: Easy to understand and maintain
- **State management**: Tracks what's deployed vs. what should be deployed
- **Actively maintained**: Regular updates and security patches

## Decision

We will use **Terraform** by HashiCorp as our primary Infrastructure as Code tool for provisioning cloud resources.

Specifically:

- Terraform will manage all cloud infrastructure resources (VMs, networks, storage, Kubernetes clusters)
- Terraform modules will be created for reusable components
- State will be stored in Cloudflare R2 (S3-compatible) for collaboration and locking
- Each environment (dev/staging/production) will have separate state files
- Terraform version will be pinned in version control (v1.11+ required for R2 native locking)

## Consequences

### Positive

- **Multi-cloud native**: Single tool for all cloud providers
- **Large ecosystem**: Thousands of providers and modules available
- **Free and open source**: No cost for small-scale deployments
- **HCL syntax**: Readable and easy to learn
- **Strong community**: Extensive documentation, examples, and support
- **Plan before apply**: Preview changes before executing
- **Modular design**: Reusable components reduce duplication
- **Industry standard**: Widely adopted, good for learning and career growth

### Negative

- **State management complexity**: Remote state requires careful handling
- **Learning curve**: Terraform-specific concepts (providers, resources, data sources)
- **State lock conflicts**: Team coordination needed during concurrent changes
- **Provider limitations**: Some cloud features lag behind provider releases
- **HCL limitations**: Not a full programming language (by design)

### Trade-offs

- **Declarative vs. Imperative**: Less flexibility but more predictable
- **State management**: Requires remote backend setup but enables collaboration
- **Provider dependency**: Relies on provider quality but gains multi-cloud support

## Alternatives Considered

### Pulumi

**Description**: Infrastructure as Code using real programming languages (TypeScript, Python, Go)

**Why not chosen**:

- Smaller community and ecosystem
- More complex for simple use cases
- Team prefers declarative approach
- May reconsider if we need complex logic

**Trade-offs**: More programming flexibility vs. simpler declarative syntax

### OpenTofu

**Description**: Open source fork of Terraform following HashiCorp's license change

**Why not chosen**:

- Too new and ecosystem not yet mature
- Terraform's BSL license acceptable for our small-scale use
- Will monitor and may migrate if ecosystem matures

**Trade-offs**: True open source vs. proven stability

### Cloud-Specific Tools (CloudFormation, ARM, Deployment Manager)

**Description**: Native IaC tools for AWS, Azure, GCP respectively

**Why not chosen**:

- Creates vendor lock-in to single cloud provider
- Need to learn and maintain multiple tools
- Doesn't work for hybrid/multi-cloud environment
- No support for on-premise infrastructure

**Trade-offs**: Native integration vs. cloud portability

### Ansible for Provisioning

**Description**: Use Ansible for both provisioning and configuration

**Why not chosen**:

- Ansible better suited for configuration management
- Terraform's declarative model better for infrastructure state
- Ansible cloud modules less mature than Terraform providers
- We'll use Ansible for its strengths (see ADR-0003)

**Trade-offs**: Single tool vs. best tool for each job

## Implementation Notes

### Small Company Considerations

**State Backend**:

- Start with local state for learning and testing
- Move to remote backend (Cloudflare R2 with S3 compatibility) when collaborating
- Use native state locking (`use_lockfile`) to prevent conflicts (Terraform v1.10+)
- See [ADR-0014: Cloudflare R2 for Terraform State Storage](0014-cloudflare-r2-terraform-state.md)

**Module Organization**:

- Keep modules simple initially
- Create modules when patterns emerge (don't over-engineer)
- Use public Terraform Registry modules where appropriate

**Cost Management**:

- Use `terraform plan` to estimate costs before applying
- Tag all resources with environment and owner for cost tracking
- Destroy dev/test environments when not in use
- Use free tiers and spot/preemptible instances where possible

**Version Control**:

- Pin Terraform version in `.terraform-lock.hcl`
- Pin provider versions in `versions.tf`
- Use semantic versioning for custom modules

## References

- [Terraform Documentation](https://www.terraform.io/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Terraform Registry](https://registry.terraform.io/)
- [HashiCorp Learn](https://learn.hashicorp.com/terraform)
- [Terraform State Management](https://www.terraform.io/docs/language/state/index.html)
- [ADR-0014: Cloudflare R2 for Terraform State Storage](0014-cloudflare-r2-terraform-state.md)
- [Research-0018: Terraform State Management](../research/0018-terraform-state-management.md)

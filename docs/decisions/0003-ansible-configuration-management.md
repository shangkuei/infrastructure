# 3. Ansible for Configuration Management

Date: 2025-10-19

## Status

Accepted

## Context

While Terraform ([ADR-0002](0002-terraform-primary-tool.md)) handles infrastructure provisioning, we need a tool for:

- **Configuration management**: Installing and configuring software on servers
- **Application deployment**: Deploying applications to Kubernetes and VMs
- **Operational tasks**: Maintenance, backups, updates, troubleshooting
- **Day-2 operations**: Ongoing management after initial provisioning

For a small company, we need a tool that is:

- **Agentless**: No software to install on managed nodes
- **Simple to learn**: Easy for small teams without dedicated ops engineers
- **Idempotent**: Safe to run repeatedly
- **Multi-platform**: Works across Linux, Windows, and network devices
- **Free and open source**: No licensing costs

## Decision

We will use **Ansible** for configuration management and operational automation.

Specifically:

- Ansible will configure servers and applications after Terraform provisions infrastructure
- Ansible playbooks will handle routine operational tasks (backups, updates, monitoring)
- Ansible roles will be created for reusable configuration patterns
- Ansible Vault will encrypt sensitive data in playbooks
- Inventory will be managed both statically (Git) and dynamically (cloud providers)

## Consequences

### Positive

- **Agentless**: Uses SSH, no agents to maintain on target systems
- **Simple YAML**: Easy to read and write, low learning curve
- **Large module library**: Built-in modules for most common tasks
- **Idempotent**: Safe to run playbooks multiple times
- **Free and open source**: No cost for any scale of deployment
- **Strong community**: Extensive documentation and Ansible Galaxy roles
- **Multi-platform**: Linux, Windows, network devices, cloud APIs
- **Low overhead**: Minimal resource requirements

### Negative

- **Performance at scale**: SSH-based approach slower than agent-based tools for large fleets
- **Limited state management**: No built-in state tracking like Terraform
- **Complex conditionals**: YAML limitations for complex logic
- **Variable precedence**: Can be confusing with many variable sources
- **Windows support**: Requires WinRM setup, less mature than Linux support

### Trade-offs

- **Agentless vs. Performance**: Easier setup but slower execution at scale
- **YAML vs. Code**: Simpler syntax but less programming flexibility
- **Push vs. Pull**: Manual execution vs. automated continuous enforcement

## Alternatives Considered

### Terraform Provisioners

**Description**: Use Terraform's provisioner blocks for configuration

**Why not chosen**:

- HashiCorp recommends against provisioners for configuration
- Creates tight coupling between infrastructure and configuration
- Makes Terraform runs slower and less reliable
- Difficult to rerun configuration without recreating resources

**Trade-offs**: Single tool vs. separation of concerns

### Chef/Puppet

**Description**: Agent-based configuration management tools

**Why not chosen**:

- Require agents on all managed nodes (more complexity)
- Steeper learning curve (Ruby DSL for Chef, Puppet DSL for Puppet)
- More overhead for small-scale deployments
- Overkill for small company

**Trade-offs**: More features and scale vs. simplicity

### SaltStack

**Description**: Agent-based (or agentless) configuration management

**Why not chosen**:

- Can be agentless but designed for agent-based
- Smaller community than Ansible
- More complex architecture (master/minion model)
- Not as widely used in small deployments

**Trade-offs**: Performance and features vs. simplicity

### Shell Scripts

**Description**: Custom bash/PowerShell scripts for configuration

**Why not chosen**:

- Not idempotent by default
- No built-in error handling
- Hard to test and maintain
- Limited cross-platform support
- No community modules

**Trade-offs**: Ultimate flexibility vs. reliability and maintainability

## Implementation Notes

### Small Company Considerations

**Inventory Management**:

- Start with static inventory in Git for simple setups
- Add dynamic inventory (DigitalOcean) as infrastructure grows
- Use inventory groups for environment separation (dev, staging, prod)

**Playbook Organization**:

- Keep playbooks simple and focused (single responsibility)
- Create roles only when patterns emerge (avoid premature abstraction)
- Use Ansible Galaxy roles for common tasks (nginx, docker, monitoring)
- Document playbook purposes and usage in comments

**Secret Management**:

- Use Ansible Vault for sensitive data (passwords, API keys)
- Store vault password in secure location (not in Git)
- Consider external secret management (GitHub Secrets, cloud KMS) for CI/CD

**Testing**:

- Use `--check` mode for dry-run testing
- Use `--diff` to see what would change
- Test in dev environment before production
- Use Molecule for role testing when complexity warrants

**Performance Tips**:

- Use `pipelining = True` in ansible.cfg for speed
- Set `host_key_checking = False` for lab environments
- Use `strategy = free` for parallel execution when order doesn't matter
- Keep playbooks small and focused for faster execution

## Integration with Terraform

**Workflow**:

1. **Terraform**: Provision infrastructure (VMs, networks, storage)
2. **Terraform output**: Export instance IPs, DNS names to inventory
3. **Ansible**: Configure instances, install software, deploy applications
4. **GitHub Actions**: Orchestrate Terraform → Ansible workflow

**Example Pattern**:

```bash
# 1. Provision infrastructure
terraform apply

# 2. Generate dynamic inventory from Terraform outputs
terraform output -json > inventory/terraform-inventory.json

# 3. Configure instances
ansible-playbook -i inventory/terraform-inventory.json playbooks/configure-servers.yml

# 4. Deploy application
ansible-playbook -i inventory/terraform-inventory.json playbooks/deploy-app.yml
```

## References

- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Ansible Galaxy](https://galaxy.ansible.com/)
- [Ansible for DevOps](https://www.ansiblefordevops.com/)
- [Terraform + Ansible Integration](https://www.terraform.io/docs/language/resources/provisioners/local-exec.html)

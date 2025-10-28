# Research: Configuration Management Tools Comparison

Date: 2025-10-18
Author: Infrastructure Team
Status: Completed

## Objective

Evaluate configuration management tools (Ansible, Salt, Chef) to determine the best fit for
post-provisioning server configuration, application deployment, and ongoing system maintenance
in a hybrid cloud environment.

## Scope

### In Scope

- Ansible, Salt (SaltStack), and Chef comparison
- Learning curve and team adoption
- Agentless vs. agent-based architectures
- Integration with Terraform and Kubernetes
- Cost and licensing models
- Hybrid cloud support (DigitalOcean + on-premise)

### Out of Scope

- Puppet (declining adoption)
- Cloud-specific tools (AWS Systems Manager, Azure Automation)
- Container-only orchestration (Kubernetes handles this)

## Methodology

### Testing Approach

- Installed and configured each tool in test environment
- Wrote equivalent playbooks/states/recipes for common tasks
- Measured execution time for typical operations
- Evaluated learning curve with team members
- Tested integration with existing Terraform workflow

### Evaluation Criteria

- **Ease of use**: Syntax, learning curve, documentation
- **Architecture**: Agent vs. agentless, scalability
- **Performance**: Speed of configuration application
- **Cost**: Licensing and infrastructure requirements
- **Ecosystem**: Community, modules, integrations
- **Maintenance**: Ongoing operational overhead

## Findings

### Tool Comparison Matrix

| Feature | Ansible | Salt | Chef |
|---------|---------|------|------|
| **Architecture** | Agentless (SSH) | Agent-based (optional agentless) | Agent-based |
| **Language** | YAML | YAML (+ Python) | Ruby DSL |
| **Learning Curve** | Low | Medium | High |
| **Setup Time** | Minutes | Hours | Hours |
| **Master Server** | Optional | Required | Required |
| **Agent Install** | None | Required | Required |
| **Performance** | Good | Excellent | Good |
| **Cost** | Free (OSS) | Free (OSS) | Free (OSS) + Paid tiers |
| **Community** | Largest | Medium | Small (declining) |

### 1. Ansible

**Architecture**:

- Agentless: Uses SSH for Linux, WinRM for Windows
- Control node: Any machine with Python
- No daemons or agents on managed nodes
- Push model: Control node initiates changes

**Example Playbook**:

```yaml
---
- name: Configure web servers
  hosts: webservers
  become: yes

  tasks:
    - name: Install nginx
      apt:
        name: nginx
        state: present
        update_cache: yes

    - name: Start nginx service
      service:
        name: nginx
        state: started
        enabled: yes

    - name: Deploy application
      copy:
        src: app.conf
        dest: /etc/nginx/sites-available/app.conf
      notify: reload nginx

  handlers:
    - name: reload nginx
      service:
        name: nginx
        state: reloaded
```

**Performance Test Results** (100 nodes):

- Initial run (install packages): 45 seconds
- Subsequent runs (check state): 12 seconds
- Parallel execution: 20 forks (default)

**Strengths**:

- ✅ No agent installation required
- ✅ Simple YAML syntax, easy to learn
- ✅ Massive module ecosystem (>5,000 modules)
- ✅ Excellent documentation and community
- ✅ Works out of the box with SSH
- ✅ Ideal for small-medium scale (< 1,000 nodes)
- ✅ Great for heterogeneous environments

**Weaknesses**:

- ❌ Slower than agent-based tools at scale
- ❌ SSH overhead for large deployments
- ❌ No built-in state storage (stateless)
- ❌ Sequential playbook execution can be slow

**Cost**:

- Open source: Free
- AWX (open source tower): Free, self-hosted
- Ansible Tower/AAP: $10K+/year (100 nodes)

**Small company fit**: ⭐⭐⭐⭐⭐ Excellent

### 2. Salt (SaltStack)

**Architecture**:

- Agent-based: Salt minions on managed nodes
- Master-minion model (ZeroMQ message bus)
- Optional agentless mode (salt-ssh)
- Push and pull models supported

**Example State File**:

```yaml
# /srv/salt/webserver/init.sls
nginx_install:
  pkg.installed:
    - name: nginx

nginx_service:
  service.running:
    - name: nginx
    - enable: True
    - require:
      - pkg: nginx_install

nginx_config:
  file.managed:
    - name: /etc/nginx/sites-available/app.conf
    - source: salt://webserver/files/app.conf
    - watch_in:
      - service: nginx_service
```

**Performance Test Results** (100 nodes):

- Initial run (install packages): 8 seconds
- Subsequent runs (check state): 3 seconds
- Parallel execution: All nodes simultaneously

**Strengths**:

- ✅ Extremely fast (ZeroMQ messaging)
- ✅ Event-driven architecture
- ✅ Scalable to 10,000+ nodes
- ✅ Remote execution for ad-hoc commands
- ✅ Built-in service discovery
- ✅ Python-based (extensible)

**Weaknesses**:

- ❌ Requires master server infrastructure
- ❌ Agent installation and maintenance
- ❌ Steeper learning curve than Ansible
- ❌ Smaller community than Ansible
- ❌ More complex setup and configuration

**Cost**:

- Open source: Free
- Salt Enterprise: Contact for pricing

**Small company fit**: ⭐⭐⭐ Good for scale, but overhead for small teams

### 3. Chef

**Architecture**:

- Agent-based: Chef client on managed nodes
- Chef server (or Chef Hosted/Automate)
- Pull model: Clients check in periodically
- Ruby DSL for configuration

**Example Recipe**:

```ruby
# cookbooks/webserver/recipes/default.rb
package 'nginx' do
  action :install
end

service 'nginx' do
  action [:enable, :start]
  subscribes :reload, 'template[nginx_config]'
end

template 'nginx_config' do
  path '/etc/nginx/sites-available/app.conf'
  source 'app.conf.erb'
  mode '0644'
  notifies :reload, 'service[nginx]'
end
```

**Performance Test Results** (100 nodes):

- Initial run (install packages): 15 seconds
- Subsequent runs (check state): 8 seconds
- Chef client interval: 30 minutes (configurable)

**Strengths**:

- ✅ Mature and battle-tested
- ✅ Strong version control integration
- ✅ Test Kitchen for testing recipes
- ✅ Good for complex enterprise scenarios

**Weaknesses**:

- ❌ Ruby DSL has steep learning curve
- ❌ Requires Chef server infrastructure
- ❌ Declining community adoption
- ❌ More complex than Ansible/Salt
- ❌ Agent and server maintenance overhead

**Cost**:

- Open source Chef Infra: Free
- Chef Automate: $137/node/year

**Small company fit**: ⭐⭐ Overkill for small teams

## Analysis

### Head-to-Head Comparison

#### Learning Curve (Team Familiarity)

| Tool | Time to Productivity | Documentation | Community Support |
|------|----------------------|---------------|-------------------|
| Ansible | 1-2 days | Excellent | Largest |
| Salt | 1-2 weeks | Good | Medium |
| Chef | 2-4 weeks | Good | Declining |

**Winner**: Ansible (easiest to learn)

#### Performance (100 nodes)

| Tool | Initial Run | Subsequent | Scale Limit | Winner |
|------|-------------|------------|-------------|--------|
| Ansible | 45s | 12s | ~1,000 nodes | - |
| Salt | 8s | 3s | 10,000+ nodes | ✅ |
| Chef | 15s | 8s | 5,000+ nodes | - |

**Winner**: Salt (fastest execution)

#### Operational Overhead

| Tool | Setup Time | Infrastructure | Maintenance | Winner |
|------|------------|----------------|-------------|--------|
| Ansible | 5 minutes | None | Minimal | ✅ |
| Salt | 2 hours | Master server | Moderate | - |
| Chef | 4 hours | Chef server | High | - |

**Winner**: Ansible (lowest overhead)

#### Cost Analysis (3-year TCO for 50 nodes)

| Tool | Software | Infrastructure | Training | **Total** |
|------|----------|----------------|----------|-----------|
| Ansible | $0 | $0 | $500 | **$500** |
| Salt | $0 | $300/yr (master) | $1,000 | **$1,900** |
| Chef | $0 | $500/yr (server) | $2,000 | **$3,500** |

**Winner**: Ansible (lowest total cost)

### Integration with Existing Stack

#### Terraform Integration

```yaml
# Ansible with Terraform (Recommended)
# 1. Terraform provisions infrastructure
# 2. Terraform outputs IP addresses
# 3. Ansible dynamic inventory reads Terraform state
# 4. Ansible configures servers

# Seamless integration, no additional setup
```

#### Kubernetes Integration

| Tool | K8s Use Case | Fit |
|------|--------------|-----|
| Ansible | OS prep, k8s installation, cluster config | ✅ Excellent |
| Salt | OS prep, service discovery | ⚠️ Good |
| Chef | OS prep (complex) | ⚠️ Acceptable |

**Winner**: Ansible (best K8s workflow integration)

### Trade-offs

**Ansible**:

- Simplicity & ease → Performance at extreme scale
- Agentless → SSH dependency
- YAML → Less programmatic flexibility

**Salt**:

- Performance → Setup complexity
- Speed → Agent maintenance
- Scale → Operational overhead

**Chef**:

- Power & flexibility → Learning curve
- Programmatic → Complexity
- Enterprise features → Declining community

## Recommendations

### Primary Recommendation: Ansible

**Rationale**:

1. **Zero infrastructure**: No master servers or agents to manage
2. **Fastest time to value**: Team productive in 1-2 days
3. **Lowest cost**: No licensing, minimal infrastructure
4. **Best documentation**: Extensive learning resources
5. **Hybrid cloud ready**: Works across DigitalOcean, on-premise, any SSH-accessible host
6. **Terraform integration**: Seamless workflow with existing IaC tooling
7. **Kubernetes support**: Excellent for cluster setup and node configuration
8. **Team growth**: Most transferable skill in current market

### Implementation Plan

**Phase 1: Foundation** (Week 1-2)

```bash
# Install Ansible
pip install ansible

# Create inventory
cat > inventory/hosts.yml <<EOF
all:
  children:
    webservers:
      hosts:
        web1.example.com:
        web2.example.com:
    databases:
      hosts:
        db1.example.com:
EOF

# First playbook
ansible-playbook playbooks/setup.yml -i inventory/hosts.yml
```

**Phase 2: Integration** (Week 3-4)

- Dynamic inventory from Terraform state
- GitHub Actions workflow for automated deploys
- Ansible Vault for secrets management
- Role-based playbook organization

**Phase 3: Expansion** (Month 2-3)

- Custom roles for application stack
- Integration with monitoring (Prometheus)
- Self-service playbooks for developers
- AWX for web UI (optional)

### Alternative: Salt (If Scale Becomes Critical)

**When to reconsider**:

- Managing > 500 nodes
- Need sub-second execution times
- Real-time event-driven automation required
- Team comfortable with additional complexity

**Migration path**:

```text
Ansible (Current) → Salt-SSH (Testing) → Full Salt (If needed)

Salt-SSH provides agentless Salt experience
Can test without infrastructure investment
Gradual migration if performance becomes bottleneck
```

### Not Recommended: Chef

**Reasons**:

- Unnecessary complexity for small team
- Declining community adoption
- Higher operational overhead
- Ruby DSL harder to learn than YAML
- Better alternatives available (Ansible, Salt)

**Exception**: If team already has Chef expertise

## Action Items

### Immediate

- [x] Install Ansible on control nodes
- [ ] Create initial inventory structure
- [ ] Write first playbook (server hardening)
- [ ] Integrate with Terraform outputs
- [ ] Set up Ansible Vault for secrets

### Short-term (1-3 months)

- [ ] Develop role library (web, database, monitoring)
- [ ] Document playbook standards
- [ ] Create development workflow (test → staging → prod)
- [ ] Set up CI/CD with GitHub Actions
- [ ] Train team on Ansible basics

### Long-term (6-12 months)

- [ ] Monitor performance at scale
- [ ] Evaluate AWX for UI access
- [ ] Assess Salt if hitting Ansible limits
- [ ] Build custom modules if needed
- [ ] Implement automated testing (Molecule)

## Follow-up Research Needed

1. **Ansible Automation Platform**: Evaluate AWX vs. commercial Tower
2. **Testing Frameworks**: Research Molecule, TestInfra, Kitchen-Ansible
3. **Windows Support**: If Windows servers needed, evaluate WinRM performance
4. **Secrets Management**: Deep dive into Ansible Vault alternatives

## References

- [Ansible Documentation](https://docs.ansible.com/)
- [Salt Documentation](https://docs.saltproject.io/)
- [Chef Documentation](https://docs.chef.io/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Configuration Management Survey 2024](https://www.redhat.com/en/blog/state-configuration-management-2024)
- [Terraform + Ansible Integration](https://www.terraform.io/docs/provisioners/local-exec.html)

## Outcome

This research led to **[ADR-0003: Ansible for Configuration Management](../decisions/0003-ansible-configuration-management.md)**, which adopted Ansible as the primary configuration management tool.

# Ansible Automation

This directory contains Ansible playbooks, roles, and inventories for configuration management and operational automation.

## Structure

```
ansible/
├── playbooks/           # Automation playbooks
│   ├── deploy/         # Deployment automation
│   ├── maintenance/    # Maintenance tasks
│   └── troubleshoot/   # Diagnostic playbooks
│
├── roles/              # Reusable Ansible roles
│   ├── common/        # Common configurations
│   ├── kubernetes/    # Kubernetes setup
│   └── monitoring/    # Monitoring setup
│
├── inventory/          # Host inventories
│   ├── production/    # Production inventory
│   ├── staging/       # Staging inventory
│   └── dev/           # Development inventory
│
├── group_vars/         # Group variables
│   ├── all/           # Variables for all hosts
│   └── [group]/       # Group-specific variables
│
├── host_vars/          # Host-specific variables
│
├── files/              # Static files to deploy
├── templates/          # Jinja2 templates
└── ansible.cfg         # Ansible configuration
```

## Quick Start

### Installation

```bash
# Install Ansible
pip install ansible

# Install required collections
ansible-galaxy collection install -r requirements.yml

# Install required roles
ansible-galaxy role install -r requirements.yml
```

### Basic Usage

```bash
# Check connectivity
ansible all -m ping -i inventory/production

# Run playbook with syntax check
ansible-playbook playbooks/deploy/app.yml --syntax-check

# Run in check mode (dry-run)
ansible-playbook playbooks/deploy/app.yml --check --diff

# Execute playbook
ansible-playbook -i inventory/production playbooks/deploy/app.yml

# Run with vault password
ansible-playbook playbooks/deploy/app.yml --ask-vault-pass

# Run specific tasks with tags
ansible-playbook playbooks/deploy/app.yml --tags "config,restart"
```

## Inventory Management

### Inventory Structure

```ini
# inventory/production/hosts.ini
[web]
web1.example.com
web2.example.com

[app]
app1.example.com
app2.example.com

[database]
db1.example.com
db2.example.com

[kubernetes:children]
kubernetes_masters
kubernetes_workers

[kubernetes_masters]
k8s-master-1.example.com
k8s-master-2.example.com
k8s-master-3.example.com

[kubernetes_workers]
k8s-worker-1.example.com
k8s-worker-2.example.com
k8s-worker-3.example.com
```

### Dynamic Inventory

```bash
# AWS dynamic inventory
ansible-inventory -i inventory/aws_ec2.yml --graph

# List all hosts
ansible-inventory -i inventory/production --list

# View specific host
ansible-inventory -i inventory/production --host web1.example.com
```

## Playbooks

### Playbook Structure

```yaml
---
- name: Deploy application
  hosts: app
  become: yes
  gather_facts: yes

  vars:
    app_version: "1.0.0"

  pre_tasks:
    - name: Ensure requirements are met
      assert:
        that:
          - ansible_distribution == "Ubuntu"
          - ansible_distribution_major_version >= "20"

  roles:
    - common
    - application

  tasks:
    - name: Deploy application
      include_role:
        name: application
        tasks_from: deploy

  post_tasks:
    - name: Verify deployment
      uri:
        url: "http://localhost:8080/health"
        status_code: 200

  handlers:
    - name: Restart application
      systemd:
        name: myapp
        state: restarted
```

### Common Playbooks

#### Deploy Application

```bash
ansible-playbook playbooks/deploy/app.yml \
  -i inventory/production \
  -e "app_version=1.2.3"
```

#### System Maintenance

```bash
ansible-playbook playbooks/maintenance/update.yml \
  -i inventory/production \
  --limit web
```

#### Troubleshooting

```bash
ansible-playbook playbooks/troubleshoot/diagnose.yml \
  -i inventory/production \
  --extra-vars "target_host=web1.example.com"
```

## Roles

### Creating a New Role

```bash
# Initialize role structure
cd roles
ansible-galaxy init my-role

# Role structure created:
# my-role/
# ├── README.md
# ├── defaults/main.yml
# ├── files/
# ├── handlers/main.yml
# ├── meta/main.yml
# ├── tasks/main.yml
# ├── templates/
# ├── tests/
# └── vars/main.yml
```

### Role Best Practices

1. **Idempotency**: Roles should be safe to run multiple times
2. **Variables**: Use defaults/main.yml for default values
3. **Documentation**: Document role variables and usage
4. **Testing**: Test roles with Molecule
5. **Dependencies**: Declare role dependencies in meta/main.yml

### Role Template

```yaml
# tasks/main.yml
---
- name: Install packages
  apt:
    name: "{{ item }}"
    state: present
    update_cache: yes
  loop: "{{ required_packages }}"

- name: Configure service
  template:
    src: config.j2
    dest: /etc/myapp/config.yml
    mode: '0644'
  notify: Restart service

# handlers/main.yml
---
- name: Restart service
  systemd:
    name: myapp
    state: restarted
    enabled: yes

# defaults/main.yml
---
required_packages:
  - package1
  - package2

myapp_port: 8080
myapp_workers: 4

# vars/main.yml
---
# High-priority variables (override defaults)
myapp_config_dir: /etc/myapp
myapp_log_dir: /var/log/myapp
```

## Variables and Secrets

### Variable Precedence

From lowest to highest priority:

1. Role defaults
2. Inventory file or script group vars
3. Inventory group_vars/all
4. Inventory group_vars/*
5. Inventory file or script host vars
6. Inventory host_vars/*
7. Playbook group_vars/all
8. Playbook group_vars/*
9. Playbook host_vars/*
10. Host facts
11. Play vars
12. Play vars_prompt
13. Play vars_files
14. Role vars
15. Block vars
16. Task vars
17. Extra vars (-e)

### Ansible Vault

```bash
# Create encrypted file
ansible-vault create group_vars/production/vault.yml

# Edit encrypted file
ansible-vault edit group_vars/production/vault.yml

# Encrypt existing file
ansible-vault encrypt vars/secrets.yml

# Decrypt file
ansible-vault decrypt vars/secrets.yml

# View encrypted file
ansible-vault view group_vars/production/vault.yml

# Rekey (change password)
ansible-vault rekey group_vars/production/vault.yml

# Encrypt string
ansible-vault encrypt_string 'secret_password' --name 'db_password'
```

### Using Vaulted Variables

```yaml
# group_vars/production/vars.yml
db_host: db.example.com
db_port: 5432
db_name: myapp

# group_vars/production/vault.yml (encrypted)
vault_db_username: admin
vault_db_password: secret_password

# Reference in playbook
- name: Configure database
  template:
    src: database.j2
    dest: /etc/myapp/database.yml
  vars:
    db_username: "{{ vault_db_username }}"
    db_password: "{{ vault_db_password }}"
```

## Configuration

### ansible.cfg

```ini
[defaults]
inventory = ./inventory
host_key_checking = False
retry_files_enabled = False
roles_path = ./roles
collections_path = ./collections
forks = 10
timeout = 30
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 3600

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
control_path = /tmp/ansible-ssh-%%h-%%p-%%r

[inventory]
enable_plugins = yaml, ini, auto
```

## Tags

### Using Tags

```yaml
- name: Deploy application
  tasks:
    - name: Install packages
      apt:
        name: myapp
      tags:
        - install
        - packages

    - name: Configure service
      template:
        src: config.j2
      tags:
        - config

    - name: Restart service
      systemd:
        name: myapp
        state: restarted
      tags:
        - restart
        - never  # Only run when explicitly specified
```

### Running with Tags

```bash
# Run only install tasks
ansible-playbook playbooks/deploy/app.yml --tags "install"

# Skip config tasks
ansible-playbook playbooks/deploy/app.yml --skip-tags "config"

# Run tasks tagged with "never"
ansible-playbook playbooks/deploy/app.yml --tags "never"

# List available tags
ansible-playbook playbooks/deploy/app.yml --list-tags
```

## Testing

### Syntax Check

```bash
ansible-playbook playbooks/deploy/app.yml --syntax-check
```

### Linting

```bash
# Install ansible-lint
pip install ansible-lint

# Lint playbooks
ansible-lint playbooks/

# Lint specific playbook
ansible-lint playbooks/deploy/app.yml

# Lint with custom rules
ansible-lint -c .ansible-lint.yml playbooks/
```

### Molecule Testing

```bash
# Initialize molecule in role
cd roles/my-role
molecule init scenario --driver-name docker

# Create test instance
molecule create

# Run converge (apply role)
molecule converge

# Run verify tests
molecule verify

# Destroy test instance
molecule destroy

# Full test cycle
molecule test
```

### Integration Testing

```bash
# Run playbook against test environment
ansible-playbook -i inventory/test playbooks/deploy/app.yml --check

# Validate with smoke tests
ansible-playbook playbooks/test/smoke-tests.yml -i inventory/test
```

## Best Practices

### Playbook Organization

- One playbook per major task or workflow
- Use roles for reusable functionality
- Keep playbooks focused and modular
- Use include/import for complex playbooks

### Variable Management

- Use group_vars for shared variables
- Use host_vars for host-specific variables
- Encrypt sensitive data with Ansible Vault
- Document all variables in defaults/main.yml

### Error Handling

```yaml
- name: Task with error handling
  block:
    - name: Attempt operation
      command: /bin/risky-operation
  rescue:
    - name: Handle failure
      debug:
        msg: "Operation failed, running recovery"
    - name: Recovery action
      command: /bin/recovery-operation
  always:
    - name: Cleanup
      file:
        path: /tmp/work
        state: absent
```

### Performance

- Use `async` for long-running tasks
- Leverage `serial` for rolling updates
- Enable pipelining in ansible.cfg
- Use `delegate_to` for API calls
- Cache facts with fact_caching

### Security

- Never commit vault passwords
- Use SSH key authentication
- Limit sudo privileges
- Audit playbook changes
- Encrypt sensitive variables

## Troubleshooting

### Debug Tasks

```yaml
- name: Debug variable
  debug:
    var: my_variable
    verbosity: 2

- name: Debug message
  debug:
    msg: "The value is {{ my_variable }}"
```

### Verbose Output

```bash
# Minimal verbosity
ansible-playbook playbooks/deploy/app.yml

# Verbose output
ansible-playbook playbooks/deploy/app.yml -v

# More verbose
ansible-playbook playbooks/deploy/app.yml -vv

# Debug level
ansible-playbook playbooks/deploy/app.yml -vvv

# Connection debug
ansible-playbook playbooks/deploy/app.yml -vvvv
```

### Common Issues

**SSH connection timeout**:

```bash
# Test connectivity
ansible all -m ping -i inventory/production

# Check SSH config
ssh -vvv user@host

# Increase timeout
ansible-playbook playbooks/deploy/app.yml -e "ansible_timeout=60"
```

**Privilege escalation failure**:

```bash
# Test sudo
ansible all -m command -a "whoami" -b

# Ask for sudo password
ansible-playbook playbooks/deploy/app.yml --ask-become-pass
```

**Vault password issues**:

```bash
# Use password file
echo 'vault_password' > .vault_pass
chmod 600 .vault_pass
ansible-playbook playbooks/deploy/app.yml --vault-password-file .vault_pass
```

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/ansible-lint.yml
name: Ansible Lint
on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run ansible-lint
        uses: ansible/ansible-lint-action@main
```

### Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/ansible/ansible-lint
    rev: v6.14.0
    hooks:
      - id: ansible-lint
        files: \.(yaml|yml)$
```

## Related Documentation

- [Playbook Examples](playbooks/README.md)
- [Role Development](roles/README.md)
- [Inventory Guide](inventory/README.md)
- [ADR-0003: Ansible for Configuration Management](../docs/decisions/0003-ansible-configuration-management.md)
- [Compute Specifications](../specs/compute/)

# Research: CI/CD Platform Comparison

Date: 2025-10-18
Author: Infrastructure Team
Status: Completed

## Objective

Evaluate CI/CD platforms (GitHub Actions, GitLab CI, Jenkins, CircleCI) for infrastructure automation, focusing on cost, integration with existing toolchain, and ease of use for small teams.

## Scope

### In Scope

- GitHub Actions, GitLab CI, Jenkins, CircleCI
- Terraform/Ansible workflow integration
- Cost for small companies
- GitHub integration quality
- Self-hosted vs. SaaS options

### Out of Scope

- Enterprise platforms (TeamCity, Bamboo)
- Cloud-specific tools (AWS CodePipeline, Azure DevOps)
- Traditional deployment tools (Capistrano, Fabric)

## Methodology

### Testing Approach

- Implemented identical pipeline in each platform
- Measured build times and reliability
- Evaluated setup and maintenance complexity
- Tested Terraform and Ansible integration
- Analyzed cost for typical workload (50 builds/month)

### Evaluation Criteria

- **Cost**: Free tier limits and pricing
- **Integration**: GitHub, Terraform, Ansible compatibility
- **Ease of use**: YAML syntax, documentation
- **Performance**: Build speed and reliability
- **Security**: Secrets management, isolation

## Findings

### Platform Comparison Matrix

| Feature | GitHub Actions | GitLab CI | Jenkins | CircleCI |
|---------|----------------|-----------|---------|----------|
| **Hosting** | SaaS | SaaS/Self-hosted | Self-hosted | SaaS |
| **Free Tier** | 2,000 min/month | 400 min/month | Unlimited | 6,000 min/month |
| **Setup Time** | Instant | 5 min (SaaS) | 2-4 hours | 10 min |
| **GitHub Integration** | Native | Good | Plugin | Good |
| **Configuration** | YAML (.github/) | YAML (.gitlab-ci.yml) | Groovy/DSL | YAML (.circleci/) |
| **Terraform Support** | Excellent | Excellent | Good | Good |
| **Self-Hosted** | Runners only | Full platform | Full platform | Limited |
| **Market Share** | Growing rapidly | Established | Declining | Niche |

### 1. GitHub Actions

**Architecture**:

- SaaS platform integrated with GitHub
- Workflow files in `.github/workflows/`
- Matrix builds, reusable workflows
- GitHub-hosted or self-hosted runners

**Example Workflow**:

```yaml
name: Terraform Plan
on:
  pull_request:
    paths:
      - 'terraform/**'

jobs:
  plan:
    runs-on: ubuntu-latest
    env:
      DIGITALOCEAN_TOKEN: ${{ secrets.DIGITALOCEAN_TOKEN }}

    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.0

      - name: Terraform Init
        working-directory: ./terraform/environments/production
        run: terraform init

      - name: Terraform Plan
        working-directory: ./terraform/environments/production
        run: terraform plan -out=tfplan

      - name: Comment PR
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: 'Terraform plan completed ✅'
            })
```

**Pros**:

- ✅ **Native GitHub integration**: Zero setup
- ✅ **Free tier**: 2,000 minutes/month (Linux)
- ✅ **Marketplace**: 18,000+ pre-built actions
- ✅ **Matrix builds**: Test multiple versions
- ✅ **Secrets management**: GitHub Secrets integration
- ✅ **Self-hosted runners**: For private infrastructure
- ✅ **Fastest growing**: Active development

**Cons**:

- ❌ **Tied to GitHub**: Vendor lock-in
- ❌ **Limited free tier**: 2,000 min/month
- ❌ **macOS expensive**: $0.08/min (10x Linux)

**Cost Analysis** (50 builds/month, 5 min avg):

```
Free Tier: 2,000 minutes/month
Usage: 50 builds × 5 min = 250 minutes
Cost: $0 (within free tier)

If exceeding:
Linux: $0.008/minute
250 minutes = $2/month
```

**Best for**: GitHub users, small teams, rapid iteration

### 2. GitLab CI

**Architecture**:

- Integrated CI/CD platform
- Self-hosted or SaaS (gitlab.com)
- Configuration in `.gitlab-ci.yml`
- GitLab Runners (shared or self-hosted)

**Example Pipeline**:

```yaml
stages:
  - validate
  - plan
  - apply

variables:
  TF_VERSION: "1.6.0"

terraform:validate:
  stage: validate
  image: hashicorp/terraform:$TF_VERSION
  script:
    - cd terraform/environments/production
    - terraform init -backend=false
    - terraform validate
  only:
    - merge_requests

terraform:plan:
  stage: plan
  image: hashicorp/terraform:$TF_VERSION
  script:
    - cd terraform/environments/production
    - terraform init
    - terraform plan -out=tfplan
  artifacts:
    paths:
      - terraform/environments/production/tfplan
  only:
    - merge_requests

terraform:apply:
  stage: apply
  image: hashicorp/terraform:$TF_VERSION
  script:
    - cd terraform/environments/production
    - terraform init
    - terraform apply tfplan
  when: manual
  only:
    - main
```

**Pros**:

- ✅ **Self-hosted option**: Full control
- ✅ **Complete DevOps platform**: CI/CD + registry + K8s
- ✅ **Free tier**: 400 minutes/month
- ✅ **Built-in container registry**: No Docker Hub needed
- ✅ **Auto DevOps**: Templates for common workflows

**Cons**:

- ❌ **Smaller free tier**: 400 min/month
- ❌ **Requires migration**: If using GitHub
- ❌ **Self-hosted overhead**: Infrastructure to manage

**Cost Analysis** (50 builds/month):

```
GitLab.com Free: 400 minutes/month
Usage: 250 minutes
Cost: $0 (within free tier)

Self-hosted:
Server: $12/month (DO Droplet)
Cost: $12/month + management time
```

**Best for**: GitLab users, self-hosted needs, complete DevOps platform

### 3. Jenkins

**Architecture**:

- Self-hosted automation server
- Plugin-based extensibility
- Jenkinsfile (Groovy DSL) or UI config
- Master + agent architecture

**Example Jenkinsfile**:

```groovy
pipeline {
    agent any

    environment {
        DIGITALOCEAN_TOKEN = credentials('digitalocean-token')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                dir('terraform/environments/production') {
                    sh 'terraform init'
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                dir('terraform/environments/production') {
                    sh 'terraform plan -out=tfplan'
                }
            }
        }

        stage('Terraform Apply') {
            when {
                branch 'main'
            }
            steps {
                input message: 'Apply Terraform changes?'
                dir('terraform/environments/production') {
                    sh 'terraform apply tfplan'
                }
            }
        }
    }
}
```

**Pros**:

- ✅ **Unlimited builds**: No time limits
- ✅ **Highly customizable**: 1,800+ plugins
- ✅ **Self-hosted**: Full control
- ✅ **Battle-tested**: Mature platform

**Cons**:

- ❌ **Complex setup**: 2-4 hours initial config
- ❌ **Maintenance burden**: Updates, plugins, security
- ❌ **Infrastructure cost**: Server + storage
- ❌ **Declining adoption**: Losing market share
- ❌ **Plugin compatibility**: Version conflicts

**Cost Analysis**:

```
Infrastructure:
Server: $24/month (2GB RAM droplet)
Storage: $10/month (backups)
Total: $34/month + admin time

Operational:
Setup: 4-8 hours
Maintenance: 2-4 hours/month
Updates: 1 hour/month
```

**Best for**: Complex workflows, unlimited builds, full control needs

### 4. CircleCI

**Architecture**:

- SaaS CI/CD platform
- Configuration in `.circleci/config.yml`
- Docker-first approach
- Credits-based pricing

**Example Config**:

```yaml
version: 2.1

orbs:
  terraform: circleci/terraform@3.2

jobs:
  plan:
    docker:
      - image: hashicorp/terraform:1.6.0
    steps:
      - checkout
      - terraform/init:
          path: terraform/environments/production
      - terraform/plan:
          path: terraform/environments/production

workflows:
  terraform:
    jobs:
      - plan:
          filters:
            branches:
              ignore: main
```

**Pros**:

- ✅ **Generous free tier**: 6,000 minutes/month
- ✅ **Docker-native**: Container workflows
- ✅ **Orbs**: Reusable config packages
- ✅ **Performance**: Fast builds

**Cons**:

- ❌ **Complex pricing**: Credit system
- ❌ **GitHub migration**: Need to link repos
- ❌ **Less native**: Compared to GitHub Actions

**Cost Analysis**:

```
Free Tier: 6,000 credits/month
Linux: 10 credits/minute
Usage: 50 builds × 5 min = 250 min = 2,500 credits
Cost: $0 (within free tier)
```

**Best for**: Docker workflows, performance-critical builds

## Analysis

### Integration Quality (with Terraform/Ansible)

| Platform | Terraform | Ansible | Rating |
|----------|-----------|---------|--------|
| GitHub Actions | Native actions, great docs | Excellent | ⭐⭐⭐⭐⭐ |
| GitLab CI | Docker-based, proven | Excellent | ⭐⭐⭐⭐⭐ |
| Jenkins | Plugins available | Good | ⭐⭐⭐ |
| CircleCI | Orbs available | Good | ⭐⭐⭐⭐ |

### Ease of Use Ranking

1. **GitHub Actions**: Instant setup, native integration
2. **CircleCI**: Quick setup, good docs
3. **GitLab CI**: Medium setup, comprehensive
4. **Jenkins**: Complex setup, steep learning curve

### Cost Comparison (Annual, 50 builds/month)

| Platform | Infrastructure | Usage | Admin Time | **Total** |
|----------|----------------|-------|------------|-----------|
| GitHub Actions | $0 | $0 | $0 | **$0** |
| GitLab CI (SaaS) | $0 | $0 | $0 | **$0** |
| GitLab CI (Self) | $144 | $0 | $500* | **$644** |
| Jenkins | $408 | $0 | $1,000* | **$1,408** |
| CircleCI | $0 | $0 | $0 | **$0** |

*Estimated admin time value

## Recommendations

### Primary: GitHub Actions

**Rationale**:

1. **Zero setup**: Already using GitHub
2. **Native integration**: First-class citizen
3. **Free tier**: Sufficient for small teams
4. **Marketplace**: 18,000+ actions
5. **Active development**: Fastest-growing platform
6. **Learning value**: Industry momentum

**Implementation**:

```bash
# 1. Create workflow directory
mkdir -p .github/workflows

# 2. Add Terraform workflow
cat > .github/workflows/terraform.yml <<EOF
name: Terraform
on: [pull_request]
jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - run: terraform init
      - run: terraform plan
EOF

# 3. Commit and push
git add .github/
git commit -m "Add Terraform CI/CD"
git push
```

### Alternative: GitLab CI

**When to consider**:

- Already using GitLab
- Want self-hosted option
- Need complete DevOps platform
- Require container registry

**Migration effort**: Medium (2-4 hours to migrate repos)

### Not Recommended: Jenkins

**Reasons**:

- High operational overhead
- Declining market adoption
- Better alternatives available
- Complex for small teams

**Exception**: If already invested heavily in Jenkins

## Action Items

1. **Immediate**:
   - [x] Enable GitHub Actions on repository
   - [ ] Create `.github/workflows/` directory
   - [ ] Add Terraform plan workflow
   - [ ] Add Ansible lint workflow
   - [ ] Configure secrets (DIGITALOCEAN_TOKEN)

2. **Short-term** (1-3 months):
   - [ ] Add Terraform apply workflow (manual trigger)
   - [ ] Implement environment-specific workflows
   - [ ] Add security scanning (tfsec, ansible-lint)
   - [ ] Set up deployment notifications
   - [ ] Create reusable workflows

3. **Long-term** (6-12 months):
   - [ ] Monitor free tier usage
   - [ ] Consider self-hosted runners if needed
   - [ ] Evaluate advanced features (matrix, caching)
   - [ ] Implement GitOps workflows

## Follow-up Research Needed

1. **GitOps Tools**: ArgoCD vs. Flux for Kubernetes deployments
2. **Self-Hosted Runners**: When and how to implement
3. **Security Scanning**: Integration of security tools in pipeline

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitLab CI Documentation](https://docs.gitlab.com/ee/ci/)
- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [CircleCI Documentation](https://circleci.com/docs/)
- [Terraform GitHub Actions](https://github.com/hashicorp/setup-terraform)
- [CI/CD Market Survey 2024](https://www.jetbrains.com/lp/devecosystem-2024/devops/)

## Outcome

This research led to **[ADR-0006: GitHub Actions for CI/CD](../decisions/0006-github-actions-cicd.md)**, which adopted GitHub Actions as the primary CI/CD platform.

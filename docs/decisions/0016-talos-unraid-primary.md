# 16. Talos Linux on Unraid as Primary Infrastructure

Date: 2025-10-31

## Status

Accepted

**Supersedes**:

- [ADR-0015: Oracle Cloud as Primary Provider](0015-oracle-cloud-primary.md)
- [ADR-0013: DigitalOcean as Primary Cloud Provider](0013-digitalocean-primary-cloud.md)

## Context

After evaluating cloud providers (Oracle Cloud, DigitalOcean, AWS, Azure, GCP) and testing various configurations,
the decision has been made to prioritize rapid Kubernetes setup and learning using local infrastructure. This approach
allows for:

- **Immediate availability**: No dependency on cloud account provisioning or approval processes
- **Zero ongoing costs**: No monthly cloud bills during development and learning
- **Full control**: Complete control over infrastructure configuration and updates
- **Production-grade experience**: Talos Linux provides a production-quality Kubernetes distribution
- **Tailscale integration**: Secure networking without complex VPN setup

### Current Infrastructure

**Unraid Server**:

- Host operating system with VM management capabilities
- Stable, reliable platform for running virtual machines
- Local storage and network resources available

**Planned Configuration**:

- **2 VMs total**: Minimal viable Kubernetes cluster
  - 1 control plane node
  - 1 worker node
- **Talos Linux**: Immutable, API-driven Kubernetes OS
- **Tailscale**: Zero-config VPN mesh network for secure access

### Why Talos Linux

Talos Linux is a modern, secure, and minimal Linux distribution designed specifically for Kubernetes:

**Key Features**:

- **API-Driven**: All configuration via API, no SSH access by design
- **Immutable**: Read-only root filesystem, configuration as code
- **Minimal Attack Surface**: No shell, no SSH, only Kubernetes components
- **Production-Ready**: Used in production by organizations worldwide
- **Easy Management**: `talosctl` CLI for all operations
- **Secure by Default**: mTLS for all communication, secure boot support
- **Small Footprint**: ~80MB RAM for system, rest available for workloads

### Why Tailscale

Tailscale provides zero-config VPN mesh networking:

**Key Features**:

- **Zero Configuration**: No port forwarding, NAT traversal handled automatically
- **Secure**: WireGuard-based encryption
- **Easy Access**: Access cluster from anywhere securely
- **Free Tier**: Suitable for personal/small team use
- **Multi-Platform**: Works across all operating systems
- **Integration**: Can integrate with kubectl and other tools

### Cluster Configuration

**Minimal 2-Node Setup**:

| Node Type | Count | Role | Resources |
|-----------|-------|------|-----------|
| Control Plane | 1 | Kubernetes control plane | 2 CPU, 4GB RAM, 50GB disk |
| Worker | 1 | Application workloads | 2-4 CPU, 4-8GB RAM, 100GB disk |

**Why 2 Nodes**:

- **Learning**: Sufficient for learning Kubernetes concepts and operations
- **Resource Efficient**: Minimal resource usage on Unraid host
- **Real Cluster**: Multi-node setup provides realistic production experience
- **Scalable**: Easy to add more nodes as needs grow

## Decision

We will use **Talos Linux on Unraid VMs** as our primary infrastructure platform, with **Tailscale** for secure networking.

### Primary Infrastructure - Talos on Unraid

**Core Components**:

1. **Unraid Host**
   - VM management platform
   - Storage provider for VM disks
   - Network bridge for VM connectivity
   - Host for 2 Talos Linux VMs

2. **Talos Linux Cluster**
   - 1 control plane node (Kubernetes API, etcd, controllers)
   - 1 worker node (application workloads)
   - API-driven management via `talosctl`
   - Immutable infrastructure, configuration as code
   - Kubernetes 1.29+ (latest stable)

3. **Tailscale Mesh Network**
   - Secure access to Kubernetes cluster from anywhere
   - Zero-config VPN connectivity
   - Access to services without port forwarding
   - Integration with local development environment

4. **Local Storage**
   - Local path provisioner for persistent volumes
   - NFS shares from Unraid (optional, for shared storage)
   - Storage managed at Kubernetes level

5. **Networking**
   - CNI: Flannel (default with Talos) or Cilium (advanced)
   - Service exposure via NodePort or LoadBalancer (MetalLB)
   - Ingress via nginx-ingress or Traefik
   - Tailscale for external access

### Cloud Services - Supporting Role

**Cloudflare (Edge Services)**:

- DNS management
- CDN and caching (when needed for public services)
- DDoS protection
- SSL/TLS certificates
- Cloudflare R2 for backup storage and Terraform state

**Future Considerations**:

- Oracle Cloud or DigitalOcean for public-facing production workloads
- Geographic distribution when global presence needed
- Managed databases for production data
- Advanced enterprise features as requirements grow

### Tailscale Integration

**Setup**:

- Install Tailscale on Talos nodes (via Kubernetes DaemonSet)
- Install Tailscale on development machines
- Access cluster via Tailscale network
- Expose services via Tailscale subnet routing (optional)

**Benefits**:

- Secure kubectl access from anywhere
- No firewall configuration needed
- Access cluster services directly
- Integration with CI/CD (GitHub Actions can access via Tailscale)

## Consequences

### Positive

- **Zero Cost**: No monthly cloud bills during development
  - No compute costs
  - No Kubernetes control plane costs
  - No networking or load balancer costs
  - Only electricity costs (minimal)

- **Immediate Availability**: Start working immediately
  - No cloud account approval process
  - No resource quotas or limits
  - No geographic restrictions
  - Full control over resources

- **Production-Grade Experience**: Real Kubernetes learning
  - Talos provides production-quality Kubernetes
  - Multi-node cluster for realistic scenarios
  - API-driven operations like production systems
  - Immutable infrastructure best practices

- **Full Control**: Complete infrastructure ownership
  - Modify configuration freely
  - Test destructive operations safely
  - Learn from mistakes without cost
  - Experiment with different configurations

- **Security by Default**: Talos Linux security model
  - No SSH access (secure by design)
  - Immutable system (cannot be modified)
  - Minimal attack surface
  - mTLS for all communication
  - Secure boot support

- **Easy Management**: Simple operational model
  - `talosctl` CLI for all operations
  - Configuration as code (YAML files)
  - Declarative updates
  - Built-in health checks

- **Secure Remote Access**: Tailscale benefits
  - Zero-config VPN setup
  - Secure access from anywhere
  - No port forwarding needed
  - WireGuard-based encryption

- **Learning Focus**: Optimize for skill development
  - Hands-on Kubernetes experience
  - Infrastructure as code practices
  - GitOps workflows
  - Troubleshooting skills

### Negative

- **No High Availability**: Single Unraid host
  - Host failure = complete outage
  - No automatic failover
  - Not suitable for production critical workloads
  - Physical risks (power, hardware failure)

- **No Geographic Distribution**: Local only
  - High latency for remote users
  - Single location risk
  - Cannot serve global users effectively
  - Limited to home internet connection

- **Resource Constraints**: Limited by host hardware
  - Cannot scale beyond host capacity
  - Memory/CPU limits
  - Storage limits
  - Network bandwidth limits

- **Limited Internet Bandwidth**: Home connection
  - Upload bandwidth typically limited
  - Not suitable for high-traffic services
  - Potential ISP restrictions on hosting
  - Variable latency

- **Maintenance Responsibility**: Self-managed
  - Manual updates and patching
  - Hardware maintenance
  - Power and cooling management
  - Network troubleshooting

- **No Managed Services**: DIY everything
  - No managed databases
  - No managed load balancers
  - No managed monitoring
  - Self-service only

### Trade-offs

- **Cost vs. Availability**: Zero cost but lower availability
  - Acceptable for learning and development
  - Not suitable for production critical workloads
  - Can migrate to cloud for production needs

- **Control vs. Convenience**: Full control but more responsibility
  - More work to setup and maintain
  - Greater learning opportunity
  - Better understanding of infrastructure

- **Local vs. Cloud**: Immediate access but limited reach
  - Perfect for learning phase
  - Transition to cloud for production
  - Hybrid approach for best of both

## Alternatives Considered

### Oracle Cloud Always Free Tier

**Why not chosen** (for now):

- **Provisioning complexity**: Difficult to obtain free tier resources
- **Account approval**: May face verification delays
- **Learning delay**: Delays immediate hands-on learning
- **Arm architecture**: Requires multi-arch images (additional complexity)

**When to reconsider**: For public-facing production workloads after learning phase

### DigitalOcean DOKS

**Why not chosen** (for now):

- **Cost**: $90-120/month for production-ready cluster
- **Not needed yet**: Overkill for learning phase
- **Can add later**: Easy to add when needed for production

**When to reconsider**: When deploying production services with uptime requirements

### AWS/Azure/GCP

**Why not chosen**:

- **Cost**: Higher costs than DigitalOcean or Oracle Cloud
- **Complexity**: Steeper learning curves
- **Trial limitations**: Time-limited free tiers
- **Overkill**: Too complex for current learning objectives

### k3s or MicroK8s

**Why not chosen**:

- **Less production-like**: Simplified Kubernetes distributions
- **Different experience**: Doesn't match production best practices
- **Manual management**: Still requires OS-level access and management
- **Security**: Not as secure by default as Talos

**Talos advantages**: Production-grade, secure by default, API-driven, immutable

## Implementation Plan

### Phase 1: Talos Cluster Setup (Week 1, Days 1-3)

**Day 1: Environment Preparation**

1. **Unraid VM Preparation**

   ```bash
   # On Unraid web UI:
   # 1. Create 2 new VMs with following specs:
   #    - Control Plane: 2 vCPU, 4GB RAM, 50GB disk
   #    - Worker: 4 vCPU, 8GB RAM, 100GB disk
   # 2. Download Talos Linux ISO
   # 3. Attach ISO to both VMs
   ```

2. **Talos CLI Installation**

   ```bash
   # On management machine (laptop/desktop):
   # macOS
   brew install siderolabs/tap/talosctl

   # Linux
   curl -sL https://talos.dev/install | sh

   # Verify installation
   talosctl version
   ```

3. **Generate Talos Configuration**

   ```bash
   # Generate cluster configuration
   talosctl gen config talos-home https://<control-plane-ip>:6443

   # This creates:
   # - controlplane.yaml (control plane node config)
   # - worker.yaml (worker node config)
   # - talosconfig (talosctl configuration)
   ```

**Day 2: Cluster Bootstrap**

1. **Apply Configuration to Nodes**

   ```bash
   # Apply to control plane
   talosctl apply-config --insecure \
     --nodes <control-plane-ip> \
     --file controlplane.yaml

   # Apply to worker
   talosctl apply-config --insecure \
     --nodes <worker-ip> \
     --file worker.yaml
   ```

2. **Bootstrap Kubernetes**

   ```bash
   # Set node and endpoint in talosctl config
   talosctl --talosconfig=./talosconfig \
     config endpoint <control-plane-ip>

   talosctl --talosconfig=./talosconfig \
     config node <control-plane-ip>

   # Bootstrap etcd on control plane
   talosctl bootstrap

   # Wait for bootstrap to complete (5-10 minutes)
   talosctl health --wait-timeout=10m
   ```

3. **Configure kubectl Access**

   ```bash
   # Retrieve kubeconfig
   talosctl kubeconfig ./kubeconfig

   # Test cluster access
   kubectl --kubeconfig=./kubeconfig get nodes

   # Copy to default location (optional)
   cp ./kubeconfig ~/.kube/config-talos
   ```

**Day 3: Cluster Validation**

1. **Verify Cluster Health**

   ```bash
   # Check node status
   kubectl get nodes -o wide

   # Check system pods
   kubectl get pods -A

   # Check component status
   talosctl health

   # Check cluster info
   kubectl cluster-info
   ```

2. **Deploy Test Application**

   ```bash
   # Deploy nginx test
   kubectl create deployment nginx --image=nginx:latest
   kubectl expose deployment nginx --port=80 --type=NodePort

   # Test access
   kubectl get svc nginx
   curl http://<node-ip>:<nodeport>
   ```

3. **Document Configuration**
   - Save configuration files to Git repository
   - Document IP addresses and access methods
   - Create basic troubleshooting guide

### Phase 2: Tailscale Integration (Week 1, Days 4-5)

**Day 4: Tailscale Setup**

1. **Create Tailscale Account**
   - Sign up at https://login.tailscale.com/
   - Create auth key for Kubernetes nodes
   - Note down auth key securely

2. **Deploy Tailscale on Cluster**

   ```bash
   # Create namespace
   kubectl create namespace tailscale

   # Create secret with auth key
   kubectl create secret generic tailscale-auth \
     --from-literal=TS_AUTHKEY=<your-auth-key> \
     -n tailscale

   # Deploy Tailscale DaemonSet
   kubectl apply -f https://raw.githubusercontent.com/tailscale/tailscale/main/docs/k8s/daemonset.yaml
   ```

3. **Install Tailscale on Management Machine**

   ```bash
   # macOS
   brew install tailscale
   sudo tailscale up

   # Linux
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up

   # Verify connectivity to cluster nodes
   tailscale status
   ```

**Day 5: Network Configuration and Testing**

1. **Configure kubectl via Tailscale**

   ```bash
   # Update kubeconfig to use Tailscale IPs
   # Modify server URL in kubeconfig:
   # server: https://<tailscale-ip>:6443

   # Test access
   kubectl get nodes
   kubectl get pods -A
   ```

2. **Test Remote Access**

   ```bash
   # From different network/device
   # Install Tailscale and login
   # Access cluster via kubectl
   kubectl get nodes

   # Test service access
   curl http://<tailscale-node-ip>:<nodeport>
   ```

3. **Document Tailscale Setup**
   - Document Tailscale configuration
   - Create access guide for team members
   - Document service exposure patterns

### Phase 3: Core Services Deployment (Week 2)

**Day 1-2: Storage and Ingress**

1. **Install Local Path Provisioner**

   ```bash
   # Deploy local-path-storage
   kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

   # Set as default storage class
   kubectl patch storageclass local-path \
     -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

   # Test with PVC
   kubectl apply -f - <<EOF
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: test-pvc
   spec:
     accessModes:
       - ReadWriteOnce
     resources:
       requests:
         storage: 1Gi
   EOF
   ```

2. **Install Nginx Ingress Controller**

   ```bash
   # Install via Helm (recommended)
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm repo update

   helm install ingress-nginx ingress-nginx/ingress-nginx \
     --namespace ingress-nginx \
     --create-namespace \
     --set controller.service.type=NodePort

   # Verify installation
   kubectl get pods -n ingress-nginx
   kubectl get svc -n ingress-nginx
   ```

3. **Install Cert-Manager**

   ```bash
   # Install cert-manager
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

   # Verify installation
   kubectl get pods -n cert-manager

   # Create self-signed issuer for testing
   kubectl apply -f - <<EOF
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: selfsigned-issuer
   spec:
     selfSigned: {}
   EOF
   ```

**Day 3-4: Monitoring and GitOps**

1. **Install Prometheus Stack**

   ```bash
   # Add helm repo
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update

   # Install kube-prometheus-stack
   helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
     --namespace monitoring \
     --create-namespace \
     --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
     --set grafana.adminPassword=admin

   # Verify installation
   kubectl get pods -n monitoring

   # Access Grafana via port-forward
   kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
   ```

2. **Install ArgoCD (Optional)**

   ```bash
   # Install ArgoCD
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

   # Get initial admin password
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

   # Access ArgoCD UI via port-forward
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```

**Day 5: Testing and Validation**

1. **Deploy Sample Application Stack**

   ```bash
   # Deploy complete application with:
   # - Deployment
   # - Service
   # - Ingress
   # - PersistentVolumeClaim
   # Test all components working together
   ```

2. **Performance Testing**

   ```bash
   # Test cluster performance
   # - Pod scheduling time
   # - Service response time
   # - Storage performance
   # - Network throughput
   ```

3. **Documentation**
   - Document all deployed services
   - Create service access guide
   - Document common operations
   - Create troubleshooting guide

### Phase 4: Infrastructure as Code (Week 3)

**Terraform Configuration**

1. **Talos Terraform Provider**

   ```hcl
   # Configure Talos provider
   terraform {
     required_providers {
       talos = {
         source = "siderolabs/talos"
         version = "~> 0.4.0"
       }
     }
   }

   # Store cluster configuration
   # Document VM specifications
   # Plan for future automation
   ```

2. **Kubernetes Manifest Management**

   ```bash
   # Organize manifests
   infrastructure/
   ├── kubernetes/
   │   ├── core/          # Core services (ingress, cert-manager)
   │   ├── monitoring/    # Prometheus, Grafana
   │   ├── apps/          # Applications
   │   └── kustomization.yaml
   ```

3. **GitOps Setup**

   ```bash
   # If using ArgoCD:
   # - Create Git repository for manifests
   # - Configure ArgoCD applications
   # - Set up auto-sync policies
   # - Test GitOps workflow
   ```

### Phase 5: Operations and Maintenance (Ongoing)

**Daily Operations**

1. **Monitoring**

   ```bash
   # Check cluster health
   talosctl health
   kubectl get nodes
   kubectl get pods -A

   # Check Grafana dashboards
   # Review any alerts
   ```

2. **Backup Strategy**

   ```bash
   # Backup etcd
   talosctl -n <control-plane-ip> etcd snapshot ./backup.db

   # Backup configurations
   # - Talos configs in Git
   # - Kubernetes manifests in Git
   # - Document restore procedures
   ```

3. **Updates and Maintenance**

   ```bash
   # Talos updates
   talosctl upgrade --nodes <node-ip> \
     --image ghcr.io/siderolabs/installer:v1.6.0

   # Kubernetes updates
   talosctl upgrade-k8s --nodes <control-plane-ip> --to 1.29.0
   ```

## Success Metrics

### Technical Metrics

- **Cluster Uptime**: >95% (acceptable for learning environment)
- **Pod Startup Time**: <30 seconds
- **Service Response Time**: <100ms (local network)
- **Storage Performance**: Adequate for development workloads

### Learning Metrics

- **Cluster operational**: Within 1-2 days
- **Core services deployed**: Within 1 week
- **Comfortable with talosctl**: Within 2 weeks
- **Comfortable with kubectl**: Within 2 weeks
- **GitOps workflow established**: Within 3 weeks

### Operational Metrics

- **Successful backups**: Weekly
- **Configuration in Git**: 100%
- **Documentation coverage**: All core operations documented
- **Incident response time**: <1 hour (learning environment)

## Security Considerations

### Talos Security

- **No SSH Access**: Secure by design, API-only access
- **Immutable System**: Read-only root filesystem
- **mTLS**: All Talos API communication encrypted
- **Minimal Attack Surface**: Only Kubernetes components running
- **Secure Boot**: Support for secure boot (optional)

### Tailscale Security

- **WireGuard Encryption**: Strong encryption for all traffic
- **MagicDNS**: Secure DNS resolution
- **ACLs**: Access control at network level
- **Key Management**: Automatic key rotation
- **Zero Trust**: No implicit trust relationships

### Kubernetes Security

- **RBAC**: Role-based access control enabled
- **Network Policies**: Pod-to-pod traffic control (when using Cilium)
- **Pod Security Standards**: Enforce security policies
- **Secret Encryption**: Encrypt secrets at rest (configure in Talos)
- **Audit Logging**: Enable Kubernetes audit logs

### Access Control

- **talosctl Access**: Protect Talos configuration files
- **kubectl Access**: Protect kubeconfig files
- **Tailscale Access**: Use ACLs to restrict access
- **Service Exposure**: Only expose necessary services
- **MFA**: Enable MFA for Tailscale account

### Network Security

- **Local Network**: Talos nodes on isolated VLAN (recommended)
- **Firewall**: Unraid firewall rules to protect nodes
- **Tailscale Only**: External access only via Tailscale
- **No Port Forwarding**: No ports exposed to internet directly
- **mTLS**: Encrypt all inter-component communication

## Migration and Scaling Strategy

### Scaling Locally

**Add More Workers**:

```bash
# When more capacity needed:
# 1. Create new VM on Unraid
# 2. Generate worker config
# 3. Apply config and join cluster
# 4. Verify node joined successfully

talosctl gen config --output-types worker > worker-2.yaml
talosctl apply-config --nodes <new-worker-ip> --file worker-2.yaml
```

**Convert to HA Control Plane** (when needed):

```bash
# Add 2 more control plane nodes
# Requires minimum 3 control plane nodes for HA
# Follow Talos HA setup documentation
```

### Migration to Cloud

**When to Consider Cloud Migration**:

- Public-facing production services needed
- High availability requirements
- Geographic distribution needed
- Resource limits exceeded on local hardware
- Internet bandwidth becomes bottleneck

**Migration Strategy**:

1. **Keep Talos**: Talos can run on cloud VMs (Oracle Cloud, DigitalOcean, AWS, etc.)
2. **Kubernetes Portability**: Manifests are cloud-agnostic
3. **Backup Data**: Backup application data before migration
4. **Parallel Setup**: Build cloud cluster in parallel
5. **DNS Cutover**: Update DNS to point to cloud cluster
6. **Gradual Migration**: Migrate workloads incrementally

**Estimated Migration Effort**:

- Infrastructure setup: 1-2 days (automated with Terraform)
- Application migration: 1-3 days (depending on complexity)
- Testing and validation: 1-2 days
- Total: 3-7 days

### Hybrid Strategy (Future)

**Local + Cloud**:

- Keep local cluster for development and testing
- Use cloud for production workloads
- Tailscale mesh for connectivity between clusters
- Same operational tools (kubectl, Helm, ArgoCD)

## Future Considerations

### Advanced Networking

- **Cilium CNI**: Enhanced networking and security features
- **Service Mesh**: Istio or Linkerd for advanced traffic management
- **MetalLB**: LoadBalancer type services on bare metal
- **Multiple Ingress Controllers**: Separate internal/external ingress

### Storage Enhancements

- **Longhorn**: Distributed block storage for replicated volumes
- **NFS Integration**: Use Unraid NFS shares for persistent storage
- **Backup Solutions**: Velero for cluster backup and restore

### Monitoring and Observability

- **Log Aggregation**: Loki for centralized logging
- **Distributed Tracing**: Jaeger or Tempo
- **Application Metrics**: OpenTelemetry integration
- **Custom Dashboards**: Business-specific Grafana dashboards

### CI/CD Integration

- **GitHub Actions**: Build and deploy via Tailscale
- **GitLab Runner**: Self-hosted runners on cluster
- **ArgoCD**: Full GitOps workflow
- **Image Registry**: Harbor for private container registry

## References

- [Talos Linux Documentation](https://www.talos.dev/latest/)
- [Talos Linux GitHub](https://github.com/siderolabs/talos)
- [Tailscale Documentation](https://tailscale.com/kb/)
- [Tailscale on Kubernetes](https://tailscale.com/kb/1185/kubernetes/)
- [Unraid Documentation](https://wiki.unraid.net/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [ADR-0015: Oracle Cloud as Primary Provider](0015-oracle-cloud-primary.md) (Superseded)
- [ADR-0013: DigitalOcean as Primary Cloud Provider](0013-digitalocean-primary-cloud.md) (Superseded)
- [ADR-0009: Tailscale for Hybrid Cloud Networking](0009-tailscale-hybrid-networking.md) (Still relevant)

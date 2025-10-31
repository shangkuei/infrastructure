# Talos Linux Advanced Features Guide

**Date**: 2025-11-01
**Status**: Reference Guide
**Related**: [Talos Configuration Options](../architecture/talos-configuration-options.md), [Talos Cluster Specification](../../specs/talos/talos-cluster-specification.md)

## Overview

This guide covers advanced Talos Linux features and configurations for production Kubernetes clusters, including networking, security, storage, and operational features.

---

## 1. Host DNS (CoreDNS on Host)

### Overview

Host DNS provides local DNS resolution on each node using CoreDNS running directly on the host (not in a container). This improves DNS performance and reliability.

### Configuration

**Method 1: Using Dummy Interface (Recommended)**

```yaml
machine:
  network:
    interfaces:
      - interface: dummy0
        addresses:
          - 169.254.2.53/32
        dummy: true
```

**Method 2: CoreDNS Local Configuration**

```yaml
machine:
  pods:
    - apiVersion: v1
      kind: Pod
      metadata:
        name: coredns-local
        namespace: kube-system
      spec:
        hostNetwork: true
        containers:
          - name: coredns
            image: coredns/coredns:1.11.1
            args:
              - -conf
              - /etc/coredns/Corefile
```

**Kubelet Configuration:**

```yaml
machine:
  kubelet:
    clusterDNS:
      - 169.254.2.53  # Host DNS
      - 10.96.0.10    # Cluster DNS (fallback)
```

### Benefits

- Reduced DNS latency (no network hop to cluster DNS)
- Better reliability (survives cluster DNS issues)
- Lower cluster DNS load

### Terraform Example

```hcl
control_plane_patches = [
  yamlencode({
    machine = {
      network = {
        interfaces = [{
          interface = "dummy0"
          addresses = ["169.254.2.53/32"]
          dummy     = true
        }]
      }
      kubelet = {
        clusterDNS = ["169.254.2.53", "10.96.0.10"]
      }
    }
  })
]
```

---

## 2. Ingress Firewall (nftables)

### Overview

Talos uses nftables for packet filtering. Configure network policies at the host level.

### Configuration

**Enable nftables Rules:**

```yaml
machine:
  network:
    nftables:
      enabled: true
```

**Custom Firewall Rules:**

```yaml
machine:
  files:
    - content: |
        #!/sbin/nft -f

        table inet filter {
          chain input {
            type filter hook input priority 0; policy drop;

            # Allow established/related
            ct state {established, related} accept

            # Allow loopback
            iif lo accept

            # Allow Kubernetes API
            tcp dport 6443 accept

            # Allow Talos API
            tcp dport 50000 accept

            # Allow Kubelet
            tcp dport 10250 accept

            # Allow ICMP
            ip protocol icmp accept
            ip6 nexthdr icmpv6 accept
          }

          chain forward {
            type filter hook forward priority 0; policy accept;
          }

          chain output {
            type filter hook output priority 0; policy accept;
          }
        }
      path: /var/etc/nftables.nft
      permissions: 0644
      op: create
```

### Kubernetes Network Policies

Use Cilium or Calico CNI for pod-level network policies:

```yaml
cluster:
  network:
    cni:
      name: cilium
```

### Terraform Example

```hcl
control_plane_patches = [
  yamlencode({
    machine = {
      files = [{
        content = <<-EOT
          #!/sbin/nft -f
          table inet filter {
            chain input {
              type filter hook input priority 0; policy drop;
              ct state {established, related} accept
              iif lo accept
              tcp dport {6443, 50000, 10250} accept
              ip protocol icmp accept
            }
          }
        EOT
        path        = "/var/etc/nftables.nft"
        permissions = "0644"
        op          = "create"
      }]
    }
  })
]
```

---

## 3. Multihoming and Tailscale

### Overview

Configure multiple network interfaces for Tailscale VPN integration, providing secure remote access to cluster.

### Tailscale Integration

**Option 1: DaemonSet (Recommended)**

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: tailscale
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: tailscale
  template:
    metadata:
      labels:
        app: tailscale
    spec:
      hostNetwork: true
      containers:
        - name: tailscale
          image: tailscale/tailscale:latest
          env:
            - name: TS_AUTHKEY
              valueFrom:
                secretKeyRef:
                  name: tailscale-auth
                  key: authkey
            - name: TS_ROUTES
              value: "10.244.0.0/16,10.96.0.0/12"
            - name: TS_STATE_DIR
              value: /var/lib/tailscale
          securityContext:
            capabilities:
              add:
                - NET_ADMIN
          volumeMounts:
            - name: state
              mountPath: /var/lib/tailscale
            - name: dev-net-tun
              mountPath: /dev/net/tun
      volumes:
        - name: state
          hostPath:
            path: /var/lib/tailscale
            type: DirectoryOrCreate
        - name: dev-net-tun
          hostPath:
            path: /dev/net/tun
            type: CharDevice
```

**Option 2: Static Pod (Control Plane)**

```yaml
machine:
  pods:
    - apiVersion: v1
      kind: Pod
      metadata:
        name: tailscale
        namespace: kube-system
      spec:
        hostNetwork: true
        containers:
          - name: tailscale
            image: tailscale/tailscale:latest
            env:
              - name: TS_AUTHKEY
                value: "tskey-auth-xxxxx"
            securityContext:
              privileged: true
```

### Multihoming Configuration

```yaml
machine:
  network:
    interfaces:
      # Primary network
      - interface: eth0
        addresses:
          - 192.168.1.100/24
        routes:
          - network: 0.0.0.0/0
            gateway: 192.168.1.1
            metric: 100

      # Secondary network (management)
      - interface: eth1
        addresses:
          - 10.0.1.100/24
        routes:
          - network: 10.0.0.0/8
            gateway: 10.0.1.1
            metric: 200

      # Tailscale (added dynamically)
      - interface: tailscale0
        ignore: true  # Let Tailscale manage
```

### Terraform Example

```hcl
worker_patches = [
  yamlencode({
    machine = {
      network = {
        interfaces = [
          {
            interface = "eth0"
            dhcp      = true
          },
          {
            interface = "eth1"
            addresses = ["10.0.1.100/24"]
            routes = [{
              network = "10.0.0.0/8"
              gateway = "10.0.1.1"
              metric  = 200
            }]
          }
        ]
      }
    }
  })
]
```

---

## 4. Virtual (Shared) IP

### Overview

Configure a Virtual IP (VIP) for high availability, typically for control plane load balancing.

### Layer 2 VIP Configuration

```yaml
machine:
  network:
    interfaces:
      - interface: eth0
        addresses:
          - 192.168.1.101/24
        vip:
          ip: 192.168.1.100  # Shared VIP
          equinixMetal:
            apiToken: ""
          hcloud:
            apiToken: ""
```

### Control Plane with VIP

```yaml
cluster:
  controlPlane:
    endpoint: https://192.168.1.100:6443  # VIP endpoint
```

### Requirements

- All control plane nodes on same Layer 2 network
- VIP in same subnet as node IPs
- VIP not in DHCP range

### Terraform Example

```hcl
module "talos_cluster" {
  source = "../../modules/talos-cluster"

  cluster_name     = "ha-cluster"
  cluster_endpoint = "https://192.168.1.100:6443"  # VIP

  control_plane_nodes = {
    "cp-01" = {
      ip_address   = "192.168.1.101"
      install_disk = "/dev/sda"
    }
    "cp-02" = {
      ip_address   = "192.168.1.102"
      install_disk = "/dev/sda"
    }
    "cp-03" = {
      ip_address   = "192.168.1.103"
      install_disk = "/dev/sda"
    }
  }

  control_plane_patches = [
    yamlencode({
      machine = {
        network = {
          interfaces = [{
            interface = "eth0"
            vip = {
              ip = "192.168.1.100"
            }
          }]
        }
      }
    })
  ]
}
```

### Alternative: External Load Balancer

For cloud environments, use cloud load balancer instead:

```hcl
# AWS ALB, GCP Load Balancer, etc.
cluster_endpoint = "https://k8s-lb.example.com:6443"
```

---

## 5. PKI and Certificate Lifetimes

### Overview

Talos manages Kubernetes PKI certificates automatically. Configure certificate lifetimes and rotation.

### Certificate Configuration

**API Server Certificates:**

```yaml
cluster:
  apiServer:
    certSANs:
      - 192.168.1.100
      - k8s.example.com
      - "*.k8s.example.com"
    env:
      # Certificate validity (default: 8760h = 1 year)
      KUBE_API_SERVER_CERT_VALIDITY: "17520h"  # 2 years
```

**Kubelet Certificates:**

```yaml
machine:
  kubelet:
    extraArgs:
      # Enable certificate rotation
      rotate-certificates: "true"
      rotate-server-certificates: "true"
      # Certificate renewal threshold
      cert-rotation-threshold: "0.1"  # Renew at 10% remaining lifetime
```

### Certificate Locations

Talos manages certificates in:

- `/system/secrets/kubernetes/` - Kubernetes PKI
- `/system/secrets/etcd/` - etcd PKI
- `/system/secrets/` - Talos API certificates

### Certificate Rotation

**Automatic Rotation:**

- Kubelet certificates rotate automatically when `rotate-certificates: true`
- Control plane certificates managed by Talos

**Manual Renewal:**

```bash
# View certificate expiration
talosctl -n <node-ip> get certificates

# Renew certificates (requires Talos upgrade)
talosctl -n <node-ip> upgrade --image ghcr.io/siderolabs/installer:v1.8.0
```

### Terraform Example

```hcl
control_plane_patches = [
  yamlencode({
    machine = {
      kubelet = {
        extraArgs = {
          rotate-certificates        = "true"
          rotate-server-certificates = "true"
          cert-rotation-threshold    = "0.1"
        }
      }
    }
    cluster = {
      apiServer = {
        certSANs = [
          "192.168.1.100",
          "k8s.example.com",
          "*.k8s.example.com"
        ]
        env = {
          KUBE_API_SERVER_CERT_VALIDITY = "17520h"
        }
      }
    }
  })
]
```

---

## 6. Machine Configuration OAuth2 Authentication

### Overview

Authenticate Talos API access using OAuth2/OIDC providers.

### Configuration

```yaml
machine:
  features:
    rbac: true

cluster:
  apiServer:
    extraArgs:
      # OIDC configuration
      oidc-issuer-url: https://accounts.google.com
      oidc-client-id: kubernetes
      oidc-username-claim: email
      oidc-groups-claim: groups
      oidc-username-prefix: "oidc:"
      oidc-groups-prefix: "oidc:"
```

### Service Account Configuration

```yaml
cluster:
  apiServer:
    extraArgs:
      service-account-issuer: https://kubernetes.default.svc
      service-account-signing-key-file: /system/secrets/kubernetes/sa.key
      api-audiences: api,talos
```

### Terraform Example

```hcl
control_plane_patches = [
  yamlencode({
    machine = {
      features = {
        rbac = true
      }
    }
    cluster = {
      apiServer = {
        extraArgs = {
          oidc-issuer-url      = "https://accounts.google.com"
          oidc-client-id       = "kubernetes"
          oidc-username-claim  = "email"
          oidc-groups-claim    = "groups"
          oidc-username-prefix = "oidc:"
          oidc-groups-prefix   = "oidc:"
        }
      }
    }
  })
]
```

---

## 7. Role-Based Access Control (RBAC)

### Talos RBAC

**Enable Talos RBAC:**

```yaml
machine:
  features:
    rbac: true
```

**Configure Talos Roles:**

```bash
# Generate role-based talosconfig
talosctl config new admin-readonly \
  --roles os:reader \
  --crt admin.crt \
  --key admin.key
```

**Available Talos Roles:**

- `os:admin` - Full administrative access
- `os:reader` - Read-only access
- `os:operator` - Operational tasks (reboot, upgrade)

### Kubernetes RBAC

**ClusterRole Example:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-reader
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
```

**ClusterRoleBinding:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-pods
subjects:
  - kind: User
    name: jane@example.com
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

### Terraform Configuration

```hcl
control_plane_patches = [
  yamlencode({
    machine = {
      features = {
        rbac = true
      }
    }
    cluster = {
      apiServer = {
        extraArgs = {
          authorization-mode = "Node,RBAC"
        }
      }
    }
  })
]
```

---

## 8. Deploy Cilium CNI

### Overview

Cilium provides eBPF-based networking with advanced features like network policies, load balancing, and observability.

### Installation Methods

**Method 1: Talos Built-in (Recommended)**

```yaml
cluster:
  network:
    cni:
      name: none  # Don't install default CNI

cluster:
  inlineManifests:
    - name: cilium
      contents: |
        apiVersion: helm.cattle.io/v1
        kind: HelmChart
        metadata:
          name: cilium
          namespace: kube-system
        spec:
          repo: https://helm.cilium.io/
          chart: cilium
          version: 1.14.5
          targetNamespace: kube-system
          valuesContent: |
            ipam:
              mode: kubernetes
            kubeProxyReplacement: strict
            k8sServiceHost: localhost
            k8sServicePort: 7445
            hubble:
              enabled: true
              relay:
                enabled: true
              ui:
                enabled: true
```

**Method 2: Helm Post-Installation**

```bash
# After cluster bootstrap
helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium \
  --version 1.14.5 \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=strict \
  --set k8sServiceHost=localhost \
  --set k8sServicePort=7445 \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true
```

### Cilium with KubePrism

```yaml
cluster:
  network:
    cni:
      name: none

machine:
  features:
    kubeprism:
      enabled: true
      port: 7445
```

### Terraform Example

```hcl
module "talos_cluster" {
  source = "../../modules/talos-cluster"

  cluster_name     = "cilium-cluster"
  cluster_endpoint = "https://192.168.1.100:6443"
  cni_name         = "none"  # Install Cilium manually

  control_plane_patches = [
    yamlencode({
      machine = {
        features = {
          kubeprism = {
            enabled = true
            port    = 7445
          }
        }
      }
      cluster = {
        inlineManifests = [{
          name = "cilium"
          contents = <<-EOT
            apiVersion: v1
            kind: Namespace
            metadata:
              name: cilium
          EOT
        }]
      }
    })
  ]
}

# Apply Cilium via Helm after cluster is ready
resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.14.5"
  namespace  = "kube-system"

  set {
    name  = "ipam.mode"
    value = "kubernetes"
  }

  set {
    name  = "kubeProxyReplacement"
    value = "strict"
  }

  set {
    name  = "k8sServiceHost"
    value = "localhost"
  }

  set {
    name  = "k8sServicePort"
    value = "7445"
  }

  depends_on = [module.talos_cluster]
}
```

---

## 9. MayaStor Storage (OpenEBS Mayastor)

### Overview

MayaStor (now OpenEBS Mayastor) provides high-performance cloud-native storage using NVMe-oF.

### Prerequisites

```yaml
machine:
  kernel:
    modules:
      - name: nvme-tcp  # NVMe over TCP
      - name: nvme-fabrics
```

### Hugepages Configuration

```yaml
machine:
  kubelet:
    extraArgs:
      system-reserved: "memory=2Gi"
  sysctls:
    vm.nr_hugepages: "1024"
```

### Installation

```yaml
# OpenEBS Mayastor Helm Chart
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: mayastor
  namespace: mayastor
spec:
  repo: https://openebs.github.io/mayastor-extensions/
  chart: mayastor
  version: 2.4.0
  targetNamespace: mayastor
  valuesContent: |
    mayastor:
      io_engine:
        logLevel: info
      agents:
        ha:
          enabled: true
```

### Storage Class

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: mayastor-nvme
provisioner: io.openebs.csi-mayastor
parameters:
  repl: "3"
  protocol: "nvmf"
  ioTimeout: "60"
volumeBindingMode: WaitForFirstConsumer
```

### Terraform Example

```hcl
worker_patches = [
  yamlencode({
    machine = {
      kernel = {
        modules = [
          { name = "nvme-tcp" },
          { name = "nvme-fabrics" }
        ]
      }
      sysctls = {
        "vm.nr_hugepages" = "1024"
      }
      kubelet = {
        extraArgs = {
          system-reserved = "memory=2Gi"
        }
      }
    }
  })
]
```

---

## 10. Pod Security

### Pod Security Standards

```yaml
cluster:
  apiServer:
    extraArgs:
      # Enable Pod Security admission
      admission-control-config-file: /etc/kubernetes/admission-config.yaml
    extraVolumes:
      - name: admission-config
        hostPath: /var/etc/kubernetes/admission-config.yaml
        mountPath: /etc/kubernetes/admission-config.yaml
        readOnly: true

machine:
  files:
    - content: |
        apiVersion: apiserver.config.k8s.io/v1
        kind: AdmissionConfiguration
        plugins:
          - name: PodSecurity
            configuration:
              apiVersion: pod-security.admission.config.k8s.io/v1
              kind: PodSecurityConfiguration
              defaults:
                enforce: "restricted"
                enforce-version: "latest"
                audit: "restricted"
                audit-version: "latest"
                warn: "restricted"
                warn-version: "latest"
              exemptions:
                usernames: []
                runtimeClasses: []
                namespaces: [kube-system]
      path: /var/etc/kubernetes/admission-config.yaml
      permissions: 0644
```

### Namespace Pod Security Labels

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Terraform Example

```hcl
control_plane_patches = [
  yamlencode({
    cluster = {
      apiServer = {
        extraArgs = {
          admission-control-config-file = "/etc/kubernetes/admission-config.yaml"
        }
        extraVolumes = [{
          name      = "admission-config"
          hostPath  = "/var/etc/kubernetes/admission-config.yaml"
          mountPath = "/etc/kubernetes/admission-config.yaml"
          readOnly  = true
        }]
      }
    }
    machine = {
      files = [{
        content = <<-EOT
          apiVersion: apiserver.config.k8s.io/v1
          kind: AdmissionConfiguration
          plugins:
            - name: PodSecurity
              configuration:
                apiVersion: pod-security.admission.config.k8s.io/v1
                kind: PodSecurityConfiguration
                defaults:
                  enforce: "restricted"
                  enforce-version: "latest"
        EOT
        path        = "/var/etc/kubernetes/admission-config.yaml"
        permissions = "0644"
      }]
    }
  })
]
```

---

## 11. Deploying Metrics Server

### Installation

```yaml
cluster:
  inlineManifests:
    - name: metrics-server
      contents: |
        apiVersion: v1
        kind: ServiceAccount
        metadata:
          name: metrics-server
          namespace: kube-system
        ---
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: metrics-server
          namespace: kube-system
        spec:
          selector:
            matchLabels:
              k8s-app: metrics-server
          template:
            metadata:
              labels:
                k8s-app: metrics-server
            spec:
              serviceAccountName: metrics-server
              containers:
                - name: metrics-server
                  image: registry.k8s.io/metrics-server/metrics-server:v0.7.0
                  args:
                    - --cert-dir=/tmp
                    - --secure-port=10250
                    - --kubelet-preferred-address-types=InternalIP
                    - --kubelet-use-node-status-port
                    - --metric-resolution=15s
```

### Via Helm

```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args[0]=--kubelet-insecure-tls
```

### Verification

```bash
kubectl top nodes
kubectl top pods -A
```

---

## 12. Deploy Traefik as Gateway API

### Gateway API CRDs

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
```

### Traefik Installation

```yaml
cluster:
  inlineManifests:
    - name: traefik
      contents: |
        apiVersion: helm.cattle.io/v1
        kind: HelmChart
        metadata:
          name: traefik
          namespace: traefik
        spec:
          repo: https://traefik.github.io/charts
          chart: traefik
          version: 26.0.0
          targetNamespace: traefik
          valuesContent: |
            deployment:
              kind: DaemonSet
            ports:
              web:
                hostPort: 80
              websecure:
                hostPort: 443
            experimental:
              kubernetesGateway:
                enabled: true
            providers:
              kubernetesGateway:
                enabled: true
```

### Gateway Resource

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: traefik-gateway
  namespace: traefik
spec:
  gatewayClassName: traefik
  listeners:
    - name: http
      protocol: HTTP
      port: 80
    - name: https
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - name: tls-cert
```

---

## 13. Horizontal Pod Autoscaling (HPA)

### Prerequisites

- Metrics Server installed
- Resource requests defined on pods

### HPA Configuration

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 50
          periodSeconds: 15
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
```

### Testing

```bash
# Generate load
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://myapp; done"

# Watch HPA
kubectl get hpa -w
```

---

## 14. KubePrism

### Overview

KubePrism is a load balancer for Kubernetes API servers, built into Talos, providing high availability without external load balancers.

### Configuration

```yaml
machine:
  features:
    kubeprism:
      enabled: true
      port: 7445
```

### Benefits

- No external load balancer needed
- Automatic failover between control plane nodes
- Works with any CNI (especially Cilium)
- Local caching of Kubernetes API requests

### With Cilium

```yaml
machine:
  features:
    kubeprism:
      enabled: true
      port: 7445

cluster:
  network:
    cni:
      name: none  # Install Cilium with k8sServicePort: 7445
```

### Terraform Example

```hcl
control_plane_patches = [
  yamlencode({
    machine = {
      features = {
        kubeprism = {
          enabled = true
          port    = 7445
        }
      }
    }
  })
]
```

---

## 15. Node Labels

### Configuration

```yaml
machine:
  nodeLabels:
    node-role.kubernetes.io/worker: ""
    node.kubernetes.io/instance-type: "m5.large"
    topology.kubernetes.io/region: "us-west-2"
    topology.kubernetes.io/zone: "us-west-2a"
    environment: "production"
    workload-type: "compute"
```

### Node Annotations

```yaml
machine:
  nodeAnnotations:
    cluster-autoscaler.kubernetes.io/safe-to-evict: "true"
    backup.velero.io/backup-volumes: "data"
```

### Node Taints

```yaml
machine:
  nodeTaints:
    node-role.kubernetes.io/control-plane: "NoSchedule"
    workload=gpu: "NoSchedule"
```

### Terraform Example

```hcl
worker_patches = [
  yamlencode({
    machine = {
      nodeLabels = {
        "node-role.kubernetes.io/worker"      = ""
        "node.kubernetes.io/instance-type"    = "worker"
        "topology.kubernetes.io/region"       = "homelab"
        "environment"                          = "production"
        "workload-type"                        = "compute"
      }
      nodeAnnotations = {
        "cluster-autoscaler.kubernetes.io/safe-to-evict" = "true"
      }
      nodeTaints = {
        "workload" = "general:NoSchedule"
      }
    }
  })
]
```

---

## Summary

This guide covers advanced Talos Linux features essential for production Kubernetes clusters:

✅ **Host DNS** - Local DNS resolution for improved performance
✅ **Ingress Firewall** - nftables-based host firewall
✅ **Multihoming/Tailscale** - VPN integration and multi-network support
✅ **Virtual IP** - Layer 2 VIP for HA without external load balancer
✅ **PKI/Certificates** - Automatic cert management and rotation
✅ **OAuth2 Auth** - OIDC integration for API authentication
✅ **RBAC** - Talos and Kubernetes role-based access control
✅ **Cilium CNI** - eBPF-based networking with advanced features
✅ **MayaStor Storage** - High-performance NVMe-based storage
✅ **Pod Security** - Kubernetes Pod Security Standards
✅ **Metrics Server** - Resource metrics for monitoring
✅ **Traefik Gateway** - Gateway API ingress controller
✅ **HPA** - Horizontal pod autoscaling
✅ **KubePrism** - Built-in API server load balancer
✅ **Node Labels** - Node classification and scheduling

All configurations can be applied via Terraform using the talos-cluster module with custom patches.

## Next Steps

1. Review [Talos Cluster Specification](../../specs/talos/talos-cluster-specification.md)
2. Use [Talos Terraform Module](../../terraform/modules/talos-cluster/)
3. Deploy with custom patches for required features
4. Monitor cluster health with `talosctl health`
5. Configure backup strategy for etcd and persistent volumes

## References

- [Talos Documentation](https://www.talos.dev/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Cilium Documentation](https://docs.cilium.io/)
- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [OpenEBS Mayastor](https://openebs.io/docs/concepts/mayastor)

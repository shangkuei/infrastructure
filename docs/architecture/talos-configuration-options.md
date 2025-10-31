# Talos Linux Configuration Options

**Date**: 2025-11-01
**Status**: Reference Documentation
**Related**: [Talos Cluster Specification](../../specs/talos/talos-cluster-specification.md)

## Overview

This document catalogs the configuration options available in Talos Linux based on investigation of the official Talos Terraform provider and Talos v1.10 configuration schema.

## Talos Linux Capabilities

### Core Features

- **Immutable OS**: SquashFS-based read-only root filesystem
- **Minimal Attack Surface**: <50 binaries, no shell, no package manager, no SSH
- **API-Only Management**: mTLS-secured API for all operations
- **Declarative Configuration**: Single YAML file defines entire system state
- **Fast Deployment**: Boot to running Kubernetes in minutes
- **Automatic Updates**: Image-based updates with rollback capability

### Kubernetes Integration

- **Latest Versions**: Linux 6.16.9, Kubernetes 1.34.1, CNI Plugins 1.8.0 (as of 2025)
- **CNI Support**: Flannel (default), Cilium, Calico, or custom CNI
- **Multiple CNIs**: MetalLB, KubeVIP, Cilium for service exposure
- **Built-in Components**: CoreDNS, metrics-server, kube-proxy
- **Version Management**: Easy Kubernetes version upgrades via talosctl

### Storage Features

- **Raw User Volumes**: Unformatted disk space allocation as partitions
- **Existing Volume Support**: Mount existing partitions without formatting
- **Swap Support**: Block device swap configuration via SwapVolumeConfig
- **zswap**: Compressed swap page cache via ZswapConfig
- **Encryption**: System disk encryption support

### Network Features

- **Advanced Interface Config**: Bonds, bridges, VLANs, bridge ports
- **Device Selectors**: Match by bus path, MAC address, PCI ID, driver
- **WireGuard**: Built-in VPN support with peer configuration
- **KubeSpan**: Encrypted mesh networking for cluster nodes
- **VIP Support**: Virtual IP (Layer 2) for high availability
- **DHCP**: Full DHCP client support with custom options
- **IPv6**: Full IPv6 support with dual-stack capability

## Machine Configuration Schema (v1alpha1)

### Top-Level Structure

```yaml
version: v1alpha1
debug: true|false
machine: # Machine-specific configuration
cluster: # Cluster-wide configuration
```

### Machine Configuration

#### Machine Type

- **controlplane**: Runs Kubernetes control plane components (API server, scheduler, controller manager) + etcd
- **worker**: Runs only kubelet for workload pods

#### Installation Configuration (InstallConfig)

```yaml
machine:
  install:
    disk: /dev/sda                    # Installation disk
    image: ghcr.io/siderolabs/installer:v1.8.0
    wipe: false                       # Wipe disk before install
    extraKernelArgs:                  # Additional kernel arguments
      - console=ttyS1
      - panic=10
    diskSelector:                     # Alternative to explicit disk path
      size: 4GB
      model: WDC*
      busPath: /pci0000:00/*
      driver: virtio_net
```

#### Network Configuration (NetworkConfig)

**Basic Settings:**

```yaml
machine:
  network:
    hostname: worker-1
    nameservers:
      - 8.8.8.8
      - 1.1.1.1
    searchDomains:
      - example.com
    disableSearchDomain: false
```

**Interface Configuration:**

```yaml
machine:
  network:
    interfaces:
      - interface: eth0
        addresses:
          - 192.168.1.100/24
        routes:
          - network: 0.0.0.0/0
            gateway: 192.168.1.1
            metric: 1024
        mtu: 1500
        dhcp: false
        dhcpOptions:
          routeMetric: 1024
```

**Device Selection:**

```yaml
deviceSelector:
  busPath: 00:*                   # PCI/USB bus prefix (wildcard support)
  hardwareAddr: '*:f0:ab'         # MAC address (wildcard support)
  permanentAddr: 'aa:bb:cc:*'     # Permanent MAC
  pciID: '8086:1234'              # PCI vendor:device ID
  driver: virtio_net              # Kernel driver
  physical: true                  # Physical devices only
```

**Advanced Networking:**

- **Bond**: Link aggregation (modes: 802.3ad, active-backup, etc.)
- **Bridge**: Layer 2 bridge with STP support
- **VLAN**: 802.1Q VLAN tagging
- **WireGuard**: VPN tunnels with peer configuration
- **VIP**: Virtual IP for HA (Layer 2)

#### Kubelet Configuration (KubeletConfig)

```yaml
machine:
  kubelet:
    image: ghcr.io/siderolabs/kubelet:v1.31.0
    clusterDNS:
      - 10.96.0.10
      - 169.254.2.53
    extraArgs:
      rotate-server-certificates: "true"
      feature-gates: "ServerSideApply=true"
      max-pods: "150"
    extraMounts:                    # Additional container mounts
      - destination: /var/lib/example
        type: bind
        source: /var/lib/example
        options: [bind, rshared, rw]
    extraConfig:                    # Kubelet configuration overrides
      serverTLSBootstrap: true
    credentialProviderConfig:       # Cloud credential provider
      apiVersion: kubelet.config.k8s.io/v1
      kind: CredentialProviderConfig
    nodeIP:
      validSubnets:
        - 10.0.0.0/8
        - '!10.0.0.3/32'
        - fdc7::/16
    defaultRuntimeSeccompProfileEnabled: true
    registerWithFQDN: false
    skipNodeRegistration: false
    disableManifestsDirectory: false
```

#### Control Plane Configuration

```yaml
machine:
  controlPlane:
    controllerManager:
      disabled: false               # Disable controller-manager
    scheduler:
      disabled: false               # Disable scheduler
```

#### Security Configuration

**Certificates:**

```yaml
machine:
  token: <cluster-join-token>
  ca:
    crt: <ca-certificate>
    key: <ca-key>
  acceptedCAs:
    - <additional-ca-cert>
  certSANs:
    - 192.168.1.100
    - k8s.example.com
```

**System Disk Encryption:**

```yaml
machine:
  systemDiskEncryption:
    state:
      provider: luks2
      keys:
        - slot: 0
          tpm: {}
    ephemeral:
      provider: luks2
```

**Seccomp Profiles:**

```yaml
machine:
  seccompProfiles:
    - name: audit.json
      value:
        defaultAction: SCMP_ACT_LOG
```

#### System Configuration

**Kernel:**

```yaml
machine:
  kernel:
    modules:
      - name: btrfs
```

**Sysctls:**

```yaml
machine:
  sysctls:
    net.ipv4.ip_forward: "1"
    net.bridge.bridge-nf-call-iptables: "1"
```

**Sysfs:**

```yaml
machine:
  sysfs:
    devices.system.cpu.cpu0.cpufreq.scaling_governor: performance
```

**Environment:**

```yaml
machine:
  env:
    GRPC_GO_LOG_VERBOSITY_LEVEL: "99"
    GRPC_GO_LOG_SEVERITY_LEVEL: info
    http_proxy: http://proxy.example.com:8080
    https_proxy: http://proxy.example.com:8080
    no_proxy: localhost,127.0.0.1
```

**Time Configuration:**

```yaml
machine:
  time:
    disabled: false
    servers:
      - time.cloudflare.com
    bootTimeout: 2m0s
```

**Logging:**

```yaml
machine:
  logging:
    destinations:
      - endpoint: tcp://192.168.1.50:514
        format: json_lines
```

**Container Registry:**

```yaml
machine:
  registries:
    mirrors:
      docker.io:
        endpoints:
          - https://registry-1.docker.io
    config:
      registry.example.com:
        auth:
          username: user
          password: pass
        tls:
          insecureSkipVerify: true
```

**Files:**

```yaml
machine:
  files:
    - content: |
        example file content
      permissions: 0644
      path: /etc/example.conf
      op: create
```

**Node Labels and Taints:**

```yaml
machine:
  nodeLabels:
    node-role.kubernetes.io/worker: ""
    environment: production
  nodeAnnotations:
    annotation.example.com/key: value
  nodeTaints:
    node-role.kubernetes.io/control-plane: NoSchedule
```

### Cluster Configuration

#### Core Settings

```yaml
cluster:
  clusterName: my-cluster
  controlPlane:
    endpoint: https://192.168.1.100:6443
    localAPIServerPort: 443
  network:
    cni:
      name: flannel                 # flannel, cilium, calico, none
    dnsDomain: cluster.local
    podSubnets:
      - 10.244.0.0/16
    serviceSubnets:
      - 10.96.0.0/12
```

#### API Server Configuration

```yaml
cluster:
  apiServer:
    image: registry.k8s.io/kube-apiserver:v1.31.0
    certSANs:
      - 192.168.1.100
      - k8s.example.com
    extraArgs:
      audit-log-path: /var/log/audit.log
      audit-log-maxage: "30"
    extraVolumes:
      - hostPath: /var/log
        mountPath: /var/log
    env:
      GOGC: "100"
    disablePodSecurityPolicy: true
    admissionControl:
      - name: PodSecurity
        configuration:
          apiVersion: pod-security.admission.config.k8s.io/v1alpha1
          kind: PodSecurityConfiguration
```

#### etcd Configuration

```yaml
cluster:
  etcd:
    image: gcr.io/etcd-development/etcd:v3.5.11
    ca:
      crt: <ca-cert>
      key: <ca-key>
    extraArgs:
      quota-backend-bytes: "8589934592"
    advertisedSubnets:
      - 10.0.0.0/8
```

## Terraform Provider Resources

### Available Resources

1. **talos_machine_secrets**: Generate cluster secrets (certificates, tokens)
2. **talos_machine_configuration_apply**: Apply configuration to nodes
3. **talos_machine_bootstrap**: Bootstrap etcd and Kubernetes

### Available Data Sources

1. **talos_client_configuration**: Generate Talos client config
2. **talos_machine_configuration**: Generate machine configs (controlplane/worker)
3. **talos_cluster_kubeconfig**: Generate Kubernetes kubeconfig
4. **talos_cluster_health**: Check cluster health
5. **talos_machine_disks**: Query disk information (CEL expressions)

### Configuration Patches

Apply custom configurations via YAML patches:

```hcl
config_patches = [
  yamlencode({
    machine = {
      kubelet = {
        extraArgs = {
          rotate-server-certificates = "true"
        }
      }
      network = {
        nameservers = ["1.1.1.1", "8.8.8.8"]
      }
    }
  })
]
```

## Platform Support

Talos Linux runs on:

- **Cloud**: AWS, GCP, Azure, Oracle Cloud, DigitalOcean
- **Virtualization**: Proxmox, VMware, Hyper-V, KVM/QEMU
- **Bare Metal**: x86_64, ARM64
- **Edge**: Raspberry Pi, embedded devices
- **Containers**: Docker (for testing)

## Management Tools

- **talosctl**: CLI for Talos management
- **Terraform**: Infrastructure as Code via official provider
- **Sidero Omni**: SaaS management platform
- **Cluster API**: Kubernetes-native cluster management

## Security Features

1. **No SSH Access**: API-only management reduces attack surface
2. **Immutable OS**: Read-only root filesystem prevents tampering
3. **mTLS**: All API communication is encrypted and authenticated
4. **Minimal Binaries**: <50 binaries reduces CVE exposure
5. **Automatic Security Updates**: Image-based updates include patches
6. **TPM Support**: Disk encryption with TPM binding
7. **Seccomp Profiles**: Container syscall filtering

## Performance & Scaling

- **Boot Time**: ~1-2 minutes to running Kubernetes
- **Resource Usage**: ~100-200MB RAM for OS components
- **Cluster Size**: Tested up to hundreds of nodes
- **etcd**: Built-in with optimized defaults
- **Update Speed**: Rolling updates in minutes

## Limitations

1. **No Shell Access**: Debugging requires log analysis and metrics
2. **No Package Manager**: All software runs in containers
3. **Configuration Only at Boot**: Most changes require reboot
4. **Learning Curve**: Different from traditional Linux administration

## Best Practices

1. **Use Git**: Store machine configs in version control
2. **Backup etcd**: Regular automated etcd snapshots
3. **HA Control Plane**: Use 3+ control plane nodes for production
4. **Load Balancer**: Use LB for control plane endpoint in HA setups
5. **Monitoring**: Deploy metrics collection early
6. **Network Planning**: Plan CIDR ranges to avoid conflicts
7. **Testing**: Test upgrades in non-production first

## Resources

- [Talos Documentation](https://www.talos.dev/v1.10/)
- [Configuration Reference](https://www.talos.dev/v1.10/reference/configuration/)
- [Terraform Provider](https://registry.terraform.io/providers/siderolabs/talos/latest/docs)
- [GitHub Repository](https://github.com/siderolabs/talos)
- [Community Slack](https://slack.dev.talos-systems.io/)

## Version Information

- **Documented Version**: Talos v1.10 / v1.8.0
- **Kubernetes**: 1.28.x - 1.34.x
- **Terraform Provider**: >= 0.7.0
- **Last Updated**: 2025-11-01

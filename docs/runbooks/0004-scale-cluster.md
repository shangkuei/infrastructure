# Runbook: Scale Kubernetes Cluster

## Overview

Procedures for scaling Kubernetes cluster nodes up or down based on workload demands.

## Prerequisites

- Access to cloud provider (DigitalOcean, AWS, etc.)
- `kubectl` and `doctl`/`aws-cli` configured
- Terraform access (if using IaC)
- Understanding of current cluster capacity

## Procedure

### Scaling DigitalOcean Kubernetes (DOKS)

**Step 1: Check Current Capacity**

```bash
# View current nodes
kubectl get nodes
kubectl top nodes

# Check node pools
doctl kubernetes cluster node-pool list <cluster-id>

# Check resource usage
kubectl describe nodes | grep -A 5 "Allocated resources"
```

**Step 2: Scale Node Pool**

```bash
# Via doctl
doctl kubernetes cluster node-pool update <cluster-id> <pool-id> --count 5

# Or via Terraform
cd terraform/environments/production
terraform plan -var="node_count=5"
terraform apply -var="node_count=5"
```

**Step 3: Verify New Nodes**

```bash
# Watch nodes join
kubectl get nodes -w

# Check node readiness
kubectl get nodes
# Expected: All nodes STATUS=Ready

# Verify pods redistributed
kubectl get pods -A -o wide
```

### Scaling AWS EKS

**Step 1: Update Node Group**

```bash
# Via AWS CLI
aws eks update-nodegroup-config \
  --cluster-name my-cluster \
  --nodegroup-name my-nodegroup \
  --scaling-config minSize=3,maxSize=10,desiredSize=5

# Or via Terraform
terraform apply -var="desired_size=5"
```

**Step 2: Monitor Scaling**

```bash
# Watch Auto Scaling Group
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names <asg-name>

# Watch nodes
kubectl get nodes -w
```

## Verification

```bash
# 1. All nodes healthy
kubectl get nodes
# Expected: All Ready

# 2. Pods running
kubectl get pods -A
# Expected: No pending pods

# 3. Resource capacity increased
kubectl describe nodes | grep -A 5 "Allocatable"
```

## Rollback

```bash
# Scale back down
doctl kubernetes cluster node-pool update <cluster-id> <pool-id> --count 3

# Or Terraform
terraform apply -var="node_count=3"
```

## Troubleshooting

### Nodes Not Joining

**Check**:

```bash
doctl kubernetes cluster get <cluster-id>
kubectl get nodes
```

**Solutions**:

- Check cloud provider status
- Verify network connectivity
- Check cluster version compatibility

### Pods Not Scheduling on New Nodes

**Check**:

```bash
kubectl get pods -A -o wide
kubectl describe pod <pending-pod>
```

**Solutions**:

- Check node taints/tolerations
- Verify resource requests
- Check pod affinity rules

## Cost Impact

**DigitalOcean**:

- Basic node ($12/month): 3 nodes → 5 nodes = +$24/month
- Standard node ($24/month): 3 nodes → 5 nodes = +$48/month

**AWS**:

- t3.medium ($30/month): 3 nodes → 5 nodes = +$60/month

## References

- [DOKS Scaling](https://docs.digitalocean.com/products/kubernetes/how-to/scale/)
- [EKS Scaling](https://docs.aws.amazon.com/eks/latest/userguide/autoscaling.html)

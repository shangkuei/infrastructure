# CloudNativePG Operator

Cloud-native PostgreSQL operator for Kubernetes, installed via OLM v1.

## Overview

CloudNativePG is a comprehensive operator designed to manage PostgreSQL workloads on Kubernetes. It covers the full lifecycle of a PostgreSQL
cluster, from bootstrapping and upgrades to backup and recovery, including high availability and connection pooling.

## Installation Method

- **Operator Source**: [OperatorHub.io](https://operatorhub.io/operator/cloudnative-pg)
- **Installation**: OLM v1 ClusterExtension
- **Catalog**: operatorhubio
- **Channel**: stable
- **Namespace**: cloudnative-pg (operator), cluster-wide operation
- **Scope**: Cluster-wide (watches all namespaces)

## Components

- **namespace-cloudnative-pg.yaml**: Operator namespace
- **clusterextension-cloudnative-pg.yaml**: OLM v1 operator installation
- **kustomization.yaml**: Kustomize manifest

## Dependencies

- OLM v1 (operator-controller)
- operatorhubio ClusterCatalog
- Storage class for persistent volumes

## Features

- **High Availability**: Automated failover and self-healing
- **Backup & Recovery**: Continuous backup with point-in-time recovery (PITR)
- **Rolling Updates**: Zero-downtime PostgreSQL upgrades
- **Connection Pooling**: Built-in PgBouncer integration
- **Monitoring**: Prometheus metrics and observability
- **TLS/SSL**: Automatic certificate management
- **Declarative Configuration**: GitOps-friendly CRDs

## Usage

After installation, create PostgreSQL clusters using the Cluster CRD:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-cluster
  namespace: default
spec:
  instances: 3

  postgresql:
    parameters:
      max_connections: "100"
      shared_buffers: "256MB"

  storage:
    size: 10Gi
    storageClass: openebs-hostpath

  backup:
    barmanObjectStore:
      destinationPath: s3://backups/postgres
      s3Credentials:
        accessKeyId:
          name: backup-credentials
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: backup-credentials
          key: ACCESS_SECRET_KEY
```

## Documentation

- [CloudNativePG Documentation](https://cloudnative-pg.io/)
- [PostgreSQL Best Practices](https://cloudnative-pg.io/documentation/current/postgresql_conf/)
- [Backup and Recovery Guide](https://cloudnative-pg.io/documentation/current/backup_recovery/)
- [OperatorHub Listing](https://operatorhub.io/operator/cloudnative-pg)

## Storage Requirements

PostgreSQL requires persistent storage. Ensure you have a storage class configured:

- **Recommended**: openebs-hostpath or other local-path provisioner
- **Production**: Network-attached storage with backup capabilities
- **Minimum**: PV provisioner with RWO access mode

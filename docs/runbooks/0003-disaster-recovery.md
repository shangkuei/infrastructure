# Runbook: Disaster Recovery

## Overview

Procedures for recovering from catastrophic failures including cluster loss, data corruption, or regional outages.

## Prerequisites

- Backup access (Velero, etcd snapshots)
- Off-site backup storage (S3, Spaces)
- Terraform state backups
- Documented RTO/RPO targets

## Recovery Scenarios

### Scenario 1: Complete Cluster Loss

**Impact**: All Kubernetes cluster data lost

**Recovery Steps**:

1. **Provision New Cluster**

```bash
cd terraform/environments/production
terraform apply
```

2. **Restore Cluster State**

```bash
# Install Velero
helm install velero vmware-tanzu/velero

# Restore from backup
velero restore create --from-backup daily-backup-20250101
velero restore describe <restore-name>
```

3. **Verify Applications**

```bash
kubectl get pods -A
kubectl get pvc -A
kubectl get ingress -A
```

**RTO**: 2-4 hours  
**RPO**: 24 hours (daily backups)

### Scenario 2: Database Corruption

**Impact**: Application database corrupted/lost

**Recovery Steps**:

1. **Restore from Snapshot**

```bash
# DigitalOcean
doctl databases backups list <database-id>
doctl databases backups restore <database-id> <backup-id>

# Or use PITR (Point-in-Time Recovery)
```

2. **Verify Data Integrity**

```bash
# Connect to database
doctl databases connection <database-id>

# Run integrity checks
SELECT COUNT(*) FROM critical_table;
```

3. **Restore Application**

```bash
kubectl rollout restart deployment/app -n production
```

**RTO**: 1-2 hours  
**RPO**: 1 hour (automated backups)

### Scenario 3: Regional Outage

**Impact**: Entire cloud region unavailable

**Recovery Steps**:

1. **Activate DR Region**

```bash
cd terraform/environments/dr
terraform apply
```

2. **Update DNS**

```bash
# Update Cloudflare DNS to point to DR region
doctl compute cdn update <cdn-id> --origin dr.example.com
```

3. **Restore Data**

```bash
# Sync from cross-region replica or restore from backup
```

**RTO**: 4-8 hours (manual DR activation)  
**RPO**: Depends on replication (real-time to 24 hours)

## Verification Checklist

After recovery:

- [ ] All critical pods running
- [ ] Database connections working
- [ ] External access functional (DNS, ingress)
- [ ] Monitoring and alerts active
- [ ] Backups resumed
- [ ] Application functionality tested
- [ ] Performance metrics normal

## Post-Recovery

1. **Document Incident**
   - Timeline of events
   - Root cause analysis
   - Recovery actions taken
   - Lessons learned

2. **Update Procedures**
   - Refine runbooks based on experience
   - Update RTO/RPO estimates
   - Improve backup strategy

3. **Test Recovery**
   - Schedule regular DR drills
   - Validate backups monthly
   - Test restoration procedures quarterly

## Backup Strategy

### Kubernetes Resources

```bash
# Install Velero
helm install velero vmware-tanzu/velero \
  --set configuration.provider=aws \
  --set configuration.backupStorageLocation.bucket=backups \
  --set configuration.backupStorageLocation.config.region=nyc3

# Create backup schedule
velero schedule create daily-backup --schedule="0 1 * * *"
```

### Databases

```bash
# Enable automated backups (DigitalOcean)
doctl databases update <database-id> --backup-hour 2 --backup-minute 0

# Manual backup
doctl databases backups create <database-id>
```

### Infrastructure State

```bash
# Terraform state backup (automated via Terraform Cloud)
# Or manual:
terraform state pull > terraform.tfstate.backup
aws s3 cp terraform.tfstate.backup s3://backups/terraform/
```

## Contacts

**On-Call**: Use PagerDuty rotation  
**Cloud Provider Support**: Via support tickets  
**Database DBA**: [Contact info]  

## References

- [Velero Documentation](https://velero.io/docs/)
- [Kubernetes Backup Best Practices](https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/)

# Secrets & DB Encryption Monitoring Reference

## Overview
Comprehensive monitoring for External Secrets sync status and database encryption key versions integrated into the GitOps observability stack.

## New Alerts Configured

### External Secrets Monitoring

#### 1. **ExternalSecretNotReady** (Critical)
- **Trigger**: `external_secrets_sync_calls_error > 0` for 5 minutes
- **Severity**: Critical
- **Description**: External Secret sync failures detected
- **Possible Causes**:
  - OCI Vault secret not found
  - IAM permissions insufficient (IRSA)
  - Network connectivity issues
  - Secret format mismatch

#### 2. **ExternalSecretStatusNotSynced** (Critical)
- **Trigger**: `externalsecret_status_condition{condition="Ready", status="False"} == 1` for 10 minutes
- **Severity**: Critical
- **Description**: ExternalSecret not in Ready state
- **Impact**: Application may be unable to start or function correctly
- **Action**: `kubectl describe externalsecret <name> -n platform`

### DB Encryption Key Version Monitoring

#### 3. **DBEncryptionKeyVersionStale** (Warning)
- **Trigger**: `mokhaback_db_encryption_key_version_distribution{version!="current"} > 1000` for 24 hours
- **Severity**: Warning
- **Description**: Large number of records using old encryption key version
- **Possible Causes**:
  - Re-encryption job not running or failed
  - High data volume requiring longer migration time
  - Performance constraints preventing re-encryption

#### 4. **MultipleEncryptionKeyVersionsActive** (Info)
- **Trigger**: More than 3 encryption key versions active for 1 hour
- **Severity**: Info
- **Description**: Multiple encryption key versions in use
- **Normal During**: Key rotation (should reduce over time as re-encryption completes)

## Dashboard Enhancements

### New Panels Added to Secret Rotation Dashboard

#### External Secrets Status Section (Row 5)

1. **External Secrets Ready Status Table**
   - **Type**: Table
   - **Shows**: All ExternalSecrets with their Ready condition status
   - **Color Coding**: Green (Ready), Red (Not Ready)
   - **Location**: Grid position (0, 34), 12 width

2. **External Secrets Sync Calls Rate Graph**
   - **Type**: Time series
   - **Shows**: Rate of sync calls by status (success/error)
   - **Metric**: `rate(external_secrets_sync_calls_total[5m])`
   - **Location**: Grid position (12, 34), 12 width

#### DB Encryption Key Versions Section (Row 6)

3. **DB Encryption Key Version Distribution - Detailed Table**
   - **Type**: Table
   - **Shows**: All tables/fields with encryption key version distribution
   - **Columns**: Table, Field, Key Version, Record Count
   - **Sorting**: By record count (descending)
   - **Color Coding**: Gradient gauge for record count, background color for version
   - **Location**: Grid position (0, 42), 24 width

#### Summary Stats (Row 7)

4. **External Secrets Sync Errors (Last 1h)**
   - **Type**: Stat
   - **Metric**: `sum(increase(external_secrets_sync_calls_error[1h]))`
   - **Threshold**: 0=Green, 1=Red
   - **Location**: Grid position (0, 52), 8 width

5. **Records Using Old Encryption Keys**
   - **Type**: Stat
   - **Metric**: `sum(mokhaback_db_encryption_key_version_distribution{version!="current"})`
   - **Thresholds**: 0=Green, 100=Yellow, 1000=Red
   - **Location**: Grid position (8, 52), 8 width

6. **Active Encryption Key Versions**
   - **Type**: Stat
   - **Metric**: `count(count by (version) (...))`
   - **Thresholds**: 0-2=Green, 3-4=Yellow, 5+=Orange
   - **Location**: Grid position (16, 52), 8 width

## Accessing the Dashboard

**Grafana URL**: `http://localhost:3000/d/mokhaback-secrets-rotation/`

**Port Forward**:
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

**Credentials**:
- Username: `admin`
- Password: `<from OCI Vault monitoring secret>`

## Metrics Reference

### External Secrets Operator Metrics
- `external_secrets_sync_calls_total` - Total sync calls
- `external_secrets_sync_calls_error` - Failed sync calls
- `externalsecret_status_condition` - ExternalSecret Ready condition

### Application Encryption Metrics
- `mokhaback_db_encryption_key_version_distribution` - Records per key version
- `mokhaback_db_encryption_key_rotation_timestamp_seconds` - Last rotation time
- `mokhaback_jwt_key_rotation_timestamp_seconds` - JWT key rotation time

## Troubleshooting

### External Secret Not Syncing

1. Check ExternalSecret status:
   ```bash
   kubectl get externalsecret -n platform
   kubectl describe externalsecret <name> -n platform
   ```

2. Check External Secrets Operator logs:
   ```bash
   kubectl logs -n external-secrets-operator deployment/external-secrets
   ```

3. Verify OCI Vault:
   ```bash
   oci vault secret get-secret-bundle --secret-id <secret-path>
   ```

### High Number of Old Key Version Records

1. Check re-encryption job status:
   ```bash
   kubectl get jobs -n platform | grep reencrypt
   kubectl logs -n platform job/<reencrypt-job-name>
   ```

2. Verify rotation CronJob schedule:
   ```bash
   kubectl get cronjob -n platform
   ```

3. Monitor re-encryption progress:
   ```promql
   mokhaback_db_encryption_key_version_distribution{version="current"} / 
   sum(mokhaback_db_encryption_key_version_distribution)
   ```

## Alert Summary

Total Alerts Configured: **15**
- **Security & Rotation**: 8 alerts
- **External Secrets**: 2 alerts (NEW)
- **DB Encryption Versions**: 2 alerts (NEW)
- **RED Metrics**: 6 alerts

All alerts are automatically loaded into Prometheus via the PrometheusRule CRD and managed through GitOps.

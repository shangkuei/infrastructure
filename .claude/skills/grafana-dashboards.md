# Grafana Dashboards Skill

Build and manage Grafana dashboards for the monitoring stack.

## When to Use

Use this skill when:

- Adding dashboards from Grafana Labs community
- Adding dashboards from upstream projects (Flux, SeaweedFS, etc.)
- Creating custom dashboards for services
- Fixing datasource references in imported dashboards

## Dashboard Infrastructure

### Jsonnet-Based Dashboards (Mixins)

Located in: `kubernetes/overlays/monitor-cluster/shangkuei-lab/_dashboards/`

- `dashboards.jsonnet` - Main file combining all mixins
- `build-dashboards.sh` - Builds jsonnet dashboards
- `vendor/` - Jsonnet dependencies (jsonnetfile.json)

### External Dashboards

Located in: `kubernetes/overlays/monitor-cluster/shangkuei-lab/_dashboards/`

- `build-external-dashboards.sh` - Downloads and processes external dashboards
- `external-dashboards/` - Temporary download directory (cleaned up after build)

### Generated Manifests

Located in: `kubernetes/overlays/monitor-cluster/shangkuei-lab/grafanadashboards/`

- `grafanadashboard-*.yaml` - GrafanaDashboard CRs for each category

## Adding Community Dashboards

### Step 1: Find Dashboard ID

Search Grafana Labs: https://grafana.com/grafana/dashboards/

Note the dashboard ID from the URL (e.g., `13192` for Gitea, `22555` for Immich).

### Step 2: Update build-external-dashboards.sh

Add the dashboard download:

```bash
# Add dashboard ID constant
<SERVICE>_DASHBOARD_ID="<ID>"

# Add download command
echo "==> Downloading <Category> dashboards from Grafana Labs..."
curl -sL "${GRAFANA_LABS_API}/${<SERVICE>_DASHBOARD_ID}/revisions/latest/download" \
  -o "${OUTPUT_DIR}/<service>.json"

# Patch the dashboard
patch_dashboard "${OUTPUT_DIR}/<service>.json" "<uid>" "<Title>"

# Fix datasource references (uses existing function)
fix_seaweedfs_datasource "${OUTPUT_DIR}/<service>.json"
```

### Step 3: Generate Manifest

Add to the manifest generation:

```bash
generate_manifest \
  "${MANIFEST_DIR}/grafanadashboard-<category>.yaml" \
  "<Folder Name>" \
  "Grafana Dashboards for <Category> - Source: https://grafana.com/grafana/dashboards/" \
  "${OUTPUT_DIR}/<service>.json"
```

### Step 4: Run Build Script

```bash
cd kubernetes/overlays/monitor-cluster/shangkuei-lab/_dashboards
./build-external-dashboards.sh
```

### Step 5: Verify Generated Manifest

Check the generated file in `grafanadashboards/` directory.

## Adding Mixin-Based Dashboards

### Step 1: Add Dependency

Update `jsonnetfile.json`:

```json
{
  "source": {
    "git": {
      "remote": "https://github.com/<org>/<repo>.git",
      "subdir": "<mixin-path>"
    }
  },
  "version": "<tag-or-branch>"
}
```

Install dependencies:

```bash
jb install
```

### Step 2: Import Mixin

Update `dashboards.jsonnet`:

```jsonnet
// Import mixin
local <service>Mixin = (import '<service>-mixin/mixin.libsonnet') {
  _config+:: {
    // Override config as needed
  },
};

// Add to dashboard generation
local <service>Dashboards = {
  [k]: unhideClusterVariable(<service>Mixin.grafanaDashboards[k])
  for k in std.objectFields(<service>Mixin.grafanaDashboards)
  if isRelevant<Service>Dashboard(k)
};

// Combine with other dashboards
kpDashboards + ... + <service>Dashboards
```

### Step 3: Build Dashboards

```bash
./build-dashboards.sh
```

## Common Fixes

### Datasource References

External dashboards often use `__inputs` with placeholders like `${DS_PROMETHEUS}`.

The `fix_seaweedfs_datasource` function handles this:

```bash
jq '
  del(.__inputs, .__requires) |
  walk(
    if type == "object" and has("datasource") then
      if .datasource == null or
         .datasource == "${DS_PROMETHEUS}" or
         (.datasource | type == "string" and startswith("${DS_")) then
        .datasource = {"type": "prometheus", "uid": "${DS_PROMETHEUS}"}
      else
        .
      end
    else
      .
    end
  )
'
```

### Job Label Mismatches

Upstream dashboards may use different job labels. Fix with sed:

```bash
sed -i.bak \
  -e 's/exported_job=\\"<upstream_name>\\"/job=\\"<our_job_name>\\"/g' \
  "$json_file"
```

### Multi-Cluster Support

Unhide the cluster variable for dashboards:

```jsonnet
local unhideClusterVariable(dashboard) =
  if std.objectHas(dashboard, 'templating') && std.objectHas(dashboard.templating, 'list') then
    dashboard {
      templating+: {
        list: [
          if std.objectHas(item, 'name') && item.name == 'cluster' then
            item { hide: 0 }
          else
            item
          for item in dashboard.templating.list
        ],
      },
    }
  else
    dashboard;
```

## GrafanaDashboard CR Structure

```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: <dashboard-name>
  namespace: monitoring
spec:
  instanceSelector:
    matchLabels:
      dashboards: grafana
  allowCrossNamespaceImport: true
  folder: "<Folder Name>"
  resyncPeriod: 24h
  json: |
    <indented-dashboard-json>
```

## Creating Custom Dashboards Manually

For dashboards that don't come from external sources, create the GrafanaDashboard CR directly:

### Step 1: Create Dashboard JSON

Design your dashboard in Grafana UI, then export as JSON.

Key requirements:

- Use `${DS_PROMETHEUS}` for Prometheus datasource references
- Include cluster variable for multi-cluster support
- Use `$__rate_interval` instead of fixed intervals in queries

### Step 2: Create GrafanaDashboard Manifest

```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: <dashboard-name>
  namespace: monitoring
spec:
  instanceSelector:
    matchLabels:
      dashboards: grafana
  allowCrossNamespaceImport: true
  folder: "<Folder Name>"
  resyncPeriod: 24h
  json: |
    {
      "title": "<Dashboard Title>",
      "uid": "<unique-id>",
      "templating": {
        "list": [
          {
            "name": "DS_PROMETHEUS",
            "type": "datasource",
            "query": "prometheus"
          },
          {
            "name": "cluster",
            "type": "query",
            "query": "label_values(up, cluster)"
          }
        ]
      },
      ...
    }
```

### Step 3: Add to Kustomization

Edit `kubernetes/overlays/monitor-cluster/shangkuei-lab/kustomization.yaml`:

```yaml
resources:
  # Under appropriate section
  - grafanadashboards/grafanadashboard-<name>.yaml
```

## Current Dashboard Categories

| Manifest File | Folder | Sources |
|---------------|--------|---------|
| grafanadashboard-flux.yaml | Flux CD | github.com/fluxcd/flux2-monitoring-example |
| grafanadashboard-seaweedfs.yaml | SeaweedFS | github.com/seaweedfs/seaweedfs |
| grafanadashboard-cloudflared.yaml | Cloudflare | Custom (cloudflared metrics) |
| grafanadashboard-docker-containers.yaml | Infrastructure | Custom (cAdvisor metrics) |
| grafanadashboard-unraid-nas.yaml | Infrastructure | Custom (node-exporter metrics) |
| grafanadashboard-gitea.yaml | Unraid Applications | Grafana Labs (ID: 13192) + Custom |
| grafanadashboard-immich.yaml | Unraid Applications | Grafana Labs (ID: 22555) + Custom |
| grafanadashboard-vaultwarden.yaml | Unraid Applications | Custom (vwmetrics exporter) |
| grafanadashboard-plex.yaml | Unraid Applications | Custom (plex-media-server-exporter) |
| grafanadashboard-*.yaml | Various | kube-prometheus, mixins |

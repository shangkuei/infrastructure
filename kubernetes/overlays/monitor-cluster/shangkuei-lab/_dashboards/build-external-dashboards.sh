#!/usr/bin/env bash
# Build Grafana dashboards from external sources (Flux, SeaweedFS)
# Note: Alloy dashboards are built from jsonnet via build-dashboards.sh
# Downloads dashboards from upstream repos and generates GrafanaDashboard CRs
# Prerequisites: curl, jq
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/external-dashboards"
MANIFEST_DIR="${SCRIPT_DIR}/../grafanadashboards"

# Dashboard sources
FLUX_REPO="https://raw.githubusercontent.com/fluxcd/flux2-monitoring-example/main/monitoring/configs/dashboards"
SEAWEEDFS_REPO="https://raw.githubusercontent.com/seaweedfs/seaweedfs/master/other/metrics"

# Create output directory
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

echo "==> Downloading Flux dashboards..."
curl -sL "${FLUX_REPO}/cluster.json" -o "${OUTPUT_DIR}/flux-cluster.json"
curl -sL "${FLUX_REPO}/control-plane.json" -o "${OUTPUT_DIR}/flux-control-plane.json"
curl -sL "${FLUX_REPO}/logs.json" -o "${OUTPUT_DIR}/flux-logs.json"

echo "==> Downloading SeaweedFS dashboards..."
curl -sL "${SEAWEEDFS_REPO}/grafana_seaweedfs.json" -o "${OUTPUT_DIR}/seaweedfs-overview.json"
curl -sL "${SEAWEEDFS_REPO}/grafana_seaweedfs_heartbeat.json" -o "${OUTPUT_DIR}/seaweedfs-heartbeat.json"
curl -sL "${SEAWEEDFS_REPO}/grafana_seaweedfs_k8s.json" -o "${OUTPUT_DIR}/seaweedfs-s3-api.json"

echo "==> Patching dashboards..."

# Function to patch dashboard JSON
patch_dashboard() {
  local input_file="$1"
  local uid="$2"
  local title="$3"

  jq --arg uid "$uid" --arg title "$title" '
    .uid = $uid |
    .title = $title |
    # Remove editable and id to let Grafana manage them
    del(.id) |
    .editable = false
  ' "$input_file" > "${input_file}.tmp" && mv "${input_file}.tmp" "$input_file"
}

# Patch Flux dashboards
patch_dashboard "${OUTPUT_DIR}/flux-cluster.json" "flux-cluster" "Flux Cluster Stats"
patch_dashboard "${OUTPUT_DIR}/flux-control-plane.json" "flux-control-plane" "Flux Control Plane"
patch_dashboard "${OUTPUT_DIR}/flux-logs.json" "flux-logs" "Flux Logs"

# Patch Flux logs dashboard - fix variable queries to include namespace filter
echo "==> Patching Flux logs dashboard variable queries..."
jq '
  .templating.list = [.templating.list[] |
    if .name == "controller" or .name == "app" then
      .query = "label_values({namespace=~\"$namespace\"}, app)" |
      .definition = "label_values({namespace=~\"$namespace\"}, app)"
    elif .name == "stream" then
      .query = "label_values({namespace=~\"$namespace\"}, stream)" |
      .definition = "label_values({namespace=~\"$namespace\"}, stream)"
    else
      .
    end
  ]
' "${OUTPUT_DIR}/flux-logs.json" > "${OUTPUT_DIR}/flux-logs.json.tmp" \
  && mv "${OUTPUT_DIR}/flux-logs.json.tmp" "${OUTPUT_DIR}/flux-logs.json"

# Patch SeaweedFS dashboards
patch_dashboard "${OUTPUT_DIR}/seaweedfs-overview.json" "seaweedfs-overview" "SeaweedFS Overview"
patch_dashboard "${OUTPUT_DIR}/seaweedfs-heartbeat.json" "seaweedfs-heartbeat" "SeaweedFS Heartbeat"
patch_dashboard "${OUTPUT_DIR}/seaweedfs-s3-api.json" "seaweedfs-s3-api" "SeaweedFS S3 API"

# Fix SeaweedFS datasource references
# The upstream dashboards use __inputs with DS_PROMETHEUS and mixed datasource formats
# Convert to the standard format: {"type": "prometheus", "uid": "${DS_PROMETHEUS}"}
echo "==> Fixing SeaweedFS dashboard datasource references..."
fix_seaweedfs_datasource() {
  local input_file="$1"
  jq '
    # Remove __inputs and __requires sections (used for import, not runtime)
    del(.__inputs, .__requires) |
    # Fix all datasource references recursively
    # Handle various formats: null, "${DS_PROMETHEUS}", "${DS_PROMETHEUS-DEV}", string refs
    walk(
      if type == "object" and has("datasource") then
        if .datasource == null or
           .datasource == "${DS_PROMETHEUS}" or
           .datasource == "${DS_PROMETHEUS-DEV}" or
           (.datasource | type == "string" and startswith("${DS_")) then
          .datasource = {"type": "prometheus", "uid": "${DS_PROMETHEUS}"}
        else
          .
        end
      else
        .
      end
    )
  ' "$input_file" > "${input_file}.tmp" && mv "${input_file}.tmp" "$input_file"
}

fix_seaweedfs_datasource "${OUTPUT_DIR}/seaweedfs-overview.json"
fix_seaweedfs_datasource "${OUTPUT_DIR}/seaweedfs-heartbeat.json"
fix_seaweedfs_datasource "${OUTPUT_DIR}/seaweedfs-s3-api.json"

# Fix SeaweedFS job labels in queries
# Upstream dashboards use exported_job="filer|volume" but our ServiceMonitors use job="seaweedfs-*"
# Note: In JSON, quotes are escaped as \" so we need to handle both formats
echo "==> Fixing SeaweedFS job label references in queries..."
for json_file in "${OUTPUT_DIR}"/seaweedfs-*.json; do
  sed -i.bak \
    -e 's/exported_job=\\"filer\\"/job=\\"seaweedfs-filer\\"/g' \
    -e 's/exported_job=\\"volume\\"/job=\\"seaweedfs-volume\\"/g' \
    -e 's/exported_job="filer"/job="seaweedfs-filer"/g' \
    -e 's/exported_job="volume"/job="seaweedfs-volume"/g' \
    "$json_file"
  rm -f "${json_file}.bak"
done

# Fix SeaweedFS S3 API dashboard service filters
# Upstream dashboard uses service=~"$service-*" filters which expect specific service naming
# Our services are named seaweedfs-filer, seaweedfs-volume, etc.
# Remove all service filters since we filter by namespace instead
echo "==> Fixing SeaweedFS S3 API dashboard service filters..."
sed -i.bak \
  -e "s/,service=~\\\\\"\\\$service-api\\\\\"//g" \
  -e "s/service=~\\\\\"\\\$service-api\\\\\",//g" \
  -e "s/,service=~\\\\\"\\\$service-volume\\\\\"//g" \
  -e "s/service=~\\\\\"\\\$service-volume\\\\\",//g" \
  "${OUTPUT_DIR}/seaweedfs-s3-api.json"
rm -f "${OUTPUT_DIR}/seaweedfs-s3-api.json.bak"

# Fix SeaweedFS S3 API dashboard namespace variable query
# Upstream uses endpoint="metrics" but our ServiceMonitors use endpoint names like "filer-metrics", "volume-metrics"
echo "==> Fixing SeaweedFS S3 API dashboard namespace variable..."
jq '
  .templating.list = [.templating.list[] |
    if .name == "namespace" then
      .query = "label_values(SeaweedFS_build_info, namespace)" |
      .definition = "label_values(SeaweedFS_build_info, namespace)"
    else
      .
    end
  ]
' "${OUTPUT_DIR}/seaweedfs-s3-api.json" > "${OUTPUT_DIR}/seaweedfs-s3-api.json.tmp" \
  && mv "${OUTPUT_DIR}/seaweedfs-s3-api.json.tmp" "${OUTPUT_DIR}/seaweedfs-s3-api.json"

# Fix SeaweedFS S3 API dashboard endpoint filters
# Upstream uses endpoint="metrics" but our endpoints are named "filer-metrics", "volume-metrics", "master-metrics"
# Change to regex pattern that matches all our endpoints
echo "==> Fixing SeaweedFS S3 API dashboard endpoint filters..."
sed -i.bak \
  -e "s/endpoint=\\\\\"metrics\\\\\"/endpoint=~\\\\\".*-metrics\\\\\"/g" \
  -e "s/endpoint=\\\\\"swfs-\.\*-metrics\\\\\"/endpoint=~\\\\\".*-metrics\\\\\"/g" \
  "${OUTPUT_DIR}/seaweedfs-s3-api.json"
rm -f "${OUTPUT_DIR}/seaweedfs-s3-api.json.bak"

# Fix SeaweedFS S3 API dashboard variable case mismatch
# Upstream has queries using $NAMESPACE but variable is defined as $namespace (case-sensitive)
echo "==> Fixing SeaweedFS S3 API dashboard variable case..."
sed -i.bak \
  -e 's/\$NAMESPACE/\$namespace/g' \
  "${OUTPUT_DIR}/seaweedfs-s3-api.json"
rm -f "${OUTPUT_DIR}/seaweedfs-s3-api.json.bak"

# Remove "Heartbeat by Host (Push Metrics Delta)" panel from heartbeat dashboard
# This panel requires push_time_seconds metric which only exists with Pushgateway setups
# Dashboard uses older "rows" format with nested panels
echo "==> Removing unsupported panel from SeaweedFS Heartbeat dashboard..."
jq '
  .rows = [.rows[] |
    .panels = [.panels[] | select(.title != "Heartbeat by Host (Push Metrics Delta)")]
  ]
' "${OUTPUT_DIR}/seaweedfs-heartbeat.json" > "${OUTPUT_DIR}/seaweedfs-heartbeat.json.tmp" \
  && mv "${OUTPUT_DIR}/seaweedfs-heartbeat.json.tmp" "${OUTPUT_DIR}/seaweedfs-heartbeat.json"

# Function to generate GrafanaDashboard CR
generate_manifest() {
  local output_file="$1"
  local folder="$2"
  local header="$3"
  shift 3
  local json_files=("$@")

  echo "==> Generating ${output_file}..."

  cat > "${output_file}" << EOF
---
# ${header}
# Do not edit manually - regenerate with: ./dashboards/build-external-dashboards.sh
EOF

  for json_file in "${json_files[@]}"; do
    local name
    name=$(basename "$json_file" .json)

    cat >> "${output_file}" << EOF

---
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: ${name}
  namespace: monitoring
spec:
  instanceSelector:
    matchLabels:
      dashboards: grafana
  allowCrossNamespaceImport: true
  folder: "${folder}"
  resyncPeriod: 24h
  json: |
EOF
    # Indent the JSON with 4 spaces
    cat "$json_file" | sed 's/^/    /' >> "${output_file}"
  done
}

# Generate Flux dashboard manifest
generate_manifest \
  "${MANIFEST_DIR}/grafanadashboard-flux.yaml" \
  "Flux CD" \
  "Grafana Dashboards for Flux CD - Source: https://github.com/fluxcd/flux2-monitoring-example" \
  "${OUTPUT_DIR}/flux-cluster.json" \
  "${OUTPUT_DIR}/flux-control-plane.json" \
  "${OUTPUT_DIR}/flux-logs.json"

# Generate SeaweedFS dashboard manifest
generate_manifest \
  "${MANIFEST_DIR}/grafanadashboard-seaweedfs.yaml" \
  "SeaweedFS" \
  "Grafana Dashboards for SeaweedFS - Source: https://github.com/seaweedfs/seaweedfs" \
  "${OUTPUT_DIR}/seaweedfs-overview.json" \
  "${OUTPUT_DIR}/seaweedfs-heartbeat.json" \
  "${OUTPUT_DIR}/seaweedfs-s3-api.json"

echo "==> Generated manifests:"
echo "    - ${MANIFEST_DIR}/grafanadashboard-flux.yaml"
echo "    - ${MANIFEST_DIR}/grafanadashboard-seaweedfs.yaml"

# Cleanup
rm -rf "${OUTPUT_DIR}"
echo "==> Done!"

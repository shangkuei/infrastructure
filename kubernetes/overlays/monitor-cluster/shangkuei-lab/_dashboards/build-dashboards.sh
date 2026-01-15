#!/usr/bin/env bash
# Build Grafana dashboards and PrometheusRules from kube-prometheus jsonnet
# Prerequisites: jsonnet, jsonnet-bundler (jb), jq
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/output-dashboards"
ALERTS_OUTPUT_DIR="${SCRIPT_DIR}/output-alerts"
DASHBOARD_DIR="${SCRIPT_DIR}/../grafanadashboards"
RULES_DIR="${SCRIPT_DIR}/../prometheusrules"

cd "${SCRIPT_DIR}"

echo "==> Installing jsonnet dependencies..."
jb install

echo "==> Building dashboards from jsonnet..."
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"
jsonnet -J vendor -m "${OUTPUT_DIR}" dashboards.jsonnet

# The jsonnet output is a JSON-encoded string, decode it to proper JSON
echo "==> Decoding dashboard JSON files..."
for json_file in "${OUTPUT_DIR}"/*.json; do
  # Parse the JSON string and output proper JSON
  jq -r '.' "${json_file}" > "${json_file}.tmp" && mv "${json_file}.tmp" "${json_file}"
done

# Fix Loki dashboards for SSD mode
# The loki-mixin doesn't properly replace container-based resource queries for SSD mode
# In SSD mode, all containers are named 'loki', so we filter by pod name instead
echo "==> Fixing Loki SSD mode resource queries..."
for loki_dashboard in "${OUTPUT_DIR}"/loki-*.json; do
  if [[ -f "${loki_dashboard}" ]]; then
    # Replace container patterns with pod patterns for SSD mode
    # distributor/ingester -> loki.*-write.*, querier -> loki.*-read.*, backend -> loki.*-backend.*
    # Also fix log filter: |= "level=error" (substring) -> | logfmt | level="error" (field filter)
    sed -e 's/container=~\\".*distributor.*\\"/pod=~\\"loki.*-write.*\\"/g' \
        -e 's/container=~\\".*ingester.*\\"/pod=~\\"loki.*-write.*\\"/g' \
        -e 's/container=~\\".*querier.*\\"/pod=~\\"loki.*-read.*\\"/g' \
        -e 's/container=~\\".*backend.*\\"/pod=~\\"loki.*-backend.*\\"/g' \
        -e 's/|= \\"level=error\\"/| logfmt | level=\\"error\\"/g' \
        "${loki_dashboard}" > "${loki_dashboard}.tmp" \
      && mv "${loki_dashboard}.tmp" "${loki_dashboard}"
  fi
done

# Fix Node Exporter USE dashboards - remove != 0 from error queries
# The USE (Utilization, Saturation, Errors) methodology uses != 0 to filter errors,
# but this shows empty panels when there are no errors. Showing 0 is more informative.
echo "==> Fixing Node Exporter USE dashboard error queries..."
for node_dashboard in "${OUTPUT_DIR}"/node-*.json "${OUTPUT_DIR}"/nodes.json; do
  if [[ -f "${node_dashboard}" ]]; then
    # Remove != 0 from specific error metrics only:
    # - instance:node_network_receive_drop_excluding_lo:rate5m
    # - instance:node_network_transmit_drop_excluding_lo:rate5m
    # - instance:node_vmstat_pgmajfault:rate5m
    # Pattern: metric{labels} != 0" -> metric{labels}"
    sed -e 's/\(instance:node_network_receive_drop_excluding_lo:rate5m{[^}]*}\) != 0"/\1"/g' \
        -e 's/\(instance:node_network_transmit_drop_excluding_lo:rate5m{[^}]*}\) != 0"/\1"/g' \
        -e 's/\(instance:node_vmstat_pgmajfault:rate5m{[^}]*}\) != 0"/\1"/g' \
        "${node_dashboard}" > "${node_dashboard}.tmp" \
      && mv "${node_dashboard}.tmp" "${node_dashboard}"
  fi
done

# Function to determine folder based on dashboard filename
# Order matters: more specific patterns (prefix matches) must come before generic substring matches
get_folder() {
  local filename="$1"
  if [[ "${filename}" == loki-* ]]; then
    echo "Loki"
  elif [[ "${filename}" == alloy-* ]]; then
    echo "Alloy"
  elif [[ "${filename}" == *"grafana"* ]]; then
    echo "Grafana"
  elif [[ "${filename}" == node-* ]] || [[ "${filename}" == nodes ]]; then
    echo "Node Exporter"
  elif [[ "${filename}" == *"prometheus"* ]] || [[ "${filename}" == *"alertmanager"* ]]; then
    echo "Prometheus"
  elif [[ "${filename}" == mayastor-* ]] || [[ "${filename}" == zfslocalpv* ]] || [[ "${filename}" == npd-* ]]; then
    echo "OpenEBS"
  elif [[ "${filename}" == coredns* ]]; then
    echo "CoreDNS"
  elif [[ "${filename}" == cilium-* ]] || [[ "${filename}" == hubble-* ]]; then
    echo "Cilium"
  elif [[ "${filename}" == cert-manager* ]]; then
    echo "Cert Manager"
  else
    echo "Kubernetes"
  fi
}

# Function to convert folder name to manifest filename
folder_to_filename() {
  local folder="$1"
  echo "${folder}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-'
}

echo "==> Generating GrafanaDashboard CRs by folder..."

# Collect unique folders (avoiding associative arrays for bash 3.x compatibility)
folders=""
for json_file in "${OUTPUT_DIR}"/*.json; do
  filename=$(basename "${json_file}" .json)
  folder=$(get_folder "${filename}")
  # Add folder to list if not already present
  if ! echo "${folders}" | grep -qF "|${folder}|"; then
    folders="${folders}|${folder}|"
  fi
done

# Generate separate manifest for each folder
echo "${folders}" | tr '|' '\n' | while read -r folder; do
  [ -z "${folder}" ] && continue

  folder_file=$(folder_to_filename "${folder}")
  manifest_file="${DASHBOARD_DIR}/grafanadashboard-${folder_file}.yaml"

  echo "==> Generating ${manifest_file}..."

  cat > "${manifest_file}" << EOF
---
# Grafana Dashboards for ${folder}
# Auto-generated by: make build
# Source: https://github.com/prometheus-operator/kube-prometheus
# Do not edit manually - regenerate with 'make build'
EOF

  # Process dashboards for this folder
  for json_file in "${OUTPUT_DIR}"/*.json; do
    filename=$(basename "${json_file}" .json)
    json_folder=$(get_folder "${filename}")

    # Skip if not in this folder
    [ "${json_folder}" != "${folder}" ] && continue

    # Convert filename to valid k8s name (lowercase, replace _ with -)
    name=$(echo "${filename}" | tr '[:upper:]' '[:lower:]' | tr '_' '-')

    echo "  - ${name}"

    cat >> "${manifest_file}" << EOF

---
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: kp-${name}
  namespace: monitoring
spec:
  instanceSelector:
    matchLabels:
      dashboards: grafana
  allowCrossNamespaceImport: true
  folder: "${folder}"
  resyncPeriod: 24h
  json: |
$(sed 's/^/    /' "${json_file}")
EOF
  done

  echo "    Dashboard count: $(grep -c "^kind: GrafanaDashboard" "${manifest_file}")"
done

echo "==> Generated dashboard manifests in ${DASHBOARD_DIR}/"

# Build alerts/rules from jsonnet
echo ""
echo "==> Building PrometheusRules from jsonnet..."
rm -rf "${ALERTS_OUTPUT_DIR}"
mkdir -p "${ALERTS_OUTPUT_DIR}"
jsonnet -J vendor -m "${ALERTS_OUTPUT_DIR}" alerts.jsonnet

echo "==> Generating PrometheusRule CRs..."
rm -rf "${RULES_DIR}"
mkdir -p "${RULES_DIR}"

for json_file in "${ALERTS_OUTPUT_DIR}"/*.json; do
  filename=$(basename "${json_file}" .json)
  # Convert filename to valid k8s name (lowercase, replace _ with -)
  name=$(echo "${filename}" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
  output_file="${RULES_DIR}/prometheusrule-${name}.yaml"

  echo "  - ${name}"

  # Convert JSON to YAML PrometheusRule CR
  cat > "${output_file}" << EOF
---
# PrometheusRule from kube-prometheus jsonnet
# Auto-generated by: make build
# Source: https://github.com/prometheus-operator/kube-prometheus
# Do not edit manually - regenerate with 'make build'
EOF

  # Convert the JSON PrometheusRule to YAML and append
  jq -r '.' "${json_file}" | yq -P >> "${output_file}"

  # Fix namespace: all rules should be in monitoring namespace
  sed -i '' 's/namespace: default/namespace: monitoring/' "${output_file}"

  # Add prometheus.io/scrape-by label for Prometheus rule selector
  yq -i '.metadata.labels."prometheus.io/scrape-by" = "prometheus-cluster"' "${output_file}"
done

echo "==> Generated: ${RULES_DIR}/"
echo "==> Rule count: $(ls -1 "${RULES_DIR}"/*.yaml 2>/dev/null | wc -l | tr -d ' ')"

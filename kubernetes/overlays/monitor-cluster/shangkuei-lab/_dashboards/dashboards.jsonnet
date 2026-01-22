// Build Grafana dashboards from kube-prometheus and additional mixins
// Run: jsonnet -J vendor -m output dashboards.jsonnet
local kp = (import 'kube-prometheus/main.libsonnet');
local addMixin = (import 'kube-prometheus/lib/mixin.libsonnet');

// CoreDNS mixin for DNS monitoring
local coredns = addMixin({
  name: 'coredns',
  mixin: import 'coredns-mixin/mixin.libsonnet',
});

// OpenEBS mixin for storage monitoring (ZFS LocalPV, Mayastor)
local openebsMixin = (import 'openebs-mixin/mixin.libsonnet') {
  _config+:: {
    // Enable storage backends we use (LVM LocalPV disabled)
    casTypes: {
      lvmLocalPV: false,
      zfsLocalPV: true,
      mayastor: true,
    },
    // Disable NPD (Node Problem Detector) - not installed
    dashboards+: {
      npd: false,
    },
  },
};
local openebs = addMixin({
  name: 'openebs',
  mixin: openebsMixin,
});

// Loki mixin for log monitoring (configured for simple-scalable/SSD mode)
local lokiMixin = (import 'loki-mixin/mixin.libsonnet') {
  _config+:: {
    // Enable SSD mode for simple-scalable deployment
    ssd: {
      enabled: true,
      pod_prefix_matcher: 'loki.*',
    },
    // Use pod label for component differentiation (SSD mode uses same container name)
    // Default 'container' doesn't work because all pods have container='loki'
    per_component_label: 'pod',
    // Use 'node' label for joining node-exporter and kubelet/cadvisor metrics
    // Default 'instance' doesn't work because ports differ (9100 vs 10250)
    per_node_label: 'node',
    // Disable components we don't use
    blooms: { enabled: false },
    promtail: { enabled: false },
    thanos: { enabled: false },
    // Operational dashboard - only S3
    operational: {
      memcached: false,
      consul: false,
      bigTable: false,
      dynamo: false,
      gcs: false,
      s3: true,
      azureBlob: false,
      boltDB: false,
    },
  },
};
local loki = addMixin({
  name: 'loki',
  mixin: lokiMixin,
});

// Filter function to exclude non-Linux dashboards (Windows, AIX, Darwin/macOS) and proxy
// Also exclude:
// - loki-deletion: metrics removed in Loki 3.x (no upstream fix planned)
// - loki-mixin-recording-rules: requires ruler WAL remote-write (not configured)
// - prometheus-remote-write: remote write not configured
local isIncludedDashboard(filename) =
  std.length(std.findSubstr('windows', filename)) == 0 &&
  !std.endsWith(filename, '-aix.json') &&
  !std.endsWith(filename, '-darwin.json') &&
  filename != 'proxy.json' &&
  filename != 'loki-deletion.json' &&
  filename != 'loki-mixin-recording-rules.json' &&
  filename != 'prometheus-remote-write.json';

// Unhide cluster variable in dashboard templating
// kube-prometheus defaults to hide=2 (completely hidden) for single-cluster setups
// We need hide=0 (visible) to select between multiple clusters (e.g., shangkuei-lab, shangkuei-unraid)
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

// Fix loki-mixin metric name bug: loki_write_memory_streams -> loki_ingester_memory_streams
// See: https://github.com/grafana/loki/issues/13479 (similar pattern)
local fixLokiMetrics(dashboard) =
  std.parseJson(std.strReplace(std.manifestJsonEx(dashboard, ''), 'loki_write_memory_streams', 'loki_ingester_memory_streams'));

// Fix network metrics that incorrectly filter by container label
// container_network_* metrics are pod-level (no container label exists)
// Join with kube_pod_container_info to filter pods containing the selected container
local fixNetworkMetrics(dashboard) =
  local json = std.manifestJsonEx(dashboard, '');
  // Replace TX query: join with kube_pod_container_info to filter by container
  // Use 'sum by (namespace, pod)' so the join on(namespace, pod) works
  local fixedTx = std.strReplace(
    json,
    'sum by (pod)(rate(container_network_transmit_bytes_total{cluster=\\"$cluster\\", namespace=\\"$namespace\\", container=~\\"$container\\"}[$__rate_interval]))',
    'sum by (namespace, pod)(rate(container_network_transmit_bytes_total{cluster=\\"$cluster\\", namespace=\\"$namespace\\"}[$__rate_interval])) * on(namespace, pod) group_left() max by(namespace, pod) (kube_pod_container_info{cluster=\\"$cluster\\", namespace=\\"$namespace\\", container=~\\"$container\\"})'
  );
  // Replace RX query: same join pattern
  local fixedRx = std.strReplace(
    fixedTx,
    'sum by (pod)(rate(container_network_receive_bytes_total{cluster=\\"$cluster\\", namespace=\\"$namespace\\"}[$__rate_interval]))',
    'sum by (namespace, pod)(rate(container_network_receive_bytes_total{cluster=\\"$cluster\\", namespace=\\"$namespace\\"}[$__rate_interval])) * on(namespace, pod) group_left() max by(namespace, pod) (kube_pod_container_info{cluster=\\"$cluster\\", namespace=\\"$namespace\\", container=~\\"$container\\"})'
  );
  std.parseJson(fixedRx);

// Remove panels that use promtail-specific metrics (we use Alloy instead)
// The "bad words" panel requires promtail_custom_bad_words_total metric
local removePromtailPanels(dashboard) =
  dashboard {
    panels: [
      panel
      for panel in dashboard.panels
      if !std.objectHas(panel, 'targets') ||
         !std.any([
           std.objectHas(target, 'expr') && std.length(std.findSubstr('promtail_custom', target.expr)) > 0
           for target in panel.targets
         ])
    ],
  };

// Remove panels that use deprecated CoreDNS forward metrics (removed in CoreDNS 1.10+)
// coredns_forward_requests_total was removed; use coredns_dns_requests_total instead
local removeDeprecatedCorednsPanels(dashboard) =
  dashboard {
    rows: [
      row {
        panels: [
          panel
          for panel in row.panels
          if !std.objectHas(panel, 'targets') ||
             !std.any([
               std.objectHas(target, 'expr') && std.length(std.findSubstr('coredns_forward_requests_total', target.expr)) > 0
               for target in panel.targets
             ])
        ],
      }
      for row in dashboard.rows
    ],
  };

// Extract dashboard definitions from kube-prometheus
// Each item is a ConfigMap with data containing {filename.json: jsonContent}
// Parse JSON strings and unhide cluster variable for multi-cluster support
local kpDashboards = {
  [std.objectFields(item.data)[0]]: unhideClusterVariable(std.parseJson(item.data[std.objectFields(item.data)[0]]))
  for item in kp.grafana.dashboardDefinitions.items
  if isIncludedDashboard(std.objectFields(item.data)[0])
};

// Extract dashboards from mixins (apply same filter and fix metric names)
// Apply removeDeprecatedCorednsPanels to coredns dashboard
// Apply unhideClusterVariable to all dashboards for multi-cluster support
local corednsDashboards = {
  [k]: unhideClusterVariable(if k == 'coredns.json' then removeDeprecatedCorednsPanels(coredns.grafanaDashboards[k]) else coredns.grafanaDashboards[k])
  for k in std.objectFields(coredns.grafanaDashboards)
};

// Patch loki-logs dashboard to filter container variable to loki containers only
local patchLokiLogsContainerFilter(dashboard) =
  dashboard {
    templating+: {
      list: [
        if item.name == 'container' then
          item { regex: 'loki.*', refresh: 1 }
        else
          item
        for item in dashboard.templating.list
      ],
    },
  };

// Remove Disk Space Utilization panel from loki-resources-overview (not relevant for SSD mode)
// Dashboard uses rows structure, so we need to filter panels within rows
local removeDiskSpacePanel(dashboard) =
  dashboard {
    rows: [
      row {
        panels: [
          panel
          for panel in row.panels
          if !std.objectHas(panel, 'title') || panel.title != 'Disk Space Utilization'
        ],
      }
      for row in dashboard.rows
    ],
  };

// Apply fixes to loki dashboards:
// - fixLokiMetrics: correct metric name bugs
// - fixNetworkMetrics: remove invalid container filter from network metrics
// - removePromtailPanels: remove panels for promtail metrics (we use Alloy)
// - patchLokiLogsContainerFilter: filter container dropdown to loki containers
// - removeDiskSpacePanel: remove disk panel from resources overview
local processLokiDashboard(name, dashboard) =
  local fixed = fixLokiMetrics(dashboard);
  if name == 'loki-logs.json' then
    patchLokiLogsContainerFilter(removePromtailPanels(fixNetworkMetrics(fixed)))
  else if name == 'loki-resources-overview.json' then
    removeDiskSpacePanel(fixed)
  else
    fixed;

local lokiDashboards = {
  [k]: unhideClusterVariable(processLokiDashboard(k, loki.grafanaDashboards[k]))
  for k in std.objectFields(loki.grafanaDashboards)
  if isIncludedDashboard(k)
};

// Extract dashboards from OpenEBS mixin
local openebsDashboards = {
  [k]: unhideClusterVariable(openebs.grafanaDashboards[k])
  for k in std.objectFields(openebs.grafanaDashboards)
};

// Alloy mixin for telemetry collector monitoring
// Current setup: DaemonSet with clustering for metrics + logs collection
// - Metrics: ServiceMonitor/PodMonitor discovery via prometheus.operator components
// - Logs: Pod log collection via loki.source.kubernetes
// - Include: cluster-* (clustering enabled), prometheus-remote-write (metrics collection),
//            controller, resources, logs
// - Exclude: opentelemetry (requires OTEL),
//            loki (uses loki.source.file metrics, we use loki.source.kubernetes)
local alloyMixin = (import 'alloy-mixin/mixin.libsonnet');
local isRelevantAlloyDashboard(filename) =
  // Exclude dashboards that require features we don't use
  filename != 'alloy-opentelemetry.json' &&
  // alloy-loki uses loki_source_file_* metrics which require loki.source.file
  // We use loki.source.kubernetes which exposes different metrics
  filename != 'alloy-loki.json';

// Patch alloy-logs dashboard to filter by container=alloy
// This ensures the dashboard only shows Alloy's own logs (which have level label)
local patchAlloyLogsDashboard(dashboard) =
  local json = std.manifestJsonEx(dashboard, '');
  // Patch job variable query to filter by container=alloy
  local patched1 = std.strReplace(
    json,
    '{cluster=~\\"$cluster\\", namespace=~\\"$namespace\\"}, job)',
    '{cluster=~\\"$cluster\\", namespace=~\\"$namespace\\", container=\\"alloy\\"}, job)'
  );
  // Add container="alloy" filter to Loki queries (panel queries)
  local patched2 = std.strReplace(
    patched1,
    '{cluster=~\\"$cluster\\", namespace=~\\"$namespace\\", job=~\\"$job\\"',
    '{cluster=~\\"$cluster\\", namespace=~\\"$namespace\\", job=~\\"$job\\", container=\\"alloy\\"'
  );
  // Also patch the level variable query
  local patched3 = std.strReplace(
    patched2,
    '{cluster=~\\"$cluster\\", namespace=~\\"$namespace\\", job=~\\"$job\\", instance=~\\"$instance\\"}, level)',
    '{cluster=~\\"$cluster\\", namespace=~\\"$namespace\\", job=~\\"$job\\", instance=~\\"$instance\\", container=\\"alloy\\"}, level)'
  );
  std.parseJson(patched3);

local alloyDashboards = {
  [k]: unhideClusterVariable(if k == 'alloy-logs.json' then patchAlloyLogsDashboard(alloyMixin.grafanaDashboards[k]) else alloyMixin.grafanaDashboards[k])
  for k in std.objectFields(alloyMixin.grafanaDashboards)
  if isRelevantAlloyDashboard(k)
};

// Cilium mixin for CNI monitoring
// Provides dashboards for Cilium agent, operator, Hubble, and networking components
// Filter out enterprise-only dashboards we don't have deployed:
// - hubble-timescape: Requires Hubble Enterprise (Timescape feature)
// - cilium-external-fqdn-proxy: Requires Enterprise external FQDN proxy
local ciliumMixin = (import 'cilium-enterprise-mixin/mixin.libsonnet');
local isRelevantCiliumDashboard(filename) =
  filename != 'hubble-timescape.json' &&
  filename != 'cilium-external-fqdn-proxy.json';

local ciliumDashboards = {
  [k]: unhideClusterVariable(ciliumMixin.grafanaDashboards[k])
  for k in std.objectFields(ciliumMixin.grafanaDashboards)
  if isRelevantCiliumDashboard(k)
};

// cert-manager mixin for certificate monitoring
// Provides dashboards for certificate expiry, issuance, and overall health
local certManagerMixin = (import 'cert-manager-mixin/mixin.libsonnet');
local certManagerDashboards = {
  [k]: unhideClusterVariable(certManagerMixin.grafanaDashboards[k])
  for k in std.objectFields(certManagerMixin.grafanaDashboards)
};

// Combine all dashboards
kpDashboards + corednsDashboards + lokiDashboards + openebsDashboards + alloyDashboards + ciliumDashboards + certManagerDashboards

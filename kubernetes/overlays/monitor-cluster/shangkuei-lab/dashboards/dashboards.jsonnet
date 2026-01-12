// Build Grafana dashboards from kube-prometheus and additional mixins
// Run: jsonnet -J vendor -m output dashboards.jsonnet
local kp = (import 'kube-prometheus/main.libsonnet');
local addMixin = (import 'kube-prometheus/lib/mixin.libsonnet');

// CoreDNS mixin for DNS monitoring
local coredns = addMixin({
  name: 'coredns',
  mixin: import 'coredns-mixin/mixin.libsonnet',
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
local kpDashboards = {
  [std.objectFields(item.data)[0]]: item.data[std.objectFields(item.data)[0]]
  for item in kp.grafana.dashboardDefinitions.items
  if isIncludedDashboard(std.objectFields(item.data)[0])
};

// Extract dashboards from mixins (apply same filter and fix metric names)
// Apply removeDeprecatedCorednsPanels to coredns dashboard
local corednsDashboards = {
  [k]: if k == 'coredns.json' then removeDeprecatedCorednsPanels(coredns.grafanaDashboards[k]) else coredns.grafanaDashboards[k]
  for k in std.objectFields(coredns.grafanaDashboards)
};

// Apply fixes to loki dashboards:
// - fixLokiMetrics: correct metric name bugs
// - fixNetworkMetrics: remove invalid container filter from network metrics
// - removePromtailPanels: remove panels for promtail metrics (we use Alloy)
local processLokiDashboard(name, dashboard) =
  local fixed = fixLokiMetrics(dashboard);
  if name == 'loki-logs.json' then
    removePromtailPanels(fixNetworkMetrics(fixed))
  else
    fixed;

local lokiDashboards = {
  [k]: processLokiDashboard(k, loki.grafanaDashboards[k])
  for k in std.objectFields(loki.grafanaDashboards)
  if isIncludedDashboard(k)
};

// Combine all dashboards
kpDashboards + corednsDashboards + lokiDashboards

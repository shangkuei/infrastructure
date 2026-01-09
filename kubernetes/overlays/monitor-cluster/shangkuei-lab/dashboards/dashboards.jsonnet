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
local isIncludedDashboard(filename) =
  std.length(std.findSubstr('windows', filename)) == 0 &&
  !std.endsWith(filename, '-aix.json') &&
  !std.endsWith(filename, '-darwin.json') &&
  filename != 'proxy.json';

// Extract dashboard definitions from kube-prometheus
// Each item is a ConfigMap with data containing {filename.json: jsonContent}
local kpDashboards = {
  [std.objectFields(item.data)[0]]: item.data[std.objectFields(item.data)[0]]
  for item in kp.grafana.dashboardDefinitions.items
  if isIncludedDashboard(std.objectFields(item.data)[0])
};

// Extract dashboards from mixins
local corednsDashboards = coredns.grafanaDashboards;
local lokiDashboards = loki.grafanaDashboards;

// Combine all dashboards
kpDashboards + corednsDashboards + lokiDashboards

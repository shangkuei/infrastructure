// Build PrometheusRule alerts from kube-prometheus and additional mixins
// Run: jsonnet -J vendor -m output-alerts alerts.jsonnet
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
    alertRules+: {
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

// Helper to extract prometheusRule if it exists in a component
// Note: Key must have .json suffix for jsonnet multi-output mode
local getRule(component, name) =
  if std.objectHas(component, 'prometheusRule') then
    { [name + '.json']: component.prometheusRule }
  else
    {};

// Extract PrometheusRules from all kube-prometheus components
local kpRules =
  getRule(kp.alertmanager, 'alertmanager') +
  getRule(kp.kubePrometheus, 'kube-prometheus') +
  getRule(kp.kubeStateMetrics, 'kube-state-metrics') +
  getRule(kp.kubernetesControlPlane, 'kubernetes-control-plane') +
  getRule(kp.nodeExporter, 'node-exporter') +
  getRule(kp.prometheus, 'prometheus') +
  getRule(kp.prometheusOperator, 'prometheus-operator');

// Extract rules from mixins - wrap single PrometheusRule objects with keyed names
// The addMixin function returns prometheusRules as a single PrometheusRule object
local corednsRules = { 'coredns.json': coredns.prometheusRules };
local lokiRules = { 'loki.json': loki.prometheusRules };
local openebsRules = { 'openebs.json': openebs.prometheusRules };

// Alloy mixin for telemetry collector alerts
// Note: alloy-mixin.prometheusAlerts is just groups, not a full PrometheusRule CR
// We need to wrap it in the proper structure
local alloyMixin = (import 'alloy-mixin/mixin.libsonnet');
local alloyRules = {
  'alloy.json': {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      name: 'alloy-rules',
      namespace: 'default',
      labels: {
        'app.kubernetes.io/name': 'alloy',
        'app.kubernetes.io/part-of': 'alloy',
      },
    },
    spec: alloyMixin.prometheusAlerts,
  },
};

// Combine all rules
kpRules + corednsRules + lokiRules + openebsRules + alloyRules

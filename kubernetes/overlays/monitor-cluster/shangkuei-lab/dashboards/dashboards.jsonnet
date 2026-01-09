// Build Grafana dashboards from kube-prometheus mixin
// Run: jsonnet -J vendor -m output dashboards.jsonnet
local kp = (import 'kube-prometheus/main.libsonnet');

// Extract only the dashboard definitions
// Each item is a ConfigMap with data containing {filename.json: jsonContent}
// Output each dashboard as a separate JSON file
{
  [std.objectFields(item.data)[0]]: item.data[std.objectFields(item.data)[0]]
  for item in kp.grafana.dashboardDefinitions.items
}

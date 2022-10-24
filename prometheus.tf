resource "helm_release" "prometheus" {
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  name       = "prometheus"
  version    = "15.16.1"
  namespace  = kubernetes_namespace_v1.prometheus.metadata[0].name

  values = [
    yamlencode({
      nodeExporter     = { enabled = false }
      kubeStateMetrics = { enabled = false }
      pushgateway      = { enabled = false }
      alertmanager     = { enabled = false }
      serverFiles      = { "prometheus.yml" = { scrape_configs = [] } }
      server           = {
        extraFlags = ["web.enable-remote-write-receiver"]
        ingress    = { enabled = true, hosts = ["prometheus.lvh.me"], ingressClassName = "nginx" }
      }
    })
  ]

  depends_on = [helm_release.ingress_nginx]
}

resource "kubernetes_namespace_v1" "prometheus" {
  metadata { name = "prometheus" }
}

resource "helm_release" "default_opentelemetry_collector" {
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  name       = "default"
  version    = "0.36.3"
  namespace  = kubernetes_namespace_v1.opentelemetry.metadata[0].name

  values = [
    yamlencode({
      mode    = "deployment"
      config  = yamldecode(file("${path.root}/opentelemetry-collector.yaml"))
      extraEnvs = [
        {
          name  = "JAEGER_OTLP_ENDPOINT",
          value = "jaeger-collector.${kubernetes_namespace_v1.jaeger.metadata[0].name}.svc.cluster.local:4317"
        },
        {
          name  = "PROMETHEUS_PUSHGATEWAY_ENDPOINT",
          value = "prometheus-server.${kubernetes_namespace_v1.prometheus.metadata[0].name}.svc.cluster.local"
        },
      ]
    })
  ]

  depends_on = [
    helm_release.jaeger,
    helm_release.prometheus,
    helm_release.ingress_nginx,
  ]
}

resource "kubernetes_namespace_v1" "opentelemetry" {
  metadata { name = "otel" }
}

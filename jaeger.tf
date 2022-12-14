resource "helm_release" "jaeger" {
  repository = "https://jaegertracing.github.io/helm-charts"
  chart      = "jaeger"
  name       = "jaeger"
  version    = "0.62.1"
  namespace  = kubernetes_namespace_v1.jaeger.metadata[0].name

  values = [
    yamlencode({
      allInOne = {
        enabled  = true
        tag      = "1.38.1"
        ingress  = { enabled = false }
        extraEnv = [
          {
            name  = "METRICS_STORAGE_TYPE",
            value = "prometheus"
          },
          {
            name  = "PROMETHEUS_SERVER_URL",
            value = "http://prometheus-server.${kubernetes_namespace_v1.prometheus.metadata[0].name}.svc.cluster.local"
          }
        ]
      }

      collector = { enabled = false }
      agent     = { enabled = false }
      query     = { enabled = false }

      provisionDataStore = {
        cassandra     = false
        elasticsearch = false
        kafka         = false
      }
    })
  ]

  depends_on = [
    helm_release.prometheus,
    helm_release.ingress_nginx,
  ]
}

resource "kubernetes_ingress_v1" "jaeger" {
  metadata {
    name      = "jaeger"
    namespace = kubernetes_namespace_v1.jaeger.metadata[0].name
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "jaeger.lvh.me"
      http {
        path {
          path = "/"
          backend {
            service {
              name = "jaeger-query"
              port {
                name = "http-query"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.jaeger]
}

resource "kubernetes_namespace_v1" "jaeger" {
  metadata { name = "jaeger" }
}

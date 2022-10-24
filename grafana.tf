resource "helm_release" "grafana" {
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  name       = "grafana"
  version    = "6.43.0"
  namespace  = kubernetes_namespace_v1.grafana.metadata[0].name

  values = [
    yamlencode({
      ingress       = { enabled = true, hosts = ["grafana.lvh.me"], ingressClassName = "nginx" }
      "grafana.ini" = {
        auth             = { disable_login_form = true }
        "auth.anonymous" = { enabled = true, org_name = "Main Org.", org_role = "Editor" }
      }
      datasources = {
        "datasources.yaml" = {
          apiVersion  = 1
          datasources = [
            {
              name      = "Prometheus"
              type      = "prometheus"
              url       = "http://prometheus-server.${kubernetes_namespace_v1.prometheus.metadata[0].name}.svc.cluster.local"
              access    = "proxy"
              isDefault = true
            }
          ]
        }
      }
      dashboardProviders = {
        "dashboardproviders.yaml" = {
          apiVersion = 1
          providers  = [
            {
              disableDeletion = false
              editable        = true
              folder          = ""
              name            = "default"
              options         = { path = "/var/lib/grafana/dashboards/default" }
              orgId           = 1
              type            = "file"
            },
          ]
        }
      }
    })
  ]

  depends_on = [
    helm_release.prometheus,
    helm_release.ingress_nginx,
  ]
}

resource "kubernetes_namespace_v1" "grafana" {
  metadata { name = "grafana" }
}
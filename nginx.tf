resource "helm_release" "ingress_nginx" {
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  name       = "nginx"
  version    = "4.3.0"
  namespace  = kubernetes_namespace_v1.nginx.metadata[0].name

  values = [
    yamlencode({
      controller = {
        extraArgs      = { publish-status-address = "127.0.0.1" }
        hostPort       = { enabled = true, ports = { http = 80, https = 443 } }
        nodeSelector   = { "ingress-ready" = "true", "kubernetes.io/os" = "linux" }
        publishService = { enabled = false }
        service        = { type = "NodePort" }
      }
    })
  ]
}

resource "kubernetes_namespace_v1" "nginx" {
  metadata { name = "nginx" }
}
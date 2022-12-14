locals {
  kind = { version = "v1.24.6" }
}

resource "kind_cluster" "otelplay" {
  name = "otelplay"

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role  = "control-plane"
      image = "kindest/node:${local.kind.version}"
    }

    node {
      role  = "worker"
      image = "kindest/node:${local.kind.version}"

      dynamic "extra_mounts" {
        for_each = toset(var.docker_volume != null ? [var.docker_volume] : [])
        content {
          container_path = "/var/lib/containerd"
          host_path      = "/var/lib/docker/volumes/${var.docker_volume}/_data"
        }
      }

      kubeadm_config_patches = [
        yamlencode({
          kind             = "JoinConfiguration"
          nodeRegistration = { kubeletExtraArgs = { "node-labels" = "ingress-ready=true" } }
        })
      ]

      extra_port_mappings {
        container_port = 80
        host_port      = 80
        protocol       = "TCP"
      }
    }
  }
}

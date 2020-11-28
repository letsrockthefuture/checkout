locals {
  namespace      = var.namespace
  app            = var.app
  version        = var.app_version
  docker_image   = var.docker_image
  container_port = var.container_port
}

resource "kubernetes_namespace" "checkout_namespace" {
  metadata {
    annotations = {
      name            = local.namespace
      istio-injection = "enabled"
    }

    labels = {
      app = local.app
    }

    name = local.namespace
  }
}

resource "kubernetes_deployment" "checkout_deployment" {
  metadata {
    name      = local.app
    namespace = local.namespace
    labels = {
      app     = local.app
      version = local.version
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = local.app
      }
    }
    template {
      metadata {
        labels = {
          app     = local.app
          version = local.version
        }
      }
      spec {
        container {
          image = local.docker_image
          name  = local.app
          args  = ["-listen=:${local.container_port}", "-text=${local.app}"]

          port {
            container_port = local.container_port
          }

          resources {
            limits {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
          liveness_probe {
            http_get {
              path = "/"
              port = local.container_port
            }

            initial_delay_seconds = 3
            period_seconds        = 3
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.checkout_namespace
  ]
}

resource "kubernetes_service" "checkout_service" {
  metadata {
    name      = local.app
    namespace = local.namespace

    labels = {
      app = local.app
    }
  }

  spec {
    selector = {
      app = kubernetes_deployment.checkout_deployment.metadata.0.labels.app
    }

    type = "LoadBalancer"

    port {
      port = local.container_port
    }
  }

  depends_on = [
    kubernetes_namespace.checkout_namespace,
    kubernetes_deployment.checkout_deployment
  ]
}

resource "kubernetes_manifest" "checkout_gateway" {
  provider = kubernetes-alpha

  manifest = {
    "apiVersion" = "networking.istio.io/v1alpha3"
    "kind"       = "Gateway"
    "metadata" = {
      "name"      = "${local.app}-gateway"
      "namespace" = local.namespace
    }
    "spec" = {
      "selector" = {
        "istio" = "ingressgateway"
      }
      "servers" = [
        {
          "hosts" = [
            "*"
          ]
          "port" = {
            "name"     = "http"
            "number"   = local.container_port
            "protocol" = "HTTP"
          }
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "checkout_virtual_service" {
  provider = kubernetes-alpha

  manifest = {
    "apiVersion" = "networking.istio.io/v1alpha3"
    "kind"       = "VirtualService"
    "metadata" = {
      "name" = local.app
    }
    "spec" = {
      "gateways" = [
        "${local.app}-gateway",
      ]
      "hosts" = [
        "*"
      ]
      "http" = [
        {
          "route" = [
            {
              "destination" = {
                "host"   = local.app
                "subset" = local.version
              }
              "weight" = 75
            },
            {
              "destination" = {
                "host"   = local.app
                "subset" = "v2"
              }
              "weight" = 25
            }
          ]
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "checkout_destination_rule" {
  provider = kubernetes-alpha

  manifest = {
    "apiVersion" = "networking.istio.io/v1alpha3"
    "kind"       = "DestinationRule"
    "metadata" = {
      "name"      = local.app
      "namespace" = local.namespace
    }
    "spec" = {
      "host" = local.app
      "subsets" = [
        {
          "name" = "monolith"
          "labels" = {
            "version" = "v1"
          }
        },
        {
          "name" = local.app
          "labels" = {
            "version" = local.version
          }
        }
      ]
    }
  }
}

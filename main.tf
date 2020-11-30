locals {
  app                        = var.app
  namespace                  = var.namespace
  version                    = var.app_version
  replicas                   = var.replicas
  docker_image               = var.docker_image
  container_port             = var.container_port
  weight_to_checkout_service = var.weight_to_checkout_service
  monolith_service           = var.monolith_service
  weight_to_monolith_service = var.weight_to_monolith_service
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
    replicas = local.replicas
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
          args  = ["-listen=:${local.container_port}", "-text=Service: ${local.app}.${local.app}.svc.cluster.local"]

          port {
            container_port = local.container_port
          }

          resources {
            requests {
              cpu    = "25m"
              memory = "64Mi"
            }
            limits {
              cpu    = "50m"
              memory = "128Mi"
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
        node_selector = {
          "app" = local.app
        }
      }
    }
  }
}

resource "kubernetes_service" "checkout_private_service" {
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

    type = "ClusterIP"

    port {
      port = local.container_port
    }
  }

  depends_on = [
    kubernetes_deployment.checkout_deployment
  ]
}

resource "kubernetes_service" "checkout_public_service" {
  metadata {
    name      = "${local.app}-public"
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

  depends_on = [
    kubernetes_deployment.checkout_deployment,
    kubernetes_service.checkout_private_service,
    kubernetes_service.checkout_public_service
  ]
}

resource "kubernetes_manifest" "checkout_virtual_service" {
  provider = kubernetes-alpha

  manifest = {
    "apiVersion" = "networking.istio.io/v1alpha3"
    "kind"       = "VirtualService"
    "metadata" = {
      "name"      = local.app
      "namespace" = local.namespace
    }
    "spec" = {
      "gateways" = [
        "${local.app}-gateway",
      ]
      "hosts" = [
        "*",
      ]
      "http" = [
        {
          "match" = [
            {
              "uri" = {
                "exact" = "/${local.app}"
              }
            },
          ]
          "route" = [
            {
              "destination" = {
                "host" = local.app
              }
              "weight" = local.weight_to_checkout_service
            },
            {
              "destination" = {
                "host" = local.monolith_service
              }
              "weight" = local.weight_to_monolith_service
            }
          ]
        },
      ]
    }
  }

  depends_on = [
    kubernetes_deployment.checkout_deployment,
    kubernetes_service.checkout_private_service,
    kubernetes_service.checkout_public_service,
    kubernetes_manifest.checkout_gateway
  ]
}

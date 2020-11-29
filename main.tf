locals {
  namespace      = var.namespace
  app            = var.app
  version        = var.app_version
  docker_image   = var.docker_image
  container_port = var.container_port
}

/* resource "kubernetes_namespace" "checkout_namespace" {
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
} */

resource "kubernetes_service_account" "checkout_service_account" {
  metadata {
    name      = local.app
    namespace = local.namespace
    labels = {
      app = local.app
    }
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
        service_account_name = local.app
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
        "${local.app}-gateway"
      ]
      "hosts" = [
        "*"
      ]
      "http" = [
        {
          "match" = [
            {
              "uri" = {
                "exact" = "/checkout"
              }
            }
          ]
          "route" = [
            {
              "destination" = {
                "host" = local.app
                "port" = {
                  "number" = local.container_port
                }
              }
            }
          ]
        }
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
          "name" = "v1"
          "labels" = {
            "version" = "v2"
          }
        },
        {
          "name" = local.version
          "labels" = {
            "version" = local.version
          }
        }
      ]
    }
  }

  depends_on = [
    kubernetes_deployment.checkout_deployment,
    kubernetes_service.checkout_private_service,
    kubernetes_service.checkout_public_service,
    kubernetes_manifest.checkout_gateway,
    kubernetes_manifest.checkout_virtual_service
  ]
}

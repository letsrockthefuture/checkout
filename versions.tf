terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

provider "kubernetes" {}

provider "kubernetes-alpha" {
  config_path          = "~/.kube/config"
  server_side_planning = true
}

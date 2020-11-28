terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

provider "kubernetes" {}

provider "kubernetes-alpha" {
  server_side_planning = true
}

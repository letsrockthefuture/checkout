variable "cluster_name" {
  type    = string
  default = "hash-challenge-kubernetes-engine"
}

variable "namespace" {
  type    = string
  default = "checkout"
}

variable "app" {
  type    = string
  default = "checkout"
}

variable "app_version" {
  type    = string
  default = "v1"
}

variable "zone" {
  type    = string
  default = "us-east1-b"
}

variable "docker_image" {
  type        = string
  description = "Name of the Docker image to deploy."
  default     = "hashicorp/http-echo:latest"
}

variable "container_port" {
  type    = string
  default = "35251"
}

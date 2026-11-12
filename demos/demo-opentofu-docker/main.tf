# Démo J4 — Bloc 5.2 : un Nginx décrit en code (provider kreuzwerker/docker).
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.6"
    }
  }
}

provider "docker" {}

variable "port" {
  description = "Port publié sur le poste."
  type        = number
  default     = 8091
}

variable "message" {
  description = "Texte de la page d'accueil."
  type        = string
  default     = "Déployé par OpenTofu"
}

resource "docker_image" "nginx" {
  name         = "docker.io/library/nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "web" {
  name  = "demo-tofu-web"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.port
  }

  upload {
    file    = "/usr/share/nginx/html/index.html"
    content = "<h1>${var.message}</h1>\n"
  }
}

output "url" {
  value = "http://localhost:${var.port}"
}

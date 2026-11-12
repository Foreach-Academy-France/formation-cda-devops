# Exercice 4.1 : point de départ. Complétez les TODO, puis :
#   tofu init && tofu fmt && tofu validate && tofu plan && tofu apply
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.6"
    }
  }
}

# Lit DOCKER_HOST s'il est défini, sinon /var/run/docker.sock
provider "docker" {}

# TODO 1 : trois variables
#   - nom     (string, défaut "exercice-nginx")
#   - port    (number, défaut 8090, avec une validation : 1024 à 65535)
#   - message (string, texte de la page d'accueil)

# TODO 2 : une ressource docker_image pour docker.io/library/nginx:1.27-alpine
#          (keep_locally = true : destroy ne supprime pas l'image du poste)

# TODO 3 : une ressource docker_container qui utilise l'image ci-dessus,
#          publie le port 80 du conteneur sur var.port, et dépose une page
#          /usr/share/nginx/html/index.html contenant var.message (bloc « upload »)

# TODO 4 : un output « url » (http://localhost:<port>)

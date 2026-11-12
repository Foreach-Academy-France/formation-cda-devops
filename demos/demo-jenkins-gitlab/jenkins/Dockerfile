# =============================================================================
# Jenkins LTS pour la démo du Jour 2 (Bloc 3.3) — NE PAS EXPOSER sur un réseau.
#   - plugins installés au build (liste dans plugins.txt) ;
#   - configuration « as code » (casc.yaml) : admin, jobs de démo, pas d'assistant ;
#   - client Docker : les pipelines lancent leurs étapes dans des conteneurs
#     node:XX-alpine via le daemon Docker du poste (socket monté par compose.yaml).
# =============================================================================
FROM docker.io/jenkins/jenkins:2.580.1-lts-jdk21

# Uniquement le binaire client : le daemon est celui du poste.
COPY --from=docker.io/library/docker:29.9.2-cli /usr/local/bin/docker /usr/local/bin/docker.real
# Petite enveloppe pour Podman (voir docker-wrapper.sh) ; transparente avec Docker.
COPY --chmod=755 docker-wrapper.sh /usr/local/bin/docker

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Configuration as Code : lue au démarrage
COPY casc.yaml /usr/share/jenkins/casc.yaml
ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/casc.yaml \
    JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=true"
# ALLOW_LOCAL_CHECKOUT : autorise un dépôt Git local (file://), utilisé par la démo
# hors ligne. À ne jamais activer sur un vrai Jenkins.

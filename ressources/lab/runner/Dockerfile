# =============================================================================
# Runner GitHub Actions self-hosted du lab TaskFlow (CDA)
#
# Base : myoung34/github-runner (Ubuntu 24.04 + agent actions/runner, qui
# s'enregistre seul au démarrage avec REPO_URL + RUNNER_TOKEN). Elle fournit déjà
# docker CLI, le plugin « docker compose », git, curl et jq.
# On ajoute OpenTofu (Jour 4 : le staging décrit en IaC) en version ÉPINGLÉE,
# avec vérification de l'empreinte SHA-256 du paquet téléchargé.
# Le build se termine par un contrôle de tous les outils : si une future version
# de l'image de base en perdait un, le build échoue ici, pas pendant un déploiement.
# =============================================================================
FROM docker.io/myoung34/github-runner:ubuntu-noble

ARG TOFU_VERSION=1.13.9

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl jq git \
    && rm -rf /var/lib/apt/lists/*

# Architecture du poste (amd64 sur PC, arm64 sur Mac Apple Silicon)
RUN arch="$(dpkg --print-architecture)" \
    && deb="tofu_${TOFU_VERSION}_${arch}.deb" \
    && base="https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}" \
    && cd /tmp \
    && curl -fsSLO "${base}/${deb}" \
    && curl -fsSLO "${base}/tofu_${TOFU_VERSION}_SHA256SUMS" \
    && grep " ${deb}\$" "tofu_${TOFU_VERSION}_SHA256SUMS" | sha256sum -c - \
    && dpkg -i "${deb}" \
    && rm -f "/tmp/${deb}" "/tmp/tofu_${TOFU_VERSION}_SHA256SUMS"

RUN docker --version \
    && docker compose version \
    && git --version \
    && curl --version | head -n1 \
    && jq --version \
    && tofu version

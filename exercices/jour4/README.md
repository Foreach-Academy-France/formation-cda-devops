# Jour 4 — Exercices : Infrastructure as Code et observabilité

Exercices courts, à faire seul (ou en binôme pour la discussion), entre les blocs de théorie du matin. Le 4.5 sert aussi
pendant l'étape 4 du TP fil rouge (partie C).

| # | Exercice | Durée | Bloc | Fichiers fournis |
|---|---|---|---|---|
| 4.1 | [Un Nginx en code avec OpenTofu](01-opentofu-nginx.md) | 20 min | 5.2 | [`opentofu-nginx/main.tf`](opentofu-nginx/main.tf) (squelette) |
| 4.2 | [Provoquer et corriger une dérive](02-opentofu-drift.md) | 15 min | 5.2 | le dossier de l'exercice 4.1 |
| 4.3 | [Lire un plan avant de l'appliquer](03-lire-un-plan.md) | 10 min | 5.2 | [`plans/plan-pr-57.txt`](plans/plan-pr-57.txt) |
| 4.4 | [Un playbook Ansible idempotent](04-ansible-dossier-deploiement.md) | 30 min | 5.3 | [`ansible-depart/`](ansible-depart/) (inventaire, playbook à compléter, modèle) |
| 4.5 | [Analyser des logs JSON avec `jq`](05-logs-jq.md) | 20 min | 6.1 | [`logs/api.log`](logs/api.log) (1 815 lignes) |

**Corrigé :** [`solutions.md`](solutions.md), à ouvrir après avoir cherché.

## Avant de commencer

- `tofu version` (≥ 1.6), `ansible --version` (≥ 2.15), `jq --version` : voir `ressources/setup-poste.md`.
- Le Nginx des exercices 4.1 et 4.2 est publié sur le port **8090** (hors des ports du fil rouge : 3000, 3001, 8080, 8081,
  80/443, 9090, 9093). Variable `port` si 8090 est déjà pris.
- Podman au lieu de Docker : `export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock` (socket activé par
  `systemctl --user enable --now podman.socket`). Le provider voit alors des différences parasites (`ulimit`, `pid_mode`)
  qui n'existent pas avec Docker Engine : ignorez-les.
- Travaillez dans une **copie** des dossiers fournis (`cp -r opentofu-nginx ~/ex-tofu`) : le state et `.terraform/` ne
  doivent pas finir dans le dépôt du cours.
- Mémo des commandes : [`ressources/cheatsheet-opentofu-ansible.md`](../../ressources/cheatsheet-opentofu-ansible.md).

# Démos formateur

Démos live des matinées (et des débuts d'après-midi). Chaque dossier est **autonome** : un `README.md` avec le déroulé minuté (« dire / taper / montrer / question à poser à la salle ») et, quand c'est pertinent, un `demo.sh` rejouable.

## Index

| Démo | Jour / bloc | Durée | Ce qu'on montre |
|---|---|---|---|
| [demo-git-branches](demo-git-branches/) | J1 — Bloc 2.1 | 10 min | branche = pointeur ; fast-forward, commit de fusion, squash |
| [demo-git-conflit](demo-git-conflit/) | J1 — TP 1 | 10 min | conflit textuel (`zdiff3`), conflit sémantique, `log --merge`, `merge --abort` |
| [demo-compose](demo-compose/) | J2 — étape 0 (secours) | 10-25 min | rappel Docker express : web + Postgres + Adminer, `.env`, DNS par service, healthcheck, volume |
| [demo-actions-hello](demo-actions-hello/) | J2 — Bloc 3.2 | 15 min | événements, jobs, steps, runner, contextes, `needs`, `workflow_dispatch`, job en échec |
| [demo-jenkins-gitlab](demo-jenkins-gitlab/) | J2 — Bloc 3.3 | 15 min | le CI de TaskFlow dans Jenkins (configuration as code) ; `.gitlab-ci.yml` équivalent |
| [demo-ssh-serveur](demo-ssh-serveur/) | J3 — Bloc 4.3 | 15 min | vrai serveur : clé SSH, non-root, pare-feu ; déploiement push vs pull |
| [demo-trivy-gitleaks](demo-trivy-gitleaks/) | J3 — Bloc 7.1 | 15 min | secret dans l'historique (gitleaks), CVE d'une image (Trivy) |
| [demo-opentofu-docker](demo-opentofu-docker/) | J4 — Bloc 5.2 | 15 min | `init` / `plan` / `apply` / `destroy`, state, drift |
| [demo-ansible-local](demo-ansible-local/) | J4 — Bloc 5.3 | 10 min | playbook, idempotence (`changed` → `ok`), template, handler |
| [demo-prometheus-grafana](demo-prometheus-grafana/) | J4 — Bloc 6.1 | 15 min | métriques RED, PromQL, dashboard provisionné, alerte jusqu'au mail |
| [demo-zap-juice-shop](demo-zap-juice-shop/) | J5 — Bloc 7.4 | 10 min | scan ZAP baseline d'une cible d'entraînement, lecture du rapport |

## Conventions des scripts `demo.sh`

- `bash` strict (`set -euo pipefail`), chaque commande est **affichée en vert avant d'être exécutée** : la salle lit ce que vous tapez.
- Une pause (`Entrée pour continuer…`) entre chaque étape. `DEMO_AUTO=1` supprime les pauses pour tester avant le cours :

  ```bash
  for d in demos/demo-*/; do [ -f "$d/demo.sh" ] && DEMO_AUTO=1 bash "$d/demo.sh" >/dev/null && echo "OK $d"; done
  ```

- Tout est créé dans un dossier temporaire (`mktemp`) et **nettoyé à la fin**, y compris après Ctrl+C (`trap … EXIT`) : conteneurs, volumes, images construites. Les images de base téléchargées restent en cache.
- Les démos Git créent un dépôt jetable dans `/tmp` (`KEEP=1` pour le conserver et le faire explorer).
- `DOCKER=podman` est accepté ; les images sont **pleinement qualifiées** (`docker.io/library/…`) pour fonctionner aussi avec Podman.
- Ports modifiables par variables d'environnement (voir chaque README) si un port est déjà pris.

## Avant le premier jour

Le réseau de salle est souvent lent : pré-téléchargez les images la veille.

```bash
for img in \
  docker.io/library/nginx:1.27-alpine docker.io/library/nginx:1.29-alpine docker.io/library/alpine:3.21 \
  docker.io/library/node:20-alpine docker.io/library/postgres:16-alpine docker.io/library/adminer:4 \
  docker.io/aquasec/trivy docker.io/zricethezav/gitleaks \
  docker.io/prom/prometheus docker.io/prom/alertmanager docker.io/prom/blackbox-exporter docker.io/grafana/grafana \
  docker.io/bkimminich/juice-shop ghcr.io/zaproxy/zaproxy:2.17.0; do
  docker pull "$img"
done
# + l'image Jenkins de demo-jenkins-gitlab (voir son README), à construire la veille
```

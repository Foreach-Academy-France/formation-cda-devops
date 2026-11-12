# Lab

Le lab tient en **un seul conteneur** : le runner GitHub Actions self-hosted (`runner/`).

```
ressources/lab/
└── runner/     # runner GitHub Actions self-hosted (docker compose up -d --build)
```

## Il n'y a pas de serveur à installer

Ni VPS ni SSH en TP : **votre poste** porte les deux environnements, chacun dans son dossier et son projet Compose.

| Élément | Où | Rôle |
|---|---|---|
| Dépôt `taskflow` | GitHub | `ci.yml` (J2), `release.yml` (J3) : build, scan Trivy, publication sur ghcr.io |
| `~/taskflow-staging/` (`STAGING_DIR`) | votre poste | **serveur de staging** : `compose.staging.yaml`, `.env` ; au J4, aussi le state OpenTofu |
| `~/taskflow-prod/` (`PROD_DIR`) | votre poste | **serveur de production** : `compose.prod.yaml`, `nginx/`, `.env`, `certs/`, `backups/` |
| Projet `taskflow-staging` | Docker du poste | db + api + front, **sans proxy**, `http://localhost:8081` |
| Projet `taskflow-prod` | Docker du poste | db + api + front + `proxy` (Nginx, HTTPS auto-signé), `https://taskflow.localhost` |
| Runner (`runner/`) | conteneur du poste | exécute `deploy-staging` et `deploy-production` (labels `self-hosted,lab`) |

## Ports du poste pendant la semaine

| Port | Usage |
|---|---|
| 8080 | TaskFlow en **dev** (`compose.yaml`) |
| 8081 | TaskFlow **staging** |
| 80 / 443 | TaskFlow **prod** (proxy) ; à défaut **8082 / 8443** (`HTTP_PORT` / `HTTPS_PORT` dans `~/taskflow-prod/.env`) |
| 3000 | API en dev (hors conteneur) |
| 3001 · 9090 · 9093 | Grafana · Prometheus · Alertmanager (J4) |
| 3002 | OWASP Juice Shop (J5) |
| 8880 / 8444 | labo Nginx de l'exercice 3.2 |

## Chemin d'un déploiement

```
merge sur main
  -> GitHub (cloud)  : prepare -> images (build -> Trivy -> push ghcr.io)
  -> runner (poste)  : deploy-staging   : docker compose pull && up -d dans ~/taskflow-staging
                       smoke test http://host.docker.internal:8081/health
  -> approbation humaine (environment production)
  -> runner (poste)  : deploy-production : sauvegarde, pull && up -d dans ~/taskflow-prod
                       smoke test https://host.docker.internal:<HTTPS_PORT>/health (certificat vérifié)
```

Le runner **va chercher** ses jobs chez GitHub (connexion sortante, modèle *pull*) : rien à ouvrir sur le poste.

Mise en route : [`runner/README.md`](runner/README.md), au moment de la partie B du TP étape 2 (Jour 3).

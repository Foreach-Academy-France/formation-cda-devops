# Architecture de TaskFlow

Ce document répond à la question : *« qu'est-ce qui tourne où, et qui parle à qui ? »*

## Quatre environnements sur le même poste

| | Développement | Staging | « Production » | Monitoring |
| --- | --- | --- | --- | --- |
| Décrit par | `compose.yaml` | `infra/` (OpenTofu) — `compose.staging.yaml` au J3 | `compose.prod.yaml` | `monitoring/compose.monitoring.yaml` |
| Dossier | le dépôt | `~/taskflow-staging/` (state OpenTofu) | `~/taskflow-prod/` | `monitoring/` |
| Images | construites localement | ghcr.io (`image_tag`) | ghcr.io (`IMAGE_TAG`) | images officielles |
| Accès | `http://localhost:8080` | `http://localhost:8081` | `https://taskflow.localhost` | Grafana `:3001`, Prometheus `:9090`, Alertmanager `:9093`, Mailpit `:8025` |
| Déployé par | le développeur | `release.yml`, job `deploy-staging` (auto) | `release.yml`, job `deploy-production` (approbation) | à la main (`docker compose up -d`) |

## Vue d'ensemble (production)

```mermaid
flowchart LR
    U["Navigateur<br/>https://taskflow.localhost"] -->|"HTTPS :443<br/>(HTTP :80 redirigé)"| P

    subgraph H["Poste (hôte Docker) : stack taskflow-prod"]
        subgraph D["Réseau privé Compose"]
            P["proxy<br/>Nginx : TLS, reverse proxy"] -->|"http://front:80"| F["front<br/>Nginx + site statique"]
            F -->|"/api et /health<br/>http://api:3000"| A["api<br/>Node + Express"]
            A -->|"SQL :5432"| DB[("db<br/>PostgreSQL 16")]
            DB --- V[("volume pgdata")]
        end
        C["certs/ (gitignoré)"] -.->|"monté en lecture seule"| P
    end
```

Seul le service `proxy` publie des ports (`HTTP_PORT`, `HTTPS_PORT`). Le front, l'API et la
base ne sont **pas** joignables depuis l'extérieur : ils ne sont visibles que sur le réseau
privé créé par Compose.

## Chaîne de livraison (CI/CD)

```mermaid
flowchart LR
    Dev["Développeur"] -->|"Pull Request"| CI["ci.yml<br/>lint, tests, intégration, build"]
    Dev -->|"PR sur infra/"| IAC["iac.yml<br/>fmt, validate, plan"]
    Dev -->|"PR + hebdo"| SEC["security.yml<br/>gitleaks, npm audit,<br/>Semgrep, ZAP"]
    CI -->|"merge sur main"| R["release.yml"]
    R --> B["images<br/>build → Trivy → push ghcr.io<br/>tag : SHA court"]
    B --> ST["deploy-staging<br/>runner du lab<br/>tofu apply + smoke test"]
    ST --> PR["deploy-production<br/>approbation humaine<br/>deploy.sh + smoke test"]
```

Le runner `[self-hosted, lab]` est un conteneur sur le poste qui pilote le Docker de la
machine (socket monté). C'est ce qui lui permet de mettre à jour le staging et la production :
GitHub ne pourrait pas atteindre votre poste depuis Internet. Rollback : relancer *Release*
à la main avec le tag d'une version précédente.

## Services et ports

| Service | Image | Port conteneur | Publié sur l'hôte | Rôle |
| --- | --- | --- | --- | --- |
| `proxy` | `nginx:1.29-alpine` | 80, 443 | `${HTTP_PORT:-80}`, `${HTTPS_PORT:-443}` | HTTPS, redirection 80 → 443 |
| `front` | `ghcr.io/<owner>/taskflow-front` (Nginx) | 80 | non publié (dev : `8080`) | Sert le site, relaie `/api` et `/health` |
| `api` | `ghcr.io/<owner>/taskflow-api` (Node 20) | 3000 | non publié | API REST |
| `db` | `postgres:16-alpine` | 5432 | non publié | Stockage (volume `pgdata`) |

## Flux d'une requête

1. Le navigateur demande `https://taskflow.localhost/api/tasks`.
2. Le `proxy` termine le TLS (certificat de `certs/`) et transmet à `http://front:80`.
3. Le Nginx de `front` reconnaît le préfixe `/api/` et transmet à `http://api:3000`.
4. L'API lit la base (`db:5432`), répond en JSON, et écrit une ligne de log JSON sur stdout.
5. La réponse remonte le même chemin.

> Le Nginx de `front` re-résout `api` toutes les 10 s (directive `resolver`). Le `proxy`,
> lui, résout `front` au démarrage : `deploy.sh` le recharge (`nginx -s reload`) après chaque
> déploiement. Sans cela, après un redéploiement (nouveau conteneur, donc parfois nouvelle
> adresse IP), ils continueraient d'écrire à l'ancienne adresse : erreur 502.

## Santé et supervision

- `GET /health` → `{ "status": "ok", "db": "up", "version": "<sha>", "env": "production" }`,
  ou **503** si la base est injoignable.
- Chaque conteneur a un `healthcheck` ; `docker compose ps` affiche `healthy` / `unhealthy`.
- `restart: unless-stopped` relance un conteneur tombé.
- Logs de l'API : lignes JSON (`method`, `path`, `status`, `ms`) :
  `docker compose -f compose.prod.yaml logs -f --since 10m api`.
- La stack de monitoring rejoint le réseau `taskflow-prod` (déclaré `external`) :
  Prometheus collecte `api:3000/metrics` (métriques RED + nombre de tâches) et le blackbox
  exporter sonde `http://front/health`. `/metrics` n'est **jamais** routé par les Nginx :
  il n'est visible que sur le réseau privé.
- Les règles d'alerte (`monitoring/prometheus/rules/taskflow.yml`, dont `TaskFlowApiDown`)
  partent vers Alertmanager, qui envoie un mail (Mailpit en local).

## Configuration

| Variable | Où elle est définie | Rôle |
| --- | --- | --- |
| `DATABASE_URL` | `.env` de `~/taskflow-prod/` | Connexion de l'API à PostgreSQL |
| `POSTGRES_PASSWORD` | `.env` | Mot de passe de la base |
| `APP_ENV` | `.env` | `production` |
| `APP_VERSION` | construite dans l'image par le CI | SHA court affiché dans `/health` |
| `GHCR_OWNER`, `IMAGE_TAG` | `.env` / `deploy.sh` | Quelles images lancer |
| `HTTP_PORT`, `HTTPS_PORT` | `.env` | Ports publiés par le proxy |

Le fichier `.env`, `certs/` et `backups/` n'existent **que** dans le dossier de déploiement.
Ils ne sont jamais versionnés ni copiés par le pipeline.

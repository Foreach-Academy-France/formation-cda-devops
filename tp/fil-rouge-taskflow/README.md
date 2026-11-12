# Fil rouge : TaskFlow

> **Quand** : du jour 2 au jour 5 | **Format** : individuel (avec un binôme pour les revues de code)
> **Objectif** : faire passer une application dans une chaîne DevOps complète. Elle est **vérifiée** à chaque PR (CI),
> **publiée et scannée** (ghcr.io, Trivy), **déployée** en staging puis en production (CD), son infrastructure est
> **décrite en code** (OpenTofu), elle est **surveillée** (Prometheus, Grafana, alertes) et **contrôlée** (DevSecOps).

---

## Présentation de TaskFlow

TaskFlow est un gestionnaire de tâches **volontairement simple** : vous n'aurez presque pas de code applicatif à écrire.
Tout l'effort porte sur ce qui entoure le code : images, environnement, pipeline, déploiement, exploitation.

| Partie | Technologie | Port | Rôle |
|---|---|---|---|
| `front/` | Vite + JavaScript sans framework ; en conteneur, servi par **Nginx** | 5173 avec `npm run dev`, 8080 avec Compose | L'interface web |
| `api/` | Node 20 + Express + `pg` (client PostgreSQL) | 3000 | L'API REST (*REST* : des URL qui représentent des ressources, manipulées avec GET, POST, PATCH, DELETE) |
| base | PostgreSQL 16 | 5432 | Une table `tasks` (créée automatiquement au démarrage de l'API) |

**Routes de l'API**

| Méthode et chemin | Rôle | Réponse |
|---|---|---|
| `GET /api/tasks` | Liste des tâches | 200 |
| `POST /api/tasks` avec `{ "title": "..." }` | Crée une tâche | 201 |
| `PATCH /api/tasks/:id/toggle` | Bascule « terminée / à faire » | 200 ou 404 |
| `DELETE /api/tasks/:id` | Supprime une tâche | 204 ou 404 |
| `GET /health` | État de l'API et de la base : `{"status":"ok","db":"up","version":"dev","env":"local"}` | 200, ou **503** si la base ne répond pas |

`/health` est la route clé de la semaine : elle sert aux healthchecks Docker, au smoke test du pipeline et à la supervision.

**Variables d'environnement de l'API** (valeurs par défaut dans `api/src/config.js`)

| Variable | Défaut | Rôle |
|---|---|---|
| `PORT` | `3000` | Port d'écoute |
| `DATABASE_URL` | `postgres://taskflow:taskflow@localhost:5432/taskflow` | Adresse de la base : `postgres://utilisateur:motdepasse@hôte:port/base` |
| `APP_ENV` | `local` | `local` ou `production` |
| `APP_VERSION` | `dev` | Version affichée par `/health` (le pipeline y mettra le « SHA court » du commit : les 7 premiers caractères de son identifiant, par exemple `a1b2c3d`) |

L'API écrit **une ligne JSON par requête** sur sa sortie standard (`method`, `path`, `status`, `ms`) : vous les lirez avec
`docker logs` et `docker compose logs`.

### Ce qui est fourni, ce que vous ajoutez

Le **starter** contient le code, les tests et le lint (tout est vert), plus les **Dockerfiles** (`api/`, `front/` en
multi-stage), `front/nginx.conf` et un **`compose.yaml` de développement** : `docker compose up -d --build` lance
db + api + front sur http://localhost:8080. Vous ne les écrivez pas, mais vous devez savoir les expliquer : c'est le rôle
du rappel Docker de l'étape 0.

Il ne contient **aucun** workflow, ni configuration de déploiement, d'IaC, de monitoring ou de sécurité. C'est votre
travail de la semaine.

### Architecture visée en fin de semaine

```
                                   Votre poste
 ┌───────────────────────────────────────────────────────────────────────────────┐
 │ DEV        ~/taskflow       docker compose up   → http://localhost:8080          │
 │                                                                                  │
 │ STAGING    ~/taskflow-staging  (Compose au J3, OpenTofu au J4)                   │
 │            front:8081 → api → db                → http://localhost:8081          │
 │                                                                                  │
 │ PROD       ~/taskflow-prod  stack « taskflow-prod » (réseau taskflow-prod)       │
 │            proxy Nginx 80/443 → front → api → db → https://taskflow.localhost    │
 │                                                                                  │
 │ MONITORING stack « taskflow-monitoring », branchée sur le réseau taskflow-prod   │
 │            Prometheus :9090 · Grafana :3001 · Alertmanager :9093                 │
 │                                                                                  │
 │ RUNNER     conteneur GitHub Actions self-hosted : récupère les jobs de deploy    │
 └───────────────────────────────────────────────────────────────────────────────┘
        ▲ images tirées de ghcr.io                  ▲ jobs récupérés chez GitHub
        └── GitHub : dépôt taskflow · ci.yml · release.yml · iac.yml · security.yml ┘
```

Il n'y a **ni serveur distant ni cloud** dans le TP : votre poste joue le rôle des serveurs. Les gestes (images
versionnées, `.env` hors Git, environnements séparés, reverse proxy, HTTPS, state d'infrastructure, alertes) sont
ceux de la production réelle. Ce qui change sur un vrai serveur ou un vrai cloud est expliqué dans les slides.

---

## Les étapes du fil rouge

| Étape | Quand | Durée | Énoncé | Branche conseillée | Ce que vous ajoutez au dépôt |
|---|---|---|---|---|---|
| 0 | J2 matin | 15 min | [`etape0-mise-en-place.md`](etape0-mise-en-place.md) | — | Dépôt `taskflow`, ruleset sur `main`, appli lancée avec Compose |
| 1 | J2 après-midi | 3h30 | [`etape1-ci.md`](etape1-ci.md) | `ci/pipeline` | `.github/workflows/ci.yml`, `ci-autres-outils/` (Jenkinsfile, `.gitlab-ci.yml`), checks requis |
| 2 | J3 après-midi | 3h30 | [`etape2-cd.md`](etape2-cd.md) | `cd/release` | `compose.prod.yaml`, `deploy/`, `.env.example`, `.github/workflows/release.yml`, `.github/dependabot.yml`, `docs/DEPLOIEMENT.md` |
| 3 | J4 après-midi | 1h | [`etape3-iac.md`](etape3-iac.md) | `infra/staging` | `infra/` (OpenTofu), `.github/workflows/iac.yml` (bonus : `ansible/`) |
| 4 | J4 après-midi | 2h | [`etape4-monitoring.md`](etape4-monitoring.md) | `feat/metrics`, `ops/monitoring` | `api/src/metrics.js`, `monitoring/`, `docs/INCIDENTS.md`, une issue d'amélioration |
| 5 | J5 | 55 min | [`etape5-devsecops.md`](etape5-devsecops.md) | `sec/pipeline` | `.github/workflows/security.yml`, en-têtes dans `front/nginx.conf`, `docs/SECURITE.md` |

Chaque étape se termine par une checklist **« Je valide avec le formateur »** et par une PR revue par votre binôme.

**Conventions** (les mêmes qu'au TP 1) :

- une branche par sujet, jamais de commit direct sur `main` (le ruleset l'interdit) ;
- messages *Conventional Commits* : `feat:`, `fix:`, `docs:`, `ci:`, `build:`, `test:`, `chore:` ;
- une PR par étape, avec une description qui dit **ce qui change**, **pourquoi**, et **comment le vérifier**.

---

## Structure : `starter/` et `solution/`

```
fil-rouge-taskflow/
├── README.md                ← ce fichier
├── etape0-mise-en-place.md … etape5-devsecops.md   ← les énoncés
├── incident/                ← script et journaux de l'incident (étape 4)
├── starter/                 ← votre point de départ
│   ├── api/                 ← src/, tests/, Dockerfile
│   ├── front/               ← index.html, src/, tests/, Dockerfile, nginx.conf
│   ├── compose.yaml         ← environnement de développement
│   ├── docs/ARCHITECTURE.md
│   └── .github/             ← pull_request_template.md, CODEOWNERS (exemple)
└── solution/                ← le starter + tout ce que vous ajoutez pendant la semaine
    ├── .github/workflows/   ← ci.yml, release.yml, iac.yml, security.yml (+ dependabot.yml)
    ├── ci-autres-outils/    ← Jenkinsfile, .gitlab-ci.yml
    ├── compose.prod.yaml, .env.example, deploy/
    ├── infra/               ← OpenTofu (staging)
    ├── ansible/             ← bonus de l'étape 3
    ├── monitoring/          ← Prometheus, Grafana, Alertmanager, blackbox
    ├── api/src/metrics.js
    └── docs/                ← ARCHITECTURE, DEPLOIEMENT, INCIDENTS, SECURITE
```

Le **runner** GitHub Actions n'est pas dans votre dépôt : il est fourni dans
[`../../ressources/lab/runner/`](../../ressources/lab/runner/README.md).

---

## Vous êtes en retard ? Récupérer un fichier de la solution

Le but est d'avancer **et** de comprendre. Si vous êtes bloqué plus de 15 minutes sur un fichier :

1. Définissez une fois par terminal le chemin du dossier de la formation (adaptez-le) :

   ```bash
   export FORMATION=~/formation-cda-devops
   ls "$FORMATION/tp/fil-rouge-taskflow/solution"
   ```

2. Copiez **seulement** le fichier qui vous bloque, depuis votre dépôt :

   ```bash
   cd ~/taskflow
   cp "$FORMATION/tp/fil-rouge-taskflow/solution/.github/workflows/ci.yml" .github/workflows/ci.yml
   ```

3. **Lisez-le ligne par ligne** (chaque fichier de la solution est commenté) et comparez avec le vôtre : `git diff`.
4. Commitez en le disant honnêtement : `git commit -m "ci: reprend ci.yml de la solution"`.

> Attention aux fichiers qui évoluent d'un jour à l'autre : `release.yml` de la solution contient déjà la version
> finale (staging via OpenTofu au jour 4). Au jour 3, reprenez plutôt les extraits donnés dans l'énoncé de l'étape 2.

> Copier n'est pas tricher si vous comprenez ce que vous copiez : en entreprise, on part très souvent d'un fichier
> existant. Le formateur vous posera des questions sur chaque ligne lors de la validation.

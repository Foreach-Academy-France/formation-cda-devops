# TaskFlow

Un petit gestionnaire de tâches, volontairement simple : c'est le **fil rouge** de la
formation DevOps. Le code est fourni ; votre travail sera de le **conteneuriser, tester
automatiquement, publier et déployer**.

```
taskflow/
├── front/   # Interface web : Vite + JavaScript (sans framework)
└── api/     # API REST : Node 20 + Express + PostgreSQL
```

## Ce qu'il faut sur votre poste

- Node.js 20 ou plus (`node -v`)
- Docker (uniquement pour lancer la base PostgreSQL pendant cette première étape)

## Lancer l'application en local

### 1. La base de données PostgreSQL (une seule ligne)

```bash
docker run -d --name taskflow-db -e POSTGRES_USER=taskflow -e POSTGRES_PASSWORD=taskflow -e POSTGRES_DB=taskflow -p 5432:5432 postgres:16-alpine
```

> Ces valeurs correspondent à `DATABASE_URL` par défaut :
> `postgres://taskflow:taskflow@localhost:5432/taskflow`.
> Pour arrêter puis supprimer la base : `docker rm -f taskflow-db`.

### 2. L'API (port 3000)

```bash
cd api
npm ci
npm run dev
```

Vérification : <http://localhost:3000/health> doit afficher `{"status":"ok","db":"up",...}`.

### 3. Le front (port 5173)

Dans un **second terminal** :

```bash
cd front
npm ci
npm run dev
```

Ouvrez <http://localhost:5173>. En développement, Vite redirige `/api` et `/health`
vers l'API (voir `front/vite.config.js`).

## Variables d'environnement de l'API

| Variable       | Défaut                                                  | Rôle                              |
| -------------- | ------------------------------------------------------- | --------------------------------- |
| `PORT`         | `3000`                                                  | Port d'écoute                     |
| `DATABASE_URL` | `postgres://taskflow:taskflow@localhost:5432/taskflow`  | Connexion PostgreSQL              |
| `APP_ENV`      | `local`                                                 | `local` ou `production`           |
| `APP_VERSION`  | `dev`                                                   | Version affichée dans `/health`   |

Voir `api/.env.example`. Ne commitez jamais un vrai fichier `.env`.

## Qualité du code

Dans `api/` **et** dans `front/` :

| Commande               | Rôle                                         |
| ---------------------- | -------------------------------------------- |
| `npm run lint`         | Analyse du code avec ESLint                  |
| `npm run format:check` | Vérifie le formatage Prettier                |
| `npm run format`       | Reformate automatiquement le code            |
| `npm test`             | Tests unitaires (Vitest)                     |

Spécifique à l'API : `npm run test:int` lance le test d'intégration avec une vraie base
(il est ignoré si `DATABASE_URL` n'est pas défini) :

```bash
DATABASE_URL=postgres://taskflow:taskflow@localhost:5432/taskflow npm run test:int
```

## Aperçu de l'API

| Méthode et chemin           | Rôle                                  | Réponse          |
| --------------------------- | ------------------------------------- | ---------------- |
| `GET /api/tasks`            | Liste des tâches                      | 200              |
| `POST /api/tasks`           | Crée une tâche (`{ "title": "..." }`) | 201              |
| `PATCH /api/tasks/:id/toggle` | Bascule terminée / à faire          | 200 ou 404       |
| `DELETE /api/tasks/:id`     | Supprime une tâche                    | 204 ou 404       |
| `GET /health`               | État de l'API et de la base           | 200, ou 503 si la base est down |

L'API écrit **une ligne JSON par requête** sur sa sortie standard (`method`, `path`,
`status`, `ms`) : vous les retrouverez avec `docker logs` plus tard.

---

## Version « solution » : tout ce qui est construit pendant la formation

Les Dockerfiles et `compose.yaml` sont fournis dès le starter. La solution ajoute la chaîne DevOps complète.

### Tout lancer avec Docker Compose (développement)

```bash
docker compose up -d --build
docker compose ps            # db, api et front doivent être "healthy"
```

Application : <http://localhost:8080> · santé : <http://localhost:8080/health>.
Arrêter : `docker compose down` (garde les données) ou `docker compose down -v` (efface aussi le volume).

### Fichiers ajoutés, jour par jour

| Jour | Fichier / dossier | Rôle |
| --- | --- | --- |
| J2 | `.github/workflows/ci.yml` | Lint, tests unitaires et d'intégration (service Postgres), build, matrix Node 20/22, couverture |
| J2 | `ci-autres-outils/` | Le même pipeline en `Jenkinsfile` et `.gitlab-ci.yml` |
| J3 | `.github/workflows/release.yml` | Build → scan Trivy → push ghcr.io → staging (auto) → production (approbation) ; rollback |
| J3 | `compose.prod.yaml`, `compose.staging.yaml`, `.env.example`, `deploy/` | Environnements, proxy HTTPS, certificat, déploiement, smoke test, sauvegarde |
| J3 | `.github/dependabot.yml`, `.pre-commit-config.yaml` | Mises à jour des dépendances, gitleaks avant chaque commit |
| J4 | `infra/`, `.github/workflows/iac.yml` | Le staging en OpenTofu ; fmt, validate et plan sur les PR |
| J4 | `ansible/` | Bonus : préparation du dossier de production |
| J4 | `api/src/metrics.js`, `monitoring/` | `/metrics`, Prometheus, Grafana, Alertmanager, blackbox |
| J5 | `.github/workflows/security.yml`, `.gitleaks.toml`, `.zap/` | gitleaks, npm audit, Semgrep, ZAP baseline |
| J5 | `front/nginx.conf` (en-têtes), `api/src/app.js` (durcissement) | Corrections issues des rapports de sécurité |
| — | `docs/` | ARCHITECTURE, DEPLOIEMENT, INCIDENTS, SECURITE |

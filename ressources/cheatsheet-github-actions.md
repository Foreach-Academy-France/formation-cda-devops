# Cheatsheet GitHub Actions

> Un **workflow** (fichier YAML dans `.github/workflows/`) est déclenché par un **événement** ; il contient des **jobs** (en parallèle par défaut) ; chaque job tourne sur un **runner** neuf et enchaîne des **steps** (une commande `run:` ou une action `uses:`). Un job = un **check** sur la PR.

## Anatomie d'un workflow (CI de TaskFlow, abrégée)

```yaml
name: CI                                   # nom dans l'onglet Actions

on:                                        # QUAND ?
  pull_request:                            # toujours, sans filtre (checks requis !)
  push:
    branches: [main]
    paths-ignore: ["**.md", "docs/**"]     # filtre seulement sur push

permissions:                               # droits du GITHUB_TOKEN, au plus juste
  contents: read

concurrency:                               # annule le run dépassé d'une PR, jamais sur main
  group: ci-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

env:
  COVERAGE_MIN: 75                         # une seule source de vérité

jobs:                                      # QUOI ?
  api:
    name: api                              # = nom du check (« api (20) » avec la matrice)
    runs-on: ubuntu-latest                 # OÙ ?
    timeout-minutes: 10
    strategy:
      fail-fast: false
      matrix:
        node: [20, 22]
    defaults:
      run:
        working-directory: api
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with:
          node-version: ${{ matrix.node }}
          cache: npm
          cache-dependency-path: api/package-lock.json   # depuis la RACINE
      - run: npm ci
      - run: npm run lint
      - run: npm run test:coverage
```

YAML : **espaces** uniquement (2 par niveau), jamais de tabulation ; `clé: valeur` (espace après `:`) ; `- ` = élément de liste ; `|` = bloc multi-ligne (sans lui, les lignes sont **repliées** en une seule) ; `>-` = lignes repliées sans saut final (pratique pour `options:`).

Valider avant de pousser : `docker run --rm -v "$PWD":/repo -w /repo docker.io/rhysd/actionlint:1.7.12`.

## Déclencheurs (`on:`)

| Déclencheur | Quand | Piège |
|---|---|---|
| `pull_request` | ouverture, réouverture, nouveau commit (`synchronize`) ; teste le **commit de fusion simulé** | secrets non transmis aux PR de forks |
| `push` (`branches:`, `tags: ["v*"]`, `paths:`, `paths-ignore:`) | push correspondant | `branches:` ne voit pas les tags |
| `workflow_dispatch` (+ `inputs:`) | bouton *Run workflow* | n'apparaît que si le fichier est sur la branche par défaut |
| `schedule: - cron: "0 5 * * 1"` | planifié, **UTC**, branche par défaut | peut être retardé ; désactivé après 60 jours sans activité |
| `workflow_call` | appelé par un autre workflow | réutilisation |
| `release: types: [published]` | publication d'une release | |

> **Filtre de chemins + check requis = PR bloquée.** Un check requis qui ne s'exécute pas reste *Expected — Waiting for status*. Filtrez les `push`, pas les `pull_request` (ou sautez les jobs avec `if:` : un job **sauté** compte comme réussi).

## Jobs : ordre, conditions, services

| Mot-clé | Effet |
|---|---|
| `needs: [api, front]` | attend la réussite de ces jobs (sinon : parallèle) |
| `if: github.ref == 'refs/heads/main'` | exécute seulement si… |
| `if: always()` / `failure()` / `cancelled()` | quoi qu'il arrive / après un échec / après annulation |
| `strategy.matrix` + `fail-fast: false` | répète le job ; chaque variante = un check `nom (valeur)` |
| `timeout-minutes: 10` | coupe un job bloqué (défaut : 360 min !) |
| `outputs:` + `${{ needs.<job>.outputs.<x> }}` | passer une valeur à un autre job |
| `runs-on: [self-hosted, lab]` | runner chez vous (Jour 3) |
| `environment: production` | secrets dédiés, approbation (Jour 3) |
| `container: node:20-alpine` | le job tourne **dans** un conteneur (services joignables par leur nom) |

Service Postgres (steps sur la VM → `localhost` + `ports:`) :

```yaml
    services:
      postgres:
        image: postgres:16-alpine
        env: { POSTGRES_USER: taskflow, POSTGRES_PASSWORD: taskflow, POSTGRES_DB: taskflow }
        ports: ["5432:5432"]
        options: >-
          --health-cmd "pg_isready -U taskflow -d taskflow"
          --health-interval 5s --health-timeout 3s --health-retries 10
    env:
      DATABASE_URL: postgres://taskflow:taskflow@localhost:5432/taskflow
```

## Expressions, contextes, fichiers spéciaux

| Expression / fichier | Valeur |
|---|---|
| `${{ github.sha }}`, `${{ github.ref_name }}`, `${{ github.event_name }}`, `${{ github.actor }}` | commit, branche/tag, événement, auteur |
| `${{ github.repository }}` / `${{ github.repository_owner }}` | `owner/repo` / `owner` |
| `${{ matrix.node }}`, `${{ inputs.tag }}`, `${{ steps.<id>.outputs.<x> }}` | matrice, saisie manuelle, sortie de step |
| `${{ env.X }}` / `${{ vars.X }}` / `${{ secrets.X }}` | variable du YAML / du dépôt / secret |
| `hashFiles('**/package-lock.json')`, `contains()`, `startsWith()`, `format()` | fonctions |
| `echo "cle=valeur" >> "$GITHUB_OUTPUT"` | sortie d'un step (`id:` requis) |
| `echo "### Titre" >> "$GITHUB_STEP_SUMMARY"` | Markdown dans le résumé du run |
| `echo "::error title=T::message"` / `::warning::` / `::notice::` | annotation sur la PR |
| `echo "X=1" >> "$GITHUB_ENV"` | variable pour les steps suivants |

SHA court : `echo "tag=${GITHUB_SHA::7}" >> "$GITHUB_OUTPUT"` ; propriétaire en minuscules : `${GITHUB_REPOSITORY_OWNER,,}`.

> **Injection** : `${{ }}` est remplacé **avant** l'exécution du shell. Ne mettez jamais une donnée contrôlable (titre de PR, nom de branche, `inputs.*`) directement dans `run:` ; passez-la par `env:` puis `"$VAR"`.

## Couverture avec seuil dans le résumé (TaskFlow)

```yaml
      - name: Couverture (seuil ${{ env.COVERAGE_MIN }} %)
        run: |
          lines=$(jq -r '.total.lines.pct' coverage/coverage-summary.json)
          echo "Couverture des lignes : **${lines} %** (seuil ${COVERAGE_MIN} %)" >> "$GITHUB_STEP_SUMMARY"
          if awk -v p="$lines" -v min="$COVERAGE_MIN" 'BEGIN { exit !(p < min) }'; then
            echo "::error title=Couverture insuffisante::${lines} % < ${COVERAGE_MIN} %"; exit 1
          fi
```

## Actions courantes

| Action | Rôle |
|---|---|
| `actions/checkout@v7` | récupère le code (la VM est vide) |
| `actions/setup-node@v7` | installe Node ; `cache: npm` + `cache-dependency-path` |
| `actions/cache@v4` | cache personnalisé (clé `hashFiles(...)`) |
| `actions/upload-artifact@v7` / `download-artifact` | conserver/partager des fichiers ; `path:` **depuis la racine**, `if-no-files-found: error` |
| `docker/setup-buildx-action@v4`, `docker/build-push-action@v7` | build d'images, cache `type=gha` |
| `docker/login-action`, `docker/metadata-action` | registre, tags d'images (Jour 3) |

> Une action référencée par **tag** (`@v7`) peut changer sous vos pieds : au Jour 3, on les épingle par **SHA** et Dependabot les met à jour.

## Secrets, variables, `GITHUB_TOKEN`

| Type | Où | Lecture |
|---|---|---|
| Secret | *Settings > Secrets and variables > Actions* (ou d'un Environment) | `${{ secrets.X }}` (masqué dans les logs) |
| Variable | même page, onglet *Variables* | `${{ vars.X }}` |
| `env:` | dans le YAML (workflow, job, step) | `$X` ou `${{ env.X }}` |
| `GITHUB_TOKEN` | automatique, expire avec le job | `${{ secrets.GITHUB_TOKEN }}` ; droits fixés par `permissions:` |

## Ruleset de `main` en code (`gh api`)

```bash
gh api "repos/{owner}/taskflow/rulesets" --jq '.[] | "\(.id) \(.name)"'      # lister
gh api -X POST "repos/{owner}/taskflow/rulesets" --input ruleset.json          # créer
gh api -X PUT  "repos/{owner}/taskflow/rulesets/<id>" --input ruleset.json     # remplacer (toutes les règles)
gh ruleset check main                                                          # règles qui s'appliquent
```

Règle des checks requis (noms **exacts** des checks, `15368` = application GitHub Actions) :

```json
{ "type": "required_status_checks",
  "parameters": { "strict_required_status_checks_policy": true,
    "required_status_checks": [ { "context": "api (20)", "integration_id": 15368 },
                                { "context": "api (22)", "integration_id": 15368 },
                                { "context": "api-integration", "integration_id": 15368 },
                                { "context": "front", "integration_id": 15368 } ] } }
```

## `gh` pour suivre la CI

| Commande | Effet |
|---|---|
| `gh pr create --fill --draft` / `gh pr ready` | ouvrir une PR brouillon / la sortir du brouillon |
| `gh pr checks --watch` | suivre les checks de la PR courante |
| `gh run list --limit 5` / `gh run watch` / `gh run view --log-failed` | lister, suivre, lire **seulement** les logs en échec |
| `gh run rerun <id> --failed` | relancer les jobs en échec |
| `gh workflow run ci.yml` | déclencher un `workflow_dispatch` |

## GitHub Actions ↔ GitLab CI ↔ Jenkins (l'essentiel)

| GitHub Actions | GitLab CI | Jenkins (déclaratif) |
|---|---|---|
| `.github/workflows/*.yml` | `.gitlab-ci.yml` | `Jenkinsfile` |
| job, `needs:` | job dans un `stage:`, `needs:` | `stage`, séquentiel ; `parallel { }` |
| `runs-on` + `setup-node` | `image: node:20-alpine` | `agent { docker { image 'node:20-alpine' } }` |
| `strategy.matrix` | `parallel: matrix:` | `matrix { axes { axis { … } } }` |
| `services:` (`localhost`) | `services:` + `alias` (nom du service) | `docker.image().withRun()` + réseau |
| `cache: npm` | `cache: key: files:` | rien d'intégré |
| `upload-artifact` | `artifacts: paths:` | `archiveArtifacts` |
| `concurrency` | `interruptible` + `auto_cancel` | `disableConcurrentBuilds(abortPrevious: true)` |
| `timeout-minutes` | `timeout:` | `options { timeout(...) }` |
| `secrets.X` | variables CI/CD masquées | Credentials + `withCredentials` |

Tableau complet : `tp/fil-rouge-taskflow/solution/ci-autres-outils/README.md`.

## Lire un échec

1. *Actions* > run rouge > job rouge > step marqué d'une croix (ou `gh run view --log-failed`).
2. Cherchez la **première** erreur utile (au-dessus de `##[error]Process completed with exit code 1`).
3. Reproduisez la commande en local, dans le bon dossier ; corrigez au bon endroit (code, lockfile, workflow).
4. *Re-run* seulement pour un incident externe (réseau, registre) ; *Enable debug logging* pour plus de détails.

## Pièges fréquents

- Fichier hors de `.github/workflows/` ou mauvaise extension : rien ne se passe, sans message.
- `cache-dependency-path` et `upload-artifact path:` ignorent `working-directory` : chemins depuis la racine.
- `run:` multi-ligne sans `|` : une seule commande aux arguments bizarres, sans erreur.
- Job renommé (ou matrice ajoutée) : le ruleset attend un check qui ne viendra plus.
- Service sans healthcheck : tests qui échouent « une fois sur trois ».
- `permissions:` absent : droits par défaut du dépôt, souvent trop larges.
- Cron en UTC ; `schedule` et `workflow_dispatch` lisent le fichier de la branche par défaut.
- Runner self-hosted sur dépôt public : n'acceptez pas les workflows de PR externes sans approbation (Jour 3).

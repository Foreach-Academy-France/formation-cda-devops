# La CI de TaskFlow dans trois outils

Ce dossier contient deux traductions de [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) :

| Fichier | Outil | Où le mettre dans un vrai projet |
|---|---|---|
| [`Jenkinsfile`](Jenkinsfile) | Jenkins (pipeline déclaratif, plugin *Docker Pipeline*) | racine du dépôt, ou *Script Path* du job = `ci-autres-outils/Jenkinsfile` |
| [`.gitlab-ci.yml`](.gitlab-ci.yml) | GitLab CI | **racine** du dépôt (ou chemin personnalisé dans *Settings > CI/CD*) |

Les trois fichiers font **la même chose** : lint et tests unitaires de l'API sur Node 20 et 22 avec un seuil de couverture de 75 %, tests d'intégration contre PostgreSQL 16, lint/tests/build du front avec conservation de `front/dist`, puis build des deux images Docker.

Ils ont été exécutés : le `Jenkinsfile` dans le Jenkins LTS de [`demos/demo-jenkins-gitlab/`](../../../../demos/demo-jenkins-gitlab/README.md), le `.gitlab-ci.yml` avec [`gitlab-ci-local`](https://github.com/firecow/gitlab-ci-local) (mêmes conteneurs qu'un runner GitLab de type *docker*).

## Tableau de correspondance

| Concept | GitHub Actions (`ci.yml`) | Jenkins (`Jenkinsfile`) | GitLab CI (`.gitlab-ci.yml`) |
|---|---|---|---|
| Fichier | `.github/workflows/*.yml` (plusieurs workflows possibles) | `Jenkinsfile` (Groovy déclaratif), un par job | `.gitlab-ci.yml` (un seul, `include:` pour découper) |
| Qui exécute | runner hébergé `ubuntu-latest` ou self-hosted | **controller** + **agents** (que vous installez et opérez) | **runner** GitLab (partagé sur gitlab.com ou le vôtre) |
| Déclencheurs | `on: pull_request`, `push: branches: [main]` | webhook du dépôt ou *Multibranch Pipeline* (scan des branches et PR) ; `triggers { cron(...) }` | `workflow: rules:` (`merge_request_event`, branche par défaut) |
| Ignorer la doc | `paths-ignore:` | `when { changeset 'api/**' }` sur un stage | `rules: changes:` (liste positive seulement) |
| Unité de travail | **job** → **steps** | **stage** → **steps** (`sh`) | **job** rangé dans un **stage** → `script:` |
| Ordre | parallèle par défaut, `needs:` pour séquencer | séquentiel par défaut, `parallel { }` pour paralléliser | les jobs d'un stage en parallèle, les stages en séquence ; `needs:` pour un graphe |
| Environnement d'exécution | VM + `actions/setup-node` | `agent { docker { image 'node:20-alpine' } }` | `image: node:20-alpine` |
| Récupérer le code | `actions/checkout` (explicite) | implicite à chaque nouvel agent (`checkout scm`) | implicite (le runner clone) |
| Dossier de travail | `defaults.run.working-directory` | `dir('api') { ... }` | `cd api` dans `before_script` |
| Matrice | `strategy.matrix` | `matrix { axes { axis { ... } } }` | `parallel: matrix:` |
| Base de test | `services:` (joignable sur `localhost` + `ports:`) | pas d'équivalent natif : `docker.image(...).withRun()` sur un réseau dédié | `services:` (joignable par son **alias**) |
| Attendre la base | `options: --health-cmd` | boucle `pg_isready` | le runner attend le port exposé |
| Cache des dépendances | `setup-node` `cache: npm` | rien d'intégré : volume, miroir npm (Nexus, Artifactory) | `cache: key: files: [package-lock.json]` |
| Artefact | `actions/upload-artifact` (`front-dist`) | `archiveArtifacts 'front/dist/**'` | `artifacts: paths: [front/dist/]` |
| Résumé / couverture | `$GITHUB_STEP_SUMMARY` + `::error` | console du build (plugins *Coverage*, *JUnit* pour des graphiques) | `coverage:` (regex, affichée sur la MR) |
| Durée max | `timeout-minutes` | `options { timeout(...) }` | `timeout:` |
| Annuler le run précédent | `concurrency` + `cancel-in-progress` | `disableConcurrentBuilds(abortPrevious: true)` | `interruptible: true` + `workflow: auto_cancel` |
| Secrets | `secrets.X` (Settings du dépôt) | *Credentials* + `withCredentials { }` | variables CI/CD *masked* / *protected* |
| Approbation manuelle | Environment avec *required reviewers* (Jour 3) | `input` | `when: manual` + environnement protégé |
| Réutilisation | actions, workflows réutilisables (`workflow_call`) | *Shared Libraries* | `extends:`, ancres YAML, `include:`, composants CI/CD |
| Bloquer le merge | ruleset + checks requis | statut renvoyé au dépôt (plugin GitHub / GitLab) | *Pipelines must succeed* (paramètre de MR) |

## Quand choisir quoi ?

| Situation | Choix raisonnable | Pourquoi |
|---|---|---|
| Code sur GitHub, équipe petite à moyenne | GitHub Actions | intégré à la PR, rien à opérer, Marketplace |
| Code sur GitLab (souvent auto-hébergé en entreprise) | GitLab CI | tout dans un outil : dépôt, CI, registre, environnements |
| Existant Jenkins, réseau fermé, outils maison, plusieurs forges | Jenkins | 100 % self-hosted, plugins pour tout, mais **à opérer** : mises à jour, plugins, sauvegarde de `JENKINS_HOME`, sécurité |
| Contrainte de souveraineté ou de coût des minutes | runners self-hosted (GitHub ou GitLab) | l'orchestrateur reste SaaS, l'exécution chez vous |

## Questions pour comparer

1. Dans Jenkins, pourquoi faut-il créer un réseau Docker et nettoyer derrière soi (`docker network rm`, `docker rmi`), alors que GitHub Actions et GitLab ne le demandent pas ?
2. Dans GitLab, l'API joint la base sur `postgres:5432` ; dans GitHub Actions, sur `localhost:5432`. Qu'est-ce qui explique la différence ?
3. Le `Jenkinsfile` ne met pas en cache `~/.npm`. Combien de temps cela coûte-t-il par build ? Comment l'éviter sur un agent permanent ?
4. Quel fichier est le plus lisible pour un nouveau venu ? Lequel est le plus puissant ? Le plus facile à **tester** avant de le pousser ?

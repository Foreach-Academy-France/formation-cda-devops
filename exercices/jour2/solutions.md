# Jour 2 — Solutions des exercices

> À ouvrir **après** avoir cherché (et utilisé les indices).

---

## Exercice 2.1 — Rebase interactif, fixup, tag

**1. Analyse.** La branche a **1 commit de retard** sur `main` (`feat(front): client API fetchTasks`) et 5 commits : `wip` + `tri des taches…` + `fix typo` forment **une** intention (le tri dans `api/src/app.js`) ; `docs: …` est propre ; `oups, fichier de debug` ajoute `debug.js` et doit disparaître.

**2-3. Une seule commande**, qui rebase sur `main`, réécrit et vérifie chaque commit :

```bash
git rebase -i main --exec "node --check api/src/app.js"
```

```text
reword <sha> wip
exec node --check api/src/app.js
fixup  <sha> tri des taches par statut (non terminées d'abord)
exec node --check api/src/app.js
fixup  <sha> fix typo
exec node --check api/src/app.js
pick   <sha> docs: documente le tri dans le README
exec node --check api/src/app.js
drop   <sha> oups, fichier de debug
exec node --check api/src/app.js
```

On ne modifie que les mots-clés des lignes `pick` ; les lignes `exec` (ajoutées par `--exec`) peuvent rester ou être supprimées sous les commits « fondus ». Git rouvre l'éditeur pour le `reword` : `feat(api): trie les tâches par statut`. Variante acceptée : `pick` sur `wip` puis `squash` et réécriture du message combiné. On peut aussi vérifier après coup : `git rebase main -x "node --check api/src/app.js"`.

> En vrai projet, l'`exec` serait `npm test` : chaque commit de la PR est alors **testé**, ce qui rend `git bisect` fiable.

```bash
git log --oneline --graph --all
git log --all --oneline -- debug.js     # rien
grep sort api/src/app.js                # tasks.sort((a, b) => Number(a.done) - Number(b.done));
git switch main && git merge feature/tri-taches   # Fast-forward
```

**4. Fast-forward** : la branche part du dernier commit de `main`, `main` n'a qu'à avancer son pointeur. Historique linéaire, pas de commit de fusion. Avec *Squash and merge* (la règle de TaskFlow), GitHub créerait **un seul** commit sur `main` contenant les deux, avec le titre de la PR comme message (`feat(api): trie les tâches par statut (#42)`) ; le détail `feat` / `docs` reste lisible dans la PR.

**5. SemVer.** Fonctionnalité compatible : on incrémente le MINEUR et on remet le CORRECTIF à zéro → **`v1.4.0`**.

```bash
git tag -a v1.4.0 -m "v1.4.0 : tri des tâches par statut (non terminées d'abord)"
git show --no-patch v1.4.0
git push origin v1.4.0          # dans un vrai dépôt : les tags ne partent pas avec git push
```

**6. CHANGELOG** :

```markdown
## [1.4.0]
### Ajouté
- `GET /api/tasks` renvoie les tâches non terminées en premier (#42)
```

**7.** Le **tag** est un repère Git immuable sur un commit (pour les outils et les développeurs) ; la **release GitHub** ajoute à ce tag des notes générées à partir des PR fusionnées et d'éventuels fichiers (pour les utilisateurs du dépôt) ; le **CHANGELOG** est l'historique rédigé, versionné dans le dépôt, orienté impact (pour les utilisateurs et le support). Sur TaskFlow : `git tag -a v0.1.0 -m "..." && git push origin v0.1.0 && gh release create v0.1.0 --generate-notes`.

**Bonus 8-9.** `git commit --fixup=<sha>` crée un commit nommé `fixup! feat(api): trie les tâches par statut`. `git rebase -i --autosquash main` le place automatiquement sous sa cible avec le mot-clé `fixup` : il suffit d'enregistrer. **10.** `rebase.autoSquash` rend `--autosquash` implicite ; `rerere` (*reuse recorded resolution*) mémorise la résolution d'un conflit et la rejoue si le même conflit revient (rebases répétés d'une longue branche).

**Questions de justification**

1. Le rebase **réécrit** les commits (nouveaux SHA). Un `git push` simple est refusé ; il faut `git push --force-with-lease`, qui refuse d'écraser la branche distante si quelqu'un y a poussé depuis votre dernier `fetch` (`--force` écrase sans vérifier). Le binôme doit ensuite `git fetch && git reset --hard origin/feature/tri-taches` (ou `git pull --rebase`) : à faire **avec** lui, d'où la règle d'or.
2. Le squash ne concerne que `main`. **Pendant la revue**, le relecteur lit les commits de la branche : des commits propres (`feat`, puis `docs`) se relisent un par un ; `--exec` garantit que chacun est valide ; rebaser sur `main` règle les conflits **avant** la revue (et satisfait *Require branches to be up to date*). *Rebase and merge* se justifie quand l'équipe veut garder **plusieurs** commits par PR sur `main` (grosses PR découpées, `git bisect` fin) : il exige alors des branches impeccables. Choix d'équipe, écrit dans `CONTRIBUTING.md` et imposé par les méthodes de merge du ruleset.
3. *Require branches to be up to date* oblige à intégrer `main` (rebase ou merge) avant de fusionner : les checks ont tourné sur le code **tel qu'il sera** après merge. Coût : avec 10 personnes qui fusionnent souvent, chacun rebase et relance la CI plusieurs fois (« course au merge ») ; la réponse à l'échelle est une *merge queue*.

---

## Exercice 2.2 — Le workflow cassé

| Ligne | Problème | Catégorie | Correction |
|---|---|---|---|
| 9 | `pull_request` sans `:` au milieu d'un dictionnaire | syntaxe YAML | `pull_request:` |
| 32 | tabulation avant `- run: npm test` | syntaxe YAML | 6 espaces |
| 35 | `runs-on ubuntu-latest` sans `:` | syntaxe YAML | `runs-on: ubuntu-latest` |
| 8 | `branch:` : clé inconnue, GitHub refuse le fichier (*Unexpected value*) | sémantique GHA | `branches: [main]` |
| 27 | `matrix.version` n'existe pas (la matrice définit `node`) | sémantique GHA | `${{ matrix.node }}` |
| 57 | `needs: [api-unit]` : job inexistant | sémantique GHA | `needs: [api]` |
| 29 | `cache-dependency-path: package-lock.json` : relatif à la racine, le fichier est dans `api/` | exécution (setup-node échoue : *Some specified paths were not resolved*) | `api/package-lock.json` |
| 51-53 | `run:` multi-ligne sans `\|` : YAML replie en `npm ci npm run test:int` | exécution silencieuse (`test:int` jamais lancé) | `run: \|` |
| 68 | `path: dist/` : `upload-artifact` ignore `working-directory` | exécution silencieuse (artefact vide, simple *warning*) | `path: front/dist/` (+ `if-no-files-found: error`) |
| 61-64 | job `front` sans `setup-node` : Node « de l'image du runner », non maîtrisé, sans cache | reproductibilité | ajouter `actions/setup-node` (`node-version: 20`, cache) ; idem pour `api-integration` |
| 11-12 | `contents: write` : le `GITHUB_TOKEN` pourrait pousser du code | sécurité | `contents: read` (moindre privilège) |
| 37-44 | service Postgres sans healthcheck : les tests peuvent démarrer avant que la base accepte les connexions (échec aléatoire) | robustesse | `options: --health-cmd "pg_isready -U taskflow -d taskflow" ...` |

Fichier corrigé (vérifié avec actionlint 1.7.12) :

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  api:
    name: api
    runs-on: ubuntu-latest
    strategy:
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
          cache-dependency-path: api/package-lock.json
      - run: npm ci
      - run: npm run lint
      - run: npm test

  api-integration:
    name: api-integration
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: taskflow
          POSTGRES_PASSWORD: taskflow
          POSTGRES_DB: taskflow
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready -U taskflow -d taskflow"
          --health-interval 5s
          --health-timeout 3s
          --health-retries 10
    env:
      DATABASE_URL: postgres://taskflow:taskflow@localhost:5432/taskflow
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with:
          node-version: 20
          cache: npm
          cache-dependency-path: api/package-lock.json
      - name: Installer et lancer les tests d'intégration
        working-directory: api
        run: |
          npm ci
          npm run test:int

  front:
    name: front
    runs-on: ubuntu-latest
    needs: [api]
    defaults:
      run:
        working-directory: front
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with:
          node-version: 20
          cache: npm
          cache-dependency-path: front/package-lock.json
      - run: npm ci
      - run: npm run build
      - uses: actions/upload-artifact@v7
        with:
          name: front-dist
          path: front/dist/
```

**Bonus `name:`** : le nom affiché d'un job est le nom du **check** sur la PR. Le ruleset référence ce nom : le renommer (ou le laisser dériver de l'identifiant) casse silencieusement la protection — la PR attend un check qui ne viendra plus.

**Questions de justification.** 1. Une PR et des **checks requis** : la PR rouge (ou un artefact vide repéré en revue) bloque le merge. Et la revue humaine du workflow lui-même. 2. Oui, c'est peu coûteux (quelques secondes) : un job `actionlint` déclenché par `paths: [".github/workflows/**"]`, ou mieux un hook **pre-commit** pour un retour immédiat ; les deux se complètent (le hook est contournable, la CI ne l'est pas).

---

## Exercice 2.3 — Quel workflow se déclenche ?

| # | Workflow(s) | Justification |
|---|---|---|
| 1 | aucun | `CI` ne réagit au `push` que sur `main` ; pas de PR ouverte. |
| 2 | **CI**, **Security** | `pull_request` (`opened`) sur les deux. |
| 3 | CI : **1** run va au bout (le second annule le premier) ; Security : **2** | `synchronize` à chaque commit ; `concurrency` de `ci.yml` regroupe par numéro de PR et annule le run dépassé. `security.yml` n'a pas de `concurrency`. |
| 4 | **CI**, **Release** | La fusion est un `push` sur `main` ; `app.js` n'est pas exclu par `paths-ignore`. |
| 5 | **CI**, **Security** | Sur `pull_request`, aucun filtre de chemins. |
| 6 | **aucun** | Push sur `main` ne touchant que `docs/**` : exclu de `CI` et de `Release` ; `Security` ne réagit pas au push. |
| 7 | **2** | Sur `main`, `cancel-in-progress` vaut `false` : chaque commit de `main` garde son verdict (les deux runs partagent le groupe `ci-refs/heads/main` : le second **attend** le premier). |
| 8 | **Release** | `workflow_dispatch` avec l'input `tag` (redéploiement / rollback, Jour 3). |
| 9 | **Security** | `cron: "0 5 * * 1"` = lundi 5 h 00 UTC, sur la branche par défaut. |
| 10 | **aucun** | Un tag n'est pas une branche : `branches: [main]` ne le concerne pas. |

11. Avec `paths-ignore` sur `pull_request`, la PR « doc seule » ne lancerait **aucun** job : les checks requis resteraient *Expected — Waiting for status to be reported* et la PR serait **bloquée à vie** (sauf contournement du ruleset). Sur `push: main`, il n'y a pas de check requis : filtrer y est sans risque. Solution avancée si l'on veut filtrer les PR : toujours lancer le workflow, et sauter les jobs coûteux avec une condition (`if:` sur la sortie d'un job « détecteur de changements », par exemple `dorny/paths-filter`) : un job **sauté** compte comme réussi.
12. Sur une PR, seul le dernier commit compte : annuler économise des minutes et donne le verdict plus vite. Sur `main`, chaque commit est un candidat à la livraison (Jour 3) : il doit avoir son verdict, et annuler un run de `main` laisserait un commit « sans statut ».
13. Paris = UTC+1 en hiver (6 h 00), UTC+2 en été (7 h 00). Une nouvelle vulnérabilité peut être publiée **sans** que le code change : le scan planifié la détecte même si personne n'ouvre de PR.
14. `on: push: tags: ["v*"]`, dans un workflow dédié (ou dans `release.yml` avec une condition), qui crée la release : `gh release create "$GITHUB_REF_NAME" --generate-notes` avec `permissions: contents: write` — **uniquement** sur ce job.

---

## Exercice 2.4 — Lire un log de CI en échec

### Log 1

- **Job/step** : `api (20)`, step `Run npm ci` (checkout et setup-node verts).
- **Cause** : `npm error Missing: zod@3.23.8 from lock file`.
- **Explication** : la PR a ajouté `zod` dans `api/package.json` sans commiter `api/package-lock.json`.
- **Correction** : sur le poste, `cd api && npm install` puis commit de `package.json` **et** `package-lock.json` ; la PR se relance seule.

1. `npm ci` est volontairement strict : il installe exactement ce qui a été testé et commité. `npm install` en CI masquerait l'oubli et installerait des versions potentiellement différentes de celles du développeur : on perd la reproductibilité.
2. Lancer en local les **mêmes** commandes que la CI (`npm ci && npm run lint && npm test`) avant de pousser ; ou un hook pre-push ; ou `npm ci` dans un script `verify` commun au poste et à la CI.

### Log 2

- **Job/step** : `api-integration`, step `Run npm run test:int` ; 4 tests en échec sur 4.
- **Cause** : `Error: connect ECONNREFUSED 127.0.0.1:5432`.
- **Explication** : les steps tournent **sur la VM** ; le port 5432 du conteneur Postgres n'est pas publié sur la VM.
- **Correction** : `ports: - 5432:5432` dans le service.

3. Oui : `postgres service is healthy.` La ligne `docker create … --network-alias postgres … postgres:16-alpine` ne contient **aucun** `-p`.
4. Ajouter `ports:` (corrigé ci-dessous). Si le job tournait dans un conteneur (`container: node:20-alpine`), pas besoin de `ports:` : le job et le service partagent un réseau Docker, et l'hôte devient `postgres` (nom du service) : `DATABASE_URL=postgres://taskflow:taskflow@postgres:5432/taskflow`.

```yaml
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: taskflow
          POSTGRES_PASSWORD: taskflow
          POSTGRES_DB: taskflow
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready -U taskflow"
          --health-interval 5s
          --health-timeout 3s
          --health-retries 10
```

### Log 3

- **Job/step** : `api (20)`, step `Run npm run test:coverage` ; `api (22)` est vert.
- **Cause** : `TypeError: Object.groupBy is not a function` (journalisée par l'API, d'où le `500` au lieu de `200`).
- **Explication** : `Object.groupBy` existe depuis Node 21. L'auteur développe en Node 22 : tout passe chez lui.
- **Correction** : voir question 6.

5. Même code, **runtimes** différents : la matrice teste exactement ce qu'on lui demande. Sans elle, le bug serait passé… et aurait cassé **en production**, puisque `api/Dockerfile` utilise `node:20-alpine`.
6. Options :
   - (a) retirer Node 20 de la matrice : `ci.yml` seulement. **Mauvais choix** : la prod tourne en Node 20, on cache le problème.
   - (b) réécrire sans `Object.groupBy` (un `reduce`, ou deux `filter`) : `api/src/app.js` seulement. **Choix recommandé aujourd'hui** : compatible avec ce qui est déployé, aucun risque.
   - (c) passer à Node 22 : `api/Dockerfile` (`FROM node:22-alpine`), `api/package.json` (`"engines": { "node": ">=22" }`), `ci.yml` (versions de `setup-node`, matrice 22/24), `front/Dockerfile` si l'on veut rester homogène, la doc du poste. Légitime, mais c'est une **décision d'équipe** à prendre dans sa propre PR, pas en douce dans une PR de fonctionnalité.
7. Sans `fail-fast: false`, l'échec de `api (20)` **annule** `api (22)` : on perd l'information « ça passe en 22 », précieuse pour le diagnostic.

---

## Exercice 2.5 — Traduire en GitLab CI et en Jenkins

Corrigés complets : [`traduire/corrige/.gitlab-ci.yml`](traduire/corrige/.gitlab-ci.yml) (validé par `gitlab-ci-local --list`) et [`traduire/corrige/Jenkinsfile`](traduire/corrige/Jenkinsfile) (validé par le linter déclaratif du Jenkins de la démo).

| Élément | Traduction | Remarque |
|---|---|---|
| `on: pull_request` + `push: main` | GitLab `workflow: rules:` ; Jenkins : configuration du job (webhook, Multibranch) | dans Jenkins, le déclencheur n'est **pas** dans le fichier |
| `concurrency` | `interruptible` + `auto_cancel` ; `disableConcurrentBuilds(abortPrevious: true)` | mot pour mot |
| `timeout-minutes` | `timeout:` ; `options { timeout(...) }` | mot pour mot |
| `strategy.matrix` | `parallel: matrix:` ; `matrix { axes ... }` **ou** une boucle | Jenkins : `matrix` interdit dans un `parallel` |
| `services: redis` | `services:` + `alias: redis` (adresse `redis:6379`) ; Jenkins : `withRun` + réseau + ménage | Jenkins demande du **code** |
| `needs: [lint, test]` | un stage suivant ; un stage séquentiel | GitLab peut aussi utiliser `needs:` |
| `cache: npm` | `cache: key: files:` + `npm ci --cache .npm` ; Jenkins : rien d'intégré | pas d'équivalent direct en Jenkins |
| `upload-artifact` | `artifacts: paths: expire_in:` ; `archiveArtifacts` | mot pour mot |

**Comparaison attendue (exemple).** Les concepts se traduisent un pour un (étapes, parallélisme, matrice, artefacts, durées). GitLab est le plus proche de GitHub Actions (YAML, services, cache). Jenkins demande du code pour ce que les plateformes SaaS offrent (services, cache, nettoyage) et le déclencheur vit **hors** du fichier ; en échange, il s'adapte à tout. Le plus facile à maintenir pour une petite équipe : celui de la forge qu'elle utilise déjà.

# Étape 1 : l'intégration continue de TaskFlow

> **Quand** : Jour 2, après-midi | **Durée** : 3h30 (débrief et quiz compris)
> **Objectif** : chaque PR et chaque push sur `main` déclenchent `ci.yml` (lint, tests unitaires sur Node 20 et 22,
> tests d'intégration contre PostgreSQL, couverture avec seuil, build du front et artefact) ; ces checks sont
> **requis** par le ruleset de `main` ; vous avez vu une PR cassée être **bloquée** ; vous savez lire et écrire
> l'équivalent **Jenkins** et **GitLab CI**.

---

## Prérequis (état attendu en début d'étape)

- Étape 0 validée : dépôt `<vous>/taskflow`, ruleset `protection-main` actif, binôme collaborateur, `docker compose up` OK.
- Slides du Jour 2, blocs 3.1 à 3.3 ; exercices 2.2 à 2.4 faits ce matin.
- Antisèche : [`ressources/cheatsheet-github-actions.md`](../../ressources/cheatsheet-github-actions.md).
- Extension VS Code *GitHub Actions* ; actionlint en conteneur :

  ```bash
  alias actionlint='docker run --rm -v "$PWD":/repo -w /repo docker.io/rhysd/actionlint:1.7.12'
  ```

**Le contrat de ce pipeline** (les jours suivants s'appuient dessus : respectez les noms à la lettre)

| Job (`name:`) | Ce qu'il fait | Check(s) sur la PR |
|---|---|---|
| `api` | lint + Prettier + tests unitaires + couverture (seuil), sur Node 20 **et** 22 | `api (20)`, `api (22)` |
| `api-integration` | `npm run test:int` contre un service `postgres:16-alpine` | `api-integration` |
| `front` | lint + Prettier + tests + build, artefact **`front-dist`** | `front` |
| `docker-build` (bonus) | les deux `Dockerfile` se construisent | `docker-build` (non requis) |

Déclencheurs : `pull_request` et `push` sur `main`. Une branche `feature/ci`, une PR, relue par le binôme.

---

## 1.0 Lancer en local ce que la CI lancera (10 min)

```bash
cd ~/taskflow && git switch main && git pull && git switch -c feature/ci
(cd api && npm ci && npm run lint && npm run format:check && npm run test:coverage)
(cd front && npm ci && npm run lint && npm run format:check && npm run test:coverage && npm run build)
```

**Résultat attendu** : API `Tests  27 passed | 10 skipped (37)` et un tableau de couverture dont la ligne
`All files` affiche environ **81 %** de lignes ; front `Tests  7 passed (7)` puis `✓ built in …`.

Puis les tests d'intégration contre un Postgres jetable (le même que le service de la CI) :

```bash
docker run -d --rm --name pg-ci -p 5432:5432 \
  -e POSTGRES_USER=taskflow -e POSTGRES_PASSWORD=taskflow -e POSTGRES_DB=taskflow \
  docker.io/library/postgres:16-alpine
sleep 5
(cd api && DATABASE_URL=postgres://taskflow:taskflow@localhost:5432/taskflow npm run test:int)
docker rm -f pg-ci
```

**Résultat attendu** : `Tests  10 passed (10)`.

> **Si ça ne marche pas**
> - `port is already allocated` sur 5432 : votre stack `docker compose` ne publie pas 5432, mais un autre Postgres local
>   peut le faire. Utilisez `-p 55432:5432` et adaptez `DATABASE_URL`.
> - `ECONNREFUSED` : Postgres n'a pas fini de démarrer ; relancez la commande de test.

> **Pourquoi ?** Un pipeline ne fait rien de magique : il lance **ces** commandes, sur une machine neuve, à chaque fois.
> Si une commande échoue chez vous, elle échouera chez GitHub — en plus lent.

---

## 1.1 Premier job `api` (20 min)

Créez `.github/workflows/ci.yml`. **Contraintes** :

- `name: CI` ; déclencheurs `pull_request` (sans filtre) et `push` sur `main` ;
- `permissions: contents: read` au niveau du workflow ;
- un job d'identifiant **et** de `name:` `api`, `runs-on: ubuntu-latest`, `timeout-minutes: 10` ;
- `defaults.run.working-directory: api` ;
- steps : checkout, `actions/setup-node@v7` (Node 20, `cache: npm`), `npm ci`, `npm run lint`, `npm run format:check`,
  `npm run test:coverage` — chaque step avec un `name:` lisible.

Squelette de départ :

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  api:
    name: api
    runs-on: ubuntu-latest
    timeout-minutes: 10
    defaults:
      run:
        working-directory: api
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with:
          node-version: 20
          cache: npm
          cache-dependency-path: ??? # chemin depuis la RACINE du dépôt
      # ... à vous
```

```bash
actionlint .github/workflows/ci.yml
git add .github/workflows/ci.yml && git commit -m "ci: ajoute le job api (lint, tests unitaires)"
git push -u origin feature/ci
gh pr create --fill --draft
gh pr checks --watch
```

**Résultat attendu** : le check `api` passe au vert en moins d'une minute. Dans le log du step de tests :
`27 passed | 10 skipped`.

> **Si ça ne marche pas**
> - Aucun run : le fichier doit être dans `.github/workflows/` (point, `s` final) et avoir l'extension `.yml`.
> - `Dependencies lock file is not found` : `cache-dependency-path` est relatif à la **racine**, pas au `working-directory`.
> - `Invalid workflow file` : relancez actionlint, il donne la ligne.

---

## 1.2 Matrice Node 20 / 22 (10 min)

Faites tourner le job `api` sur Node **20** (la version des images Docker) et **22** (la prochaine LTS que l'équipe
adoptera). Gardez le verdict des deux versions même si l'une échoue.

Indices : `strategy.matrix`, `${{ matrix.node }}`, `fail-fast`.

**Résultat attendu** : deux checks, **`api (20)`** et **`api (22)`**, tous deux verts.

> **Pourquoi deux checks ?** Quand un job a une matrice, GitHub ajoute les valeurs au nom : `api (20)`. C'est **ce nom**
> que le ruleset exigera. Si vous écriviez `name: api-${{ matrix.node }}`, les checks changeraient de nom (et le ruleset
> devrait suivre).

---

## 1.3 Job `api-integration` avec un service PostgreSQL (20 min)

Ajoutez un job **`api-integration`** (Node 20 seulement) qui lance `npm run test:int` contre un **service container**
`postgres:16-alpine`. Contraintes :

- mêmes identifiants qu'en local (`taskflow` / `taskflow` / base `taskflow`) — base jetable, pas un secret ;
- les steps tournent **sur la VM** : publiez le port, et définissez `DATABASE_URL` au niveau du job ;
- les tests ne démarrent qu'une fois la base **prête** (pas seulement « démarrée »).

Indices : `services:`, `ports:`, `options: --health-cmd "pg_isready -U taskflow -d taskflow" --health-interval 5s ...`,
`env:` au niveau du job.

**Résultat attendu** : un step *Initialize containers* qui se termine par `postgres service is healthy.`, puis
`Tests  10 passed (10)`.

> **Si ça ne marche pas**
> - `10 skipped` : `DATABASE_URL` n'est pas visible du step (mauvaise indentation de `env:`).
> - `ECONNREFUSED 127.0.0.1:5432` : `ports:` manque (relisez l'exercice 2.4, log 2).

> **Pourquoi un job séparé ?** Les tests d'intégration sont plus lents et dépendent d'un service : isolés, ils
> donnent un verdict distinct (« la logique est bonne, c'est la requête SQL qui casse ») et peuvent tourner **en
> parallèle** du job `api`. Le compromis inverse (`needs: api`) économise des minutes en cas d'échec unitaire, au prix
> d'un retour plus lent : à vous de trancher et de le justifier dans la PR.

---

## 1.4 Job `front` et artefact `front-dist` (15 min)

Ajoutez un job **`front`** : lint, Prettier, tests, build, puis conservez `front/dist/` comme artefact nommé
**`front-dist`** (7 jours de rétention). L'artefact doit faire **échouer** le job s'il est vide.

Indices : `actions/upload-artifact@v7`, `path:` (relatif à la racine : `upload-artifact` ignore `working-directory`),
`retention-days`, `if-no-files-found: error`.

**Résultat attendu** : en bas de la page du run, rubrique *Artifacts* : `front-dist`, téléchargeable ; le zip contient
`index.html` et `assets/`.

---

## 1.5 Couverture de tests et seuil bloquant (25 min)

Le starter fournit `npm run test:coverage` (Vitest + `@vitest/coverage-v8`) : il écrit un tableau dans la console et
un résumé machine dans `coverage/coverage-summary.json`. Objectif : dans le job `api`,

1. afficher un **tableau de couverture** (lignes, instructions, fonctions, branches) dans le **résumé du run**
   (`$GITHUB_STEP_SUMMARY`, Markdown) ;
2. **échouer** si la couverture des lignes est inférieure à un seuil `COVERAGE_MIN` défini **une fois**, dans `env:` au
   niveau du workflow, avec une annotation lisible sur la PR.

Choisissez le seuil (la couverture actuelle est d'environ 81 %) et justifiez-le dans la description de la PR.

Briques utiles :

```bash
jq -r '.total.lines.pct' coverage/coverage-summary.json        # 80.99
echo "| lines | 80.99 % |" >> "$GITHUB_STEP_SUMMARY"            # une ligne de Markdown dans le résumé
echo "::error title=Couverture insuffisante::lignes 62 % < 75 %"  # annotation rouge sur la PR
awk -v p=62 -v min=75 'BEGIN { exit !(p < min) }' && echo "sous le seuil"   # comparer des décimaux en shell
```

**Résultat attendu** : sur la page du run, onglet *Summary* : « Couverture de l'API (Node 20) » et « (Node 22) » avec un
tableau ; le job reste vert. Testez le seuil **en local** en simulant le résumé GitHub :

```bash
cd api && npm run test:coverage >/dev/null
export GITHUB_STEP_SUMMARY=/tmp/summary.md COVERAGE_MIN=90
# collez ici le script de votre step, puis :
cat /tmp/summary.md; echo "code de sortie : $?"
```

> **Si ça ne marche pas**
> - `jq: error: Could not open file coverage/coverage-summary.json` : le reporter `json-summary` n'est pas actif
>   (`api/vitest.config.js`), ou le step ne tourne pas dans `api/`.
> - Le job reste vert sous le seuil : votre comparaison ne fait pas `exit 1` ; testez-la en local avec `COVERAGE_MIN=90`.

> **Questions de justification**
> - Pourquoi un seuil sur les **lignes** des tests **unitaires**, alors que `db.js` et `postgres.js` ne sont couverts que
>   par les tests d'intégration ? Que faudrait-il pour mesurer une couverture **globale** ?
> - Pourquoi `src/server.js` est-il exclu de la mesure (`api/vitest.config.js`) ? Est-ce de la triche ?
> - Le front affiche ~28 % : faut-il lui imposer le même seuil ? (indice : que contient `main.js` ?)

---

## 1.6 Optimiser : `concurrency`, `paths`, durées (15 min)

1. **`concurrency`** : un nouveau push sur une PR doit annuler le run devenu inutile ; sur `main`, on n'annule **jamais**
   (chaque commit de `main` doit avoir son verdict : c'est lui qui sera livré demain). Indice :
   `cancel-in-progress: ${{ github.event_name == 'pull_request' }}` et un `group` qui distingue les PR.
2. **`paths-ignore`** : ne pas relancer toute la CI sur `main` pour un commit qui ne touche que `**.md` ou `docs/**`.
   **Où** mettre ce filtre ? Relisez l'exercice 2.3, question 11, avant de répondre.
3. **Cache** : ouvrez le log d'un run « froid » et d'un run « chaud » du job `api` : comparez la durée du step `npm ci`
   et repérez `Cache restored successfully`. Notez les deux durées dans la PR.

**Résultat attendu** : deux pushs rapprochés sur la PR → le premier run est *Cancelled* ; une PR qui ne modifie que le
README lance **quand même** les checks requis.

---

## 1.7 Rendre les checks obligatoires, puis casser volontairement (25 min)

### a. Mettre à jour le ruleset

Les checks n'existent qu'après un premier run : c'est le cas maintenant. Ajoutez une règle `required_status_checks` à
`protection-main`. Récupérez l'`id` (`gh api repos/{owner}/taskflow/rulesets --jq '.[] | "\(.id) \(.name)"'`), copiez
`~/ruleset-main.json` (étape 0 : règles du TP 1, squash uniquement) en `~/ruleset-main-v2.json` et **ajoutez** dans `rules`
(sans rien retirer : un `PUT` remplace toute la liste) :

```json
{
  "type": "required_status_checks",
  "parameters": {
    "strict_required_status_checks_policy": true,
    "required_status_checks": [
      { "context": "api (20)", "integration_id": 15368 },
      { "context": "api (22)", "integration_id": 15368 },
      { "context": "api-integration", "integration_id": 15368 },
      { "context": "front", "integration_id": 15368 }
    ]
  }
}
```

```bash
gh api -X PUT "repos/{owner}/taskflow/rulesets/<id>" --input ~/ruleset-main-v2.json --jq '.rules[].type'
```

> **Questions de justification**
> - `integration_id: 15368` est l'identifiant de l'application *GitHub Actions*. Que se passerait-il sans lui, si un
>   autre outil (ou un script avec un jeton) publiait un statut nommé `front` en vert ?
> - `strict_required_status_checks_policy: true` = « la branche doit être à jour avec `main` ». Quel lien avec le rebase
>   de ce matin ? Quel coût pour une équipe nombreuse ?
> - Pourquoi ne pas exiger `docker-build` ?

### b. Fusionner la PR `feature/ci`

Sortez la PR du mode brouillon (`gh pr ready`), demandez la revue du binôme (`gh pr edit --add-reviewer <binome>`). Le
binôme relit **le workflow** (droits, déclencheurs, noms des jobs) et approuve. Fusionnez (*Squash and merge* : vérifiez
que le titre de la PR est un message conventionnel, par exemple `ci: pipeline d'intégration continue`).

**Résultat attendu** : un run CI démarre sur `main` (push) et passe au vert.

### c. La PR volontairement cassée (deux scénarios)

```bash
git switch main && git pull && git switch -c test/pr-cassee
```

1. **Un test qui échoue** : dans `api/tests/app.test.js`, test « crée une tâche et répond 201 », remplacez
   `toBe(201)` par `toBe(200)`. Commit, push, PR.
   **Attendu** : `api (20)` et `api (22)` rouges ; *Merging is blocked — Required status checks must pass* ; dans le log :
   `AssertionError: expected 201 to be 200`. Corrigez, poussez : tout repasse au vert.
2. **Des tests supprimés** : « ce fichier de tests est trop long, on le supprime » — `git rm api/tests/app.test.js`.
   Commit, push.
   **Attendu** : les tests **passent** (`10 passed`), mais la couverture tombe à environ **37 %** : step de couverture
   rouge, annotation *Couverture insuffisante*, merge bloqué. C'est exactement le rôle du seuil.

Remettez le fichier (`git restore --source=main api/tests/app.test.js`), vérifiez le vert, puis **fermez** la PR sans la
fusionner et supprimez la branche.

> **Si ça ne marche pas**
> - Le bouton *Merge* reste actif malgré le rouge : le ruleset n'a pas la règle (`gh api .../rulesets/<id> --jq
>   '.rules[].type'`), ou vous êtes dans `bypass_actors`.
> - La PR affiche *Expected — Waiting for status to be reported* : un nom de check du ruleset ne correspond à aucun job
>   (`api` au lieu de `api (20)`, faute de frappe). Corrigez le ruleset, pas le workflow.

### d. Première version : tag annoté et release GitHub (5 min)

`main` a maintenant une CI verte : c'est la première version « livrable » de TaskFlow. SemVer : on démarre en `0.x`
tant que l'API peut encore changer.

```bash
git switch main && git pull
git tag -a v0.1.0 -m "v0.1.0 : TaskFlow avec intégration continue"
git push origin v0.1.0
gh release create v0.1.0 --title "v0.1.0" --generate-notes
```

**Résultat attendu** : la release liste la PR `ci: pipeline d'intégration continue` (le titre squashé). Aucun workflow ne
se déclenche sur le tag : pourquoi ? (exercice 2.3, situation 10). Au Jour 3, les images seront étiquetées par SHA court.

---

## 1.8 Comparer : le même pipeline en Jenkins et en GitLab CI (40 min)

Dans `ci-autres-outils/` (nouvelle branche `feature/ci-autres-outils`), écrivez :

- `Jenkinsfile` : pipeline **déclaratif**, chaque étape dans un conteneur `node:XX-alpine` ; matrice Node 20/22 pour
  l'API ; Postgres lancé par le pipeline lui-même (plugin *Docker Pipeline*) ; artefact `front/dist/**` archivé ;
  `timeout`, annulation du build précédent ;
- `.gitlab-ci.yml` : stages, `parallel: matrix`, `services:` (attention à l'adresse de la base), cache npm par lockfile,
  artefact `front-dist`, `rules` équivalentes aux déclencheurs, `interruptible`.

Pas assez à l'aise ? Commencez par l'exercice [2.5](../../exercices/jour2/05-traduire-gha-gitlab-jenkins.md) (plus petit),
et appuyez-vous sur le **tableau de correspondance** des slides (bloc 3.3).

**Validation** (au moins une par fichier) :

| Fichier | Sans rien installer | En local |
|---|---|---|
| `.gitlab-ci.yml` | gitlab.com > *Build > Pipeline editor* > *Validate* | `cp ci-autres-outils/.gitlab-ci.yml .` puis `npx -y gitlab-ci-local@4 --list` (et sans `--list` pour l'exécuter, Docker requis) ; ne commitez pas la copie |
| `Jenkinsfile` | linter du Jenkins du formateur (adresse donnée en séance) | `KEEP=1 bash demos/demo-jenkins-gitlab/demo.sh` puis `curl ... /pipeline-model-converter/validate` (commande dans l'exercice 2.5) |

**Résultat attendu** : les deux fichiers validés ; dans la description de la PR, **trois** différences qui vous ont
surpris entre les outils.

> **Si ça ne marche pas**
> - GitLab : `DATABASE_URL` en `localhost` → le job tourne **dans** un conteneur : utilisez l'alias du service.
> - Jenkins : `"matrix" or "parallel" cannot be nested inside another "matrix" or "parallel"` → sortez la matrice
>   du `parallel` (un stage à part), ou bouclez dans un `script { }`.
> - Jenkins : `EACCES: permission denied, mkdir '/.npm'` → `environment { npm_config_cache = '/tmp/.npm' }`.

---

## Questions de réflexion (à préparer pour le débrief)

1. Votre `ci.yml` met combien de temps entre le push et le verdict ? Quel job est le chemin critique ? Que changeriez-vous
   pour passer sous les 3 minutes, et à quel prix ?
2. Le job `api` sur Node 22 coûte des minutes à chaque PR. Quand cesser de le lancer sur les PR (et le garder sur `main`
   ou en `schedule`) ?
3. Pourquoi `pull_request` teste-t-il le **commit de fusion simulé** (`refs/pull/N/merge`) plutôt que la tête de la
   branche ? Quel lien avec *Require branches to be up to date* ?
4. Les actions sont référencées par tag (`@v7`). Quel risque si le propriétaire de l'action déplace ce tag ? (réponse
   complète au Jour 3 : épinglage par SHA, Dependabot)
5. Pour une équipe qui découvre la CI, que recommandez-vous : GitHub Actions, GitLab CI ou Jenkins ? Trois arguments.

---

## Je valide avec le formateur

- [ ] `ci.yml` : jobs `api` (matrice 20/22), `api-integration` (service Postgres, healthcheck), `front` (artefact `front-dist`) ; `permissions: contents: read` ; actionlint ne dit rien.
- [ ] Le résumé du run affiche la couverture ; `COVERAGE_MIN` est défini une seule fois ; j'explique mon seuil.
- [ ] `concurrency` annule les runs dépassés des PR, jamais ceux de `main` ; `paths-ignore` n'est **que** sur `push`.
- [ ] Le ruleset exige `api (20)`, `api (22)`, `api-integration`, `front` (avec `integration_id`) ; la PR `feature/ci` a été relue et approuvée par le binôme.
- [ ] J'ai vu les deux PR cassées bloquées (test rouge ; couverture sous le seuil), puis vertes.
- [ ] Tag annoté `v0.1.0` poussé et release GitHub publiée avec notes générées.
- [ ] `ci-autres-outils/Jenkinsfile` et `.gitlab-ci.yml` validés, PR ouverte avec trois différences commentées.

## Bonus pour les rapides

- **Job `docker-build`** (`needs` sur les trois autres) : `docker/setup-buildx-action@v4` + `docker/build-push-action@v7`
  avec `push: false` et le cache `type=gha` ; comparez la durée du deuxième run.
- **Badge** CI en tête du `README.md` (`https://github.com/<vous>/taskflow/actions/workflows/ci.yml/badge.svg`).
- **actionlint dans la CI** : un job déclenché seulement quand `.github/workflows/**` change… et qui ne doit pas être
  requis (pourquoi ?).
- **Lancer le `Jenkinsfile` pour de vrai** dans le Jenkins de la démo, en pointant `TASKFLOW_REPO_URL` vers votre dépôt.
- **Filtrer les PR intelligemment** : un job « détecteur » (`dorny/paths-filter`) et des `if:` sur les jobs coûteux, sans
  bloquer les checks requis (un job **sauté** compte comme réussi). Attention au piège des matrices sautées.

Solution de référence (à ouvrir **après**) : [`solution/.github/workflows/ci.yml`](solution/.github/workflows/ci.yml),
[`solution/ci-autres-outils/`](solution/ci-autres-outils/README.md).

# Exercice 2.5 — Traduire un workflow GitHub Actions en GitLab CI et en Jenkins

| | |
|---|---|
| **Durée** | 25 min (GitLab 10 min, Jenkins 15 min) |
| **Bloc** | 3.3 — Jenkins et GitLab CI |
| **Quand** | en ouverture de la partie « Comparer » du TP (étape 1.8), ou en travail personnel |
| **Prérequis** | slides du bloc 3.3 ; tableau de correspondance [`tp/fil-rouge-taskflow/solution/ci-autres-outils/README.md`](../../tp/fil-rouge-taskflow/solution/ci-autres-outils/README.md) (autorisé : c'est un dictionnaire, pas un corrigé) |
| **Fichier fourni** | [`traduire/ci-catalogue.yml`](traduire/ci-catalogue.yml) |

## Situation

Votre équipe reprend le service **catalogue** d'une autre équipe. Il a une CI GitHub Actions, mais le client héberge son code sur **GitLab**, et la DSI exploite un **Jenkins** pour les projets historiques. Vous devez fournir les deux traductions, **à comportement égal**.

Lisez `ci-catalogue.yml` : déclencheurs, `concurrency`, 3 jobs (`lint`, `test` en matrice Node 20/22 avec un service Redis, `build` qui attend les deux autres et conserve `dist/`), des `timeout-minutes`, le cache npm.

## Consignes

### Partie A — `.gitlab-ci.yml` (10 min)

1. Écrivez `.gitlab-ci.yml` : deux stages, les mêmes jobs, la même matrice, le service Redis, le cache, l'artefact, les durées maximales, l'annulation des pipelines dépassés.
2. Attention à l'adresse de Redis : le job GitLab tourne **dans un conteneur**.
3. Validez :
   - **sans rien installer** : sur gitlab.com, *Build > Pipeline editor*, collez le fichier, onglet *Validate* puis *Visualize* ;
   - **ou en local** (Node requis) : dans un dossier qui est un dépôt Git contenant votre fichier, `npx -y gitlab-ci-local@4 --list` doit lister `lint`, `test: [20]`, `test: [22]`, `build`.

### Partie B — `Jenkinsfile` (15 min)

4. Écrivez un `Jenkinsfile` **déclaratif** : `lint` et `test` en parallèle, puis `build` ; chaque étape dans un conteneur `node` ; l'artefact archivé ; les `timeout`.
5. Le service Redis n'existe pas en Jenkins : lancez-le vous-même (plugin *Docker Pipeline* : `docker.image(...).withRun(...)`), et pensez au ménage.
6. Validez avec le **linter déclaratif** du Jenkins de la démo (`demos/demo-jenkins-gitlab/`, lancé par le formateur ou chez vous avec `KEEP=1`) :

   ```bash
   J=http://localhost:8090
   CRUMB=$(curl -s -u admin:admin -c /tmp/jk "$J/crumbIssuer/api/json" | jq -r '.crumbRequestField+":"+.crumb')
   curl -s -u admin:admin -b /tmp/jk -H "$CRUMB" -X POST -F "jenkinsfile=<Jenkinsfile" "$J/pipeline-model-converter/validate"
   # → « Jenkinsfile successfully validated. »
   ```

### Partie C — Comparer (à rendre en 5 lignes)

7. Ce qui s'est traduit **mot pour mot**, ce qui a demandé du code en plus, ce qui n'a **pas** d'équivalent direct.
8. Lequel des trois fichiers préféreriez-vous maintenir, et pourquoi ?

## Résultat attendu

- `.gitlab-ci.yml` validé (Pipeline editor ou `gitlab-ci-local --list`) ; `REDIS_URL` pointe vers l'alias du service.
- `Jenkinsfile` validé par le linter ; Redis démarré et supprimé par le pipeline lui-même.
- Votre paragraphe de comparaison.

## Indices

<details>
<summary>Indice 1 — GitLab</summary>

`stages:` + `stage:` dans chaque job ; `parallel: matrix:` ; `services: - name: redis:7-alpine` + `alias: redis` ; `cache: key: files: [package-lock.json]` avec `npm ci --cache .npm` ; `artifacts: paths:` + `expire_in:` ; `interruptible: true` + `workflow: auto_cancel: on_new_commit: interruptible`. Le job `build` dans un stage **suivant** remplace `needs`.
</details>

<details>
<summary>Indice 2 — Jenkins</summary>

`pipeline { agent none; stages { stage('verify') { parallel { ... } } stage('build') { ... } } }` ; dans chaque stage, `agent { docker { image 'node:22-alpine' } }` ; `options { timeout(time: 5, unit: 'MINUTES') }` ; `post { success { archiveArtifacts artifacts: 'dist/**' } }` ; `environment { npm_config_cache = '/tmp/.npm' }` (dans le conteneur, Jenkins n'est pas root et `HOME` n'est pas inscriptible).
</details>

<details>
<summary>Indice 3 — Redis et la matrice dans Jenkins</summary>

Une directive `matrix` ne peut pas être placée **dans** un `parallel`. Deux options : sortir `test` du `parallel` et en faire un stage `matrix` (mais alors `lint` ne tourne plus en même temps), ou garder le `parallel` et boucler sur `['20', '22']` dans un bloc `script { }`. Pour Redis : `docker network create`, `withRun("--network <net> --network-alias redis")`, `inside("--network <net>")`, puis `docker network rm` dans un `finally`.
</details>

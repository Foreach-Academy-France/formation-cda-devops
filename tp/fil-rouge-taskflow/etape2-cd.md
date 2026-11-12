# Étape 2 : déploiement continu (CD)

> **Quand** : Jour 3, après-midi | **Durée** : 3h30 (A : 1h, B : 1h30, C : 45 min, débrief : 15 min)
> **Objectif** : un merge sur `main` construit les images, les **scanne**, les publie, déploie **staging**
> automatiquement puis **production après approbation** ; un rollback se fait en un clic ; aucun secret n'est dans Git.

On n'automatise que ce qu'on sait faire à la main : la partie A fait chaque geste une fois, la partie B les confie au
pipeline, la partie C prouve qu'on sait revenir en arrière.

---

## Prérequis (état attendu en début d'étape)

- Étape 1 terminée : `ci.yml` vert sur `main` (jobs `api`, `api-integration`, `front`) ; ruleset sur `main`
  (PR + 1 revue + checks requis).
- Slides du Jour 3 (blocs 4.1 à 4.3 et 7.1) et exercices 3.2 (Nginx) et 3.3 (secrets) faits ce matin.
- Docker avec le plugin Compose **v2.17 ou plus** (`docker compose version`), `openssl` (sinon `gen-cert.sh` passe par
  un conteneur), `jq`, `gh` (facultatif).
- Ports : 8081 (staging) libre ; 80 et 443 libres **ou** 8082 et 8443 (`ss -ltn | grep -E ':(80|443|8081|8082|8443)\b'`).
  8080 reste à la stack de dev.
- Variable pratique pour la suite :
  ```bash
  export FORMATION=~/formation-cda-devops           # votre clone du dépôt de cours (adaptez)
  export SOL=$FORMATION/tp/fil-rouge-taskflow/solution
  ```

## Ce que vous allez construire

```
                              GitHub (cloud)
  merge sur main ─▶ release.yml
     prepare ─▶ images [api, front] : build ─▶ Trivy (CRITICAL = échec) ─▶ push ghcr.io :<sha> :latest
                                    │
       runner self-hosted (votre poste, conteneur, labels self-hosted,lab) ◀── va chercher les jobs
                                    ▼
     deploy-staging    (environment staging)    ~/taskflow-staging  http://localhost:8081   smoke test
                                    ▼  approbation humaine (required reviewers)
     deploy-production (environment production) ~/taskflow-prod     https://taskflow.localhost smoke test
                                                                    └─ rollback auto si smoke test KO
```

| Dossier (« serveur ») | Projet Compose | Contenu propre à l'environnement (jamais dans Git) |
|---|---|---|
| `~/taskflow-staging` (`STAGING_DIR`) | `taskflow-staging` | `.env` |
| `~/taskflow-prod` (`PROD_DIR`) | `taskflow-prod` | `.env`, `certs/`, `backups/` |

**Choix de conception** (à savoir justifier) : un fichier Compose **par environnement** (`compose.staging.yaml`,
`compose.prod.yaml`) plutôt qu'un seul fichier paramétré. Les deux diffèrent par leur **structure** (la prod a un
proxy TLS, le staging non), pas seulement par des valeurs : un fichier par environnement reste lisible et se relit
en PR. Ce qui ne diffère que par des valeurs (mot de passe, ports, `APP_ENV`) vient du `.env`. Le `deploy.sh` est
commun : il prend le fichier dans `COMPOSE_FILE`.

---

## Partie A. Déploiement manuel de la production (1h)

### A.0 Ajouter les fichiers de déploiement au dépôt (15 min)

```bash
cd ~/taskflow && git switch main && git pull && git switch -c feature/deploiement
cp "$SOL/compose.prod.yaml" "$SOL/compose.staging.yaml" "$SOL/.env.example" "$SOL/.pre-commit-config.yaml" .
cp -r "$SOL/deploy" . && mkdir -p docs && cp "$SOL/docs/DEPLOIEMENT.md" docs/
```

Ajoutez au `.gitignore` : `certs/`, `backups/`, `*.pem`, `*.key`, `*.crt` (le `.env` y est déjà).

**Installez le hook gitleaks avant de créer le moindre `.env`** :

```bash
pipx install pre-commit        # ou : pip install --user pre-commit
pre-commit install
pre-commit run --all-files     # premier passage : télécharge et compile gitleaks
```

Lisez les fichiers et répondez (par écrit, dans la description de la PR) :

| Fichier | Trouvez… |
|---|---|
| `compose.prod.yaml` | le seul service avec `ports:` ; d'où viennent les images ; le rôle de `:?` ; pourquoi le réseau par défaut est **nommé** |
| `compose.staging.yaml` | les trois différences structurelles avec la prod ; pourquoi les noms de conteneurs et de volume sont fixés |
| `deploy/deploy.sh` | où est mémorisée la version précédente ; ce que fait `--wait` ; pourquoi `nginx -s reload` |
| `deploy/smoke-test.sh` | les trois conditions vérifiées ; pourquoi vérifier la **version** |

```bash
git add . && git commit -m "build: ajoute la configuration de déploiement (staging, prod, scripts)"
git push -u origin feature/deploiement
```

PR, CI verte, revue par votre binôme, merge.

> **Si ça ne marche pas**
> - `pre-commit: command not found` : `pipx ensurepath` puis rouvrez le terminal. Sans Python : le hook
>   `gitleaks-docker` (voir l'en-tête de `.pre-commit-config.yaml`).
> - Le hook bloque un fichier de `deploy/` : lisez la règle (`RuleID`). Un vrai secret ? Retirez-le. Un faux positif ?
>   Notez-le pour le Jour 5 (`.gitleaksignore`).

### A.1 Construire les images à la main (10 min)

C'est exactement ce que fera le job `images` du pipeline : une image par composant, **taguée par le SHA court**.

```bash
cd ~/taskflow && git switch main && git pull
export OWNER=$(gh api user -q .login | tr '[:upper:]' '[:lower:]')   # ou à la main, EN MINUSCULES
export TAG=$(git rev-parse --short=7 HEAD)
docker build -t ghcr.io/$OWNER/taskflow-api:$TAG   --build-arg APP_VERSION=$TAG api
docker build -t ghcr.io/$OWNER/taskflow-front:$TAG front
docker images "ghcr.io/$OWNER/*"
```

**Résultat attendu** : deux images locales `taskflow-api` et `taskflow-front` avec le tag `$TAG`. On ne les pousse
pas : le registre sera alimenté par le pipeline (aucun jeton personnel à manipuler).

### A.2 Préparer le « serveur » de production (10 min)

```bash
mkdir -p ~/taskflow-prod/nginx && cd ~/taskflow-prod
cp ~/taskflow/compose.prod.yaml ~/taskflow/deploy/*.sh . && cp ~/taskflow/deploy/nginx/taskflow.conf nginx/
cp ~/taskflow/.env.example .env && chmod 600 .env
PASS=$(openssl rand -hex 24) && sed -i "s/changez-moi/$PASS/g" .env && unset PASS   # macOS : sed -i ''
nano .env      # GHCR_OWNER=<vous en minuscules> ; ports 8082/8443 si 80/443 indisponibles
./gen-cert.sh
docker compose -f compose.prod.yaml config --quiet && echo "configuration valide"
ls -l .env certs/
```

**Résultat attendu** : `.env` en `-rw-------`, `certs/taskflow.key` en `-rw-------`, `configuration valide`.

> **Pourquoi `openssl rand -hex 24` ?** Long, aléatoire, et uniquement `0-9a-f` : aucun caractère qui casserait
> l'URL de `DATABASE_URL`. Et `unset PASS` : le mot de passe ne traîne pas dans votre shell.

### A.3 Lancer la production (10 min)

```bash
cd ~/taskflow-prod
IMAGE_TAG=$TAG docker compose -f compose.prod.yaml up -d --wait
docker compose -f compose.prod.yaml ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'
echo "$TAG" > .deployed_tag
```

On n'utilise pas encore `deploy.sh` : il commence par `docker compose pull`, et vos images ne sont pas sur ghcr.io.

**Résultat attendu** : quatre services `healthy` ; seul `proxy` a des ports publiés (`0.0.0.0:443->443/tcp`).

> **Si ça ne marche pas**
> - `dependency failed to start: container taskflow-prod-api-1 is unhealthy` : `docker compose -f compose.prod.yaml logs api`.
>   `password authentication failed` : le mot de passe de `DATABASE_URL` diffère de `POSTGRES_PASSWORD`, **ou** un
>   volume `taskflow-prod_pgdata` existait déjà avec un autre mot de passe (Postgres ne lit `POSTGRES_PASSWORD`
>   qu'à la création du volume). Lab seulement : `docker compose -f compose.prod.yaml down -v`.
> - `bind: address already in use` / `permission denied` sur 80 : `HTTP_PORT=8082`, `HTTPS_PORT=8443` dans `.env`.
> - `proxy` redémarre en boucle : `logs proxy` ; souvent `certs/` vide (relancez `./gen-cert.sh`).
> - `unknown flag: --wait` : plugin Compose trop ancien ; mettez Docker à jour.

### A.4 Vérifier (10 min)

```bash
P=${HTTPS_PORT:-443}     # ou 8443
curl -fsS --cacert certs/taskflow.crt https://localhost:$P/health; echo
curl -sI -H 'Host: taskflow.localhost' http://localhost:${HTTP_PORT:-80}/ | grep -iE '^(HTTP|location)'
curl -s --cacert certs/taskflow.crt https://localhost:$P/metrics | head -c 80; echo
```

**Résultat attendu** : `{"status":"ok","db":"up","version":"<TAG>","env":"production"}`, un `301` vers https,
et `/metrics` qui renvoie… la page HTML du front (l'API n'est pas exposée : seuls `/api/` et `/health` sont relayés).

Ouvrez `https://taskflow.localhost` (ou `:8443`) : l'avertissement du navigateur est normal (certificat auto-signé).

Notez que `curl --cacert` **vérifie** le certificat au lieu de l'ignorer (`-k`) : c'est ce que fera le smoke test.

### A.5 Sauvegarder et restaurer (5 min)

Créez deux tâches, puis :

```bash
./backup.sh && ls -lh backups/
docker compose -f compose.prod.yaml exec db psql -U taskflow -d taskflow -c 'DELETE FROM tasks;'
gunzip -c backups/taskflow-*.sql.gz | docker compose -f compose.prod.yaml exec -T db psql -q -U taskflow -d taskflow
docker compose -f compose.prod.yaml exec db psql -U taskflow -d taskflow -c 'SELECT count(*) FROM tasks;'
```

**Résultat attendu** : `count = 2` après restauration.

### Questions de réflexion (partie A)

1. Rangez chaque élément de `~/taskflow-prod` dans **code**, **configuration** ou **données**. Lequel le pipeline
   a-t-il le droit d'écraser ?
2. Le facteur III de 12-factor dit « la configuration dans l'environnement ». Où est-elle ici ? Qu'est-ce qui, dans
   une image, rendrait impossible le *build once, deploy many* ?
3. Qu'est-ce qui distingue l'image qui tourne en ce moment de celle que le pipeline produira pour le même commit ?
   (Indice : où a-t-elle été construite, et qui l'a scannée ?)

---

## Partie B. Pipeline de release (1h30)

### B.1 Préparer le « serveur » de staging (5 min)

```bash
mkdir -p ~/taskflow-staging && cd ~/taskflow-staging
cp ~/taskflow/.env.example .env && chmod 600 .env
PASS=$(openssl rand -hex 24) && sed -i "s/changez-moi/$PASS/g; s/^APP_ENV=.*/APP_ENV=staging/" .env && unset PASS
nano .env      # GHCR_OWNER
```

Le pipeline copiera lui-même `compose.staging.yaml` et les scripts. **Mot de passe différent de la prod** : une fuite
du staging ne doit pas ouvrir la prod.

### B.2 Démarrer le runner self-hosted (15 min)

Suivez [`../../ressources/lab/runner/README.md`](../../ressources/lab/runner/README.md) (jeton d'enregistrement,
`.env` avec `PROD_DIR` et `STAGING_DIR` en chemins **absolus**, `docker compose up -d --build`).

**Résultat attendu** : `lab-runner` **Idle** dans *Settings > Actions > Runners* avec les labels `self-hosted` et `lab` ;
`docker compose exec runner sh -c 'ls "$PROD_DIR" "$STAGING_DIR"'` liste vos deux dossiers ;
`docker compose exec runner tofu version` répond (servira au Jour 4).

**Avant d'aller plus loin** : *Settings > Actions > General > Fork pull request workflows from outside collaborators*
→ **Require approval for all outside collaborators**. Votre dépôt est public et ce runner a l'équivalent d'un accès
root à votre poste (socket Docker).

### B.3 Créer les environments GitHub (10 min)

| Environment | Protection | Variables (seulement si différent du défaut) |
|---|---|---|
| `staging` | aucune | `FRONT_PORT` (défaut 8081) |
| `production` | **Required reviewers** : vous et votre binôme ; **Deployment branches and tags** : *Selected* → `main` ; (option) *Prevent self-review* si votre binôme est relecteur | `HTTPS_PORT` (défaut 443 ; `8443` sinon) |

*Settings > Environments > New environment*. Aucun **secret** à créer : le `GITHUB_TOKEN` du run suffit pour ghcr.io et
les `.env` ne quittent jamais votre poste.

> **Pourquoi des variables d'environment et pas de dépôt ?** Elles ne sont visibles que des jobs qui déclarent cet
> environment. Même logique pour les secrets : un secret de `production` n'est lisible qu'**après** l'approbation.

### B.4 Écrire `release.yml` (40 min)

Créez `.github/workflows/release.yml` sur une branche `feature/release`. **Cahier des charges** :

| # | Exigence |
|---|---|
| 1 | Déclencheurs : `push` sur `main` (en ignorant `docs/**` et `**/*.md`) ; `workflow_dispatch` avec `tag` (texte, vide par défaut) et `environment` (choix `staging` / `production`) |
| 2 | `permissions: {}` au niveau du workflow ; chaque job déclare le strict nécessaire |
| 3 | Job `prepare` : calcule `tag` (SHA court), `owner` (minuscules), et trois booléens `build`, `staging`, `production`. Valide le tag d'un rollback (`^[0-9a-f]{7}$`) et refuse de construire autre chose que `main` |
| 4 | Job `images`, matrice `[api, front]` : build **chargé localement** (pas encore publié) → Trivy, **échec sur CRITICAL corrigeable**, rapport dans `$GITHUB_STEP_SUMMARY` même en cas d'échec → push `:<sha>` et `:latest` |
| 5 | Job `deploy-staging` : `runs-on: [self-hosted, lab]`, `environment: staging`, copie `compose.staging.yaml` + scripts dans `$STAGING_DIR`, `docker login` avec `GITHUB_TOKEN`, `COMPOSE_FILE=compose.staging.yaml ./deploy.sh`, smoke test sur `http://host.docker.internal:8081/health` **avec la version attendue**, `docker logout` dans tous les cas |
| 6 | Job `deploy-production` : `environment: production`, après staging vert ; sauvegarde, `./deploy.sh`, smoke test HTTPS **avec vérification du certificat**, rollback automatique vers `.previous_tag` si le smoke test échoue |
| 7 | Rollback (`tag` saisi) : `images` sauté, seul l'environnement choisi est déployé |
| 8 | Un seul déploiement à la fois **par environnement**, jamais interrompu |
| 9 | Toute action tierce épinglée par **SHA complet** avec la version en commentaire |

**Indices et fragments** (le reste, c'est à vous) :

<details>
<summary>Le plan dans <code>prepare</code> (et l'injection de script)</summary>

```yaml
      - id: plan
        env:                       # JAMAIS ${{ inputs.tag }} directement dans run: (injection de script)
          INPUT_TAG: ${{ inputs.tag }}
          INPUT_ENV: ${{ inputs.environment }}
        run: |
          echo "owner=${GITHUB_REPOSITORY_OWNER,,}" >> "$GITHUB_OUTPUT"
          if [ "$GITHUB_EVENT_NAME" = "push" ] || [ -z "$INPUT_TAG" ]; then
            ...   # tag=${GITHUB_SHA::7}, build=true, staging=true, production=true
          else
            ...   # valider "$INPUT_TAG", build=false, un seul environnement à true
          fi
```
</details>

<details>
<summary>Faire tourner un job dont un « needs » a été sauté</summary>

Par défaut, un job est sauté si un job dont il dépend l'a été. `!cancelled()` lève cette règle ; on teste alors
soi-même les résultats :

```yaml
    if: >-
      !cancelled()
      && needs.prepare.outputs.staging == 'true'
      && (needs.images.result == 'success' || needs.images.result == 'skipped')
```
</details>

<details>
<summary>Trivy sur une image locale</summary>

`docker/build-push-action` avec `load: true` et `push: false` met l'image dans le Docker du runner ;
`aquasecurity/trivy-action` la scanne avec `image-ref`, `severity: CRITICAL`, `ignore-unfixed: true`,
`exit-code: "1"`, `format: table`, `output: <fichier>`. Un step `if: ${{ !cancelled() }}` recopie le fichier dans
`$GITHUB_STEP_SUMMARY`. On pousse ensuite **cette** image (`docker push`) : celle qui a été scannée.
</details>

<details>
<summary>Récupérer le SHA d'une action pour l'épingler</summary>

```bash
git ls-remote https://github.com/aquasecurity/trivy-action 'refs/tags/v0.36.0^{}' 'refs/tags/v0.36.0'
```
Pour un tag annoté, prenez la ligne `^{}` (le commit), pas l'objet tag.
</details>

<details>
<summary>Le runner et ses variables</summary>

`$PROD_DIR` et `$STAGING_DIR` sont des variables **du processus du runner** : utilisables dans `run:`
(`cd "$STAGING_DIR"`), mais **pas** dans `${{ env.STAGING_DIR }}` (le contexte `env` ne contient que ce que le YAML
déclare). Le smoke test vise `host.docker.internal` : le runner est un conteneur, `localhost` serait lui-même.
</details>

Validez localement avant de pousser :

```bash
docker run --rm -v "$PWD":/repo -w /repo docker.io/rhysd/actionlint:latest -no-color
```

(`.github/actionlint.yaml` déclare déjà le label `lab`.) Raccourci si vous êtes en retard :
`cp "$SOL/.github/workflows/release.yml" .github/workflows/` puis **lisez-le** et comparez avec votre version.

PR, CI verte, revue, merge. Ouvrez l'onglet **Actions**.

### B.5 Le premier run : rouge, et c'est normal (15 min)

Il est très probable que le job `images` échoue au step Trivy : les images de base du starter (`node:20-alpine`,
`nginx:1.27-alpine`) contiennent des vulnérabilités **CRITICAL** pour lesquelles un correctif existe. Rien n'est
publié, rien n'est déployé : le contrôle fonctionne.

1. Lisez le **résumé** du run : paquet, CVE, version installée, version corrigée. D'où vient chaque paquet (image de
   base ? dépendance npm de l'application ? outil embarqué dans l'image) ?
2. Corrigez dans une PR `fix/images-vulnerables`. Pistes, à justifier :
   - front : image de base plus récente **et** `RUN apk upgrade --no-cache` (une image officielle a souvent des
     correctifs Alpine publiés mais pas encore reconstruits) ;
   - api : si la CVE est dans `npm` lui-même (`/usr/local/lib/node_modules/npm`), l'image de production n'a pas
     besoin de npm : supprimez-le après `npm ci --omit=dev`.
   Vérifiez **avant** de pousser :
   ```bash
   docker build -t tf-api:test api
   docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker.io/aquasec/trivy:0.76.2 image --quiet \
     --severity CRITICAL --ignore-unfixed --exit-code 1 tf-api:test && echo "vert" || echo "encore rouge"
   ```
   (Trivy lit l'image dans votre Docker par le socket. Même chose avec `front`.)
3. Merge : le run reprend. `images` vert, `deploy-staging` s'exécute sur **votre** runner, puis `deploy-production`
   affiche **Waiting for review**. Vérifiez staging (`curl -s http://localhost:8081/health`) **avant** d'approuver
   (*Review deployments > Approve and deploy*).

**Résultat attendu** : dans le résumé, le plan, deux rapports Trivy sans CRITICAL, `Publié : ghcr.io/...:<sha>` ; le
smoke test de production affiche `Smoke test OK ... "version":"<sha>","env":"production"`. Sur la page du dépôt,
*Deployments* liste `staging` et `production` avec leurs URL.

> **Si ça ne marche pas**
> - `deploy-staging` reste *Queued* : runner *Offline*, ou labels différents de `[self-hosted, lab]`.
> - `STAGING_DIR absent ou sans .env` : B.1 pas fait, ou chemin du `.env` du runner faux.
> - `denied` au `pull` : paquet privé non lié au dépôt. Page du paquet > *Package settings* > *Manage Actions access*
>   > ajoutez `taskflow` (rôle *Read*). Faites-le pour les deux paquets.
> - Smoke test `Failed to connect to host.docker.internal port 443` : variable `HTTPS_PORT` de l'environment
>   `production` manquante (vous êtes en 8443).
> - Smoke test `SSL certificate problem` : `certs/taskflow.crt` a été généré sans `host.docker.internal` dans le SAN ;
>   `FORCE=1 ./gen-cert.sh` puis `docker compose -f compose.prod.yaml restart proxy`.
> - `deploy-production` sauté alors que staging est vert : relisez sa condition `if:` (les trois `needs`).
> - Le job prod échoue sur `Deployment branches` : vous avez lancé le workflow depuis une autre branche que `main`.

### B.6 La preuve : une modification arrive seule en production (5 min)

Changez le titre dans `front/index.html` (PR, merge). Mesurez avec l'horodatage des runs :

| Jalon | Heure |
|---|---|
| merge de la PR | |
| fin de `deploy-staging` | |
| approbation | |
| fin de `deploy-production` | |

Ce délai, c'est le **lead time for changes** de DORA (ici, sans le temps de revue). Gardez-le pour le débrief.

### Questions de réflexion (partie B)

1. Retirez les *required reviewers* de `production` : qu'est-ce qui change dans le YAML ? Dans l'organisation de
   l'équipe ? Qu'est-ce qui devrait exister **avant** de franchir ce pas (tests, monitoring, rollback auto) ?
2. Pourquoi publier l'image **après** le scan plutôt que l'inverse ? Pourquoi `:latest` est-il dangereux pour
   déployer, alors qu'on le publie quand même ?
3. Le job `images` tourne chez GitHub, les déploiements chez vous. Pourquoi ne pas tout faire sur le runner self-hosted ?
4. Le runner est persistant. Citez deux choses qu'un job peut laisser au job suivant, et ce que fait `release.yml` contre.

---

## Partie C. Rollback et Dependabot (45 min)

### C.1 Dependabot (10 min)

```bash
git switch main && git pull && git switch -c chore/dependabot
mkdir -p .github && cp "$SOL/.github/dependabot.yml" .github/
```

Lisez-le : quatre écosystèmes (npm × 2 dossiers, docker × 2, github-actions). Merge, puis *Insights > Dependency graph >
Dependabot* : les premières PR arrivent dans les minutes qui suivent. Activez aussi *Settings > Code security >
Dependabot alerts* et *Dependabot security updates*.

> **Question** : une PR Dependabot qui monte `aquasecurity/trivy-action` modifie un SHA de 40 caractères. Comment
> savez-vous que le nouveau SHA est légitime ? (Release notes, tag signé, *immutable releases*, délai avant de fusionner.)

### C.2 Casser une release (10 min)

Une erreur de configuration qui passe le lint et les tests : dans `front/nginx.conf`, changez le port de l'API.

```nginx
    set $api_upstream http://api:3001;
```

PR (la CI est **verte** : aucun test ne lit `nginx.conf`), merge.

**Résultat attendu** : `images` vert, `deploy-staging` **rouge** au smoke test (`502` sur `/health`),
`deploy-production` **sauté**. La production n'a jamais vu cette version : c'est **le rôle du staging**.
Notez le SHA cassé (`cat ~/taskflow-staging/.deployed_tag`).

### C.3 Rollback du staging en un clic (5 min)

Staging est cassé. Revenez à la version précédente **sans rien reconstruire** :

```bash
cat ~/taskflow-staging/.previous_tag
gh workflow run release.yml -f tag=<sha-précédent> -f environment=staging
```

(ou *Actions > Release > Run workflow*). **Résultat attendu** : `images` sauté (gris), `deploy-staging` vert,
`deploy-production` sauté ; `curl -s http://localhost:8081/health` affiche l'ancienne version.

### C.4 Roll forward (10 min)

Le rollback a rétabli le service ; `main` contient toujours l'erreur. Corrigez-la **par une PR** :
`git revert <sha-du-merge-cassé>` (ou correction du port), PR, merge. Le pipeline livre une **nouvelle** version
saine sur staging puis, après approbation, en production.

> **Rollback ou roll forward ?** Le rollback est la réponse **immédiate** (minutes, sans réfléchir) ; le roll forward
> est la réponse **durable**. Le rollback est impossible si la version N a fait une migration de base que N-1 ne
> comprend pas : d'où la règle *expand/contract*.

### C.5 Le filet de la production (10 min)

Que se passe-t-il si une version cassée atteint quand même la production ? Simulez-le en forçant le SHA cassé de C.2 :

```bash
gh workflow run release.yml -f tag=<sha-cassé> -f environment=production
```

Approuvez, puis lisez le job : le smoke test échoue, le step **Rollback automatique** redéploie `.previous_tag`, le
job reste **rouge**. **Résultat attendu** : `curl -s --cacert ~/taskflow-prod/certs/taskflow.crt https://localhost:${HTTPS_PORT:-443}/health`
renvoie la version saine.

> Pourquoi laisser le job rouge alors que le service est rétabli ? Parce qu'un incident a eu lieu : il doit être vu,
> analysé (post-mortem au Jour 4), et sa cause corrigée.

---

## Débrief (15 min)

- Lead time mesuré en B.6 : où passe le temps ? Que coûterait le passage au déploiement continu ?
- Les 4 métriques DORA : laquelle ce pipeline améliore-t-il directement ? (fréquence, lead time ; et le **temps de
  restauration** grâce au rollback par tag.) Laquelle mesure-t-on au Jour 4 avec le monitoring ?
- Qu'est-ce qui, dans ce pipeline, est « sécurité » ? (scan d'image, permissions minimales, actions épinglées, entrées
  validées, secrets hors Git, logout du registre, approbation, branches de déploiement restreintes.)

---

## Checklist de validation (ce que le formateur vérifie)

- [ ] `.pre-commit-config.yaml` présent ; `pre-commit install` fait ; aucun secret dans l'historique (`gitleaks git .`)
- [ ] `~/taskflow-prod/.env` et `~/taskflow-staging/.env` en `600`, mots de passe différents
- [ ] Runner `lab-runner` Idle ; approbation des workflows de forks exigée
- [ ] Environments `staging` (libre) et `production` (*required reviewers*, branche `main` seulement)
- [ ] `release.yml` : `permissions: {}` + permissions par job ; actions tierces épinglées par SHA ; actionlint propre
- [ ] Un run complet : Trivy dans le résumé, staging puis production après approbation, smoke tests verts
- [ ] `http://localhost:8081/health` et `https://taskflow.localhost/health` affichent le **même** SHA, `env` différent
- [ ] Rollback de staging fait par `workflow_dispatch` ; release cassée stoppée au staging
- [ ] `.github/dependabot.yml` présent, au moins une PR Dependabot ouverte
- [ ] Je sais expliquer : livraison continue vs déploiement continu ; build once deploy many ; pourquoi le socket Docker est dangereux

## Bonus pour les rapides

1. **Blue/green de la prod** : deux projets `taskflow-blue` / `taskflow-green` sur le réseau `taskflow-prod`, le proxy
   bascule de l'un à l'autre par `nginx -s reload` ; mesurez la coupure avec
   `while true; do curl -s -o /dev/null -w '%{http_code}\n' --cacert certs/taskflow.crt https://localhost:$P/health; sleep 0.2; done`
   pendant un déploiement classique, puis pendant une bascule.
2. **Release GitHub** : à chaque déploiement de production réussi, créer un tag `prod-<date>-<sha>` et une release
   avec les notes générées (`gh release create --generate-notes`). Quelles permissions faut-il ajouter, à quel job ?
3. **SBOM** : `trivy image --format cyclonedx` dans le job `images`, publié en artefact. À quoi sert-il le jour où une
   nouvelle CVE critique est annoncée sur une bibliothèque ?
4. **zizmor** : `pipx run zizmor .github/workflows/` ; triez ce qu'il remonte sur vos workflows.

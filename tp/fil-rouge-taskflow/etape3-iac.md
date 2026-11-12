# Étape 3 : le staging en Infrastructure as Code

> **Quand** : Jour 4, début d'après-midi | **Durée** : 1h (A : 25 min, B : 15 min, C : 20 min)
> **Objectif** : l'environnement **staging** de TaskFlow n'est plus un `compose.staging.yaml` copié sur le poste : il
> est **décrit en code** (OpenTofu, dossier `infra/`), son state vit hors de Git, chaque PR qui touche `infra/` affiche
> son **plan**, et le pipeline de release l'applique.

Ce matin, vous avez manipulé un Nginx (exercices 4.1 à 4.3). Même outil, même provider, mais cette fois sur un vrai
environnement **qui contient des données** : on va devoir les garder.

---

## Prérequis (état attendu en début d'étape)

- Étape 2 terminée : `release.yml` déploie staging (`~/taskflow-staging`, http://localhost:8081) puis production.
- Le runner du lab tourne, avec `STAGING_DIR` et `PROD_DIR` montés au même chemin que sur le poste, et **`tofu`** dans
  son image (`docker exec taskflow-runner tofu version`). Sinon : reconstruire le runner (`ressources/lab/runner`,
  `docker compose up -d --build`).
- Sur le poste : `tofu version` ≥ 1.6 (exercices du matin).
- Variables pratiques (comme à l'étape 2) :
  ```bash
  export FORMATION=~/formation-cda-devops
  export SOL=$FORMATION/tp/fil-rouge-taskflow/solution
  export STAGING_DIR=~/taskflow-staging
  ```

## Ce que vous allez construire

```
taskflow/
├── infra/
│   ├── versions.tf                 required_providers (docker, random) + backend "local" (chemin donné à l'init)
│   ├── providers.tf                provider docker (+ authentification ghcr.io si un jeton est fourni)
│   ├── variables.tf                ghcr_owner, image_tag, front_port, environment, db_password, ghcr_*
│   ├── main.tf                     réseau, volume, mot de passe, 3 images, 3 conteneurs
│   ├── outputs.tf                  url, health_url, image_tag, containers, network
│   ├── ci-env.sh                   variables TF_VAR_* pour les jobs (owner en minuscules, tag courant, mot de passe)
│   ├── terraform.tfvars.example
│   └── .terraform.lock.hcl         VERSIONNÉ (versions et empreintes des providers)
└── .github/workflows/
    ├── iac.yml                     PR sur infra/** : fmt -check, validate, plan publié dans la PR
    └── release.yml                 job deploy-staging : plan -out puis apply, smoke test

~/taskflow-staging/terraform.tfstate     le state : HORS du dépôt (il contient le mot de passe de la base)
```

| Ressource OpenTofu | Objet Docker (mêmes noms qu'à l'étape 2) |
|---|---|
| `docker_network.this` | réseau `taskflow-staging` |
| `docker_volume.pgdata` | volume `taskflow-staging-pgdata` (**importé**, pas recréé) |
| `docker_container.db` / `.api` / `.front` | `taskflow-staging-db` / `-api` / `-front` (front sur `var.front_port` = 8081) |

---

## Partie A. Décrire le staging (25 min)

### A.1 Le squelette

```bash
cd ~/taskflow && git switch main && git pull && git switch -c feature/infra-staging
mkdir infra && cd infra
```

Écrivez `versions.tf` : OpenTofu ≥ 1.6, providers `kreuzwerker/docker` (`~> 3.6`) et `hashicorp/random` (`~> 3.6`), et
un **backend `local` vide** (`backend "local" {}`) : le chemin du state sera donné à l'`init`, il ne doit pas être
écrit en dur.

### A.2 Les variables

Dans `variables.tf`, au minimum :

| Variable | Type / défaut | Contrainte (bloc `validation`) |
|---|---|---|
| `ghcr_owner` | string, **sans défaut** | minuscules, chiffres, tirets |
| `image_tag` | string, `latest` | SHA court (7 caractères hexadécimaux) ou `latest` |
| `front_port` | number, `8081` | 1024-65535 |
| `environment` | string, `staging` | — |
| `db_password` | string, `null`, **`sensitive`** | — (expliqué en B) |
| `ghcr_username` / `ghcr_token` | string, `null` (`ghcr_token` `sensitive`) | — |

### A.3 Les ressources

Contraintes pour `main.tf` (n'hésitez pas à relire `compose.staging.yaml` : c'est la traduction à faire) :

- un `random_password` de 32 caractères **sans caractères spéciaux** (il finit dans une URL) ; un `local` qui prend
  `var.db_password` s'il est fourni, sinon ce mot de passe aléatoire ;
- trois `docker_image` (`postgres:16-alpine` et les deux images `ghcr.io/<owner>/taskflow-*:<tag>`), avec
  `keep_locally = true` ;
- le conteneur `db` monte le volume et a l'**alias réseau `db`** ; `api` a l'alias **`api`** (c'est le nom qu'utilise
  `front/nginx.conf`) ; seul `front` publie un port ;
- des `healthcheck` sur les trois conteneurs et `wait = true` sur `db` et `api` (l'équivalent de
  `depends_on: condition: service_healthy`) ; `depends_on` explicite `db` → `api` → `front` ;
- `restart = "unless-stopped"` partout.

Puis `outputs.tf` (au moins `url`, `health_url` et `image_tag`) et un `providers.tf` avec `provider "docker" {}`.

```bash
tofu init -backend=false && tofu fmt && tofu validate
```

> **Si ça ne marche pas**
> - `Unsupported argument "aliases"` : l'alias se met dans le bloc `networks_advanced { name = ..., aliases = ["api"] }`.
> - `you have supplied a 'wait' argument, but the container does not have a healthcheck` : ajoutez un bloc
>   `healthcheck` au conteneur (certaines images construites en format OCI perdent le `HEALTHCHECK` du Dockerfile).
> - Bloqué plus de 10 minutes : comparez avec `$SOL/infra/main.tf`, **puis** refermez-le et écrivez le vôtre.

### A.4 Le lock file pour toutes les plateformes

Vous êtes sur Linux, un binôme est sur macOS, le runner est en `linux_amd64` :

```bash
tofu providers lock -platform=linux_amd64 -platform=linux_arm64 -platform=darwin_amd64 -platform=darwin_arm64 -platform=windows_amd64
git status --short       # .terraform.lock.hcl à committer ; .terraform/ ne doit PAS apparaître
```

Ajoutez au `.gitignore` racine : `.terraform/`, `*.tfstate`, `*.tfstate.*`, `*.tfplan`, `tfplan`, `terraform.tfvars`.

---

## Partie B. Migrer le staging Compose vers OpenTofu, sans perdre les données (15 min)

Créez d'abord une tâche « créée avant la migration » sur http://localhost:8081 : elle doit survivre.

### B.1 Arrêter le staging Compose (sans supprimer le volume)

```bash
cd "$STAGING_DIR"
docker compose -f compose.staging.yaml down        # PAS de -v : le volume et ses données restent
docker volume ls | grep taskflow-staging           # taskflow-staging-pgdata est toujours là
```

### B.2 Initialiser avec le state dans `STAGING_DIR`, et importer le volume

```bash
cd ~/taskflow/infra
tofu init -backend-config="path=$STAGING_DIR/terraform.tfstate"
export TF_VAR_ghcr_owner=<vous-en-minuscules>
export TF_VAR_image_tag=$(cat "$STAGING_DIR/.deployed_tag" 2>/dev/null || echo latest)
# Le volume a été initialisé avec le mot de passe du .env du staging : on le reprend
export TF_VAR_db_password=$(sed -n 's/^POSTGRES_PASSWORD=//p' "$STAGING_DIR/.env")

tofu import docker_volume.pgdata taskflow-staging-pgdata
tofu plan
```

**Lisez le plan.** Le volume doit apparaître **sans** `must be replaced`. S'il est marqué `labels # forces replacement` :
c'est le piège vu en cours (labels `com.docker.compose.*` posés par Compose). Ajoutez au volume
`lifecycle { ignore_changes = [labels] }` et relancez le plan. **N'appliquez jamais un plan qui détruit le volume.**

```bash
tofu apply
curl -s "$(tofu output -raw health_url)"           # {"status":"ok","db":"up","version":"<sha>","env":"staging"}
curl -s http://localhost:8081/api/tasks            # la tâche créée avant la migration est là
tofu plan                                          # No changes : l'infrastructure correspond au code
```

> **Si ça ne marche pas**
> - `Conflict. The container name "/taskflow-staging-db" is already in use` ou `network with name taskflow-staging
>   already exists` : le staging Compose tourne encore (B.1).
> - `Error pulling image ... denied` : paquets ghcr.io privés. `export TF_VAR_ghcr_username=<vous>` et
>   `TF_VAR_ghcr_token=<PAT avec read:packages>` (ou `docker login ghcr.io` puis rendez les paquets publics).
> - L'API ne devient jamais *healthy* et ses logs disent `password authentication failed` : `TF_VAR_db_password` vide ou
>   différent de celui qui a initialisé le volume.
> - Podman au lieu de Docker : `tofu plan` propose de **tout** recréer (`ipam_options`, `ulimit`, `pid_mode`) même juste
>   après un apply. Ce sont des attributs renvoyés par Podman, pas par Docker Engine : la cible du TP est Docker Engine.

### Questions de réflexion (parties A et B)

1. Ouvrez `$STAGING_DIR/terraform.tfstate` et cherchez `POSTGRES_PASSWORD`. Qu'en concluez-vous sur le stockage du state ?
2. Pourquoi `tofu import` plutôt que laisser Tofu créer un volume neuf ? Que se serait-il passé sinon ?
3. Pourquoi l'alias réseau `api` est-il indispensable alors que le conteneur s'appelle `taskflow-staging-api` ?
4. Compose savait déjà faire ce staging. Qu'apporte Tofu de plus ? Qu'est-ce qu'on perd ?

---

## Partie C. L'IaC dans le pipeline (20 min)

### C.1 `iac.yml` : vérifier et planifier chaque PR

Créez `.github/workflows/iac.yml` (point de départ : `$SOL/.github/workflows/iac.yml`, lisez **tout** l'en-tête) :

| Job | Runner | Étapes |
|---|---|---|
| `iac-validate` | `ubuntu-latest` | `opentofu/setup-opentofu` (épinglé par SHA), `tofu fmt -check -recursive`, `tofu init -backend=false -lockfile=readonly`, `tofu validate` |
| `iac-plan` | `[self-hosted, lab]` | `tofu init` avec le state de `$STAGING_DIR`, `./ci-env.sh` (garde la version **déjà** déployée), `tofu plan -detailed-exitcode -out=tfplan`, plan publié dans le **résumé** du job et en **commentaire de PR** |

Déclencheurs : `pull_request` sur `infra/**`, plus un `schedule` hebdomadaire qui échoue en cas de **dérive**.

> **Choix à justifier** : le `plan` tourne sur le runner self-hosted. Sur `ubuntu-latest`, le daemon Docker est vide
> et le state absent : le plan dirait « 9 to add » à chaque PR, sans intérêt pour le relecteur. Le prix : du code de PR
> s'exécute sur une machine qui a le socket Docker. D'où la condition `head.repo.full_name == github.repository`
> (jamais de PR de fork) et aucun secret dans ce job.

`infra/ci-env.sh` (à copier depuis `$SOL/infra/`, `chmod +x`) écrit dans `$GITHUB_ENV` : `TF_VAR_ghcr_owner` (en
minuscules), `TF_VAR_image_tag`, et `TF_VAR_db_password` lu dans `$STAGING_DIR/.env` (masqué dans les logs).

### C.2 `deploy-staging` en version OpenTofu

Dans `release.yml`, remplacez les étapes du job `deploy-staging` (même nom, mêmes `needs`, `if`, `environment`,
`concurrency`) par :

1. `tofu init -lockfile=readonly -backend-config="path=$STAGING_DIR/terraform.tfstate"` (dans `infra/`) ;
2. `./ci-env.sh "$TAG"` (le tag vient de `needs.prepare.outputs.tag`) ;
3. une étape de **migration** sans effet après le premier passage (conteneurs Compose supprimés, volume importé) ;
4. `tofu plan -out=tfplan` puis `tofu apply tfplan` : on applique **le plan affiché**, pas un nouveau calcul ;
5. `./deploy/smoke-test.sh "http://host.docker.internal:${FRONT_PORT}/health" "$TAG"`.

Le provider tire les images lui-même : passez `TF_VAR_ghcr_username: ${{ github.actor }}` et
`TF_VAR_ghcr_token: ${{ secrets.GITHUB_TOKEN }}` (permission `packages: read`). Le jeton configure le provider : il n'est
**pas** écrit dans le state.

> **Si ça ne marche pas**
> - `tofu: command not found` dans le job : l'image du runner n'a pas OpenTofu (voir Prérequis).
> - `STAGING_DIR` vide : c'est une variable d'environnement **du conteneur runner** ; utilisez `"$STAGING_DIR"` en
>   shell, pas `${{ env.STAGING_DIR }}` (contexte GitHub, vide).
> - `Error acquiring the state lock` : un autre job (plan d'une PR, déploiement) tient le verrou. `-lock-timeout=120s`
>   le fait attendre ; un verrou orphelin après un job annulé se lève avec `tofu force-unlock <ID>` (en sachant ce
>   qu'on fait).
> - `Error: Inconsistent dependency lock file` : `.terraform.lock.hcl` pas commité, ou pas à jour après un changement
>   de version de provider.

### C.3 Prouver que ça marche

1. Poussez la branche, ouvrez la PR : `iac-validate` et `iac-plan` passent ; le plan apparaît en commentaire
   (`No changes` si votre staging est déjà à jour).
2. Dans la même PR, changez une chose **inoffensive** (par exemple un label sur le réseau) : le commentaire est mis à jour
   avec `1 to change`.
3. Mergez : `release.yml` déploie le staging par OpenTofu, puis la production par Compose (inchangée).
4. Dérive : `docker rm -f taskflow-staging-front`, puis *Actions > IaC > Run workflow* : le job `iac-plan` échoue
   (« Dérive détectée »). Relancez la dernière release (ou `tofu apply` à la main) pour corriger.

### Questions de réflexion (partie C)

1. Pourquoi `fmt` et `validate` sur `ubuntu-latest`, et `plan` sur le runner du lab ?
2. Pourquoi `apply tfplan` plutôt que `apply -auto-approve` ? Pourquoi supprimer `tfplan` après usage ?
3. La production reste en Compose. Faut-il la passer aussi en OpenTofu ? Quels risques, quels gains ?

---

## Checklist de validation (ce que le formateur vérifie)

- [ ] `infra/` : `tofu fmt -check` et `tofu validate` passent ; variables avec validation ; outputs
- [ ] `.terraform.lock.hcl` commité (plusieurs plateformes) ; **aucun** `*.tfstate` ni `.terraform/` dans Git
      (`git ls-files | grep -E 'tfstate|\.terraform/'` vide)
- [ ] State dans `~/taskflow-staging/terraform.tfstate` ; `tofu plan` → `No changes`
- [ ] http://localhost:8081/health → `ok`, bonne version ; la tâche créée avant la migration existe toujours
- [ ] `iac.yml` : actions épinglées par SHA, `permissions` minimales, plan visible dans une PR
- [ ] `deploy-staging` passe par OpenTofu (logs du job : `Apply complete!`) et son smoke test est vert
- [ ] Je sais expliquer : state et secrets, `import`, `-/+` vs `~`, pourquoi le plan tourne sur le runner self-hosted

## Bonus pour les rapides

1. **Ansible** : un playbook local qui prépare `~/taskflow-prod` (dossiers, `.env` depuis un modèle en `0600`, scripts,
   conf Nginx, certificat généré une seule fois, handler qui recharge le proxy). Prouvez `changed=0` au deuxième
   passage. Référence : `$SOL/ansible/`.
2. **Module** : déplacez les ressources dans `infra/modules/taskflow-env/` et créez un deuxième environnement `preprod`
   sur le port 8083 en quelques lignes.
3. **`prevent_destroy`** : ajoutez-le au volume, lancez `tofu destroy` et lisez le message. Pourquoi est-ce une bonne
   idée en production et une gêne en staging ?
4. **Backend `pg`** : stockez le state dans une base PostgreSQL (un conteneur à part) et observez le verrou en lançant
   deux `plan` en même temps.

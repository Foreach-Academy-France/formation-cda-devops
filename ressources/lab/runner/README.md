# Runner GitHub Actions self-hosted

## Pourquoi un runner chez moi ?

Les runners de GitHub (`ubuntu-latest`) sont dans le cloud : ils ne voient pas
votre poste. Pour que `release.yml` puisse **déployer sur vos « serveurs »**
(`~/taskflow-staging/` et `~/taskflow-prod/`, deux stacks Compose sur votre poste),
il faut un runner qui tourne **chez vous**. C'est ce conteneur.

Il reçoit les jobs `runs-on: [self-hosted, lab]` (`deploy-staging`,
`deploy-production`) et pilote le Docker de votre poste grâce au socket monté.
Son image contient : docker CLI + plugin compose, git, curl, jq et **OpenTofu**
(`tofu`, utilisé au Jour 4 pour décrire le staging en code).

## Pas à pas

### 0. Pré-requis
- Docker fonctionne (`docker run --rm hello-world`) — voir `../../setup-poste.md`.
- Votre dépôt `taskflow` existe sur GitHub et vous en êtes propriétaire (ou admin).
- Les dossiers `~/taskflow-prod/` et `~/taskflow-staging/` existent (TP étape 2, parties A et B.1).

### 1. Récupérer un jeton d'enregistrement
1. Sur GitHub, ouvrez **votre** dépôt `taskflow`.
2. **Settings** > **Actions** > **Runners** > bouton **New self-hosted runner**.
3. Choisissez Linux. Dans la section « Configure », repérez la ligne
   `./config.sh --url https://github.com/... --token AAAA...`
4. Copiez **seulement** la valeur après `--token`. Elle expire en **1 heure**.
   (Ne suivez pas les instructions de téléchargement : notre conteneur fait tout.)

### 2. Configurer
```bash
cd ressources/lab/runner
cp .env.example .env
nano .env        # REPO_URL, RUNNER_TOKEN, PROD_DIR, STAGING_DIR (chemins ABSOLUS)
```
Vérifiez : `echo $HOME` vous donne le début des chemins.

### 3. Démarrer
```bash
docker compose up -d --build
docker compose logs -f runner
```
Attendu à la fin des logs :
```
√ Runner successfully added
√ Runner connection is good
Current runner version: ...
Listening for Jobs
```
(Quittez les logs avec `Ctrl+C` : le runner continue.)

### 4. Vérifier côté GitHub
**Settings** > **Actions** > **Runners** : votre `lab-runner` apparaît avec les
étiquettes `self-hosted`, `lab` et la pastille verte **Idle** (= connecté, en attente de travail).
Pendant un déploiement il passe à **Active**.

### 5. Vérifier que le runner voit votre Docker
```bash
docker compose exec runner docker ps
docker compose exec runner sh -c 'ls "$PROD_DIR" "$STAGING_DIR"'   # guillemets simples : variables lues DANS le conteneur
docker compose exec runner tofu version
```
Le premier doit lister **vos** conteneurs (ceux de votre poste), le second le contenu des deux dossiers.

## Si ça ne marche pas

| Symptôme | Cause probable | Que faire |
|---|---|---|
| `Invalid configuration provided for token` / 404 dans les logs | Jeton expiré ou mal copié, ou mauvais `REPO_URL` | Générez un nouveau jeton, corrigez `.env`, `docker compose up -d --force-recreate` |
| `Runner already exists` | Un ancien runner du même nom est enregistré | Supprimez-le dans Settings > Actions > Runners, ou changez `RUNNER_NAME` |
| Erreur « Renseignez PROD_DIR / STAGING_DIR » | Variable absente de `.env` | Ajoutez-la (chemin absolu) |
| `permission denied ... docker.sock` dans le job | Socket inaccessible | Linux : voir « Podman » ci-dessous ; vérifier que Docker tourne |
| Le runner reste « Offline » | Conteneur arrêté / jeton refusé | `docker compose ps`, `docker compose logs runner` |
| Les jobs ne démarrent pas (« Waiting for a runner ») | `runs-on` ne correspond pas aux labels | Le workflow doit avoir `runs-on: [self-hosted, lab]` |
| Un volume monté dans la stack prod est vide (`cannot load certificate`) | `PROD_DIR` différent du chemin réel de l'hôte | Même chemin des deux côtés (voir commentaire de `compose.yaml`) |
| Smoke test : `Failed to connect to host.docker.internal` | `extra_hosts` absent, ou port différent | Vérifiez `compose.yaml` ; variables `FRONT_PORT` / `HTTPS_PORT` des environments GitHub |
| `Permission denied` en relançant `./deploy.sh` à la main | Le runner (root) a écrit les fichiers | `sudo chown -R "$USER" ~/taskflow-prod ~/taskflow-staging` |

Arrêt propre (le runner se désenregistre) : `docker compose down`.
Après un redémarrage de l'ordinateur, le conteneur redémarre seul (`restart: unless-stopped`) ;
si le jeton a expiré mais que le runner est déjà enregistré, cela fonctionne quand même (la configuration est conservée dans le conteneur tant qu'il n'est pas supprimé).

## Sécurité : à lire

> **Monter `/var/run/docker.sock` donne au conteneur le contrôle total de Docker, donc
> l'équivalent de `root` sur votre machine.** Tout code exécuté par un workflow peut lancer
> n'importe quel conteneur, lire vos fichiers montés, etc.
>
> - Acceptable ici : lab, machine personnelle, dépôt **à vous**, runner rattaché à **ce seul dépôt**, jobs de déploiement déclenchés uniquement par un push sur `main` (protégée) ou à la main, environment `production` protégé par une approbation.
> - Votre dépôt `taskflow` est **public** (protection de branche gratuite) : n'importe qui peut le *forker* et ouvrir une Pull Request dont le workflow pourrait viser votre runner. **Obligatoire** : Settings > Actions > General > *Fork pull request workflows from outside collaborators* > **« Require approval for all outside collaborators »**. N'approuvez jamais un workflow venant d'un inconnu.
> - Sans ces garde-fous, **jamais** de runner auto-hébergé sur un dépôt public. En entreprise, le dépôt est privé.
> - Le runner est **persistant** : ce qu'un job laisse (identifiants `docker login`, fichiers dans `work/`) est visible
>   du job suivant. `release.yml` fait donc `docker logout` en fin de job.
> - En vrai : runner sur une machine dédiée, **éphémère** (`--ephemeral` : un job puis destruction, ou Actions Runner
>   Controller sur Kubernetes), et accès Docker restreint (proxy de socket, Docker rootless, ou pas de Docker du tout).
> - À la fin de la formation : `docker compose down`, puis supprimez le runner dans GitHub.

## Docker Desktop, WSL2, macOS
- Docker Desktop (Windows/macOS) expose bien `/var/run/docker.sock` aux conteneurs : le compose fonctionne tel quel.
- Windows : lancez tout **depuis le terminal WSL** et gardez `taskflow-prod` et `taskflow-staging` dans le système de fichiers WSL (`/home/...`), pas dans `/mnt/c/...`.
- macOS : `PROD_DIR` et `STAGING_DIR` doivent être dans un dossier partagé avec Docker Desktop (votre dossier personnel l'est par défaut).

## Note formateur : Podman
Sur une machine où `docker` est en réalité **Podman** (cas de la machine de préparation),
le socket n'est pas `/var/run/docker.sock` mais `/run/user/<uid>/podman/podman.sock`
(activer : `systemctl --user enable --now podman.socket`). Pour tester ce lab avec Podman,
remplacez temporairement la ligne du socket dans `compose.yaml` par
`- /run/user/1000/podman/podman.sock:/var/run/docker.sock`. En rootless, les ports < 1024 sont refusés :
la prod passe en `HTTP_PORT=8082` / `HTTPS_PORT=8443`.
La cible officielle reste Docker Desktop / Docker Engine.

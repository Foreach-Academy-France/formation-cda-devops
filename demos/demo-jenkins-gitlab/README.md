# Démo — Jenkins et GitLab CI : mêmes concepts, autres syntaxes

| | |
|---|---|
| **Jour / bloc** | Jour 2 matin — Bloc 3.3 « Jenkins et GitLab CI » (15 min de slides + 15 min de démo) |
| **Durée** | 15 min de démo (Jenkins démarré **avant** le bloc) |
| **Prérequis** | Docker Engine (ou Podman, détecté automatiquement), `jq`, `curl`, `git` ; port **8090** libre ; images `jenkins/jenkins:2.580.1-lts-jdk21`, `node:20-alpine`, `node:22-alpine`, `postgres:16-alpine` pré-téléchargées ; option GitLab locale : Node/npx |
| **Ce qu'on montre** | Jenkins **décrit en code** (plugins + JCasC) ; controller qui pilote Docker ; un pipeline déclaratif (`stages`, `parallel`, `matrix`, `post`, artefact) ; la CI de TaskFlow en `Jenkinsfile` qui passe ; le même pipeline en `.gitlab-ci.yml` (lu sur gitlab.com ou exécuté en local) ; le tableau de correspondance |

## Contenu du dossier

| Fichier | Rôle |
|---|---|
| `compose.yaml` | Jenkins LTS sur `127.0.0.1:8090`, socket Docker du poste monté, `JENKINS_HOME` au **même chemin** que sur le poste |
| `jenkins/Dockerfile` | image Jenkins LTS + client `docker` + plugins + JCasC, sans assistant d'installation |
| `jenkins/plugins.txt` | `configuration-as-code`, `job-dsl`, `workflow-aggregator`, `git`, `docker-workflow`, `pipeline-graph-view` |
| `jenkins/casc.yaml` | compte `admin`, deux jobs : `01-hello-pipeline` (syntaxe pure) et `02-taskflow-ci` (lit `ci-autres-outils/Jenkinsfile` dans le dépôt TaskFlow) |
| `jenkins/docker-wrapper.sh` | contournement Podman (`--pids-limit=-1`), transparent avec Docker Engine |
| `gitlab/.gitlab-ci.yml` | premier pipeline GitLab commenté ligne à ligne (équivalent de `01-hello-pipeline` et de `hello.yml`) |
| `demo.sh` | déroulé rejouable, nettoyage complet à la fin |

Les fichiers TaskFlow montrés sont ceux de la solution : [`tp/fil-rouge-taskflow/solution/ci-autres-outils/`](../../tp/fil-rouge-taskflow/solution/ci-autres-outils/README.md) (`Jenkinsfile`, `.gitlab-ci.yml` et le **tableau de correspondance** avec GitHub Actions).

## Préparer (la veille, 10 min)

```bash
# Test complet sans pause (télécharge les plugins, lance les deux jobs, nettoie)
DEMO_AUTO=1 bash demos/demo-jenkins-gitlab/demo.sh
# Le matin même : garder Jenkins démarré pour la séance
KEEP=1 DEMO_AUTO=1 bash demos/demo-jenkins-gitlab/demo.sh
```

Par défaut, `02-taskflow-ci` lit un dépôt Git **local** fabriqué par `demo.sh` à partir de `tp/fil-rouge-taskflow/solution` (aucun compte, aucun réseau entrant). Pour pointer vers un vrai dépôt GitHub public : `TASKFLOW_REPO_URL=https://github.com/<vous>/taskflow.git bash demo.sh` (il doit contenir `ci-autres-outils/Jenkinsfile`).

## Déroulé minuté

| Min | Étape | Dire | Taper / montrer | Question à poser à la salle |
|---|---|---|---|---|
| 0-2 | 1 | « Jenkins existe depuis 2011 (ex-Hudson) : 100 % self-hosted, extensible par plugins. Ici, il est décrit **en code** : la liste des plugins et un fichier JCasC. » | `plugins.txt`, `casc.yaml` | « Que se passe-t-il le jour où le serveur Jenkins meurt, si tout a été configuré à la souris ? » |
| 2-4 | 2 | « Un **controller** (l'interface, l'état, les plugins) et des **agents** (qui exécutent). Ici le controller pilote le Docker du poste : chaque stage tourne dans un conteneur `node`. » | `compose.yaml` : socket, `JENKINS_HOME` au même chemin | « Pourquoi le même chemin des deux côtés ? » (c'est le daemon du poste qui monte le workspace — même astuce que le runner du Jour 3) |
| 4-6 | 3 | « La syntaxe déclarative : `stages`, `parallel`, `matrix`, `post`. » | job `01-hello-pipeline`, vue graphique, artefact | « Quel mot-clé GitHub Actions correspond à `parallel` ? » (des jobs sans `needs`) |
| 6-10 | 4-5 | « La CI de TaskFlow, traduite. Jenkins n'a pas de `services:` : on lance Postgres nous-mêmes sur un réseau Docker, et on nettoie. » | `Jenkinsfile`, puis le build `02-taskflow-ci` : stages verts, `Couverture des lignes`, `10 passed` | « Qu'est-ce que GitHub fait pour nous et que Jenkins nous laisse faire ? » (VM jetable, cache, nettoyage, mises à jour) |
| 10-13 | 6 | « GitLab CI : un seul fichier YAML, des **stages** qui s'enchaînent, des jobs parallèles dans un stage, `services:` joignable par alias, `rules:` pour les déclencheurs. » | `gitlab/.gitlab-ci.yml` puis `ci-autres-outils/.gitlab-ci.yml` ; gitlab.com > *Pipeline editor* > *Validate* (ou `GITLAB_LOCAL=1`) | « Pourquoi l'API joint-elle la base sur `postgres:5432` et non `localhost:5432` ? » (le job tourne lui-même dans un conteneur) |
| 13-15 | — | « Mêmes concepts, trois syntaxes : savoir lire les trois est une compétence attendue. » | tableau de correspondance | « Vous arrivez dans une entreprise qui a Jenkins et GitHub. Que proposez-vous, et à quel coût ? » |

## Option GitLab

- **Lecture sur gitlab.com** (recommandé, rien à installer) : un projet personnel vide, coller `gitlab/.gitlab-ci.yml` dans *Build > Pipeline editor*, onglet *Validate* puis *Visualize* : le graphe des stages apparaît sans consommer de minutes. Pour un pipeline réel, n'importe quel grand projet public (onglet *Build > Pipelines*).
- **Exécution locale** : `GITLAB_LOCAL=1 bash demo.sh` lance `ci-autres-outils/.gitlab-ci.yml` avec [`gitlab-ci-local`](https://github.com/firecow/gitlab-ci-local) (jobs `api: [20]`, `api-integration`, `front`) dans des conteneurs, comme un runner GitLab *docker*. Le job `docker-build` (Docker-in-Docker) n'est pas lancé.
- On n'héberge **pas** GitLab : l'instance pèse plusieurs Go de RAM, hors sujet pour une démo de 15 min.

## Pièges à anticiper

- **Premier lancement lent** : `jenkins-plugin-cli` télécharge les plugins (plusieurs minutes sur un réseau de salle) → construire la veille ; l'image `demo-jenkins-cda:local` reste en cache avec `KEEP=1`.
- **`Permission denied` sur `/var/run/docker.sock`** : le groupe du socket n'a pas été transmis. `demo.sh` le calcule (`DOCKER_GID`) ; à la main : `DOCKER_GID=$(stat -c %g /var/run/docker.sock) docker compose up -d`.
- **`mkdir /var/jenkins_home: permission denied` ou workspace vide dans le conteneur `node`** : `JENKINS_HOME` n'est pas au même chemin sur le poste et dans le conteneur. Toujours passer par `demo.sh` (ou définir `JENKINS_HOME_DIR` en chemin absolu).
- **Podman** : `demo.sh` le détecte (`docker version`), monte `/run/user/$UID/podman/podman.sock`, lance Jenkins en root du conteneur (= votre utilisateur en rootless) et active `PODMAN_COMPAT=1` (sinon `can't fork: Resource temporarily unavailable` dans les conteneurs `node`).
- **Sécurité** : le conteneur Jenkins a accès au socket Docker, donc l'équivalent de **root sur le poste**. Port publié sur `127.0.0.1` uniquement, mot de passe `admin` : démo locale, jamais sur un réseau partagé. En entreprise : agents séparés, éphémères, sans socket de l'hôte.

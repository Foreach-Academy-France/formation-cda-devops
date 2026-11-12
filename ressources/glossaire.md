# Glossaire DevOps

Les termes de la formation, expliqués simplement. Ordre alphabétique.

| Terme | Explication |
|---|---|
| **Action (GitHub Actions)** | Brique réutilisable utilisée dans une étape (`uses: actions/checkout@v7`). Comme une fonction toute faite. |
| **Agile** | Façon de travailler par petites livraisons fréquentes plutôt qu'un gros projet livré à la fin. |
| **Alertmanager** | Composant de la stack Prometheus qui reçoit les alertes, les regroupe, les dédoublonne et envoie les notifications (mail, chat). |
| **Ansible** | Outil de **configuration** : un playbook YAML décrit l'état voulu d'une machine (paquets, fichiers, services) ; relancé, il ne refait que ce qui manque. |
| **API** | Interface par laquelle des programmes se parlent. Ici : le serveur de TaskFlow répond à `/api/tasks`. |
| **apt** | Gestionnaire de paquets de Debian/Ubuntu : `sudo apt install nginx`. |
| **Artefact** | Fichier produit par un pipeline et conservé : dossier `dist/`, rapport de tests, image Docker. |
| **Auto-signé (certificat)** | Certificat TLS fabriqué par vous-même, sans autorité reconnue. Chiffre bien, mais le navigateur avertit. Parfait en local, interdit en production publique. |
| **Backend (state)** | Endroit où OpenTofu/Terraform range son *state* : fichier local, ou stockage partagé avec verrou (S3, GitLab, Terraform Cloud) en équipe. |
| **Backup / sauvegarde** | Copie des données (ici `pg_dump` de la base). Une sauvegarde jamais testée en restauration n'est pas une sauvegarde. |
| **Bind mount** | Dossier de votre poste monté dans un conteneur. Voir *volume*. |
| **Blue/green** | Stratégie de déploiement : deux environnements complets ; on déploie sur celui qui ne reçoit pas le trafic, puis on bascule d'un coup. |
| **Branche** | Ligne de travail parallèle dans Git ; permet de développer sans toucher `main`. |
| **Build** | Étape qui transforme le code en quelque chose d'exécutable (compilation, `npm run build`, construction d'une image). |
| **CALMS** | Culture, Automatisation, Lean, Mesure, Partage : les piliers du DevOps. |
| **Canary** | Stratégie de déploiement : la nouvelle version reçoit d'abord une petite part du trafic, que l'on augmente si les métriques restent bonnes. |
| **CD (déploiement continu)** | *Continuous Deployment* : chaque changement validé part en production automatiquement, sans humain. |
| **CD (livraison continue)** | *Continuous Delivery* : le code est toujours prêt à être déployé, un humain appuie sur le bouton. |
| **Certificat** | Document numérique qui prouve l'identité d'un site et permet le chiffrement (HTTPS). |
| **CI (intégration continue)** | *Continuous Integration* : à chaque push, on construit et on teste automatiquement pour détecter vite les erreurs. |
| **Clé SSH (publique / privée)** | Paire de fichiers : la **publique** se donne (cadenas), la **privée** reste secrète (clé). Remplace le mot de passe. |
| **CODEOWNERS** | Fichier qui désigne les relecteurs obligatoires selon les dossiers modifiés (`/infra/ @equipe-ops`). |
| **Commit** | Photo (enregistrement) de votre projet à un instant, avec un message. |
| **Conflit** | Deux personnes ont modifié les mêmes lignes ; Git demande à un humain de choisir. |
| **Conteneur** | Processus isolé qui embarque tout ce dont une application a besoin. Plus léger qu'une machine virtuelle : il partage le noyau de l'hôte. |
| **Conventional Commits** | Convention de messages (`feat:`, `fix:`, `docs:`...) qui rend l'historique lisible. |
| **Cron** | Planification de tâches : `0 6 * * 1` = lundis à 6 h. |
| **CVE** | Identifiant public d'une vulnérabilité connue (`CVE-2024-12345`), avec un score de gravité (CVSS). Trivy et `npm audit` les recherchent. |
| **DAST** | *Dynamic Application Security Testing* : on attaque l'application **en fonctionnement** (ZAP, Burp). Trouve les problèmes de configuration et d'exécution. |
| **Dependabot** | Service GitHub qui surveille les dépendances et ouvre des PR de mise à jour (et d'alerte de sécurité). |
| **DevOps** | Culture et pratiques qui rapprochent développeurs (Dev) et exploitants (Ops) : on construit **et** on fait tourner, avec de l'automatisation. |
| **Docker** | Outil pour construire et lancer des conteneurs. |
| **Docker Compose** | Décrit plusieurs conteneurs dans un fichier `compose.yaml` et les lance ensemble (`docker compose up`). |
| **Dockerfile** | Recette de construction d'une image, instruction par instruction. |
| **DORA (métriques)** | 4 mesures de la performance d'une équipe : fréquence de déploiement, délai de livraison, taux d'échec, temps de rétablissement. |
| **Drift (dérive)** | Écart entre l'infrastructure réelle et sa description en code, souvent dû à une modification manuelle. `tofu plan` le révèle. |
| **Environment (GitHub)** | Réglage GitHub (ex. `production`) avec ses propres secrets et éventuellement une validation manuelle avant déploiement. |
| **Environnement (dev / test / prod)** | Lieux où tourne l'application : votre poste (dev), un essai (test), le vrai (prod). Même code, configuration différente. |
| **Expand / contract** | Migration de base en deux temps compatible avec un rollback : on ajoute (colonne, table) sans casser l'ancienne version, puis on retire l'ancien plus tard. |
| **Fast-forward** | Fusion triviale : la branche cible n'a pas bougé, Git avance simplement le pointeur. |
| **Feature flag** | Interrupteur dans le code qui active une fonctionnalité sans redéployer ; sépare « déployer » de « mettre à disposition ». |
| **ghcr.io** | *GitHub Container Registry* : registre d'images Docker de GitHub. |
| **Git Flow** | Workflow plus lourd avec `main`, `develop`, `feature/*`, `hotfix/*`. |
| **GitHub Flow** | Workflow simple : `main` toujours déployable, travail en branches courtes, Pull Request, revue, merge. |
| **GITHUB_TOKEN** | Jeton temporaire créé automatiquement à chaque workflow, avec des droits limités (`permissions:`). |
| **GitLab CI** | Intégration continue de GitLab : pipeline décrit dans `.gitlab-ci.yml` (stages, jobs), exécuté par des *runners*. |
| **gitleaks** | Outil qui cherche des secrets (clés, jetons, mots de passe) dans un dépôt et dans tout son historique Git. |
| **Grafana** | Outil de tableaux de bord qui interroge Prometheus (et d'autres sources). Dans le TP, ses dashboards sont provisionnés en code. |
| **Healthcheck** | Test automatique de bonne santé d'un service (`/health`, `pg_isready`). Compose ou Docker marque le conteneur *healthy* / *unhealthy*. |
| **Hôte** | La machine qui fait tourner les conteneurs (ici : votre poste). |
| **HTTP / HTTPS** | Protocole du web / sa version chiffrée (par TLS). Cadenas dans le navigateur. |
| **Idempotence** | Propriété d'une opération qui donne le même résultat qu'on la lance une ou dix fois. Essentielle en IaC et en déploiement. |
| **Image (Docker)** | Modèle figé, en lecture seule, à partir duquel on lance des conteneurs. Composée de couches. |
| **Infrastructure as Code** | Décrire l'infrastructure dans des fichiers versionnés (compose, workflows) plutôt que de cliquer à la main. |
| **Jenkins** | Serveur d'intégration continue auto-hébergé ; les pipelines sont décrits dans un `Jenkinsfile`, exécutés par des *agents*. |
| **Job** | Ensemble d'étapes qui s'exécute sur un runner. Plusieurs jobs tournent en parallèle sauf si `needs:` les ordonne. |
| **Journal / log** | Messages écrits par un programme pour raconter ce qu'il fait. Premier réflexe en cas de panne. |
| **JSON (logs)** | Un événement par ligne au format JSON : lisible par les outils de recherche. |
| **Juice Shop** | Application volontairement vulnérable de l'OWASP, pour s'entraîner légalement à trouver des failles. |
| **Label (runner)** | Étiquette d'un runner (`self-hosted`, `lab`) ; `runs-on:` s'en sert pour choisir où exécuter. |
| **Lead time** | Temps écoulé entre la demande (ou le commit) et la mise en production. À comparer au temps de travail effectif (*process time*). |
| **Lean** | Approche issue de l'industrie (Toyota) : maximiser la valeur, supprimer les gaspillages (attente, stock, défauts), fluidifier le flux. |
| **Lint / linter** | Outil qui détecte les fautes de style et erreurs probables sans exécuter le code (ESLint). |
| **Matrix (matrice)** | Dans GitHub Actions, lance le même job pour plusieurs valeurs (`node: [20, 22]`) ; chaque combinaison devient un check. |
| **Merge** | Fusion d'une branche dans une autre. |
| **Métrique** | Valeur numérique mesurée dans le temps (requêtes/s, latence, mémoire). Prometheus les collecte. |
| **Monitoring / supervision** | Surveiller en continu qu'un service fonctionne et alerter (Uptime Kuma). |
| **Nginx** | Serveur web et **reverse proxy** très répandu. |
| **OpenTofu** | Version libre et compatible de Terraform (commande `tofu`). Décrit l'infrastructure en fichiers `.tf`. |
| **OWASP** | Fondation qui publie des ressources libres de sécurité applicative : le **Top 10** des risques web, ZAP, Juice Shop. |
| **PaaS** | *Platform as a Service* : hébergeur qui exécute votre application sans que vous gériez le serveur (Render, Railway). |
| **Pipeline** | Chaîne automatique d'étapes : lint, tests, build, publication, déploiement. |
| **Plan (OpenTofu)** | Liste des changements qu'OpenTofu ferait pour atteindre l'état décrit (`+` créer, `~` modifier, `-/+` recréer, `-` détruire). Se relit avant `apply`. |
| **Port** | Numéro de « porte » d'une machine : 80 (HTTP), 443 (HTTPS), 22 (SSH), 5432 (PostgreSQL). `-p 8080:80` = port 8080 de l'hôte vers 80 du conteneur. |
| **Post-mortem (sans blâme)** | Compte rendu d'un incident : chronologie, cause, correction, prévention. On cherche les failles du système, pas un coupable. |
| **Production (prod)** | Environnement réel utilisé par les vrais utilisateurs. Ici : la stack `taskflow-prod` sur votre poste. |
| **Prometheus** | Base de métriques qui va **chercher** (pull) les métriques des cibles à intervalle régulier ; on l'interroge en PromQL. |
| **PromQL** | Langage de requête de Prometheus : `rate(http_requests_total[5m])`. |
| **Provider** | Plugin OpenTofu/Terraform qui sait piloter une plateforme (Docker, AWS, Azure…). |
| **Pull Request (PR)** | Demande de fusion d'une branche sur GitHub : lieu de la discussion et de la revue de code. |
| **Rebase** | Rejouer vos commits au-dessus d'une autre base pour un historique linéaire. Ne jamais le faire sur une branche partagée. |
| **RED (méthode)** | *Rate, Errors, Duration* : les trois métriques à suivre pour un service. |
| **Registre (registry)** | Entrepôt d'images (Docker Hub, ghcr.io). `docker push` envoie, `docker pull` télécharge. |
| **Release** | Version publiée et nommée (tag `v1.2.0`) avec ses notes. |
| **Repository (dépôt)** | Projet versionné avec Git. |
| **Reverse proxy** | Serveur placé devant vos applications : unique point d'entrée, gère HTTPS et redirige vers le bon service. |
| **Revue de code** | Relecture du code d'un collègue avant le merge. |
| **Rollback** | Retour à la version précédente après un déploiement raté (redéployer l'ancien tag). |
| **Ruleset** | Ensemble de règles GitHub appliquées à des branches (PR obligatoire, revues, checks requis, méthode de fusion). |
| **Runner** | Machine (ou conteneur) qui exécute les jobs GitHub Actions. *GitHub-hosted* : fourni par GitHub. *Self-hosted* : le vôtre. |
| **SAST** | *Static Application Security Testing* : analyse du code source sans l'exécuter (Semgrep, CodeQL). |
| **SBOM** | *Software Bill of Materials* : inventaire de tous les composants d'un logiciel ou d'une image. |
| **SCA** | *Software Composition Analysis* : analyse des dépendances tierces et de leurs vulnérabilités (`npm audit`, Trivy, Dependabot). |
| **Secret** | Information confidentielle (mot de passe, jeton, clé). Jamais dans Git ni dans une image ; stocké dans les *Secrets* GitHub ou un `.env` protégé. |
| **Semgrep** | Outil de SAST à base de règles, qui repère des motifs de code dangereux (injection, `eval`…). |
| **SemVer** | *Semantic Versioning* `MAJEUR.MINEUR.CORRECTIF` : 2.4.1. Majeur = rupture, mineur = nouveauté compatible, correctif = bug corrigé. |
| **Service (Compose)** | Un conteneur décrit dans `compose.yaml` (`db`, `api`, `front`). Son nom sert d'adresse réseau interne. |
| **SHA (de commit)** | Identifiant unique d'un commit (ex. `a1b2c3d`). Sert à tagger précisément les images. |
| **Shift-left** | Faire les contrôles (tests, sécurité) le plus tôt possible dans le cycle, quand corriger coûte le moins. |
| **Smoke test** | Test minimal après déploiement : « est-ce que ça démarre ? » (`curl -f .../health`). |
| **Squash** | Fusion qui écrase tous les commits d'une PR en un seul commit sur la branche cible. |
| **SSH** | *Secure Shell* : connexion chiffrée à une machine distante (port 22). |
| **Staging** | Environnement de pré-production, le plus proche possible de la prod, où l'on vérifie une version avant de la promouvoir. |
| **State (OpenTofu)** | Fichier où OpenTofu mémorise ce qu'il a créé. Ne va pas dans Git (peut contenir des secrets). |
| **Step (étape)** | Une action ou une commande dans un job. |
| **sudo** | Exécuter une commande avec les droits administrateur. |
| **Tag** | Étiquette fixe sur un commit (`v1.0.0`), ou version d'une image (`api:1.0.0`). |
| **TLS** | *Transport Layer Security* : chiffrement qui protège HTTPS (successeur de SSL). |
| **Trigger / déclencheur** | Événement qui lance un workflow : `push`, `pull_request`, `workflow_dispatch`, `schedule`. |
| **Trivy** | Scanner de vulnérabilités pour images de conteneurs, dépôts et fichiers IaC. |
| **Trunk-based development** | Tout le monde intègre sur `main` au moins une fois par jour, par petites branches très courtes. |
| **Value stream mapping** | Cartographie du flux de valeur : chaque étape de l'idée à la prod, avec son temps de travail et son temps d'attente. |
| **VM (machine virtuelle)** | Ordinateur simulé avec son propre système complet ; plus lourd qu'un conteneur. |
| **Volume (Docker)** | Espace de stockage géré par Docker qui survit à la suppression du conteneur : indispensable pour une base de données. |
| **VPS** | *Virtual Private Server* : serveur virtuel loué chez un hébergeur, accessible par SSH. Dans le lab, votre poste en tient le rôle. |
| **Workflow** | Fichier YAML de GitHub Actions décrivant déclencheurs, jobs et étapes. |
| **YAML** | Format de fichier de configuration basé sur l'indentation (espaces, jamais de tabulation). Compose et Actions l'utilisent. |
| **ZAP** | OWASP Zed Attack Proxy : scanner DAST libre, utilisé en mode *baseline* dans le pipeline. |
| **12 factors (config)** | Principe : la configuration (mots de passe, URL) vient de l'environnement (`.env`), pas du code. |
| **200 / 201 / 204 / 301 / 404 / 500** | Succès / créé / succès sans contenu / redirection permanente / introuvable / erreur interne. |
| **502 / 503 / 504** | Erreurs HTTP côté serveur : 502 = l'application derrière le proxy ne répond pas ; 503 = service indisponible (ex. base de données down) ; 504 = trop lent. |

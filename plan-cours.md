---
type: course-plan
duration: 4 jours × 7h + 1 demi-journée par demi-groupe (syllabus : 31h30)
format: cours + exercices le matin, TP fil rouge l'après-midi — maximum de mises en situation
last_updated: 2026-11-12
---

# Plan de cours — DevOps pour les CDA (31h30)

**Public :** apprenants du titre professionnel **Concepteur Développeur d'Applications (CDA, niveau 6 / Bac+3-4)**. Ils développent des applications complètes (front + back + BDD), **connaissent Git** (commit, branche, push, PR simple) et ont **des bases légères en Docker** (ils savent lancer un conteneur, ont vu un Dockerfile, mais n'ont pas l'habitude de les écrire). Ils n'ont jamais opéré de pipeline CI/CD complet, d'IaC, de monitoring ni d'outillage de sécurité.

**Conséquences pédagogiques :**
- **Mise en situation d'abord** : chaque notion est introduite par un problème concret (un incident, une étude de cas, un pipeline cassé), puis pratiquée immédiatement.
- **Matin = cours + exercices** (blocs de théorie de 30-45 min max, toujours suivis d'un exercice ou d'une démo) ; **après-midi = TP fil rouge** sur TaskFlow.
- **Git : on ne repart pas de zéro.** On approfondit le travail d'équipe (revue, protection de branche, rebase, conventions).
- **Docker : rappel express seulement.** Les Dockerfiles et le `compose.yaml` de dev sont **fournis** dans le starter ; les apprenants les lisent, les comprennent et les modifient, sans les écrire de zéro.
- **Niveau CDA** : on attend des justifications d'architecture (pourquoi ce pipeline, quels compromis), pas seulement « ça marche ».
- **Tout tourne en local** : pas de VPS ni de cloud. La « prod » est une stack Compose séparée sur le poste ; le serveur réel est expliqué en théorie.
- **Pas de dates dans les supports** : on écrit « Jour 1 … Jour 5 », « demain », jamais un jour de la semaine ni une date.

## Choix d'outils

| Besoin | Outil | Pourquoi |
|---|---|---|
| Versions / collaboration | **Git + GitHub** (PR, review, rulesets, CODEOWNERS) | Outil du marché, déjà connu |
| Conteneurs | **Docker + Compose v2** (fournis dans le starter) | Base du CD, de l'IaC et du monitoring |
| CI | **GitHub Actions** (pratique) ; **Jenkins** et **GitLab CI** (présentation + démo, tableau de correspondance) | Imposé par le syllabus |
| Registre | **ghcr.io** | Gratuit, authentifié par `GITHUB_TOKEN` |
| CD | Runner **self-hosted** en conteneur sur le poste (`ressources/lab/runner`) + **GitHub Environments** (`staging` auto, `production` avec approbation) | GitHub ne joint pas le poste ; le runner va chercher les jobs. Les Environments matérialisent livraison continue ≠ déploiement continu |
| « Prod » | Stack Compose `taskflow-prod` dans `~/taskflow-prod/` derrière Nginx en HTTPS (certificat auto-signé) | Gestes de prod réels sans infrastructure |
| IaC | **OpenTofu** (compatible Terraform, binaire `tofu`) avec le provider **`kreuzwerker/docker`** ; **Ansible** en local (`connection: local`) | Zéro coût, zéro compte cloud ; mêmes concepts (state, plan, drift, idempotence) qu'en vrai cloud |
| Monitoring | **Prometheus** + **Grafana** (provisionnés en code) + **blackbox exporter** + **Alertmanager** ; API instrumentée avec `prom-client` ; logs JSON (`jq`) ; Loki en bonus | Standard du marché ; réutilise le cours *Automatisation CI & monitoring* |
| DevSecOps | **gitleaks** (secrets), **Dependabot** + `npm audit` (dépendances), **Trivy** (images), **Semgrep** ou **CodeQL** (SAST), **OWASP ZAP** (DAST) ; **OWASP Juice Shop** comme cible d'entraînement ; présentation **Burp Suite, nmap, sqlmap, nikto** | Couvre « intégration de la sécurité tout au long du cycle » + « outils de pentest » + « tour des failles OWASP » |

---

## Projet fil rouge : TaskFlow

Application volontairement simple (le cœur du travail est le DevOps, pas le code) : **front** Vite + JS vanilla servi par Nginx, **API** Node 20 + Express + `pg`, **PostgreSQL 16**. Détails de l'API, des variables d'env et de la table : voir `tp/fil-rouge-taskflow/README.md`.

- `GET/POST /api/tasks`, `PATCH /api/tasks/:id/toggle`, `DELETE /api/tasks/:id`
- `GET /health` → `{ status, db, version, env }` (503 si la BDD est indisponible)
- Logs : une ligne JSON par requête sur stdout

**Starter** (`tp/fil-rouge-taskflow/starter/`) : code + tests + lint verts **+ Dockerfiles (api, front multi-stage) + `compose.yaml` de dev**. Aucun workflow, aucune config de déploiement, d'IaC, de monitoring ni de sécurité.

**Solution** (`tp/fil-rouge-taskflow/solution/`) : le starter + tout ce que l'apprenant ajoute pendant la semaine :

```
├── .github/
│   ├── workflows/ci.yml          # J2 : lint, tests (unitaires + intégration avec service postgres), build, matrix Node 20/22, cache, concurrency, couverture, artefact
│   ├── workflows/release.yml     # J3 : build & push ghcr.io → scan Trivy (bloquant sur CRITICAL) → deploy staging (auto) → deploy production (approbation) → smoke test ; rollback par workflow_dispatch
│   ├── workflows/iac.yml         # J4 : tofu fmt -check / validate / plan sur les PR qui touchent infra/
│   ├── workflows/security.yml    # J5 : gitleaks, npm audit, Semgrep (SAST), ZAP baseline (DAST) sur la stack lancée dans le job ; PR + hebdomadaire
│   ├── dependabot.yml            # J3 : npm (api, front), docker, github-actions
│   ├── pull_request_template.md · CODEOWNERS
├── ci-autres-outils/             # J2 : Jenkinsfile et .gitlab-ci.yml équivalents à ci.yml (lecture et comparaison)
├── compose.yaml                  # (fourni) dev
├── compose.prod.yaml             # J3 : db, api, front (images ghcr.io:${IMAGE_TAG}), proxy nginx 80/443
├── deploy/                       # J3 : nginx/taskflow.conf, gen-cert.sh, deploy.sh, backup.sh
├── infra/                        # J4 : OpenTofu — environnement « staging » (réseau, volume, conteneurs db/api/front depuis ghcr.io), variables, outputs
├── ansible/                      # J4 (bonus) : playbook local qui prépare ~/taskflow-prod (dossiers, .env depuis template, chmod 600, certificat)
├── monitoring/                   # J4 : compose.monitoring.yaml, prometheus (scrape + règles), blackbox, alertmanager, grafana provisionné (datasource + dashboard RED)
├── api/src/metrics.js            # J4 : prom-client (RED + métrique métier), route /metrics
├── front/nginx.conf              # J5 : en-têtes de sécurité (CSP, X-Content-Type-Options, Referrer-Policy, Permissions-Policy…)
├── .gitleaks.toml · .zap/rules.tsv · .semgrepignore (si utile)  # J5
└── docs/ ARCHITECTURE.md · DEPLOIEMENT.md · INCIDENTS.md · SECURITE.md
```

---

## Répartition horaire (31h30)

Horaires types : **9h00-12h30** / **13h30-17h00** (pauses incluses). Jour 5 : demi-groupe A le matin, demi-groupe B l'après-midi, **même séance de 3h30**.

| Module du syllabus | Volume | Placement |
|---|---|---|
| Introduction à la culture DevOps | 3h | J1 matin (+ 30 min d'accueil et vérification des postes) |
| Gestion de versions et collaboration | 4h30 | J1 après-midi (3h30) + J2 matin (1h) |
| Intégration continue (CI) | 6h | J2 matin (2h30) + J2 après-midi (3h30) |
| Déploiement continu (CD) | 6h | J3 matin (2h30) + J3 après-midi (3h30) |
| Infrastructure as Code | 4h30 | J4 matin (3h30) + J4 après-midi (1h) |
| Surveillance et retour d'information | 3h | J4 après-midi (2h30) + smoke tests / healthchecks du J3 (30 min) |
| DevSecOps | 4h30 | J3 matin (1h : sécurité du pipeline) + J5 (3h30) |

> **Fil conducteur :** *on n'automatise que ce qu'on sait faire à la main*, et *la sécurité commence dès le premier pipeline* (shift-left) : les secrets et les dépendances sont traités dès le J3, l'outillage complet arrive au J5.

---

## 📅 Jour 1 — Culture DevOps & collaboration Git

> **Objectif fin de journée :** l'apprenant sait expliquer ce que DevOps change (culture, flux, mesure), relier DevOps à Agile et Lean, et a contribué à un repo d'équipe en respectant un workflow pro (branche, PR, revue, protection de branche, conflit résolu).

### Matin — Culture DevOps (3h30)

- **Accueil et vérification des postes (30 min)** : tour de table, programme de la semaine, `ressources/setup-poste.md` (Git, clé SSH GitHub, Docker, Node, OpenTofu, Ansible).
- **Bloc 1.1 — Pourquoi DevOps ? (40 min)** : le mur de la confusion Dev/Ops, histoire (Agile 2001, Debois 2009, *The Phoenix Project*), CALMS, la boucle infinie, « you build it, you run it ».
- **Exercice 1 — Étude de cas « La Fromagerie » (30 min)** → `tp/tp0-cartographie-pipeline/` partie A : lister les problèmes d'une équipe qui déploie en FTP le vendredi soir et les classer selon CALMS.
- **Bloc 1.2 — Agile, Lean et DevOps (40 min)** : Agile (itérations, feedback) → DevOps (prolonge l'agilité jusqu'à la prod) ; Lean : 7 gaspillages appliqués au logiciel, flux, WIP, **value stream mapping**, lead time vs temps de traitement ; Scrum/Kanban en deux slides ; les « Three Ways » (flux, feedback, apprentissage continu).
- **Exercice 2 — Value stream mapping (30 min)** : cartographier le flux « idée → prod » de La Fromagerie, calculer lead time et taux d'efficacité, proposer 3 améliorations.
- **Bloc 1.3 — Mesurer : DORA et bénéfices (20 min)** : les 4 métriques DORA (fréquence de déploiement, lead time des changements, taux d'échec, temps de restauration), bénéfices chiffrés, CI / livraison continue / déploiement continu (première définition, approfondie au J3), panorama des outils de la semaine.
- **Exercice 3 — Cartographier le pipeline cible de TaskFlow (20 min)** → `tp0` partie B, restitution rapide.

### Après-midi — TP 1 : Git en équipe (3h30)

- **Bloc 2.1 — Git pour travailler en équipe (30 min, rappel rapide)** : modèle mental (working dir / index / commit / remote), branches = pointeurs, Conventional Commits, `.gitignore`, `git log --graph`. **Démo** `demos/demo-git-branches/`.
- **Bloc 2.2 — Workflows d'équipe (30 min)** : GitHub Flow vs Git Flow vs trunk-based (et lien avec la CI) ; PR, revue de code (quoi regarder, commenter avec bienveillance, *conventional comments*) ; protection de branche / rulesets, CODEOWNERS.
- **TP 1 — Projet collaboratif (2h15)** → `tp/tp1-git-collaboratif/` : par équipes de 3-4, un repo partagé ; branche par fonctionnalité, PR avec template, **revue obligatoire par un pair**, ruleset sur `main`, conflit **provoqué** puis résolu ; **démo** `demos/demo-git-conflit/`.
- **Débrief (15 min)** : ce qui a coincé, lien avec la CI de demain.

**Exercices** : `exercices/jour1/` (VSM, lire un historique, réparer ses erreurs : `restore`, `reset`, `revert`, `reflog`).

---

## 📅 Jour 2 — Git avancé & intégration continue

> **Objectif fin de journée :** chaque PR et chaque push sur `main` de TaskFlow déclenche un pipeline GitHub Actions (lint + tests unitaires + tests d'intégration avec Postgres + build) qui protège `main` ; l'apprenant sait lire un `Jenkinsfile` et un `.gitlab-ci.yml` équivalents.

### Matin

- **Bloc 2.3 — Historique propre et versions (45 min)** : `rebase` vs `merge`, rebase interactif (squash, reword), règle d'or, `pull --rebase` ; SemVer, tags annotés, releases GitHub, CHANGELOG. **Exercice** `exercices/jour2/` (rebase interactif).
- **Mise en place du fil rouge (15 min)** → `tp/fil-rouge-taskflow/etape0-mise-en-place.md` : créer son repo `taskflow` depuis le starter, ruleset sur `main`, `docker compose up` ; **rappel Docker express** (image / conteneur / Dockerfile / compose, en lisant les fichiers fournis).
- **Bloc 3.1 — L'intégration continue (45 min)** : intégrer souvent, build reproductible, tests automatiques, feedback rapide, « on ne laisse pas `main` rouge » ; pyramide des tests ; ce qu'un pipeline CI doit contenir ; avantages chiffrés.
- **Bloc 3.2 — GitHub Actions (45 min)** : workflow, événement, job, step, runner, action ; `on: push / pull_request`, `needs`, `services`, `matrix`, `cache`, `concurrency`, artefacts, `$GITHUB_STEP_SUMMARY`, permissions du `GITHUB_TOKEN`. **Démo** `demos/demo-actions-hello/`. **Exercices** : YAML cassé à corriger, choisir le bon déclencheur, lire un log de CI en échec.
- **Bloc 3.3 — Jenkins et GitLab CI (15 min de slides + démo)** → `demos/demo-jenkins-gitlab/` : architecture (controller / agents, runners), `Jenkinsfile` déclaratif, `.gitlab-ci.yml` (stages, jobs, `rules`, `services`, cache, artefacts) ; tableau de correspondance avec GitHub Actions ; quand choisir quoi.

### Après-midi — TP fil rouge, étape 1 : CI (3h30)

→ `tp/fil-rouge-taskflow/etape1-ci.md`
- `ci.yml` : lint + tests api (repository mémoire) ; tests d'intégration avec un **service Postgres** ; lint + tests + build front ; artefact `dist/`
- Optimiser : cache npm, `matrix` Node 20/22, `concurrency`, `paths`, `timeout-minutes`
- Couverture de tests dans le résumé du job (seuil bloquant)
- Ruleset : checks requis + 1 revue ; PR volontairement cassée → bloquée → corrigée
- **Comparer** : écrire (ou compléter) le `Jenkinsfile` et le `.gitlab-ci.yml` équivalents dans `ci-autres-outils/` (bonus : lancer Jenkins en conteneur via la démo)

---

## 📅 Jour 3 — Déploiement continu & sécurité du pipeline

> **Objectif fin de journée :** un merge sur `main` construit les images, les scanne, les publie, déploie **staging** automatiquement puis **production après approbation** ; un rollback est possible en un clic ; aucun secret n'est dans Git.

### Matin

- **Bloc 4.1 — Livrer et déployer (45 min)** : **livraison continue** (toujours déployable, décision humaine) vs **déploiement continu** (sans humain) ; artefact immuable « build once, deploy many » ; environnements dev / staging / prod ; configuration par l'environnement (12-factor) ; registre d'images et tags (SHA vs `latest`).
- **Bloc 4.2 — Stratégies de déploiement (45 min)** : recreate, rolling, **blue/green**, **canary**, feature flags ; rollback vs roll forward ; migrations de BDD compatibles (expand/contract) ; smoke tests et healthchecks (lien avec le monitoring) ; push (SSH depuis le CI) vs pull (runner self-hosted, GitOps, Watchtower). **Exercice** : choisir une stratégie pour 4 scénarios.
- **Bloc 4.3 — Outils et pratiques (30 min)** : GitHub Environments (règles de protection, approbation, secrets par environnement) ; runner self-hosted (démarrage en démo) et ses risques (socket Docker) ; déploiement sur un vrai serveur (SSH, `demos/demo-ssh-serveur/`), PaaS, Kubernetes/ArgoCD (cité). **Exercice** : corriger une conf Nginx de reverse proxy.
- **Bloc 7.1 — DevSecOps (1) : sécuriser le pipeline (1h)** : shift-left ; **secrets** (ne jamais committer, `.env` hors Git, secrets GitHub, rotation ; **gitleaks** en pre-commit et sur l'historique) ; **supply chain** (Dependabot, `npm audit`, actions épinglées par SHA, permissions minimales du `GITHUB_TOKEN`) ; **scan d'image Trivy**. **Démo** `demos/demo-trivy-gitleaks/`. **Exercice** : trouver le secret caché dans un historique Git, puis le purger et faire la rotation.

### Après-midi — TP fil rouge, étape 2 : CD (3h30)

→ `tp/fil-rouge-taskflow/etape2-cd.md`
- **Partie A — Déploiement manuel (1h)** : créer `~/taskflow-prod/`, `.env` (chmod 600), certificat auto-signé, `docker compose -f compose.prod.yaml up -d` → `https://taskflow.localhost` ; comprendre chaque geste avant de l'automatiser.
- **Partie B — Pipeline de release (1h30)** : `release.yml` : build & push ghcr.io (tags SHA + `latest`) → **Trivy** (échoue sur CRITICAL) → job `deploy-staging` (runner self-hosted, environment `staging`) → smoke test `/health` → job `deploy-production` (environment `production` avec approbation = **livraison continue** ; sans approbation = **déploiement continu**).
- **Partie C — Rollback et Dependabot (45 min)** : `workflow_dispatch` avec input `tag` ; casser volontairement une release (smoke test rouge) et revenir en arrière ; `dependabot.yml`.
- **Débrief (15 min)** : quel temps entre merge et prod ? (lien avec DORA)

---

## 📅 Jour 4 — Infrastructure as Code & monitoring

> **Objectif fin de journée :** l'environnement staging de TaskFlow est décrit en code (OpenTofu), vérifié dans le CI ; TaskFlow expose ses métriques, Prometheus/Grafana les affichent, une alerte se déclenche quand l'API tombe, et un incident a été analysé jusqu'au post-mortem et à l'issue d'amélioration.

### Matin — Infrastructure as Code (3h30)

- **Bloc 5.1 — Pourquoi l'IaC (30 min)** : snowflake servers, dérive de configuration, reproductibilité, revue de code de l'infra ; déclaratif vs impératif ; provisioning (Terraform/OpenTofu, Pulumi, CloudFormation) vs configuration (Ansible, Chef, Puppet) ; immuable vs mutable.
- **Bloc 5.2 — OpenTofu / Terraform (1h)** : providers, ressources, variables, outputs, `init` / `plan` / `apply` / `destroy`, **state** (et pourquoi il ne va pas dans Git ; backends distants et verrou), drift, modules. **Démo** `demos/demo-opentofu-docker/` (provider Docker). Exemple équivalent AWS en lecture seule.
- **Exercices OpenTofu (45 min)** → `exercices/jour4/` : déployer un Nginx avec variables et output, provoquer un drift (`docker rm` à la main) et le corriger avec `plan`/`apply`, lire un plan.
- **Bloc 5.3 — Ansible (30 min)** : inventaire, playbook, modules, idempotence, handlers, templates Jinja2, Vault (cité). **Démo** `demos/demo-ansible-local/`.
- **Exercice Ansible (30 min)** : playbook local qui prépare un dossier de déploiement (idempotence vérifiée en relançant).
- **Synthèse (15 min)** : Terraform pour *créer*, Ansible pour *configurer* ; où mettre l'IaC dans le pipeline (fmt / validate / plan sur PR, apply contrôlé).

### Après-midi

- **TP fil rouge, étape 3 : IaC (1h)** → `etape3-iac.md` : `infra/` OpenTofu crée l'environnement staging de TaskFlow (réseau, volume, conteneurs db/api/front depuis les images ghcr.io du J3) ; `iac.yml` (fmt, validate, plan en commentaire de PR ou dans le résumé). Bonus : playbook Ansible qui prépare `~/taskflow-prod`.
- **Bloc 6.1 — Surveiller et apprendre (30 min)** : logs / métriques / traces ; méthodes RED et USE ; Prometheus (pull, PromQL), Grafana, alerting, SLI/SLO (cités) ; boucle de feedback : alerte → incident → post-mortem sans blâme → issue → amélioration du pipeline. **Démo** `demos/demo-prometheus-grafana/`.
- **TP fil rouge, étape 4 : monitoring et retour d'information (2h)** → `etape4-monitoring.md` :
  - Instrumenter l'API (`prom-client`, route `/metrics`), test unitaire de la route
  - `monitoring/compose.monitoring.yaml` : Prometheus (scrape api + blackbox sur `/health`), Grafana provisionné (dashboard RED), Alertmanager + règle `TaskFlowApiDown`
  - Analyser les logs JSON avec `jq` (top des routes, erreurs 5xx, latence)
  - **Incident** : `incident/declencher-incident.sh` → alerte → diagnostic (logs, métriques) → correction → post-mortem dans `docs/INCIDENTS.md` → **issue GitHub** d'amélioration (ex. : ajouter un test qui aurait détecté l'incident)

---

## 📅 Jour 5 — DevSecOps (demi-groupe A le matin, demi-groupe B l'après-midi, 3h30 chacun)

> **Objectif fin de séance :** l'apprenant connaît le Top 10 OWASP, a exploité des failles sur une cible d'entraînement, sait à quoi servent les outils de pentest, et TaskFlow a un workflow de sécurité (secrets, dépendances, SAST, DAST) dont il a traité les résultats.

- **Bloc 7.2 — Sécurité tout au long du cycle (20 min)** : où placer chaque contrôle dans la boucle DevOps (plan : threat modeling ; code : SAST, secrets ; build : SCA, SBOM ; test : DAST ; release : signature ; operate : WAF, monitoring) ; SAST vs DAST vs SCA vs IAST ; faux positifs et triage.
- **Bloc 7.3 — Tour des failles OWASP Top 10 (45 min)** : chaque catégorie (contrôle d'accès, crypto, injection, conception non sûre, mauvaise configuration, composants vulnérables, authentification, intégrité, journalisation, SSRF) avec un exemple de code vulnérable, sa correction et l'outil qui la détecte.
- **Exercice — Chasse aux failles sur OWASP Juice Shop (40 min)** → `exercices/jour5/` : `docker run` Juice Shop en local, 5-6 défis guidés (injection SQL au login, XSS, contrôle d'accès cassé, données sensibles exposées…), chacun rattaché à sa catégorie OWASP.
- **Bloc 7.4 — Outils de pentest (25 min, démo comprise)** : méthodologie (reconnaissance, scan, exploitation, rapport), cadre légal (autorisation écrite, article 323-1 du Code pénal) ; **nmap**, **OWASP ZAP**, **Burp Suite**, **sqlmap**, **nikto** ; démo ZAP sur Juice Shop → `demos/demo-zap-juice-shop/`.
- **TP fil rouge, étape 5 : pipeline DevSecOps (55 min)** → `etape5-devsecops.md` : `security.yml` (gitleaks, `npm audit --audit-level=high`, Semgrep, ZAP baseline sur la stack lancée par Compose dans le job) ; lire les rapports, trier vrai / faux positif, **corriger** (en-têtes de sécurité dans `front/nginx.conf`, etc.), documenter les exceptions dans `docs/SECURITE.md`.
- **QCM (15 min)** → `evaluation/qcm.md`. *(Pause de 10 min incluse dans la séance.)*

---

## Évaluation

**Formative** : exercices du matin, quiz de fin de journée (5 questions dans les slides), validation de chaque étape du fil rouge par le formateur, revues de PR entre pairs.

**Sommative** — `evaluation/grille-evaluation.md` :
- **QCM** (20 questions, 15 min, fin de séance du J5) → `evaluation/qcm.md` (corrigé formateur : `evaluation/qcm-corrige.md`, jamais publié)
- **État final du repo TaskFlow** (100 points) :

| Bloc | Points |
|---|---|
| Collaboration Git (ruleset, PR revues, commits conventionnels, tag/release) | 15 |
| CI (lint, tests unitaires + intégration, build, cache/matrix, checks requis) | 20 |
| CD (images ghcr.io, staging auto, production avec approbation, smoke test, rollback) | 20 |
| IaC (OpenTofu staging fonctionnel, variables/outputs, `iac.yml`) | 15 |
| Monitoring (/metrics, Prometheus + Grafana provisionnés, alerte, post-mortem + issue) | 15 |
| DevSecOps (gitleaks, SCA, SAST, DAST, résultats triés et corrigés, `SECURITE.md`) | 15 |

## Livrables (par apprenant)

- le dépôt `taskflow` (historique propre, PR revues, release taguée) ;
- les workflows `ci.yml`, `release.yml`, `iac.yml`, `security.yml` verts ;
- la stack `taskflow-prod` déployée en HTTPS et la stack de monitoring ;
- `docs/ARCHITECTURE.md`, `DEPLOIEMENT.md`, `INCIDENTS.md`, `SECURITE.md`.

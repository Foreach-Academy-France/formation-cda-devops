# Formation DevOps — CDA

> 31h30 pour construire la chaîne DevOps complète d'une application : collaboration Git, intégration continue, déploiement continu, infrastructure as code, monitoring et sécurité.

**Public** : titre professionnel **Concepteur Développeur d'Applications** (CDA)
**Durée** : 4 jours × 7h + une demi-journée par demi-groupe (31h30)
**Institution** : ForEach Academy
**Formateur** : Fabrice Claeys
**Prérequis** : développement d'une application web (front + back + base de données) · Git et GitHub (commit, branche, push, PR) · bases de Docker et de Linux

📺 **Site de la formation (slides, TP en PDF)** : https://foreach-academy-france.github.io/formation-cda-devops/

---

## Objectifs pédagogiques

À l'issue du module, vous serez capable de :

- expliquer les principes et les bénéfices du DevOps, et leurs liens avec les méthodes Agile et Lean ;
- travailler en équipe avec Git : branches, pull requests, revues de code, protection de branche, historique propre ;
- mettre en place une intégration continue (GitHub Actions) et lire un pipeline Jenkins ou GitLab CI ;
- automatiser la livraison et le déploiement d'une application, en distinguant **livraison continue** et **déploiement continu** ;
- décrire une infrastructure en code (OpenTofu/Terraform, Ansible) ;
- surveiller une application (logs, métriques, alertes) et utiliser ces retours pour améliorer le cycle de développement ;
- intégrer la sécurité tout au long du pipeline (secrets, dépendances, SAST, DAST) et connaître les failles OWASP et les outils de pentest.

---

## Organisation

**Le matin** : cours en blocs courts (45 min max) et exercices de mise en situation.
**L'après-midi** : TP fil rouge encadré.
**Jour 5** : la classe est coupée en deux. Le demi-groupe A vient le matin, le demi-groupe B l'après-midi, pour la même séance de 3h30.

```
code → pull request → CI → images scannées → staging → production → monitoring → alerte → amélioration
```

### Projet fil rouge : TaskFlow

Un gestionnaire de tâches volontairement simple : **front** Vite (JavaScript) + **API** Node/Express + **PostgreSQL**. Les Dockerfiles et le `compose.yaml` de développement sont fournis. Toute la semaine, vous construisez autour de l'application.

| Étape | Jour | Ce que vous ajoutez au projet |
|-------|------|-------------------------------|
| 0 | J2 | Votre dépôt `taskflow`, ruleset sur `main`, application lancée avec Compose |
| 1 | J2 | `ci.yml` : lint, tests unitaires et d'intégration, build, matrix, cache, couverture, checks requis ; équivalents Jenkins et GitLab CI |
| 2 | J3 | Déploiement manuel, puis `release.yml` : images ghcr.io scannées par Trivy, staging automatique, production après approbation, rollback ; Dependabot |
| 3 | J4 | `infra/` : le staging décrit en OpenTofu, vérifié par `iac.yml` |
| 4 | J4 | `/metrics`, Prometheus, Grafana, alerte ; analyse d'un incident, post-mortem et issue d'amélioration |
| 5 | J5 | `security.yml` : gitleaks, npm audit, Semgrep, ZAP ; en-têtes de sécurité ; `SECURITE.md` |

**Stack** : Git & GitHub · Docker & Compose · GitHub Actions (Jenkins, GitLab CI en comparaison) · ghcr.io · Nginx · OpenTofu · Ansible · Prometheus · Grafana · Alertmanager · gitleaks · Trivy · Semgrep · OWASP ZAP · OWASP Juice Shop

**Tout tourne sur votre poste** : le staging et la « production » sont deux stacks Compose séparées. Un runner GitHub Actions self-hosted, en conteneur sur le poste, déploie à chaque merge.

Plan détaillé bloc par bloc : [plan-cours.md](./plan-cours.md)

---

## Programme

### Jour 1 : Culture DevOps & collaboration Git

| Horaire | Contenu |
|---------|---------|
| **MATIN — Culture DevOps** | |
| 9h00-9h30 | Accueil, vérification des postes |
| 9h30-10h40 | **Pourquoi DevOps ?** CALMS, boucle infinie · **Exercice** : étude de cas « La Fromagerie » |
| 10h50-12h00 | **Agile, Lean et DevOps** : gaspillages, flux, value stream mapping · **Exercice** : VSM |
| 12h00-12h30 | **Mesurer** : métriques DORA, CI / livraison / déploiement continus · **Exercice** : pipeline cible |
| **APRÈS-MIDI — Git en équipe** | |
| 13h30-14h30 | Rappel Git, workflows d'équipe (GitHub Flow, trunk-based), PR, revue, rulesets |
| 14h30-17h00 | **TP1 : projet collaboratif** : branches, PR, revue, conflit provoqué, débrief |

**Slides** : [Jour 1](./slides/jour1-culture-devops-git.md) · **TP** : [TP0](./tp/tp0-cartographie-pipeline/) · [TP1](./tp/tp1-git-collaboratif/) · **Exercices** : [jour 1](./exercices/jour1/)

### Jour 2 : Git avancé & intégration continue

| Horaire | Contenu |
|---------|---------|
| **MATIN** | |
| 9h00-10h00 | Rebase interactif, SemVer, tags, releases · mise en place du fil rouge et rappel Docker express |
| 10h00-12h30 | **Intégration continue** · **GitHub Actions** · Jenkins et GitLab CI · exercices (YAML cassé, déclencheurs, log en échec) |
| **APRÈS-MIDI** | |
| 13h30-17h00 | **Fil rouge, étape 1 : pipeline CI** |

**Slides** : [Jour 2](./slides/jour2-git-avance-ci.md) · **TP** : [Étape 0](./tp/fil-rouge-taskflow/etape0-mise-en-place.md) · [Étape 1](./tp/fil-rouge-taskflow/etape1-ci.md) · **Exercices** : [jour 2](./exercices/jour2/)

### Jour 3 : Déploiement continu & sécurité du pipeline

| Horaire | Contenu |
|---------|---------|
| **MATIN** | |
| 9h00-11h00 | **Livraison vs déploiement continu**, environnements, stratégies (blue/green, canary, rollback), GitHub Environments, runner self-hosted · exercices |
| 11h00-12h30 | **DevSecOps (1)** : secrets, gitleaks, Dependabot, Trivy · **Exercice** : le secret caché dans l'historique |
| **APRÈS-MIDI** | |
| 13h30-17h00 | **Fil rouge, étape 2 : déploiement manuel, pipeline de release, rollback** |

**Slides** : [Jour 3](./slides/jour3-cd-securite-pipeline.md) · **TP** : [Étape 2](./tp/fil-rouge-taskflow/etape2-cd.md) · **Exercices** : [jour 3](./exercices/jour3/)

### Jour 4 : Infrastructure as Code & monitoring

| Horaire | Contenu |
|---------|---------|
| **MATIN — Infrastructure as Code** | |
| 9h00-12h30 | Pourquoi l'IaC · **OpenTofu / Terraform** · **Ansible** · exercices (drift, idempotence) |
| **APRÈS-MIDI** | |
| 13h30-14h30 | **Fil rouge, étape 3 : le staging en OpenTofu** |
| 14h30-17h00 | **Surveiller et apprendre** · **Fil rouge, étape 4 : métriques, dashboards, alerte, incident et post-mortem** |

**Slides** : [Jour 4](./slides/jour4-iac-monitoring.md) · **TP** : [Étape 3](./tp/fil-rouge-taskflow/etape3-iac.md) · [Étape 4](./tp/fil-rouge-taskflow/etape4-monitoring.md) · **Exercices** : [jour 4](./exercices/jour4/)

### Jour 5 : DevSecOps (demi-groupe A 9h00-12h30, demi-groupe B 13h30-17h00)

| Durée | Contenu |
|-------|---------|
| 20 min | Sécurité tout au long du cycle : SAST, DAST, SCA, triage |
| 45 min | **Tour des failles de l'OWASP Top 10** |
| 40 min | **Exercice** : chasse aux failles sur OWASP Juice Shop |
| 25 min | **Outils de pentest** : nmap, ZAP, Burp Suite, sqlmap, nikto (démo) |
| 55 min | **Fil rouge, étape 5 : workflow de sécurité, corrections** |
| 15 min | **QCM** |

**Slides** : [Jour 5](./slides/jour5-devsecops.md) · **TP** : [Étape 5](./tp/fil-rouge-taskflow/etape5-devsecops.md) · **Exercices** : [jour 5](./exercices/jour5/)

> Fil conducteur : *on n'automatise que ce qu'on sait faire à la main* (déploiement manuel avant le pipeline), et *la sécurité commence dès le premier pipeline* (les secrets et les dépendances sont traités au jour 3).

---

## Couverture du syllabus

| Module | Durée | Placement | Mise en pratique |
|--------|-------|-----------|------------------|
| Introduction à la culture DevOps | 3h | J1 matin | Étude de cas, value stream mapping, pipeline cible |
| Gestion de versions et collaboration | 4h30 | J1 après-midi + J2 matin | TP1 collaboratif, rebase interactif, ruleset |
| Intégration continue | 6h | J2 | Étape 1 : `ci.yml`, Jenkinsfile, `.gitlab-ci.yml` |
| Déploiement continu | 6h | J3 | Étape 2 : staging auto, production avec approbation, rollback |
| Infrastructure as Code | 4h30 | J4 matin + début d'après-midi | Exercices OpenTofu / Ansible, étape 3 |
| Surveillance et retour d'information | 3h | J4 après-midi (+ smoke tests au J3) | Étape 4 : métriques, alerte, post-mortem → issue |
| DevSecOps | 4h30 | J3 (1h) + J5 (3h30) | Secret dans l'historique, Trivy, Juice Shop, étape 5 |

---

## Évaluation

- **Formative** : exercices du matin, quiz de fin de journée, validation des étapes du fil rouge, revues de PR entre pairs.
- **QCM** : 20 questions en fin de séance du jour 5 → [qcm.md](./evaluation/qcm.md)
- **État final du dépôt TaskFlow** (100 points) → [grille](./evaluation/grille-evaluation.md) : collaboration Git (15), CI (20), CD (20), IaC (15), monitoring (15), DevSecOps (15).

### Livrables attendus

- le dépôt `taskflow` : historique propre, PR revues, release taguée ;
- les workflows `ci.yml`, `release.yml`, `iac.yml` et `security.yml` au vert ;
- la stack `taskflow-prod` déployée en HTTPS, et la stack de monitoring ;
- `docs/ARCHITECTURE.md`, `DEPLOIEMENT.md`, `INCIDENTS.md` et `SECURITE.md`.

---

## Structure du dépôt

```
├── slides/          # Slides Marp, un fichier par jour
├── demos/           # Démos jouées en direct par le formateur
├── exercices/       # Exercices du matin, par jour (+ solutions)
├── tp/
│   ├── tp0-cartographie-pipeline/
│   ├── tp1-git-collaboratif/
│   └── fil-rouge-taskflow/   # Énoncés étape par étape + starter/ + solution/
├── evaluation/      # QCM, grille d'évaluation
└── ressources/      # Installation du poste, cheatsheets, glossaire, lab (runner GitHub Actions)
```

---

## Ressources

### Avant le jour 1
- [Installer son poste](./ressources/setup-poste.md) : Git, VS Code, Docker, Node 20, OpenTofu, Ansible, images à pré-télécharger

### Aide-mémoire
- [Git](./ressources/cheatsheet-git.md) · [Docker & Compose](./ressources/cheatsheet-docker.md) · [GitHub Actions](./ressources/cheatsheet-github-actions.md) · [Linux, SSH & Nginx](./ressources/cheatsheet-linux-ssh-nginx.md)
- [OpenTofu & Ansible](./ressources/cheatsheet-opentofu-ansible.md) · [Prometheus](./ressources/cheatsheet-prometheus.md) · [DevSecOps & OWASP](./ressources/cheatsheet-devsecops.md)
- [Glossaire](./ressources/glossaire.md)

### Documentation officielle
- [Pro Git (en français)](https://git-scm.com/book/fr/v2) · [GitHub Actions](https://docs.github.com/fr/actions) · [Jenkins](https://www.jenkins.io/doc/book/pipeline/) · [GitLab CI](https://docs.gitlab.com/ee/ci/)
- [OpenTofu](https://opentofu.org/docs/) · [Ansible](https://docs.ansible.com/) · [Prometheus](https://prometheus.io/docs/) · [Grafana](https://grafana.com/docs/)
- [OWASP Top 10](https://owasp.org/Top10/fr/) · [OWASP ZAP](https://www.zaproxy.org/docs/) · [OWASP Juice Shop](https://owasp.org/www-project-juice-shop/)

### Pour aller plus loin
- *The Phoenix Project* et *The DevOps Handbook*, Gene Kim et al.
- *Accelerate*, Nicole Forsgren, Jez Humble, Gene Kim
- [roadmap.sh/devops](https://roadmap.sh/devops) · [DORA](https://dora.dev/)

### Construire les slides en local

```bash
npm install
npm run slides:server   # aperçu live sur http://localhost:8080
npm run build           # HTML dans dist/
```

---

**2026 — Formation DevOps CDA — ForEach Academy**

# Grille d'évaluation — état final du dépôt TaskFlow

**Formation** : DevOps CDA (31h30) — ForEach Academy
**Évalué** : le dépôt `taskflow` de l'apprenant **à la fin de la séance du jour 5**, ses runs GitHub Actions et ses stacks locales (vérifiées en direct pendant les TP ou sur captures).
**Total** : 100 points + QCM /20 (voir [`qcm.md`](qcm.md)).

> **Comment noter.** Chaque critère vaut tout ou partie de ses points : ✅ atteint (100 %), ◐ partiel (50 %), ❌ absent (0).
> La question « **pourquoi ?** » est posée sur au moins un critère par bloc : un fichier copié de la solution sans
> savoir l'expliquer vaut ◐ au mieux. Un écart à la solution **justifié** par l'apprenant vaut ✅.

**Apprenant :** ______________________ **Dépôt :** `github.com/______________/taskflow`

---

## 1. Collaboration Git — 15 points

| Critère | Points | Comment vérifier | Note |
|---|---|---|---|
| Ruleset actif sur `main` : PR obligatoire, 1 revue, squash uniquement, checks requis | 5 | *Settings > Rules* ; `git push origin main` refusé | |
| PR relues par le binôme, avec description (quoi / pourquoi / comment vérifier) et au moins un commentaire de revue traité | 4 | onglet *Pull requests* (fermées) | |
| Historique de `main` lisible : messages Conventional Commits, pas de commit « wip » ou « fix fix » | 3 | `git log --oneline main` | |
| Une release taguée en SemVer (`v0.1.0` ou plus) avec notes | 3 | onglet *Releases* | |

## 2. Intégration continue — 20 points

| Critère | Points | Comment vérifier | Note |
|---|---|---|---|
| `ci.yml` se déclenche sur `pull_request` et `push` sur `main` ; dernier run vert | 4 | onglet *Actions* | |
| Lint + tests unitaires de l'API et du front ; build du front publié en artefact | 4 | jobs `api`, `front`, artefact `front-dist` | |
| Tests d'intégration contre un **service** PostgreSQL | 4 | job `api-integration`, tests non *skipped* dans le log | |
| Optimisations justifiées : cache npm, matrix Node 20/22, `concurrency`, `timeout-minutes` | 3 | lecture de `ci.yml` + question « pourquoi » | |
| Couverture dans le résumé du job, avec seuil bloquant | 2 | *Summary* d'un run | |
| Équivalents Jenkins et GitLab CI dans `ci-autres-outils/`, cohérents avec `ci.yml` | 3 | lecture, l'apprenant explique 2 correspondances | |

## 3. Déploiement continu — 20 points

| Critère | Points | Comment vérifier | Note |
|---|---|---|---|
| Images `taskflow-api` et `taskflow-front` publiées sur ghcr.io, taguées par SHA court | 4 | *Packages* du compte | |
| Scan Trivy **avant** la publication, bloquant sur CRITICAL | 3 | job `images` de `release.yml` | |
| Staging déployé automatiquement à chaque merge, smoke test vert | 4 | run *Release* + `curl localhost:8081/health` | |
| Production derrière l'approbation de l'environment `production` ; HTTPS sur `https://taskflow.localhost` | 4 | *Settings > Environments* ; run en attente d'approbation | |
| Rollback testé (`workflow_dispatch` avec un tag précédent) | 3 | run manuel dans l'historique | |
| `.env` hors Git, `dependabot.yml`, `docs/DEPLOIEMENT.md` à jour | 2 | `git ls-files`, fichiers | |

## 4. Infrastructure as Code — 15 points

| Critère | Points | Comment vérifier | Note |
|---|---|---|---|
| `infra/` crée le staging (réseau, volume, 3 conteneurs) ; `tofu plan` ne propose aucun changement après `apply` | 6 | `tofu plan` dans `STAGING_DIR` | |
| Variables (`image_tag`, `ghcr_owner`, `front_port`) et outputs ; aucun state ni `.terraform/` dans Git, lockfile versionné | 4 | lecture + `git ls-files infra/` | |
| `iac.yml` : `fmt -check`, `validate`, `plan` visible sur une PR qui touche `infra/` | 3 | une PR fermée avec le plan | |
| L'apprenant sait expliquer state, drift et la différence OpenTofu / Ansible (bonus Ansible : +1 dans la limite de 15) | 2 | question orale | |

## 5. Monitoring et retour d'information — 15 points

| Critère | Points | Comment vérifier | Note |
|---|---|---|---|
| L'API expose `/metrics` (RED + métrique métier), testée ; `/metrics` non joignable depuis le proxy | 3 | `curl -sk https://taskflow.localhost/metrics \| head -3` renvoie la page HTML du front (fallback SPA), jamais `# HELP …` | |
| Stack `monitoring/` : Prometheus (cibles UP), Grafana provisionné avec le dashboard RED | 4 | `localhost:9090/targets`, `localhost:3001` | |
| Règle d'alerte `TaskFlowApiDown` qui se déclenche et notifie | 3 | incident rejoué ou capture | |
| Post-mortem sans blâme dans `docs/INCIDENTS.md` (chronologie, cause, détection, actions) | 3 | fichier | |
| Issue d'amélioration ouverte (et idéalement PR liée) | 2 | onglet *Issues* | |

## 6. DevSecOps — 15 points

| Critère | Points | Comment vérifier | Note |
|---|---|---|---|
| `security.yml` : gitleaks, `npm audit`, Semgrep, ZAP baseline ; déclenché sur PR et planifié | 5 | fichier + dernier run | |
| Résultats traités : vulnérabilités corrigées (dépendances montées, en-têtes de sécurité dans `front/nginx.conf`) | 4 | run vert ou alertes restantes justifiées | |
| `docs/SECURITE.md` : triage vrai / faux positif, exceptions justifiées et datées | 3 | fichier | |
| Permissions minimales du `GITHUB_TOKEN` et actions épinglées dans les workflows ; gitleaks en pre-commit | 3 | lecture des workflows, `.pre-commit-config.yaml` | |

---

## Récapitulatif

| Bloc | Points | Note |
|---|---|---|
| 1. Collaboration Git | 15 | |
| 2. Intégration continue | 20 | |
| 3. Déploiement continu | 20 | |
| 4. Infrastructure as Code | 15 | |
| 5. Monitoring et retour d'information | 15 | |
| 6. DevSecOps | 15 | |
| **Total dépôt** | **100** | |
| QCM | 20 | |

**Note finale proposée /20** = (total dépôt / 100 × 16) + (QCM / 20 × 4) = ______

**Appréciation (points forts, axes de progrès) :**

&nbsp;

&nbsp;

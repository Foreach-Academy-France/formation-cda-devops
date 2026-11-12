# Travaux pratiques : vue d'ensemble

Ce dossier contient les énoncés des travaux pratiques (TP) de la formation DevOps CDA.
Chaque énoncé donne l'**objectif**, les **contraintes**, la commande clé de chaque étape, le résultat attendu et un
encadré « Si ça ne marche pas ». Il pose aussi des **questions de justification** : à votre niveau, on attend que vous
sachiez expliquer *pourquoi* votre pipeline est construit ainsi, pas seulement qu'il soit vert.

> **Règles de la semaine**
> 1. On n'automatise que ce qu'on sait faire à la main : chaque geste est fait une fois manuellement, puis confié au pipeline.
> 2. La sécurité commence dès le premier pipeline : aucun secret dans Git, permissions minimales, dépendances surveillées.

## Ordre et durée

| Quand | TP | Durée | Énoncé | Livrable |
|---|---|---|---|---|
| J1 matin | **TP 0** : étude de cas et pipeline cible | 30 + 20 min | [`tp0-cartographie-pipeline/`](tp0-cartographie-pipeline/README.md) | Problèmes de « La Fromagerie » classés CALMS + pipeline cible de TaskFlow |
| J1 après-midi | **TP 1** : projet Git collaboratif | 2h15 | [`tp1-git-collaboratif/`](tp1-git-collaboratif/README.md) | Ruleset sur `main`, une PR revue et fusionnée par personne, un conflit résolu |
| J2 matin | **Fil rouge, étape 0** : mise en place et rappel Docker | 15 min | [`etape0-mise-en-place.md`](fil-rouge-taskflow/etape0-mise-en-place.md) | Dépôt `taskflow`, ruleset, appli lancée avec Compose |
| J2 après-midi | **Fil rouge, étape 1** : intégration continue | 3h30 | [`etape1-ci.md`](fil-rouge-taskflow/etape1-ci.md) | `ci.yml` (checks requis), Jenkinsfile et `.gitlab-ci.yml` équivalents |
| J3 après-midi | **Fil rouge, étape 2** : déploiement continu | 3h30 | [`etape2-cd.md`](fil-rouge-taskflow/etape2-cd.md) | Prod manuelle en HTTPS, `release.yml` (Trivy, staging, production avec approbation, rollback), Dependabot |
| J4 après-midi | **Fil rouge, étape 3** : infrastructure as code | 1h | [`etape3-iac.md`](fil-rouge-taskflow/etape3-iac.md) | `infra/` OpenTofu (staging), `iac.yml` |
| J4 après-midi | **Fil rouge, étape 4** : monitoring et retour d'information | 2h | [`etape4-monitoring.md`](fil-rouge-taskflow/etape4-monitoring.md) | `/metrics`, `monitoring/`, alerte, post-mortem, issue d'amélioration |
| J5 | **Fil rouge, étape 5** : DevSecOps | 55 min | [`etape5-devsecops.md`](fil-rouge-taskflow/etape5-devsecops.md) | `security.yml`, en-têtes de sécurité, `docs/SECURITE.md` |

Les exercices du matin sont dans [`../exercices/`](../exercices/README.md).

## Le fil rouge en une image

```
J2  ruleset + ci.yml ───────────────▶ chaque PR : lint, tests (unitaires + intégration), build
                                              │ merge sur main
J3  release.yml ────────────────────▶ images ghcr.io ─▶ scan Trivy ─▶ staging (auto) ─▶ production (approbation)
                                              │                         ▲ runner self-hosted sur votre poste
J4  infra/ (OpenTofu) + iac.yml ────▶ le staging devient du code (plan sur PR)
J4  /metrics + monitoring/ ─────────▶ Prometheus ─▶ Grafana ─▶ alerte ─▶ post-mortem ─▶ issue ─▶ PR
J5  security.yml ───────────────────▶ gitleaks · npm audit · Semgrep · ZAP ─▶ corrections ─▶ SECURITE.md
```

## Livrables de fin de formation (par apprenant)

Ils sont évalués avec la grille [`../evaluation/grille-evaluation.md`](../evaluation/grille-evaluation.md) :

- [ ] un dépôt `taskflow` : ruleset sur `main`, PR relues, commits conventionnels, une release taguée ;
- [ ] `ci.yml`, `release.yml`, `iac.yml` et `security.yml` au vert ;
- [ ] le staging (OpenTofu) et la production (HTTPS) déployés par le pipeline, avec un rollback testé ;
- [ ] la stack de monitoring avec un dashboard et une alerte qui fonctionne ;
- [ ] `docs/ARCHITECTURE.md`, `docs/DEPLOIEMENT.md`, `docs/INCIDENTS.md` et `docs/SECURITE.md`.

> **Pour votre dossier professionnel CDA** : gardez des captures (PR revue, runs verts, approbation de déploiement,
> dashboard Grafana, rapport ZAP). Elles illustrent la préparation et l'exécution du déploiement d'une application.

## Vous êtes en retard ?

C'est prévu :

1. Chaque étape se termine par une checklist **« Je valide avec le formateur »** : faites valider avant de passer à la
   suite, même si tout n'est pas parfait.
2. Le dossier [`fil-rouge-taskflow/solution/`](fil-rouge-taskflow/solution/) contient la version finale de chaque
   fichier. La marche à suivre est dans [`fil-rouge-taskflow/README.md`](fil-rouge-taskflow/README.md#vous-êtes-en-retard--récupérer-un-fichier-de-la-solution).
3. Les aide-mémoire sont dans [`../ressources/`](../ressources/).

# Exercice 2.3 — Quel workflow se déclenche ?

| | |
|---|---|
| **Durée** | 10 min |
| **Bloc** | 3.2 — GitHub Actions (déclencheurs, filtres, `concurrency`) |
| **Prérequis** | démo `demo-actions-hello` |
| **Fichiers fournis** | aucun : les trois workflows sont ci-dessous |

## Situation

Voici les déclencheurs des trois workflows que TaskFlow aura en fin de semaine. Savoir prédire **quand** un workflow s'exécute, c'est savoir expliquer « pourquoi mon pipeline ne s'est pas lancé » ou « pourquoi ma PR est bloquée ».

```yaml
# .github/workflows/ci.yml (aujourd'hui)
name: CI
on:
  pull_request:
  push:
    branches: [main]
    paths-ignore:
      - "**.md"
      - "docs/**"
concurrency:
  group: ci-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

```yaml
# .github/workflows/release.yml (Jour 3, extrait simplifié)
name: Release
on:
  push:
    branches: [main]
    paths-ignore:
      - "**.md"
      - "docs/**"
  workflow_dispatch:
    inputs:
      tag:
        description: "Tag d'image à (re)déployer (ex. 3f2b9d1)"
        required: true
```

```yaml
# .github/workflows/security.yml (Jour 5, extrait simplifié)
name: Security
on:
  pull_request:
  schedule:
    - cron: "0 5 * * 1"
```

## Consignes

Pour chaque situation, indiquez le(s) workflow(s) déclenché(s) — `CI`, `Release`, `Security` ou **aucun** — et justifiez en une ligne.

| # | Situation | Workflow(s) | Justification |
|---|---|---|---|
| 1 | Vous poussez un commit sur `feature/filtre`, aucune PR ouverte. | | |
| 2 | Vous ouvrez une PR `feature/filtre` → `main`. | | |
| 3 | Vous poussez deux commits à 20 secondes d'intervalle sur la PR ouverte. Combien de runs CI vont **jusqu'au bout** ? | | |
| 4 | La PR (qui modifie `api/src/app.js`) est fusionnée. | | |
| 5 | Une PR qui ne modifie que `docs/DEPLOIEMENT.md` est ouverte. | | |
| 6 | Cette même PR est fusionnée. | | |
| 7 | Deux PR sont fusionnées à 30 secondes d'intervalle : combien de runs CI sur `main` vont jusqu'au bout ? | | |
| 8 | *Run workflow* sur « Release », tag `3f2b9d1`. | | |
| 9 | Lundi, 5 h 00 UTC. | | |
| 10 | `git push origin v1.2.0` (tag annoté). | | |

## Questions de justification

11. Pourquoi `paths-ignore` est-il sur `push` mais **pas** sur `pull_request` dans `ci.yml` ? Que se passerait-il pour la PR de la situation 5 si le filtre était aussi sur `pull_request`, sachant que les checks `api (20)`, `api (22)`, `api-integration` et `front` sont **requis** ?
12. Pourquoi annule-t-on les runs dépassés sur une PR mais jamais sur `main` ?
13. Le cron est en UTC. À quelle heure tourne `security.yml` à Paris en hiver, en été ? Pourquoi un audit de sécurité **planifié** en plus de celui des PR ?
14. Vous voulez publier une release GitHub à chaque tag `v*`. Quel déclencheur ajoutez-vous, et dans quel workflow ?

## Indices

<details>
<summary>Indice 1</summary>

`pull_request` sans filtre réagit à l'ouverture, à la réouverture et à **chaque nouveau commit** (`opened`, `reopened`, `synchronize`). Fusionner une PR = un **push sur `main`**. Un filtre `branches:` ne concerne pas les tags.
</details>

<details>
<summary>Indice 2</summary>

Un check requis qui ne s'exécute jamais n'est ni vert ni rouge : il reste « *Expected — Waiting for status to be reported* ». Un job **sauté** par une condition `if:`, lui, compte comme réussi.
</details>

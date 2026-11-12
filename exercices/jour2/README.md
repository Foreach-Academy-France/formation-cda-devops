# Jour 2 — Exercices : Git avancé et intégration continue

Exercices courts du matin, chacun rattaché à un bloc des slides du Jour 2. Ils préparent directement l'étape 1 du fil rouge (le `ci.yml` de TaskFlow).

| # | Exercice | Durée | Bloc | Fichiers fournis |
|---|---|---|---|---|
| 2.1 | [Préparer une branche pour la revue : rebase interactif, fixup, tag](01-rebase-interactif.md) | 20 min (+10 bonus) | 2.3 | [`rebase-setup.sh`](rebase-setup.sh) |
| 2.2 | [Le workflow cassé](02-yaml-a-corriger.md) | 15 min | 3.2 | [`yaml-a-corriger/ci-casse.yml`](yaml-a-corriger/ci-casse.yml) |
| 2.3 | [Quel workflow se déclenche ?](03-quel-declencheur.md) | 10 min | 3.2 | — |
| 2.4 | [Lire un log de CI en échec](04-lire-log-ci.md) | 15 min | 3.2 | [`logs-ci/`](logs-ci/) (3 logs + `ci-extrait.yml`) |
| 2.5 | [Traduire un workflow GitHub Actions en GitLab CI et en Jenkins](05-traduire-gha-gitlab-jenkins.md) | 25 min | 3.3 (TP étape 1.8 ou travail perso) | [`traduire/ci-catalogue.yml`](traduire/ci-catalogue.yml) |

**Corrigé :** [`solutions.md`](solutions.md) (et [`traduire/corrige/`](traduire/corrige/) pour l'exercice 2.5) — à ouvrir **après** avoir cherché.

## Avant de commencer

- Les fichiers de `yaml-a-corriger/` et `logs-ci/` sont **volontairement faux** : ne les copiez pas dans votre dépôt `taskflow`.
- actionlint en conteneur (aucune installation) : `docker run --rm -v "$PWD":/repo -w /repo docker.io/rhysd/actionlint:1.7.12 <fichier>`. Extension VS Code recommandée : *GitHub Actions* (`github.vscode-github-actions`).
- Les scripts `.sh` créent un dépôt Git jetable dans `/tmp` et affichent la commande de nettoyage.

# Jour 1 — Solutions des exercices

> À ouvrir **après** avoir cherché (et utilisé les indices). Lire une solution sans avoir essayé ne fait rien retenir.

---

## Exercice 1.1 — Classer des situations selon CALMS

Le pilier entre parenthèses est un second classement défendable.

| # | Pilier | +/− | Correction (pour les anti-patterns) |
|---|---|---|---|
| 1 | **C** (S) | + | — Post-mortem sans blâme, publié : culture de l'apprentissage et partage |
| 2 | **A** (S) | − | Automatiser le déploiement (pipeline) ; la procédure devient du code versionné et relu, que tout le monde peut lancer |
| 3 | **L** | + | — Limite de WIP, flux tiré : on finit avant de commencer |
| 4 | **C** (M) | − | Mesures **d'équipe**, jamais nominatives ; post-mortem sans blâme. Un classement pousse à cacher les bugs |
| 5 | **A** | + | — CI avec checks requis : le feedback est automatique |
| 6 | **M** | − | Mesurer les 4 métriques DORA (même dans un tableur au début) |
| 7 | **L** | − | Branches courtes, intégration quotidienne, *feature flags* pour livrer du code désactivé |
| 8 | **C** (S) | + | — Dev et Ops travaillent ensemble dès la conception |
| 9 | **A** (S) | − | Infrastructure as Code (OpenTofu, Ansible, J4) : les serveurs sont décrits, recréables, revus |
| 10 | **M** | + | — Indicateurs DORA visibles de tous, utilisés pour décider |
| 11 | **S** (C) | + | — Revue systématique et rotation : la connaissance circule, le *bus factor* augmente |
| 12 | **L** (A) | − | Tests automatisés en CI et petites livraisons fréquentes : la recette n'est plus un goulot de deux semaines |

**Question de réflexion** : les situations 4, 6 (un tableur suffit), 7 (une règle d'équipe sur la durée des branches),
12 (au moins en partie : réduire la taille des lots) et même 2 (écrire et partager la procédure, former un second
binôme) se corrigent **sans outil**. Les outils rendent une bonne pratique **durable et peu coûteuse**, ils ne la créent
pas : d'où « culture avant outils ».

---

## Exercice 1.2 — *Value stream mapping* de La Fromagerie

### La carte (état actuel)

```
 Patron ─▶ [1. Demande]  ▲  [2. Priorisation] ▲ [3. Dév.]  ▲ [4. Relecture] ▲ [5. Corrections] ▲ [6. Test]  ▲ [7. Mise en ligne] ─▶ Prod
           Julien        │  réunion mensuelle │  Sofia     │  Julien        │  Sofia           │  Julien    │  Julien, FTP
           PT 0,5 h      │  PT 1 h            │  PT 14 h   │  PT 1 h        │  PT 3 h          │  PT 2 h    │  PT 1,5 h
                         │                    │            │  %C/A 50 %     │                  │  %C/A 60 % │
 Attentes :            70 h                 21 h         28 h             7 h                14 h         49 h
```

| # | Étape | Temps de traitement | Attente **avant** l'étape |
|---|---|---|---|
| 1 | Prise de la demande (carnet) | 0,5 h | — |
| 2 | Priorisation en réunion mensuelle | 1 h | 10 j = 70 h |
| 3 | Développement | 14 h | 3 j = 21 h |
| 4 | Relecture (clé USB) | 1 h | 4 j = 28 h |
| 5 | Corrections | 3 h | 1 j = 7 h |
| 6 | Test manuel | 2 h | 2 j = 14 h |
| 7 | Mise en ligne FTP + colonne en base | 1,5 h | 7 j = 49 h |
| | **Total** | **23 h** | **189 h** |

### Les calculs

1. Σ temps de traitement = 0,5 + 1 + 14 + 1 + 3 + 2 + 1,5 = **23 h**.
2. Σ attentes = 70 + 21 + 28 + 7 + 14 + 49 = **189 h**.
3. **Lead time** = 23 + 189 = **212 h** = 212 / 7 ≈ **30,3 jours ouvrés** ≈ **6 semaines**.
4. **Efficacité du flux** = 23 / 212 ≈ **10,8 %** : la fonctionnalité passe près de 9 dixièmes de son temps à attendre.
5. Coder deux fois plus vite : 14 h → 7 h, lead time 212 → 205 h, soit **−3,3 %** seulement. Optimiser le
   développement ne sert presque à rien tant que les attentes restent.
6. La plus longue attente : **70 h** avant la réunion mensuelle de priorisation. Gaspillage **attente / délais**, causé
   par un **gros lot** (on trie tout une fois par mois). Juste derrière : 49 h d'attente de la fenêtre de mise en ligne
   mensuelle (même cause) et 28 h d'attente de relecture (indisponibilité d'une personne : *bus factor*).

### Trois améliorations (exemple de solution)

| Amélioration | Étape(s) | Gaspillage visé | Pratique / outil | Nouveau temps |
|---|---|---|---|---|
| A. Backlog visible (tableau Kanban / issues GitHub), priorisation **hebdomadaire** ou au fil de l'eau | 2 | Attente, gros lot | Kanban, GitHub Issues (J1) | attente 70 h → **7 h** |
| B. PR sur GitHub et accord d'équipe « on relit avant de commencer un nouveau sujet », relecteur de secours (CODEOWNERS à deux noms) | 4 | Attente, transfert (clé USB) | PR, revue, CODEOWNERS (J1) | attente 28 h → **2 h** |
| C. Pipeline CI/CD : tests automatiques sur chaque PR, déploiement automatique après merge, migration de base versionnée | 6, 7 | Attente, défauts, réapprentissage | `ci.yml` (J2), `release.yml` (J3) | test : PT 2 h → 0,2 h, attente 14 h → **0** ; mise en ligne : PT 1,5 h → 0,2 h, attente 49 h → **1 h** |

**État futur** avec A + B + C :

| | Avant | Après |
|---|---|---|
| Σ traitement | 23 h | 0,5 + 1 + 14 + 1 + 3 + 0,2 + 0,2 = **19,9 h** |
| Σ attentes | 189 h | 7 + 21 + 2 + 7 + 0 + 1 = **38 h** |
| Lead time | 212 h (≈ 30 j) | **57,9 h** (≈ 8,3 j ouvrés), divisé par **3,7** |
| Efficacité | 10,8 % | 19,9 / 57,9 ≈ **34 %** |

En ajoutant une **limite de WIP** pour Sofia (attente avant développement 21 h → 3,5 h) et des corrections enchaînées
dans la foulée de la revue (7 h → 1 h) : attentes = 14,5 h, lead time = **34,4 h** (≈ 4,9 jours ouvrés), efficacité
≈ **58 %**.

### Justification attendue

- **Meilleur rapport gain / effort** : A (priorisation plus fréquente) : −63 h sans aucun outil, une simple décision
  d'organisation. B est aussi quasi gratuit.
- **Changement de culture plutôt qu'outil** : A, B et la limite de WIP. Seule C demande vraiment de l'outillage (et
  c'est la plus longue à mettre en place : c'est la semaine de formation).
- **Risques** : déployer plus souvent **sans** tests automatiques augmenterait le taux d'échec ; c'est pourquoi C
  regroupe tests **et** déploiement. Une revue « sous 2 h » faite à la va-vite perd son intérêt : la PR doit rester
  petite. Prioriser au fil de l'eau sans limite de WIP recrée des changements de contexte.

### Pour aller plus loin

1. En cas d'échec : 6 h de restauration + 2 h de correction + 140 h d'attente de la fenêtre suivante = 148 h de plus.
   Lead time moyen attendu = 212 + 0,5 × 148 = **286 h** (≈ 41 jours ouvrés, plus de 8 semaines). Vous avez estimé le
   **taux d'échec des changements** (50 %) et le **temps de restauration** (6 h), et montré leur effet sur le **délai** :
   les métriques DORA de stabilité pèsent sur le débit.
2. %C/A cumulé = 0,5 × 0,6 = **30 %** : 7 fonctionnalités sur 10 reviennent en arrière au moins une fois. Tester
   **avant** la relecture (CI verte avant la revue humaine) évite de faire relire du travail qui sera de toute façon
   renvoyé : c'est exactement l'ordre « CI puis revue » de la PR.

---

## Exercice 1.3 — Lire un historique Git

### Partie 1

1. **9 commits**. `HEAD -> main`, sur `fd16415`.
2. **`3b7627e Merge branch 'feature/health'`** ; parents : `057cd1f` (côté `main`, premier parent) et `24df34a`
   (dernier commit de `feature/health`, second parent).
3. `057cd1f chore: ajoute le .gitignore`.
4. **Fast-forward** : `main` et `fix/titre-page` pointent sur le **même** commit `fd16415` et il n'existe aucun commit
   « Merge branch 'fix/titre-page' ».
5. `v1.0.0` (sur `fd16415`) **contient** `/health` (`f1f8d16` est un ancêtre via le merge) ; **pas** le Dockerfile
   (`93db9eb` est un descendant, pas un ancêtre).
6. `feature/docker` ; oui, fast-forward : elle part de `fd16415`, qui est toujours le sommet de `main`.
7. `feature/health` et `fix/titre-page`.
8. « Fonctionnalités » : `f1f8d16 feat(api): ajoute la route GET /health` et `8f17968 feat(api): crée l'application
   Express`. « Corrections » : `fd16415 fix(front): corrige le titre de la page`. Les `chore:`, `test:` et le commit de
   fusion n'apparaissent pas (ou dans une section « Divers »).
9. En squash, le commit de fusion est remplacé par **un commit ordinaire `S` à un seul parent** (`057cd1f`), qui
   contient les changements de `f1f8d16` + `24df34a`. `main` a alors **5 commits** en ligne droite :
   `20bc9b4 → 8f17968 → 057cd1f → S → fix(front)` (ce dernier, et ceux au-dessus, ont un **nouveau SHA**, puisque leur
   parent a changé). Les deux commits de `feature/health` ne sont **pas** des ancêtres de `main` : `git branch --merged`
   ne la liste plus, et `git branch -d feature/health` refuse (il faut `-D`). C'est le piège classique après un
   *Squash and merge* sur GitHub : on supprime la branche avec le bouton *Delete branch*, ou avec `-D` en local.

### Partie 2

```console
$ git log --oneline main..feature/docker        # dans feature/docker, pas dans main
93db9eb build(api): ajoute un Dockerfile
$ git log --oneline feature/docker..main        # l'inverse : rien
$ git log --oneline --first-parent main          # 5 lignes : la vue « PR par PR »
fd16415 fix(front): corrige le titre de la page
3b7627e Merge branch 'feature/health'
057cd1f chore: ajoute le .gitignore
8f17968 feat(api): crée l'application Express
20bc9b4 chore: initialise le projet TaskFlow
$ git merge-base main feature/docker             # = sommet de main → fast-forward possible
fd16415eb53d05b4e5d41e7c9ad2ccd6b8e4b550
$ git log -S "/health" --oneline --all
24df34a test(api): teste la route /health
f1f8d16 feat(api): ajoute la route GET /health
$ git log -1 --format=%P 3b7627e                 # les deux parents
057cd1f… 24df34a…
$ git branch --merged main
  feature/health
  fix/titre-page
* main
```

**Question de réflexion** : avec des squash, `main` est linéaire, `git log` et `git log --first-parent` donnent le même
résultat. Avec des commits de fusion, `--first-parent` ne suit que le premier parent de chaque fusion (le côté `main`) :
on obtient une ligne par PR fusionnée, ce qui rend lisible un historique riche en branches **sans perdre** le détail des
commits, toujours accessible.

---

## Exercice 1.4 — Réparer ses erreurs

Commandes validées sur le dépôt créé par `reparer-setup.sh` :

```bash
# Cas 1 — working dir
echo "n'importe quoi" > README.md
git status && git diff
git restore README.md

# Cas 2 — index
echo "mes notes" > notes-perso.txt
git add .
git restore --staged notes-perso.txt
rm notes-perso.txt

# Cas 3 — amend : fichier oublié + message
echo 'npm ci && npm test' > docs/INSTALL.md
echo 'Voir docs/INSTALL.md' >> README.md
git add README.md && git commit -m "docs: decsription de l'installation"
git add docs/INSTALL.md
git commit --amend -m "docs: décrit l'installation"
git log --oneline -2                      # un seul commit docs:, nouveau SHA

# Cas 4 — reset --soft : regrouper deux commits locaux
git switch -c feature/tri
echo '// tri' >> api/src/app.js && git commit -am "wip"
echo '// tri 2' >> api/src/app.js && git commit -am "wip encore"
git reset --soft HEAD~2                   # la branche recule, les changements restent dans l'index
git commit -m "feat(api): trie les tâches par date"
git switch main

# Cas 5 — commit fait sur main par erreur
echo 'mode sombre' >> README.md && git commit -am "feat(front): ajoute le mode sombre"
git status -sb                            # ## main...origin/main [ahead 2]
git branch feature/mode-sombre            # une étiquette de plus sur ce commit
git reset --hard HEAD~1                   # main recule ; le commit vit sur la branche

# Cas 6 — revert d'un commit déjà poussé
git log --oneline                         # repérer le SHA de « change le port par défaut »
git revert <sha>                          # (ou --no-edit) crée un commit inverse
git push                                  # pousse aussi le commit docs: du cas 3
git log --oneline -4                      # 1 commit ajouté par le revert ; config.js : ?? 3000

# Cas 7 — reflog
git reset --hard HEAD~2                   # la catastrophe
git reflog                                # HEAD@{1}: revert: Revert "feat(api): change le port…"
git reset --hard HEAD@{1}                 # retour à l'état d'avant
git branch -D feature/export              # Deleted branch feature/export (was dcb9964).
git branch feature/export dcb9964         # le SHA affiché par -D, ou retrouvé dans `git reflog`
git log --oneline --graph --all
git status -sb                            # ## main...origin/main (plus d'avance ni de retard)
```

**Cas 5, variante** : `git switch -c feature/mode-sombre` puis `git switch main && git reset --hard HEAD~1` donne le même
résultat. `--mixed` à la place de `--hard` aurait reculé `main` mais laissé la modification de `README.md` dans le
répertoire de travail : il aurait fallu un `git restore` en plus.

**Questions de réflexion**

1. `--amend` et `reset` **remplacent** ou **retirent** des commits : si ces commits sont déjà sur GitHub, l'historique
   local et le distant divergent, et publier exige un *force push* qui efface le travail fondé dessus. Vos collègues
   verraient au `git pull` une fusion inattendue ou des commits « en double ». `revert` **ajoute** un commit : personne
   n'a rien à réécrire.
2. Toute réécriture de commits **déjà présents** sur `main` (amend, reset suivi d'un push forcé, rebase de `main`) est
   refusée par *Block force pushes*. Ce n'est pas un problème, c'est le but : sur une branche partagée, on corrige par
   `revert` (ou par une nouvelle PR), jamais en réécrivant. Sur **votre** branche de PR, réécrire reste permis
   (`--force-with-lease`, J2).
3. Le reflog ne contient que ce qui a été **commité** (ou au moins mis en stash) **dans ce clone** : une modification
   jamais commitée effacée par `reset --hard` ou `restore` est perdue ; un commit fait sur le poste d'un collègue
   n'est pas dans **votre** reflog ; et les entrées expirent (90 jours par défaut, 30 pour les commits devenus
   inaccessibles).

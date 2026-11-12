# Exercice 1.4 — Réparer ses erreurs : `restore`, `reset`, `revert`, `reflog`

| | |
|---|---|
| **Durée** | 25 min (seul) |
| **Bloc** | 2.1 — Le modèle mental (4 zones), commit / branche / HEAD |
| **Prérequis** | Git ≥ 2.28 |
| **Fichiers fournis** | [`reparer-setup.sh`](reparer-setup.sh) : crée un dépôt TaskFlow jetable **et** un faux GitHub (dépôt *bare*) dans `/tmp` |

## Objectif

Savoir choisir **la bonne commande d'annulation selon la zone où se trouve l'erreur** et selon que le travail est
**déjà partagé** ou non, et retrouver un commit qu'on croit perdu.

| L'erreur est… | Partagée ? | Commande |
|---|---|---|
| dans le répertoire de travail | non | `git restore <fichier>` |
| dans l'index | non | `git restore --staged <fichier>` |
| dans le **dernier** commit | non | `git commit --amend` |
| dans les **N derniers** commits | non | `git reset --soft` / `--mixed` / `--hard HEAD~N` |
| dans un commit **déjà poussé** | **oui** | `git revert <sha>` |
| « j'ai tout perdu » | — | `git reflog`, puis `git switch -c` ou `git reset --hard <sha>` |

| `git reset …` | Déplace la branche | Vide l'index | Écrase le répertoire de travail |
|---|---|---|---|
| `--soft` | oui | non | non |
| `--mixed` (défaut) | oui | oui | non |
| `--hard` | oui | oui | **oui** (irréversible pour ce qui n'a jamais été commité) |

## Mise en place

```bash
bash reparer-setup.sh
cd <chemin affiché>/taskflow
git log --oneline --graph --all
```

Vous êtes sur `main`, à jour avec `origin/main` (3 commits). Une branche locale `feature/export` (2 commits) n'a jamais
été poussée.

## Consignes

Faites les cas **dans l'ordre** : chacun part de l'état laissé par le précédent. Après chaque cas, `git status` doit être
propre et vous notez la commande utilisée.

### Cas 1 — « J'ai massacré un fichier » (working dir)

1. `echo "n'importe quoi" > README.md`, puis constatez avec `git status` et `git diff`.
2. Retrouvez la version du dernier commit.

### Cas 2 — « J'ai ajouté le mauvais fichier » (index)

3. Créez `notes-perso.txt`, puis `git add .`.
4. Retirez **uniquement** `notes-perso.txt` de l'index, sans le supprimer du disque. Supprimez-le ensuite.

### Cas 3 — « Faute de frappe et fichier oublié dans mon dernier commit » (amend)

5. Créez `docs/INSTALL.md` (une ligne : `npm ci && npm test`) et modifiez `README.md` (ajoutez une ligne
   `Voir docs/INSTALL.md`). Commitez **seulement** `README.md` avec le message `docs: decsription de l'installation`.
6. En **un seul** nouveau geste, ajoutez le fichier oublié **et** corrigez le message en
   `docs: décrit l'installation`. Vérifiez qu'il n'y a qu'un seul commit `docs:` et que son SHA a changé.

### Cas 4 — « Mes commits sont illisibles » (reset --soft)

7. Créez une branche `feature/tri`. Faites deux commits successifs nommés `wip` et `wip encore` (modifiez n'importe quel
   fichier de `api/src/`). Le hook du TP 1 les refuserait : ici, on les fait quand même.
8. Remplacez ces deux commits par **un seul** commit `feat(api): trie les tâches par date`, **sans perdre** les
   modifications. Revenez sur `main`.

### Cas 5 — « J'ai commité sur `main` au lieu d'une branche »

9. Sur `main`, ajoutez une ligne dans `README.md` et commitez `feat(front): ajoute le mode sombre`. `git status` vous
   dit que `main` est **en avance** de deux commits sur `origin/main` (celui du cas 3 et celui-ci).
10. Déplacez ce commit sur une nouvelle branche `feature/mode-sombre` et remettez `main` sur le commit précédent (celui
    du cas 3, qu'on garde). Le commit « mode sombre » doit exister sur la branche, et plus sur `main`.

### Cas 6 — « Le commit est déjà sur GitHub et il casse tout » (revert)

11. Le commit `feat(api): change le port par défaut` (déjà poussé) a introduit un bug. Annulez-le **sans réécrire
    l'historique**, puis poussez.
12. `git log --oneline -4` : combien de commits a-t-on ajouté ? Que contient `api/src/config.js` ?

### Cas 7 — « J'ai tout perdu » (reflog)

13. Catastrophe : lancez `git reset --hard HEAD~2` sur `main`. Le revert et le commit `docs:` ont « disparu ».
    Retrouvez l'état d'avant **avec `git reflog`** et revenez-y.
14. Ménage trop rapide : `git branch -D feature/export` (la branche n'était pas fusionnée). Recréez-la avec ses deux
    commits.

## Résultat attendu

```text
$ git log --oneline --graph --all
* 16df0a0 (feature/mode-sombre) feat(front): ajoute le mode sombre
| * e063a69 (feature/tri) feat(api): trie les tâches par date
|/
| * 4395eef (HEAD -> main, origin/main) Revert "feat(api): change le port par défaut"
|/
* 67ad4ce docs: décrit l'installation
| * dcb9964 (feature/export) test(api): teste l'export CSV
| * 031bddf feat(api): ajoute l'export CSV des tâches
|/
* 249b6f8 feat(api): change le port par défaut
* 88b744a feat(api): ajoute la route /health
* 456ec19 chore: initialise le projet TaskFlow
```

(Vos SHA seront différents, sauf ceux des trois premiers commits et de `feature/export`, créés par le script avec
des dates fixes ; l'ordre des colonnes peut varier.) `api/src/config.js` contient de nouveau `?? 3000`, `git status` est
propre et `main` est identique à `origin/main`.

> **Si ça ne marche pas**
> - Cas 6 : le push envoie aussi le commit `docs:` du cas 3 : c'est normal, il n'avait jamais été poussé. Si le push
>   est refusé (`non-fast-forward`), vous avez réécrit un commit **déjà poussé** : `git log origin/main..main` et
>   `git log main..origin/main` pour comprendre.
> - Cas 7 : `git reflog` est long ; cherchez la ligne **juste avant** `reset: moving to HEAD~2`.
> - Vous avez fait pire que prévu : relancez `reparer-setup.sh`, c'est fait pour.

## Indices

<details>
<summary>Indice 1 — cas 1, 2 et 3</summary>

Lisez ce qu'écrit `git status` : il **donne** les commandes `git restore` et `git restore --staged`. Pour le cas 3 :
`git add` du fichier oublié, puis `git commit --amend -m "…"`.
</details>

<details>
<summary>Indice 2 — cas 4 et 5</summary>

Cas 4 : `git reset --soft HEAD~2` ramène la branche deux commits en arrière en gardant tout dans l'index ; il ne reste
qu'à commiter. Cas 5 : une branche n'est qu'une étiquette : posez-en une nouvelle sur le commit actuel
(`git branch feature/mode-sombre`), puis ramenez l'étiquette `main` un commit en arrière (`git reset --hard HEAD~1` : sans danger ici, le commit est
désormais porté par la nouvelle branche).
</details>

<details>
<summary>Indice 3 — cas 6 et 7</summary>

Cas 6 : `git log --oneline` pour trouver le SHA, puis `git revert <sha>`. Cas 7 : `HEAD@{1}` désigne « où était HEAD
juste avant le dernier mouvement » ; `git branch -D` affiche le SHA de la branche supprimée (`was …`), et le reflog de
`HEAD` garde la trace des commits faits sur cette branche.
</details>

## Questions de réflexion

1. Pourquoi `git commit --amend` et `git reset` sont-ils dangereux sur des commits **déjà poussés**, alors que
   `git revert` ne l'est pas ? Que verraient vos collègues au `git pull` suivant ?
2. Le ruleset du TP 1 bloque les *force pushes* sur `main`. Parmi les commandes de cet exercice, lesquelles deviennent
   **impossibles à publier** sur `main` ? Est-ce un problème ?
3. Le reflog est **local** et expire (90 jours par défaut). Qu'est-ce qu'il ne peut **pas** vous rendre ?

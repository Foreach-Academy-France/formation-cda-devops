# Exercice 2.1 — Préparer une branche pour la revue : rebase interactif, fixup, tag

| | |
|---|---|
| **Durée** | 20 min (+ 10 min de bonus) |
| **Bloc** | 2.3 — Historique propre et versions |
| **Prérequis** | Git ≥ 2.38 ; savoir quitter l'éditeur de Git (voir encadré) |
| **Fichier fourni** | [`rebase-setup.sh`](rebase-setup.sh) |

## Situation

Vous avez travaillé deux jours sur `feature/tri-taches`. L'historique ressemble à votre journée : `wip`, `fix typo`, un fichier de debug commité par erreur… et pendant ce temps, `main` a avancé. Avant d'ouvrir la PR, vous voulez que votre relecteur lise **une histoire claire** : un commit par intention, au-dessus du `main` actuel, chaque commit valide.

> **Règle d'or** : on ne réécrit que **sa** branche, **pas encore partagée** (ou partagée avec l'accord explicite de ceux qui l'utilisent). Jamais `main`.

```bash
bash exercices/jour2/rebase-setup.sh
cd <chemin affiché par le script>
git log --oneline --graph --all
```

> **Éditeur** : `git config --global core.editor "code --wait"` (VS Code) ou `nano`. Dans la liste du rebase, le commit le plus **ancien** est **en haut** (l'inverse de `git log`).

## Consignes

### Partie A — Nettoyer et rebaser (15 min)

1. Inspectez la branche **avant** de toucher à quoi que ce soit : `git log --stat main..feature/tri-taches`, puis `git log -p` sur les commits douteux. Combien de commits la branche a-t-elle de retard sur `main` ? Quels commits forment **une seule** intention ? Lequel n'aurait jamais dû exister ?
2. En **une seule** commande `git rebase -i`, obtenez exactement deux commits au-dessus du `main` actuel :
   - `feat(api): trie les tâches par statut` (le tri, sans les étapes intermédiaires) ;
   - `docs: documente le tri dans le README` (inchangé) ;
   - et plus aucune trace de `debug.js`.
3. Vérifiez que **chaque** commit de la branche est valide (le fichier JavaScript se lit sans erreur de syntaxe), sans les vérifier à la main un par un : cherchez l'option `--exec` de `git rebase`.
4. Fusionnez dans `main` (ici en local, sans GitHub) : quel type de fusion obtenez-vous, et pourquoi ? Que donnerait
   *Squash and merge* sur GitHub pour cette branche ?

### Partie B — Versionner (5 min)

5. Le tri est une **nouvelle fonctionnalité compatible** : la version précédente était `v1.3.2`. Quel numéro SemVer donnez-vous ? Posez un **tag annoté** sur `main` avec un message utile, puis affichez-le avec `git show --no-patch <tag>`.
6. Rédigez l'entrée de `CHANGELOG.md` correspondante (format *Keep a Changelog*, sans date).
7. **Release GitHub** : le dépôt jetable n'a pas de remote, la release se fait sur **votre** dépôt `taskflow`, à
   l'étape 1.7 d du TP cet après-midi (`git push origin <tag>` puis `gh release create <tag> --generate-notes`).
   Préparez dès maintenant : quelle différence entre un tag, une release GitHub et une entrée de CHANGELOG ? Qui lit quoi ?

### Bonus — `fixup!` et `--autosquash` (10 min)

8. Votre relecteur demande de renommer la variable `tasks` en `sortedTasks` dans le commit `feat(api)`. Faites la modification, puis créez un commit **ciblé** : `git commit --fixup=<sha du commit feat>`. Regardez son message.
9. Intégrez-le sans éditer la liste à la main : `git rebase -i --autosquash main` (la liste est déjà réordonnée : enregistrez simplement). Vérifiez avec `git log --oneline` qu'il reste deux commits.
10. Bonus du bonus : `git config --global rebase.autoSquash true` et `git config --global rerere.enabled true`. À quoi sert la seconde ?

## Résultat attendu

```text
* 140bb23 (HEAD -> main, tag: v1.4.0, feature/tri-taches) docs: documente le tri dans le README
* f8d2348 feat(api): trie les tâches par statut
* ced80c7 feat(front): client API fetchTasks
* 5217edd chore: ajoute le .gitignore
* a6641d8 feat(api): liste des tâches
```

Historique **linéaire**, `debug.js` absent de **tous** les commits (`git log --all -- debug.js` ne renvoie plus rien : les anciens commits ne sont plus atteignables que par le reflog), le tri présent dans `api/src/app.js`, `front/src/api.js` (venu de `main`) présent.

## Indices

<details>
<summary>Indice 1 — les mots-clés</summary>

`pick` garde · `reword` garde et change le message · `squash` fusionne avec le précédent et combine les messages · `fixup` fusionne et jette le message · `drop` supprime · `exec` lance une commande après le commit précédent.
</details>

<details>
<summary>Indice 2 — la liste à obtenir</summary>

```text
reword <sha> wip
fixup  <sha> tri des taches par statut (non terminées d'abord)
fixup  <sha> fix typo
pick   <sha> docs: documente le tri dans le README
drop   <sha> oups, fichier de debug
```

Et pour vérifier chaque commit : `git rebase -i main --exec "node --check api/src/app.js"`.
</details>

<details>
<summary>Indice 3 — en cas de souci</summary>

Perdu au milieu : `git rebase --abort`. Mauvais résultat validé : `git reflog` puis `git reset --hard <ancienne position>` (d'où l'intérêt d'un dépôt jetable).
</details>

## Questions de justification

1. La branche avait déjà été poussée et votre binôme l'a récupérée pour tester. Que se passe-t-il après votre rebase ? Quelle commande pour pousser, et pourquoi `--force-with-lease` plutôt que `--force` ?
2. Le ruleset de `main` (TP 1, repris pour TaskFlow) n'autorise que « *Squash and merge* » : chaque PR devient **un** commit sur `main`, dont le message est le titre de la PR. Pourquoi alors se donner la peine d'un rebase interactif sur sa branche ? (pensez au relecteur, à `--exec`, au conflit avec `main`) Dans quel cas l'équipe préférerait-elle autoriser *Rebase and merge* ?
3. Le ruleset de `main` exige que la branche soit **à jour** avant le merge (*Require branches to be up to date*). Quel lien avec ce que vous venez de faire ? Quel coût pour une équipe de 10 personnes ?

# Cheatsheet Git — travailler en équipe

> Les 4 zones : **répertoire de travail** → `git add` → **index** → `git commit` → **dépôt local** → `git push` →
> **distant** (GitHub). Un commit = un instantané + son (ses) parent(s) ; une branche = une étiquette sur un commit ;
> `HEAD` = « vous êtes ici ».

## Configurer une fois par poste

```bash
git config --global user.name "Prénom Nom"
git config --global user.email "votre-email-github@exemple.fr"
git config --global init.defaultBranch main
git config --global merge.conflictStyle zdiff3            # conflits avec l'ancêtre commun
git config --global alias.lg "log --oneline --graph --all --decorate"
git config --global core.editor "code --wait"             # facultatif
```

## Le quotidien

| Commande | Effet |
|---|---|
| `git status` / `git status -sb` | Où j'en suis (version courte : branche, avance/retard sur le distant) |
| `git diff` / `git diff --staged` | Changements non indexés / indexés (ce qui partira au commit) |
| `git add -p` | Choisir les morceaux à indexer, un par un |
| `git commit -m "feat(api): ajoute la pagination"` | Enregistrer un commit |
| `git fetch` puis `git log origin/main` | Voir le distant **sans** toucher à vos fichiers |
| `git pull` / `git push -u origin ma-branche` | Récupérer + intégrer / envoyer (`-u` la première fois) |
| `git switch -c feature/x` / `git switch main` | Créer et basculer / changer de branche |
| `git stash` / `git stash pop` | Mettre de côté / reprendre des changements non commités |

## Conventional Commits

```
<type>(<portée>)<!>: <description à l'impératif, en minuscules, ≤ 72 caractères>

<corps : POURQUOI>

<pied : BREAKING CHANGE: …   Refs: #42   Closes #42>
```

Types : `feat` (→ MINEUR), `fix` (→ CORRECTIF), `feat!` / `BREAKING CHANGE:` (→ MAJEUR), `docs`, `style`, `refactor`,
`perf`, `test`, `build`, `ci`, `chore`, `revert`. Hook local : `git config core.hooksPath .githooks` (TP 1).

## Lire l'historique

| Question | Commande |
|---|---|
| Le graphe complet | `git log --oneline --graph --all` (ou `git lg`) |
| Ce que ma branche a de plus que `main` | `git log --oneline main..feature/x` |
| L'historique de `main` « PR par PR » | `git log --oneline --first-parent main` |
| Les branches déjà fusionnées | `git branch --merged main` (une branche **squashée** n'y apparaît pas) |
| Le point de départ commun | `git merge-base main feature/x` |
| Quand cette chaîne est apparue / a disparu | `git log -S "DATABASE_URL" --oneline` |
| Qui a écrit ces lignes | `git blame -L 10,20 fichier` |
| Le détail d'un commit, ses parents | `git show <sha>` · `git log -1 --format=%P <sha>` |

## Fusionner

| Stratégie | Commande locale | Bouton GitHub | Résultat |
|---|---|---|---|
| Fast-forward | `git merge feature/x` (si `main` n'a pas bougé) | — | `main` avance, aucun commit ajouté |
| Commit de fusion | `git merge --no-ff feature/x` | *Create a merge commit* | Un commit à 2 parents |
| Squash | `git merge --squash feature/x && git commit` | *Squash and merge* | **Un** commit ordinaire, message = titre de la PR |
| Rebase (J2) | `git rebase main` puis fast-forward | *Rebase and merge* | Les commits rejoués en ligne droite |

Après un squash : `git branch -D feature/x` (`-d` refuse, c'est normal).

## Conflits

```
<<<<<<< HEAD
  votre version (branche courante)
||||||| ancêtre commun             ← avec zdiff3
  la version d'origine
=======
  la version qui arrive
>>>>>>> main
```

| Étape | Commande |
|---|---|
| Quels fichiers ? | `git status` (`UU` = à résoudre) |
| Quels commits en cause ? | `git log --merge --oneline` |
| Après édition : plus de marqueur ? | `git diff --check` |
| Valider la résolution | `git add <fichier>` puis `git commit --no-edit` (merge) ou `git rebase --continue` |
| Tout annuler | `git merge --abort` / `git rebase --abort` |

Conflit **textuel** (deux ajouts) : souvent garder les deux. Conflit **sémantique** (deux intentions) : décider **avec**
l'autre auteur, écrire la décision dans la PR, faire relire.

## Annuler (du plus doux au plus brutal)

| Situation | Commande | Sûr sur une branche partagée ? |
|---|---|---|
| Fichier modifié, pas encore indexé | `git restore fichier` | — (local) |
| Fichier indexé par erreur | `git restore --staged fichier` | — (local) |
| Corriger le **dernier** commit (message, oubli) | `git add oubli && git commit --amend` | Non |
| Défaire N commits, garder les changements **indexés** | `git reset --soft HEAD~N` | Non |
| Défaire N commits, garder les changements **non indexés** | `git reset HEAD~N` (`--mixed`) | Non |
| Défaire N commits **et** les changements | `git reset --hard HEAD~N` (irréversible pour le non-commité) | Non |
| Annuler un commit **déjà poussé** | `git revert <sha>` (crée un commit inverse) | **Oui** |
| Annuler une PR fusionnée | Bouton *Revert* sur la PR (crée une PR inverse) | **Oui** |
| Commit fait sur `main` par erreur | `git branch feature/x && git reset --hard origin/main` | — |
| « J'ai tout perdu » | `git reflog` puis `git reset --hard HEAD@{1}` ou `git branch secours <sha>` | — |
| Branche supprimée trop vite | `git branch nom <sha>` (SHA affiché par `branch -D`, ou dans `git reflog`) | — |

## GitHub : PR, revue, protection

| Besoin | Où / commande |
|---|---|
| Ouvrir une PR | `gh pr create --fill` (ou `--title "feat: …"`), `--draft` si pas prête |
| Relire | `gh pr checkout <n>` · `gh pr review <n> --approve` / `--request-changes -b "…"` / `--comment -b "…"` |
| Fusionner | `gh pr merge <n> --squash --delete-branch` |
| Fermer une issue au merge | `Closes #42` dans la description de la PR |
| Protéger `main` | *Settings → Rules → Rulesets* : PR obligatoire, 1 approbation, Code Owners, conversations résolues, squash, *Block force pushes*, checks requis (J2) ; *bypass list* vide |
| Voir les règles actives | `gh ruleset list` · `gh ruleset check main` |
| Qui relit quoi | `.github/CODEOWNERS` : `chemin @pseudo1 @pseudo2` (le **dernier** motif qui correspond gagne ; **au moins deux** propriétaires) |
| Modèle de description | `.github/pull_request_template.md` |

**Conventional comments** : `praise:` · `issue (blocking):` · `suggestion (non-blocking):` · `question:` · `nitpick:` ·
`todo:` · `thought:`. Proposer du code : bloc ` ```suggestion ` dans un commentaire de ligne.

## Rebase (J2)

| Commande | Effet |
|---|---|
| `git fetch && git rebase origin/main` | Rejoue **vos** commits au-dessus de la dernière `main` |
| `git rebase -i HEAD~3` | Réécrire les 3 derniers commits (`squash`, `reword`, `drop`, `fixup`) |
| `git pull --rebase` | `pull` sans commit de fusion |
| `git push --force-with-lease` | Pousser une branche **personnelle** rebasée (jamais `main`) |

> **Règle d'or : on ne réécrit jamais une branche que d'autres utilisent.**

## Tags et versions (J2)

`vMAJEUR.MINEUR.CORRECTIF` : `fix` → `v1.0.1`, `feat` → `v1.1.0`, rupture → `v2.0.0`.
`git tag -a v1.0.0 -m "…"` · `git push origin v1.0.0` · `gh release create v1.0.0 --generate-notes`.

## .gitignore et secrets

```gitignore
node_modules/
dist/
coverage/
.env
*.log
```

`git check-ignore -v .env` (pourquoi est-il ignoré ?) · `git rm --cached fichier` (arrêter de suivre un fichier déjà commité).

## Pièges fréquents

- **Commiter un secret** : le supprimer ensuite ne suffit pas (historique, clones, forks). **Révoquez-le et changez-le**
  immédiatement ; outillage (gitleaks) au J3.
- **Travailler sur `main`** : `git switch -c ma-branche` avant de commiter (les changements suivent).
- **`git reset --hard`** et **`git clean -fd`** détruisent sans corbeille ce qui n'a jamais été commité.
- **`git branch -d` refuse après un squash** : normal ; vérifiez que la PR est fusionnée, puis `-D`.
- **L'approbation disparaît** après un push : règle *Dismiss stale approvals* ; redemandez une revue.
- **`HEAD detached`** : vous êtes sur un commit, pas une branche ; `git switch -c nom` pour garder le travail.
- **`git add .` sans `git status`** : `node_modules`, `.env` ou fichiers de sauvegarde partent dans le commit.

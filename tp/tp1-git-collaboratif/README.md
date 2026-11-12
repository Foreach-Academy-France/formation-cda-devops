# TP 1 : Git en équipe, comme en entreprise

> **Durée** : 2h15 (jour 1 après-midi, pause et démo conflit incluses) | **Format** : équipes de 3 ou 4 (variante solo en fin d'énoncé)
> **Objectif** : faire vivre un dépôt d'équipe avec les règles d'une équipe professionnelle : **ruleset** sur `main`,
> **CODEOWNERS**, **template de PR**, **Conventional Commits** vérifiés, **revue en *conventional comments***, fusion en
> **squash**, et deux conflits **provoqués** puis résolus (un textuel, un sémantique).

Vous connaissez déjà `branch`, `commit`, `push` et la PR simple : on ne refait pas les bases. L'énoncé donne
l'objectif, les contraintes et la commande clé ; à vous de trouver le chemin dans l'interface de GitHub.

---

## Ce dont vous avez besoin

- Git ≥ 2.40 configuré et une clé SSH sur GitHub (`ssh -T git@github.com` répond `Hi <pseudo>!`).
- Un éditeur ; `gh` (GitHub CLI) est conseillé (commandes données en option).
- Le site de départ : [`starter/`](starter/) (site statique « Promo CDA », `CONTRIBUTING.md`, template de PR, hook `commit-msg`).
- L'antisèche : [`../../ressources/cheatsheet-git.md`](../../ressources/cheatsheet-git.md).
- Réglage conseillé pour la journée : `git config --global merge.conflictStyle zdiff3`.

**Rôles** (à décider maintenant) :

| Rôle | Qui | Responsabilités |
|---|---|---|
| **Mainteneur** | 1 personne | Crée le dépôt, configure le ruleset et les réglages, écrit `CODEOWNERS` |
| **Contributeurs** | les autres | Relisent la PR `CODEOWNERS`, contribuent comme le mainteneur |
| **Rédacteurs A et B** (étape 8) | 2 personnes, dont au moins un contributeur | Proposent chacun un nouveau titre pour le site |

Tout le monde, mainteneur compris, ajoute sa carte. Dans les commandes, remplacez `<mainteneur>` par le pseudo GitHub du
mainteneur et `<prenom>` par **votre** prénom, en minuscules, sans accent.

## Déroulé

| # | Étape | Durée | Horaire indicatif |
|---|---|---|---|
| 1 | Création du dépôt et invitations | 10 min | 14h30 |
| 2 | Ruleset sur `main` et réglages de fusion | 15 min | 14h40 |
| 3 | `CODEOWNERS`, livré par une première PR relue | 15 min | 14h55 |
| 4 | Hook, branche, carte, commits conventionnels | 15 min | 15h10 |
| 5 | Pull Request avec le template | 10 min | 15h25 |
| — | *Pause* | 10 min | 15h35 |
| 6 | Revue croisée en *conventional comments* | 20 min | 15h45 |
| — | 🎬 Démo conflit (formateur, `demos/demo-git-conflit/`) | 10 min | 16h05 |
| 7 | Squash and merge en série : conflit **textuel** | 15 min | 16h15 |
| 8 | Conflit **sémantique** provoqué | 15 min | 16h30 |

---

## Étape 1 : créer le dépôt (10 min)

**Mainteneur.** Depuis le dossier de la formation :

```bash
cp -r tp/tp1-git-collaboratif/starter ~/site-promo
cd ~/site-promo
git init -b main
git add . && git commit -m "chore: initialise le site Promo CDA"
gh repo create site-promo --public --source=. --push
```

> Sans `gh` : créez un dépôt **public** vide (ni README, ni `.gitignore`) sur GitHub, puis
> `git remote add origin git@github.com:<mainteneur>/site-promo.git && git push -u origin main`.

Invitez les membres : **Settings → Collaborators → Add people** (ou `gh api -X PUT repos/<mainteneur>/site-promo/collaborators/<pseudo>`).
**Contributeurs** : acceptez l'invitation (`https://github.com/<mainteneur>/site-promo/invitations`), puis clonez :

```bash
git clone git@github.com:<mainteneur>/site-promo.git ~/site-promo && cd ~/site-promo
```

**Résultat attendu** : chaque membre a un clone ; `git log --oneline` affiche un seul commit ; `ls -a` montre `.github/`
et `.githooks/`.

> **Si ça ne marche pas**
> - `Permission denied (publickey)` : votre clé SSH n'est pas sur GitHub (`ressources/setup-poste.md`, section 2).
> - `Repository not found` au clone : l'invitation n'est pas acceptée, ou le pseudo est mal orthographié.
> - Le dépôt **doit être public** : les rulesets sont gratuits sur les dépôts publics, payants sur les dépôts privés.

## Étape 2 : protéger `main` avec un ruleset (15 min)

**Mainteneur**, avec les autres membres qui regardent l'écran. Deux réglages : le **ruleset**, puis les **méthodes de
fusion** du dépôt.

**2.1 — Ruleset.** **Settings → Rules → Rulesets → New ruleset → New branch ruleset** :

| Champ / règle | Valeur |
|---|---|
| *Ruleset name* | `protection-main` |
| *Enforcement status* | **Active** |
| *Bypass list* | **vide** (personne ne contourne, administrateurs compris) |
| *Target branches* | *Add target → Include default branch* |
| *Restrict deletions*, *Block force pushes* | cochées |
| *Require a pull request before merging* | cochée, avec : *Required approvals* **1** ; *Dismiss stale pull request approvals when new commits are pushed* ; *Require review from Code Owners* ; *Require conversation resolution before merging* ; *Allowed merge methods* : **Squash** uniquement |
| *Require status checks to pass* | **pas encore** : il n'y a pas de CI (ce sera demain, sur TaskFlow) |

**2.2 — Réglages de fusion.** **Settings → General → Pull Requests** : décochez *Allow merge commits* et *Allow rebase
merging* ; gardez *Allow squash merging* avec *Default commit message* = **Pull request title** ; cochez
*Automatically delete head branches*.

**2.3 — Vérifier que la règle mord.**

```bash
git commit --allow-empty -m "test: push direct"
git push
```

**Résultat attendu** :

```console
remote: error: GH013: Repository rule violations found for refs/heads/main.
remote: - Changes must be made through a pull request.
 ! [remote rejected] main -> main (push declined due to repository rule violations)
```

Puis supprimez ce commit, qui n'existe que chez vous : `git reset --hard origin/main`.

> Avec `gh` : `gh ruleset list` et `gh ruleset check main` affichent les règles qui s'appliquent à `main`.

> **Si ça ne marche pas**
> - Le push **passe** : le ruleset n'est pas *Active*, ne cible pas la branche par défaut, ou votre rôle figure dans la
>   *bypass list*. Corrigez, puis annulez le commit poussé **par une PR** (`git revert`) : on ne réécrit pas `main`.
> - Pas de menu *Rules* : vous n'êtes pas administrateur du dépôt, ou le dépôt est privé sur un compte gratuit.

**Questions de justification** (à noter pour le débrief) :

1. Pourquoi une *bypass list* vide, alors que le mainteneur est « de confiance » ?
2. *Dismiss stale approvals* va vous faire perdre du temps à l'étape 7. Quel risque cette règle couvre-t-elle ?
3. Pourquoi n'autoriser que le **squash** ? Que perd-on par rapport à un commit de fusion ?

## Étape 3 : `CODEOWNERS`, par une première PR (15 min)

**Mainteneur** : sur une branche `chore/codeowners`, créez `.github/CODEOWNERS`. Contrainte : **chaque chemin a au
moins deux propriétaires** (sinon un propriétaire unique ne pourra jamais faire fusionner ses propres changements).
Exemple pour une équipe Alice (mainteneuse), Bob, Chloé :

```text
# Le DERNIER motif qui correspond l'emporte.
*                  @alice @bob
/.github/          @alice @bob
/CONTRIBUTING.md   @alice @chloe
/index.html        @bob @chloe
/style.css         @chloe @alice
/cartes/           @alice @bob @chloe
```

```bash
git switch -c chore/codeowners
# créer .github/CODEOWNERS avec les vrais pseudos GitHub
git add .github/CODEOWNERS
git commit -m "chore: ajoute CODEOWNERS"
git push -u origin chore/codeowners
gh pr create --fill --reviewer <pseudo-d-un-contributeur>
```

**Un contributeur** relit et approuve (il vérifie notamment la règle « au moins deux propriétaires »). Le mainteneur
fusionne en **Squash and merge**. Tout le monde : `git switch main && git pull`.

**Résultat attendu** : sur GitHub, en ouvrant `.github/CODEOWNERS`, aucun avertissement (*This CODEOWNERS file is
valid*) ; `git log --oneline main` montre `chore: ajoute CODEOWNERS (#1)`.

> **Si ça ne marche pas**
> - GitHub souligne un pseudo en rouge dans le fichier : faute de frappe, ou la personne n'a pas encore accepté
>   l'invitation (un propriétaire doit avoir un accès en **écriture**).
> - Le titre du commit squashé n'est pas conventionnel : le réglage *Default commit message* de l'étape 2.2 n'est pas
>   appliqué ; corrigez le titre dans la boîte de dialogue avant de confirmer.

> **Pourquoi par une PR ?** Parce que `main` est déjà protégée : même la configuration du dépôt passe par la revue.
> C'est le principe « tout est code, tout est relu ».

## Étape 4 : hook, branche, carte (15 min)

**Tout le monde.**

```bash
git switch main && git pull
git config core.hooksPath .githooks          # active la vérification des messages
git switch -c feature/carte-<prenom>
cp cartes/exemple.html cartes/<prenom>.html
```

1. Personnalisez votre carte (titre, initiale, nom, rubriques, étiquettes).
2. Ajoutez **une** ligne dans la liste `<ul class="promo">` de `index.html`, **juste au-dessus du commentaire** (tout le
   monde au même endroit : c'est voulu).
3. Faites **au moins deux commits** séparés et conventionnels (par exemple la carte, puis le lien sur l'accueil).
   Essayez d'abord un message non conforme pour voir le hook refuser.

**Résultat attendu** :

```console
$ git commit -m "ajout carte"
✖ Message refusé : il ne respecte pas Conventional Commits.
$ git log --oneline main..HEAD
4f5e6d7 (HEAD -> feature/carte-alice) feat(accueil): ajoute le lien vers la carte d'Alice
8c1d2e4 feat(cartes): ajoute la carte d'Alice
```

> **Si ça ne marche pas**
> - Le hook ne se déclenche pas : `git config core.hooksPath` doit afficher `.githooks` ; sous Windows, travaillez
>   dans WSL ; vérifiez que le fichier est exécutable (`ls -l .githooks/commit-msg`, sinon `chmod +x`).
> - La carte s'affiche sans style : le lien vers la feuille doit rester `../style.css`.

## Étape 5 : la Pull Request (10 min)

```bash
git push -u origin feature/carte-<prenom>
gh pr create --title "feat: ajoute la carte de <Prénom>"     # gh ouvre votre éditeur avec le template
```

(ou le bouton **Compare & pull request**, qui pré-remplit aussi la description avec le template). Complétez **toutes** les rubriques du template : *Pourquoi*, *Quoi*,
*Comment vérifier*, checklist.

**Résultat attendu** : GitHub a **automatiquement** ajouté les propriétaires de `index.html` et de `cartes/` comme
relecteurs ; l'encadré de fusion affiche *Review required* et *Code owner review required* ; le bouton est grisé.

> **Pourquoi ?** Le titre de la PR deviendra le seul message visible dans `main` (squash) : c'est lui qui doit être
> parfait. La description sert au relecteur **et** à celui qui lira l'historique dans six mois.

## Étape 6 : revue croisée en *conventional comments* (20 min)

Organisez-vous pour que **chacun relise au moins une PR** dont il est propriétaire du code (`index.html` notamment).
Dans **Files changed**, chaque relecteur laisse **au minimum** :

- un `praise:` ;
- une **suggestion de code** (bouton *Add a suggestion* ou bloc ` ```suggestion `), préfixée
  `suggestion (non-blocking):` ;
- un `question:` **ou** un `issue (blocking):` (s'il n'y a vraiment rien de bloquant, inventez une exigence raisonnable,
  par exemple un `alt` manquant ou une étiquette en double).

Puis **Review changes → Request changes** s'il y a un `issue (blocking)`, sinon *Approve*.

L'**auteur** : applique ou refuse **avec une réponse argumentée** chaque commentaire (*Commit suggestion* applique une
suggestion en un clic), corrige le bloquant sur sa branche, pousse, puis marque chaque conversation *Resolve
conversation*. Le relecteur **re-approuve**.

**Résultat attendu** : chaque PR a au moins trois commentaires labellisés, toutes ses conversations résolues, une
approbation d'un propriétaire du code, et l'encadré de fusion est vert.

> **Si ça ne marche pas**
> - *Approve* est grisé : c'est **votre** PR. On ne s'approuve pas soi-même.
> - L'approbation a disparu après la correction : c'est *Dismiss stale approvals* (étape 2). Normal : on approuve ce qui
>   sera fusionné, pas une version précédente.
> - *Commit suggestion* crée un commit nommé `Update index.html` : il ne passe pas par votre hook (il est créé par
>   GitHub). Sans gravité ici : seul le **titre de la PR** arrive dans `main` en squash.

> **Pourquoi ?** Le label dit à l'auteur ce qui bloque et ce qui est facultatif : moins d'allers-retours, moins de
> malentendus. Une revue qui ne contient que des reproches n'apprend rien à personne.

## Étape 7 : fusions en série, conflit textuel (15 min)

1. La **première** PR prête est fusionnée par son auteur : **Squash and merge** (vérifiez le titre), la branche est
   supprimée automatiquement.
2. Les autres PR affichent *This branch has conflicts that must be resolved* : tout le monde a modifié la même ligne de
   `index.html`. Chaque auteur concerné résout **en local** :

```bash
git switch main && git pull
git switch feature/carte-<prenom>
git merge main
```

Grâce à `zdiff3`, vous voyez trois versions : la vôtre (`HEAD`), l'**ancêtre commun** (`|||||||`) et celle de `main`.
Ici, la bonne résolution garde **les deux lignes**.

```bash
git diff --check               # ne doit RIEN afficher (plus aucun marqueur)
git add index.html
git commit --no-edit
git push
```

3. Le relecteur re-approuve, l'auteur fusionne ; la PR suivante recommence (un nouveau conflit apparaît à chaque
   fusion : c'est normal).

En local, après chaque fusion : `git switch main && git pull && git branch -D feature/carte-<prenom>`.

**Résultat attendu** : toutes les cartes sont sur `main`, `git log --oneline main` montre **un commit par PR**, tous
conventionnels, et `git grep -n '<<<<<<<\|>>>>>>>'` ne trouve rien.

> **Si ça ne marche pas**
> - `git merge main` répond `Already up to date` : vous n'avez pas fait `git pull` sur `main` avant.
> - `Merging is not possible because you have unmerged files` : oubli du `git add`.
> - Perdu au milieu de la fusion : `git merge --abort`, puis recommencez.
> - `git branch -d` refuse de supprimer votre branche : normal après un **squash** (vos commits d'origine ne sont pas
>   dans `main`) ; utilisez `-D` **après** avoir vérifié que la PR est fusionnée.

**Question de réflexion** : chaque résolution a annulé une approbation et coûté une nouvelle revue. Quel gaspillage
Lean ? Comment l'équipe aurait-elle pu l'éviter (organisation du fichier, ordre de fusion, taille des PR) ?

## Étape 8 : conflit sémantique provoqué (15 min)

Le patron de la promo veut un nouveau titre pour le site, et les deux rédacteurs ont chacun une idée.

1. **Rédacteur A** et **rédacteur B**, chacun depuis `main` à jour, sur une branche `feature/titre-<prenom>` : modifiez
   **la même** ligne `<h1 class="hero__title">` **et** le paragraphe `hero__intro` avec **votre** proposition (par
   exemple A : « La promo CDA » → « Promo CDA : nos projets » ; B : « La promo CDA » → « CDA, la promo qui déploie »).
   Commit conventionnel, PR, revue rapide (un propriétaire de `index.html`).
2. La PR de A est fusionnée la première. Celle de B est en conflit.
3. **B ne choisit pas seul.** Il ouvre le conflit en local (`git merge main`), lit les trois versions, puis **discute
   avec A dans la PR** (commentaire `question:`) pour décider du texte final : celui de A, celui de B, ou une synthèse.
4. B résout selon la décision, pousse, et **écrit la décision dans la description de la PR** (« Décision : … , validée
   par @A »). Un propriétaire de `index.html` re-relit **le fichier entier** et approuve. Squash and merge.

**Résultat attendu** : `main` contient **un** titre cohérent (pas deux titres collés), et la PR de B garde la trace de la
décision et de qui l'a validée.

> **Pourquoi ?** Git détecte les conflits **textuels** ; il ne détecte jamais les conflits d'**intention**. « Accept
> both » aurait produit deux `<h1>` : le fichier est valide, le site est faux. Seule la discussion (et, sur un vrai
> projet, les tests) protège de ce cas.

---

## Je valide avec le formateur

- [ ] Un push direct sur `main` est refusé avec `GH013`, administrateur compris (`gh ruleset check main` ou capture).
- [ ] Le dépôt n'autorise que le squash, avec le titre de la PR comme message par défaut.
- [ ] `.github/CODEOWNERS` est valide, arrivé par une PR approuvée, chaque chemin a au moins deux propriétaires.
- [ ] Chaque membre a une PR fusionnée, avec template complété, au moins trois commentaires labellisés, conversations
      résolues et approbation d'un propriétaire du code.
- [ ] `git log --oneline main` : un commit par PR, **tous** conventionnels.
- [ ] Le conflit textuel et le conflit sémantique ont été résolus ; la décision du second est écrite dans sa PR.

**Questions de justification** (débrief) :

1. Laquelle des règles du ruleset vous a le plus « gênés » ? Quel risque accepteriez-vous en la supprimant ?
2. Qu'est-ce qui, dans ce TP, aurait pu être vérifié par une **machine** plutôt que par un relecteur ? (C'est le
   programme de demain.)
3. Squash ou commit de fusion : dans quel contexte choisiriez-vous l'autre option ?
4. Votre équipe passe à 15 personnes. Que changez-vous dans `CODEOWNERS` ?

## Pour aller plus loin (si vous avez fini en avance)

- **Annuler une PR fusionnée** : sur une PR fusionnée, bouton **Revert** : GitHub crée une PR inverse. Relisez-la,
  fusionnez-la, puis rétablissez le changement par une nouvelle PR. Comparez avec `git revert` en local
  ([exercice 1.4](../../exercices/jour1/04-reparer-ses-erreurs.md)).
- **Tout en ligne de commande** : `gh pr list`, `gh pr checkout <n>`, `gh pr review <n> --approve` /
  `--request-changes -b "issue (blocking): …"`, `gh pr merge <n> --squash --delete-branch`.
- **Commits signés** : configurez la signature SSH (`git config --global gpg.format ssh`,
  `git config --global user.signingkey ~/.ssh/id_ed25519.pub`, `git config --global commit.gpgsign true`), ajoutez la
  clé comme *Signing key* sur GitHub, puis ajoutez la règle *Require signed commits* au ruleset. Que se passe-t-il pour
  les commits créés par *Commit suggestion* ?
- **Lire l'historique produit** : [exercice 1.3](../../exercices/jour1/03-lire-historique.md), puis appliquez ses
  commandes (`--first-parent`, `main..branche`, `merge-base`) au dépôt de l'équipe.

---

## Variante solo

Vous jouez tous les rôles, mais **une revue ne peut pas venir de vous-même**. Deux options :

- **Recommandée** : invitez le formateur ou un apprenant d'une autre équipe comme collaborateur, et mettez-le comme
  second propriétaire dans `CODEOWNERS`. Le TP se déroule normalement.
- **Sans relecteur** : dans le ruleset, *Required approvals* = **0** et décochez *Require review from Code Owners*
  (gardez la PR obligatoire, la résolution des conversations et le squash). Faites une **auto-revue** labellisée
  (*Review changes → Comment*). Simulez les conflits avec deux branches parties toutes deux de `main` :
  `feature/carte-<prenom>` et `feature/carte-mentor` (étape 7), puis `feature/titre-a` et `feature/titre-b` (étape 8).

La checklist est la même ; pour la revue, le formateur regarde vos commentaires d'auto-revue.

---

## Si ça ne marche pas (aide-mémoire)

| Symptôme | Cause probable | Que faire |
|---|---|---|
| `GH013: Repository rule violations found` | Vous poussez sur `main` | Normal : branche + PR |
| `Review required` / `Code owner review required` | Pas d'approbation, ou pas d'un propriétaire du fichier | Demander la revue à un propriétaire (`CODEOWNERS`) |
| `Changes requested` | Un relecteur a demandé des corrections | Corriger, pousser, répondre, demander une nouvelle revue |
| `All conversations must be resolved` | Une conversation est encore ouverte | Répondre, puis *Resolve conversation* |
| `This branch has conflicts` | Même zone modifiée dans `main` | Étape 7 ou 8 : résolution en local sur **votre** branche |
| `✖ Message refusé` au commit | Le hook `commit-msg` | Corriger le message (`type: description`) |
| `Your branch is ahead of 'origin/main'` sur `main` | Commit fait sur `main` par erreur | `git branch feature/<sujet>` puis `git reset --hard origin/main` ([exercice 1.4](../../exercices/jour1/04-reparer-ses-erreurs.md), cas 5) |
| `rejected (non-fast-forward)` sur votre branche | Quelqu'un (ou *Commit suggestion*) a poussé sur votre branche | `git pull` (sur votre branche), puis `git push` |
| Tout semble cassé | | `git status` d'abord : il dit presque toujours quoi faire. Puis le formateur |

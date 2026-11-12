# Démo — Branches, fast-forward, commit de fusion et squash

| | |
|---|---|
| **Jour / bloc** | J1 après-midi — Bloc 2.1 « Git pour travailler en équipe » (rappel rapide) |
| **Durée** | 10 min (dans les 30 min du bloc) |
| **Prérequis** | Git ≥ 2.28 (pour `git init -b`), un terminal avec une police lisible (zoom ×2) |
| **Ce qu'on montre** | une branche est un pointeur ; fast-forward vs commit de fusion vs **squash** ; `git log --oneline --graph` comme outil de lecture ; pourquoi `git branch -d` refuse une branche squashée |

## Lancer

```bash
bash demos/demo-git-branches/demo.sh              # avec pauses (en salle)
KEEP=1 bash demos/demo-git-branches/demo.sh       # conserve le dépôt /tmp pour le laisser explorer
DEMO_AUTO=1 bash demos/demo-git-branches/demo.sh  # sans pause (test avant le cours)
```

Le script crée un dépôt jetable avec `mktemp` dans `/tmp`, affiche chaque commande avant de l'exécuter, et supprime le
dépôt à la fin.

## Déroulé minuté

Public CDA : Git est connu. On va **vite** sur les étapes 1 à 4 (rappel) et on s'attarde sur 6 et 7, qui préparent les
choix du TP 1 (squash imposé par le ruleset).

| Min | Étape du script | Dire | Question à poser à la salle |
|---|---|---|---|
| 0-1 | 1. Dépôt neuf | « Deux commits sur `main`, comme au début de TaskFlow. » | « Que veut dire `HEAD -> main` ? » |
| 1-2 | 2. Créer une branche | « Une branche = un fichier de 41 octets contenant un SHA. » | « 50 branches : combien de fichiers du projet copiés ? » (aucun) |
| 2-3 | 3-4. Commit puis fast-forward | « `main` n'a pas bougé : Git avance l'étiquette, aucun commit ajouté. » | « Pourquoi pas de commit de fusion ? » |
| 3-5 | 5-6. Divergence, commit de fusion | « Quelqu'un a poussé sur `main` entre-temps : un commit à **deux** parents réunit les lignes. » | Faire **dessiner** le graphe attendu avant `git log --graph` |
| 5-8 | 7. Squash | « *Squash and merge* : toute la PR devient **un** commit ordinaire, avec le titre de la PR comme message. Les `wip` disparaissent de `main`. » | « Avantage ? (un commit par PR, `main` lisible, revert facile) Inconvénient ? (perte du détail des commits dans `main`) » |
| 8-10 | 8. Ménage | « `--merged` ne liste pas la branche squashée, et `-d` refuse : Git ne voit pas ses commits dans `main`. » | « Comment savoir alors qu'on peut la supprimer ? » (la PR est fusionnée ; *Automatically delete head branches* sur GitHub) |

## Taper à la main (variante sans script)

Si la salle est à l'aise, rejouez l'étape 7 à la main dans le dépôt conservé (`KEEP=1`) avec un commit de plus sur la
branche, et faites prédire le nombre de parents du commit squashé (`git log -1 --format=%p`).

## Pièges à anticiper

- Git < 2.28 : `git init -b main` échoue → `git init && git checkout -b main`.
- Un éditeur s'ouvre au merge : le script utilise `--no-edit`. À la main : `git config --global core.editor "code --wait"`.
- `git merge --squash` ne crée **pas** le commit : il prépare l'index, il faut `git commit` derrière.
- *Rebase and merge* (troisième bouton GitHub) et le rebase en général : demain (J2, bloc 2.3).

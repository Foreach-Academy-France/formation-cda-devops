# Exercice 1.3 — Lire un historique Git

| | |
|---|---|
| **Durée** | 15 min (seul) |
| **Bloc** | 2.1 — Lire un historique comme un pro ; fusions fast-forward, commit de fusion, squash |
| **Prérequis** | Git ≥ 2.28 |
| **Fichiers fournis** | [`historique.txt`](historique.txt) (sortie de Git à lire), [`creer-historique.sh`](creer-historique.sh) (recrée le même dépôt pour vérifier) |

## Objectif

Arriver sur un projet existant et en comprendre l'histoire en quelques minutes : branches, fusions, versions, ce qui
reste à intégrer. Puis savoir **interroger** l'historique avec les bonnes commandes plutôt que de le faire défiler.

## Le graphe à lire

Sortie de `git log --oneline --graph --all --decorate` sur un petit dépôt TaskFlow (aussi dans [`historique.txt`](historique.txt)) :

```text
* 93db9eb (feature/docker) build(api): ajoute un Dockerfile
* fd16415 (HEAD -> main, tag: v1.0.0, fix/titre-page) fix(front): corrige le titre de la page
*   3b7627e Merge branch 'feature/health'
|\  
| * 24df34a (feature/health) test(api): teste la route /health
| * f1f8d16 feat(api): ajoute la route GET /health
* | 057cd1f chore: ajoute le .gitignore
|/  
* 8f17968 feat(api): crée l'application Express
* 20bc9b4 chore: initialise le projet TaskFlow
```

## Consignes

### Partie 1 — Lire, sans lancer de commande (8 min)

1. Combien de commits contient ce dépôt ? Sur quelle branche et quel commit est `HEAD` ?
2. Quel commit est un **commit de fusion** ? Quels sont ses deux parents (SHA) ?
3. Pendant que `feature/health` était développée, un commit est arrivé sur `main`. Lequel ?
4. `fix/titre-page` a-t-elle été fusionnée en **fast-forward** ou avec un commit de fusion ? Justifiez.
5. La version `v1.0.0` contient-elle la route `/health` ? Le Dockerfile ?
6. Quelle branche n'est pas encore fusionnée ? Sa fusion dans `main` serait-elle un fast-forward ?
7. Quelles branches peut-on supprimer avec `git branch -d` sans rien perdre ?
8. L'équipe applique la convention Conventional Commits. Quels commits deviendraient des lignes du CHANGELOG de
   `v1.0.0` dans la section « Fonctionnalités » ? Et dans « Corrections » ?
9. Imaginez que `feature/health` ait été fusionnée en **squash** au lieu d'un commit de fusion. Redessinez le graphe :
   combien de commits sur `main` ? Combien de parents pour le commit issu de la fusion ? `git branch --merged main`
   listerait-il encore `feature/health` ?

### Partie 2 — Interroger le vrai dépôt (7 min)

```bash
bash creer-historique.sh --print
cd <chemin affiché>
```

Les identifiants sont **les mêmes** que ci-dessus (auteurs et dates sont fixés dans le script). Trouvez la commande
qui répond à chaque question, puis vérifiez vos réponses de la partie 1 :

10. Quels commits de `feature/docker` sont absents de `main` ? Et l'inverse ?
11. Affichez l'historique de `main` « PR par PR », c'est-à-dire **sans** entrer dans les branches fusionnées. Combien de
    lignes ?
12. Quel est l'**ancêtre commun** de `main` et `feature/docker` ? Qu'en déduisez-vous pour la question 6 ?
13. Quels commits ont ajouté ou retiré la chaîne `/health` dans le code ?
14. Quels sont les deux parents de `3b7627e` ? (une commande, pas le graphe)

Supprimez le dossier temporaire à la fin (`rm -rf <chemin affiché>`).

## Résultat attendu

Quatorze réponses courtes ; pour la partie 2, la **commande** et sa sortie. Corrigé : [`solutions.md`](solutions.md).

## Indices

<details>
<summary>Indice 1 — repérer un commit de fusion et un fast-forward</summary>

Un commit de fusion a **deux parents** : deux traits se rejoignent sur lui (`|\` juste en dessous), et son message par
défaut commence par `Merge branch`. Après un fast-forward, aucune trace : deux étiquettes pointent sur **le même**
commit.
</details>

<details>
<summary>Indice 2 — les commandes de la partie 2</summary>

`git log A..B` (ce qui est dans B mais pas dans A) ; `git log --first-parent` ; `git merge-base` ; `git log -S` (le
« pickaxe ») ; `git log -1 --format=%P <sha>` ou `git show --no-patch --format=raw <sha>`.
</details>

<details>
<summary>Indice 3 — squash</summary>

Un squash crée **un nouveau** commit ordinaire (un seul parent) qui contient les changements de toute la branche. Les
commits d'origine de la branche ne deviennent **pas** des ancêtres de `main`.
</details>

## Question de réflexion

Sur un gros projet fusionné en squash, `git log --first-parent` et `git log` donnent-ils le même résultat ? Pourquoi
les équipes qui fusionnent avec des commits de fusion utilisent-elles autant `--first-parent` ?

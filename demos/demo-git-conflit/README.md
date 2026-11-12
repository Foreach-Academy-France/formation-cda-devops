# Démo — Conflit textuel, conflit sémantique

| | |
|---|---|
| **Jour / bloc** | J1 après-midi — pendant le TP 1, juste avant l'étape 7 (fusions en série) |
| **Durée** | 10 min |
| **Prérequis** | Git ≥ 2.35 (pour `zdiff3`), VS Code pour la résolution graphique en étape 4 |
| **Ce qu'on montre** | lire un conflit avec l'**ancêtre commun** (`zdiff3`), `git status` (`UU`), `git log --merge`, résoudre, vérifier (`git diff --check`), `git merge --abort` ; la différence entre un conflit **textuel** (on garde les deux) et un conflit **sémantique** (on décide à deux) |

## Lancer

```bash
bash demos/demo-git-conflit/demo.sh              # en salle : à l'étape 4, résolvez dans VS Code
KEEP=1 bash demos/demo-git-conflit/demo.sh       # garde le dépôt /tmp
DEMO_AUTO=1 bash demos/demo-git-conflit/demo.sh  # test sans pause (résolutions automatiques)
```

Le scénario reprend **exactement** les étapes 7 et 8 du TP 1 (liste `<ul class="promo">` et titre `hero__title` de la
page « Promo CDA ») : les apprenants vont vivre les deux situations dans les minutes qui suivent.

## Déroulé minuté

| Min | Étape | Dire | Question à poser à la salle |
|---|---|---|---|
| 0-1 | 1 | « `zdiff3` : Git montrera aussi l'**ancêtre commun**. À mettre en global dès aujourd'hui. » | — |
| 1-3 | 2 | « Alice est fusionnée ; Bob met sa branche à jour avec `main`, comme vous tout à l'heure. » | « Que signifie `UU` ? » |
| 3-5 | 3 | « Trois versions : la nôtre, l'ancêtre (vide ici : personne n'avait de ligne), celle de `main`. `git log --merge` donne les commits responsables. » | « Que dit l'ancêtre vide sur l'intention des deux auteurs ? » (deux ajouts indépendants) |
| 5-6 | 4 | « Conflit **textuel** : *Accept Both*, puis `git diff --check`. » | « Comment être sûr qu'il ne reste aucun marqueur ? » |
| 6-8 | 5 | « Même titre modifié deux fois : l'ancêtre montre que **les deux** ont changé la même chose. *Accept Both* donnerait deux `<h1>`. » | « Qui doit décider ? Sur quel critère ? » |
| 8-9 | 6 | « Pas prêt à décider ? `git merge --abort` : retour à l'état d'avant, rien de perdu. » | — |
| 9-10 | 7 | « Décision prise à deux, appliquée, écrite dans la PR ; on redemande une revue du fichier **entier**. » | « Qu'est-ce qui aurait détecté le double `<h1>` automatiquement ? » (un test, un linter HTML : demain, la CI) |

## Pièges à anticiper

- Git < 2.35 ne connaît pas `zdiff3` : utilisez `diff3` (même idée, affichage un peu plus verbeux).
- Sur GitHub, le bouton *Resolve conflicts* existe, mais il ne permet ni de lancer les tests ni de voir le site :
  privilégiez la résolution **en local**.
- Oublier `git add` après résolution : `git commit` refuse (*Committing is not possible because you have unmerged files*).
- Après une résolution poussée, le ruleset du TP annule l'approbation (*dismiss stale approvals*) : c'est voulu.

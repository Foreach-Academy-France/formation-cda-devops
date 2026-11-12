# Exercice 2.2 — Le workflow cassé

| | |
|---|---|
| **Durée** | 15 min |
| **Bloc** | 3.2 — GitHub Actions |
| **Prérequis** | démo `demo-actions-hello` ; Docker (pour actionlint) ou l'extension VS Code *GitHub Actions* |
| **Fichier fourni** | [`yaml-a-corriger/ci-casse.yml`](yaml-a-corriger/ci-casse.yml) |

## Situation

Un collègue a écrit le premier `ci.yml` de TaskFlow « de tête », un vendredi soir. GitHub affiche *Invalid workflow file*. Votre mission : le rendre **valide**, puis **correct** (il fait ce qu'on attend de lui), puis **sûr**. Un fichier qui passe le linter n'est pas forcément un bon pipeline.

Ce que le workflow devrait faire : sur chaque PR et chaque push sur `main`, lint + tests unitaires de l'API sur Node 20 et 22, tests d'intégration contre PostgreSQL, build du front et conservation de `front/dist` sous le nom `front-dist`.

## Outil : actionlint

[actionlint](https://github.com/rhysd/actionlint) vérifie la syntaxe YAML **et** la sémantique GitHub Actions (clés inconnues, expressions, `needs`, scripts shell via shellcheck). Il tourne en conteneur :

```bash
cd exercices/jour2/yaml-a-corriger
cp ci-casse.yml ci.yml          # travaillez sur une copie
docker run --rm -v "$PWD":/repo -w /repo docker.io/rhysd/actionlint:1.7.12 ci.yml
```

> Avec Podman sous SELinux, ajoutez `:Z` au volume : `-v "$PWD":/repo:Z`.

## Consignes

1. **Valide** — Lancez actionlint, corrigez **une** erreur, relancez. Tant que le YAML ne se lit pas, actionlint ne montre que la première erreur : c'est normal. Il y a **3 erreurs de syntaxe YAML** puis **3 erreurs GitHub Actions**.
2. **Correct** — actionlint ne dit plus rien. Relisez le fichier en vous demandant, step par step, « que va-t-il se passer sur le runner ? ». Trouvez **4 problèmes** que le linter ne voit pas : un step qui n'exécute pas ce qu'on croit, un step qui échouera à l'exécution, un artefact qui sera vide, un job qui ne maîtrise pas sa version de Node.
3. **Sûr et robuste** — Trouvez **2 améliorations** : une sur les droits du `GITHUB_TOKEN`, une sur le démarrage de Postgres.
4. Remplissez un tableau `ligne | problème | catégorie (syntaxe / sémantique / exécution / sécurité) | correction`.
5. Bonus : ajoutez `name:` aux jobs. Pourquoi ces noms comptent-ils dès qu'on rend les checks obligatoires ?

## Résultat attendu

- actionlint ne renvoie **rien** (code de sortie 0).
- Le job `api-integration` exécute bien **deux** commandes ; l'artefact `front-dist` contient `index.html` ; chaque job installe sa version de Node avec cache.
- Votre tableau contient 12 lignes (6 + 4 + 2).

## Indices

<details>
<summary>Indice 1 — syntaxe et sémantique</summary>

- YAML : un déclencheur sans `:` au milieu d'autres qui en ont ; une **tabulation** (VS Code : *View > Render Whitespace*) ; un `runs-on` sans `:`.
- GitHub Actions : une clé de filtre au singulier ; une propriété de `matrix` qui n'existe pas ; un `needs` vers un job inexistant.
</details>

<details>
<summary>Indice 2 — ce que le linter ne voit pas</summary>

- Sans `|`, YAML **replie** les lignes d'un `run:` en une seule : `npm ci npm run test:int`.
- `cache-dependency-path` est relatif à la **racine** du dépôt, pas au `working-directory`.
- `actions/upload-artifact` ignore aussi `working-directory` : quel chemin lui donner ?
- Le job `front` n'a pas de `setup-node` : il utilise « le Node qui traîne » sur l'image du runner.
</details>

<details>
<summary>Indice 3 — sécurité et robustesse</summary>

- De quel droit un workflow de CI a-t-il besoin sur le dépôt ? Lire, ou écrire ?
- Le conteneur Postgres est « démarré » avant le premier step… mais est-il **prêt** ? Que faisait `healthcheck` dans `compose.yaml` ?
</details>

## Questions de justification

1. actionlint ne trouve pas les problèmes de l'étape 2. Quelle autre protection les aurait attrapés avant `main` ? (pensez à ce que vous ferez cet après-midi avec une PR volontairement cassée)
2. Faut-il lancer actionlint dans la CI elle-même ? Avantages, coût, et où le placer (pre-commit, job dédié) ?

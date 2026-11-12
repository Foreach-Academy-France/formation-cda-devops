# Exercice 2.4 — Lire un log de CI en échec

| | |
|---|---|
| **Durée** | 15 min (5 min par log) |
| **Bloc** | 3.2 — GitHub Actions (services, matrix) |
| **Prérequis** | démo `demo-actions-hello` ; avoir vu un run dans l'onglet *Actions* |
| **Fichiers fournis** | [`logs-ci/log-ci-1.txt`](logs-ci/log-ci-1.txt), [`logs-ci/log-ci-2.txt`](logs-ci/log-ci-2.txt) + [`logs-ci/ci-extrait.yml`](logs-ci/ci-extrait.yml), [`logs-ci/log-ci-3.txt`](logs-ci/log-ci-3.txt) |

## Situation

Trois PR de TaskFlow sont rouges. Le réflexe n'est ni « *Re-run jobs* en espérant », ni « ça marche chez moi » : on **lit le log** avec méthode, on corrige **au bon endroit** (code, lockfile, workflow, ou décision d'équipe).

### Méthode en 5 questions

1. **Quel job, quel step** ? (cherchez `##[error]`, puis remontez)
2. Quelle est la **première** ligne d'erreur utile ? (la dernière n'est souvent qu'une conséquence)
3. Qu'est-ce qui a **changé** dans la PR ? Qu'est-ce qui est **différent** entre le runner et le poste ?
4. Où est la correction : code, lockfile, workflow, environnement ?
5. Comment **reproduire en local** avant de repousser ?

## Consignes

Pour chaque log, rédigez une fiche de 4 lignes : *job/step* · *ligne-cause recopiée* · *cause en une phrase* · *correction (où et quoi)*. Puis répondez aux questions.

### Log 1 — [`log-ci-1.txt`](logs-ci/log-ci-1.txt)

1. Pourquoi ne pas « réparer » en remplaçant `npm ci` par `npm install` dans le workflow ?
2. Quel garde-fou **local** aurait évité cet aller-retour ?

### Log 2 — [`log-ci-2.txt`](logs-ci/log-ci-2.txt) et [`ci-extrait.yml`](logs-ci/ci-extrait.yml)

3. Le service Postgres a-t-il démarré ? Citez la ligne qui le prouve, et celle (dans *Initialize containers*) qui montre ce qui manque.
4. Corrigez `ci-extrait.yml`. Que faudrait-il changer d'autre si le job tournait lui-même dans un conteneur (`container: node:20-alpine`) ?

### Log 3 — [`log-ci-3.txt`](logs-ci/log-ci-3.txt)

5. Pourquoi `api (22)` est-il vert et `api (20)` rouge, alors que c'est le même code ? Pourquoi l'auteur n'a-t-il rien vu en local ?
6. Trois corrections sont possibles : (a) retirer Node 20 de la matrice, (b) réécrire le code sans `Object.groupBy`, (c) passer tout le projet à Node 22. Pour chacune, listez **tous** les fichiers à modifier (pensez aux `Dockerfile` et à `package.json`). Laquelle choisissez-vous aujourd'hui, et pourquoi ?
7. Qu'apporte ici `fail-fast: false` dans la matrice ?

## Indices

<details>
<summary>Indice 1 — log 1</summary>

`npm ci` installe **exactement** le `package-lock.json` et refuse s'il ne correspond pas à `package.json`. Regardez `Missing: … from lock file` et la liste des fichiers modifiés en bas du log.
</details>

<details>
<summary>Indice 2 — log 2</summary>

`ECONNREFUSED 127.0.0.1:5432` : personne n'écoute sur ce port **de la VM**. Le conteneur écoute sur **son** 5432. Relisez la commande `docker create` : quelle option `-p` manque ?
</details>

<details>
<summary>Indice 3 — log 3</summary>

`Object.groupBy` est apparu dans Node 21. Quelle version de Node tourne dans `api/Dockerfile`, donc **en production** ? Que dit le champ `engines` de `api/package.json` ?
</details>

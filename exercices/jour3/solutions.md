# Jour 3 — Solutions des exercices

> À ouvrir **après** avoir cherché. Pour 3.1, il n'y a pas de réponse unique : ce sont des propositions argumentées.

---

## Exercice 3.1 — Stratégies de déploiement

| | A. Mairie | B. Boutique, soldes | C. API médicale | D. TaskFlow |
|---|---|---|---|---|
| **Stratégie** | **Recreate**, hors heures d'usage (après 18h) | **Feature flag** (nouveau tunnel éteint) + **canary** du code (1 % → 10 % → 50 % → 100 %) | **Blue/green** + migration **expand/contract** en plusieurs releases | **Ne pas livrer en l'état** : la prod est intacte, on investigue ; si le métier insiste, livraison surveillée avec un seuil de retour arrière |
| **Pourquoi** | un seul serveur, 40 utilisateurs, plage d'inactivité ; colonne nullable = migration compatible | risque business fort, métriques disponibles, 12 réplicas permettent de doser ; le marketing veut un interrupteur **sans redéploiement** = flag | 99,9 % interdit la coupure ; de vieux clients mobiles imposent que deux versions du contrat cohabitent ; l'infra blue/green existe déjà | le staging a fait son travail : il a révélé un signal (mémoire × 3) que le smoke test ne mesure pas |
| **Refusé** | blue/green ou canary : coût (2e serveur) disproportionné | big bang le jour du pic ; canary seul : ne permet pas de couper le tunnel sans redéployer | renommer la colonne en une release : l'ancienne version (encore servie pendant la bascule, et après un rollback) planterait | « on verra en prod » : une seule machine porte staging **et** prod, la mémoire est partagée |
| **Signal** | `/health` + un agent teste une réservation à 8h30 | taux de 5xx et latence du canary comparés à la version stable ; conversion et panier moyen par variante | taux d'erreur par version d'appli mobile, latence p95, SLO de disponibilité | mémoire du conteneur (`docker stats`), OOM kills, latence |
| **Retour arrière** | rollback de l'image ; la colonne nullable peut rester | flag OFF (secondes) ; canary : retirer la nouvelle version du pool | rebasculer sur l'environnement précédent (secondes) **tant que** la phase *contract* n'a pas eu lieu | rollback par tag si elle dérive en prod ; sinon roll forward avec correctif |

**Synthèse**

1. La coupure est acceptable quand **le métier** le dit (A : personne n'utilise l'outil la nuit). La technique ne fait
   que chiffrer le coût de l'éviter.
2. Pendant une bascule blue/green et après un rollback, **l'ancienne version tourne sur la nouvelle base**. Renommer
   casse l'ancienne. *Expand/contract* :
   - R1 (*expand*) : ajouter `debut` et `fin` (nullable), écrire dans `date_rdv` **et** `debut`, script de recopie ;
   - R2 : lire `debut` ; `fin` rendu obligatoire avec une valeur par défaut calculée ; `date_rdv` encore alimentée ;
   - R3 (*contract*), quand plus aucune version ne lit `date_rdv` : supprimer `date_rdv`.
   Chaque release est réversible ; seule R3 est un point de non-retour.
3. Non. Le flag découple **déploiement** et **activation** (B : couper le tunnel). Le canary limite le **rayon
   d'impact du code déployé** (une montée de version de bibliothèque, qu'aucun flag ne peut éteindre).
4. `docker compose up -d` recrée les conteneurs modifiés : c'est un **recreate** service par service (coupure de
   quelques secondes, d'où `--wait` et le smoke test). Blue/green avec notre proxy : deux projets (`taskflow-blue`,
   `taskflow-green`) sur le même réseau ; le proxy pointe vers l'un (`proxy_pass http://front-blue:80`) ; on démarre
   l'autre, on le vérifie, on change l'upstream puis `nginx -s reload` (sans coupure). La base reste **partagée** :
   la contrainte *expand/contract* demeure.

---

## Exercice 3.2 — Configuration Nginx du proxy

| Ligne (fichier fourni) | Problème | Conséquence | Correction |
|---|---|---|---|
| `ssl_protocols ... TLSv1.3` | `;` manquant | `nginx -t` : `directive "ssl_protocols" is not terminated by ";"` ; pas de démarrage | ajouter `;` |
| `ssl_certificate /etc/ssl/certs/...` | mauvais chemin (montage dans `/etc/nginx/certs/`) | `cannot load certificate ... No such file or directory` ; pas de démarrage | `/etc/nginx/certs/taskflow.crt` |
| `proxy_pass http://127.0.0.1:8080;` (× 2) | `127.0.0.1` = le conteneur proxy lui-même ; 8080 est le port **publié** en dev | **502** `connect() failed (111: Connection refused)` | `proxy_pass http://front:80;` |
| `ssl_protocols TLSv1 TLSv1.1 ...` | protocoles obsolètes (dépréciés par la RFC 8996) | attaques par rétrogradation, échec des audits (ZAP au Jour 5) | `TLSv1.2 TLSv1.3` |
| bloc `listen 80` | sert le site en clair | trafic non chiffré possible, cookies interceptables | `return 301 https://$host$request_uri;` |
| bloc `listen 443` sans `server_name` | bloc « attrape-tout » implicite | marche par hasard avec un seul site ; mauvais aiguillage dès qu'on en ajoute un | `server_name taskflow.localhost;` |
| seul `Host` transmis | pas de `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto` | logs avec l'IP du proxy ; l'appli croit être en HTTP (redirections, cookies `Secure`) | ajouter les trois en-têtes |

Configuration corrigée (testée : 301 sur 8880, page servie sur 8444, TLS 1.1 refusé) :

```nginx
server {
    listen 80;
    server_name taskflow.localhost;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name taskflow.localhost;

    ssl_certificate     /etc/nginx/certs/taskflow.crt;
    ssl_certificate_key /etc/nginx/certs/taskflow.key;
    ssl_protocols       TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://front:80;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**Commentaire de revue type** (*conventional comments*) :

> **issue (bloquant)** : le proxy ne démarre pas (`;` manquant, chemin du certificat). Lancer
> `docker compose run --rm --no-deps proxy nginx -t` avant de pousser ; on pourrait l'ajouter au CI.
> **issue (bloquant)** : `127.0.0.1:8080` pointe sur le proxy lui-même → 502. Utiliser le nom de service `front:80`.
> **issue (sécurité)** : retirer TLS 1.0/1.1 ; HTTP doit rediriger vers HTTPS.
> **suggestion** : `server_name` explicite sur le bloc 443 et en-têtes `X-Forwarded-*`.

**Justification**

1. Une seule porte à surveiller (TLS, en-têtes, limites de débit) ; base et API jamais exposées ; on réorganise
   l'intérieur (blue/green, nouveaux services) sans changer ce que voit l'extérieur.
2. Acceptable pour le lab (le staging valide l'**image** et la **configuration applicative**), mais c'est un écart de
   parité (12-factor, facteur X) : un bug lié au proxy (en-têtes, redirection HTTPS, cookies `Secure`, taille de
   requête) passera le staging et cassera la prod. En entreprise, le staging a le même proxy et le même TLS.
3. Après recréation du front (nouvelle IP), le proxy enverrait vers l'ancienne IP → 502. `deploy.sh` fait `nginx -t`
   puis `nginx -s reload` après `up`. Alternative : `resolver 127.0.0.11` + variable dans `proxy_pass`, comme dans
   `front/nginx.conf`.

---

## Exercice 3.3 — Le secret dans l'historique

### Détection à la main

```bash
git log --all --diff-filter=D --name-only --oneline   # fichiers supprimés : .env dans « chore: retire .env du dépôt »
git log -p -- .env                                    # contenu : GITHUB_TOKEN=ghp_...
git log -S 'hooks.slack.com' --oneline                # commits qui ajoutent ou retirent la chaîne
git show <sha>:src/notify.js                          # l'URL en dur
```

| Secret | Introduit par | « Supprimé » par |
|---|---|---|
| jeton GitHub `ghp_…` (`.env`) | `feat: configuration locale` | `chore: retire .env du dépôt` |
| webhook Slack (`src/notify.js`) | `feat: envoi des notifications sur Slack` | `refactor: l'URL du webhook vient de l'environnement` |

### gitleaks

```text
RuleID: slack-webhook-url   File: src/notify.js   Commit: <sha de « feat: envoi des notifications sur Slack »>
RuleID: github-pat          File: .env            Commit: <sha de « feat: configuration locale »>
INF 8 commits scanned.
WRN leaks found: 2
```

Code de sortie **1** : c'est ce qui fait échouer un job de CI ou refuser un commit (pre-commit). Sans fuite : 0.

### Ordre de réaction : B → D → F → A → E → C

1. **B, la rotation, d'abord** : un secret poussé est **compromis**, définitivement. Des robots scannent GitHub en
   quelques minutes ; les collaborateurs, le fork, les runners de CI et les caches en ont une copie que vous **ne
   pouvez pas** effacer. Révoquer rend la fuite inoffensive ; purger ne fait que la cacher.
2. **D** : savoir si le secret a servi (incident à déclarer ? données personnelles exposées ?).
3. **F** : les nouveaux secrets vont dans les secrets GitHub ou un coffre, jamais dans un fichier versionné.
4. **A** puis **E** : purge, poussée forcée de toutes les branches et de tous les tags, puis chacun re-clone (un vieux
   clone repoussé réintroduirait l'historique). Sur GitHub, les vues en cache et les refs de PR peuvent nécessiter
   une demande au support.
5. **C** : empêcher la récidive (pre-commit local + scan en CI + *push protection* GitHub).

### Purge

`../remplacements.txt` :

```text
regex:ghp_[A-Za-z0-9]{36}==>***REVOQUE***
regex:https://hooks\.slack\.com/services/[A-Za-z0-9/]+==>***REVOQUE***
```

```bash
cp -r ../notif-service ../notif-service.bak
git filter-repo --invert-paths --path .env --replace-text ../remplacements.txt
docker run --rm -v "$PWD":/repo docker.io/zricethezav/gitleaks:v8.30.1 git /repo   # no leaks found
git log --oneline                                                                     # 7 commits
git show HEAD~2:src/notify.js | head -1      # const WEBHOOK = '***REVOQUE***';
```

- Il reste **7 commits** : `feat: configuration locale` ne contenait que `.env` ; devenu vide, filter-repo le supprime.
- Les SHA changent à partir du premier commit modifié : le SHA d'un commit dépend de son arbre **et de son parent**,
  donc toute la descendance est réécrite (les deux premiers commits, intacts, gardent leur SHA).
- filter-repo retire le remote `origin` (garde-fou contre une poussée accidentelle) : il faut le rajouter avant de
  pousser en force.

### Empêcher

`gitleaks git --pre-commit --staged` sort en **1** (`leaks found: 1`) : le hook refuserait le commit.

**Justification**

1. Voir l'ordre ci-dessus : après la purge, le secret existe toujours dans les clones, le fork, les caches et chez
   quiconque l'a récupéré. Seule la révocation le neutralise.
2. `git rm` crée un **nouveau** commit dont l'arbre ne référence plus le blob ; les commits précédents référencent
   toujours leur arbre, qui référence le blob du `.env`. Git ne modifie jamais un objet : il en ajoute.
3. Non : un hook est local (absent d'un nouveau clone tant qu'on n'a pas fait `pre-commit install`, contournable par
   `--no-verify`). Le scan en CI (`security.yml`, Jour 5) et la push protection côté serveur ne s'oublient pas.

---

## Exercice 3.4 (bonus) — Workflow à durcir

| # | Ligne | Problème | Risque | Correction |
|---|---|---|---|---|
| 1 | `pull_request_target` | s'exécute dans le contexte du dépôt **cible**, avec ses secrets et un jeton en écriture, même pour une PR de fork | « pwn request » : le code de l'attaquant tourne avec vos secrets | `pull_request` (pas de secrets pour les forks) |
| 2 | `ref: ...head.sha` | combiné à 1 : on extrait **le code de l'attaquant** dans un contexte privilégié | exécution de code arbitraire avec secrets | ne jamais extraire la tête de PR dans `pull_request_target` |
| 3 | `permissions: write-all` | jeton capable de pousser du code, modifier releases et paquets | un step compromis réécrit `main` | `permissions: contents: read` |
| 4 | `${{ github.event.pull_request.title }}` dans `run:` | injection de script : un titre contenant `"; curl ... \| sh; #` est exécuté | exécution de code (actionlint le signale) | `env: PR_TITLE` puis `"$PR_TITLE"` |
| 5 | `some-user/deploy-preview-action@main` | référence **mutable** d'une action tierce non relue | supply chain : le propriétaire, ou un attaquant (cf. trivy-action), change le code et lit `DEPLOY_TOKEN` | épingler par **SHA complet**, relire l'action, Dependabot pour les mises à jour |
| 6 | `runs-on: [self-hosted, lab]` pour toute PR | le runner monte le socket Docker = root sur la machine | prise de contrôle de la machine qui porte la prod | runner self-hosted **uniquement** pour les PR internes (`if:` sur `head.repo.full_name`) + approbation des workflows de forks |
| 7 | `npm install` | installe hors lockfile et exécute les scripts `postinstall` | code arbitraire au build | `npm ci --ignore-scripts` |
| 8 | step « Déboguer » | secret affiché (GitHub masque la valeur exacte, pas ses transformations : base64, découpage) ; `env` dumpe tout | fuite dans les logs | supprimer ; ne jamais afficher un secret |
| 9 | ni `timeout-minutes` ni `concurrency` | un job peut occuper le runner indéfiniment | déni de service sur le runner qui déploie la prod | `timeout-minutes`, `concurrency` par PR |

Version corrigée (passe actionlint) :

```yaml
name: Preview

on:
  pull_request:
    types: [opened, synchronize]

permissions:
  contents: read

concurrency:
  group: preview-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  preview:
    # Uniquement les PR ouvertes depuis CE dépôt (pas depuis un fork)
    if: github.event.pull_request.head.repo.full_name == github.repository
    runs-on: [self-hosted, lab]
    timeout-minutes: 15
    environment: preview
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false

      - name: Annoncer la PR
        env:
          PR_TITLE: ${{ github.event.pull_request.title }}
        run: echo "Prévisualisation de la PR -- $PR_TITLE"

      - name: Construire et lancer
        run: |
          npm ci --ignore-scripts
          npm run build
          docker compose -p "preview-${PR_NUMBER}" up -d
        env:
          PR_NUMBER: ${{ github.event.pull_request.number }}

      - uses: some-user/deploy-preview-action@0123456789abcdef0123456789abcdef01234567 # v1.2.3 (relu)
        with:
          token: ${{ secrets.DEPLOY_TOKEN }}
```

L'environment `preview` permet en plus d'exiger une approbation ou de restreindre ses secrets à certaines branches.

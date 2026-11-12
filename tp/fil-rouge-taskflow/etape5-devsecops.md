# Étape 5 : pipeline DevSecOps

> **Quand** : Jour 5, après le tour de l'OWASP Top 10 et la démo ZAP | **Durée** : ~55 min
> **Objectif** : ajouter à TaskFlow un workflow de sécurité (`security.yml`) qui vérifie **à chaque PR** les secrets,
> les dépendances, le code (SAST) et l'application qui tourne (DAST) ; puis **lire les rapports, trier le vrai du
> faux positif, corriger** (en-têtes de sécurité du front, dépendances) et **documenter** dans `docs/SECURITE.md`.

---

## Prérequis

- Les étapes 1 à 4 sont fusionnées dans `main` : `ci.yml`, `release.yml`, `iac.yml` sont verts, et le Jour 3 a déjà
  posé **gitleaks** en pre-commit, **Trivy** dans `release.yml`, `dependabot.yml` et les permissions minimales.
- Slides du Jour 5, blocs 7.2 à 7.4 ; antisèche [`../../ressources/cheatsheet-devsecops.md`](../../ressources/cheatsheet-devsecops.md).
- Docker en état de marche (le job DAST lance la stack Compose, et vous testerez ZAP en local).

**Vocabulaire**

| Terme | Signification |
|---|---|
| **SCA** (*Software Composition Analysis*) | analyse des **dépendances** : `npm audit`, Dependabot, Trivy |
| **SAST** (*Static Application Security Testing*) | analyse du **code source** sans l'exécuter : Semgrep, CodeQL |
| **DAST** (*Dynamic Application Security Testing*) | attaque l'**application qui tourne**, de l'extérieur : OWASP ZAP |
| **Baseline** (ZAP) | scan **passif** (spider + analyse des réponses), sans attaque : rapide, sûr, bon pour le CI |
| **Faux positif** | alerte sur quelque chose qui n'est **pas** une vraie faille |
| **Triage** | décider, pour chaque alerte : corriger / issue / exception justifiée |

---

## Étape 5.0 : état attendu au départ (3 min)

```bash
cd ~/taskflow
git switch main && git pull
git switch -c feature/security
```

`docker compose up -d --build` doit démarrer db + api + front, et `http://localhost:8080/health` répondre
`{"status":"ok",...}`. Laissez la stack tournée : vous allez la scanner avec ZAP juste après.

---

## Étape 5.1 : lancer les outils en local (10 min)

> **On n'automatise que ce qu'on sait faire à la main.** Avant d'écrire le workflow, lancez chaque contrôle sur votre
> poste : vous saurez à quoi ressemblent les rapports et ce que le CI va dire.

**1. Secrets (gitleaks)** — déjà installé au Jour 3 :

```bash
gitleaks git --redact --verbose      # scanne tout l'historique ; attendu : "no leaks found"
```

**2. Dépendances (SCA)** :

```bash
cd api   && npm audit --audit-level=high ; cd ..
cd front && npm audit --audit-level=high ; cd ..
```

Notez les paquets signalés, leur **sévérité** et s'ils sont en `dependencies` ou `devDependencies`.

**3. Code (SAST, Semgrep en conteneur, sans compte)** :

```bash
docker run --rm -v "$PWD":/src:ro -w /src docker.io/semgrep/semgrep:1.184.0 \
  semgrep scan --config p/javascript --config p/nodejsscan --metrics=off --error
```

**4. Application (DAST, ZAP baseline)** — la stack doit tourner (`http://localhost:8080`) :

```bash
mkdir -p zap-local
docker run --rm --network host -v "$PWD/zap-local:/zap/wrk:rw" \
  ghcr.io/zaproxy/zaproxy:2.17.0 \
  zap-baseline.py -t http://localhost:8080 -I -r rapport.html
```

Ouvrez `zap-local/rapport.html` dans un navigateur.

> **Si ça ne marche pas**
> - ZAP `Connection refused` : la stack n'est pas démarrée, ou `--network host` indispensable pour joindre
>   `localhost:8080` depuis le conteneur ZAP.
> - `permission denied` sur `zap-local/` : `chmod -R a+rwx zap-local` (ZAP tourne en uid 1000 dans son conteneur).
> - Semgrep ne renvoie **rien** : c'est normal, le code de TaskFlow est propre. Pour voir une alerte, créez un fichier
>   jetable avec `pool.query("... " + req.query.q)` et relancez : la règle `node_sqli_injection` doit lever.

---

## Étape 5.2 : écrire `security.yml` (15 min)

Créez `.github/workflows/security.yml` avec **quatre jobs**. Utilisez la solution comme référence, mais comprenez
chaque choix :

- **Déclencheurs** : `pull_request`, `push` sur `main`, **`schedule`** (hebdomadaire) et `workflow_dispatch`.
  *Pourquoi le `schedule` ?* Une dépendance saine aujourd'hui peut avoir une CVE publiée la semaine prochaine, sans
  que personne ne touche au code.
- **`permissions: contents: read`** : le workflow ne fait que lire.
- **Job `secrets`** : gitleaks sur **tout l'historique** (`fetch-depth: 0`). On télécharge le binaire officiel et on
  **vérifie sa somme SHA-256** (l'action officielle exige une licence pour les organisations).
- **Job `dependances`** : `npm audit --audit-level=high` pour `api` **et** `front` (matrix). Un rapport JSON complet
  est publié en artefact pour le triage.
- **Job `sast`** : Semgrep dans son conteneur officiel, règles publiques `p/javascript` + `p/nodejsscan`, `--error`
  pour faire échouer la PR en cas de résultat.
- **Job `dast`** : démarre la stack avec `docker compose up -d --wait`, vérifie `/health`, puis lance
  **`zap-baseline.py`** contre `http://localhost:8080` avec un fichier de règles `.zap/rules.tsv`.

Poussez la branche et ouvrez une PR. Les quatre checks apparaissent.

```bash
git add .github/workflows/security.yml
git commit -m "ci: ajouter security.yml (gitleaks, npm audit, Semgrep, ZAP)"
git push -u origin feature/security
```

> **Si ça ne marche pas**
> - `actionlint` (dans votre éditeur) souligne une erreur : corrigez-la avant de pousser.
> - Le job `dast` échoue au démarrage : ajoutez `docker compose logs` dans un step `if: failure()` pour voir pourquoi.
> - Le job `sast` est rouge alors que le code est propre : lisez le rapport — c'est peut-être un **vrai** positif que
>   vous avez introduit.

---

## Étape 5.3 : lire et trier les rapports (10 min)

Téléchargez les artefacts de la PR (onglet *Actions* > le run > *Artifacts*). Remplissez ce tableau de **triage** :

| Alerte | Outil | Sévérité | Vrai ou faux positif ? | Décision |
|---|---|---|---|---|
| ex : CSP Header Not Set | ZAP | Medium | **vrai** | corriger (en-têtes Nginx) |
| ex : `npm audit` sur `vitest` | npm audit | high/critical | **vrai**, mais **devDependency** | mettre à jour, sinon issue |
| ex : Suspicious Comments dans le bundle | ZAP | Info | **faux** (code minifié de bibliothèque) | IGNORE justifié |
| … | | | | |

**Rappel** des 4 questions de triage (slide 7.2) : atteignable en prod ? donnée utilisateur ? impact ? décision
(corriger / issue / exception datée) ?

---

## Étape 5.4 : corriger (15 min)

### a) En-têtes de sécurité dans `front/nginx.conf`

Le `nginx.conf` du front est le point d'entrée HTTP : c'est là qu'on pose les en-têtes. Ajoutez, **dans le bloc
`server`** (voir la solution `solution/front/nginx.conf`) :

- `server_tokens off;` — ne pas annoncer la version de Nginx ;
- `add_header Content-Security-Policy "default-src 'self'; ...; frame-ancestors 'none'" always;` — la source la plus
  importante ; le build Vite n'a **ni script ni style inline** (vérifiez `dist/index.html`), donc pas de
  `'unsafe-inline'` ;
- `add_header X-Content-Type-Options "nosniff" always;`
- `add_header Referrer-Policy "strict-origin-when-cross-origin" always;`
- `add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;`
- `add_header X-Frame-Options "DENY" always;` (doublé par `frame-ancestors 'none'` dans la CSP) ;
- `proxy_hide_header X-Powered-By;` — masquer l'en-tête `X-Powered-By: Express` des réponses de l'API.

> **Piège à deux euros** : `add_header` **n'est pas hérité**. Dès qu'une `location` (ex. `/assets/`) a son propre
> `add_header`, elle perd **tous** ceux du niveau `server`, CSP comprise. Dans la solution, le `Cache-Control` des
> assets est posé par un `map` au niveau `http` pour ne pas avoir à remettre un `add_header` dans la `location`.
> Vérifiez **après coup** qu'un fichier de `/assets/` renvoie bien la CSP (`curl -I http://localhost:8080/assets/...`).

Reconstruisez et re-scannez :

```bash
docker compose up -d --build front
curl -sI http://localhost:8080/ | grep -iE 'content-security|x-frame|x-content|referrer|permissions|server'
# relancez le ZAP baseline de l'étape 5.1 : les WARN d'en-têtes doivent disparaître
```

**Vérifiez que l'appli marche toujours** : ouvrez `http://localhost:8080`, créez une tâche, cochez-la. Si la console
du navigateur (F12) affiche une violation CSP, c'est que la politique est trop stricte pour un usage réel — ajustez
**la directive concernée**, ne supprimez pas la CSP.

### b) Dépendances

Pour chaque alerte `high`/`critical` d'`npm audit` :

```bash
cd front && npm audit                 # lire le détail et le chemin de dépendance
npm audit fix                         # corrections compatibles
# si la correction exige une montée majeure (ex. vite/vitest), testez AVANT de valider :
npm i -D vite@latest vitest@latest @vitest/coverage-v8@latest
npm test && npm run build             # tout doit rester vert
```

Si une alerte ne peut pas être corrigée tout de suite (montée de version bloquante, correctif indisponible),
**ouvrez une issue** et documentez-la comme exception datée — ne masquez jamais une alerte en silence.

---

## Étape 5.5 : documenter dans `docs/SECURITE.md` (5 min)

Complétez (ou créez) `docs/SECURITE.md` avec :

- le **tableau des contrôles** (quel outil, à quelle étape, ce qu'il protège) ;
- les **en-têtes** ajoutés et pourquoi ;
- le **registre des exceptions** : chaque faux positif ignoré (`.zap/rules.tsv`, `.gitleaks.toml`, `// nosemgrep`),
  avec *quoi, pourquoi, qui, date de revue* ;
- les **limites connues** (ex. : la baseline ZAP ne teste pas l'authentification).

Prenez la solution `solution/docs/SECURITE.md` comme modèle.

```bash
git add front/nginx.conf .zap/rules.tsv .gitleaks.toml docs/SECURITE.md api/package*.json front/package*.json
git commit -m "security: en-têtes HTTP, triage des alertes, SECURITE.md"
git push
```

---

## Checklist de validation (formateur)

- [ ] `security.yml` a les 4 jobs (`secrets`, `dependances`, `sast`, `dast`) et les déclencheurs `pull_request` +
      `push main` + `schedule` + `workflow_dispatch` ; `permissions: contents: read`.
- [ ] Les actions sont **épinglées par SHA** (commentaire avec la version).
- [ ] Le job `dast` démarre la stack, scanne `http://localhost:8080`, publie le rapport en artefact et arrête la stack.
- [ ] `front/nginx.conf` pose CSP, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, anti-clickjacking,
      `server_tokens off`, `proxy_hide_header X-Powered-By`.
- [ ] `curl -I` sur `/`, `/health` **et** un fichier `/assets/...` renvoie bien les en-têtes (y compris la CSP).
- [ ] Un **re-scan ZAP** ne montre plus les WARN d'en-têtes ; l'appli fonctionne toujours (tâche créée, pas de
      violation CSP en console).
- [ ] `docs/SECURITE.md` contient le tableau des contrôles **et** un registre d'exceptions daté.

## Questions de réflexion

1. Le job `dast` lance la **baseline** (passive). Quelle faille de l'exercice Juice Shop du matin **n'aurait-elle pas**
   été vue par ce scan ? Comment la détecter dans un pipeline ?
2. `npm audit` signale une faille `critical` dans **`vitest`** (une devDependency). Est-ce exploitable en production ?
   Faut-il quand même la corriger, et pourquoi ?
3. Pourquoi masquer `X-Powered-By` et `Server` alors que ça n'empêche **aucune** attaque en soi ?
4. Un collègue met **toutes** les règles ZAP en `IGNORE` pour que le job passe au vert. Quel est le problème, et que
   proposez-vous à la place ?
5. Pourquoi faire tourner `security.yml` **chaque semaine** alors que `ci.yml` tourne déjà à chaque PR ?

## Pour aller plus loin (bonus)

- **CodeQL** : ajoutez le workflow `github/codeql-action` (langage `javascript-typescript`) ; comparez ses résultats
  à ceux de Semgrep. Les alertes remontent dans l'onglet *Security* (nécessite `security-events: write`).
- **SBOM** : générez la nomenclature des images après le build :
  `syft ghcr.io/<owner>/taskflow-api:latest -o cyclonedx-json > sbom-api.json` ou
  `trivy image --format cyclonedx --output sbom-api.json ghcr.io/<owner>/taskflow-api:latest`.
- **API** : proposez `app.disable('x-powered-by')` et une limite de taille de corps (`express.json({ limit: '16kb' })`)
  dans `api/src/app.js` (hors périmètre de cette étape : à faire via une PR dédiée).
- Faites **échouer Semgrep volontairement** (une requête SQL concaténée dans un fichier jetable) pour voir la PR
  passer au rouge, puis corrigez.

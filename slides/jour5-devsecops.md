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
  section.small { font-size: 18px; }
  section.small table { font-size: 15px; }
  section.code pre, section.code pre code { font-size: 13px; }
  section.code pre { padding: 12px; margin: 8px 0; }
---

<!-- _class: lead -->
# Jour 5 — DevSecOps

**DevOps — Concepteur Développeur d'Applications**
CDA — ForEach Academy

Formateur : Fabrice Claeys

---

## Programme de la séance (3h30)

Séance jouée deux fois : demi-groupe A le matin, demi-groupe B l'après-midi. Les horaires sont relatifs au début de la séance.

| Horaire | Contenu |
|---------|---------|
| H+0:00 – H+0:20 | **7.2 La sécurité tout au long du cycle** — threat modeling, SAST / DAST / SCA / IAST, SBOM, triage |
| H+0:20 – H+1:05 | **7.3 Tour de l'OWASP Top 10** — code vulnérable, correction, outil qui détecte |
| H+1:05 – H+1:45 | 🧪 **Exercice** — Chasse aux failles sur OWASP Juice Shop |
| H+1:45 – H+1:55 | *Pause* |
| H+1:55 – H+2:20 | **7.4 Outils de pentest** — méthodologie, cadre légal, nmap, ZAP, Burp, sqlmap, nikto + 🎬 démo ZAP |
| H+2:20 – H+3:15 | 🛠️ **TP fil rouge, étape 5** — `security.yml`, triage, en-têtes, `SECURITE.md` |
| H+3:15 – H+3:30 | **QCM final** (`evaluation/qcm.md`) |

---

## Objectifs de la séance

À la fin de la séance, vous saurez :

- **Placer** chaque contrôle de sécurité au bon endroit de la boucle DevOps, et justifier ce choix
- **Reconnaître** les 10 catégories de l'OWASP Top 10 dans du code Node/Express, et les corriger
- **Exploiter** des failles sur une cible d'entraînement **autorisée** (Juice Shop), puis dire comment le pipeline les aurait évitées
- **Expliquer** la méthodologie et le cadre légal d'un test d'intrusion, et à quoi sert chaque outil
- **Opérer** un workflow de sécurité : lire les rapports, **trier** vrai / faux positif, corriger, documenter

> Fil conducteur de la semaine : *la sécurité commence dès le premier pipeline*. Aujourd'hui, on complète l'outillage et on apprend à **traiter** ce qu'il remonte.

---

## Rappel du Jour 3 (bloc 7.1) : le pipeline est déjà sécurisé

| Déjà en place | Où | Ce que ça empêche |
|---|---|---|
| **gitleaks** en pre-commit + exercice d'historique | poste du dev | un secret qui part dans Git |
| Secrets GitHub, `.env` hors Git, **rotation** | dépôt / environments | des identifiants lisibles par tous |
| **Dependabot** (npm, docker, github-actions) | dépôt | des dépendances qui vieillissent en silence |
| **Trivy** dans `release.yml` (bloquant sur CRITICAL) | build | une image avec une CVE critique en prod |
| `permissions:` minimales, actions **épinglées par SHA** | workflows | un jeton trop puissant, une action modifiée en douce |

**Aujourd'hui on ajoute** : le scan de l'historique **dans le CI**, `npm audit` bloquant, un **SAST** (Semgrep), un **DAST** (ZAP), et les corrections qui vont avec.

---

<!-- _class: lead -->
# 7.2 La sécurité tout au long du cycle

---

## Un contrôle par case de la boucle

```
  PLAN ──▶ CODE ──▶ BUILD ──▶ TEST ──▶ RELEASE ──▶ DEPLOY ──▶ OPERATE ──▶ MONITOR
   │        │        │         │         │           │          │           │
 threat   SAST     SCA       DAST     signature   config     WAF,        alertes,
 modeling secrets  SBOM      (ZAP)    (cosign)    durcie     correctifs  logs de
 (STRIDE) (IDE,    (npm      IAST     provenance  (IaC       (Dependabot sécurité,
          hook)    audit,             SBOM joint  scannée)   en continu) post-mortem
                   Trivy)
     ◀──────────────── coût de correction : ×1 à gauche ... ×30 et plus à droite ──────
```

- **Shift-left** : trouver le problème là où il coûte le moins (dans l'IDE plutôt qu'en prod)
- **Shift-right aussi** : certaines failles n'apparaissent qu'à l'exécution (configuration, en-têtes) ou **après** coup (CVE publiée sur une dépendance déjà en prod) → scans planifiés
- Aucun outil ne couvre tout : on **empile** des contrôles complémentaires (*défense en profondeur*)

---

## PLAN : le threat modeling en 15 minutes (STRIDE)

Avant de coder : *« qu'est-ce qui peut mal tourner ? »* sur un schéma des flux (navigateur → Nginx → API → Postgres).

| Lettre | Menace | Propriété violée | Exemple sur TaskFlow | Parade |
|---|---|---|---|---|
| **S** | *Spoofing* (usurpation) | authentification | quelqu'un se fait passer pour un autre utilisateur | authentification, MFA |
| **T** | *Tampering* (altération) | intégrité | modifier une tâche d'un autre via l'API | contrôle d'accès, validation |
| **R** | *Repudiation* (répudiation) | traçabilité | « ce n'est pas moi qui ai supprimé » | logs horodatés et protégés |
| **I** | *Information disclosure* | confidentialité | stack trace ou `DATABASE_URL` dans une réponse | gestion d'erreurs, secrets |
| **D** | *Denial of service* | disponibilité | POST de 50 Mo en boucle | taille max du body, rate limit |
| **E** | *Elevation of privilege* | autorisation | un utilisateur accède à une route admin | moindre privilège |

> Livrable : 5 à 10 menaces priorisées, chacune reliée à un contrôle ou à une issue. Outils : OWASP Threat Dragon, Microsoft Threat Modeling Tool, un tableau blanc.

---

## Les familles d'outils : SAST, DAST, SCA, IAST

| | **SAST** | **DAST** | **SCA** | **IAST** |
|---|---|---|---|---|
| Analyse | le **code source** | l'**appli qui tourne**, de l'extérieur | les **dépendances** (lockfile, image) | l'appli de **l'intérieur** pendant les tests |
| Quand | à chaque PR, dans l'IDE | après déploiement (staging, job CI) | à chaque PR + **planifié** | pendant les tests fonctionnels |
| Trouve | injection, `eval`, XSS, secrets en dur | en-têtes manquants, cookies, config, XSS réfléchie | CVE connues, licences | flux réel donnée → requête |
| Rate | la configuration, l'exécution | le code jamais atteint | le code **maison** | ce qui n'est pas testé |
| Outils | **Semgrep**, CodeQL, SonarQube | **OWASP ZAP**, Burp, nikto | **npm audit**, Dependabot, **Trivy**, Snyk | Contrast, Datadog IAST |

> Aujourd'hui dans `security.yml` : **gitleaks** (secrets) + **npm audit** (SCA) + **Semgrep** (SAST) + **ZAP baseline** (DAST). Trivy (SCA d'image) reste dans `release.yml`.

---

## BUILD et RELEASE : SBOM et signature

**SBOM** (*Software Bill of Materials*) = la liste des ingrédients d'un artefact : chaque paquet, sa version, sa licence (formats **CycloneDX** ou **SPDX**).

```bash
syft ghcr.io/<owner>/taskflow-api:latest -o cyclonedx-json > sbom-api.json
trivy image --format cyclonedx --output sbom-api.json ghcr.io/<owner>/taskflow-api:latest
trivy sbom sbom-api.json            # rescanner le SBOM plus tard, sans l'image
```

- Utile le jour d'une nouvelle faille (Log4Shell, `xz`…) : *« sommes-nous touchés ? »* en une recherche
- Exigé de plus en plus (Cyber Resilience Act européen, décret américain de 2021)

**Signature** : prouver que l'image déployée est **celle que le CI a construite**.
- **cosign** (projet Sigstore) : `cosign sign` dans `release.yml`, `cosign verify` avant le déploiement ; signature *keyless* via l'OIDC de GitHub
- Provenance **SLSA** / attestations GitHub (`actions/attest-build-provenance`) : *qui* a construit *quoi*, *depuis quel commit*

> Cité seulement : pas de signature dans le TP.

---

## Faux positifs, faux négatifs : le triage

|  | L'outil **alerte** | L'outil **se tait** |
|---|---|---|
| **Vraie faille** | ✅ vrai positif → **corriger** | ❌ **faux négatif** → le plus dangereux, invisible |
| **Pas de faille** | ⚠️ **faux positif** → justifier et ignorer | ✅ vrai négatif |

- Trop de faux positifs → l'équipe ne lit plus les rapports (*alert fatigue*) → le vrai positif passe
- Un scanner silencieux ne prouve **rien** : Semgrep (règles publiques) rate une injection SQL si la requête est construite dans une autre fonction ; ZAP baseline ne voit que les pages qu'il trouve

**Pour chaque alerte, 4 questions :**
1. Le code ou la page signalés sont-ils **atteignables** en production ?
2. La donnée vient-elle de **l'utilisateur** (non fiable) ?
3. Quel **impact** si c'est exploité (confidentialité, intégrité, disponibilité) ?
4. Décision : **corriger** maintenant, **issue** priorisée, ou **exception justifiée** (datée, signée, revue)

---

## Où documenter une exception ?

| Outil | Mécanisme d'exception | À éviter |
|---|---|---|
| gitleaks | `.gitleaks.toml` : `[[allowlists]]` sur un **chemin** ou une **valeur** | ignorer une règle entière ; « allowlister » un vrai secret (on le **révoque**) |
| npm audit | pas d'ignore natif : mettre à jour, `overrides` dans `package.json`, ou issue datée | `npm audit fix --force` à l'aveugle (montées de version majeures) |
| Semgrep | `// nosemgrep: <id-de-règle>` sur la ligne, `.semgrepignore` | `nosemgrep` sans identifiant de règle |
| ZAP | `.zap/rules.tsv` : `ID<TAB>IGNORE / WARN / FAIL` | tout passer en IGNORE pour avoir du vert |

Et **toujours** une ligne dans `docs/SECURITE.md` : *quoi, pourquoi, qui, quand on le revoit.*

> Bonne pratique : une alerte **corrigée** passe en `FAIL` dans `rules.tsv` → elle ne pourra plus jamais revenir sans casser le build (test de non-régression de sécurité).

---

<!-- _class: lead -->
# 7.3 Tour de l'OWASP Top 10

---

## L'OWASP Top 10 (édition 2021)

**OWASP** (*Open Worldwide Application Security Project*) : fondation à but non lucratif ; le Top 10 classe les risques les plus fréquents des applications web, à partir de données réelles.

| # | Catégorie 2021 | En une phrase |
|---|---|---|
| A01 | **Broken Access Control** | l'utilisateur accède à ce qui n'est pas à lui |
| A02 | **Cryptographic Failures** | données sensibles mal (ou pas) chiffrées |
| A03 | **Injection** (dont XSS) | une donnée devient du code (SQL, shell, HTML) |
| A04 | **Insecure Design** | la faille est dans la conception, pas dans une ligne |
| A05 | **Security Misconfiguration** | réglages par défaut, en-têtes absents, erreurs bavardes |
| A06 | **Vulnerable and Outdated Components** | dépendance avec une CVE connue |
| A07 | **Identification and Authentication Failures** | mots de passe faibles, sessions mal gérées |
| A08 | **Software and Data Integrity Failures** | code ou données acceptés sans vérifier l'origine |
| A09 | **Security Logging and Monitoring Failures** | l'attaque a lieu et personne ne le voit |
| A10 | **Server-Side Request Forgery (SSRF)** | le serveur va chercher une URL choisie par l'attaquant |

---

## Et l'édition 2025 ?

Publiée fin 2025 ; mêmes idées, ordre et périmètres revus (vérifiez la version de référence sur `owasp.org/Top10`) :

| 2025 | Évolution par rapport à 2021 |
|---|---|
| A01 Broken Access Control | toujours n°1 ; **absorbe le SSRF** (ex-A10) |
| A02 Security Misconfiguration | monte de la 5e à la 2e place |
| A03 **Software Supply Chain Failures** | élargit l'ex-A06 : dépendances, **build, registres, CI** |
| A04 Cryptographic Failures | descend de la 2e place |
| A05 Injection | descend de la 3e place |
| A06 Insecure Design · A07 Authentication Failures · A08 Software or Data Integrity Failures | quasi inchangées |
| A09 Security Logging and **Alerting** Failures | l'accent passe sur l'alerte |
| A10 **Mishandling of Exceptional Conditions** | nouveau : erreurs mal gérées, *fail open* |

> Dans ce cours on suit **2021** (encore la référence des outils et de Juice Shop), en signalant les correspondances. La supply chain en n°3 : c'est exactement ce que fait votre pipeline depuis le Jour 3.

---

<!-- _class: code -->
## A01 — Contrôle d'accès défaillant (IDOR)

<div class="columns">
<div>

**Vulnérable** : l'identifiant suffit

```js
router.delete('/:id', async (req, res) => {
  // N'importe quel utilisateur connecté
  // supprime la tâche de n'importe qui
  await repo.remove(req.params.id);
  res.status(204).end();
});
```

</div>
<div>

**Corrigé** : on vérifie le propriétaire **côté serveur**

```js
router.delete('/:id', requireAuth, async (req, res) => {
  const ok = await repo.removeOwned(
    req.params.id, req.user.id, // WHERE id=$1 AND owner=$2
  );
  if (!ok) return res.status(404).end(); // pas 403 :
  res.status(204).end();                 // on ne confirme rien
});
```

</div>
</div>

- Aussi : routes admin seulement « cachées » dans le front, CORS `*` avec cookies, URL devinables
- **Détection** : difficile pour les outils (c'est de la logique métier) → **tests d'autorisation** automatisés (utilisateur A ne voit pas B), revue de code, Burp (*Autorize*), ZAP authentifié
- **Juice Shop** : défi « View Basket », « Admin Section »

---

<!-- _class: code -->
## A02 — Défaillances cryptographiques

<div class="columns">
<div>

**Vulnérable**

```js
import crypto from 'node:crypto';
// MD5, sans sel : cassé en secondes
// (tables arc-en-ciel)
const hash = crypto.createHash('md5')
  .update(password).digest('hex');

// et le site en HTTP simple
app.listen(80);
```

</div>
<div>

**Corrigé**

```js
import bcrypt from 'bcrypt';  // ou argon2
// lent + salé : coûteux à attaquer
const hash = await bcrypt.hash(password, 12);
const ok = await bcrypt.compare(input, hash);

// HTTPS partout (proxy du Jour 3) + HSTS :
// Strict-Transport-Security: max-age=31536000
```

</div>
</div>

- Aussi : secret JWT faible ou commité, clé en dur, données sensibles en clair en base, TLS désactivé (`rejectUnauthorized: false`)
- **Détection** : **Semgrep** (`md5`, `rejectUnauthorized`, secrets en dur), **gitleaks**, ZAP / testssl.sh (HTTP sans redirection, HSTS absent)
- **Juice Shop** : les mots de passe sont en **MD5** (visible dans le jeton JWT obtenu par injection SQL)

---

<!-- _class: code -->
## A03 — Injection (SQL, commande, XSS)

<div class="columns">
<div>

**Vulnérable**

```js
// SQL : la donnée devient du code
pool.query(`SELECT * FROM tasks
  WHERE title = '${req.query.q}'`);
// q = ' OR 1=1--  → toutes les lignes

// Commande système
exec('ping -c 1 ' + req.query.host);
// host = 8.8.8.8; cat /etc/passwd

// XSS : du HTML construit à la main
res.send('<h1>Bonjour ' + req.query.name);
```

</div>
<div>

**Corrigé**

```js
// Requête paramétrée : le pilote sépare
// le code SQL et les valeurs
pool.query('SELECT * FROM tasks WHERE title = $1',
  [req.query.q]);

// Pas de shell ; arguments séparés + validation
execFile('ping', ['-c', '1', host]);

// Échapper, ou renvoyer du JSON ; côté front :
el.textContent = task.title;  // jamais innerHTML
// + CSP en défense en profondeur
```

</div>
</div>

- **Détection** : **Semgrep** `p/nodejsscan` (*node_sqli_injection*, *generic_os_command_exec*, *express_xss*) ; **ZAP** scan actif, **sqlmap** ; ESLint `no-eval`
- TaskFlow utilise déjà `$1` dans `repositories/postgres.js` et `textContent` dans `main.js` : allez vérifier
- **Juice Shop** : « Login Admin » (SQL), « DOM XSS »

---

<!-- _class: code -->
## A04 — Conception non sûre

<div class="columns">
<div>

**Vulnérable** : aucune limite prévue

```js
// Réinitialisation du mot de passe :
// code à 4 chiffres, essais illimités
router.post('/reset', async (req, res) => {
  const user = await users.byEmail(req.body.email);
  if (req.body.code === user.resetCode) {
    await users.setPassword(user.id, req.body.pwd);
  }
});
```

</div>
<div>

**Corrigé** : la menace était prévisible dès le PLAN

```js
import rateLimit from 'express-rate-limit';
router.post('/reset',
  rateLimit({ windowMs: 15 * 60_000, limit: 5 }),
  async (req, res) => {
    // jeton aléatoire long (crypto.randomBytes),
    // usage unique, expire en 15 min
  });
```

</div>
</div>

- Aucune ligne n'est « fausse » : c'est le **scénario** qui l'est (10 000 combinaisons, pas de limite)
- Aussi : quantités négatives dans un panier, workflow qu'on peut sauter (payer → livrer)
- **Détection** : **threat modeling** (STRIDE), *abuse cases* dans les user stories, revue d'architecture ; les scanners ne le voient presque jamais
- **Juice Shop** : défi « Zero Stars » (envoyer une note de 0 que l'interface n'autorise pas)

---

<!-- _class: code -->
## A05 — Mauvaise configuration de sécurité

<div class="columns">
<div>

**Vulnérable**

```js
app.use((err, req, res, next) => {
  // stack trace, chemins, versions...
  res.status(500).send(err.stack);
});
// + X-Powered-By: Express
// + aucun en-tête de sécurité
// + /metrics ouvert sur Internet
```

```nginx
server_tokens on;   # Server: nginx/1.27.5
autoindex on;       # listing des fichiers
```

</div>
<div>

**Corrigé**

```js
app.disable('x-powered-by');
app.use((err, req, res, _next) => {
  log({ level: 'error', message: err.message });
  res.status(500).json({ error: 'Erreur interne' });
});
```

```nginx
server_tokens off;
add_header Content-Security-Policy
  "default-src 'self'; frame-ancestors 'none'" always;
add_header X-Content-Type-Options nosniff always;
```

</div>
</div>

- **Détection** : **ZAP baseline** (c'est son terrain : en-têtes, cookies, fuites), **nikto**, Trivy `config` / Checkov pour l'IaC et les Dockerfiles
- **TaskFlow** : c'est ce que vous corrigez dans le TP (`front/nginx.conf`)
- **Juice Shop** : « Error Handling », « Exposed Metrics », listing de `/ftp`

---

<!-- _class: code -->
## A06 — Composants vulnérables et obsolètes

<div class="columns">
<div>

**Vulnérable**

```json
{
  "dependencies": {
    "express": "4.17.1",
    "lodash": "4.17.15",
    "jsonwebtoken": "8.5.1"
  }
}
```

```dockerfile
FROM node:14   # plus maintenue depuis 2023
```

</div>
<div>

**Corrigé** : un **processus**, pas un geste

```bash
npm audit --audit-level=high   # bloque la PR
npm outdated                   # ce qui vieillit
npm audit fix                  # corrections compatibles
```

```dockerfile
FROM node:20-alpine            # version supportée
```

+ Dependabot (PR automatiques) + scan **hebdomadaire**

</div>
</div>

- Une dépendance saine aujourd'hui peut avoir une CVE **demain** sans changement de votre code → `schedule:` dans `security.yml`
- Une alerte dans une **devDependency** (vitest, vite) compte aussi : elle s'exécute dans le CI et sur vos postes
- **Détection** : **npm audit**, **Dependabot**, **Trivy** (image), OWASP Dependency-Check, Snyk ; en 2025, catégorie élargie à toute la **supply chain**

---

<!-- _class: code -->
## A07 — Identification et authentification

<div class="columns">
<div>

**Vulnérable**

```js
router.post('/login', async (req, res) => {
  const u = await users.byEmail(req.body.email);
  if (!u) return res.status(404)
    .json({ error: 'Email inconnu' });  // énumération
  if (u.password !== req.body.password) // en clair !
    return res.status(401)
      .json({ error: 'Mauvais mot de passe' });
  res.json({ token: jwt.sign({ id: u.id }, 'secret') });
});
```

</div>
<div>

**Corrigé**

```js
router.post('/login', loginLimiter, async (req, res) => {
  const u = await users.byEmail(req.body.email);
  const ok = u && await bcrypt.compare(
    req.body.password, u.hash);
  if (!ok) return res.status(401)   // même message
    .json({ error: 'Identifiants invalides' });
  res.json({ token: jwt.sign({ sub: u.id },
    process.env.JWT_SECRET, { expiresIn: '15m' }) });
});
```

</div>
</div>

- Aussi : pas de MFA, session qui n'expire jamais, jeton dans l'URL, mots de passe par défaut (`admin/admin`)
- **Détection** : revue de code, **Burp Intruder** / ZAP fuzzer (*credential stuffing*, force brute), Semgrep (secret JWT en dur), gitleaks
- **Juice Shop** : « Password Strength » (le mot de passe de l'admin est trivial)

---

<!-- _class: code -->
## A08 — Intégrité du logiciel et des données

<div class="columns">
<div>

**Vulnérable**

```js
// Désérialisation d'une donnée utilisateur
import serialize from 'node-serialize';
const prefs = serialize.unserialize(
  req.cookies.prefs);      // exécute du code !
```

```yaml
# CI : action non épinglée, script distant
- uses: un-auteur/une-action@main
- run: curl https://x.sh | bash
```

</div>
<div>

**Corrigé**

```js
// Données = JSON, validé par un schéma
const prefs = prefsSchema.parse(
  JSON.parse(req.cookies.prefs));
```

```yaml
# Action épinglée par SHA, binaire vérifié
- uses: actions/checkout@3d3c42e5...  # v7.0.1
- run: sha256sum -c gitleaks_checksums.txt
```

</div>
</div>

- Aussi : `npm install` sans lockfile, CDN sans **SRI** (`integrity="sha384-..."`), mise à jour automatique non signée
- **Détection** : Semgrep (`node-serialize`, `eval`), **actionlint** / zizmor / OpenSSF Scorecard (workflows), `npm ci` + lockfile, signature **cosign**, SBOM
- **Votre pipeline** : `security.yml` télécharge gitleaks **et vérifie sa somme SHA-256**

---

<!-- _class: code -->
## A09 — Journalisation et surveillance défaillantes

<div class="columns">
<div>

**Vulnérable**

```js
router.post('/login', async (req, res) => {
  if (!ok) {
    // rien n'est journalisé : 10 000 échecs
    // en 5 minutes passent inaperçus
    return res.status(401).end();
  }
  console.log('login', req.body); // mot de passe
});                               // dans les logs !
```

</div>
<div>

**Corrigé**

```js
if (!ok) {
  log({ level: 'warn', event: 'login_failed',
        email: maskEmail(req.body.email),
        ip: req.ip });          // pas le mot de passe
  return res.status(401).end();
}
```

```yaml
# Prometheus (Jour 4) : alerte sur le taux de 401
expr: rate(http_requests_total{status="401"}[5m]) > 5
```

</div>
</div>

- Journaliser les **événements de sécurité** (échecs d'authentification, refus d'accès, erreurs de validation), **jamais** les secrets ni les données personnelles en clair
- Logs **centralisés**, horodatés, conservés, avec **alerte** et un humain qui la reçoit (Jour 4 : Alertmanager)
- **Détection** : quasi impossible à scanner → exercices d'incident, revue des logs, *purple team*
- **Juice Shop** : « Access Log » (des logs exposés… à l'attaquant)

---

<!-- _class: code -->
## A10 — Server-Side Request Forgery (SSRF)

<div class="columns">
<div>

**Vulnérable**

```js
// "Importer une image depuis une URL"
router.post('/avatar', async (req, res) => {
  const r = await fetch(req.body.url);
  res.send(Buffer.from(await r.arrayBuffer()));
});
// url = http://169.254.169.254/latest/meta-data/
//   → identifiants cloud de la machine
// url = http://db:5432 ou http://api:3000/metrics
```

</div>
<div>

**Corrigé**

```js
const ALLOWED = new Set(['images.example.com']);
router.post('/avatar', async (req, res) => {
  const url = new URL(req.body.url);
  if (url.protocol !== 'https:' ||
      !ALLOWED.has(url.hostname)) {
    return res.status(400).json({ error: 'URL refusée' });
  }
  // + pas de redirections, timeout, taille max
});
```

</div>
</div>

- Le serveur est **à l'intérieur** du réseau : il joint ce que l'attaquant ne joint pas (BDD, métadonnées cloud, `/metrics`)
- Défense en profondeur : **liste blanche**, réseau Docker segmenté, egress filtré
- **Détection** : Semgrep (*express-ssrf*, `fetch(req.…)`), Burp **Collaborator**, ZAP scan actif ; en 2025, rattaché à A01

---

## 🧪 Exercice — Chasse aux failles sur OWASP Juice Shop (40 min)

→ `exercices/jour5/01-chasse-juice-shop.md`

```bash
docker run --rm -p 3002:3000 docker.io/bkimminich/juice-shop
# puis http://localhost:3002  (3000 = API TaskFlow, 3001 = Grafana)
```

| # | Défi | Catégorie OWASP 2021 |
|---|---|---|
| 1 | Trouver le **tableau des scores** caché | A05 (reconnaissance) |
| 2 | Se connecter en **admin** sans mot de passe | A03 Injection |
| 3 | Déclencher une **XSS DOM** | A03 Injection |
| 4 | Voir le **panier d'un autre** + la page d'**administration** | A01 |
| 5 | Lire un **document confidentiel** | A01 / A05 |
| 6 | Faire **parler** le serveur (erreurs, métriques) | A05 |

Pour chaque défi : indices progressifs, puis **« comment le pipeline l'aurait évité / détecté »** (c'est la partie notée à l'oral).

> Juice Shop est **fait pour être attaqué**, sur **votre** poste. Les mêmes gestes sur un site réel sans autorisation écrite sont un **délit** (prochain bloc).

---

<!-- _class: lead -->
# 7.4 Outils de pentest

---

## Méthodologie d'un test d'intrusion

```
 0. CADRAGE        1. RECONNAISSANCE     2. SCAN              3. EXPLOITATION       4. RAPPORT
 ──────────        ─────────────────     ───────              ───────────────       ─────────
 autorisation      passive : DNS,        ports, services,     prouver l'impact      constats classés
 écrite, périmètre whois, GitHub,        versions (nmap),     (sqlmap, Burp),       (CVSS), preuves,
 (IP, URL), dates, archives, offres      vulnérabilités       sans casser ni        recommandations,
 contacts, règles  d'emploi ; active :   (nikto, ZAP)         exfiltrer plus que    plan de correction,
 d'engagement      crawl, robots.txt                          nécessaire            contre-test
```

- **Boîte noire** (rien n'est fourni), **grise** (un compte de test), **blanche** (code + doc)
- Référentiels : **OWASP WSTG** (*Web Security Testing Guide*), PTES, OSSTMM ; **ASVS** comme liste d'exigences
- Le livrable, c'est le **rapport** : un pentest sans rapport exploitable n'a servi à rien

---

## Le cadre légal : sans autorisation écrite, c'est un délit

**Code pénal, article 323-1** : accéder ou se maintenir **frauduleusement** dans tout ou partie d'un système de traitement automatisé de données (STAD) : **3 ans** d'emprisonnement et **100 000 €** d'amende ; **5 ans et 150 000 €** si des données sont supprimées ou modifiées, ou le fonctionnement altéré.
Articles voisins : 323-2 (entraver le fonctionnement), 323-3 (introduire, extraire, modifier des données), 323-3-1 (détenir ou fournir un outil d'attaque **sans motif légitime**).

**Avant de lancer un seul scan :**
- une **autorisation écrite** du propriétaire du système (pas du stagiaire d'à côté) : périmètre, dates, techniques autorisées, contacts d'urgence
- un hébergeur tiers (cloud, SaaS) a ses propres règles : sa politique de test s'applique aussi
- **Bug bounty** (YesWeHack, HackerOne, programmes d'éditeurs) : l'autorisation, c'est la **politique du programme** ; hors périmètre = hors la loi
- Trouvé une faille par hasard ? **Divulgation responsable** : prévenir l'éditeur (fichier `security.txt`) ou l'ANSSI, sans exploiter davantage

> Ici : Juice Shop et TaskFlow **sur votre poste**. C'est le seul périmètre autorisé de la semaine.

---

## nmap : qu'est-ce qui écoute ?

```bash
nmap -sV -p 1-10000 127.0.0.1         # ports TCP ouverts + version des services
nmap -sV --script http-headers,http-title -p 8080,3002 127.0.0.1
```

```
PORT     STATE SERVICE VERSION
3002/tcp open  http    Node.js Express framework
8080/tcp open  http    nginx
9090/tcp open  http    Golang net/http server (Prometheus)
```

- Phase **scan** : cartographier la **surface d'attaque** (un port oublié = une porte)
- Sur votre poste, il répond à : *« ma stack expose-t-elle autre chose que prévu ? »* (l'API et Postgres ne doivent **pas** apparaître)
- Côté défense : pare-feu, ports liés à `127.0.0.1`, réseaux Docker internes ; `server_tokens off` rend `-sV` moins bavard

---

## OWASP ZAP : le scanner web libre

**Proxy d'interception + scanner** : il se place entre le navigateur et le site, enregistre, analyse, attaque.

| Mode | Ce qu'il fait | Où |
|---|---|---|
| **Baseline** (`zap-baseline.py`) | spider ~1 min + analyse **passive** (aucune attaque) | **CI à chaque PR** |
| **Full scan** (`zap-full-scan.py`) | spider + **scan actif** (injections réelles) | staging, la nuit, cible autorisée |
| **API scan** (`zap-api-scan.py`) | à partir d'un OpenAPI / GraphQL | API |
| **Desktop** | proxy manuel, *fuzzer*, *Manual Explore* | pentest manuel, apprentissage |

```bash
docker run --rm --network host -v "$PWD/zap:/zap/wrk:rw" ghcr.io/zaproxy/zaproxy:2.17.0 \
  zap-baseline.py -t http://localhost:8080 -c rules.tsv -I -r rapport.html
```

> Le scan **actif** envoie de vraies attaques : jamais sur une prod, jamais sans autorisation.

---

## Burp Suite, sqlmap, nikto

| Outil | Rôle | Commande type (cible locale) |
|---|---|---|
| **Burp Suite** (Community gratuite, Pro payante) | **proxy d'interception** de référence : *Repeater* (rejouer et modifier une requête), *Intruder* (fuzzing), *Decoder* ; Pro : scanner, *Collaborator* (SSRF) | navigateur intégré → Proxy → *Send to Repeater* |
| **sqlmap** | détecte et **exploite** les injections SQL (extraction de tables) | `sqlmap -u "http://localhost:3002/rest/products/search?q=x" --batch --level 2` |
| **nikto** | scanner de **configuration** de serveur web : fichiers par défaut, versions, en-têtes | `nikto -h http://localhost:8080` |

- ZAP ≈ Burp en libre : en entreprise, les pentesteurs utilisent surtout **Burp Pro** ; dans un CI, surtout **ZAP**
- sqlmap est très **bruyant** et peut modifier ou bloquer une base : périmètre et sauvegarde d'abord
- Distributions prêtes à l'emploi : Kali Linux, Parrot (même cadre légal)

---

## 🎬 Démo — ZAP sur Juice Shop

→ `demos/demo-zap-juice-shop/`

1. Juice Shop sur `http://localhost:3002`
2. **ZAP baseline** en conteneur : rapport HTML, lecture des alertes (CSP absente, CORS `*`, en-têtes…)
3. Comparaison : **ce que la baseline ne voit pas** (l'injection SQL du login) → seul un scan **actif** ou un humain la trouve
4. (Si le temps le permet) **ZAP Desktop** : *Manual Explore*, historique des requêtes, rejouer le login avec `' OR 1=1--`

**Ce qu'on retient :**
- la baseline est **rapide et sûre** → elle a sa place à chaque PR
- elle ne remplace ni un scan actif planifié sur staging, ni un pentest humain, ni la **revue de code**

---

## 🛠️ TP fil rouge — étape 5 : pipeline DevSecOps (55 min)

→ `tp/fil-rouge-taskflow/etape5-devsecops.md`

| Étape | Durée | Livrable |
|---|---|---|
| 5.1 Lancer les outils **en local** | 10 min | savoir ce que le CI va dire avant de pousser |
| 5.2 Écrire `security.yml` (4 jobs) | 15 min | PR avec les 4 checks |
| 5.3 **Lire et trier** les rapports | 10 min | tableau vrai / faux positif |
| 5.4 **Corriger** : en-têtes dans `front/nginx.conf`, dépendances | 15 min | ZAP sans WARN, `npm audit` vert |
| 5.5 Documenter dans `docs/SECURITE.md` | 5 min | exceptions justifiées |

Bonus : CodeQL, SBOM avec `syft` / `trivy sbom`, `app.disable('x-powered-by')` dans l'API, faire échouer Semgrep exprès.

---

## Quiz de fin de séance

1. Quelle est la différence entre un **SAST** et un **DAST** ? Donnez un outil de chaque et le moment où il tourne dans le pipeline.
2. `pool.query("SELECT * FROM tasks WHERE id = " + req.params.id)` : quelle catégorie OWASP, quelle correction, quel outil l'aurait signalé ?
3. Pourquoi `security.yml` tourne-t-il aussi **chaque semaine**, alors que le code n'a pas changé ?
4. ZAP signale « *Information Disclosure - Suspicious Comments* » dans le bundle Vite minifié. Que faites-vous, concrètement ?
5. Un ami vous demande de « tester rapidement » la sécurité du site de son employeur avec nmap et sqlmap. Que répondez-vous ?

<!--
Réponses :
1. SAST = analyse du code source sans l'exécuter (Semgrep, CodeQL), à chaque PR, très tôt. DAST = attaque l'application qui tourne, de l'extérieur (ZAP, Burp), après démarrage de la stack (job CI, staging). Le SAST voit le code jamais exécuté ; le DAST voit la configuration réelle (en-têtes, serveur).
2. A03 Injection (SQL). Requête paramétrée : pool.query('SELECT * FROM tasks WHERE id = $1', [id]) + validation de l'id (parseId). Semgrep p/nodejsscan (node_sqli_injection) en SAST, sqlmap / ZAP actif en DAST.
3. Les CVE sont publiées en continu : une dépendance saine lundi peut être vulnérable mercredi. Le scan planifié (et Dependabot) détecte ce que personne n'a « changé ».
4. Triage : ouvrir le fichier et la ligne, vérifier que les mots-clés (TODO, select, user…) viennent de la bibliothèque minifiée et ne révèlent rien → faux positif ; IGNORE de la règle 10027 dans .zap/rules.tsv (ou mieux, limité à l'URL si possible) + ligne dans docs/SECURITE.md (quoi, pourquoi, qui, date de revue). Pas d'ignore global sans justification.
5. Non : sans autorisation écrite du propriétaire du système (l'employeur, pas l'ami), c'est un accès frauduleux à un STAD (art. 323-1 du Code pénal, jusqu'à 3 ans et 100 000 €), et détenir des outils d'attaque sans motif légitime est visé par le 323-3-1. Proposer : un pentest cadré (contrat, périmètre, dates), un programme de bug bounty s'il existe, ou s'entraîner sur Juice Shop.
-->

---

## Quiz — Réponses

1. **SAST** : lit le **code** sans l'exécuter (Semgrep, CodeQL), à chaque PR. **DAST** : attaque l'**appli qui tourne** de l'extérieur (ZAP, Burp), une fois la stack démarrée. Complémentaires : code jamais exécuté vs configuration réelle
2. **A03 Injection SQL** → requête **paramétrée** (`$1`) + validation de l'id ; Semgrep `p/nodejsscan` (*node_sqli_injection*), sqlmap / ZAP actif
3. Les **CVE sont publiées en continu** : une dépendance saine lundi peut être vulnérable mercredi (shift-right)
4. **Triage** : ouvrir la ligne, constater que c'est du code de bibliothèque minifié → **faux positif** → `10027 IGNORE` dans `.zap/rules.tsv` **+** justification datée dans `docs/SECURITE.md`
5. **Non** : sans **autorisation écrite** du propriétaire, c'est un accès frauduleux (art. **323-1** du Code pénal, 3 ans et 100 000 €). Pentest cadré, bug bounty officiel, ou Juice Shop

---

## Récap de la semaine : de l'idée à la prod, en sécurité

| Jour | Boucle DevOps | Ce que votre dépôt `taskflow` sait faire maintenant |
|---|---|---|
| **1** | culture, PLAN, CODE | CALMS, DORA, *value stream* ; ruleset sur `main`, PR revues, conflits maîtrisés |
| **2** | BUILD, TEST | `ci.yml` : lint, tests unitaires + intégration Postgres, build, cache, matrix ; Jenkins / GitLab CI comparés |
| **3** | RELEASE, DEPLOY | `release.yml` : images ghcr.io (SHA), **Trivy**, staging auto, prod **avec approbation**, rollback ; gitleaks, Dependabot |
| **4** | OPERATE, MONITOR | staging en **OpenTofu** (`iac.yml`), Ansible ; Prometheus, Grafana, Alertmanager ; incident → post-mortem → issue |
| **5** | partout | `security.yml` : **gitleaks + npm audit + Semgrep + ZAP**, en-têtes de sécurité, `SECURITE.md` |

**Les idées à garder :**
- *On n'automatise que ce qu'on sait faire à la main* : chaque job de vos workflows, vous l'avez d'abord lancé en local
- *La sécurité commence dès le premier pipeline* : chaque contrôle a sa place dans la boucle, et un outil qui alerte **n'est utile que si quelqu'un trie**
- Un pipeline se **justifie** : pour chaque étape, sachez dire ce qu'elle protège et ce qu'elle coûte

---

## Pour aller plus loin

- **OWASP** : Top 10 (`owasp.org/Top10`), **Cheat Sheet Series** (une fiche par sujet), **ASVS**, **WSTG**
- **Entraînement légal** : OWASP Juice Shop (100+ défis), PortSwigger **Web Security Academy** (gratuit, labs Burp), Root-Me, TryHackMe, HackTheBox
- **ANSSI** : guides de développement sécurisé, `cyber.gouv.fr` ; **CNIL** pour les données personnelles
- **Supply chain** : OpenSSF Scorecard, SLSA, Sigstore (cosign)
- Antisèche de la séance : `ressources/cheatsheet-devsecops.md`

> Évaluation : QCM maintenant (15 min), puis l'état final de votre dépôt `taskflow` (grille `evaluation/grille-evaluation.md`, bloc DevSecOps = 15 points).

# Solutions — Exercice Jour 5 (document formateur)

> À ne pas distribuer avant la correction. Les énoncés officiels et les charges exactes de chaque défi sont visibles
> sur le *Score Board* de Juice Shop une fois celui-ci trouvé. Ce document donne les réponses et surtout la grille de
> correction de la **colonne « pipeline »**, qui est le cœur pédagogique de l'exercice.

## Rappel de cadrage

- Cible **locale uniquement**, port **3002** (3000 = API TaskFlow dev, 3001 = Grafana). Redémarrer le conteneur
  réinitialise toute la progression (elle est en mémoire).
- Version testée au moment de la rédaction : image `bkimminich/juice-shop` (≈ v20). Les noms de défis sont stables ;
  les détails d'UI peuvent bouger d'une version à l'autre.
- Ne pas transformer l'exercice en concours de « qui débloque le plus de défis » : l'objectif est la **colonne
  pipeline**, pas le score.

---

## Défi 1 — Score Board · A05 Security Misconfiguration

- **Réussite** : route `#/score-board` (nom trouvable dans `main.js`). La page se charge car aucun contrôle d'accès
  serveur ne la protège.
- **Cause racine** : sécurité par l'obscurité ; une page « cachée » sans contrôle n'est pas protégée.
- **Correction** : contrôle d'accès **côté serveur** pour toute page sensible ; ne pas compter sur l'absence de lien.
- **Pipeline** : revue de code ; ZAP (spider) liste les routes atteignables ; test d'autorisation. Les scanners ne
  « savent » pas qu'une page devrait être protégée → la revue reste nécessaire.

## Défi 2 — Login Admin · A03 Injection (SQL)

- **Réussite** : e-mail `' OR 1=1--` (+ n'importe quel mot de passe) dans `/rest/user/login` ; la condition devient
  toujours vraie et la requête renvoie le premier compte (l'admin). Le JWT renvoyé contient le hash **MD5** du mot
  de passe (A02 en bonus).
- **Correction** : requête **paramétrée** (`WHERE email = $1 AND password = $2`), hachage **bcrypt/argon2**, message
  d'erreur unique (anti-énumération), limite de tentatives.
- **Pipeline** : **SAST** Semgrep `p/nodejsscan` → `ajinabraham.njsscan.database.sql_injection.node_sqli_injection`
  (vérifié : détecté sur un template literal `pool.query(\`... ${req.query.q} ...\`)`). **DAST** : ZAP scan **actif**
  ou **sqlmap**. La **baseline** ZAP ne le trouve pas (c'est passif) → point clé à faire remarquer.

## Défi 3 — DOM XSS · A03 Injection

- **Réussite** : charge officielle `<iframe src="javascript:alert(\`xss\`)">` dans la barre de recherche ; le front
  réinjecte la saisie via une API qui interprète le HTML (bypassSecurityTrustHtml côté Angular).
- **Correction** : `textContent` au lieu d'`innerHTML` (TaskFlow le fait déjà dans `front/src/main.js`) ; CSP stricte
  en défense en profondeur (celle de TaskFlow : `script-src 'self'`, pas d'inline).
- **Pipeline** : Semgrep (`express_xss`, `raw-html-format`) côté serveur ; ESLint (`no-unsanitized`) pour `innerHTML`
  côté front ; ZAP détecte surtout la XSS **réfléchie/stockée**, pas la DOM. → revue + CSP indispensables.

## Défi 4 — View Basket + Admin Section · A01 Broken Access Control

- **Réussite** :
  - *View Basket* : après login, modifier l'id dans `/rest/basket/<id>` (IDOR) ; l'API ne vérifie pas le
    propriétaire.
  - *Admin Section* : route `#/administration`, atteignable sans rôle admin car non vérifié côté serveur.
- **Correction** : vérifier la propriété (`WHERE id = $1 AND owner_id = $2`) et le rôle (middleware) **côté
  serveur** ; renvoyer 404 plutôt que 403 pour ne pas confirmer l'existence.
- **Pipeline** : les scanners voient très mal l'autorisation → **tests d'autorisation** automatisés (A ne lit pas la
  ressource de B), revue de code, Burp *Autorize* / ZAP authentifié. C'est le défi où « aucun outil ne l'aurait vu,
  mais un test oui » est la **bonne** réponse.

## Défi 5 — Confidential Document / Forgotten Developer Backup · A01 + A05

- **Réussite** : `/ftp/` a le **listing activé** ; `acquisitions.md` s'ouvre directement. Pour les `.bak`, le serveur
  bloque l'extension et le contournement passe par un **null byte encodé** (`%2500.md`) — charge exacte sur le Score
  Board.
- **Cause racine** : données sensibles laissées dans un dossier public + listing de répertoire actif + filtrage
  d'extension contournable (liste noire au lieu de liste blanche).
- **Correction** : pas de secret/sauvegarde dans un dossier servi ; `autoindex off` (défaut Nginx) ; liste blanche
  d'extensions ; `.dockerignore` pour ne pas copier ces fichiers dans l'image.
- **Pipeline** : **gitleaks** (si les fichiers passent par Git), **nikto** / **ZAP** (listing, fichiers de
  sauvegarde), revue des `COPY` du Dockerfile.

## Défi 6 — Error Handling + Exposed Metrics · A05 + A09

- **Réussite** :
  - *Error Handling* : provoquer une erreur non gérée (route API inexistante type `/rest/qwertz`, ou un type de
    paramètre inattendu) → page d'erreur avec pile d'appels et chemins internes.
  - *Exposed Metrics* : endpoint `/metrics` (Prometheus) servi **sans authentification**.
- **Correction** : gestionnaire d'erreurs qui journalise le détail et renvoie un message générique (comme l'API
  TaskFlow : `{ error: 'Erreur interne du serveur' }`, pas de stack au client) ; `/metrics` non exposé à l'extérieur
  (TaskFlow : accessible uniquement sur le réseau Docker, jamais routé par Nginx — rappel du Jour 4).
- **Pipeline** : ZAP (fuite d'info, en-têtes) ; revue de la config du reverse proxy ; alerte de monitoring (A09).

---

## Grille de correction rapide (oral, /6)

Pour chaque défi présenté, 1 point si le binôme donne **à la fois** : (a) la bonne catégorie OWASP, (b) la cause
racine en une phrase, (c) la case du pipeline (outil + étape) **ou** le contrôle humain équivalent. Un défi « non
débloqué » mais correctement analysé vaut autant qu'un défi débloqué sans analyse.

Message à faire passer en conclusion : **ZAP baseline (CI à chaque PR) n'aurait trouvé que les défis 5 et 6.** Les
défis 2 et 3 relèvent du SAST **à condition** que le code soit reconnaissable, les défis 1 et 4 de la revue et des
tests. D'où le pipeline du TP : plusieurs outils complémentaires, et un humain qui **trie**.

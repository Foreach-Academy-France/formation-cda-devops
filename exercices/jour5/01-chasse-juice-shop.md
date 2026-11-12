# Exercice 1 — Chasse aux failles sur OWASP Juice Shop (40 min)

> **Objectif pédagogique** : reconnaître six familles de failles de l'OWASP Top 10 (édition 2021) sur une cible
> d'entraînement **autorisée**, et surtout répondre à la question du DevOps : **à quel endroit du pipeline aurait-on
> pu éviter ou détecter cette faille ?**
>
> **Modalité** : en binôme. Chaque défi donne la catégorie OWASP et une piste conceptuelle ; l'énoncé officiel complet
> de chaque défi est sur le *Score Board* de Juice Shop (défi 1). **Restitution** (5 dernières minutes) : chaque binôme
> présente **un** défi et sa ligne « pipeline ».

---

## Mise en place (2 min)

```bash
docker run --rm -p 3002:3000 docker.io/bkimminich/juice-shop
# ou : bash exercices/jour5/lancer-juice-shop.sh
```

Ouvrez `http://localhost:3002`, fermez les bannières. Gardez les **outils de développement** (F12) ouverts, onglet
*Réseau* : beaucoup d'informations y transitent. Un défi réussi affiche une **bannière verte**.

> **Si ça ne marche pas**
> - `port is already allocated` : un autre service occupe 3002 (`docker ps`) ; changez le port de gauche : `-p 3003:3000`.
> - Page blanche : Juice Shop met 10 à 30 s à démarrer ; attendez `Server listening on port 3000`.
> - Sous Podman, l'image est déjà préfixée par `docker.io/`.

---

## Votre fiche de rendu

Recopiez ce tableau et remplissez-le au fur et à mesure. **La dernière colonne est la plus importante** et c'est
elle qui est évaluée à l'oral.

| # | Défi | Fait ? | OWASP 2021 | Cause racine (1 phrase) | Correction (code / config) | Où le pipeline l'aurait vu (outil, étape) |
|---|---|---|---|---|---|---|
| 1 | Score Board | | A05 | | | |
| 2 | Login Admin | | A03 | | | |
| 3 | DOM XSS | | A03 | | | |
| 4 | View Basket + Admin Section | | A01 | | | |
| 5 | Confidential Document | | A01 / A05 | | | |
| 6 | Error Handling + Exposed Metrics | | A05 / A09 | | | |

« Aucun outil automatique ne l'aurait vu » est une réponse **acceptable** si vous dites **qui** l'aurait vu à la
place (revue de code, test d'autorisation, threat modeling).

---

## Défi 1 — Trouver le tableau des scores (A05, 5 min)

La page *Score Board* existe mais n'est dans aucun menu : il faut la **découvrir** (phase de reconnaissance). Elle
liste ensuite tous les défis et leur énoncé.

- **Piste** : dans une SPA, toutes les routes du front sont livrées au navigateur dans le JavaScript. L'onglet
  *Sources* et une recherche sur le mot « score » vous mèneront au nom de la route.
- **Pourquoi c'est une faille (A05)** : la sécurité par l'obscurité (« cacher » une page sans contrôle d'accès
  réel) ne protège rien ; ce qui n'est pas protégé côté **serveur** est accessible.
- **Pipeline** : une route sensible seulement masquée dans le front se repère en **revue de code** et par un test
  d'autorisation ; ZAP (spider) finit souvent par trouver les routes exposées.

---

## Défi 2 — Se connecter en administrateur (A03 Injection, 6 min)

Le formulaire de connexion construit sa requête SQL **à partir du texte saisi** sans le séparer du code.

- **Piste conceptuelle** : rappelez-vous le slide A03. Si l'e-mail saisi est inséré tel quel dans
  `... WHERE email = '<saisie>' AND ...`, une saisie bien choisie peut **changer le sens** de la condition et
  rendre la fin de la requête inopérante. Regardez la réponse de `/rest/user/login` dans l'onglet *Réseau*.
- **Observation bonus** : décodez le jeton JWT renvoyé (coller sur `jwt.io`, ou juste lire la partie du milieu en
  base64). Le hachage du mot de passe y est en **MD5** — c'est le défi A02 « Cryptographic Failures » en prime.
- **Correction** : requête **paramétrée** (`WHERE email = $1`), hachage **bcrypt/argon2**, même message d'erreur
  pour « e-mail inconnu » et « mauvais mot de passe » (anti-énumération).
- **Pipeline** : **SAST** Semgrep (`p/nodejsscan`, règle `node_sqli_injection`) à la PR ; **DAST** ZAP scan actif
  ou **sqlmap** sur la cible autorisée ; revue de code.

---

## Défi 3 — XSS DOM (A03 Injection, 6 min)

Un champ de recherche réinjecte la saisie dans la page **sans l'échapper**, via une API du DOM qui interprète le
HTML.

- **Piste** : cherchez un champ dont le contenu réapparaît tel quel dans la page (la barre de recherche). L'énoncé
  exact du défi sur le Score Board indique la charge `<iframe src="javascript:alert(\`xss\`)">` à utiliser — c'est
  une démonstration **inoffensive** (une simple boîte de dialogue).
- **Pourquoi « DOM »** : l'injection se produit **dans le navigateur** (le JS du front écrit la saisie dans le DOM),
  pas dans une réponse du serveur (ce serait une XSS réfléchie ou stockée).
- **Correction** : côté front, écrire la donnée avec `element.textContent`, **jamais** `innerHTML` (c'est exactement
  ce que fait `front/src/main.js` de TaskFlow) ; en défense en profondeur, une **CSP** stricte bloque l'exécution.
- **Pipeline** : Semgrep (`express_xss`, `raw-html-format`) pour le code serveur, ESLint pour `innerHTML` côté front,
  ZAP pour la XSS réfléchie ; la XSS **DOM** est difficile à détecter automatiquement → revue + CSP.

---

## Défi 4 — Accéder au panier d'un autre, puis à l'administration (A01, 8 min)

Deux failles de **contrôle d'accès** :

- **Panier d'un autre** : après connexion, observez l'appel `/rest/basket/<id>` dans l'onglet *Réseau*. L'API
  renvoie le panier **à partir de l'identifiant dans l'URL**, sans vérifier qu'il appartient à l'utilisateur
  connecté. C'est une **IDOR** : changer le numéro suffit.
- **Section admin** : il existe une route d'administration côté front, atteignable sans être administrateur parce
  que le serveur ne vérifie pas le rôle. On la découvre comme le Score Board (défi 1).
- **Correction** : vérifier **côté serveur** que la ressource appartient à l'utilisateur (`WHERE id = $1 AND
  owner_id = $2`) et exiger le bon rôle (middleware `requireRole('admin')`) ; ne pas se reposer sur le fait qu'une
  route est « cachée ».
- **Pipeline** : les scanners voient **mal** la logique d'autorisation → **tests d'autorisation** automatisés
  (l'utilisateur A ne doit pas lire la ressource de B), revue de code, Burp *Autorize* / ZAP authentifié.

---

## Défi 5 — Lire un document confidentiel / une sauvegarde oubliée (A01 / A05, 6 min)

Un dossier de fichiers statiques est servi avec **listing activé** : on voit tout son contenu, y compris des fichiers
qui n'auraient pas dû rester là.

- **Piste** : explorez le chemin `/ftp` du serveur. Certains fichiers s'ouvrent directement ; pour d'autres, le
  serveur refuse certaines extensions — l'énoncé du défi « Forgotten Developer Backup » explique le contournement
  d'extension à employer (reconnaissance + mauvaise configuration).
- **Cause racine** : **données sensibles exposées** (A02/A05) + **listing de répertoire** laissé actif (A05).
- **Correction** : ne jamais déposer de secrets ou de sauvegardes dans un dossier public ; désactiver le listing
  (`autoindex off`, comportement par défaut de Nginx), filtrer les extensions **par liste blanche**.
- **Pipeline** : **gitleaks** aurait bloqué ces fichiers s'ils étaient passés par Git ; **nikto** / **ZAP** repèrent
  un listing actif et des fichiers de sauvegarde ; revue des `COPY` dans le Dockerfile (ne copier que le nécessaire).

---

## Défi 6 — Faire parler le serveur : erreurs et métriques (A05 / A09, 6 min)

- **Erreur non gérée** : demandez au serveur quelque chose d'inattendu (par exemple une route d'API inexistante ou
  un paramètre d'un type incorrect) et regardez la réponse. Juice Shop renvoie une **page d'erreur bavarde** (type,
  pile d'appels, chemins internes) : une fuite d'information utile à un attaquant (A05, et A10 « Mishandling of
  Exceptional Conditions » en 2025).
- **Métriques exposées** : Juice Shop publie un endpoint de métriques Prometheus accessible **sans authentification**.
  Retrouvez-le (pensez au nom standard vu au Jour 4). C'est un défaut d'**observabilité** : des données internes
  servies à tout le monde.
- **Correction** : gestionnaire d'erreurs qui **journalise** le détail côté serveur et renvoie un message générique
  (`{ "error": "Erreur interne" }`, exactement comme l'API TaskFlow) ; `/metrics` **non routé** vers l'extérieur
  (dans TaskFlow, il reste sur le réseau Docker interne, jamais exposé par Nginx — rappel du Jour 4).
- **Pipeline** : **ZAP** (fuite d'information, en-têtes), revue de la configuration du reverse proxy ; une alerte
  de monitoring sur les endpoints sensibles (A09 : journaliser et surveiller).

---

## Restitution (5 min)

Chaque binôme présente **un** défi : la faille, sa catégorie OWASP, **et** la case du pipeline qui l'aurait
arrêtée. On en tire la conclusion du bloc 7.4 :

- un **scanner** (ZAP baseline) trouve surtout la **configuration** (défis 5 et 6) ;
- un **SAST** trouve le code dangereux (défis 2 et 3) **s'il est écrit de façon reconnaissable** ;
- le **contrôle d'accès** (défis 1 et 4) échappe presque toujours aux outils → **tests** et **revue** ;
- aucun outil ne remplace l'autre : c'est la **défense en profondeur**.

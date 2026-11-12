# Exercice 3.2 — La configuration Nginx du proxy à corriger

| | |
|---|---|
| **Durée** | 20 min |
| **Bloc** | 4.3 — Outils et pratiques (reverse proxy, HTTPS) |
| **Prérequis** | avoir lu `compose.prod.yaml` (service `proxy`) ; Docker et Compose |
| **Fichiers fournis** | [`taskflow-casse.conf`](taskflow-casse.conf), [`nginx-labo/`](nginx-labo/) (`compose.yaml`, `gen-cert.sh`) |

## Contexte

En production, un seul conteneur publie des ports : **`proxy`** (Nginx). Il termine le TLS et transmet au **`front`**
(port 80 sur le réseau privé de la stack), qui sert le site et relaie `/api` et `/health` vers l'API.

```text
navigateur ──https──▶ proxy :443 ──http──▶ front :80 ──▶ api :3000 ──▶ db :5432
           ──http───▶ proxy :80  ──301──▶ (redirection vers https)
```

| Sur le poste (`~/taskflow-prod/`) | Dans le conteneur `proxy` |
|---|---|
| `nginx/taskflow.conf` | `/etc/nginx/conf.d/default.conf` |
| `certs/taskflow.crt`, `certs/taskflow.key` | `/etc/nginx/certs/` |

Un collègue a écrit la configuration du proxy et ouvert une PR. Le proxy ne démarre pas, et même une fois démarré,
plusieurs choses sont fausses. Le fichier contient **7 problèmes** : 2 empêchent le démarrage, 1 casse le service,
4 sont des défauts de sécurité ou de fonctionnement que `nginx -t` ne verra jamais.

## Objectif

Corriger la configuration, la **tester avant de l'appliquer**, vérifier le résultat, puis rédiger le commentaire de
revue que vous auriez laissé sur la PR.

## Mise en place

Le labo reproduit la partie réseau de la stack : un `front` factice (Nginx « Welcome to nginx! ») et le `proxy`, sur
les ports **8880** (HTTP) et **8444** (HTTPS).

```bash
cd nginx-labo
bash gen-cert.sh                        # certificat auto-signé dans ./certs/
cp ../taskflow-casse.conf taskflow.conf
docker compose up -d && docker compose ps
```

## À faire

1. Diagnostiquez le démarrage : `docker compose logs proxy`. Le conteneur étant arrêté, testez la configuration
   dans un conteneur jetable : `docker compose run --rm --no-deps proxy nginx -t`. Corrigez jusqu'à `test is successful`.
2. Démarrez (`docker compose up -d`) et testez `curl -I http://localhost:8880/` et `curl -k https://localhost:8444/`.
   Lisez le log d'erreur pour la réponse HTTPS.
3. Trouvez les problèmes restants. Pour chacun : **ligne, problème, conséquence, correction**.
4. Appliquez vos corrections **sans coupure** : `docker compose exec proxy nginx -t && docker compose exec proxy nginx -s reload`.
5. Vérifiez (résultat attendu ci-dessous), puis `docker compose down`.

## Résultat attendu

```text
$ curl -sI -H 'Host: taskflow.localhost' http://localhost:8880/ | grep -iE '^HTTP|^location'
HTTP/1.1 301 Moved Permanently
Location: https://taskflow.localhost/

$ curl -sk https://localhost:8444/ | grep title
<title>Welcome to nginx!</title>

$ curl -sk --tls-max 1.1 https://localhost:8444/ -o /dev/null -w '%{http_code}\n'
000                       # TLS 1.0 / 1.1 refusés : la poignée de main échoue
```

## Indices (si vous bloquez plus de 5 minutes)

<details>
<summary>Indice 1 — la 502</summary>

`connect() failed (111: Connection refused) ... upstream: "http://127.0.0.1:8080/"`. Dans un conteneur, `127.0.0.1`
est le conteneur lui-même. Quel est le nom du service à joindre, et sur quel port écoute-t-il **dans le réseau** ?
</details>

<details>
<summary>Indice 2 — ce que nginx -t ne voit pas</summary>

Regardez : ce que fait le bloc `listen 80` ; ce qui manque au bloc `listen 443` par rapport au premier ; les versions
de TLS acceptées ; ce que l'application sait du client réel (IP, protocole).
</details>

## Questions de justification

1. Pourquoi est-ce une bonne pratique que **seul** le proxy publie des ports ? Que gagne-t-on en sécurité **et** en
   souplesse d'exploitation ?
2. Le staging de TaskFlow n'a **pas** de proxy ni de TLS (front publié sur 8081). Est-ce acceptable ? Quels écarts
   staging/prod cela introduit-il, et quels bugs pourraient passer le staging et casser la prod ?
3. Le front fait lui-même `proxy_pass` vers l'API en résolvant `api` toutes les 10 s, alors que le proxy résout
   `front` une seule fois au démarrage. Quelle conséquence pour un redéploiement ? Comment `deploy.sh` la traite-t-il ?

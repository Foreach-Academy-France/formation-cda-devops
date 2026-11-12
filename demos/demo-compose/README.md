# Démo — Docker Compose : web + Postgres + Adminer

| | |
|---|---|
| **Jour / bloc** | Jour 2 matin — rappel Docker express pendant l'étape 0 du fil rouge (**démo de secours** : à utiliser si la salle bloque sur les questions Docker de `etape0-mise-en-place.md`) |
| **Durée** | 10 min en version express (étapes 1, 3, 4, 7, 8, 9) ; 25 min en version complète |
| **Prérequis** | Docker Compose v2 (`docker compose version`), `curl`, ports **3002** et **8082** libres (modifiables : `WEB_PORT=…`, `ADMINER_PORT=…`) ; images `postgres:16-alpine`, `adminer:4`, `node:20-alpine` pré-téléchargées |
| **Ce qu'on montre** | passer de 3 `docker run` à 1 fichier ; `services`, `build`, `image`, `ports`, `environment`, `.env`, `volumes`, `depends_on` + `condition: service_healthy`, `healthcheck` ; résolution DNS par nom de service ; `up -d`, `ps`, `logs`, `exec`, `down`, `down -v` ; persistance par volume ; comportement de `/health` quand la base tombe |

## Contenu du dossier

| Fichier | Rôle |
|---|---|
| `compose.yaml` | 3 services commentés : `db` (Postgres 16 + volume + healthcheck, **sans** port publié), `web` (build local, attend `db` healthy), `adminer` |
| `.env.example` | variables `POSTGRES_*` et ports (à copier en `.env`, jamais commité) |
| `app/` | compteur de visites Node 20 + `pg` : `GET /` insère une visite et renvoie le total, `GET /health` → 200 ou 503 |
| `demo.sh` | déroulé rejouable |

## Lancer

```bash
bash demos/demo-compose/demo.sh
WEB_PORT=3010 ADMINER_PORT=8090 bash demos/demo-compose/demo.sh   # si les ports sont pris
DEMO_AUTO=1 bash demos/demo-compose/demo.sh                       # test sans pause
```

À la main (pour laisser la stack tourner pendant les questions) :

```bash
cd demos/demo-compose
cp .env.example .env
docker compose up -d --build
docker compose ps
# … puis à la fin :
docker compose down -v
```

## Lien avec TaskFlow

Mêmes mécanismes que le `compose.yaml` fourni dans le starter (volume nommé, healthcheck `pg_isready`, `depends_on: service_healthy`, base sans port publié, DNS par nom de service). Après la démo, renvoyez la salle aux questions 8 à 12 de l'étape 0.

## Déroulé minuté

| Min | Étape | Dire | Taper / montrer | Question à poser à la salle |
|---|---|---|---|---|
| 0-4 | 1 | « Sans Compose, il faudrait un réseau, un volume, trois `docker run` avec 10 options. Compose décrit tout ça **dans un fichier versionné**. » | `compose.yaml` commenté | « Quelles options de `docker run` reconnaissez-vous ? » (`-e`, `-p`, `-v`) |
| 4-6 | 2 | « Les valeurs sensibles viennent d'un `.env` à côté du fichier, **jamais commité** ; on commite `.env.example`. » | `cat .env` ; `compose config --services` | « Pourquoi ne pas écrire le mot de passe directement dans `compose.yaml` ? » |
| 6-9 | 3 | « Une commande, toute l'application. `web` attend que `db` soit *healthy*. » | `compose up -d --build`, `compose ps` | « Que se passerait-il sans `condition: service_healthy` ? » (l'API démarre avant que Postgres accepte les connexions → plantage au démarrage) |
| 9-12 | 4 | « `web` joint la base avec l'hôte `db` : le **nom du service** sert de nom DNS sur le réseau de Compose. » | `curl` ×2 (le compteur monte), `getent hosts db` | « Dans TaskFlow, que vaudra le `DATABASE_URL` de l'API ? » (`postgres://taskflow:…@db:5432/taskflow`) |
| 12-14 | 5 | « `logs` regroupe tous les services ; `-f` pour suivre en direct. » | Logs JSON de `web`, logs de Postgres | « Comment ne voir que les 10 dernières minutes ? » (`--since 10m`) |
| 14-17 | 6 | « Pas besoin d'installer Postgres : `exec` lance `psql` **dans** le conteneur. Adminer offre la même chose en web. » | `psql … SELECT count(*)` ; navigateur sur http://localhost:8082 | « Pourquoi le port 5432 n'est-il pas publié ? » (la base n'a pas à être joignable depuis l'extérieur) |
| 17-20 | 7 | « `down` supprime conteneurs et réseau… mais **pas** le volume. » | `volume ls`, nouveau `up -d`, le compteur continue | « Que faut-il sauvegarder sur un serveur : les conteneurs ou le volume ? » |
| 20-23 | 8 | « La base tombe : l'application reste debout et `/health` renvoie **503**. » | `stop db` → 503 ; `start db` → 200 | « Qui pourrait surveiller ce `/health` pour nous prévenir ? » → healthcheck Docker, smoke test du pipeline (Jour 3), Prometheus + blackbox (Jour 4) |
| 23-25 | 9 | « `down -v` efface **aussi** les données. À ne jamais taper en production. » | Le volume a disparu | « Quand utiliser `down -v` ? » (réinitialiser un environnement de dev) |

## Points de code à commenter (si questions)

- `app/src/server.js` : `pool.on('error', …)` évite que Node plante quand la base coupe une connexion. Sans lui, l'étape 8 tue le conteneur `web` (bonne illustration de `restart: unless-stopped`).
- `healthcheck` : `$${POSTGRES_USER}` (double `$`) = variable lue **dans** le conteneur au moment du test, pas par Compose.

## Pièges à anticiper

- **Podman** : `docker compose` délègue parfois à `podman-compose` (message `Executing external compose provider`) ; la sortie de `ps` et `down` est un peu différente mais les commandes sont identiques.
- Port 8082 occupé : `ADMINER_PORT=8092` (8080 = TaskFlow dev, 8081 = staging du Jour 3, 8090 = Jenkins de la démo).
- Un ancien volume `demo-compose_db-data` créé avec un autre mot de passe : Postgres ignore les nouvelles variables `POSTGRES_*` (elles ne servent qu'à l'initialisation) → `docker compose down -v`. C'est un piège classique du fil rouge : le signaler.

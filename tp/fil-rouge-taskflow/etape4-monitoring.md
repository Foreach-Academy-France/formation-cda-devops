# Étape 4 : monitoring et retour d'information

> **Quand** : Jour 4, fin d'après-midi | **Durée** : 2h (A : 30 min, B : 35 min, C : 15 min, D : 40 min)
> **Objectif** : TaskFlow **expose ses métriques**, Prometheus les collecte, Grafana les affiche, une **alerte** vous
> prévient quand l'API tombe ; puis un incident réel est diagnostiqué, corrigé, raconté dans un **post-mortem sans
> blâme** et transformé en **issue** d'amélioration.

---

## Prérequis (état attendu en début d'étape)

- Étapes 2 et 3 terminées : la production tourne (`~/taskflow-prod`, https://taskflow.localhost), son réseau Docker
  s'appelle **`taskflow-prod`** (`docker network ls | grep taskflow-prod`) ; la release passe par staging puis production.
- Bloc 6.1 vu (RED, Prometheus, PromQL, alerting) ; démo `demo-prometheus-grafana` vue.
- Ports libres : **3001** (Grafana), **9090** (Prometheus), **9093** (Alertmanager), **8025** (Mailpit).
- `jq` installé. Variables : `export SOL=$FORMATION/tp/fil-rouge-taskflow/solution`.

## Ce que vous allez construire

```
                    réseau Docker « taskflow-prod »
  proxy ─▶ front ─▶ api:3000 ── /metrics (jamais exposé dehors)
                     ▲   ▲
     scrape 15 s ────┘   └──── blackbox : GET http://front/health (comme un utilisateur)
                     │
              Prometheus :9090 ── règles ──▶ Alertmanager :9093 ──▶ Mailpit :8025 (mail)
                     ▲
              Grafana :3001 (datasource + dashboard RED en code)
```

```
taskflow/
├── api/src/metrics.js              prom-client : RED + métriques métier, route /metrics
├── api/tests/metrics.test.js
├── monitoring/
│   ├── compose.monitoring.yaml     projet taskflow-monitoring, réseau taskflow-prod en external
│   ├── prometheus/prometheus.yml   cibles api:3000 et blackbox
│   ├── prometheus/rules/taskflow.yml   recording rules + TaskFlowApiDown & co
│   ├── prometheus/tests/taskflow_test.yml
│   ├── blackbox/blackbox.yml
│   ├── alertmanager/alertmanager.yml
│   └── grafana/{provisioning,dashboards}/
└── docs/INCIDENTS.md               post-mortem de l'incident de la partie D
```

---

## Partie A. Instrumenter l'API (30 min)

### A.1 La bibliothèque

```bash
cd ~/taskflow && git switch main && git pull && git switch -c feature/metrics
cd api && npm install prom-client
```

### A.2 `src/metrics.js`

Écrivez une fonction `createMetrics({ appVersion, collectDefaults = true })` qui crée **son propre registre**
(`new client.Registry()`, pas le registre global : chaque test crée une application neuve) et renvoie :

| Élément | Contenu |
|---|---|
| `register` | le registre |
| `middleware(req, res, next)` | démarre un chronomètre ; sur `res.on('finish')`, incrémente `http_requests_total` et observe `http_request_duration_seconds` avec les labels `method`, `route`, `status_code` |
| `handler(req, res)` | répond `register.metrics()` avec le `Content-Type` du registre |
| `taskCreated()` | incrémente `taskflow_tasks_created_total` (métrique **métier**) |

Plus une gauge `taskflow_build_info{version="<APP_VERSION>"}` toujours à 1 (elle permet de voir la version en ligne
dans Grafana) et, si `collectDefaults`, `client.collectDefaultMetrics({ register })`.

**La contrainte importante : la cardinalité.** Le label `route` doit être la route **Express** (`/api/tasks/:id/toggle`),
jamais l'URL réelle (`/api/tasks/42/toggle`) : `req.baseUrl + req.route.path`. Une requête qui ne correspond à aucune
route (404) prend le label `unmatched`.

### A.3 Brancher dans `src/app.js`

- `createApp` accepte une option `metrics` (par défaut `createMetrics({ appVersion })`) ;
- `app.get('/metrics', ...)` est déclarée **avant** le logger de requêtes et le middleware de mesure : les collectes de
  Prometheus (toutes les 15 s) ne doivent polluer ni les logs ni les compteurs ;
- la route `POST /api/tasks` appelle `metrics.taskCreated()` après une création réussie.

### A.4 Le test (`tests/metrics.test.js`)

Au minimum : `GET /metrics` répond 200 au format texte ; après un `POST` et un `PATCH /api/tasks/1/toggle`, le texte
contient `route="/api/tasks"` et `route="/api/tasks/:id/toggle"` mais **pas** `/api/tasks/1` ; une URL inconnue est
comptée sous `unmatched` ; une réponse 500 (repository qui rejette) est comptée ; `/metrics` n'appelle pas le logger.

```bash
npm test && npm run lint && npx prettier --check .
```

> **Si ça ne marche pas**
> - `A metric with the provided name has already been registered` : vous utilisez le registre global de prom-client.
>   Créez un `new client.Registry()` par appel et passez `registers: [register]` à chaque métrique.
> - Le label `route` vaut `unmatched` pour toutes les routes : vous lisez `req.route` **avant** que la réponse soit
>   terminée. Calculez les labels dans le callback de `res.on('finish')`.
> - `route="/api/tasks/"` (barre finale) : la route du routeur est `/` ; retirez la barre finale.

### A.5 Livrer

PR → CI verte → revue → merge → `release.yml` déploie staging puis (après approbation) la production. Vérifiez **depuis
le réseau de la prod**, jamais depuis l'extérieur :

```bash
cd ~/taskflow-prod
docker compose -f compose.prod.yaml exec api wget -qO- http://127.0.0.1:3000/metrics | grep -E '^taskflow_|^http_requests_total' | head
curl -sk https://taskflow.localhost/metrics | head -c 80; echo     # la page HTML du front : /metrics n'est pas routé
```

### Questions de réflexion (partie A)

1. Pourquoi ne jamais exposer `/metrics` sur Internet ? Comment le protégeriez-vous s'il devait traverser un réseau
   public ?
2. Pourquoi un **histogramme** pour la durée, plutôt qu'une gauge « durée de la dernière requête » ?
3. Qu'arriverait-il à Prometheus si `route` contenait l'URL réelle et qu'un robot appelait 100 000 URL différentes ?

---

## Partie B. La stack de supervision (35 min)

### B.1 Mettre en place les fichiers

```bash
cd ~/taskflow && mkdir -p monitoring
cp -r $SOL/monitoring/{blackbox,alertmanager,grafana} monitoring/          # fournis : à LIRE, pas à réécrire
mkdir -p monitoring/prometheus/rules monitoring/prometheus/tests
```

Lisez `alertmanager/alertmanager.yml` (routage, regroupement, inhibition) et `blackbox/blackbox.yml` (que doit renvoyer
`/health` pour être considéré comme « ok » ?).

### B.2 À écrire vous-même

1. **`monitoring/compose.monitoring.yaml`**, projet `taskflow-monitoring` : `prometheus` (v3, `--web.enable-lifecycle`),
   `blackbox`, `alertmanager`, `mailpit`, `grafana` (`grafana/provisioning` monté sur `/etc/grafana/provisioning` et
   `grafana/dashboards` sur `/var/lib/grafana/dashboards`, en lecture seule ; `GF_SECURITY_ADMIN_PASSWORD` lu dans
   l'environnement). Contraintes :
   - Prometheus et blackbox rejoignent le réseau **externe** `taskflow-prod` (`networks: taskflow: { name: taskflow-prod, external: true }`) ;
   - ports publiés sur **`127.0.0.1`** seulement : 9090, 9093, 8025, et Grafana sur 3001 ;
   - volumes nommés pour les données de Prometheus, Alertmanager et Grafana.
2. **`monitoring/prometheus/prometheus.yml`** : `scrape_interval: 15s`, `rule_files`, `alerting` vers
   `alertmanager:9093`, et trois jobs : `prometheus`, `taskflow-api` (cible `api:3000`, label `env: prod`),
   `blackbox-health` (module `http_health`, cible `http://front/health`, avec les `relabel_configs` qui transforment la
   cible en paramètre `?target=` et envoient la requête à `blackbox:9115`).
3. **`monitoring/prometheus/rules/taskflow.yml`** : au minimum les recording rules RED et l'alerte
   **`TaskFlowApiDown`** (sonde en échec depuis 1 minute, `severity: critical`, `summary`, `description`, `runbook_url`).
   Comparez ensuite avec `$SOL/monitoring/prometheus/rules/taskflow.yml` et ajoutez ce qui vous manque.
4. **`monitoring/prometheus/tests/taskflow_test.yml`** : un test `promtool` qui prouve que `TaskFlowApiDown` est
   *pending* à 30 s d'échec et *firing* après 1 min 30 (point de départ : `$SOL/monitoring/prometheus/tests/`).

```bash
cd monitoring
docker compose -f compose.monitoring.yaml config -q
docker compose -f compose.monitoring.yaml up -d
docker compose -f compose.monitoring.yaml exec prometheus promtool check rules /etc/prometheus/rules/taskflow.yml
docker compose -f compose.monitoring.yaml exec prometheus promtool test rules /etc/prometheus/tests/taskflow_test.yml
```

### B.3 Vérifier

- http://localhost:9090/targets : **4 cibles `UP`** (`prometheus`, `taskflow-api`, `blackbox-health`, `blackbox`) ;
- *Graph* : `up`, `rate(http_requests_total[5m])`, `histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))` ;
- http://localhost:3001 : le dashboard **TaskFlow : RED et disponibilité** s'ouvre en page d'accueil. Utilisez
  l'application quelques minutes (ou une boucle `curl -sk https://taskflow.localhost/api/tasks`) : les courbes bougent ;
- http://localhost:9093 : l'alerte `Watchdog` est active (et ne doit rien envoyer).

> **Si ça ne marche pas**
> - `network taskflow-prod declared as external, but could not be found` : la prod ne tourne pas, ou son réseau n'est
>   pas nommé (voir `networks: default: name: taskflow-prod` dans `compose.prod.yaml`).
> - Cible `taskflow-api` en `DOWN`, `lookup api ... no such host` : Prometheus n'est pas sur le réseau `taskflow-prod`.
> - `blackbox-health` en `UP` mais `probe_success` = 0 : regardez http://localhost:9090/graph avec
>   `probe_http_status_code` ; un 502 = le front ne joint pas l'API.
> - Grafana : « Datasource not found » dans les panneaux : l'`uid` de la datasource doit être `prometheus` (référencé par
>   le JSON du dashboard).

### B.4 Livrer

Commit (`feat(monitoring): ...`), PR, revue. **Bonus CI** : un job qui lance `promtool test rules` et
`amtool check-config` en conteneur sur les PR qui touchent `monitoring/**`.

### Questions de réflexion (partie B)

1. Pourquoi sonder `/health` **à travers le front** plutôt que directement `api:3000/health` ?
2. Pourquoi `for: 1m` sur `TaskFlowApiDown` ? Que se passe-t-il pendant cette minute ?
3. Le Watchdog est toujours actif. À quoi sert une alerte qui ne s'arrête jamais ?

---

## Partie C. Lire les logs avec `jq` (15 min)

1. **Exercice 4.5** (`exercices/jour4/05-logs-jq.md`), questions 1 à 6 si vous ne l'avez pas fait ce matin.
2. Sur **vos** logs de production :

```bash
cd ~/taskflow-prod
docker compose -f compose.prod.yaml logs --no-log-prefix api > /tmp/api.log
jq -r 'select(.path) | "\(.method) \(.path | sub("/[0-9]+"; "/:id"))"' /tmp/api.log | sort | uniq -c | sort -rn | head
jq -c 'select(.status >= 400)' /tmp/api.log | tail
jq -s '[.[] | select(.ms)] | sort_by(.ms) | reverse | .[0:3]' /tmp/api.log
```

3. Retrouvez dans les logs une requête que vous voyez dans Grafana (même minute, même route). Qu'est-ce que le log
   vous apprend que la métrique ne dit pas ? Et l'inverse ?

---

## Partie D. Incident, post-mortem, amélioration (40 min)

### D.1 Le déclenchement (formateur ou binôme)

Votre binôme (ou le formateur) lance, **sans que vous regardiez** :

```bash
bash $FORMATION/tp/fil-rouge-taskflow/incident/declencher-incident.sh
```

Le script simule un changement de configuration malheureux sur **votre** production. Vous, vous continuez à travailler…
jusqu'à ce que **l'alerte** vous prévienne (Mailpit, http://localhost:8025, ou Alertmanager). Notez l'heure de
réception : c'est le début de votre chronologie.

### D.2 Diagnostiquer avec méthode

Notez chaque commande et ce qu'elle vous apprend (vous en aurez besoin pour le post-mortem) :

1. **Alerte** : laquelle, depuis quand, quelle cible ? (Alertmanager, et Prometheus > *Alerts*)
2. **Tableau de bord** : quand la disponibilité est-elle passée à « EN PANNE » ? La version a-t-elle changé ? Pourquoi
   le panneau « Erreurs 5xx » ne montre-t-il presque rien ?
3. **Symptôme** : `curl -sk https://taskflow.localhost/health` et dans le navigateur.
4. **Conteneurs** : `docker compose -f compose.prod.yaml ps` (dans `~/taskflow-prod`).
5. **Logs** du service suspect, filtrés avec `jq` : `... logs --no-log-prefix --since 15m api | jq -c 'select(.level != "info")'`.
6. **Cause racine** : prouvez-la (ce que reçoit le conteneur, ce que contient la configuration), ne la devinez pas.

### D.3 Corriger et vérifier

Corrigez la cause (pas le symptôme), recréez ce qui doit l'être, puis vérifiez : `ps` (*healthy*), `/health`, une
création de tâche, la sonde à nouveau verte dans Grafana, le mail **`[RESOLVED]`** dans Mailpit. Notez l'heure : c'est
la fin de l'incident.

> **Si ça ne marche pas**
> - Aucune alerte après 3 minutes : la cible `blackbox-health` est-elle `UP` (partie B) ? Alertmanager reçoit-il
>   les alertes de Prometheus (*Status > Runtime* : `Alertmanagers`) ?
> - Vous avez redéployé une **ancienne** version et ça ne change rien : normal, la cause n'est pas dans l'image
>   (question de réflexion 2).

### D.4 Post-mortem sans blâme

Dans `docs/INCIDENTS.md`, copiez le modèle et remplissez-le : résumé avec **impact utilisateur**, **chronologie
horodatée** (premier signal = l'alerte, avec son délai), comment l'alerte et le dashboard ont aidé, **5 pourquoi**,
ce qui a bien / mal fonctionné, **actions** concrètes et vérifiables. Calculez votre **temps de détection** et votre
**temps de rétablissement** (MTTR).

Règle : aucune phrase ne désigne une personne. « Faire plus attention » n'est pas une action.

### D.5 L'issue d'amélioration

Créez **une issue GitHub** pour l'action la plus utile (par exemple : « L'API doit refuser de démarrer en production si
`DATABASE_URL` est absente » ou « `deploy.sh` compare `.env` à `.env.example` ») :

```bash
gh issue create --title "fix(api): refuser de démarrer sans DATABASE_URL en production" \
  --label bug --body "Post-mortem : docs/INCIDENTS.md#... ; Critère d'acceptation : test unitaire dans tests/config.test.js ; ..."
```

Liez l'issue dans le post-mortem (colonne « Statut » du tableau d'actions). **Bonus** : faites la PR qui la ferme
(`Closes #N`), avec le test qui aurait détecté l'incident.

### Questions de réflexion (partie D)

1. Combien de temps entre le début de l'incident et l'alerte ? Comment le réduire, et à quel prix ?
2. Pourquoi un rollback vers la version précédente ne répare-t-il pas cet incident ?
3. Quelle action du post-mortem empêche l'incident de **se reproduire**, et laquelle permet seulement de le **détecter
   plus vite** ? Les deux sont-elles nécessaires ?

---

## Checklist de validation (ce que le formateur vérifie)

- [ ] `api/src/metrics.js` + `tests/metrics.test.js` ; CI verte ; labels `route` normalisés (`:id`, `unmatched`)
- [ ] `/metrics` lisible depuis le réseau Docker, **pas** depuis https://taskflow.localhost
- [ ] `monitoring/compose.monitoring.yaml` : réseau `taskflow-prod` external, ports sur `127.0.0.1`, config en code
- [ ] Prometheus : 4 cibles `UP` ; `promtool test rules` passe
- [ ] Grafana : dashboard provisionné avec du trafic réel
- [ ] Incident : alerte `TaskFlowApiDown` reçue (Mailpit), production réparée, `[RESOLVED]` reçu, `.env.bak` supprimé
- [ ] `docs/INCIDENTS.md` : post-mortem sans blâme avec chronologie, temps de détection, 5 pourquoi, actions
- [ ] Une issue GitHub d'amélioration, liée au post-mortem
- [ ] Je sais expliquer : RED vs USE, boîte noire vs boîte blanche, pull, cardinalité, pourquoi le p95

## Bonus pour les rapides

1. **SLO** : définissez un SLI de disponibilité (part des requêtes `/api/*` sans 5xx) et un SLO de 99,5 % ; écrivez la
   recording rule et un panneau « budget d'erreur restant » sur 30 jours.
2. **Logs dans Grafana** : ajoutez Loki + Promtail (ou Grafana Alloy) et une datasource Loki ; interrogez
   `{container="taskflow-prod-api-1"} | json | status >= 500`.
3. **Notification réelle** : un receiver Discord ou Slack dont le webhook est lu dans un fichier (`webhook_url_file`)
   hors de Git.
4. **Staging aussi** : un deuxième job de scrape pour le staging (`env: staging`) ; quel problème de réseau faut-il
   résoudre ?

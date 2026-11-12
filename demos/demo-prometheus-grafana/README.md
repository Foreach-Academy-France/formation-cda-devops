# Démo — Prometheus, Grafana et une alerte

| | |
|---|---|
| **Jour / bloc** | J4 après-midi — Bloc 6.1 « Surveiller et apprendre » |
| **Durée** | 15 min (+ 3 min de construction des images si elles ne sont pas en cache) |
| **Prérequis** | Docker + Compose v2, `curl`, `jq` ; ports **8092, 3001, 9090, 9093, 8025** libres (variables `FRONT_PORT`, `GRAFANA_PORT`, `PROMETHEUS_PORT`, `ALERTMANAGER_PORT`, `MAILPIT_PORT`) ; la stack de monitoring des apprenants ne doit pas tourner sur le poste formateur |
| **Ce qu'on montre** | `/metrics` (format texte, invisible de l'extérieur), modèle **pull**, cibles `up`, sonde **blackbox**, PromQL (`rate`, `sum by`, `histogram_quantile`), dashboard **provisionné**, alerte *pending* → *firing*, Alertmanager (inhibition), notification par mail, rétablissement |

## Contenu

| Fichier | Rôle |
|---|---|
| `compose.app.yaml` | mini-TaskFlow **construite depuis la solution** (db, api instrumentée, front sur 8092), réseau nommé `taskflow-demo` |
| `demo.sh` | lance l'appli, puis **la stack de monitoring de la solution** (`tp/fil-rouge-taskflow/solution/monitoring/compose.monitoring.yaml`) avec `TASKFLOW_NETWORK=taskflow-demo` ; trafic, PromQL, panne, alerte, rétablissement ; nettoyage des conteneurs et volumes (images `localhost/demo-taskflow-*` gardées en cache) |

La démo n'a **aucune configuration propre** : ce que vous montrez est exactement ce que les apprenants construisent à
l'étape 4 (mêmes règles, même dashboard, même routage d'alertes).

## Lancer

```bash
bash demos/demo-prometheus-grafana/demo.sh          # avec pauses : montrer les interfaces dans le navigateur
KEEP=1 bash demos/demo-prometheus-grafana/demo.sh   # garder les stacks après la démo
DEMO_AUTO=1 bash demos/demo-prometheus-grafana/demo.sh   # test complet sans pause (~4 min)
```

## Déroulé minuté

| Min | Étape | Montrer | Question à poser à la salle |
|---|---|---|---|
| 0-3 | 1. Mini-TaskFlow | `/metrics` lu **depuis le réseau Docker** ; `/metrics` via le front = la page HTML (non routé) | « Pourquoi ne pas exposer `/metrics` publiquement ? » |
| 3-5 | 2. Stack de monitoring | Prometheus > *Status > Targets* : 4 cibles `UP`, dont la sonde blackbox | « Qui appelle qui ? » (pull) |
| 5-9 | 3. Trafic + PromQL | *Graph* : `rate(http_requests_total[1m])`, `sum by (route)`, p95 ; Grafana : dashboard *TaskFlow : RED et disponibilité* | « Pourquoi le p95 plutôt que la moyenne ? » |
| 9-13 | 4. Panne | *Alerts* : `pending` puis `firing` ; Alertmanager : `TaskFlowMetricsDown` **inhibée** ; Mailpit : le mail | « Pourquoi le panneau Erreurs 5xx reste à 0 % ? » (l'API morte ne compte plus rien : boîte noire indispensable) |
| 13-15 | 5. Rétablissement | Le panneau Disponibilité repasse au vert ; mail `[RESOLVED]` (~2 min) | « Qu'écrit-on maintenant ? » (→ post-mortem) |

## Points de vigilance

- Construction des images au premier lancement (`npm ci` dans les Dockerfile) : lancer `DEMO_AUTO=1` une fois avant le
  cours pour remplir le cache.
- Grafana : `admin` / `admin` (variable `GRAFANA_ADMIN_PASSWORD`). Tous les ports sont publiés sur `127.0.0.1` seulement.
- L'arrêt de l'API par `docker compose stop` est plus lisible en démo que l'incident du TP (redémarrage en boucle) ;
  l'effet sur les sondes et les alertes est le même.

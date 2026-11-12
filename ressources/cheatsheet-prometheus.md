# Cheatsheet Prometheus, PromQL, Alertmanager, Grafana et `jq`

> **Logs** : que s'est-il passé ? **Métriques** : est-ce que ça va, depuis quand ? **Traces** : où est passé le temps ?
> On **alerte** sur des métriques, on **diagnostique** avec les logs.

## Types de métriques (prom-client)

| Type | Comportement | Exemple TaskFlow | On l'affiche avec |
|---|---|---|---|
| Counter | ne fait que monter (0 au redémarrage) | `http_requests_total`, `taskflow_tasks_created_total` | `rate()`, `increase()` |
| Gauge | monte et descend | `process_resident_memory_bytes`, `taskflow_build_info` | valeur brute, `avg_over_time()` |
| Histogram | compte par tranches (`_bucket{le=...}`, `_sum`, `_count`) | `http_request_duration_seconds` | `histogram_quantile()` |

Nommage : `_total` pour un compteur, unité de base dans le nom (`_seconds`, `_bytes`). Labels à **faible cardinalité**
(`route="/api/tasks/:id/toggle"`, jamais l'id).

## PromQL

| Requête | Sens |
|---|---|
| `up` | 1 si la cible est collectée, 0 sinon |
| `http_requests_total{route="/api/tasks", status_code=~"5.."}` | sélection par labels (`=`, `!=`, `=~` regex, `!~`) |
| `rate(http_requests_total[5m])` | débit par seconde sur 5 min (compteurs uniquement) |
| `increase(taskflow_tasks_created_total[1h])` | augmentation sur 1 h |
| `sum by (route) (rate(http_requests_total[5m]))` | agréger en gardant un label (`without (...)` : l'inverse) |
| `sum(rate(http_requests_total{status_code=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))` | taux d'erreur (0..1) |
| `histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))` | latence p95 |
| `probe_success{job="blackbox-health"}` | sonde boîte noire (1/0) ; `probe_http_status_code`, `probe_duration_seconds` |
| `max by (version) (last_over_time(taskflow_build_info[1h]))` | dernière version vue |
| `absent(up{job="taskflow-api"})` | 1 si la série n'existe plus du tout |
| `predict_linear(node_filesystem_avail_bytes[1h], 4*3600) < 0` | disque plein dans 4 h (USE) |

## Méthodes

| | Pour | Signaux |
|---|---|---|
| **RED** | un service | **R**ate (req/s), **E**rrors (part de 5xx), **D**uration (p50/p95/p99) |
| **USE** | une ressource | **U**tilisation, **S**aturation (file d'attente, lag), **E**rrors |
| 4 signaux dorés (SRE) | les deux | latence, trafic, erreurs, saturation |

## Règles (`prometheus/rules/*.yml`)

```yaml
groups:
  - name: taskflow.alerts
    rules:
      - record: taskflow:http_errors:ratio5m          # recording rule : pré-calcul réutilisable
        expr: sum(rate(http_requests_total{status_code=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))
      - alert: TaskFlowApiDown
        expr: probe_success{job="blackbox-health"} == 0
        for: 1m                                      # inactive -> pending -> firing
        labels: { severity: critical }
        annotations:
          summary: "TaskFlow {{ $labels.env }} : /health ne répond plus"
          runbook_url: "docs/INCIDENTS.md#méthode-de-diagnostic"
```

## Commandes

| Commande | Effet |
|---|---|
| `promtool check config prometheus.yml` | Valider la configuration |
| `promtool check rules rules/taskflow.yml` | Valider les règles |
| `promtool test rules tests/taskflow_test.yml` | Tests unitaires des alertes (séries simulées : `'1 1 0 0'`, `'0+60x40'`, `'1x10'`) |
| `curl -X POST localhost:9090/-/reload` | Recharger sans redémarrer (`--web.enable-lifecycle`) |
| `curl -s localhost:9090/api/v1/query --data-urlencode 'query=up' \| jq` | PromQL en ligne de commande |
| `curl -s localhost:9090/api/v1/alerts \| jq '.data.alerts'` | Alertes actives |
| `amtool check-config alertmanager.yml` | Valider Alertmanager |
| `curl -s localhost:9093/api/v2/alerts \| jq` | Alertes vues par Alertmanager (`active`, `suppressed`) |

Dans le TP : `docker compose -f compose.monitoring.yaml exec prometheus promtool ...`.

## Alertmanager

| Clé | Rôle |
|---|---|
| `route.group_by`, `group_wait`, `group_interval`, `repeat_interval` | regrouper, attendre avant d'envoyer, renvoyer |
| `routes[].matchers` + `receiver` | router selon les labels (sévérité, équipe...) |
| `receivers[].email_configs` / `slack_configs` / `discord_configs` / `webhook_configs` | où notifier ; `send_resolved: true` |
| `inhibit_rules` | une critical masque les warnings du même `env` |
| Silence (interface :9093) | couper une alerte connue pendant une intervention |

## Grafana « as code »

`provisioning/datasources/*.yml` (datasource, `uid` fixe) et `provisioning/dashboards/*.yml` (dossier de JSON) montés
en lecture seule. Modifier un dashboard : *Export > Export as JSON*, remplacer le fichier, PR.

## Lire des logs JSON avec `jq`

| Commande | Effet |
|---|---|
| `jq . api.log` | Joli affichage |
| `jq -c 'select(.status >= 500)' api.log` | Filtrer (une ligne par résultat) |
| `jq -r '.path' api.log \| sort \| uniq -c \| sort -rn` | Compter les valeurs |
| `jq -r '.path \| sub("/[0-9]+"; "/:id")' api.log` | Normaliser les identifiants |
| `jq -r 'select(.level=="error") \| "\(.time) \(.message)"' api.log` | Format personnalisé |
| `jq -s 'map(select(.ms)) \| sort_by(.ms) \| reverse \| .[0:5]' api.log` | Les 5 plus lentes (`-s` : tout le fichier en tableau) |
| `jq -s '[.[] \| .ms // empty] \| sort \| .[length*0.95\|floor]' api.log` | p95 approximatif |
| `jq -r '.time[11:16]' api.log \| uniq -c` | Par minute (`hh:mm`) |
| `docker compose logs --no-log-prefix api \| jq -c 'select(.level != "info")'` | Directement depuis Docker |

## SLI / SLO / SLA

SLI = mesure (part des requêtes sans 5xx en moins de 300 ms) ; SLO = objectif interne (99,5 % sur 30 jours) ; SLA =
engagement contractuel (99 %) ; budget d'erreur = 100 % − SLO (0,5 % de 30 jours ≈ 3 h 36 min).

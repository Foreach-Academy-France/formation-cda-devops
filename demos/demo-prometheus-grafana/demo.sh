#!/usr/bin/env bash
# =============================================================================
# Démo J4 — Bloc 6.1 : Prometheus, Grafana, alerte
#   Usage   : bash demo.sh              (pauses : on montre Prometheus et Grafana dans le navigateur)
#             DEMO_AUTO=1 bash demo.sh  (sans pause : vérifie toute la chaîne, y compris l'alerte)
#             KEEP=1 bash demo.sh       (laisser tourner après la démo)
#   Ports   : FRONT_PORT (8092), GRAFANA_PORT (3001), PROMETHEUS_PORT (9090),
#             ALERTMANAGER_PORT (9093), MAILPIT_PORT (8025)
#   Effet   : construit une mini-TaskFlow depuis la solution, lance la stack de
#             monitoring DE LA SOLUTION (solution/monitoring/compose.monitoring.yaml),
#             génère du trafic, arrête l'API (alerte TaskFlowApiDown + mail), la relance,
#             puis supprime conteneurs et volumes. Les images construites (localhost/demo-taskflow-*)
#             restent en cache pour la prochaine fois : docker rmi localhost/demo-taskflow-api:demo localhost/demo-taskflow-front:demo
# =============================================================================
set -euo pipefail

DEMO_AUTO="${DEMO_AUTO:-0}"
KEEP="${KEEP:-0}"
DOCKER="${DOCKER:-docker}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITORING="$HERE/../../tp/fil-rouge-taskflow/solution/monitoring/compose.monitoring.yaml"
export FRONT_PORT="${FRONT_PORT:-8092}" GRAFANA_PORT="${GRAFANA_PORT:-3001}" \
  PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}" ALERTMANAGER_PORT="${ALERTMANAGER_PORT:-9093}" \
  MAILPIT_PORT="${MAILPIT_PORT:-8025}" TASKFLOW_NETWORK=taskflow-demo
PROM="http://localhost:$PROMETHEUS_PORT"

app() { "$DOCKER" compose -f "$HERE/compose.app.yaml" "$@"; }
mon() { "$DOCKER" compose -p demo-taskflow-monitoring -f "$MONITORING" "$@"; }

cleanup() {
  if [[ "$KEEP" == "1" ]]; then
    echo -e "\nStacks conservées. Arrêt : KEEP=0 bash $0 (ou docker compose ... down -v)"
    return
  fi
  mon down -v --remove-orphans >/dev/null 2>&1 || true
  app down -v --remove-orphans >/dev/null 2>&1 || true
  echo -e "\nNettoyage : stacks demo-taskflow-* arrêtées, volumes supprimés (images gardées en cache)"
}
trap cleanup EXIT

etape() { echo -e "\n\033[1;34m=== $* ===\033[0m"; }
pause() {
  if [[ "$DEMO_AUTO" == "1" ]]; then return 0; fi
  read -r -p $'\n▶ Entrée pour continuer… ' _
}
run() { echo -e "\033[1;32m\$ $*\033[0m"; eval "$*"; }
promql() {   # promql 'requête' : résultat instantané, une ligne par série
  curl -s "$PROM/api/v1/query" --data-urlencode "query=$1" \
    | jq -r '.data.result[] | "\(.metric | del(.__name__) | tostring)  →  \(.value[1])"'
}
attendre() {   # attendre "description" commande... (180 s max)
  local quoi="$1"; shift
  for _ in $(seq 1 90); do "$@" >/dev/null 2>&1 && return 0; sleep 2; done
  echo "⚠ délai dépassé : $quoi" >&2; return 1
}
alerte_active() {
  curl -s "$PROM/api/v1/alerts" | jq -e --arg s "$1" \
    '[.data.alerts[] | select(.labels.alertname == "TaskFlowApiDown" and .state == $s)] | length > 0'
}

etape "1. Une mini-TaskFlow (construite depuis la solution)"
run "app up -d --build --wait"
run "curl -s http://localhost:$FRONT_PORT/health; echo"
echo "→ L'API ne publie AUCUN port. Pour lire /metrics, il faut être sur son réseau :"
run "\"$DOCKER\" run --rm --network taskflow-demo docker.io/curlimages/curl:8.11.1 -s http://api:3000/metrics | grep -E '^(# TYPE|http_requests_total|taskflow_)' | head -n 12"
run "curl -s -o /dev/null -w '/metrics via le front : HTTP %{http_code} (index.html : non routé vers l API)\n' http://localhost:$FRONT_PORT/metrics"
pause

etape "2. La stack de monitoring de la solution, raccordée au réseau taskflow-demo"
run "mon up -d"
attendre "Prometheus prêt" curl -sf "$PROM/-/ready"
attendre "cibles UP" bash -c "curl -s $PROM/api/v1/targets | jq -e '[.data.activeTargets[] | select(.health==\"up\")] | length >= 4'"
run "curl -s $PROM/api/v1/targets | jq -r '.data.activeTargets[] | \"\(.labels.job)  \(.scrapeUrl)  \(.health)\"'"
echo "→ Navigateur : $PROM/targets, puis Grafana http://localhost:$GRAFANA_PORT (admin / admin)"
pause

etape "3. Du trafic, puis PromQL"
for i in $(seq 1 40); do
  curl -s "http://localhost:$FRONT_PORT/api/tasks" >/dev/null
  curl -s -X POST -H 'Content-Type: application/json' -d "{\"title\":\"démo $i\"}" "http://localhost:$FRONT_PORT/api/tasks" >/dev/null
  curl -s -X PATCH "http://localhost:$FRONT_PORT/api/tasks/abc/toggle" >/dev/null
done
echo "(120 requêtes envoyées ; on attend la prochaine collecte)"
sleep 20
run "promql 'up'"
run "promql 'sum by (route, status_code) (http_requests_total)'"
run "promql 'sum by (route) (rate(http_requests_total[5m]))'"
run "promql 'histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))'"
run "promql 'taskflow_tasks_created_total'"
echo "→ Grafana : dashboard « TaskFlow : RED et disponibilité » (dossier TaskFlow), provisionné depuis des fichiers."
pause

etape "4. Panne : l'API s'arrête"
run "app stop api"
run "curl -s -o /dev/null -w '/health via le front : HTTP %{http_code}\n' http://localhost:$FRONT_PORT/health"
echo "→ Prometheus > Alerts : TaskFlowApiDown passe « pending », puis « firing » après 1 min (for: 1m)."
echo "→ Question : pourquoi le panneau « Erreurs 5xx » de Grafana reste-t-il à 0 % ?"
attendre "alerte pending" alerte_active pending || true
attendre "alerte firing" alerte_active firing
run "curl -s http://localhost:$ALERTMANAGER_PORT/api/v2/alerts | jq -r '.[] | \"\(.labels.alertname)  \(.status.state)\"'"
attendre "mail reçu" bash -c "curl -s http://localhost:$MAILPIT_PORT/api/v1/messages | jq -e '.messages | length > 0'"
run "curl -s http://localhost:$MAILPIT_PORT/api/v1/messages | jq -r '.messages[].Subject'"
echo "→ Mailpit : http://localhost:$MAILPIT_PORT. TaskFlowMetricsDown (warning) est INHIBÉE par l'alerte critique."
pause

etape "5. Rétablissement"
run "app start api"
attendre "API de nouveau UP" bash -c "curl -s '$PROM/api/v1/query?query=up%7Bjob%3D%22taskflow-api%22%7D' | jq -e '.data.result[0].value[1] == \"1\"'"
run "promql 'probe_success'"
echo "→ L'alerte se résout ; Alertmanager envoie un mail [RESOLVED] (send_resolved: true)."

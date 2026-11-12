#!/usr/bin/env bash
# =============================================================================
# Démo J5 — Bloc 7.4 : OWASP ZAP baseline sur Juice Shop
#   Usage   : bash demo.sh              (pauses pour commenter)
#             DEMO_AUTO=1 bash demo.sh  (sans pause : démarre, scanne, nettoie)
#             KEEP=1 bash demo.sh       (laisse Juice Shop tourner après la démo)
#   Ports   : JUICE_PORT (3002 ; 3000 = API TaskFlow, 3001 = Grafana)
#   Effet   : démarre Juice Shop, lance un ZAP baseline, ouvre le rapport, puis
#             arrête le conteneur et supprime le dossier temporaire (sauf KEEP=1).
#
#   Cadre légal : cible d'entraînement OWASP, sur CE poste uniquement. Un scan
#   contre un système tiers sans autorisation écrite = délit (art. 323-1 CP).
# =============================================================================
set -euo pipefail

DEMO_AUTO="${DEMO_AUTO:-0}"
KEEP="${KEEP:-0}"
DOCKER="${DOCKER:-docker}"
JUICE_PORT="${JUICE_PORT:-3002}"
JUICE_IMAGE="docker.io/bkimminich/juice-shop"
ZAP_IMAGE="ghcr.io/zaproxy/zaproxy:2.17.0"
JUICE_NAME="demo-juice-shop"
WORKDIR="$(mktemp -d -t demo-zap-XXXXXX)"

cleanup() {
  "$DOCKER" rm -f "$JUICE_NAME" >/dev/null 2>&1 || true
  if [[ "$KEEP" == "1" ]]; then
    echo -e "\n📁 Rapport conservé dans $WORKDIR (Juice Shop a été arrêté)."
    return
  fi
  rm -rf "$WORKDIR"
  echo -e "\n🧹 Démo nettoyée (conteneur supprimé, dossier temporaire effacé)"
}
trap cleanup EXIT

etape() { echo -e "\n\033[1;34m=== $* ===\033[0m"; }
pause()  { [[ "$DEMO_AUTO" == "1" ]] && return 0; read -r -p $'\n▶ Entrée pour continuer… ' _; }
run()    { echo -e "\033[1;32m\$ $*\033[0m"; eval "$*"; }
attendre_http() {
  for _ in $(seq 1 "${2:-120}"); do curl -sS -o /dev/null "$1" 2>/dev/null && return 0; sleep 1; done
  echo "⚠ $1 ne répond pas" >&2; return 1
}

etape "0. Rappel du cadre légal"
cat <<TXT
  Cible : OWASP Juice Shop, application volontairement vulnérable, sur CE poste.
  Autorisé car c'est notre machine et une cible d'entraînement publiée pour ça.
  Hors de ce cadre, un scan sans autorisation écrite est un délit (art. 323-1 CP).
TXT
pause

etape "1. Démarrer la cible (Juice Shop sur http://localhost:$JUICE_PORT)"
run "$DOCKER rm -f $JUICE_NAME >/dev/null 2>&1 || true"
run "$DOCKER run -d --rm --name $JUICE_NAME -p 127.0.0.1:$JUICE_PORT:3000 $JUICE_IMAGE"
echo "(Juice Shop met 10 à 30 s à démarrer…)"
attendre_http "http://localhost:$JUICE_PORT" 120
run "curl -s -o /dev/null -w 'Juice Shop → HTTP %{http_code}\n' http://localhost:$JUICE_PORT"
pause

etape "2. Lancer le ZAP baseline (scan PASSIF : spider + analyse, aucune attaque)"
chmod -R a+rwx "$WORKDIR"
# -I : les WARN ne font pas échouer (code de sortie 0) ; -r : rapport HTML ; -J : JSON.
# --network host : le conteneur ZAP joint localhost:$JUICE_PORT de la machine.
set +e
"$DOCKER" run --rm --network host -v "$WORKDIR:/zap/wrk:rw" "$ZAP_IMAGE" \
  zap-baseline.py -t "http://localhost:$JUICE_PORT" -I -r rapport.html -J rapport.json
zap_code=$?
set -e
echo "ZAP a terminé (code $zap_code : 0 = aucune règle FAIL avec -I)."
pause

etape "3. Lire le rapport"
echo "Rapport HTML : $WORKDIR/rapport.html"
if command -v xdg-open >/dev/null 2>&1 && [[ "$DEMO_AUTO" != "1" ]]; then
  xdg-open "$WORKDIR/rapport.html" >/dev/null 2>&1 || true
fi
echo "Alertes typiques (mauvaise configuration, A05) à commenter :"
echo "  • Content Security Policy (CSP) Header Not Set"
echo "  • Cross-Domain Misconfiguration (CORS *)"
echo "  • en-têtes d'isolation d'origine manquants"
echo "  → ce sont exactement les en-têtes ajoutés à TaskFlow dans l'étape 5."
pause

etape "4. Le point clé : ce que la baseline NE voit PAS"
cat <<TXT
  La baseline est PASSIVE. Elle n'a pas trouvé :
    • l'injection SQL du login (' OR 1=1--)  → il faut un scan ACTIF ou un SAST
    • l'accès au panier d'un autre (IDOR)     → il faut des tests d'autorisation + revue
  Conclusion : défense en profondeur. La baseline a sa place dans le CI (job 'dast'
  de security.yml), mais elle ne remplace ni le scan actif, ni Semgrep, ni la revue.
TXT
pause
echo -e "\nFin de la démo."

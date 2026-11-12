#!/usr/bin/env bash
# =============================================================================
# Lance OWASP Juice Shop en local pour l'exercice du Jour 5.
#   Usage : bash lancer-juice-shop.sh          (Ctrl+C pour arrêter ; --rm supprime le conteneur)
#           JUICE_PORT=3003 bash lancer-juice-shop.sh
# Port par défaut 3002 : 3000 = API TaskFlow (dev), 3001 = Grafana (Jour 4).
# Redémarrer le conteneur remet TOUS les défis à zéro (la progression est en mémoire).
# =============================================================================
set -euo pipefail

DOCKER="${DOCKER:-docker}"
PORT="${JUICE_PORT:-3002}"
IMAGE="docker.io/bkimminich/juice-shop"

if curl -s -o /dev/null "http://localhost:$PORT" 2>/dev/null; then
  echo "Le port $PORT répond déjà : Juice Shop tourne peut-être (docker ps), ou choisissez JUICE_PORT=3003." >&2
  exit 1
fi

echo "Juice Shop sur http://localhost:$PORT (démarrage en 10 à 30 s ; Ctrl+C pour arrêter)"
exec "$DOCKER" run --rm --name juice-shop -p "127.0.0.1:$PORT:3000" "$IMAGE"

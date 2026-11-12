#!/usr/bin/env bash
# =============================================================================
# Démo J4 — Bloc 5.3 : Ansible en local (connection: local)
#   Usage   : bash demo.sh              (pauses entre les étapes)
#             DEMO_AUTO=1 bash demo.sh  (sans pause : test avant le cours)
#   Effet   : prépare un dossier de déploiement dans un dossier temporaire,
#             montre changed / ok, l'idempotence, --check --diff, la correction
#             d'une dérive, puis supprime tout.
# =============================================================================
set -euo pipefail

DEMO_AUTO="${DEMO_AUTO:-0}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(mktemp -d -t demo-ansible-XXXXXX)"
export ANSIBLE_NOCOLOR=1   # sorties filtrées par grep : pas de codes couleur
cd "$HERE"

cleanup() { rm -rf "$DEMO_DIR"; echo -e "\nNettoyage : $DEMO_DIR supprimé"; }
trap cleanup EXIT

etape() { echo -e "\n\033[1;34m=== $* ===\033[0m"; }
pause() {
  if [[ "$DEMO_AUTO" == "1" ]]; then return 0; fi
  read -r -p $'\n▶ Entrée pour continuer… ' _
}
run() { echo -e "\033[1;32m\$ $*\033[0m"; eval "$*"; }
play() { ansible-playbook -i inventory.ini playbook.yml -e "demo_dir=$DEMO_DIR" "$@"; }

command -v ansible-playbook >/dev/null || { echo "ansible-playbook introuvable" >&2; exit 1; }

etape "1. Inventaire et playbook"
run "cat inventory.ini"
run "cat playbook.yml"
run "cat templates/env.j2"
pause

etape "2. Premier passage : tout est « changed »"
run "play"
run "ls -la $DEMO_DIR $DEMO_DIR/certs"
echo "→ .env en 0600, certs/ en 0700 : les droits font partie de l'état voulu."
pause

etape "3. Deuxième passage : changed=0 (idempotence), pas de handler"
run "play | tail -n 3"
echo "→ Question : pourquoi le certificat n'est-il pas régénéré ? (regardez « creates: »)"
pause

etape "4. Simulation : --check --diff (l'équivalent d'un plan)"
run "play -e app_version=1.1.0 --check --diff | grep -E '^[-+][A-Z]|changed=' "
run "grep APP_VERSION $DEMO_DIR/.env"
echo "→ Rien n'a été écrit : c'était une simulation."
pause

etape "5. Dérive : quelqu'un fait chmod 644 sur le .env"
run "chmod 644 $DEMO_DIR/.env && ls -l $DEMO_DIR/.env"
run "play | grep -E 'changed:|RUNNING HANDLER|changed='"
run "ls -l $DEMO_DIR/.env"
echo "→ Ansible remet en conformité ce qu'il décrit. Question : et un fichier ajouté à la main à côté ?"

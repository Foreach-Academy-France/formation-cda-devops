#!/usr/bin/env bash
# =============================================================================
# Démo J4 — Bloc 5.2 : OpenTofu et le provider Docker
#   Usage   : bash demo.sh              (pauses entre les étapes)
#             DEMO_AUTO=1 bash demo.sh  (sans pause : test avant le cours)
#   Port    : TF_VAR_port (8091 par défaut)
#   Podman  : export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock
#   Effet   : copie main.tf dans un dossier temporaire, init / plan / apply,
#             dérive provoquée et corrigée, remplacement, puis destroy (même après Ctrl+C).
# =============================================================================
set -euo pipefail

DEMO_AUTO="${DEMO_AUTO:-0}"
DOCKER="${DOCKER:-docker}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="$(mktemp -d -t demo-tofu-XXXXXX)"
export TF_VAR_port="${TF_VAR_port:-8091}" TF_IN_AUTOMATION=1

cp "$HERE/main.tf" "$WORKDIR/"
cd "$WORKDIR"

cleanup() {
  cd "$WORKDIR" && tofu destroy -auto-approve -no-color >/dev/null 2>&1 || true
  "$DOCKER" rm -f demo-tofu-web >/dev/null 2>&1 || true
  rm -rf "$WORKDIR"
  echo -e "\nNettoyage : conteneur détruit, dossier temporaire supprimé"
}
trap cleanup EXIT

etape() { echo -e "\n\033[1;34m=== $* ===\033[0m"; }
pause() {
  if [[ "$DEMO_AUTO" == "1" ]]; then return 0; fi
  read -r -p $'\n▶ Entrée pour continuer… ' _
}
run() { echo -e "\033[1;32m\$ $*\033[0m"; eval "$*"; }
attendre_http() {
  for _ in $(seq 1 30); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 1; done
  echo "⚠ $1 ne répond pas" >&2; return 1
}

command -v tofu >/dev/null || { echo "tofu introuvable : voir ressources/setup-poste.md" >&2; exit 1; }

etape "1. Le code"
run "cat main.tf"
pause

etape "2. init : télécharger le provider"
run "tofu init -no-color | tail -n 3"
run "ls -a"
run "head -n 8 .terraform.lock.hcl"
echo "→ .terraform/ : jamais dans Git. .terraform.lock.hcl : dans Git (comme package-lock.json)."
pause

etape "3. fmt, validate, plan"
run "tofu fmt -check && tofu validate -no-color"
run "tofu plan -no-color | grep -E '^  # |^Plan|url'"
echo "→ Question : si je lance apply deux fois, que se passe-t-il la deuxième fois ?"
pause

etape "4. apply"
run "tofu apply -auto-approve -no-color | tail -n 4"
attendre_http "http://localhost:$TF_VAR_port"
run "curl -s \"\$(tofu output -raw url)\""
run "tofu apply -auto-approve -no-color | grep -E 'No changes|Apply complete'"
pause

etape "5. Le state : la mémoire de l'outil"
run "tofu state list"
run "tofu state show docker_container.web | grep -E '^ *(id|name|image) '"
run "\"$DOCKER\" ps --filter name=demo-tofu-web --format '{{.ID}}  {{.Names}}  {{.Ports}}'"
echo "→ Même identifiant : le state relie le code à l'objet réel. Il contient aussi les secrets : jamais dans Git."
pause

etape "6. Dérive : quelqu'un supprime le conteneur à la main"
run "\"$DOCKER\" rm -f demo-tofu-web"
run "tofu plan -no-color | grep -E 'Refreshing|will be created|^Plan'"
run "tofu apply -auto-approve -no-color | grep 'Apply complete'"
attendre_http "http://localhost:$TF_VAR_port"
run "curl -s http://localhost:$TF_VAR_port"
pause

etape "7. Modifier ou remplacer ?"
run "tofu plan -no-color -var 'message=Version 2' | grep -E 'must be replaced|forces replacement|^Plan' | sort -u"
echo "→ Question : pourquoi un remplacement (-/+) et pas une modification (~) ? Quel impact sur un vrai service ?"
run "tofu apply -auto-approve -no-color -var 'message=Version 2' | grep 'Apply complete'"
attendre_http "http://localhost:$TF_VAR_port"
run "curl -s http://localhost:$TF_VAR_port"
pause

etape "8. destroy"
run "tofu destroy -auto-approve -no-color -var 'message=Version 2' | tail -n 1"
run "tofu state list | wc -l"

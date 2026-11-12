#!/usr/bin/env bash
# =============================================================================
# Démo J3 — Bloc 7.1 : gitleaks (secrets) et Trivy (vulnérabilités des images)
#   Usage   : bash demo.sh                (pauses entre les étapes)
#             DEMO_AUTO=1 bash demo.sh    (sans pause, pour tester avant le cours)
#             DOCKER=podman bash demo.sh
#   Effet   : crée un dépôt jetable dans un dossier temporaire (supprimé à la fin),
#             lance gitleaks puis Trivy en conteneurs. La base de vulnérabilités de
#             Trivy est gardée dans le volume « demo-trivy-cache » (réutilisé d'une
#             fois sur l'autre ; KEEP_CACHE=0 pour le supprimer à la fin).
# =============================================================================
set -euo pipefail

DEMO_AUTO="${DEMO_AUTO:-0}"
DOCKER="${DOCKER:-docker}"
KEEP_CACHE="${KEEP_CACHE:-1}"
GITLEAKS="docker.io/zricethezav/gitleaks:v8.30.1"
TRIVY="docker.io/aquasec/trivy:0.76.2"
OLD_IMAGE="docker.io/library/nginx:1.27-alpine"
NEW_IMAGE="docker.io/library/nginx:1.29-alpine"
COURSE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WORKDIR="$(mktemp -d -t demo-secrets-XXXXXX)"

cleanup() {
  rm -rf "$WORKDIR"
  if [[ "$KEEP_CACHE" != "1" ]]; then "$DOCKER" volume rm -f demo-trivy-cache >/dev/null 2>&1 || true; fi
  echo -e "\n🧹 Dépôt jetable supprimé"
}
trap cleanup EXIT

etape() { echo -e "\n\033[1;34m=== $* ===\033[0m"; }
pause() { [[ "$DEMO_AUTO" == "1" ]] || read -r -p $'\n▶ Entrée pour continuer… ' _; }
run() { echo -e "\033[1;32m\$ $*\033[0m"; eval "$*" || echo -e "\033[1;33m(code de sortie : $?)\033[0m"; }
rand() { (set +o pipefail; LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$1"); }

gitleaks() { "$DOCKER" run --rm -v "$WORKDIR/repo":/repo "$GITLEAKS" "$@"; }
trivy() { "$DOCKER" run --rm -v demo-trivy-cache:/root/.cache -v "$COURSE_DIR":/cours:ro "$TRIVY" "$@"; }

# --------------------------------------------------------------------------
etape "1. Un développeur s'apprête à commiter un jeton (factice, généré à l'instant)"
mkdir -p "$WORKDIR/repo" && cd "$WORKDIR/repo"
git init -q -b main && git config user.name demo && git config user.email demo@example.com
echo "# app" > README.md && git add . && git commit -q -m "chore: init"
printf 'PORT=3000\nGITHUB_TOKEN=ghp_%s\n' "$(rand 36)" > config.env
run "cat config.env | sed 's/\\(ghp_.\\{6\\}\\).*/\\1…/'"
run "git add config.env"
pause

etape "2. Le hook pre-commit (gitleaks sur l'index) refuse le commit"
run "gitleaks git /repo --pre-commit --staged --redact --no-banner -v"
echo "→ Code de sortie 1 : le hook bloque. C'est ce que fait .pre-commit-config.yaml dans TaskFlow."
pause

etape "3. … mais un hook se contourne : git commit --no-verify"
run "git commit -q --no-verify -m 'feat: config' && git rm -q --cached config.env && rm config.env && git commit -q -m 'chore: retire config.env'"
run "git log --oneline"
run "ls"
echo "→ Le fichier a disparu… de l'arbre courant seulement."
pause

etape "4. Le scan de TOUT l'historique (ce que fera le CI) le retrouve"
run "gitleaks git /repo --redact --no-banner -v"
echo "→ Lisez « N commits scanned » : sur un historique, 0 commit = l'outil n'a rien lu (normal seulement en mode --staged)."
echo "→ Remède : RÉVOQUER le jeton d'abord, purger ensuite (exercice 3.3)."
pause

# --------------------------------------------------------------------------
etape "5. Trivy : une image de base vieille de quelques mois"
run "trivy image --quiet --severity CRITICAL --ignore-unfixed $OLD_IMAGE"
pause

etape "6. Le même scan, bloquant, comme dans release.yml"
run "trivy image --quiet --severity CRITICAL --ignore-unfixed --exit-code 1 $OLD_IMAGE >/dev/null; echo \"exit=\$?\""
run "trivy image --quiet --severity CRITICAL --ignore-unfixed --exit-code 1 $NEW_IMAGE; echo \"exit=\$?\""
echo "→ Correctif 1 : monter l'image de base (FROM) ; Dependabot (docker) propose ces PR."
echo "→ Si la dernière image officielle a encore un CRITICAL « fixed » (correctif publié par Alpine, image"
echo "  pas encore reconstruite) : RUN apk upgrade --no-cache dans le Dockerfile, puis rescanner."
pause

etape "7. SCA sur les dépendances npm (lockfile du starter TaskFlow)"
run "trivy fs --quiet --scanners vuln --severity HIGH,CRITICAL /cours/tp/fil-rouge-taskflow/starter/api"
echo "→ Même famille que npm audit. HIGH sans correctif ? On trie, on documente (docs/SECURITE.md, Jour 5)."
pause

# --------------------------------------------------------------------------
etape "8. Supply chain : un tag d'action est mutable, un SHA ne l'est pas"
run "git ls-remote https://github.com/aquasecurity/trivy-action 'refs/tags/v0.36.0' 'refs/tags/v0.36.0^{}'"
echo "→ Mars 2026 : 76 des 77 tags de trivy-action réécrits pour voler les secrets des CI (CVE-2026-33634)."
echo "  uses: aquasecurity/trivy-action@<SHA de 40 caractères> # v0.36.0   ← ce qu'on écrit dans release.yml"

#!/usr/bin/env bash
# =============================================================================
# Démo J2 — Bloc 3.3 : Jenkins et GitLab CI, les mêmes concepts que GitHub Actions
#   Usage   : bash demo.sh                 (pauses entre les étapes)
#             DEMO_AUTO=1 bash demo.sh      (sans pause, pour tester la veille)
#             GITLAB_LOCAL=1 bash demo.sh   (+ exécute .gitlab-ci.yml en local avec
#                                            gitlab-ci-local, via npx)
#             KEEP=1 bash demo.sh           (laisse Jenkins tourner à la fin)
#   Ports   : JENKINS_PORT (8090), sur 127.0.0.1 uniquement
#   Effet   : construit l'image Jenkins (plugins + JCasC), prépare un dépôt Git
#             local à partir de tp/fil-rouge-taskflow/solution, lance les deux jobs
#             de démo, puis supprime conteneur, image et dossiers (sauf KEEP=1).
#   Durée   : 5 à 8 min au premier lancement (téléchargement des plugins) ;
#             lancez-le une fois la veille.
# =============================================================================
set -euo pipefail

DEMO_AUTO="${DEMO_AUTO:-0}"
GITLAB_LOCAL="${GITLAB_LOCAL:-0}"
KEEP="${KEEP:-0}"
DOCKER="${DOCKER:-docker}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOLUTION="$HERE/../../tp/fil-rouge-taskflow/solution"

export JENKINS_PORT="${JENKINS_PORT:-8090}"
export JENKINS_ADMIN_PASSWORD="${JENKINS_ADMIN_PASSWORD:-admin}"
export JENKINS_HOME_DIR="$HERE/.jenkins-home"
export TASKFLOW_BARE_REPO="$HERE/.taskflow.git"
JENKINS_URL="http://localhost:$JENKINS_PORT"

# --- Docker Engine ou Podman ? ------------------------------------------------
if "$DOCKER" version 2>/dev/null | grep -qi podman; then
  export PODMAN_COMPAT=1 JENKINS_USER=root
  export DOCKER_SOCK="${DOCKER_SOCK:-/run/user/$(id -u)/podman/podman.sock}"
  export DOCKER_GID=0
else
  export DOCKER_SOCK="${DOCKER_SOCK:-/var/run/docker.sock}"
  DOCKER_GID="$(stat -c %g "$DOCKER_SOCK")"
  export DOCKER_GID
fi
[[ -S "$DOCKER_SOCK" ]] || { echo "Socket Docker introuvable : $DOCKER_SOCK (variable DOCKER_SOCK)" >&2; exit 1; }

compose() { (cd "$HERE" && "$DOCKER" compose "$@"); }
COOKIES="$(mktemp)"

cleanup() {
  rm -rf "${GLCI_DIR:-/nonexistent}" "$COOKIES"
  if [[ "$KEEP" == "1" ]]; then
    echo -e "\nJenkins reste disponible sur $JENKINS_URL (admin / $JENKINS_ADMIN_PASSWORD)."
    echo "Arrêt et ménage : cd $HERE && JENKINS_HOME_DIR=$JENKINS_HOME_DIR $DOCKER compose down && rm -rf .jenkins-home .taskflow.git"
    return
  fi
  compose down --remove-orphans >/dev/null 2>&1 || true
  "$DOCKER" rmi -f demo-jenkins-cda:local >/dev/null 2>&1 || true
  rm -rf "$JENKINS_HOME_DIR" "$TASKFLOW_BARE_REPO"
  echo -e "\nJenkins arrêté ; image, JENKINS_HOME et dépôt de démo supprimés."
}
trap cleanup EXIT

etape() { echo -e "\n\033[1;34m=== $* ===\033[0m"; }
pause() {
  if [[ "$DEMO_AUTO" == "1" ]]; then return 0; fi
  read -r -p $'\n> Entrée pour continuer... ' _
}
run() { echo -e "\033[1;32m\$ $*\033[0m"; eval "$*"; }

# --- API REST de Jenkins (jeton anti-CSRF « crumb » + cookie de session) -------
jenkins() { curl -fsS -u "admin:$JENKINS_ADMIN_PASSWORD" -c "$COOKIES" -b "$COOKIES" "$@"; }
lancer_job() {   # lancer_job NOM : déclenche le job et attend la fin
  local job="$1" crumb n
  crumb="$(jenkins "$JENKINS_URL/crumbIssuer/api/json" | jq -r '.crumbRequestField + ":" + .crumb')"
  n="$(jenkins "$JENKINS_URL/job/$job/api/json" | jq -r '.nextBuildNumber')"
  jenkins -X POST -H "$crumb" "$JENKINS_URL/job/$job/build" -o /dev/null
  echo "Build #$n de $job lancé : $JENKINS_URL/job/$job/$n/"
  until jenkins "$JENKINS_URL/job/$job/$n/api/json" 2>/dev/null | jq -e '.building == false' >/dev/null; do
    sleep 5
  done
  jenkins "$JENKINS_URL/job/$job/$n/api/json" | jq -r '"Résultat : " + .result + " en " + ((.duration / 1000 | floor | tostring)) + " s"'
}

command -v jq >/dev/null || { echo "jq est requis (affichage des résultats)" >&2; exit 1; }

etape "0. Préparer un dépôt Git local de TaskFlow (la solution, sans node_modules)"
rm -rf "$TASKFLOW_BARE_REPO" && mkdir -p "$JENKINS_HOME_DIR"
SRC="$(mktemp -d -t demo-jenkins-src-XXXXXX)"
tar -C "$SOLUTION" --exclude=node_modules --exclude=dist --exclude=coverage -cf - . | tar -C "$SRC" -xf -
git -C "$SRC" init -q -b main
git -C "$SRC" add -A
git -C "$SRC" -c user.name=Formateur -c user.email=formateur@example.com commit -q -m "chore: TaskFlow pour la démo Jenkins"
git clone -q --bare "$SRC" "$TASKFLOW_BARE_REPO" && rm -rf "$SRC"
echo "Dépôt prêt : $TASKFLOW_BARE_REPO (monté dans Jenkins en /srv/taskflow.git)"
pause

etape "1. Jenkins décrit en code : plugins + Configuration as Code (JCasC)"
run "cat '$HERE/jenkins/plugins.txt'"
run "sed -n '1,25p' '$HERE/jenkins/casc.yaml'"
echo "→ Pas d'assistant d'installation, pas de clics : Jenkins est reproductible (et versionné)."
pause

etape "2. Construire et démarrer Jenkins (controller seul, il pilote le Docker du poste)"
run "compose up -d --build"
echo "Attente de Jenkins (jusqu'à 5 min au premier démarrage)..."
pret=0
for _ in $(seq 1 150); do
  if jenkins "$JENKINS_URL/api/json" >/dev/null 2>&1; then pret=1; break; fi
  sleep 2
done
if [[ "$pret" != "1" ]]; then
  echo "Jenkins ne répond pas sur $JENKINS_URL. Derniers logs :" >&2
  compose logs --tail 30 jenkins >&2 || true
  exit 1
fi
run "curl -s -u admin:$JENKINS_ADMIN_PASSWORD -g '$JENKINS_URL/api/json?tree=jobs[name]' | jq -r '.jobs[].name'"
echo "→ Navigateur : $JENKINS_URL (admin / $JENKINS_ADMIN_PASSWORD)"
pause

etape "3. Job 01-hello-pipeline : stages, parallel, matrix, post (aucun conteneur)"
lancer_job 01-hello-pipeline
echo "→ Montrez la vue graphique du build (Pipeline Overview) et l'artefact archivé."
pause

etape "4. Le Jenkinsfile de TaskFlow (équivalent de ci.yml)"
run "grep -nE \"stage\\(|matrix|parallel|agent|docker\\.image|archiveArtifacts|timeout|disableConcurrentBuilds\" '$SOLUTION/ci-autres-outils/Jenkinsfile'"
pause

etape "5. Job 02-taskflow-ci : la vraie CI de TaskFlow, chaque stage dans un conteneur node"
lancer_job 02-taskflow-ci
run "jenkins '$JENKINS_URL/job/02-taskflow-ci/lastBuild/consoleText' | grep -E 'Tests |Couverture des lignes|built in|Finished' | sed 's/\x1b\[[0-9;]*m//g'"
echo "→ Comparez avec un run GitHub Actions : mêmes étapes, mêmes verdicts, autre outil."
pause

etape "6. GitLab CI : le même pipeline en YAML (stages, rules, services, cache, artefacts)"
run "grep -nE '^[a-z.][a-z_.-]*:|stage:|parallel:|services:|cache:|artifacts:|needs:|rules:' '$SOLUTION/ci-autres-outils/.gitlab-ci.yml'"
echo "→ Sur gitlab.com : Build > Pipeline editor > Validate, ou un projet public pour voir un pipeline réel."
if [[ "$GITLAB_LOCAL" == "1" ]]; then
  GLCI_DIR="$(mktemp -d -t demo-glci-XXXXXX)"
  git clone -q "$TASKFLOW_BARE_REPO" "$GLCI_DIR/taskflow"
  cp "$SOLUTION/ci-autres-outils/.gitlab-ci.yml" "$GLCI_DIR/taskflow/.gitlab-ci.yml"
  # gitlab-ci-local exécute les jobs dans des conteneurs, comme un runner GitLab « docker »
  run "(cd '$GLCI_DIR/taskflow' && npx -y gitlab-ci-local@4 --list)"
  run "(cd '$GLCI_DIR/taskflow' && npx -y gitlab-ci-local@4 --container-executable '$DOCKER' 'api: [20]' api-integration front 2>&1 | grep -E 'PASS|FAIL|Tests |Couverture')"
fi
pause

echo -e "\nFin de la démo. À retenir : mêmes concepts (déclencheur, étapes, parallélisme,"
echo "services, cache, artefacts), trois syntaxes. Tableau : tp/fil-rouge-taskflow/solution/ci-autres-outils/README.md"

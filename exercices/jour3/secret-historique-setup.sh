#!/usr/bin/env bash
# =============================================================================
# Exercice 3.3 — crée un dépôt « notif-service » dont l'historique contient deux
# secrets « supprimés » :
#   - un jeton GitHub dans un fichier .env, commité puis supprimé (git rm) ;
#   - une URL de webhook Slack écrite en dur dans le code, puis remplacée par une
#     variable d'environnement.
# Le dernier commit est PROPRE : `grep` sur les fichiers actuels ne trouve rien.
#
#   bash secret-historique-setup.sh            # crée ./notif-service
#   bash secret-historique-setup.sh /tmp/xyz   # ou ailleurs
#
# Les secrets sont FACTICES et générés aléatoirement à chaque exécution (aucun
# secret, même faux, n'est écrit dans ce dépôt de cours).
# =============================================================================
set -euo pipefail

DEST="${1:-notif-service}"
if [ -e "$DEST" ]; then
  echo "« $DEST » existe déjà : supprimez-le (rm -rf $DEST) ou choisissez un autre chemin." >&2
  exit 1
fi

rand() { (set +o pipefail; LC_ALL=C tr -dc "$1" </dev/urandom | head -c "$2"); }
GH_TOKEN="ghp_$(rand 'A-Za-z0-9' 36)"
SLACK_URL="https://hooks.slack.com/services/T$(rand 'A-Z0-9' 8)/B$(rand 'A-Z0-9' 10)/$(rand 'A-Za-z0-9' 24)"

mkdir -p "$DEST" && cd "$DEST"
git init -q -b main
git config user.name "Camille Dev"
git config user.email "camille@example.com"
git config commit.gpgsign false

c() { # c "<message>" "<date ISO>"
  git add -A
  GIT_AUTHOR_DATE="$2" GIT_COMMITTER_DATE="$2" git commit -q -m "$1"
}

cat > README.md <<'MD'
# notif-service

Petit service qui envoie des notifications (Slack, GitHub) quand une tâche TaskFlow est terminée.
MD
printf 'node_modules/\n' > .gitignore
c "chore: initialise le projet" "2026-01-05T09:12:00"

mkdir -p src
cat > src/index.js <<'JS'
import { notify } from './notify.js';

export function onTaskDone(task) {
  return notify(`Tâche terminée : ${task.title}`);
}
JS
cat > src/notify.js <<'JS'
export async function notify(text) {
  console.log('[notify]', text);
}
JS
c "feat: squelette du service de notification" "2026-01-05T10:40:00"

cat > .env <<ENV
# Configuration locale
PORT=4000
GITHUB_TOKEN=$GH_TOKEN
ENV
c "feat: configuration locale" "2026-01-06T14:03:00"

cat > src/github.js <<'JS'
export function githubHeaders() {
  return { Authorization: `Bearer ${process.env.GITHUB_TOKEN}` };
}
JS
c "feat: client GitHub" "2026-01-06T15:21:00"

git rm -q --cached .env
rm -f .env
printf 'node_modules/\n.env\n' > .gitignore
c "chore: retire .env du dépôt" "2026-01-07T08:55:00"

cat > src/notify.js <<JS
const WEBHOOK = '$SLACK_URL';

export async function notify(text) {
  await fetch(WEBHOOK, { method: 'POST', body: JSON.stringify({ text }) });
}
JS
c "feat: envoi des notifications sur Slack" "2026-01-08T11:30:00"

cat >> README.md <<'MD'

## Lancer

```bash
npm start
```
MD
c "docs: comment lancer le service" "2026-01-08T16:10:00"

cat > src/notify.js <<'JS'
const WEBHOOK = process.env.SLACK_WEBHOOK_URL;

export async function notify(text) {
  if (!WEBHOOK) throw new Error('SLACK_WEBHOOK_URL manquant');
  await fetch(WEBHOOK, { method: 'POST', body: JSON.stringify({ text }) });
}
JS
cat > .env.example <<'ENV'
PORT=4000
GITHUB_TOKEN=
SLACK_WEBHOOK_URL=
ENV
c "refactor: l'URL du webhook vient de l'environnement" "2026-01-09T09:45:00"

echo "Dépôt créé : $(pwd)  ($(git rev-list --count HEAD) commits)"
echo "Les fichiers actuels sont propres... l'historique, lui, ne l'est pas."

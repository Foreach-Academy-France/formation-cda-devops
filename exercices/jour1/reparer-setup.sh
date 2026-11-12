#!/usr/bin/env bash
# =============================================================================
# Prépare un dépôt TaskFlow jetable pour l'exercice 04 « Réparer ses erreurs ».
#   Crée dans /tmp :
#     reparer.XXXXXX/origin.git   dépôt « distant » (bare), joue le rôle de GitHub
#     reparer.XXXXXX/taskflow     votre clone, sur main, à jour avec origin/main
#   État de départ :
#     origin/main : 3 commits, dont le dernier introduit un bug (PORT 3001)
#     feature/export : 2 commits locaux, jamais poussés, jamais fusionnés
#   Usage     : bash reparer-setup.sh
#   Nettoyage : rm -rf <chemin affiché>
# =============================================================================
set -euo pipefail

ROOT="$(mktemp -d -t reparer.XXXXXX)"
git init -q --bare -b main "$ROOT/origin.git"
git clone -q "$ROOT/origin.git" "$ROOT/taskflow" 2>/dev/null
cd "$ROOT/taskflow"

git config commit.gpgsign false
# Identité locale seulement si aucune identité globale n'est configurée
if [[ -z "$(git config user.email || true)" ]]; then
  git config user.name "Apprenant CDA"
  git config user.email "apprenant@taskflow.example"
fi

# commit_as <nom> <message> : commit horodaté de façon déterministe
MINUTE=0
commit_as() {
  local name="$1" message="$2"
  local email date
  email="$(echo "$name" | tr '[:upper:]' '[:lower:]')@taskflow.example"
  MINUTE=$((MINUTE + 5))
  date="$(printf '2026-10-12T14:%02d:00+02:00' "$MINUTE")"
  git add -A
  GIT_AUTHOR_NAME="$name" GIT_AUTHOR_EMAIL="$email" GIT_AUTHOR_DATE="$date" \
  GIT_COMMITTER_NAME="$name" GIT_COMMITTER_EMAIL="$email" GIT_COMMITTER_DATE="$date" \
    git commit -q -m "$message"
}

mkdir -p api/src docs
cat > README.md <<'EOF'
# TaskFlow

Gestionnaire de tâches : front Vite, API Node 20 + Express, PostgreSQL 16.
EOF
cat > .gitignore <<'EOF'
node_modules/
.env
EOF
commit_as "Sarah" "chore: initialise le projet TaskFlow"

cat > api/src/config.js <<'EOF'
export const config = {
  port: Number(process.env.PORT ?? 3000),
  databaseUrl: process.env.DATABASE_URL ?? 'postgres://taskflow:taskflow@localhost:5432/taskflow',
};
EOF
cat > api/src/app.js <<'EOF'
import express from 'express';

export const app = express();
app.get('/health', (req, res) => res.json({ status: 'ok' }));
EOF
commit_as "Yanis" "feat(api): ajoute la route /health"

sed -i.bak 's/?? 3000/?? 3001 \/\/ BUG : le front et le compose attendent 3000/' api/src/config.js && rm -f api/src/config.js.bak
commit_as "Yanis" "feat(api): change le port par défaut"

git push -q origin main

# Branche locale jamais poussée
git switch -q -c feature/export
cat >> api/src/app.js <<'EOF'
app.get('/api/tasks/export.csv', (req, res) => res.type('text/csv').send('id,title,done\n'));
EOF
commit_as "Inès" "feat(api): ajoute l'export CSV des tâches"
mkdir -p api/tests
echo "// test de l'export CSV" > api/tests/export.test.js
commit_as "Inès" "test(api): teste l'export CSV"
git switch -q main

echo "Dépôt prêt : $ROOT/taskflow   (distant simulé : $ROOT/origin.git)"
echo "Commencez par : cd $ROOT/taskflow && git log --oneline --graph --all"
echo "Nettoyage     : rm -rf $ROOT"

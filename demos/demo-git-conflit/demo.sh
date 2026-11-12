#!/usr/bin/env bash
# =============================================================================
# Démo J1 — TP 1 : conflit textuel puis conflit sémantique (avec zdiff3)
#   Usage   : bash demo.sh            (pauses ; vous pouvez résoudre à la main)
#             DEMO_AUTO=1 bash demo.sh (sans pause, résolutions automatiques)
#   Effet   : dépôt jetable dans /tmp (mktemp), supprimé à la fin (KEEP=1 pour garder)
# =============================================================================
set -euo pipefail

DEMO_AUTO="${DEMO_AUTO:-0}"
KEEP="${KEEP:-0}"
WORKDIR="$(mktemp -d -t demo-git-conflit-XXXXXX)"

cleanup() {
  if [[ "$KEEP" == "1" ]]; then
    echo -e "\n📁 Dépôt conservé : $WORKDIR"
  else
    rm -rf "$WORKDIR"
    echo -e "\n🧹 Dépôt jetable supprimé ($WORKDIR)"
  fi
}
trap cleanup EXIT

etape() { echo -e "\n\033[1;34m=== $* ===\033[0m"; }
pause() {
  if [[ "$DEMO_AUTO" == "1" ]]; then return 0; fi
  read -r -p $'\n▶ Entrée pour continuer… ' _
}
run() { echo -e "\033[1;32m\$ $*\033[0m"; eval "$*"; }
reste_marqueurs() { grep -qE '^(<<<<<<<|\|\|\|\|\|\|\||=======|>>>>>>>)' index.html; }

cd "$WORKDIR"

etape "1. Situation de départ : la page d'accueil de la promo"
run "git init -q -b main ."
run "git config user.name 'Formateur'"
run "git config user.email 'formateur@example.com'"
run "git config merge.conflictStyle zdiff3"
echo "→ zdiff3 : dans un conflit, Git montrera AUSSI la version de l'ancêtre commun."
cat > index.html <<'HTML'
<h1 class="hero__title">La promo CDA</h1>
<ul class="promo">
  <li>Camille (exemple)</li>
  <!-- chacun ajoute sa ligne ICI -->
</ul>
HTML
run "git add index.html"
run "git commit -q -m 'chore: initialise la page de la promo'"
run "cat index.html"
pause

# ---------------------------------------------------------------------------
etape "2. CONFLIT TEXTUEL — Alice et Bob ajoutent chacun leur ligne au même endroit"
run "git switch -q -c feature/carte-alice"
sed -i.bak 's#  <!-- chacun#  <li>Alice</li>\n  <!-- chacun#' index.html && rm -f index.html.bak
run "git commit -q -am 'feat(accueil): ajoute Alice'"
run "git switch -q main"
run "git switch -q -c feature/carte-bob"
sed -i.bak 's#  <!-- chacun#  <li>Bob</li>\n  <!-- chacun#' index.html && rm -f index.html.bak
run "git commit -q -am 'feat(accueil): ajoute Bob'"
run "git switch -q main"
run "git merge -q feature/carte-alice"
echo "→ La PR d'Alice est fusionnée. Bob met sa branche à jour avec main, comme dans le TP :"
run "git switch -q feature/carte-bob"
run "git merge main || true"
run "git status --short"
echo "→ UU = modifié des deux côtés, pas encore résolu (unmerged)."
pause

etape "3. Lire les trois versions"
run "cat index.html"
cat <<'TXT'

  <<<<<<< HEAD          → la version de la branche courante (Bob)
  ||||||| …             → l'ANCÊTRE COMMUN (grâce à zdiff3)
  =======               → séparateur
  >>>>>>> main          → ce qui arrive de main (Alice)
TXT
run "git log --merge --oneline"
echo "→ --merge : les commits, des deux côtés, qui touchent les fichiers en conflit."
pause

etape "4. Résoudre : ici, on garde les deux lignes"
if [[ "$DEMO_AUTO" != "1" ]]; then
  echo "Ouvrez $WORKDIR/index.html (VS Code : « Accept Both Changes »), enregistrez, puis Entrée."
  echo "Si vous ne touchez à rien, le script résout pour vous."
  pause
fi
if reste_marqueurs; then
  echo "(résolution automatique : Alice ET Bob)"
  cat > index.html <<'HTML'
<h1 class="hero__title">La promo CDA</h1>
<ul class="promo">
  <li>Camille (exemple)</li>
  <li>Alice</li>
  <li>Bob</li>
  <!-- chacun ajoute sa ligne ICI -->
</ul>
HTML
fi
run "cat index.html"
run "git add index.html"
run "git diff --cached --check && echo 'Aucun marqueur restant ✔'"
run "git commit -q --no-edit"
run "git switch -q main && git merge -q feature/carte-bob"
run "git log --oneline --graph --all"
pause

# ---------------------------------------------------------------------------
etape "5. CONFLIT SÉMANTIQUE — deux idées différentes pour le même titre"
run "git switch -q -c feature/titre-a"
sed -i.bak 's#La promo CDA#Promo CDA : nos projets#' index.html && rm -f index.html.bak
run "git commit -q -am 'feat(accueil): met les projets en avant dans le titre'"
run "git switch -q main"
run "git switch -q -c feature/titre-b"
sed -i.bak 's#La promo CDA#CDA, la promo qui déploie#' index.html && rm -f index.html.bak
run "git commit -q -am 'feat(accueil): met le DevOps en avant dans le titre'"
run "git switch -q main && git merge -q feature/titre-a"
run "git switch -q feature/titre-b"
run "git merge main || true"
run "sed -n '1,7p' index.html"
echo "→ Ici, « Accept Both » donnerait DEUX <h1> : fichier valide, site faux."
echo "→ Ce n'est pas à Git, ni à B seul, de trancher : on en parle avec A (dans la PR)."
pause

etape "6. On n'est pas prêt à décider ? On annule proprement"
run "git merge --abort"
run "git status --short && echo '(rien : on est revenu à l état d avant la fusion)'"
echo "→ Décision prise avec A : une synthèse des deux propositions."
pause

etape "7. Rejouer la fusion et appliquer la décision"
run "git merge main || true"
cat > index.html <<'HTML'
<h1 class="hero__title">Promo CDA : nos projets, en production</h1>
<ul class="promo">
  <li>Camille (exemple)</li>
  <li>Alice</li>
  <li>Bob</li>
  <!-- chacun ajoute sa ligne ICI -->
</ul>
HTML
run "cat index.html"
run "git add index.html"
run "git diff --cached --check && echo 'Aucun marqueur restant ✔'"
run "git commit -q -m 'Merge main : titre décidé avec A (synthèse des deux propositions)'"
run "git log --oneline --graph --all"
echo -e "\n✅ Deux conflits : le textuel se résout seul, le sémantique se résout à deux."
echo "   Dans la PR : écrire la décision, puis demander une NOUVELLE revue du fichier entier."

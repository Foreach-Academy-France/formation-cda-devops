# Démo — gitleaks et Trivy : secrets et vulnérabilités

| | |
|---|---|
| **Jour / bloc** | J3 matin — Bloc 7.1 « DevSecOps (1) : sécuriser le pipeline » |
| **Durée** | 15 min |
| **Prérequis** | Docker (ou `DOCKER=podman`), Git, accès Internet (base Trivy ≈ 80 Mo au premier lancement) |
| **Images** | `docker.io/zricethezav/gitleaks:v8.30.1`, `docker.io/aquasec/trivy:0.76.2`, `docker.io/library/nginx:1.27-alpine`, `docker.io/library/nginx:1.29-alpine` |
| **Ce qu'on montre** | hook pre-commit qui bloque un jeton ; contournement par `--no-verify` ; scan de l'historique qui le retrouve ; Trivy sur une image ancienne vs récente ; `--exit-code 1` (bloquant) ; SCA sur un `package-lock.json` ; tag mutable vs SHA (incident trivy-action) |

```bash
# La veille (réseau de salle lent) : images + base de vulnérabilités dans le volume demo-trivy-cache
DEMO_AUTO=1 bash demos/demo-trivy-gitleaks/demo.sh >/dev/null
bash demos/demo-trivy-gitleaks/demo.sh          # en séance, avec pauses
KEEP_CACHE=0 DEMO_AUTO=1 bash demos/demo-trivy-gitleaks/demo.sh   # supprime aussi le cache à la fin
```

Le script crée un dépôt jetable dans un dossier `mktemp`, supprimé à la fin (même après Ctrl+C). Le jeton est
**factice et généré au lancement** : aucun secret, même faux, n'est écrit dans le dépôt du cours.

## Déroulé

| Min | Étape du script | Dire / montrer | Question à poser à la salle |
|---|---|---|---|
| 0-2 | 1. jeton dans `config.env` | « Cas réel : on teste en local, on colle un jeton dans un fichier, `git add .` » | « Qui a déjà commité un `.env` ? » (main levée sans jugement) |
| 2-4 | 2. `gitleaks git --pre-commit --staged` | règle `github-pat`, entropie, code de sortie **1** = commit refusé | « Pourquoi le plus tôt possible ? » (un secret jamais commité n'a pas à être purgé) |
| 4-6 | 3. `--no-verify`, puis `git rm` | le hook est local et contournable ; le fichier disparaît de l'arbre | « Le secret est-il encore quelque part ? » |
| 6-8 | 4. scan de l'historique | gitleaks le retrouve avec le **commit** et l'auteur ; lien avec l'exercice 3.3 | « Que fait-on en premier : purger ou révoquer ? » |
| 8-10 | 5-6. Trivy sur `nginx:1.27-alpine` puis `1.29-alpine` | CVE, paquet, version installée / corrigée ; `--ignore-unfixed` ; `exit=1` | « Même la dernière image officielle peut avoir un CRITICAL corrigé : que faire ? » (`apk upgrade`, attendre la reconstruction, documenter) |
| 10-12 | 7. `trivy fs` sur `starter/api` | SCA : vulnérabilités des dépendances npm, même principe que `npm audit` | « HIGH sans correctif : on bloque la release ? » (triage, exception documentée) |
| 12-15 | 8. `git ls-remote` trivy-action | un tag est un pointeur **déplaçable** ; mars 2026 : 76/77 tags de `aquasecurity/trivy-action` réécrits pour voler les secrets des CI (CVE-2026-33634) ; seul l'épinglage par SHA protégeait | « Qui met à jour les SHA épinglés ? » (Dependabot, écosystème `github-actions`) |

## Pièges à anticiper

- **Les résultats Trivy changent chaque jour** (nouvelles CVE, images reconstruites) : lancez la démo la veille et
  ajustez le discours. Si `nginx:1.29-alpine` est propre ce jour-là, c'est encore mieux : « monter de version suffit ».
- Premier lancement de Trivy : téléchargement de la base (30 s à quelques minutes). Le volume `demo-trivy-cache` la garde.
- `0 commits scanned` sur un historique : gitleaks n'a rien lu (dépôt appartenant à un autre utilisateur, `--user`
  ajouté). En mode `--staged`, 0 commit est normal.
- Podman rootless : passez `DOCKER=podman`. Les images sont pleinement qualifiées (`docker.io/...`).
- Pas d'Internet pour `git ls-remote` : montrez la ligne `uses: aquasecurity/trivy-action@<sha> # v0.36.0` de
  `solution/.github/workflows/release.yml`.

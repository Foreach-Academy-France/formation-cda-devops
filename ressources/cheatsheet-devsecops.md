# Cheatsheet DevSecOps

> La sécurité à chaque étape de la boucle DevOps. Rappel : *un outil qui alerte n'est utile que si quelqu'un trie.*

## Où placer chaque contrôle

| Étape | Contrôle | Outils |
|---|---|---|
| PLAN | threat modeling (STRIDE) | OWASP Threat Dragon |
| CODE | secrets, SAST | gitleaks, **Semgrep**, CodeQL |
| BUILD | dépendances (SCA), SBOM | **npm audit**, **Trivy**, syft, Dependabot |
| TEST | DAST, IAST | **OWASP ZAP**, Burp |
| RELEASE | signature, provenance | cosign (Sigstore), attestations SLSA |
| DEPLOY | config durcie, IaC scannée | Trivy config, Checkov |
| OPERATE | WAF, veille CVE | Dependabot, scans planifiés |
| MONITOR | logs de sécurité, alertes | Prometheus, Alertmanager (J4) |

## Les familles d'outils

| | Analyse | Trouve | Rate |
|---|---|---|---|
| **SAST** | le code source | injection, XSS, `eval`, secrets | la config, l'exécution |
| **DAST** | l'appli qui tourne | en-têtes, cookies, config | le code non atteint |
| **SCA** | les dépendances | CVE connues, licences | le code maison |
| **IAST** | l'appli de l'intérieur (tests) | flux donnée → requête | le non-testé |

## OWASP Top 10 (2021) en une ligne chacun

| # | Catégorie | Correction type |
|---|---|---|
| A01 | Broken Access Control | vérifier propriété **et** rôle côté serveur ; 404 plutôt que 403 |
| A02 | Cryptographic Failures | bcrypt/argon2, HTTPS + HSTS, pas de secret en dur |
| A03 | Injection (SQL, XSS) | requêtes **paramétrées** (`$1`), `textContent`, échappement, CSP |
| A04 | Insecure Design | threat modeling, rate limit, *abuse cases* |
| A05 | Security Misconfiguration | en-têtes, `server_tokens off`, erreurs génériques, pas de listing |
| A06 | Vulnerable Components | `npm audit`, Dependabot, Trivy, images à jour |
| A07 | Auth Failures | hash fort, MFA, sessions courtes, anti-énumération |
| A08 | Data Integrity Failures | lockfile + `npm ci`, SRI, actions épinglées, cosign |
| A09 | Logging & Monitoring Failures | journaliser les événements de sécu (jamais les secrets), alerter |
| A10 | SSRF | liste blanche d'URL, réseau segmenté |

> 2025 : A01 absorbe le SSRF ; A05 Misconfiguration monte en 2e ; **Software Supply Chain** devient A03 ;
> nouveau A10 « Mishandling of Exceptional Conditions ». On garde 2021 comme référence des outils.

## Commandes

### gitleaks (secrets)
```bash
gitleaks git --redact --verbose                 # tout l'historique
gitleaks dir . --redact                          # l'arborescence actuelle
# config : .gitleaks.toml ([extend] useDefault=true + [[allowlists]] étroites)
```

### npm audit (SCA)
```bash
npm audit                          # détail lisible
npm audit --audit-level=high       # échoue (code 1) sur high/critical → pour le CI
npm audit --json > audit.json      # pour le triage / artefact
npm audit fix                      # corrections compatibles (jamais --force à l'aveugle)
```

### Semgrep (SAST, sans compte)
```bash
docker run --rm -v "$PWD":/src:ro -w /src docker.io/semgrep/semgrep:1.184.0 \
  semgrep scan --config p/javascript --config p/nodejsscan --metrics=off --error
# faux positif : // nosemgrep: <id-de-règle>  (sur la ligne, jamais nu)
```

### OWASP ZAP (DAST)
```bash
# baseline (passif) — pour le CI
docker run --rm --network host -v "$PWD/zap:/zap/wrk:rw" ghcr.io/zaproxy/zaproxy:2.17.0 \
  zap-baseline.py -t http://localhost:8080 -c rules.tsv -I -r rapport.html
# full scan (ACTIF) — staging / cible autorisée uniquement
zap-full-scan.py -t http://localhost:8080
# .zap/rules.tsv : ID<TAB>IGNORE|WARN|FAIL<TAB>commentaire
```

### SBOM
```bash
syft <image> -o cyclonedx-json > sbom.json
trivy image --format cyclonedx --output sbom.json <image>
trivy sbom sbom.json               # rescanner un SBOM plus tard
```

### Outils de pentest (cible autorisée uniquement)
```bash
nmap -sV -p 1-10000 127.0.0.1                    # ports + versions
nikto -h http://localhost:8080                    # config du serveur web
sqlmap -u "http://host/rest/x?q=1" --batch        # injections SQL
# Burp Suite : proxy d'interception (Repeater, Intruder, Decoder)
```

## En-têtes de sécurité HTTP (Nginx)

```nginx
server_tokens off;
add_header Content-Security-Policy "default-src 'self'; frame-ancestors 'none'" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "DENY" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
proxy_hide_header X-Powered-By;
# Strict-Transport-Security : sur le proxy HTTPS seulement
```

> Piège : `add_header` **n'est pas hérité**. Une `location` avec son propre `add_header` perd tous ceux du niveau
> `server` (CSP comprise). Vérifiez les en-têtes aussi sur `/assets/...`, pas seulement sur `/`.

## Triage : 4 questions par alerte

1. Atteignable en **production** ?
2. La donnée vient-elle de l'**utilisateur** ?
3. Quel **impact** (confidentialité / intégrité / disponibilité) ?
4. **Décision** : corriger / issue priorisée / exception datée et justifiée.

Une alerte **corrigée** passe en `FAIL` dans `rules.tsv` → test de non-régression de sécurité.

## Cadre légal (France)

- **Article 323-1** Code pénal : accès ou maintien frauduleux dans un STAD = 3 ans / 100 000 € (5 ans / 150 000 € si
  données altérées). 323-2 (entrave), 323-3 (données), 323-3-1 (outils d'attaque sans motif légitime).
- **Jamais** sans **autorisation écrite** du propriétaire (périmètre, dates, contacts). Bug bounty = autorisation
  dans la politique du programme. Faille trouvée par hasard → **divulgation responsable** (security.txt, ANSSI).
- Entraînement légal : **OWASP Juice Shop**, PortSwigger Web Security Academy, Root-Me, TryHackMe, HackTheBox.

# Démo — OWASP ZAP sur Juice Shop

| | |
|---|---|
| **Jour / bloc** | J5 — Bloc 7.4 « Outils de pentest » |
| **Durée** | ~10 min |
| **Prérequis** | Docker ; ports **3002** (Juice Shop) et libres pour ZAP ; images `bkimminich/juice-shop` et `ghcr.io/zaproxy/zaproxy:2.17.0` pré-téléchargées (≈ 450 + 1700 Mo). Faites les `docker pull` **avant** la séance. |
| **Ce qu'on montre** | un scan **DAST** automatisé (ZAP baseline) contre une appli qui tourne ; la lecture d'un rapport ; **ce que la baseline voit** (en-têtes, CORS, fuites) **et ce qu'elle ne voit pas** (l'injection SQL du login) → pourquoi il faut aussi un scan actif, un SAST et une revue humaine. |

> Cadre légal : on scanne **Juice Shop sur le poste du formateur**, cible d'entraînement de l'OWASP, explicitement
> autorisée. Les mêmes gestes contre un système tiers sans autorisation écrite tombent sous l'article 323-1 du Code
> pénal (voir slides 7.4).

## Contenu du dossier

| Fichier | Rôle |
|---|---|
| `demo.sh` | démarre Juice Shop, lance un **ZAP baseline**, montre le rapport, puis nettoie |

## Lancer

```bash
docker pull docker.io/bkimminich/juice-shop          # avant la séance
docker pull ghcr.io/zaproxy/zaproxy:2.17.0           # avant la séance (~1.7 Go)

bash demos/demo-zap-juice-shop/demo.sh               # démo guidée (pauses)
DEMO_AUTO=1 bash demos/demo-zap-juice-shop/demo.sh   # sans pause (vérifie que tout tourne et nettoie)
KEEP=1 bash demos/demo-zap-juice-shop/demo.sh        # laisse Juice Shop tourner après la démo
```

Le script ouvre le rapport HTML à la fin (ou affiche son chemin). Le conteneur Juice Shop et les rapports temporaires
sont supprimés en sortie, sauf `KEEP=1`.

## Déroulé (formateur)

1. **Démarrer la cible** : Juice Shop sur `http://localhost:3002` (le script attend qu'il réponde).
2. **ZAP baseline** : scan **passif** (spider ~1 min + analyse des réponses, **aucune attaque**). Commenter le
   résumé `FAIL / WARN / PASS` à la fin.
3. **Lire le rapport** : ouvrir le HTML, montrer les alertes typiques de **mauvaise configuration** (A05) :
   - *Content Security Policy (CSP) Header Not Set*
   - *Cross-Domain Misconfiguration* (CORS `Access-Control-Allow-Origin: *`)
   - en-têtes d'isolation d'origine manquants
   → exactement les en-têtes que les apprenants **ajoutent** à TaskFlow dans l'étape 5.
4. **Le point clé** : la baseline **n'a pas** trouvé l'injection SQL du login (`' OR 1=1--`) ni les failles de
   contrôle d'accès de l'exercice du matin. Un scan **passif** ne les voit pas. Pour cela, il faut :
   - un scan **actif** (`zap-full-scan.py`, sur cible autorisée uniquement),
   - un **SAST** (Semgrep) sur le code,
   - des **tests d'autorisation** et une **revue** de code.
5. **(Si le temps le permet)** Montrer **ZAP Desktop** : *Manual Explore* sur Juice Shop, l'historique des requêtes,
   rejouer la requête de login modifiée. (Hors script : application graphique.)

## Ce qu'on retient

- La **baseline** est rapide et sûre → sa place est **dans le CI, à chaque PR** (c'est le job `dast` de `security.yml`).
- Elle **ne remplace pas** un scan actif planifié, un pentest humain, ni la revue de code : **défense en profondeur**.

## Si ça ne marche pas

- Juice Shop met 10 à 30 s à démarrer : le script attend `http://localhost:3002`.
- ZAP ne joint pas la cible : la démo utilise `--network host` (indispensable pour atteindre `localhost:3002` depuis
  le conteneur ZAP).
- `permission denied` sur le dossier de rapport : le script fait un `chmod` (ZAP tourne en uid 1000 dans son conteneur).
- Sous Podman (`docker` = alias), le scan fonctionne mais peut être un peu plus lent au premier lancement.

# Exercices du Jour 5 — DevSecOps

> **Séance** : 3h30, jouée deux fois (demi-groupe A le matin, demi-groupe B l'après-midi).
> Les exercices se placent entre le bloc 7.3 (OWASP Top 10) et le bloc 7.4 (outils de pentest).

| # | Exercice | Durée | Moment | Fichiers |
|---|---|---|---|---|
| 1 | **Chasse aux failles sur OWASP Juice Shop** : 6 défis guidés, chacun rattaché à sa catégorie OWASP et à « comment le pipeline l'aurait évité / détecté » | 40 min | H+1:05 – H+1:45 | [`01-chasse-juice-shop.md`](01-chasse-juice-shop.md), [`lancer-juice-shop.sh`](lancer-juice-shop.sh) |

Solutions (formateur, à ne pas distribuer avant la correction) : [`solutions.md`](solutions.md).

## Prérequis

- Docker en état de marche (`docker run hello-world`), environ 500 Mo libres pour l'image Juice Shop.
  **Faites le `docker pull` à l'avance** (la veille ou pendant le bloc 7.2) : à 15 personnes sur le même Wi-Fi, le
  téléchargement prend du temps.
- Un navigateur avec ses outils de développement (F12) : onglets *Réseau*, *Application / Stockage*, *Console*.
- Le port **3002** libre : 3000 est pris par l'API TaskFlow en dev, 3001 par Grafana (Jour 4), 8080 par le front.

```bash
docker pull docker.io/bkimminich/juice-shop
bash exercices/jour5/lancer-juice-shop.sh        # ou : docker run --rm -p 3002:3000 docker.io/bkimminich/juice-shop
# → http://localhost:3002
```

## Cadre

Juice Shop est une application **volontairement vulnérable** publiée par l'OWASP pour l'entraînement. On l'attaque
**uniquement sur son propre poste**. Les mêmes techniques contre un site dont vous n'avez pas l'autorisation écrite
du propriétaire tombent sous le coup de l'article 323-1 du Code pénal (voir slides, bloc 7.4).

# Jour 3 — Exercices : déploiement continu et sécurité du pipeline

Exercices du matin, chacun à la suite d'un bloc de théorie. L'après-midi est consacré au TP fil rouge, étape 2
([`../../tp/fil-rouge-taskflow/etape2-cd.md`](../../tp/fil-rouge-taskflow/etape2-cd.md)).

| # | Exercice | Durée | Bloc | Fichiers fournis |
|---|---|---|---|---|
| 3.1 | [Choisir une stratégie de déploiement](01-strategie-deploiement.md) | 25 min | 4.2 | — (4 scénarios dans l'énoncé) |
| 3.2 | [La configuration Nginx du proxy à corriger](02-nginx-a-corriger.md) | 20 min | 4.3 | [`taskflow-casse.conf`](taskflow-casse.conf), [`nginx-labo/`](nginx-labo/) |
| 3.3 | [Le secret caché dans l'historique Git](03-secret-historique.md) | 30 min | 7.1 | [`secret-historique-setup.sh`](secret-historique-setup.sh) |
| 3.4 | *Bonus* — [Durcir un workflow GitHub Actions](04-workflow-a-durcir.md) | 15 min | 7.1 | [`workflow-a-durcir.yml`](workflow-a-durcir.yml) |

**Corrigé :** [`solutions.md`](solutions.md), à ouvrir après avoir cherché.

## Avant de commencer

- Images à pré-télécharger (le réseau de salle est lent) :
  ```bash
  docker pull docker.io/library/nginx:1.29-alpine
  docker pull docker.io/zricethezav/gitleaks:v8.30.1
  docker pull docker.io/library/python:3.13-alpine     # pour git filter-repo sans l'installer
  ```
- Le labo 3.2 utilise les ports **8880** et **8444** : il cohabite avec la prod (80/443 ou 8082/8443), le staging (8081)
  et le dev (8080).
- L'exercice 3.3 crée un dépôt jetable **hors** de votre dépôt `taskflow` (par défaut `./notif-service`) :
  lancez le script dans un dossier de travail, pas dans un clone existant.

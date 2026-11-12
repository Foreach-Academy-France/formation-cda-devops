# Exercices — DevOps CDA

Exercices **courts (10 à 40 min)** de mise en situation : ce sont eux qui occupent la seconde moitié de chaque bloc du matin. Certains se font en groupe (étude de cas, value stream mapping), la plupart seul. Ils servent d'évaluation **formative** : on s'entraîne, on se trompe, on recommence. Ils ne sont pas notés.

## Index

| Jour | # | Exercice | Durée | Bloc |
|---|---|---|---|---|
| J1 | 1.1 | [Classer des situations selon CALMS](jour1/01-classement-calms.md) | 10 min | 1.1, 1.3 |
| J1 | 1.2 | [*Value stream mapping* de La Fromagerie](jour1/02-value-stream-mapping.md) | 30 min | 1.2 |
| J1 | 1.3 | [Lire un historique Git](jour1/03-lire-historique.md) | 15 min | 2.1 |
| J1 | 1.4 | [Réparer ses erreurs : `restore`, `reset`, `revert`, `reflog`](jour1/04-reparer-ses-erreurs.md) | 25 min | 2.1 |
| J2 | 2.1 | [Rebase interactif, fixup, tag et release](jour2/01-rebase-interactif.md) | 20 min | 2.3 |
| J2 | 2.2 | [Le workflow cassé](jour2/02-yaml-a-corriger.md) | 15 min | 3.2 |
| J2 | 2.3 | [Quel workflow se déclenche ?](jour2/03-quel-declencheur.md) | 10 min | 3.2 |
| J2 | 2.4 | [Lire un log de CI en échec](jour2/04-lire-log-ci.md) | 15 min | 3.2 |
| J2 | 2.5 | [Traduire un workflow en GitLab CI et en Jenkins](jour2/05-traduire-gha-gitlab-jenkins.md) | 25 min | 3.3 |
| J3 | 3.1 | [Choisir une stratégie de déploiement](jour3/01-strategie-deploiement.md) | 25 min | 4.2 |
| J3 | 3.2 | [La configuration Nginx du proxy à corriger](jour3/02-nginx-a-corriger.md) | 20 min | 4.3 |
| J3 | 3.3 | [Le secret caché dans l'historique Git](jour3/03-secret-historique.md) | 30 min | 7.1 |
| J3 | 3.4 | *Bonus* — [Durcir un workflow GitHub Actions](jour3/04-workflow-a-durcir.md) | 15 min | 7.1 |
| J4 | 4.1 | [Un Nginx en code avec OpenTofu](jour4/01-opentofu-nginx.md) | 20 min | 5.2 |
| J4 | 4.2 | [Provoquer et corriger une dérive](jour4/02-opentofu-drift.md) | 15 min | 5.2 |
| J4 | 4.3 | [Lire un plan avant de l'appliquer](jour4/03-lire-un-plan.md) | 10 min | 5.2 |
| J4 | 4.4 | [Un playbook Ansible idempotent](jour4/04-ansible-dossier-deploiement.md) | 30 min | 5.3 |
| J4 | 4.5 | [Analyser des logs JSON avec `jq`](jour4/05-logs-jq.md) | 20 min | 6.1 |
| J5 | 5.1 | [Chasse aux failles sur OWASP Juice Shop](jour5/01-chasse-juice-shop.md) | 40 min | 7.3 |

Chaque jour a son propre index : [jour 1](jour1/README.md) · [jour 2](jour2/README.md) · [jour 3](jour3/README.md) · [jour 4](jour4/README.md) · [jour 5](jour5/README.md).

## Comment travailler un exercice

1. **Lisez tout l'énoncé** avant de taper une commande : objectif, prérequis, résultat attendu.
2. **Suivez les consignes numérotées** dans l'ordre et comparez avec le « Résultat attendu ».
3. **Bloqué ?** Ouvrez l'**Indice 1** ; s'il ne suffit pas, l'**Indice 2**, puis le 3. Chaque indice en dit un peu plus que le précédent : n'ouvrez le suivant qu'après avoir réessayé.
4. **Ensuite seulement**, comparez avec le corrigé du jour (`jourN/solutions.md`). Lire la solution sans avoir cherché ne fait rien retenir.
5. Répondez aux questions de réflexion : ce sont elles qui reviennent dans le QCM et dans les questions de validation du fil rouge.

## Conventions

- Les scripts `.sh` créent leurs dépôts Git **jetables** dans le dossier temporaire du système (`/tmp`) et affichent la commande de nettoyage. Lancez-les avec `bash nom-du-script.sh`.
- Les fichiers « cassés », « à trous » et les logs sont **fournis** dans le dossier de chaque jour. Ne les copiez pas tels quels dans votre dépôt `taskflow`.
- Les commandes Docker utilisent des noms d'images complets (`docker.io/library/...`) : elles fonctionnent avec Docker comme avec Podman.
- Exemples cohérents avec TaskFlow : API Node 20 + Express (port 3000), PostgreSQL 16 (5432), front Vite servi par Nginx (8080 en dev), images `ghcr.io/<owner>/taskflow-api` et `taskflow-front`, « prod » locale = stack Compose `taskflow-prod` dans `~/taskflow-prod/`, domaine `taskflow.localhost`.

## Pour le formateur

- Les fichiers `solutions.md` sont des **corrigés** : à distribuer après l'exercice (ils sont exclus de la génération PDF des supports apprenants).
- La chasse aux failles du jour 5 se fait **uniquement** sur Juice Shop lancé en local : rappelez le cadre légal (slide 7.4) avant de commencer.
- `jour1/historique.txt` est la sortie réelle de `creer-historique.sh --print` (dates et auteurs fixés : mêmes identifiants de commit partout). Si une future version de Git change les identifiants, régénérez-le : `bash creer-historique.sh --print | sed -n '4,$p' > historique.txt`.

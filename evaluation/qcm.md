# QCM — Formation DevOps CDA

**Nom :** ______________________ **Prénom :** ______________________ **Demi-groupe :** A ☐ B ☐

**Durée** : 15 minutes · **Questions** : 20 · **Barème** : 1 point par bonne réponse

> Chaque question n'a **qu'une seule bonne réponse** parmi A, B, C et D.
> Reportez vos réponses dans la **grille en fin de document**. Une mauvaise réponse ne fait pas perdre de point.
> Les exemples s'appuient sur le projet fil rouge **TaskFlow** (API Node 20 + Express + PostgreSQL 16, front Vite servi par Nginx).

---

## Culture DevOps

**1.** Dans `release.yml`, le job `deploy-production` utilise l'environment GitHub `production`, qui exige l'approbation d'un relecteur. Comment qualifier ce pipeline ?

- A. De l'intégration continue : la production n'est pas concernée.
- B. Du déploiement continu : tout est automatisé dans GitHub Actions.
- C. De la livraison continue : l'application est toujours prête à partir, mais un humain décide de la mise en production.
- D. Du déploiement manuel : il faut lancer les commandes sur le serveur.

---

**2.** Pour une fonctionnalité de La Fromagerie, on mesure **10 jours** entre l'idée et la mise en ligne (*lead time*), dont **1 jour** de travail effectif (*process time*). Quelle est l'efficacité du flux ?

- A. 10 % : le reste du temps, le travail attend.
- B. 90 % : seul 1 jour a été perdu.
- C. 1 % : un jour sur cent.
- D. Impossible à calculer sans connaître la taille de l'équipe.

---

**3.** Laquelle de ces mesures **ne fait pas partie** des quatre métriques DORA ?

- A. La fréquence de déploiement.
- B. Le délai entre un commit et sa mise en production (*lead time for changes*).
- C. Le temps de restauration après un incident.
- D. Le nombre de lignes de code écrites par développeur et par semaine.

---

## Gestion de versions et collaboration

**4.** Quelle est la « règle d'or » du `git rebase` ?

- A. Toujours rebaser `main` sur sa branche de fonctionnalité.
- B. Ne jamais rebaser une branche déjà poussée et utilisée par d'autres personnes.
- C. Ne jamais rebaser une branche qui contient plus de trois commits.
- D. Toujours faire `git push --force` sur `main` après un rebase.

---

**5.** Le ruleset de `main` n'autorise que la fusion en **squash**. Quel avantage en tire-t-on ?

- A. Les conflits deviennent impossibles.
- B. Chaque PR devient un seul commit sur `main`, dont le message est le titre de la PR (au format Conventional Commits) : l'historique reste lisible et chaque changement se revert d'un coup.
- C. La CI n'a plus besoin de tourner sur les PR.
- D. Les revues de code deviennent facultatives.

---

**6.** Deux PR fusionnées l'une après l'autre ne provoquent **aucun conflit Git**, mais `main` ne compile plus : l'une renomme une fonction que l'autre utilise. Comment appelle-t-on ce problème, et qu'est-ce qui le détecte ?

- A. Un conflit textuel ; Git le détecte avec des marqueurs `<<<<<<<`.
- B. Une dérive de configuration ; OpenTofu la détecte avec `plan`.
- C. Une fuite de secret ; gitleaks la détecte.
- D. Un conflit sémantique ; seule l'intégration continue (build + tests sur `main` et sur des PR à jour) le détecte.

---

## Intégration continue

**7.** Dans `ci.yml`, le job `api-integration` doit exécuter les tests d'intégration contre une vraie base PostgreSQL. Quelle est la bonne solution ?

- A. Déclarer un conteneur `postgres:16-alpine` dans la section `services:` du job, avec un healthcheck, et passer `DATABASE_URL` aux tests.
- B. Installer PostgreSQL avec `apt-get` à chaque step.
- C. Utiliser la base de production, accessible depuis GitHub.
- D. Ce n'est pas possible : les tests d'intégration ne se lancent qu'en local.

---

**8.** Le job `api` utilise `strategy.matrix.node: [20, 22]`. Quels noms de checks faut-il exiger dans le ruleset de `main` ?

- A. `api`, une seule fois : la matrice est invisible pour GitHub.
- B. `node`.
- C. `api (20)` et `api (22)` : la matrice crée un check par combinaison.
- D. Aucun : les jobs d'une matrice ne peuvent pas être requis.

---

**9.** Dans un `Jenkinsfile` déclaratif, quel élément correspond le mieux à `runs-on:` de GitHub Actions ?

- A. `post { always { … } }`
- B. `agent`, qui désigne la machine (ou le conteneur) où le pipeline s'exécute.
- C. `stage('Build')`
- D. `environment { … }`

---

## Déploiement continu

**10.** Que signifie le principe « **build once, deploy many** » appliqué à TaskFlow ?

- A. On construit une image par environnement pour l'adapter à chacun.
- B. On ne déploie qu'une seule fois par semaine.
- C. On construit les images une seule fois (tag = SHA court du commit) et on promeut **la même image** de staging vers la production ; seule la configuration (`.env`) change.
- D. On reconstruit l'image en production pour être sûr qu'elle contienne les dernières dépendances.

---

**11.** Quelle stratégie de déploiement envoie d'abord **une petite partie du trafic** (par exemple 5 %) vers la nouvelle version, puis augmente si les métriques restent bonnes ?

- A. Canary.
- B. Recreate.
- C. Blue/green.
- D. Rollback.

---

**12.** Pourquoi le smoke test sur `/health` se trouve-t-il **après** chaque job de déploiement, et pas seulement dans `ci.yml` ?

- A. Parce que `ci.yml` ne sait pas exécuter `curl`.
- B. Pour remplacer les tests unitaires, devenus inutiles.
- C. Parce que GitHub l'impose pour utiliser un environment.
- D. Parce qu'il vérifie l'application **déployée** : la configuration réelle de l'environnement (variables, base, réseau) peut casser une image qui passait tous les tests.

---

## Infrastructure as Code

**13.** Pourquoi ne versionne-t-on **pas** `terraform.tfstate` dans Git ?

- A. Parce qu'OpenTofu le recrée à l'identique à chaque `plan`.
- B. Parce que Git refuse les fichiers JSON.
- C. Parce qu'il ne contient rien d'utile.
- D. Parce qu'il peut contenir des secrets en clair et que deux personnes qui l'éditent en même temps le corrompent : on utilise un backend distant avec verrou (ou, dans le TP, un fichier hors du dépôt).

---

**14.** Un collègue supprime à la main le conteneur `taskflow-staging-api` (`docker rm -f`). Que se passe-t-il au prochain `tofu plan` ?

- A. Rien : OpenTofu ne regarde que le code.
- B. Le plan détecte la **dérive** (la ressource du state n'existe plus) et propose de recréer le conteneur.
- C. OpenTofu supprime tout le staging.
- D. Le plan échoue définitivement : il faut supprimer le state.

---

**15.** On lance deux fois de suite le même playbook Ansible sur la même machine. Que doit afficher le **second** passage s'il est bien écrit ?

- A. `failed=1`, car les dossiers existent déjà.
- B. Le même nombre de `changed` que le premier passage.
- C. `changed=0` : les modules sont **idempotents**, l'état voulu est déjà atteint.
- D. Rien : Ansible refuse de relancer un playbook déjà exécuté.

---

## Surveillance et retour d'information

**16.** Que mesure la méthode **RED**, utilisée pour le dashboard de l'API TaskFlow ?

- A. *Rate*, *Errors*, *Duration* : le nombre de requêtes par seconde, la part d'erreurs et la latence.
- B. *Restart*, *Exit*, *Deploy* : le cycle de vie des conteneurs.
- C. *Read*, *Edit*, *Delete* : les opérations sur la base.
- D. *Redis*, *Elasticsearch*, *Docker* : les composants de la stack.

---

**17.** L'alerte `TaskFlowApiDown` s'est déclenchée ; la cause était une variable mal nommée dans `.env`. Après la correction, quelle action **boucle la boucle de feedback** DevOps ?

- A. Identifier la personne responsable pour qu'elle ne recommence pas.
- B. Désactiver l'alerte, qui a fait trop de bruit.
- C. Rédiger un post-mortem sans blâme et ouvrir une issue d'amélioration (par exemple un test ou une vérification au démarrage qui aurait détecté l'erreur avant la production).
- D. Redémarrer Prometheus.

---

## DevSecOps

**18.** Quelle est la différence entre **Semgrep** et **OWASP ZAP** dans `security.yml` ?

- A. Aucune : les deux analysent les dépendances npm.
- B. Semgrep fait du **SAST** (il lit le code source sans l'exécuter) ; ZAP fait du **DAST** (il attaque l'application en fonctionnement).
- C. Semgrep cherche les secrets ; ZAP scanne les images Docker.
- D. Semgrep fait du DAST, ZAP du SAST.

---

**19.** Un développeur a committé un jeton GitHub, puis l'a supprimé dans le commit suivant. Que faut-il faire **en premier** ?

- A. Révoquer le jeton et en générer un nouveau (rotation) : il reste dans l'historique et a pu être copié ; la purge de l'historique vient ensuite.
- B. Rien : le dernier commit ne le contient plus.
- C. Faire un `git revert` du commit qui l'a ajouté.
- D. Rendre le dépôt privé, ce qui suffit à régler le problème.

---

**20.** Sur Juice Shop, saisir `' OR 1=1--` comme e-mail permet de se connecter en administrateur. Quelle catégorie de l'OWASP Top 10 est concernée, et quelle est la correction ?

- A. A07 Défauts d'identification ; imposer des mots de passe plus longs.
- B. A05 Mauvaise configuration ; ajouter un en-tête CSP.
- C. A06 Composants vulnérables ; lancer `npm audit fix`.
- D. A03 Injection ; utiliser des requêtes paramétrées (`$1`) au lieu de concaténer l'entrée dans le SQL.

---

## Grille de réponses

| Q | Réponse | Q | Réponse | Q | Réponse | Q | Réponse |
|---|---|---|---|---|---|---|---|
| 1 | | 6 | | 11 | | 16 | |
| 2 | | 7 | | 12 | | 17 | |
| 3 | | 8 | | 13 | | 18 | |
| 4 | | 9 | | 14 | | 19 | |
| 5 | | 10 | | 15 | | 20 | |

**Score : ______ / 20**

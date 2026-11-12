# Exercice 3.1 — Choisir une stratégie de déploiement

| | |
|---|---|
| **Durée** | 25 min (15 min en binôme, 10 min de restitution) |
| **Bloc** | 4.2 — Stratégies de déploiement |
| **Format** | binôme, réponse écrite (un tableau par scénario) |

## Rappel des options

| Stratégie | En une phrase |
|---|---|
| **Recreate** | On arrête l'ancienne version, puis on démarre la nouvelle (coupure courte) |
| **Rolling** | On remplace les instances une par une ; les deux versions coexistent pendant la bascule |
| **Blue/green** | Deux environnements complets ; on bascule le trafic d'un coup, retour arrière = rebasculer |
| **Canary** | La nouvelle version reçoit d'abord une petite part du trafic (1 %, 10 %…), on observe, on élargit |
| **Feature flag** | Le code est déployé éteint ; on active la fonctionnalité séparément, pour qui on veut |

Et deux décisions transverses : **rollback** (revenir à l'image précédente) ou **roll forward** (corriger et redéployer vite),
et la **migration de base** (compatible avec les deux versions ? *expand / contract*).

## Consigne

Pour chacun des 4 scénarios, remplissez :

| Question | Votre réponse |
|---|---|
| Stratégie retenue (une ou une combinaison) | |
| Pourquoi celle-là (2 arguments tirés de l'énoncé) | |
| Ce que vous refusez, et pourquoi | |
| Comment vous saurez que ça se passe bien (signal, seuil) | |
| Plan de retour arrière (rollback ou roll forward ? données ?) | |

Il n'y a pas une seule bonne réponse : on évalue la **justification** et la cohérence avec les contraintes.

---

### Scénario A — L'outil interne de la mairie

Application de gestion des salles municipales, 40 agents, utilisée de 8h30 à 18h en semaine. Un seul petit serveur,
une base PostgreSQL. Aucun budget pour une deuxième machine. La nouvelle version change l'écran de réservation et
ajoute une colonne `capacite` (nullable) à la table `salles`.

### Scénario B — La boutique en ligne avant les soldes

E-commerce, 3 000 commandes par jour, pic attendu × 8 le premier jour des soldes. L'équipe veut livrer un **nouveau
tunnel de paiement** (prestataire différent). Hébergement sur Kubernetes, 12 réplicas de l'API, métriques Prometheus
(taux d'erreur, panier moyen, taux de conversion). Le marketing veut pouvoir « couper » le nouveau tunnel sans
redéploiement si le taux de conversion baisse.

### Scénario C — L'API de prise de rendez-vous médicaux

API publique consommée par 3 applications mobiles (dont certaines versions anciennes ne sont pas mises à jour par
les patients). Disponibilité contractuelle de 99,9 %. La nouvelle version **renomme** la colonne `date_rdv` en
`debut` et ajoute `fin` (obligatoire). Deux environnements identiques existent déjà derrière un répartiteur de charge.

### Scénario D — TaskFlow, notre fil rouge

Une stack Compose par environnement sur une seule machine (staging sur 8081, prod derrière Nginx en HTTPS). Le
pipeline déploie staging puis prod après approbation. Une version vient de passer le smoke test en staging, mais un
collègue signale qu'elle **consomme trois fois plus de mémoire** que la précédente. Le product owner veut la mise en
production aujourd'hui.

## Questions de synthèse

1. Dans quels scénarios une **coupure de quelques secondes** est-elle acceptable ? Qu'est-ce qui le décide : la
   technique ou le métier ?
2. Pourquoi le renommage de colonne du scénario C interdit-il un simple blue/green « en une étape » ? Décrivez les
   déploiements successifs *expand / contract*.
3. Un feature flag remplace-t-il un canary ? Donnez un cas où l'un est utile et l'autre non.
4. Quelle stratégie TaskFlow utilise-t-il **réellement** aujourd'hui avec `docker compose up -d` ? Que faudrait-il
   pour faire du blue/green avec notre proxy Nginx ?

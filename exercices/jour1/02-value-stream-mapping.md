# Exercice 1.2 — *Value stream mapping* de La Fromagerie

| | |
|---|---|
| **Durée** | 30 min (exercice 2 de la matinée, après le bloc 1.2) |
| **Format** | groupes de 3 ou 4 (les mêmes que pour le TP 0) |
| **Bloc** | 1.2 — Lean : flux, attente, VSM, lead time, efficacité du flux |
| **Prérequis** | partie A du TP 0 (vous connaissez La Fromagerie) |
| **Fichiers fournis** | aucun : une feuille A3 ou un tableau blanc suffit |

## Objectif

Cartographier le flux réel d'une fonctionnalité **de la demande jusqu'à la production**, chiffrer le **lead time** et
l'**efficacité du flux**, puis proposer des améliorations **chiffrées** et **justifiées**. Vous verrez que le problème
n'est presque jamais la vitesse à laquelle on code.

## Rappels

| Terme | Définition |
|---|---|
| **Temps de traitement** (PT, *process time*) | Temps où quelqu'un travaille **effectivement** sur l'élément |
| **Temps d'attente** | Temps où l'élément attend (file, disponibilité de quelqu'un, fenêtre de mise en ligne) |
| ***Lead time*** (LT) | Temps total entre la demande et la mise en production = Σ PT + Σ attentes |
| **Efficacité du flux** | Σ PT ÷ LT, en % |
| **%C/A** (*complete & accurate*) | Part des éléments reçus par une étape **sans** devoir être renvoyés en arrière |

**Convention de l'exercice** : on compte en **heures ouvrées**, avec **1 jour ouvré = 7 h** (une semaine = 5 jours
ouvrés = 35 h). Les week-ends ne comptent pas.

## Le matériau : entretien avec Julien

Le formateur a demandé à Julien de raconter le parcours de la page « Plateau de fromages », de l'idée du patron jusqu'à
la mise en ligne. Voici ses réponses, dans l'ordre.

> « Tout a commencé à la machine à café : le patron m'a expliqué son idée de plateaux composés. Je l'ai notée dans mon
> carnet, ça m'a pris une demi-heure avec les questions.
>
> On trie les demandes en réunion, une fois par mois. Là, la réunion avait lieu **dix jours ouvrés** plus tard. Pendant la
> réunion, on a passé environ **une heure** sur le sujet : décider, rédiger une petite fiche pour Sofia.
>
> Sofia n'a pas pu commencer tout de suite : elle finissait deux autres sujets. Elle s'y est mise **trois jours ouvrés**
> après la réunion. Le développement lui-même, si elle n'avait pas été interrompue, c'est **deux jours de travail**,
> donc 14 heures.
>
> Ensuite, elle m'a passé ses fichiers sur une clé USB pour que je relise. Je n'ai pas eu le temps avant **quatre jours
> ouvrés**. La relecture m'a pris **une heure**. En général, je renvoie une fois sur deux le travail pour corrections ;
> cette fois aussi.
>
> Sofia a repris ses corrections **le lendemain** (un jour ouvré d'attente) ; elles lui ont pris **trois heures**.
>
> Puis il fallait tester. Je teste sur mon poste, « en cliquant partout », quand j'ai un créneau : **deux jours ouvrés**
> plus tard. Le test m'a pris **deux heures**. Quand je teste, à peu près quatre fois sur dix je trouve quelque chose qui
> oblige à revenir en arrière ; là, rien vu (on sait maintenant pourquoi…).
>
> Et après, on attend le vendredi de mise en ligne. Là, il tombait **sept jours ouvrés** après mon test. La mise en ligne
> par FTP, avec la colonne à ajouter en base, c'est **une heure et demie**. »

## Consignes

### 1. Dessiner la carte (10 min)

Sur une feuille, de gauche à droite : le client (le patron), puis chaque **étape** dans une case (nom, qui, temps de
traitement, %C/A si connu), et entre deux cases un **triangle d'attente** avec sa durée. Sous la carte, tracez la
**ligne de temps** en créneaux : attentes en haut, traitements en bas (comme sur la slide « Exemple : corriger un bug
de TaskFlow »).

### 2. Calculer (7 min)

1. La somme des temps de traitement (en heures).
2. La somme des temps d'attente (en heures).
3. Le **lead time** en heures, en jours ouvrés et en semaines.
4. L'**efficacité du flux** (en %, une décimale).
5. Si Sofia codait **deux fois plus vite** (7 h au lieu de 14 h), de combien de % le lead time baisserait-il ?
6. Quelle est la **plus longue** attente ? Quel gaspillage Lean représente-t-elle ?

### 3. Proposer 3 améliorations (8 min)

Proposez **trois** changements. Pour chacun, indiquez :

| Amélioration | Étape(s) touchée(s) | Gaspillage Lean visé | Pratique / outil de la semaine | Nouveau temps estimé |
|---|---|---|---|---|
| | | | | |

Puis recalculez le **lead time** et l'**efficacité** de la carte **cible** (état futur) avec vos trois améliorations.

### 4. Justifier (5 min, restitution)

- Laquelle de vos améliorations a le **meilleur rapport gain / effort** ?
- Laquelle demande surtout un changement de **culture** ou d'**organisation** plutôt qu'un outil ?
- Quel **risque** introduit chacune (par exemple : déployer plus souvent sans tests) ?

## Résultat attendu

- Une carte lisible avec 7 étapes et 6 attentes.
- Lead time compris entre 200 et 220 h (vous devez trouver la valeur exacte), efficacité du flux autour de 10 %.
- Trois améliorations chiffrées et un état futur dont le lead time est au moins **divisé par 3**.

## Indices

<details>
<summary>Indice 1 — combien d'étapes ?</summary>

Sept étapes de traitement : prise de la demande, priorisation, développement, relecture, corrections, test, mise en
ligne. Six attentes entre elles. L'attente avant la prise de la demande n'existe pas (le patron parle directement à Julien).
</details>

<details>
<summary>Indice 2 — conversions</summary>

10 jours ouvrés = 70 h ; 3 j = 21 h ; 4 j = 28 h ; 1 j = 7 h ; 2 j = 14 h ; 7 j = 49 h.
</details>

<details>
<summary>Indice 3 — où chercher les améliorations</summary>

Regardez les **trois plus grosses attentes** : elles pèsent bien plus que tous les temps de traitement réunis. Pour
chacune, demandez-vous : « pourquoi faut-il attendre ? Une réunion mensuelle, une personne indisponible, une fenêtre de
mise en ligne ? ». Les réponses s'appellent Kanban et priorisation continue, revue de PR dans la journée, tests
automatiques en CI, déploiement automatisé.
</details>

## Pour aller plus loin

1. **Le coût de l'échec.** La mise en ligne échoue en moyenne **une fois sur deux** (estimation de Marc). Quand elle
   échoue : 6 h de restauration, 2 h de correction, puis la page attend la **fenêtre suivante**, un mois plus tard
   (20 jours ouvrés). Quel est le **lead time moyen attendu** de la fonctionnalité ? Quelle métrique DORA venez-vous
   d'estimer ?
2. **Le %C/A cumulé.** Avec 50 % de C/A à la relecture et 60 % au test, quelle part des fonctionnalités traverse ces
   deux étapes **du premier coup** ? Qu'en concluez-vous sur l'intérêt de tester **avant** la relecture ?

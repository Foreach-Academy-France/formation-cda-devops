# Exercice 1.1 — Classer des situations selon CALMS

| | |
|---|---|
| **Durée** | 10 min (consolidation, seul : en fin de bloc 1.1, pendant le TP si vous êtes en avance, ou le soir) |
| **Bloc** | 1.1 — CALMS ; 1.3 — DORA |
| **Prérequis** | partie A du TP 0 (La Fromagerie) |
| **Fichiers fournis** | aucun |

## Objectif

Reconnaître rapidement le pilier CALMS concerné par une situation réelle d'entreprise, et distinguer une **bonne
pratique** d'un **anti-pattern**. C'est le réflexe qu'on attend de vous en entretien ou devant le jury : « qu'est-ce qui
ne va pas dans cette équipe, et par quoi commenceriez-vous ? ».

## Consignes

Pour chacune des 12 situations ci-dessous, indiquez :

1. le pilier **principal** : **C**ulture, **A**utomatisation, **L**ean, **M**esure ou partage (**S**haring) ;
2. s'il s'agit d'une **bonne pratique** (+) ou d'un **anti-pattern** (−) ;
3. pour chaque anti-pattern, **une** pratique concrète qui le corrigerait.

| # | Situation |
|---|---|
| 1 | Après chaque incident, l'équipe publie un compte rendu sur le wiki : chronologie, causes, actions. Aucun nom n'y figure. |
| 2 | La mise en production suit une procédure Word de 14 pages ; seule Nadia sait l'exécuter sans erreur. |
| 3 | Le tableau de l'équipe a une colonne « En cours » limitée à 3 cartes ; quand elle est pleine, on aide à finir avant de commencer. |
| 4 | Le manager classe les développeurs selon le nombre de bugs qu'ils ont introduits, affiché chaque lundi. |
| 5 | Chaque PR déclenche lint, tests et build ; une PR rouge ne peut pas être fusionnée. |
| 6 | L'équipe ne sait pas dire combien de déploiements elle a faits le trimestre dernier, ni combien ont échoué. |
| 7 | Une fonctionnalité est développée sur une branche pendant six semaines, puis fusionnée en une fois juste avant la démo. |
| 8 | Les Ops sont invités aux refinements pour donner leur avis sur la supervision et les sauvegardes des nouvelles fonctionnalités. |
| 9 | La configuration des serveurs n'existe que sur les serveurs eux-mêmes ; chacun a été réglé à la main au fil des années. |
| 10 | Un tableau de bord affiche en continu le délai commit → production et le taux d'échec des changements des 30 derniers jours. |
| 11 | Chaque PR doit être relue par une personne qui n'a pas écrit le code ; les relecteurs tournent chaque semaine. |
| 12 | Une recette manuelle de deux semaines a lieu avant chaque version trimestrielle ; les corrections attendent la version suivante. |

## Résultat attendu

Un tableau de 12 lignes (pilier, +/−, correction). Il n'y a pas toujours **une seule** bonne réponse pour le pilier :
ce qui compte est votre **justification**.

## Indices

<details>
<summary>Indice 1 — Mesure ou Culture ?</summary>

Mesurer **pour s'améliorer** (un indicateur d'équipe, visible de tous, qui sert à décider) relève de la Mesure. Mesurer
**pour punir** (un classement nominatif) détruit la confiance : c'est d'abord un problème de **Culture**, et les gens
apprennent vite à cacher les bugs plutôt qu'à les éviter.
</details>

<details>
<summary>Indice 2 — Lean ou Automatisation ?</summary>

Demandez-vous si le problème principal est la **taille du lot / l'attente** (Lean) ou le **geste manuel répétitif**
(Automatisation). Une recette manuelle de deux semaines est les deux à la fois : quel est le pire, le geste manuel ou les
trois mois de travail qui attendent derrière ?
</details>

## Question de réflexion

Reprenez les anti-patterns : lesquels peut-on corriger **sans acheter ni installer aucun outil** ? Qu'en concluez-vous
sur la phrase « culture avant outils » ?

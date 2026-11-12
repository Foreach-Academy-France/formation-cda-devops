# Exercice 4.3 — Lire un plan avant de l'appliquer

| | |
|---|---|
| **Durée** | 10 min |
| **Bloc** | 5.2 — symboles du plan, remplacement, perte de données |
| **Fichier fourni** | [`plans/plan-pr-57.txt`](plans/plan-pr-57.txt) : le plan publié par `iac.yml` sur une PR du staging de TaskFlow |

## Le scénario

Vous êtes relecteur de la PR #57 « chore(infra): staging en 1.4, port 8082, renommage du volume ». Le code a l'air
propre. Le job `iac-plan` a publié ce plan en commentaire. Vous ne lisez **que** le plan.

## Questions

1. Combien de ressources sont créées, modifiées, détruites ? Où le lit-on en une seconde ?
2. Faites le tableau : ressource, symbole (`~` ou `-/+`), **cause** (l'attribut marqué `# forces replacement`).
3. Lesquelles de ces actions provoquent une **coupure de service** du staging ? Pendant combien de temps environ ?
4. Laquelle provoque une **perte de données** ? Expliquez la chaîne : quel attribut, quelle ressource détruite, ce que
   contiendra la nouvelle base.
5. La modification de `restart` sur l'API aurait-elle seule déclenché un remplacement ? Comment le savoir dans le plan ?
6. Rédigez votre **commentaire de revue** (5 lignes max) : approuvez-vous ? Que demandez-vous à l'auteur ?
7. Proposez **deux** façons de renommer le volume sans perdre les données.

## Résultat attendu

Un avis de relecteur argumenté. Corrigé dans [`solutions.md`](solutions.md).

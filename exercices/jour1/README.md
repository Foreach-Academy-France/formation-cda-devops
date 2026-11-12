# Jour 1 — Exercices : culture DevOps, Lean et Git

Exercices qui complètent les blocs de la matinée et le TP 1 de l'après-midi. Les exercices 1.1, 1.3 et 1.4 se font
**seul** ; l'exercice 1.2 (VSM) est l'**exercice 2** de la matinée, en groupe.

| # | Exercice | Durée | Bloc | Quand | Fichiers fournis |
|---|---|---|---|---|---|
| 1.1 | [Classer des situations selon CALMS](01-classement-calms.md) | 10 min | 1.1, 1.3 | Consolidation (fin de bloc, TP en avance, ou le soir) | — |
| 1.2 | [*Value stream mapping* de La Fromagerie](02-value-stream-mapping.md) | 30 min | 1.2 | **Exercice 2 de la matinée** (groupes) | — |
| 1.3 | [Lire un historique Git](03-lire-historique.md) | 15 min | 2.1 | Pendant le TP 1 si vous êtes en avance, ou le soir | [`historique.txt`](historique.txt), [`creer-historique.sh`](creer-historique.sh) |
| 1.4 | [Réparer ses erreurs : `restore`, `reset`, `revert`, `reflog`](04-reparer-ses-erreurs.md) | 25 min | 2.1 | Le soir (fortement conseillé avant le J2) | [`reparer-setup.sh`](reparer-setup.sh) |

Les exercices 1 et 3 de la matinée sont les deux parties du [TP 0](../../tp/tp0-cartographie-pipeline/README.md)
(diagnostic CALMS de La Fromagerie, pipeline cible de TaskFlow).

**Corrigé :** [`solutions.md`](solutions.md) — à ouvrir après avoir cherché.

## Avant de commencer

- Les scripts `.sh` créent des dépôts **jetables** dans le dossier temporaire du système (`/tmp`) : vous pouvez tout
  casser sans risque. Ils affichent le chemin créé et la commande pour le supprimer.
- Lancez-les avec `bash nom-du-script.sh` depuis ce dossier. Sous Windows : dans Ubuntu (WSL2).
- Conseillé pour toute la semaine : `git config --global merge.conflictStyle zdiff3` et
  `git config --global alias.lg "log --oneline --graph --all --decorate"`.

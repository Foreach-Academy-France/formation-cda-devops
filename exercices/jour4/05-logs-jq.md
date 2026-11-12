# Exercice 4.5 — Analyser des logs JSON avec `jq`

| | |
|---|---|
| **Durée** | 20 min |
| **Bloc** | 6.1 — logs structurés ; utilisé aussi dans l'étape 4 du TP (partie C) |
| **Fichier fourni** | [`logs/api.log`](logs/api.log) : 2 heures de logs de l'API TaskFlow en production (1 815 lignes, heures en UTC) |

## Le scénario

L'alerte `TaskFlowHighLatency` s'est déclenchée puis résolue toute seule. Pas de redéploiement, pas d'intervention.
Le responsable demande : « Que s'est-il passé, quand, et qui a été touché ? » Vous n'avez que les logs de l'API :
une ligne JSON par requête (`method`, `path`, `status`, `ms`) et une ligne par erreur (`level`, `message`).

## Questions

Pour chaque question, notez **la commande** et **la réponse**.

1. **Volume** : combien de lignes ? Combien de requêtes HTTP (lignes avec un champ `status`) ?
2. **Codes HTTP** : répartition des `status` (combien de 200, 201, 404, 500...).
3. **Top des routes** : les routes les plus appelées, **avec les identifiants remplacés par `:id`**
   (`/api/tasks/42/toggle` → `/api/tasks/:id/toggle`). Indice : `sub("/[0-9]+"; "/:id")`.
4. **Erreurs serveur** : combien de 5xx ? Sur quelles routes ? À quelle heure la première et la dernière ?
5. **Messages d'erreur** : quels messages apparaissent dans les lignes `"level":"error"` ? Que suggèrent-ils ?
6. **Latence** sur `/api/tasks*` : moyenne, médiane (p50), p95 et maximum sur tout le fichier. Pourquoi la moyenne est-elle
   trompeuse ici ?
7. **Comparaison** : p95 pendant la fenêtre d'incident et en dehors.
8. **Les 404** : d'où viennent-ils ? Est-ce un problème pour l'incident ? Pour la sécurité ?
9. Rédigez **3 lignes** pour le responsable : quoi, quand (heure de Paris = UTC + 2 à cette période), combien de requêtes
   touchées.

## Aide-mémoire

```bash
jq -c 'select(.status >= 500)' api.log            # filtrer (une ligne JSON par résultat)
jq -r '.path' api.log | sort | uniq -c | sort -rn  # compter les valeurs d'un champ
jq -s 'map(.ms) | add / length' api.log            # -s : tout le fichier dans un tableau
jq -r '.time[11:16]' api.log                        # extraire hh:mm d'un horodatage ISO
```

Les lignes sans `ms` (démarrage, erreurs) font échouer certains calculs : filtrez-les (`select(.ms)`).

## Bonus

- Nombre de 5xx **par minute** pendant l'incident : le phénomène s'aggrave-t-il ou se résorbe-t-il ?
- Écrivez la requête **PromQL** qui aurait donné la réponse 6 sans lire un seul log (et dites ce qu'elle ne vous aurait
  pas donné).

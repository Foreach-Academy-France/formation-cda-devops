# Exercice 4.2 — Provoquer et corriger une dérive

| | |
|---|---|
| **Durée** | 15 min |
| **Bloc** | 5.2 — state, refresh, dérive (*drift*) |
| **Prérequis** | l'exercice 4.1 appliqué (conteneur `exercice-nginx` en marche) |

## Le scénario

Un collègue « fait du ménage » sur le serveur, directement en ligne de commande, sans passer par le code. Votre
travail : voir ce que l'outil en pense, et décider qui a raison.

## Étapes

1. **Suppression manuelle** : `docker rm -f exercice-nginx`, puis `tofu plan`. Quelle ligne du plan décrit la situation ?
   Quelle étape (au début de la sortie) a permis de s'en rendre compte ?
2. `tofu apply` : le conteneur revient. `curl http://localhost:8090`.
3. **Modification manuelle « invisible »** : `docker exec exercice-nginx sh -c 'echo pirate > /usr/share/nginx/html/index.html'`,
   puis `tofu plan`. Tofu voit-il la différence ? Pourquoi ?
4. **Arrêt manuel** : `docker stop exercice-nginx`, puis `tofu plan`. Que propose-t-il ?
5. **La dérive voulue** : votre collègue avait une bonne raison de changer le port en 8095 « à chaud ». Que faut-il faire
   pour que ce changement survive au prochain `apply` ?
6. Faites `tofu plan -detailed-exitcode ; echo "code=$?"` avec et sans dérive. À quoi peut servir ce code dans un pipeline ?
7. Nettoyez : `tofu destroy`. Vérifiez avec `docker ps -a` et `tofu state list`.

## Résultat attendu

Vous savez expliquer ce que Tofu **voit** (les attributs du conteneur relus pendant le *refresh*) et ce qu'il **ne voit
pas** (le contenu des fichiers dans le conteneur), et pourquoi la seule façon durable de modifier l'infrastructure est de
modifier le code.

## Indices

<details>
<summary>Indice — ce que contient le state</summary>

`tofu state show docker_container.web` : la liste exacte des attributs suivis. Le contenu de `index.html` après la
création n'en fait pas partie. Le conteneur arrêté, lui, change l'attribut `must_run`.
</details>

## Questions de justification

1. Une dérive est détectée en production un soir, juste avant de partir. Faut-il lancer `apply` tout de suite ? Qu'est-ce qui vous
   ferait hésiter ?
2. Quelle règle d'équipe empêche la dérive au lieu de la corriger après coup ?

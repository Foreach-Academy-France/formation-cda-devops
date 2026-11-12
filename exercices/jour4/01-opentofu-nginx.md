# Exercice 4.1 — Un Nginx en code avec OpenTofu

| | |
|---|---|
| **Durée** | 20 min |
| **Bloc** | 5.2 — providers, ressources, variables, outputs, cycle `init` / `plan` / `apply` / `destroy` |
| **Fichier fourni** | [`opentofu-nginx/main.tf`](opentofu-nginx/main.tf) : squelette avec des `TODO` |

## Objectif

Décrire en code un conteneur Nginx qui sert une page d'accueil personnalisée, le créer, le modifier, puis le détruire,
en lisant le plan à chaque étape.

## Contraintes

- Trois variables : `nom` (défaut `exercice-nginx`), `port` (défaut **8090**, refusé hors de 1024-65535 grâce à un bloc
  `validation`), `message` (le texte de la page).
- L'image est une ressource `docker_image` (`docker.io/library/nginx:1.27-alpine`) ; le conteneur la **référence**
  (`docker_image.nginx.image_id`) au lieu de répéter son nom.
- La page `/usr/share/nginx/html/index.html` est déposée par le bloc `upload` du conteneur (pas de bind mount).
- Un output `url`.
- `tofu fmt -check` et `tofu validate` passent.

## Étapes

1. `cp -r opentofu-nginx ~/ex-tofu && cd ~/ex-tofu`, complétez les `TODO`.
2. `tofu init` : qu'est-ce qui apparaît dans le dossier ? Ouvrez `.terraform.lock.hcl`.
3. `tofu plan`, puis `tofu apply`. Vérifiez : `curl http://localhost:8090` et `tofu output -raw url`.
4. Relancez `tofu apply` : que dit-il ? Pourquoi ?
5. `tofu plan -var port=80` : que se passe-t-il, et à quel moment (avant ou après avoir contacté Docker) ?
6. `tofu apply -var 'message=Version 2'` : lisez le plan. Le conteneur est-il **modifié** ou **remplacé** ?
7. `tofu state list` puis `tofu state show docker_container.web` : repérez l'identifiant du conteneur et comparez avec
   `docker ps`.
8. Gardez l'infrastructure pour l'exercice 4.2 (sinon : `tofu destroy`).

## Résultat attendu

La page affiche votre message sur `http://localhost:8090` ; un deuxième `apply` répond `No changes` ; le port 80 est
refusé par la validation ; changer le message **remplace** le conteneur.

## Indices

<details>
<summary>Indice 1 — le bloc ports et le bloc upload</summary>

```hcl
ports {
  internal = 80
  external = var.port
}
upload {
  file    = "/usr/share/nginx/html/index.html"
  content = "<h1>${var.message}</h1>\n"
}
```
</details>

<details>
<summary>Indice 2 — « Error: Cannot connect to the Docker daemon »</summary>

Le provider cherche `/var/run/docker.sock`. Docker est-il démarré (`docker info`) ? Avec Podman, exportez `DOCKER_HOST`
(voir le README du jour).
</details>

## Questions de justification

1. Pourquoi référencer `docker_image.nginx.image_id` plutôt qu'écrire le nom de l'image dans le conteneur ? (deux raisons)
2. Changer le message impose un **remplacement**. Sur un vrai service, quel est le coût ? Comment l'éviter ?
3. Le fichier `.terraform.lock.hcl` : dans Git ou pas ? Et `terraform.tfstate` ?

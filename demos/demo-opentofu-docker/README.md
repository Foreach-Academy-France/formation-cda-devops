# Démo — OpenTofu et le provider Docker

| | |
|---|---|
| **Jour / bloc** | J4 matin — Bloc 5.2 « OpenTofu / Terraform » |
| **Durée** | 15 min |
| **Prérequis** | `tofu` ≥ 1.6, Docker (ou Podman avec `DOCKER_HOST`), port **8091** libre (`TF_VAR_port`), image `nginx:1.27-alpine` pré-téléchargée, accès à `registry.opentofu.org` (téléchargement du provider au `init`) |
| **Ce qu'on montre** | `init` (provider, lock file), `fmt` / `validate` / `plan` / `apply`, idempotence, `output`, **state** (`state list` / `state show`), **dérive** corrigée, **remplacement** (`forces replacement`), `destroy` |

## Contenu

| Fichier | Rôle |
|---|---|
| `main.tf` | un `docker_image` + un `docker_container` Nginx (port `var.port`, page `var.message` déposée par `upload`), un output `url` |
| `demo.sh` | le déroulé ci-dessous, rejouable ; travaille dans un dossier temporaire et détruit tout à la fin (même après Ctrl+C) |

## Lancer

```bash
bash demos/demo-opentofu-docker/demo.sh
DEMO_AUTO=1 bash demos/demo-opentofu-docker/demo.sh      # test sans pause avant le cours
TF_VAR_port=8099 bash demos/demo-opentofu-docker/demo.sh # si 8091 est pris
# Podman : export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock DOCKER=podman
```

## Déroulé minuté

| Min | Étape | Dire | Question à poser à la salle |
|---|---|---|---|
| 0-2 | 1. Le code | Un provider, deux ressources, une référence (`docker_image.nginx.image_id`) qui fixe l'ordre | « Dans quel ordre Tofu va-t-il créer les deux ressources ? » |
| 2-4 | 2. `init` | `.terraform/` (binaire du provider, hors Git) et `.terraform.lock.hcl` (dans Git) | « À quel fichier Node ressemble le lock file ? » |
| 4-6 | 3. `plan` | Lire les `+`, la ligne `Plan:` | « Si je lance `apply` deux fois, que se passe-t-il ? » |
| 6-8 | 4. `apply` | Page servie ; second `apply` = `No changes` (déclaratif) | — |
| 8-10 | 5. State | Même identifiant que `docker ps` ; c'est **la** mémoire de l'outil ; il contiendrait aussi des secrets | « Pourquoi ce fichier ne va-t-il jamais dans Git ? » |
| 10-12 | 6. Dérive | `docker rm -f` à la main → le *refresh* le voit → `apply` remet le réel au code | « Et si la suppression était voulue ? » (→ modifier le code) |
| 12-14 | 7. Remplacement | Changer le message = `-/+` (`upload # forces replacement`) | « Quel impact sur un vrai service ? Comment l'éviter ? » |
| 14-15 | 8. `destroy` | Tout ce que le code gère disparaît ; l'image reste (`keep_locally`) | — |

## Points de vigilance

- **Podman** : le plan affiche en plus `pid_mode` et `ulimit # forces replacement` (attributs que Podman renvoie et pas
  Docker Engine). Le dire si ça apparaît : ce n'est pas le code, c'est le daemon.
- Le premier `init` télécharge ~30 Mo : le faire une fois la veille (le cache de plugins ne sert pas, le dossier est
  temporaire) ou exporter `TF_PLUGIN_CACHE_DIR=$HOME/.terraform.d/plugin-cache`.
- Lien avec le TP : le staging de TaskFlow (`infra/`) est la même chose avec 9 ressources, un `random_password` et un
  `import`.

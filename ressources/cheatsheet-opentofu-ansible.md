# Cheatsheet OpenTofu (Terraform) et Ansible

> **OpenTofu / Terraform** *crée* des ressources (déclaratif + **state**). **Ansible** *configure* des machines
> (tâches idempotentes, sans state). Les commandes `tofu` et `terraform` sont identiques : remplacez l'une par l'autre.

## OpenTofu : le cycle

| Commande | Effet |
|---|---|
| `tofu init` | Télécharge les providers (`.terraform/`), crée/vérifie `.terraform.lock.hcl`, prépare le backend |
| `tofu init -backend-config="path=$STAGING_DIR/terraform.tfstate"` | Backend `local` dont le chemin n'est pas écrit dans le code (TP) |
| `tofu init -backend=false` | Sans backend : pour `validate` dans le CI |
| `tofu init -upgrade` | Monte les providers dans les contraintes de version, met à jour le lock file |
| `tofu providers lock -platform=linux_amd64 -platform=darwin_arm64 ...` | Empreintes du lock file pour plusieurs OS (binômes sur macOS, runner Linux) |
| `tofu fmt` / `tofu fmt -check -recursive -diff` | Formate / vérifie le formatage (CI) |
| `tofu validate` | Syntaxe, types, références ; ne contacte rien |
| `tofu plan` | Affiche les actions (refresh du réel + comparaison au code) |
| `tofu plan -out=tfplan` puis `tofu apply tfplan` | Appliquer **exactement** le plan relu (CI) ; `tfplan` contient des secrets en clair |
| `tofu plan -detailed-exitcode` | Code 0 = rien, 2 = changements, 1 = erreur (détection de dérive) |
| `tofu apply` / `tofu apply -auto-approve` | Applique (après confirmation / sans) |
| `tofu destroy` | Supprime tout ce que le code gère |
| `tofu output` / `tofu output -raw url` | Lire les outputs (scripts, smoke tests) |

## Variables

| Façon de fournir | Exemple | Usage |
|---|---|---|
| `default` dans `variable {}` | `default = 8081` | valeur raisonnable |
| `terraform.tfvars` (hors Git si secrets) | `front_port = 8085` | poste de dev |
| Variable d'environnement | `export TF_VAR_image_tag=a1b2c3d` | **CI** |
| Ligne de commande | `-var image_tag=a1b2c3d` | ponctuel |

`sensitive = true` masque la valeur dans le plan et les logs (pas dans le state). `validation { condition, error_message }`
refuse une valeur avant tout appel d'API.

## Lire un plan

| Symbole | Action | À surveiller |
|---|---|---|
| `+` | création | — |
| `~` | modification en place | — |
| `-/+` | remplacement (`# forces replacement` désigne l'attribut responsable) | coupure de service |
| `-` | destruction | **perte de données** si volume / base |
| `<=` | lecture d'une data source | — |

Lire d'abord la ligne `Plan: X to add, Y to change, Z to destroy.`

## State

| Commande | Effet |
|---|---|
| `tofu state list` | Ressources suivies |
| `tofu state show docker_container.api` | Attributs connus d'une ressource |
| `tofu import docker_volume.pgdata taskflow-staging-pgdata` | Adopter un objet existant sans le recréer |
| `tofu state rm docker_volume.pgdata` | Arrêter de gérer (l'objet réel reste) |
| `tofu state mv docker_container.a docker_container.b` | Renommer dans le code sans recréer (ou bloc `moved {}`) |
| `tofu force-unlock <ID>` | Lever un verrou orphelin (job tué) ; jamais pendant un apply en cours |
| `tofu apply -lock-timeout=120s` | Attendre le verrou au lieu d'échouer |

**Dans Git** : `*.tf`, `.terraform.lock.hcl`, `*.tfvars.example`. **Jamais** : `*.tfstate*`, `.terraform/`,
`terraform.tfvars` (secrets), `tfplan`.

## Méta-arguments utiles

```hcl
resource "docker_volume" "pgdata" {
  name = "taskflow-staging-pgdata"
  lifecycle {
    prevent_destroy       = true            # tout plan qui le détruit échoue
    ignore_changes        = [labels]        # ne pas « corriger » cet attribut
    create_before_destroy = true            # remplacer sans trou (si les noms le permettent)
  }
}
resource "docker_container" "api" {
  depends_on = [docker_container.db]        # dépendance non visible dans les références
  count      = var.enabled ? 1 : 0          # 0 ou N exemplaires ; for_each = map/set
}
```

## Provider Docker (kreuzwerker/docker)

| Besoin | Syntaxe |
|---|---|
| Daemon distant / Podman | `DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock` ou `provider "docker" { host = "ssh://user@srv" }` |
| Registre privé | bloc `registry_auth { address = "ghcr.io", username, password }` dans le provider |
| Nom DNS sur le réseau | `networks_advanced { name = docker_network.this.id, aliases = ["api"] }` |
| Attendre *healthy* | `healthcheck { ... }` + `wait = true` |
| Port publié | `ports { internal = 80, external = 8081 }` |
| Fichier déposé | `upload { file = "/chemin", content = "..." }` |

## Ansible

| Commande | Effet |
|---|---|
| `ansible -i inventory.ini all -m ping` | Tester la connexion aux machines |
| `ansible-playbook -i inventory.ini site.yml` | Exécuter un playbook |
| `... --check --diff` | Simulation avec différences (l'équivalent d'un plan) |
| `... -e app_version=1.1.0` | Surcharger une variable |
| `... --limit web1` / `--tags env` | Restreindre aux machines / aux tâches taguées |
| `... -v` / `-vvv` | Plus de détails |
| `ansible-inventory -i inventory.ini --graph` | Voir les groupes |
| `ansible-doc ansible.builtin.template` | Documentation d'un module |
| `ansible-lint site.yml` | Bonnes pratiques |

```ini
# inventory.ini
[local]
localhost ansible_connection=local
[web]
web1 ansible_host=203.0.113.10 ansible_user=deploy
```

| Module | Usage idempotent |
|---|---|
| `file` | `state: directory`, `mode: "0750"`, `state: absent` |
| `copy` / `template` | fichier depuis le dépôt / depuis un modèle Jinja2 (`{{ var }}`, `{% if %}`, filtres `\| lower`, `\| default()`) |
| `lineinfile` | une ligne précise dans un fichier |
| `apt` / `package`, `service` / `systemd`, `user` | paquets, services, comptes |
| `command` / `shell` | **toujours `changed`** : ajouter `creates:`, `removes:` ou `changed_when:` |
| `assert` | vérifier des préconditions |
| `debug` | afficher un message |

**Handlers** : une tâche `notify: Nom` déclenche le handler `Nom` **une fois**, **à la fin** du play, **seulement si**
elle a été `changed`. **Idempotence** : un deuxième passage doit afficher `changed=0`.

**Secrets** : `ansible-vault encrypt_string 'valeur' --name db_password`, puis `--ask-vault-pass` ou
`--vault-password-file` (CI) ; `lookup('ansible.builtin.password', 'fichier', length=32)` génère et mémorise ;
`lookup('ansible.builtin.env', 'DB_PASSWORD')` lit l'environnement.

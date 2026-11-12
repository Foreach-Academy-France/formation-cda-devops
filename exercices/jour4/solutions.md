# Jour 4 — Corrigé des exercices

> À ouvrir **après** avoir cherché. Tous les codes ci-dessous ont été exécutés (OpenTofu 1.13, provider
> `kreuzwerker/docker` 3.9, Ansible 2.21, jq 1.8).

---

## Exercice 4.1 — Un Nginx en code

```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.6"
    }
  }
}

provider "docker" {}

variable "nom" {
  description = "Nom du conteneur."
  type        = string
  default     = "exercice-nginx"
}

variable "port" {
  description = "Port publié sur le poste."
  type        = number
  default     = 8090

  validation {
    condition     = var.port >= 1024 && var.port <= 65535
    error_message = "Le port doit être compris entre 1024 et 65535."
  }
}

variable "message" {
  description = "Texte affiché par la page d'accueil."
  type        = string
  default     = "Bonjour depuis OpenTofu"
}

resource "docker_image" "nginx" {
  name         = "docker.io/library/nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "web" {
  name  = var.nom
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.port
  }

  upload {
    file    = "/usr/share/nginx/html/index.html"
    content = "<h1>${var.message}</h1>\n"
  }
}

output "url" {
  description = "Adresse de la page."
  value       = "http://localhost:${var.port}"
}
```

**Réponses aux étapes**

2. `init` crée `.terraform/` (le binaire du provider, ~30 Mo) et `.terraform.lock.hcl` (version exacte + empreintes).
4. `No changes. Your infrastructure matches the configuration.` : l'outil est déclaratif, l'état voulu est atteint.
5. `Error: Invalid value for variable ... Le port doit être compris entre 1024 et 65535.` **avant** tout appel à Docker :
   la validation est évaluée pendant le plan, au chargement des variables.
6. `# docker_container.web must be replaced` ; `upload { # forces replacement }`. Le provider ne sait pas modifier un
   fichier dans un conteneur existant : il le détruit et le recrée (`Plan: 1 to add, 0 to change, 1 to destroy`).
7. `tofu state show` affiche `id = "dcf05b0d2236..."`, le même que la colonne `CONTAINER ID` de `docker ps`.

**Questions de justification**

1. (a) La référence crée une **dépendance implicite** : l'image est tirée **avant** la création du conteneur. (b) Le
   conteneur utilise l'**identifiant** de l'image (`sha256:...`) : si le tag pointe vers une nouvelle image, le plan le
   montre (remplacement). Bonus : pas de duplication du nom.
2. Une coupure (destruction puis création). Pour l'éviter : `lifecycle { create_before_destroy = true }` (impossible ici
   à cause du nom et du port uniques), ou plusieurs instances derrière un load balancer, ou un contenu servi depuis un
   volume ou une image (le contenu change sans toucher au conteneur).
3. Le lock file **dans Git** (reproductibilité des providers, comme `package-lock.json`) ; le state **jamais** (secrets,
   conflits ; il vit dans un backend).

---

## Exercice 4.2 — Dérive

1. `# docker_container.web will be created` / `Plan: 1 to add`. C'est le **refresh** (`Refreshing state...`) qui a relu
   l'état réel : le conteneur du state n'existe plus.
2. `apply` le recrée : le réel est ramené au code.
3. **Non** : Tofu ne suit que les attributs du conteneur (image, ports, nom, env...). Le contenu d'un fichier modifié
   **après** la création n'est pas dans le state. La dérive « à l'intérieur » est invisible : c'est un argument pour les
   conteneurs **immuables** (on ne modifie pas, on remplace) et pour une sonde qui vérifie le contenu (blackbox).
4. Il propose de le **remplacer** (ou de le redémarrer selon la version du provider) : l'attribut `must_run = true`
   (défaut) n'est plus respecté.
5. Reporter le changement **dans le code** (`port = 8095`, par PR), sinon le prochain `apply` remet 8090. Le code est la
   source de vérité.
6. `0` = aucun changement, `2` = changements, `1` = erreur. Dans un job planifié, `2` signale une dérive : on fait
   échouer le job pour être notifié (c'est le `schedule` de `iac.yml`).
7. `docker ps -a` ne montre plus `exercice-nginx` ; `tofu state list` est vide (l'image reste en cache : `keep_locally`).

**Justification**

1. Pas forcément : la dérive est peut-être **une correction d'urgence** faite à la main par quelqu'un d'astreinte.
   Appliquer l'écraserait. On cherche d'abord **qui** et **pourquoi** (journal, canal d'équipe), puis on choisit : remettre
   le code, ou reporter la correction dans le code.
2. « Aucune modification manuelle de l'infrastructure gérée par Tofu » + droits restreints (pas d'accès direct en
   écriture, seul le pipeline applique) + détection planifiée.

---

## Exercice 4.3 — Lire un plan

1. `Plan: 6 to add, 1 to change, 6 to destroy.` : la dernière ligne, à lire en premier.

2. | Ressource | Action | Cause |
   |---|---|---|
   | `docker_image.api`, `docker_image.front` | `-/+` | `name` (nouveau tag `9f3b2d1`) |
   | `docker_container.api` | `-/+` | `image` (conséquence de la nouvelle image) |
   | `docker_container.front` | `-/+` | `image` **et** `ports.external` 8081 → 8082 |
   | `docker_volume.pgdata` | `-/+` | `name` : `taskflow-staging-pgdata` → `taskflow-staging-data` |
   | `docker_container.db` | `-/+` | `volumes` (le volume référencé change) |
   | `docker_network.this` | `~` | ajout d'un label (sans coupure) |

3. Les trois conteneurs sont recréés : tout le staging est coupé pendant quelques dizaines de secondes (temps que la base
   redevienne *healthy*, puis l'API, puis le front). C'est normal pour un changement de version d'un staging ; le port
   change aussi, donc le smoke test et l'URL de l'environment `staging` doivent suivre (`vars.FRONT_PORT`).
4. Le **volume** est détruit et recréé sous un autre nom : la nouvelle base démarre **vide** (PostgreSQL réinitialise un
   volume vide), toutes les tâches du staging sont perdues. Le conteneur `db` est remplacé parce qu'il monte un autre
   volume.
5. Non : `restart` n'est pas marqué `# forces replacement` (le provider sait le modifier en place). Le remplacement de
   l'API vient de l'attribut `image`. Règle : seuls les attributs suivis de `# forces replacement` expliquent un `-/+`.
6. Exemple de commentaire :
   > Changement de version et de port OK. **Bloquant** : le renommage du volume détruit `taskflow-staging-pgdata`
   > (`-/+`, forces replacement), donc les données du staging. Si le nouveau nom n'apporte rien, garde l'ancien ;
   > sinon, migre les données d'abord. Peux-tu aussi séparer le changement de port dans une autre PR ? Je n'approuve
   > pas en l'état.
7. (a) **Ne pas renommer** (un nom de volume est un identifiant, pas une étiquette). (b) Créer le nouveau volume, copier
   les données (`pg_dump` / `pg_restore`, ou `docker run --rm -v ancien:/from -v nouveau:/to alpine cp -a /from/. /to/`),
   basculer, puis supprimer l'ancien dans une PR suivante. (c) Retirer l'ancien de la gestion (`tofu state rm`) puis
   importer le nouveau, si le volume a été renommé hors de Tofu. Et en prod : `lifecycle { prevent_destroy = true }`
   sur le volume, pour que ce plan **échoue** au lieu de détruire.

---

## Exercice 4.4 — Playbook Ansible

`preparer.yml` :

```yaml
- name: Préparer le dossier de déploiement de l'application
  hosts: local
  gather_facts: true
  vars:
    app_dir: "{{ ansible_env.HOME }}/exercice-ansible/app"
    app_version: "1.0.0"
    app_env: production
    app_port: 8090
    # Généré au 1er passage, mémorisé dans ce fichier (hors Git) : idempotent
    db_password: "{{ lookup('ansible.builtin.password', app_dir ~ '/../db-password.txt', chars=['ascii_letters', 'digits'], length=24) }}"

  tasks:
    - name: Créer les dossiers
      ansible.builtin.file:
        path: "{{ app_dir }}/{{ item }}"
        state: directory
        mode: "0750"
      loop: ["", releases, shared]

    - name: Écrire le fichier VERSION
      ansible.builtin.copy:
        content: "{{ app_version }}\n"
        dest: "{{ app_dir }}/VERSION"
        mode: "0644"

    - name: Rendre le .env depuis le modèle
      ansible.builtin.template:
        src: templates/env.j2
        dest: "{{ app_dir }}/shared/.env"
        mode: "0600"
      notify: Redémarrer l'application

    - name: Vérifier le contenu du .env
      ansible.builtin.lineinfile:
        path: "{{ app_dir }}/shared/.env"
        regexp: "^APP_ENV="
        line: "APP_ENV={{ app_env }}"
      check_mode: true # ne modifie rien : sert de vérification
      register: app_env_line
      failed_when: app_env_line is changed

  handlers:
    - name: Redémarrer l'application
      ansible.builtin.debug:
        msg: ".env modifié : redémarrer l'application (ici on ne fait que l'afficher)"
```

`templates/env.j2` :

```jinja
# Fichier généré par Ansible : ne pas modifier à la main (le prochain passage l'écraserait).
APP_ENV={{ app_env }}
APP_VERSION={{ app_version }}
PORT={{ app_port }}
DATABASE_URL=postgres://app:{{ db_password }}@db:5432/app
```

**Sorties observées**

```text
1er passage           localhost : ok=6  changed=3  ...   (+ RUNNING HANDLER [Redémarrer l'application])
2e passage            localhost : ok=5  changed=0  ...   (pas de handler)
-e app_version=1.1.0 --check --diff
                      -1.0.0 / +1.1.0 (VERSION) ; -APP_VERSION=1.0.0 / +APP_VERSION=1.1.0 (.env)
                      localhost : ok=6  changed=2        (simulation : rien n'est écrit)
```

6. Après `chmod 644`, le passage suivant affiche `changed` sur la tâche du template (le mode est remis à `0600`) et
   déclenche le handler : Ansible **corrige** la dérive de ce qu'il décrit.

**Justification**

1. Chaque module compare lui-même l'état voulu à l'état réel au moment de l'exécution (le fichier existe-t-il, avec ce
   contenu et ces droits ?). Sans state, Ansible ne sait pas ce qu'il a créé **hier** : retirer une tâche du playbook ne
   supprime pas le dossier (il faut une tâche `state: absent`), et il ne voit pas ce qui a été ajouté à côté.
2. Un script suffit pour une action ponctuelle, sur une machine, sans besoin de rejouer. Il devient mauvais dès qu'il
   faut le relancer sans risque (idempotence à coder soi-même : `mkdir -p`, tests partout), sur plusieurs machines, avec
   des modèles, une simulation (`--check`) et un rapport lisible.
3. `ansible-vault encrypt_string` (secret chiffré dans le dépôt, mot de passe du coffre fourni par
   `--vault-password-file` depuis un secret du CI), ou une variable d'environnement lue par
   `lookup('ansible.builtin.env', 'DB_PASSWORD')`, ou un gestionnaire de secrets (HashiCorp Vault / OpenBao).

---

## Exercice 4.5 — Logs avec `jq`

```bash
cd exercices/jour4/logs

# 1. Volume
wc -l api.log                                             # 1815
jq -s 'map(select(.status)) | length' api.log             # 1761 requêtes

# 2. Codes HTTP
jq -r 'select(.status) | .status' api.log | sort | uniq -c
#   1212 200 | 224 201 | 85 204 | 10 400 | 154 404 | 53 500 | 23 503

# 3. Top des routes (identifiants normalisés)
jq -r 'select(.path) | "\(.method) \(.path | sub("/[0-9]+"; "/:id"))"' api.log | sort | uniq -c | sort -rn | head
#   607 GET /api/tasks | 480 GET /health | 234 POST /api/tasks | 206 PATCH /api/tasks/:id/toggle
#    89 DELETE /api/tasks/:id | 30 GET /.git/config | 27 GET /server-status | 23 GET /.env ...

# 4. Erreurs serveur
jq -r 'select(.status >= 500) | "\(.status) \(.method) \(.path | sub("/[0-9]+"; "/:id"))"' api.log | sort | uniq -c | sort -rn
#   35 500 GET /api/tasks | 23 503 GET /health | 9 500 POST /api/tasks | 7 500 PATCH ... | 2 500 DELETE ...
jq -r 'select(.status >= 500) | .time' api.log | sed -n '1p;$p'
#   2026-10-22T09:12:00.000Z  et  2026-10-22T09:23:54.077Z   → 12 minutes

# 5. Messages d'erreur
jq -r 'select(.level == "error") | .message' api.log | sort | uniq -c
#   53 timeout exceeded when trying to connect

# 6. Latence sur /api/tasks*
jq -s '[.[] | select(.ms and (.path | startswith("/api/tasks"))) | .ms] | sort
       | {n: length, moyenne: (add / length | round), p50: .[length * 0.5 | floor],
          p95: .[length * 0.95 | floor], max: max}' api.log
#   n 1136, moyenne 291 ms, p50 13.6 ms, p95 2700 ms, max 4717 ms

# 7. Pendant / hors incident
jq -s '[.[] | select(.ms and (.path | startswith("/api/tasks")))]
       | group_by(.time[11:16] >= "09:12" and .time[11:16] < "09:24")
       | map({incident: (.[0].time[11:16] >= "09:12"), n: length, p95: (map(.ms) | sort | .[length * 0.95 | floor])})' api.log
#   hors incident : 1018 requêtes, p95 20.5 ms ; incident : 118 requêtes, p95 4618 ms (dont 53 en 500)

# 8. Les 404
jq -r 'select(.status == 404) | .path | sub("/[0-9]+"; "/:id")' api.log | sort | uniq -c | sort -rn
```

**Interprétation**

- 5. `timeout exceeded when trying to connect` est le message de `pg` quand **le pool de connexions** n'obtient pas de
  connexion à temps : la base est saturée ou injoignable. Les 503 de `/health` (qui fait un `SELECT 1`) le confirment.
- 6. La moyenne (291 ms) mélange 1 018 requêtes normales (~13 ms) et 118 requêtes lentes (jusqu'à 4,7 s) : elle ne
  décrit **aucune** requête réelle. La médiane dit « d'habitude c'est rapide », le p95 dit « certains ont attendu près de
  3 s ». C'est pourquoi on alerte sur un percentile.
- 8. 145 des 154 404 viennent de chemins qui n'existent pas dans TaskFlow (`/.env`, `/.git/config`, `/wp-login.php`...)
  entre 08:31 et 08:33 UTC : un **robot de scan** de vulnérabilités. Sans lien avec l'incident, mais intéressant pour la
  sécurité (J5) : il cherchait des secrets exposés. Les 9 autres sont des tâches déjà supprimées (normal). Dans les
  métriques, ces URL inconnues sont regroupées sous `route="unmatched"` (cardinalité).
- 9. Exemple : *« Entre 11h12 et 11h24 (heure de Paris), la base de données a saturé : 118 requêtes ont été servies
  lentement (p95 de 4,6 s au lieu de 20 ms), dont 53 en erreur (liste, création, modification de tâches). Le service est
  revenu à la normale sans intervention à 11h24 ; cause de la saturation à analyser côté base (requêtes lentes, pool). »*

**Bonus**

```bash
jq -r 'select(.status >= 500) | .time[11:16]' api.log | uniq -c
#   4 09:12 | 3 | 6 | 7 | 6 | 4 | 7 | 7 | 4 | 7 | 10 | 11 09:23  → ça s'aggravait jusqu'à la fin
```

```promql
histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{route=~"/api/tasks.*"}[5m])))
```

La métrique donne la tendance immédiatement et sans coût, mais **pas** le message d'erreur, ni les chemins exacts, ni
la requête individuelle : les métriques disent *que* ça va mal, les logs disent *pourquoi*.

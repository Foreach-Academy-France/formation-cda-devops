# Démo — Ansible en local

| | |
|---|---|
| **Jour / bloc** | J4 matin — Bloc 5.3 « Ansible » |
| **Durée** | 10 min |
| **Prérequis** | `ansible-playbook` ≥ 2.15, `openssl` |
| **Ce qu'on montre** | inventaire avec `ansible_connection=local`, playbook, modules `file` / `template` / `command`, boucle, **handler**, `changed` vs `ok`, **idempotence** (`changed=0`), `creates:`, `--check --diff`, dérive corrigée |

## Contenu

| Fichier | Rôle |
|---|---|
| `inventory.ini` | une seule machine : `localhost`, sans SSH |
| `playbook.yml` | crée un dossier de déploiement (`nginx/`, `certs/` en 0700, `backups/`), un `.env` en 0600 depuis un modèle, un certificat auto-signé une seule fois ; handler `Redéployer` |
| `templates/env.j2` | le modèle Jinja2 du `.env` (mot de passe généré au premier passage par `lookup('password')`, puis relu) |
| `demo.sh` | le déroulé, dans un dossier temporaire supprimé à la fin |

## Lancer

```bash
bash demos/demo-ansible-local/demo.sh
DEMO_AUTO=1 bash demos/demo-ansible-local/demo.sh   # test sans pause
```

## Déroulé minuté

| Min | Étape | Dire | Question à poser à la salle |
|---|---|---|---|
| 0-2 | 1. Fichiers | Inventaire, play, tâches = modules + paramètres ; Jinja2 | « Où est le mot de passe de la base ? » (nulle part en clair) |
| 2-4 | 2. 1er passage | Tout est `changed`, le handler s'exécute **à la fin** | — |
| 4-5 | 3. 2ᵉ passage | `changed=0`, pas de handler : **idempotence** ; `creates:` évite de régénérer le certificat | « Que se passerait-il sans `creates:` ? » |
| 5-7 | 4. `--check --diff` | Simulation : on voit le diff, rien n'est écrit (l'équivalent du `plan`) | — |
| 7-10 | 5. Dérive | `chmod 644 .env` → le passage suivant remet `0600` et déclenche le handler | « Différence avec la dérive vue par Tofu ? » (pas de state : Ansible ne voit que ce qu'il décrit) |

## Pour aller plus loin (oral)

- Sur de vraies machines : `[web]` / `[db]` dans l'inventaire, connexion SSH par clé, `become: true` pour `sudo`.
- Secrets : `ansible-vault encrypt_string`, `--vault-password-file` dans le CI.
- Rôles et collections (`ansible-galaxy`), `ansible-lint`.
- Le bonus de l'étape 3 du TP (`solution/ansible/`) prépare `~/taskflow-prod` avec le même principe.

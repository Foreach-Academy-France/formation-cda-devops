# Exercice 4.4 — Un playbook Ansible idempotent

| | |
|---|---|
| **Durée** | 30 min |
| **Bloc** | 5.3 — inventaire, playbook, modules, idempotence, handlers, Jinja2 |
| **Fichiers fournis** | [`ansible-depart/`](ansible-depart/) : `inventory.ini`, `preparer.yml` (à compléter), `templates/env.j2` |

## Objectif

Écrire un playbook qui prépare, **sur votre poste**, le dossier de déploiement d'une application, et prouver qu'il est
idempotent. C'est exactement ce que fait le bonus de l'étape 3 du TP pour `~/taskflow-prod`.

## Contraintes

Le playbook crée :

```
~/exercice-ansible/app/          (0750)
├── releases/                    (0750)
├── shared/                      (0750)
│   └── .env                     (0600, rendu depuis templates/env.j2)
└── VERSION                      (contenu : app_version)
```

- le `.env` contient `APP_ENV`, `APP_VERSION`, `PORT` et une `DATABASE_URL` avec un mot de passe **généré** au premier
  passage, puis **réutilisé** (aucun mot de passe en clair dans le playbook) ;
- un **handler** affiche « .env modifié : redémarrer l'application » quand, et seulement quand, le `.env` change ;
- uniquement des modules idempotents (`file`, `copy`, `template`...), pas de `shell: mkdir`.

## Étapes

1. `cp -r ansible-depart ~/ex-ansible && cd ~/ex-ansible`, complétez les `TODO`.
2. `ansible-playbook -i inventory.ini preparer.yml` : notez le `PLAY RECAP` (`ok`, `changed`).
3. Relancez : vous devez obtenir **`changed=0`** et le handler ne doit pas s'exécuter. **Montrez-le au formateur.**
4. `ansible-playbook -i inventory.ini preparer.yml -e app_version=1.1.0 --check --diff` : que montre-t-il ? Le fichier
   a-t-il été modifié ?
5. Appliquez réellement la version 1.1.0 : le handler se déclenche-t-il ?
6. Dérive : `chmod 644 ~/exercice-ansible/app/shared/.env`, relancez le playbook. Que se passe-t-il ?
7. Nettoyez : `rm -rf ~/exercice-ansible`.

## Indices

<details>
<summary>Indice 1 — une boucle sur les dossiers</summary>

```yaml
- name: Créer les dossiers
  ansible.builtin.file:
    path: "{{ app_dir }}/{{ item }}"
    state: directory
    mode: "0750"
  loop: ["", releases, shared]
```
</details>

<details>
<summary>Indice 2 — un mot de passe généré une seule fois</summary>

Le lookup `ansible.builtin.password` génère le mot de passe **et l'écrit dans un fichier** ; aux passages suivants, il
relit ce fichier. Mettez ce fichier hors du dépôt (par exemple à côté de `app/`).

```yaml
db_password: "{{ lookup('ansible.builtin.password', app_dir ~ '/../db-password.txt', chars=['ascii_letters', 'digits'], length=24) }}"
```
</details>

<details>
<summary>Indice 3 — « changed » à chaque passage ?</summary>

Un module `command`/`shell` est toujours `changed`. Un `template` qui contient une valeur aléatoire ou l'heure
(`{{ ansible_date_time }}`) aussi. Cherchez ce qui change entre deux passages avec `--diff`.
</details>

## Questions de justification

1. Pourquoi Ansible n'a-t-il pas besoin d'un state comme OpenTofu ? Qu'est-ce que cela l'empêche de faire ?
2. Quand un script bash suffirait-il ? Quand devient-il un mauvais choix ?
3. Comment fourniriez-vous un **vrai** secret (mot de passe de production imposé) sans l'écrire en clair dans le dépôt ?

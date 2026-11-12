# ansible/ : préparer la production (bonus du Jour 4)

`prepare-prod.yml` refait, de façon **idempotente**, les gestes manuels de la partie A de l'étape 2 : dossier
`~/taskflow-prod` (droits restreints), copie de `compose.prod.yaml`, des scripts et de la conf Nginx, `.env` rendu
depuis un modèle (0600), certificat auto-signé généré une seule fois.

```bash
cd ansible
ansible-playbook -i inventory.ini prepare-prod.yml -e ghcr_owner=<vous-en-minuscules> --check --diff   # simulation
ansible-playbook -i inventory.ini prepare-prod.yml -e ghcr_owner=<vous-en-minuscules>
ansible-playbook -i inventory.ini prepare-prod.yml -e ghcr_owner=<vous-en-minuscules>   # 2e passage : changed=0
```

| Variable | Défaut | Rôle |
|---|---|---|
| `prod_dir` | `~/taskflow-prod` | dossier de déploiement (`PROD_DIR` du runner) |
| `ghcr_owner` | obligatoire | propriétaire des images, en minuscules |
| `http_port` / `https_port` | 80 / 443 | ports du proxy (8082 / 8443 si 80/443 sont pris) |

- Le mot de passe PostgreSQL est généré au premier passage dans `~/.config/taskflow/postgres-password` (hors dépôt,
  0600). **Attention** : si `~/taskflow-prod` existe déjà avec un volume de base initialisé, reprenez l'ancien mot de
  passe (`grep POSTGRES_PASSWORD ~/taskflow-prod/.env > ...` puis écrivez-le dans ce fichier) avant le premier passage.
- Handlers : la conf Nginx modifiée recharge le proxy **s'il tourne** ; un `.env` modifié affiche un rappel de redéploiement
  (le playbook prépare, il ne déploie pas : c'est le rôle du pipeline).
- En entreprise : inventaire de vrais serveurs (SSH), secrets dans `ansible-vault` ou un coffre, et un rôle réutilisable.

# Exercice 3.3 — Le secret caché dans l'historique Git

| | |
|---|---|
| **Durée** | 30 min |
| **Bloc** | 7.1 — DevSecOps (1) : sécuriser le pipeline |
| **Prérequis** | Git ; Docker (pour gitleaks et, au besoin, `git filter-repo`) |
| **Fichiers fournis** | [`secret-historique-setup.sh`](secret-historique-setup.sh) |

## Contexte

Vous reprenez `notif-service`, un petit service écrit par une collègue partie en congé. Le dépôt va être rendu
**public**. Elle vous assure : « Pas de souci, j'ai supprimé le `.env` et tout passe par des variables
d'environnement maintenant. » Les fichiers actuels sont effectivement propres.

Votre mission avant la publication : **trouver** ce qui traîne dans l'historique, **réagir dans le bon ordre**, puis
**purger** l'historique et **empêcher** que cela se reproduise.

## Mise en place

```bash
mkdir -p ~/exercices-j3 && cd ~/exercices-j3
bash <chemin-du-cours>/exercices/jour3/secret-historique-setup.sh
cd notif-service
git log --oneline
grep -rn "ghp_\|hooks.slack" . --exclude-dir=.git      # rien : les fichiers actuels sont propres
```

(Les secrets sont factices, générés à chaque exécution.)

## Partie 1 — Détecter (10 min)

1. **À la main d'abord.** Avec les commandes Git que vous connaissez, trouvez les secrets **sans** outil dédié.
   Pistes : `git log --stat`, `git log -p`, `git log -S <chaîne>` (« pickaxe »), `git log --all --diff-filter=D --name-only`.
   Notez le commit d'introduction et le commit de « suppression » de chaque secret.
2. **Avec gitleaks**, sur tout l'historique :
   ```bash
   docker run --rm -v "$PWD":/repo docker.io/zricethezav/gitleaks:v8.30.1 git /repo -v --redact=40
   echo "code de sortie : $?"
   ```
   Combien de fuites ? Quelles règles (`RuleID`) ? Que vaut le code de sortie, et pourquoi est-ce important pour un CI ?
3. Vérifiez la ligne `N commits scanned` : si elle affiche `0`, gitleaks n'a **rien** lu (voir « Si ça ne marche pas »).

## Partie 2 — Réagir (5 min, à l'écrit)

Le dépôt a été poussé sur GitHub **il y a deux jours** (privé, mais 6 personnes y ont accès et un fork existe). Rangez
ces actions dans l'ordre où vous les feriez et justifiez la **première** :

- A. Réécrire l'historique pour supprimer les secrets, puis `git push --force`
- B. Révoquer le jeton GitHub et régénérer le webhook Slack
- C. Ajouter un hook pre-commit gitleaks et un scan gitleaks dans le CI
- D. Consulter les journaux d'audit (GitHub : *Settings > Security log* ; Slack : journaux d'accès) pour voir si les secrets ont été utilisés
- E. Prévenir les collaborateurs qu'ils doivent re-cloner
- F. Stocker les nouveaux secrets dans un gestionnaire de secrets / les secrets GitHub, jamais dans un fichier versionné

## Partie 3 — Purger (10 min)

Outil recommandé : **`git filter-repo`** (successeur officiel de `git filter-branch`). Installation au choix :
`sudo apt install git-filter-repo` · `brew install git-filter-repo` · `pipx install git-filter-repo`, ou sans rien
installer, dans un conteneur (voir plus bas).

1. Faites une **copie de sauvegarde** du dépôt (`cp -r notif-service notif-service.bak`) : la réécriture est irréversible.
2. Écrivez un fichier `../remplacements.txt` qui remplace le jeton et l'URL du webhook par `***REVOQUE***` (une ligne par
   motif, syntaxe `regex:<motif>==><remplacement>` ; lisez `git filter-repo --help`, section *--replace-text*).
3. En **une** commande : supprimez le fichier `.env` de tout l'historique (`--invert-paths --path .env`) et appliquez
   les remplacements (`--replace-text ../remplacements.txt`).
4. Vérifiez : gitleaks ne trouve plus rien ; `git log --oneline` : combien de commits reste-t-il, et pourquoi les SHA
   ont-ils **tous** changé (ou presque) ?

Sans installer `git filter-repo` :

```bash
docker run --rm -v "$PWD":/repo -v "$PWD/../remplacements.txt":/remplacements.txt:ro -w /repo \
  docker.io/library/python:3.13-alpine sh -c \
  "apk add -q --no-cache git && pip install -q --root-user-action=ignore git-filter-repo \
   && git filter-repo --force <vos options>"
```

Alternative : **BFG Repo-Cleaner** (Java) — `java -jar bfg.jar --delete-files .env --replace-text remplacements.txt`,
puis `git reflog expire --expire=now --all && git gc --prune=now --aggressive`.

## Partie 4 — Empêcher (5 min)

Dans le dépôt purgé, ajoutez un fichier `.env` contenant un faux jeton `ghp_` suivi de 36 caractères alphanumériques,
indexez-le (`git add -f .env`), puis vérifiez que gitleaks **bloque** :

```bash
docker run --rm -v "$PWD":/repo docker.io/zricethezav/gitleaks:v8.30.1 git /repo --pre-commit --staged -v
```

Dans TaskFlow, cet appel est automatisé par `.pre-commit-config.yaml` (TP étape 2).

## Si ça ne marche pas

- `0 commits scanned` / `no leaks found` alors que vous savez qu'il y en a : Git refuse de lire un dépôt appartenant à
  un autre utilisateur (« dubious ownership »). L'image gitleaks règle cela pour `root` ; si vous ajoutez
  `--user $(id -u)`, retirez-le. **Une absence d'alerte n'est une preuve que si l'outil a vraiment scanné.**
- `Refusing to destructively overwrite repo history since this does not look like a fresh clone` : `git filter-repo`
  protège les dépôts non fraîchement clonés. Vous avez fait la sauvegarde ? Ajoutez `--force`.
- Le remplacement ne s'applique pas : testez votre regex avec `git log -p | grep -E '<motif>'` ; dans `remplacements.txt`,
  pas d'espace autour de `==>`.

## Questions de justification

1. Pourquoi la **rotation** passe-t-elle avant la purge ? Que reste-t-il de compromis même après un `push --force` parfait ?
   (Pensez : forks, clones des collègues, caches, PR, CI qui a cloné le dépôt, robots qui scannent GitHub en continu.)
2. `git rm .env` + commit « supprime » le fichier. Expliquez avec le modèle objet de Git (blob, tree, commit) pourquoi
   le contenu est toujours là.
3. Un hook pre-commit suffit-il ? Pourquoi faut-il **aussi** le scan en CI et la *push protection* de GitHub ?

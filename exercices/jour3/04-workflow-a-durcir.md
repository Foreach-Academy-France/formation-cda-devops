# Exercice 3.4 (bonus) — Durcir un workflow GitHub Actions

| | |
|---|---|
| **Durée** | 15 min |
| **Bloc** | 7.1 — supply chain, permissions minimales, injection |
| **Fichier fourni** | [`workflow-a-durcir.yml`](workflow-a-durcir.yml) |

## Contexte

Une équipe veut une « prévisualisation » de chaque PR sur son runner self-hosted. Le workflow fourni fonctionne… et
offre le contrôle du runner (donc de la machine qui porte la prod) à **n'importe qui** capable d'ouvrir une PR.

## Consigne

1. Listez **au moins 7 problèmes**. Pour chacun : la ligne, le risque concret (qui peut faire quoi), la correction.
2. Proposez une version corrigée. Contraintes : la prévisualisation doit rester possible pour les PR **internes** ;
   aucun secret ne doit être accessible au code d'une PR venant d'un fork.
3. Vérifiez votre version avec actionlint :
   ```bash
   docker run --rm -v "$PWD":/repo -w /repo docker.io/rhysd/actionlint:latest -no-color workflow-corrige.yml
   ```

## Pour aller plus loin

- `zizmor` (analyseur de sécurité des workflows) : `pipx run zizmor workflow-a-durcir.yml`
- Lisez l'incident `aquasecurity/trivy-action` (slides du bloc 7.1) : quelle ligne de ce workflow aurait exposé
  `DEPLOY_TOKEN` de la même façon ?

#!/bin/sh
# Enveloppe du client docker (démo uniquement).
# PODMAN_COMPAT=1 : l'API de compatibilité de Podman applique une limite de
# processus nulle aux conteneurs créés par le client Docker (« can't fork ») ;
# on ajoute --pids-limit=-1 à chaque « docker run ». Sans effet avec Docker Engine.
if [ "${PODMAN_COMPAT:-0}" = "1" ] && [ "$1" = "run" ]; then
  shift
  exec /usr/local/bin/docker.real run --pids-limit=-1 "$@"
fi
exec /usr/local/bin/docker.real "$@"

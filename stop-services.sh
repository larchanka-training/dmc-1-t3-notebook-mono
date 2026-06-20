#!/bin/bash
set -euo pipefail

mode=$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')

KEEP_IMAGES=("postgres:17" "dpage/pgadmin4")

contains_keep_image() {
  local candidate="$1"
  for keep in "${KEEP_IMAGES[@]}"; do
    if [[ "$candidate" == "$keep" ]]; then
      return 0
    fi
  done
  return 1
}

# Always try to stop all project containers first, regardless of CLI params.
echo "Stopping project containers..."
docker compose stop || true

case "$mode" in
  cleanup)
    echo "Cleanup mode: bringing project down and removing non-kept images..."
    docker compose down

    mapfile -t compose_images < <(docker compose config --images | sort -u)
    for image in "${compose_images[@]}"; do
      if [[ -z "$image" ]]; then
        continue
      fi

      if contains_keep_image "$image"; then
        echo "Keeping image: $image"
        continue
      fi

      echo "Removing image: $image"
      docker image rm -f "$image" || true
    done
    ;;
  remove)
    echo "Remove mode: removing all project containers, volumes, and images..."
    docker compose down -v --rmi all
    ;;
  "")
    echo "Stopped project containers, images or volumes were not removed."
    ;;
  *)
    echo "Stop complete."
    echo "Usage: ./stop-services.sh [cleanup|remove]"
    echo "  cleanup: down project containers, keep postgres:17 and pgadmin images, remove others"
    echo "  remove : down project containers and remove all project images/volumes"
    ;;
esac

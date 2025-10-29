#!/usr/bin/env bash
# Push all enterprise automation images to Docker Hub
set -Eeuo pipefail

DOCKER_USER="cashthecheck"
PROJECTS=(oracle microsoft google meta ibm amazon apple openai)

echo "🔐 Checking Docker login..."
docker info | grep -q "Username: ${DOCKER_USER}" || {
  echo "[ERROR] Not logged in as ${DOCKER_USER}. Run: docker login"
  exit 1
}

for dir in "${PROJECTS[@]}"; do
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "[PUSHING] $dir → docker.io/${DOCKER_USER}/${dir}-automation:latest"

  IMAGE_LOCAL="${dir}-automation:latest"
  IMAGE_REMOTE="${DOCKER_USER}/${dir}-automation:latest"

  # Build image if it doesn't exist
  if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_LOCAL}$"; then
    echo "[INFO] Building ${IMAGE_LOCAL}..."
    (cd "$dir" && docker build -t "${IMAGE_LOCAL}" .)
  fi

  # Tag & push
  docker tag "${IMAGE_LOCAL}" "${IMAGE_REMOTE}"
  docker push "${IMAGE_REMOTE}" || {
    echo "[ERROR] Push failed for ${IMAGE_REMOTE}"
    continue
  }

  echo "[SUCCESS] ${IMAGE_REMOTE} uploaded!"
done

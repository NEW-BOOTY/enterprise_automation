#!/usr/bin/env bash
set -euo pipefail

DOCKER_USER="cutthecheck"
REPO="enterprise_automation"
TAGS=(oracle microsoft google meta ibm amazon apple openai)
CLUSTER_DIR="k8s_manifests"

mkdir -p "$CLUSTER_DIR"

echo "=== [1/6] Generating Kubernetes manifests ==="
for TAG in "${TAGS[@]}"; do
  FILE="$CLUSTER_DIR/${TAG}-deployment.yaml"
  cat > "$FILE" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${TAG}-automation
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${TAG}-automation
  template:
    metadata:
      labels:
        app: ${TAG}-automation
    spec:
      containers:
      - name: ${TAG}-automation
        image: ${DOCKER_USER}/${REPO}:${TAG}
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: ${TAG}-service
spec:
  selector:
    app: ${TAG}-automation
  ports:
    - port: 80
      targetPort: 8080
EOF
  echo "✓ ${FILE}"
done

echo "=== [2/6] Generating Docker Compose file ==="
cat > docker-compose.yml <<EOF
version: '3.8'
services:
$(for TAG in "${TAGS[@]}"; do
cat <<SERV
  ${TAG}:
    image: ${DOCKER_USER}/${REPO}:${TAG}
    container_name: ${TAG}_container
    ports:
      - "8${RANDOM:0:2}0:8080"
SERV
done)
EOF
echo "✓ docker-compose.yml"

echo "=== [3/6] Setting up CI/CD pipelines ==="
mkdir -p .github/workflows
cat > .github/workflows/docker_build.yml <<'EOF'
name: Build and Push All Images
on:
  push:
    branches: [ "main" ]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Login to DockerHub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}
      - name: Build & Push Images
        run: |
          TAGS=(oracle microsoft google meta ibm amazon apple openai)
          for tag in "${TAGS[@]}"; do
            docker build -t ${DOCKERHUB_USERNAME}/enterprise_automation:$tag .
            docker push ${DOCKERHUB_USERNAME}/enterprise_automation:$tag
          done
EOF
echo "✓ GitHub Actions workflow created"

echo "=== [4/6] Signing images with Cosign ==="
for TAG in "${TAGS[@]}"; do
  cosign sign ${DOCKER_USER}/${REPO}:${TAG} || echo "⚠️  skipped (requires key setup)"
done

echo "=== [5/6] Creating Jenkinsfile (optional) ==="
cat > Jenkinsfile <<'EOF'
pipeline {
  agent any
  stages {
    stage('Build and Push') {
      steps {
        script {
          def tags = ["oracle", "microsoft", "google", "meta", "ibm", "amazon", "apple", "openai"]
          for (t in tags) {
            sh "docker build -t cutthecheck/enterprise_automation:${t} ."
            sh "docker push cutthecheck/enterprise_automation:${t}"
          }
        }
      }
    }
  }
}
EOF
echo "✓ Jenkinsfile created"

echo "=== [6/6] Done! ==="
echo "Run these next steps:"
echo "  kubectl apply -f k8s_manifests/     # deploy all containers"
echo "  docker-compose up -d                # run all locally"

#!/bin/bash
set -e

# Script para build da imagem Docker com versão do Commitizen

VERSION="1.0.0"

echo "📦 Construindo imagem Docker versão: $VERSION"

# Nome da imagem
IMAGE_NAME="github-actions-runner-basic"
REGISTRY_USER="${DOCKER_USER:-rodrigodevux}"

# Muda para o diretório raiz do projeto
cd "$(dirname "$0")/.."

# Build da imagem com a versão do commitizen
docker build \
    --build-arg IMAGE_VERSION="$VERSION" \
    -t "$REGISTRY_USER/$IMAGE_NAME:$VERSION" \
    -t "$REGISTRY_USER/$IMAGE_NAME:latest" \
    -f ./basic-runner/Dockerfile \
    .

echo "✅ Imagem construída com sucesso!"
echo "   📌 Tags criadas:"
echo "   - $REGISTRY_USER/$IMAGE_NAME:$VERSION"
echo "   - $REGISTRY_USER/$IMAGE_NAME:latest"

# Opcionalmente, faz push se a variável DOCKER_PUSH estiver definida
if [ "$DOCKER_PUSH" = "true" ]; then
    echo "🚀 Fazendo push da imagem..."
    docker push "$REGISTRY_USER/$IMAGE_NAME:$VERSION"
    docker push "$REGISTRY_USER/$IMAGE_NAME:latest"
    echo "✅ Push realizado com sucesso!"
fi

echo ""
echo "💡 Para fazer push manual:"
echo "   docker push $REGISTRY_USER/$IMAGE_NAME:$VERSION"
echo "   docker push $REGISTRY_USER/$IMAGE_NAME:latest"
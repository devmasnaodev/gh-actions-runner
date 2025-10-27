#!/bin/bash
set -e

VERSION="1.0.0"

echo "📦 Construindo imagem Docker versão: $VERSION"

# Nome da imagem
IMAGE_NAME="github-actions-runner-deployer"
REGISTRY_USER="${DOCKER_USER:-rodrigodevux}"

# Muda para o diretório raiz do projeto
cd "$(dirname "$0")/.."

# Build da imagem com a versão do commitizen
docker build \
    --build-arg IMAGE_VERSION="$VERSION" \
    --build-arg RUNNER_VERSION="${RUNNER_VERSION:-2.329.0}" \
    -t "$REGISTRY_USER/$IMAGE_NAME:$VERSION" \
    -t "$REGISTRY_USER/$IMAGE_NAME:latest" \
    -f ./deployer-runner/Dockerfile \
    .

echo "✅ Imagem construída com sucesso!"
echo "   📌 Tags criadas:"
echo "   - $REGISTRY_USER/$IMAGE_NAME:$VERSION"
echo "   - $REGISTRY_USER/$IMAGE_NAME:latest"

# Mostrar informações da imagem
echo
echo "📊 Informações da imagem:"
docker image inspect "$REGISTRY_USER/$IMAGE_NAME:latest" --format='
📦 Repository: {{.RepoTags}}
🏗️ Created: {{.Created}}
📏 Size: {{.Size}} bytes
🏛️ Architecture: {{.Architecture}}
💻 OS: {{.Os}}'

echo
echo "🔍 Testando a imagem..."

# Teste básico da imagem
if docker run --rm --entrypoint="" "$REGISTRY_USER/$IMAGE_NAME:latest" php --version > /dev/null 2>&1; then
    echo "✅ PHP está funcionando"
else
    echo "❌ Erro ao testar PHP"
    exit 1
fi

if docker run --rm --entrypoint="" "$REGISTRY_USER/$IMAGE_NAME:latest" composer --version > /dev/null 2>&1; then
    echo "✅ Composer está funcionando"
else
    echo "❌ Erro ao testar Composer"
    exit 1
fi

if docker run --rm --entrypoint="" "$REGISTRY_USER/$IMAGE_NAME:latest" dep --version > /dev/null 2>&1; then
    echo "✅ Deployer está funcionando"
else
    echo "❌ Erro ao testar Deployer"
    exit 1
fi

echo
echo "🎉 Build concluído com sucesso!"

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
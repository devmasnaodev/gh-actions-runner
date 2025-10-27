# Dockerfile para GitHub Actions Runner Basic
FROM ubuntu:24.04

# Evita prompts interativos durante a instalação
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Sao_Paulo

# Define a versão da imagem (pode ser passada no build)
ARG IMAGE_VERSION="0.1.0"

# Instala dependências necessárias
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    jq \
    rsync \
    build-essential \
    libssl-dev \
    libffi-dev \
    ca-certificates \
    gnupg \
    lsb-release \
    sudo \
    unzip \
    tar \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Cria usuário para o runner
RUN useradd -m -s /bin/bash runner && \
    usermod -aG sudo runner && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Muda para o usuário runner
USER runner
WORKDIR /home/runner

# Cria diretório para o runner (será populado no entrypoint)
RUN mkdir -p /home/runner/actions-runner

# Copia biblioteca global
COPY --chown=runner:runner libs/ /home/runner/libs/

# Copia scripts de configuração
COPY --chown=runner:runner basic-runner/files/entrypoint.sh /home/runner/entrypoint.sh
COPY --chown=runner:runner basic-runner/files/cleanup.sh /home/runner/cleanup.sh

# Torna os scripts executáveis
RUN chmod +x /home/runner/entrypoint.sh /home/runner/cleanup.sh /home/runner/libs/*.sh

# Define variáveis de ambiente
ENV RUNNER_NAME="basic-runner"
ENV RUNNER_LABELS="basic"
ENV RUNNER_GROUP="default"

# Expõe informações sobre a imagem
LABEL org.opencontainers.image.title="GitHub Actions Runner Basic"
LABEL org.opencontainers.image.description="Self-hosted GitHub Actions Runner"
LABEL org.opencontainers.image.version="${IMAGE_VERSION}"
LABEL org.opencontainers.image.authors="Rodrigo <rodrigo.dev.ux@outlook.com>"
LABEL org.opencontainers.image.licenses="MIT"
LABEL maintainer="Rodrigo <rodrigo.dev.ux@outlook.com>"

# Define o entrypoint
ENTRYPOINT ["/home/runner/entrypoint.sh"]
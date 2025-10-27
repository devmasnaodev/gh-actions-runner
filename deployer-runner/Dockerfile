# Dockerfile para GitHub Actions Runner com Deployer
FROM ubuntu:24.04

# Evita prompts interativos e configura timezone
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Sao_Paulo

# Define a versão da imagem
ARG IMAGE_VERSION="0.1.0"

# Instalar dependências do sistema
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

# Adicionar repositório PHP 8.3
RUN add-apt-repository ppa:ondrej/php -y && apt-get update

# Instalar PHP 8.3 e extensões necessárias
RUN apt-get install -y \
    php8.3-cli \
    php8.3-bcmath \
    php8.3-curl \
    php8.3-dom \
    php8.3-intl \
    php8.3-mbstring \
    php8.3-xml \
    php8.3-zip \
    && rm -rf /var/lib/apt/lists/*

# Criar link simbólico para php
RUN ln -sf /usr/bin/php8.3 /usr/bin/php

# Instalar Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Criar usuário para o runner (Ubuntu style)
RUN useradd -m -s /bin/bash runner && \
    usermod -aG sudo runner && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Mudar para o usuário runner
USER runner
WORKDIR /home/runner

# Criar diretório para o runner (será populado no entrypoint)
RUN mkdir -p /home/runner/actions-runner

# Configurar PATH do Composer para o usuário runner
ENV COMPOSER_HOME=/home/runner/.composer
ENV PATH="/home/runner/.composer/vendor/bin:${PATH}"

# Instalar Deployer globalmente como usuário runner
RUN composer global require deployer/deployer && \
    echo 'export PATH="$HOME/.composer/vendor/bin:$PATH"' >> ~/.bashrc

# Voltar para root para criar link simbólico
USER root
RUN ln -s /home/runner/.composer/vendor/bin/dep /usr/local/bin/dep || true

# Voltar para usuário runner
USER runner

# Copia biblioteca global
COPY --chown=runner:runner libs/ /home/runner/libs/

# Copia scripts de configuração
COPY --chown=runner:runner deployer-runner/files/entrypoint.sh /home/runner/entrypoint.sh
COPY --chown=runner:runner deployer-runner/files/cleanup.sh /home/runner/cleanup.sh

# Torna os scripts executáveis
RUN chmod +x /home/runner/entrypoint.sh /home/runner/cleanup.sh /home/runner/libs/*.sh

# Variáveis de ambiente
ENV RUNNER_NAME="deployer-runner"
ENV RUNNER_LABELS="deployer,php"
ENV RUNNER_GROUP="default"
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_HOME=/home/runner/.composer

# Expor informações sobre a imagem
LABEL org.opencontainers.image.title="GitHub Actions Runner Deployer"
LABEL org.opencontainers.image.description="Self-hosted GitHub Actions Runner with PHP 8.3 and Deployer"
LABEL org.opencontainers.image.version="${IMAGE_VERSION}"
LABEL org.opencontainers.image.authors="Rodrigo <rodrigo.dev.ux@outlook.com>"
LABEL org.opencontainers.image.licenses="MIT"
LABEL maintainer="Rodrigo <rodrigo.dev.ux@outlook.com>"

# Define o entrypoint
ENTRYPOINT ["/home/runner/entrypoint.sh"]
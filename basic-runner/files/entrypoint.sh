#!/bin/bash

set -e

# ==============================================================================
# GitHub Actions Runner - Enhanced Entrypoint
# ==============================================================================

# Carrega as bibliotecas globais usando bootstrap
# shellcheck source=./libs/bootstrap.sh
source "./libs/bootstrap.sh"

# Inicializa o bootstrap (carrega common.sh e runner-utils.sh)
bootstrap_runner_libs

# Inicializa a biblioteca
init_common_lib "GitHub Actions Runner - Basic" "2.0.0"

# Função para validar variáveis de ambiente obrigatórias
validate_required_vars() {
    validate_github_vars
}

# Função para definir valores padrão das variáveis
set_default_values() {
    log_step "Definindo valores padrão para variáveis opcionais..."
    
    RUNNER_NAME=${RUNNER_NAME:-"basic-runner"}
    RUNNER_LABELS=${RUNNER_LABELS:-"basic,linux,ubuntu"}
    RUNNER_GROUP=${RUNNER_GROUP:-"default"}
    RUNNER_VERSION=${RUNNER_VERSION:-"$DEFAULT_RUNNER_VERSION"}
    
    log_info "Nome do runner: $RUNNER_NAME"
    log_info "Labels: $RUNNER_LABELS"
    log_info "Grupo: $RUNNER_GROUP"
    log_info "Versão: $RUNNER_VERSION"
}

# Função para baixar e instalar o GitHub Actions Runner
download_runner() {
    local version="$RUNNER_VERSION"
    
    log_step "Verificando se o runner versão ${version} precisa ser baixado..."
    
    # Verifica se o runner já está instalado na versão correta
    if file_exists "/home/runner/.runner_version"; then
        local installed_version=$(cat /home/runner/.runner_version)
        if [ "$installed_version" = "$version" ] && file_exists "/home/runner/run.sh"; then
            log_success "Runner versão ${version} já instalado"
            return 0
        fi
    fi
    
    log_step "Baixando GitHub Actions Runner versão ${version}..."
    
    # Remove instalação anterior se existir
    rm -rf /home/runner/actions-runner-*
    rm -f /home/runner/run.sh /home/runner/config.sh
    
    # Baixa o runner
    local download_url="https://github.com/actions/runner/releases/download/v${version}/actions-runner-linux-x64-${version}.tar.gz"
    local filename="actions-runner-linux-x64-${version}.tar.gz"
    
    if ! execute_with_retry 3 5 curl -o "$filename" -L "$download_url"; then
        log_error_and_exit "Falha ao baixar o runner versão ${version}"
    fi
    
    # Extrai o runner
    if ! tar xzf "./$filename"; then
        log_error_and_exit "Falha ao extrair o runner"
    fi
    
    # Remove o arquivo compactado
    cleanup_temp_files "$filename"
    
    # Instala dependências do runner
    if ! sudo ./bin/installdependencies.sh; then
        log_error_and_exit "Falha ao instalar dependências do runner"
    fi
    
    # Salva a versão instalada
    echo "${version}" > /home/runner/.runner_version
    
    log_success "Runner versão ${version} instalado com sucesso"
}

# Função para cleanup quando o container for parado
cleanup() {
    log_warn "Recebido sinal de parada, removendo runner..."
    if file_exists ".runner"; then
        if ./config.sh remove --token "${REGISTRATION_TOKEN}" 2>/dev/null; then
            log_success "Runner removido com sucesso"
        else
            log_warn "Falha ao remover runner (pode já ter sido removido)"
        fi
    fi
    exit 0
}

# Configura trap para cleanup
trap cleanup SIGINT SIGTERM

# Configura permissões corretas para o diretório de trabalho
setup_permissions() {
    log_step "Configurando permissões do diretório de trabalho..."
    
    # Garante que o diretório _work pertence ao usuário runner
    if [ -d "/home/runner/_work" ]; then
        sudo chown -R runner:runner /home/runner/_work
        chmod -R 755 /home/runner/_work
    fi
    
    # Cria diretório _tool se não existir
    ensure_directory "/home/runner/_work/_tool" "755"
    
    log_success "Permissões do diretório de trabalho configuradas"
}

# Função para obter token de registro
get_registration_token() {
    REGISTRATION_TOKEN=$(get_github_token "registration-token" "$GITHUB_URL" "$GITHUB_TOKEN")
    export REGISTRATION_TOKEN
}

# Função para configurar o runner
configure_runner() {
    log_step "Configurando o runner..."
    
    # Remove configuração anterior se existir
    if file_exists ".runner"; then
        log_warn "Removendo configuração anterior do runner..."
        ./config.sh remove --token "${REGISTRATION_TOKEN}" 2>/dev/null || true
    fi
    
    # Configura o runner
    if ./config.sh \
        --url "${GITHUB_URL}" \
        --token "${REGISTRATION_TOKEN}" \
        --name "${RUNNER_NAME}" \
        --labels "${RUNNER_LABELS}" \
        --runnergroup "${RUNNER_GROUP}" \
        --work "_work" \
        --unattended \
        --replace; then
        log_success "Runner configurado com sucesso!"
    else
        log_error_and_exit "Falha ao configurar o runner"
    fi
}

# Função para iniciar o runner
start_runner() {
    log_step "Iniciando o runner..."
    log_success "Runner ativo e aguardando jobs..."
    
    # Inicia o runner
    ./run.sh &
    local runner_pid=$!
    
    # Aguarda o processo do runner
    wait $runner_pid
}

# Função principal
main() {
    log_section "GitHub Actions Runner - Enhanced Entrypoint"
    
    # Configuração de padrões específicos do tipo de runner
    set_runner_defaults "basic"
    
    # Validação de variáveis de ambiente
    validate_required_vars
    
    # Construção da URL do GitHub
    build_github_url
    
    # Definição de valores padrão
    set_default_values
    
    # Configuração de permissões específicas do runner
    setup_runner_permissions
    
    # Configuração de permissões gerais
    setup_permissions
    
    # Download e instalação do runner
    download_runner
    
    # Obtenção do token de registro
    get_registration_token
    
    # Configuração do runner
    configure_runner
    
    # Início do runner
    start_runner
}

# ==============================================================================
# EXECUÇÃO PRINCIPAL
# ==============================================================================

# Executa a função principal
main
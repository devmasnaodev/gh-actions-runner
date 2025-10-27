#!/bin/bash

set -e

# ==============================================================================
# GitHub Actions Runner - Enhanced Entrypoint (Deployer Edition)
# ==============================================================================

# Carrega as bibliotecas globais usando bootstrap
# shellcheck source=./libs/bootstrap.sh
source "./libs/bootstrap.sh"

# Inicializa o bootstrap (carrega common.sh e runner-utils.sh)
bootstrap_runner_libs

# Inicializa a biblioteca
init_common_lib "GitHub Actions Runner - Deployer" "1.0.0"

# Função para validar variáveis de ambiente obrigatórias
validate_required_vars() {
    validate_github_vars
}

# Função para definir valores padrão específicos do deployer
set_deployer_defaults() {
    # Configuração específica para deployer
    RUNNER_NAME=${RUNNER_NAME:-"deployer-runner-$(hostname)"}
    RUNNER_LABELS=${RUNNER_LABELS:-"self-hosted,deployer,linux,ubuntu,php,composer"}
    RUNNER_GROUP=${RUNNER_GROUP:-"default"}
    
    # Exporta as variáveis
    export RUNNER_NAME RUNNER_LABELS RUNNER_GROUP
    
    log_info "Configuração do Deployer Runner:"
    log_info "  - Nome: $RUNNER_NAME"
    log_info "  - Labels: $RUNNER_LABELS"
    log_info "  - Grupo: $RUNNER_GROUP"
}

# Função para verificar dependências específicas do deployer
check_deployer_dependencies() {
    log_step "Verificando dependências específicas do deployer..."
    
    local required_tools=("php" "composer" "dep")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_warn "Ferramentas não encontradas (podem ser instaladas via actions): ${missing_tools[*]}"
    else
        log_success "Todas as ferramentas de deployment estão disponíveis"
    fi
    
    # Verifica versão do PHP
    if command -v php >/dev/null 2>&1; then
        local php_version=$(php -v | head -n 1)
        log_info "PHP: $php_version"
    fi
    
    # Verifica Composer
    if command -v composer >/dev/null 2>&1; then
        local composer_version=$(composer --version 2>/dev/null | head -n 1)
        log_info "Composer: $composer_version"
    fi
    
    # Verifica Deployer
    if command -v dep >/dev/null 2>&1; then
        local deployer_version=$(dep --version 2>/dev/null | head -n 1 || echo "Deployer instalado")
        log_info "Deployer: $deployer_version"
    fi
}

# Função para configurar permissões específicas do deployer
setup_deployer_permissions() {
    log_step "Configurando permissões específicas do deployer..."
    
    # Configurações básicas do runner
    setup_runner_permissions
    
    # Configurações específicas para deployment
    ensure_directory "/home/runner/.ssh" "700"
    ensure_directory "/home/runner/.config" "755"
    
    # Configurar SSH se fornecido
    setup_ssh_config
    
    log_success "Permissões específicas do deployer configuradas"
}

# Função para configurar ferramentas PHP/Composer específicas
setup_php_tools() {
    log_step "Configurando ferramentas PHP/Composer..."
    
    # Configurar Composer se necessário
    if [ -n "$COMPOSER_AUTH" ]; then
        log_info "Configurando autenticação do Composer..."
        ensure_directory "/home/runner/.composer" "755"
        echo "$COMPOSER_AUTH" > /home/runner/.composer/auth.json
        chmod 600 /home/runner/.composer/auth.json
        log_success "Autenticação do Composer configurada"
    fi
    
    # Verificar instalação do Deployer
    if ! command -v dep >/dev/null 2>&1; then
        log_warn "Deployer não encontrado no PATH"
        if [ -f "/home/runner/.composer/vendor/bin/dep" ]; then
            log_info "Deployer encontrado em ~/.composer/vendor/bin/"
        fi
    fi
    
    log_success "Ferramentas PHP/Composer configuradas"
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
    log_section "GitHub Actions Runner - Deployer Enhanced Entrypoint"
    
    # Configuração de padrões específicos do deployer
    set_runner_defaults "deployer"
    set_deployer_defaults
    
    # Validação de variáveis de ambiente
    validate_required_vars
    
    # Construção da URL do GitHub
    build_github_url
    
    # Verificação de dependências específicas
    check_deployer_dependencies
    
    # Configuração de permissões específicas do deployer
    setup_deployer_permissions
    
    # Configuração de ferramentas PHP
    setup_php_tools
    
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

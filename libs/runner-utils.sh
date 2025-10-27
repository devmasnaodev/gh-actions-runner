#!/bin/bash

# ==============================================================================
# GitHub Actions Runner - Runner Utilities
# ==============================================================================
# Utilitários específicos para runners (complementa common.sh)
# ==============================================================================

# Verifica se a biblioteca comum foi carregada
if [ "${RUNNER_COMMON_LIB_LOADED:-}" != "true" ]; then
    echo "ERRO: Biblioteca comum não foi carregada. Carregue common.sh primeiro." >&2
    exit 1
fi

# Verifica se os utilitários já foram carregados
if [ "${RUNNER_UTILS_LOADED:-}" = "true" ]; then
    return 0
fi

# Marca os utilitários como carregados
readonly RUNNER_UTILS_LOADED=true

# ==============================================================================
# FUNÇÕES ESPECÍFICAS PARA RUNNERS
# ==============================================================================

# Função para configurar permissões específicas do runner
setup_runner_permissions() {
    log_step "Configurando permissões específicas do runner..."
    
    # Garante que o diretório _work pertence ao usuário runner
    if [ -d "/home/runner/_work" ]; then
        sudo chown -R runner:runner /home/runner/_work
        chmod -R 755 /home/runner/_work
    fi
    
    # Cria diretórios essenciais se não existirem
    ensure_directory "/home/runner/_work/_tool" "755"
    ensure_directory "/home/runner/.cache" "755"
    
    # Configura permissões para Docker socket se estiver montado (deployer)
    if [ -S /var/run/docker.sock ]; then
        sudo chown root:docker /var/run/docker.sock
        sudo chmod 660 /var/run/docker.sock
        # Adiciona usuário runner ao grupo docker
        sudo usermod -aG docker runner || true
        log_success "Permissões do Docker configuradas"
    fi
    
    log_success "Permissões específicas do runner configuradas"
}

# Função para configurar SSH (específica para deployer)
setup_ssh_config() {
    if [ -n "$SSH_PRIVATE_KEY" ]; then
        log_step "Configurando SSH..."
        
        # Cria diretório SSH
        ensure_directory "/home/runner/.ssh" "700"
        
        # Configura chave privada
        echo "$SSH_PRIVATE_KEY" > /home/runner/.ssh/id_rsa
        chmod 600 /home/runner/.ssh/id_rsa
        
        # Adicionar servidor aos known hosts se fornecido
        if [ -n "$SERVER_IP" ]; then
            local server_port="${SERVER_PORT:-22}"
            log_info "Adicionando $SERVER_IP:$server_port aos known hosts..."
            ssh-keyscan -H -p "$server_port" "$SERVER_IP" >> /home/runner/.ssh/known_hosts 2>/dev/null || true
        fi
        
        log_success "SSH configurado"
    fi
}

# Função para validar versão específica do runner
validate_runner_version() {
    local version="${RUNNER_VERSION:-$DEFAULT_RUNNER_VERSION}"
    
    log_step "Validando versão do runner: $version"
    
    # Verifica se a versão é válida (formato x.y.z)
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error_and_exit "Versão inválida do runner: $version (use formato x.y.z)"
    fi
    
    log_success "Versão do runner validada: $version"
}

# Função para limpar recursos do runner
cleanup_runner_resources() {
    log_step "Limpando recursos do runner..."
    
    # Limpa arquivos temporários específicos do runner
    cleanup_temp_files "actions-runner-linux-x64-*.tar.gz"
    cleanup_temp_files "/tmp/runner-*"
    cleanup_temp_files "/home/runner/.runner_*"
    
    # Limpa logs antigos se existirem
    if [ -d "/home/runner/_diag" ]; then
        find /home/runner/_diag -name "*.log" -mtime +7 -delete 2>/dev/null || true
        log_debug "Logs antigos removidos"
    fi
    
    log_success "Recursos do runner limpos"
}

# Função para verificar saúde do runner
health_check_runner() {
    log_step "Verificando saúde do runner..."
    
    local health_status="healthy"
    
    # Verifica se o processo do runner está rodando
    if ! pgrep -f "Runner.Listener" > /dev/null; then
        log_warn "Processo Runner.Listener não encontrado"
        health_status="unhealthy"
    fi
    
    # Verifica se há espaço em disco suficiente (pelo menos 1GB livre)
    local available_space=$(df /home/runner/_work | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 1048576 ]; then  # 1GB em KB
        log_warn "Pouco espaço em disco disponível: $(($available_space / 1024))MB"
        health_status="unhealthy"
    fi
    
    # Verifica conectividade com GitHub
    if ! curl -s --connect-timeout 10 https://api.github.com > /dev/null; then
        log_warn "Falha na conectividade com GitHub API"
        health_status="unhealthy"
    fi
    
    if [ "$health_status" = "healthy" ]; then
        log_success "Runner está saudável"
        return 0
    else
        log_warn "Runner apresenta problemas de saúde"
        return 1
    fi
}

# Função para configurar valores padrão específicos do tipo de runner
set_runner_defaults() {
    local runner_type="${1:-basic}"
    
    log_step "Configurando valores padrão para runner tipo: $runner_type"
    
    case "$runner_type" in
        "basic")
            RUNNER_NAME=${RUNNER_NAME:-"basic-runner-$(hostname)"}
            RUNNER_LABELS=${RUNNER_LABELS:-"basic,linux,ubuntu"}
            RUNNER_GROUP=${RUNNER_GROUP:-"default"}
            ;;
        "deployer")
            RUNNER_NAME=${RUNNER_NAME:-"deployer-runner-$(hostname)"}
            RUNNER_LABELS=${RUNNER_LABELS:-"deployer,deploy,linux,ubuntu,docker,kubernetes,aws,gcp,azure"}
            RUNNER_GROUP=${RUNNER_GROUP:-"deployment"}
            ;;
        *)
            log_warn "Tipo de runner desconhecido: $runner_type. Usando padrões básicos."
            RUNNER_NAME=${RUNNER_NAME:-"runner-$(hostname)"}
            RUNNER_LABELS=${RUNNER_LABELS:-"self-hosted,linux,ubuntu"}
            RUNNER_GROUP=${RUNNER_GROUP:-"default"}
            ;;
    esac
    
    RUNNER_VERSION=${RUNNER_VERSION:-"$DEFAULT_RUNNER_VERSION"}
    
    # Exporta as variáveis
    export RUNNER_NAME RUNNER_LABELS RUNNER_GROUP RUNNER_VERSION
    
    log_info "Nome do runner: $RUNNER_NAME"
    log_info "Labels: $RUNNER_LABELS"
    log_info "Grupo: $RUNNER_GROUP"
    log_info "Versão: $RUNNER_VERSION"
}

# Função para remover runner de forma segura
safe_remove_runner() {
    local registration_token="$1"
    
    if [ -z "$registration_token" ]; then
        log_error "Token de registro não fornecido para remoção"
        return 1
    fi
    
    log_step "Removendo runner de forma segura..."
    
    if file_exists ".runner"; then
        if ./config.sh remove --token "$registration_token" 2>/dev/null; then
            log_success "Runner removido com sucesso do GitHub"
        else
            log_warn "Falha ao remover runner (pode já ter sido removido)"
        fi
    else
        log_warn "Arquivo .runner não encontrado - runner pode não estar configurado"
    fi
    
    # Cleanup de recursos locais
    cleanup_runner_resources
}

# ==============================================================================
# EXPORTAÇÃO DE FUNÇÕES ESPECÍFICAS DO RUNNER
# ==============================================================================

# Lista de funções específicas do runner que serão exportadas
readonly RUNNER_UTIL_FUNCTIONS=(
    setup_runner_permissions setup_ssh_config validate_runner_version
    cleanup_runner_resources health_check_runner set_runner_defaults
    safe_remove_runner
)

# Exporta todas as funções específicas do runner
for func in "${RUNNER_UTIL_FUNCTIONS[@]}"; do
    export -f "$func"
done

log_debug "Utilitários do runner carregados - ${#RUNNER_UTIL_FUNCTIONS[@]} funções específicas exportadas"
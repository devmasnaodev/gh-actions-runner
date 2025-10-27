#!/bin/bash

# ==============================================================================
# GitHub Actions Runner - Common Library
# ==============================================================================
# Biblioteca compartilhada com funções reutilizáveis para todos os scripts
# ==============================================================================

# Verifica se a biblioteca já foi carregada para evitar conflitos
if [ "${RUNNER_COMMON_LIB_LOADED:-}" = "true" ]; then
    return 0
fi

# Marca a biblioteca como carregada
readonly RUNNER_COMMON_LIB_LOADED=true

# ==============================================================================
# CONSTANTES E CONFIGURAÇÕES
# ==============================================================================

# Cores para logs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Versão padrão do runner
readonly DEFAULT_RUNNER_VERSION="2.329.0"

# ==============================================================================
# FUNÇÕES DE LOG
# ==============================================================================

# Função principal para log com timestamp e cores
log() {
    local message="$1"
    local level="${2:-INFO}"
    local color=""
    local prefix=""
    
    case "$level" in
        "ERROR")   color="$RED";    prefix="❌" ;;
        "SUCCESS") color="$GREEN";  prefix="✅" ;;
        "WARN")    color="$YELLOW"; prefix="⚠️" ;;
        "INFO")    color="$BLUE";   prefix="ℹ️" ;;
        "DEBUG")   color="$PURPLE"; prefix="🔍" ;;
        "STEP")    color="$CYAN";   prefix="🔄" ;;
        "HEADER")  color="$WHITE";  prefix="🚀" ;;
        *)         color="$NC";     prefix="📝" ;;
    esac
    
    echo -e "${color}[$(date +'%Y-%m-%d %H:%M:%S')] [$level] ${prefix} $message${NC}"
}

# Funções de log específicas para facilitar o uso
log_info() {
    log "$1" "INFO"
}

log_success() {
    log "$1" "SUCCESS"
}

log_warn() {
    log "$1" "WARN"
}

log_error() {
    log "$1" "ERROR"
}

log_debug() {
    log "$1" "DEBUG"
}

log_step() {
    log "$1" "STEP"
}

log_header() {
    log "$1" "HEADER"
}

# Função para log de erro e saída
log_error_and_exit() {
    log_error "$1"
    exit 1
}

# Função para log com separador visual
log_separator() {
    local char="${1:-=}"
    local length="${2:-80}"
    local separator=""
    
    for ((i=1; i<=length; i++)); do
        separator="${separator}${char}"
    done
    
    echo -e "${BLUE}${separator}${NC}"
}

# Função para log de seção
log_section() {
    local title="$1"
    local char="${2:-=}"
    
    log_separator "$char"
    log_header "$title"
    log_separator "$char"
}

# ==============================================================================
# FUNÇÕES DE VALIDAÇÃO
# ==============================================================================

# Função para validar se uma variável está definida
validate_var() {
    local var_name="$1"
    local var_value="${!var_name}"
    local is_required="${2:-true}"
    
    if [ -z "$var_value" ]; then
        if [ "$is_required" = "true" ]; then
            log_error_and_exit "Variável obrigatória não definida: $var_name"
        else
            log_warn "Variável opcional não definida: $var_name"
            return 1
        fi
    fi
    
    log_debug "Variável validada: $var_name"
    return 0
}

# Função para validar múltiplas variáveis
validate_vars() {
    local vars=("$@")
    local missing_vars=()
    
    for var in "${vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error_and_exit "Variáveis obrigatórias não definidas: ${missing_vars[*]}"
    fi
    
    log_success "Todas as variáveis obrigatórias estão definidas"
}

# Função para validar comandos disponíveis
validate_command() {
    local cmd="$1"
    local is_required="${2:-true}"
    
    if ! command -v "$cmd" &> /dev/null; then
        if [ "$is_required" = "true" ]; then
            log_error_and_exit "Comando obrigatório não encontrado: $cmd"
        else
            log_warn "Comando opcional não encontrado: $cmd"
            return 1
        fi
    fi
    
    log_debug "Comando validado: $cmd"
    return 0
}

# ==============================================================================
# FUNÇÕES DE CONFIGURAÇÃO GITHUB
# ==============================================================================

# Função para validar variáveis de ambiente obrigatórias do GitHub
validate_github_vars() {
    log_step "Validando variáveis de ambiente do GitHub..."
    
    local required_vars=()
    
    # Usando PAT (Personal Access Token) - método obrigatório
    if [ -n "$GITHUB_PAT" ] && [ -n "$GITHUB_OWNER" ]; then
        required_vars=("GITHUB_PAT" "GITHUB_OWNER")
        if [ -n "$GITHUB_REPOSITORY" ]; then
            log_info "Configuração detectada: Repositório específico com PAT"
        else
            log_info "Configuração detectada: Organização com PAT"
        fi
    else
        log_error_and_exit "Configuração obrigatória não encontrada. É necessário definir:
  - GITHUB_PAT: Personal Access Token do GitHub
  - GITHUB_OWNER: Nome da organização ou usuário
  - GITHUB_REPOSITORY: Nome do repositório (opcional)"
    fi
    
    # Verifica se todas as variáveis obrigatórias estão definidas
    validate_vars "${required_vars[@]}"
}

# Função para construir a URL do GitHub
build_github_url() {
    # Constrói a URL baseada nas variáveis PAT
    if [ -n "$GITHUB_REPOSITORY" ]; then
        # Repositório específico
        GITHUB_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPOSITORY}"
        log_info "URL construída para repositório: $GITHUB_URL"
    else
        # Organização
        GITHUB_URL="https://github.com/${GITHUB_OWNER}"
        log_info "URL construída para organização: $GITHUB_URL"
    fi
    
    # Define GITHUB_TOKEN como GITHUB_PAT para compatibilidade interna
    GITHUB_TOKEN="$GITHUB_PAT"
    
    # Exporta as variáveis para uso em outros scripts
    export GITHUB_URL
    export GITHUB_TOKEN
}

# Função para obter informações da URL do GitHub
parse_github_url() {
    local url="$1"
    
    if [[ "$url" =~ github\.com/([^/]+)$ ]]; then
        # URL da organização
        export GITHUB_ORG_NAME="${BASH_REMATCH[1]}"
        export GITHUB_TYPE="organization"
    elif [[ "$url" =~ github\.com/([^/]+)/([^/]+)$ ]]; then
        # URL do repositório
        export GITHUB_OWNER_NAME="${BASH_REMATCH[1]}"
        export GITHUB_REPO_NAME="${BASH_REMATCH[2]}"
        export GITHUB_TYPE="repository"
    else
        log_error_and_exit "Formato de URL inválido: $url" >&2
    fi
}

# Função para obter token de registro ou remoção
get_github_token() {
    local token_type="$1"  # "registration-token" ou "remove-token"
    local github_url="$2"
    local github_token="$3"
    
    # Parse da URL
    parse_github_url "$github_url"
    
    local token_url=""
    
    if [ "$GITHUB_TYPE" = "organization" ]; then
        token_url="https://api.github.com/orgs/${GITHUB_ORG_NAME}/actions/runners/${token_type}"
    elif [ "$GITHUB_TYPE" = "repository" ]; then
        token_url="https://api.github.com/repos/${GITHUB_OWNER_NAME}/${GITHUB_REPO_NAME}/actions/runners/${token_type}"
    fi
    
    local response
    response=$(curl -s -X POST \
        -H "Authorization: token ${github_token}" \
        -H "Accept: application/vnd.github.v3+json" \
        "$token_url")
    
    local token
    token=$(echo "$response" | jq -r .token 2>/dev/null)
    
    if [ "$token" = "null" ] || [ -z "$token" ]; then
        log_error "Resposta da API: $response" >&2
        log_error_and_exit "Falha ao obter ${token_type}. Verifique o token e as permissões." >&2
    fi
    
    echo "$token"
}

# ==============================================================================
# FUNÇÕES UTILITÁRIAS
# ==============================================================================

# Função para verificar se um arquivo existe
file_exists() {
    local file_path="$1"
    
    if [ -f "$file_path" ]; then
        log_debug "Arquivo encontrado: $file_path"
        return 0
    else
        log_debug "Arquivo não encontrado: $file_path"
        return 1
    fi
}

# Função para criar diretório se não existir
ensure_directory() {
    local dir_path="$1"
    local permissions="${2:-755}"
    
    if [ ! -d "$dir_path" ]; then
        log_step "Criando diretório: $dir_path"
        mkdir -p "$dir_path"
        chmod "$permissions" "$dir_path"
    else
        log_debug "Diretório já existe: $dir_path"
    fi
}

# Função para executar comando com retry
execute_with_retry() {
    local max_attempts="${1:-3}"
    local delay="${2:-5}"
    shift 2
    local cmd=("$@")
    
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_step "Tentativa $attempt/$max_attempts: ${cmd[*]}"
        
        if "${cmd[@]}"; then
            log_success "Comando executado com sucesso"
            return 0
        else
            log_warn "Falha na tentativa $attempt/$max_attempts"
            
            if [ $attempt -lt $max_attempts ]; then
                log_info "Aguardando ${delay}s antes da próxima tentativa..."
                sleep "$delay"
            fi
            
            ((attempt++))
        fi
    done
    
    log_error_and_exit "Comando falhou após $max_attempts tentativas: ${cmd[*]}"
}

# Função para cleanup de arquivos temporários
cleanup_temp_files() {
    local temp_pattern="${1:-actions-runner-linux-x64-*.tar.gz}"
    
    log_step "Limpando arquivos temporários: $temp_pattern"
    
    # shellcheck disable=SC2086
    rm -f $temp_pattern 2>/dev/null || true
    
    log_debug "Arquivos temporários removidos"
}

# ==============================================================================
# FUNÇÕES DE INICIALIZAÇÃO
# ==============================================================================

# Função para carregar a biblioteca e exibir informações
init_common_lib() {
    local script_name="${1:-Script}"
    local version="${2:-1.0.0}"
    
    log_section "Iniciando $script_name v$version"
    log_info "Biblioteca comum carregada com sucesso"
    log_info "Data/Hora: $(date)"
    log_info "Usuário: $(whoami)"
    log_info "Diretório: $(pwd)"
    log_separator
}

# ==============================================================================
# EXPORTAÇÃO DE FUNÇÕES
# ==============================================================================

# Lista de funções públicas que serão exportadas
readonly EXPORTED_FUNCTIONS=(
    log log_info log_success log_warn log_error log_debug log_step log_header
    log_error_and_exit log_separator log_section
    validate_var validate_vars validate_command validate_github_vars
    build_github_url parse_github_url get_github_token
    file_exists ensure_directory execute_with_retry cleanup_temp_files
    init_common_lib
)

# Exporta todas as funções públicas
for func in "${EXPORTED_FUNCTIONS[@]}"; do
    export -f "$func"
done

log_debug "Biblioteca comum carregada - ${#EXPORTED_FUNCTIONS[@]} funções exportadas"
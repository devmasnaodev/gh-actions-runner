#!/bin/bash

# ==============================================================================
# GitHub Actions Runners - Gerenciador Global
# ==============================================================================

set -e

# Cores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Diretório base do projeto
readonly PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly RUNNERS=("basic-runner" "deployer-runner")

# Função para log colorido
log() {
    local message="$1"
    local level="${2:-INFO}"
    local color=""
    
    case "$level" in
        "ERROR") color="$RED" ;;
        "SUCCESS") color="$GREEN" ;;
        "WARN") color="$YELLOW" ;;
        "INFO") color="$BLUE" ;;
        "HEADER") color="$PURPLE" ;;
        "STEP") color="$CYAN" ;;
    esac
    
    echo -e "${color}[$(date +'%H:%M:%S')] [$level] $message${NC}"
}

# Função para mostrar ajuda
show_help() {
    cat << EOF
🏃 GitHub Actions Runners - Gerenciador Global

USAGE:
    $0 <command> [runner] [options]

COMMANDS:
    build [runner]         - Build das imagens Docker
    start [runner]         - Inicia os runners
    stop [runner]          - Para os runners
    restart [runner]       - Reinicia os runners
    logs [runner]          - Mostra logs dos runners
    status                 - Status de todos os runners
    clean [runner]         - Limpeza completa (para + remove imagens)
    shell <runner>         - Acessa shell do runner
    health [runner]        - Verifica saúde dos runners
    update                 - Atualiza e reconstrói todos os runners

RUNNERS:
    basic-runner          - Runner básico para workflows simples
    deployer-runner       - Runner com ferramentas de deployment
    all                   - Todos os runners (padrão se não especificado)

EXAMPLES:
    $0 build basic-runner          # Build apenas do basic-runner
    $0 start                       # Inicia todos os runners
    $0 logs deployer-runner        # Logs do deployer-runner
    $0 status                      # Status de todos
    $0 clean all                   # Limpeza completa de todos

ENVIRONMENT:
    Configure os arquivos .env em cada diretório de runner antes de usar.

EOF
}

# Função para validar runner
validate_runner() {
    local runner="$1"
    
    if [ "$runner" = "all" ]; then
        return 0
    fi
    
    if [[ ! " ${RUNNERS[*]} " =~ " ${runner} " ]]; then
        log "Runner inválido: $runner" "ERROR"
        log "Runners disponíveis: ${RUNNERS[*]}, all" "INFO"
        exit 1
    fi
}

# Função para executar comando em runner(s)
execute_for_runners() {
    local command="$1"
    local target_runner="$2"
    shift 2
    
    local runners_to_process=()
    
    if [ "$target_runner" = "all" ] || [ -z "$target_runner" ]; then
        runners_to_process=("${RUNNERS[@]}")
    else
        runners_to_process=("$target_runner")
    fi
    
    for runner in "${runners_to_process[@]}"; do
        if [ -d "$PROJECT_DIR/$runner" ]; then
            log "Executando $command para $runner..." "STEP"
            cd "$PROJECT_DIR/$runner"
            
            case "$command" in
                "build")
                    if [ -f "./build.sh" ]; then
                        ./build.sh "$@"
                    else
                        docker compose build "$@"
                    fi
                    ;;
                "start")
                    docker compose up -d "$@"
                    ;;
                "stop")
                    docker compose down "$@"
                    ;;
                "restart")
                    docker compose restart "$@"
                    ;;
                "logs")
                    docker compose logs -f "$@"
                    ;;
                "clean")
                    docker compose down --rmi all --volumes "$@"
                    ;;
                "status")
                    echo -e "\n${CYAN}=== $runner ===${NC}"
                    docker compose ps
                    ;;
                "health")
                    echo -e "\n${CYAN}=== Health Check: $runner ===${NC}"
                    if docker compose ps | grep -q "Up"; then
                        container_name=$(docker compose ps --services | head -n1)
                        if [ -n "$container_name" ]; then
                            docker compose exec -T "$container_name" /home/runner/libs/bootstrap.sh > /dev/null 2>&1 && \
                            echo -e "${GREEN}✅ $runner: Healthy${NC}" || \
                            echo -e "${RED}❌ $runner: Unhealthy${NC}"
                        fi
                    else
                        echo -e "${YELLOW}⚠️  $runner: Not running${NC}"
                    fi
                    ;;
            esac
            
            cd "$PROJECT_DIR"
        else
            log "Diretório não encontrado: $runner" "WARN"
        fi
    done
}

# Função para acessar shell do runner
access_shell() {
    local runner="$1"
    
    validate_runner "$runner"
    
    if [ "$runner" = "all" ]; then
        log "Especifique um runner específico para acessar o shell" "ERROR"
        exit 1
    fi
    
    cd "$PROJECT_DIR/$runner"
    
    local container_name=$(docker compose ps --services | head -n1)
    if [ -n "$container_name" ]; then
        log "Acessando shell do $runner..." "INFO"
        docker compose exec "$container_name" /bin/bash
    else
        log "Container não encontrado para $runner" "ERROR"
        exit 1
    fi
}

# Função para update completo
update_all() {
    log "Iniciando update completo dos runners..." "HEADER"
    
    # Para todos os runners
    log "Parando runners..." "STEP"
    execute_for_runners "stop" "all"
    
    # Remove imagens antigas
    log "Removendo imagens antigas..." "STEP"
    execute_for_runners "clean" "all"
    
    # Rebuild
    log "Reconstruindo imagens..." "STEP"
    execute_for_runners "build" "all"
    
    log "Update completo finalizado!" "SUCCESS"
    log "Use '$0 start' para iniciar os runners" "INFO"
}

# Função para verificar pré-requisitos
check_prerequisites() {
    local missing_deps=()
    
    if ! command -v docker >/dev/null 2>&1; then
        missing_deps+=("docker")
    fi
    
    if ! docker compose version >/dev/null 2>&1; then
        missing_deps+=("docker compose")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log "Dependências não encontradas: ${missing_deps[*]}" "ERROR"
        log "Instale as dependências antes de continuar" "ERROR"
        exit 1
    fi
}

# Função para mostrar status detalhado
show_detailed_status() {
    log "Status detalhado dos GitHub Actions Runners" "HEADER"
    
    for runner in "${RUNNERS[@]}"; do
        if [ -d "$PROJECT_DIR/$runner" ]; then
            echo -e "\n${PURPLE}=== $runner ===${NC}"
            cd "$PROJECT_DIR/$runner"
            
            # Status dos containers
            docker compose ps
            
            # Informações da imagem
            local image_name=$(grep -E "^\s*image:" docker-compose.yml | cut -d: -f2- | tr -d ' ' | head -n1)
            if [ -n "$image_name" ]; then
                echo -e "\n${CYAN}Imagem Docker:${NC}"
                docker images "$image_name" 2>/dev/null || echo "Imagem não encontrada"
            fi
            
            # Verifica arquivo .env
            if [ -f ".env" ]; then
                echo -e "\n${GREEN}✅ Arquivo .env configurado${NC}"
            else
                echo -e "\n${YELLOW}⚠️  Arquivo .env não encontrado${NC}"
                if [ -f ".env.example" ]; then
                    echo -e "${BLUE}   Use: cp .env.example .env${NC}"
                fi
            fi
            
            cd "$PROJECT_DIR"
        fi
    done
    
    # Uso de disco das imagens Docker
    echo -e "\n${PURPLE}=== Uso de Disco ===${NC}"
    docker system df | grep -E "(TYPE|Images)"
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    local command="${1:-help}"
    local runner="${2:-all}"
    
    # Remove os dois primeiros argumentos
    shift 2 2>/dev/null || shift $# 2>/dev/null || true
    
    # Verifica pré-requisitos
    check_prerequisites
    
    case "$command" in
        "help"|"-h"|"--help")
            show_help
            ;;
        "build")
            validate_runner "$runner"
            execute_for_runners "build" "$runner" "$@"
            ;;
        "start")
            validate_runner "$runner"
            execute_for_runners "start" "$runner" "$@"
            ;;
        "stop")
            validate_runner "$runner"
            execute_for_runners "stop" "$runner" "$@"
            ;;
        "restart")
            validate_runner "$runner"
            execute_for_runners "restart" "$runner" "$@"
            ;;
        "logs")
            validate_runner "$runner"
            execute_for_runners "logs" "$runner" "$@"
            ;;
        "status")
            show_detailed_status
            ;;
        "clean")
            validate_runner "$runner"
            log "⚠️  Esta operação irá remover containers, imagens e volumes!" "WARN"
            read -p "Continuar? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                execute_for_runners "clean" "$runner" "$@"
            else
                log "Operação cancelada" "INFO"
            fi
            ;;
        "shell")
            access_shell "$runner"
            ;;
        "health")
            validate_runner "$runner"
            execute_for_runners "health" "$runner" "$@"
            ;;
        "update")
            log "⚠️  Esta operação irá parar, remover e reconstruir todos os runners!" "WARN"
            read -p "Continuar? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                update_all
            else
                log "Operação cancelada" "INFO"
            fi
            ;;
        *)
            log "Comando desconhecido: $command" "ERROR"
            log "Use '$0 help' para ver comandos disponíveis" "INFO"
            exit 1
            ;;
    esac
}

# Executa função principal
main "$@"
#!/bin/bash

# ==============================================================================
# GitHub Actions Runner - Bootstrap Library
# ==============================================================================
# Script para carregar todas as bibliotecas necessárias de forma conveniente
# ==============================================================================

# Define caminhos das bibliotecas
readonly LIB_DIR="${LIB_DIR:-./libs}"
readonly COMMON_LIB="$LIB_DIR/common.sh"
readonly RUNNER_UTILS="$LIB_DIR/runner-utils.sh"

# Função para carregar biblioteca comum
load_common_lib() {
    if [ ! -f "$COMMON_LIB" ]; then
        echo "ERRO: Biblioteca comum não encontrada em: $COMMON_LIB" >&2
        return 1
    fi
    
    # shellcheck source=/dev/null
    source "$COMMON_LIB"
    
    if [ "${RUNNER_COMMON_LIB_LOADED:-}" != "true" ]; then
        echo "ERRO: Falha ao carregar biblioteca comum" >&2
        return 1
    fi
    
    return 0
}

# Função para carregar utilitários do runner
load_runner_utils() {
    if [ ! -f "$RUNNER_UTILS" ]; then
        echo "AVISO: Utilitários do runner não encontrados em: $RUNNER_UTILS" >&2
        return 1
    fi
    
    # shellcheck source=/dev/null
    source "$RUNNER_UTILS"
    
    if [ "${RUNNER_UTILS_LOADED:-}" != "true" ]; then
        echo "ERRO: Falha ao carregar utilitários do runner" >&2
        return 1
    fi
    
    return 0
}

# Função principal do bootstrap
bootstrap_runner_libs() {
    local load_utils="${1:-true}"
    
    # Carrega biblioteca comum (obrigatória)
    if ! load_common_lib; then
        echo "ERRO: Não foi possível carregar as bibliotecas necessárias" >&2
        exit 1
    fi
    
    # Carrega utilitários do runner (opcional)
    if [ "$load_utils" = "true" ]; then
        if ! load_runner_utils; then
            log_warn "Utilitários do runner não carregados (continuando sem eles)"
        else
            log_debug "Utilitários do runner carregados com sucesso"
        fi
    fi
    
    log_debug "Bootstrap concluído - bibliotecas carregadas"
}

# Auto-execução do bootstrap se o script for executado diretamente
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    bootstrap_runner_libs "${1:-true}"
fi
#!/bin/bash

set -e

# Carrega as bibliotecas globais usando bootstrap
# shellcheck source=./libs/bootstrap.sh
source "./libs/bootstrap.sh"

# Inicializa o bootstrap (carrega common.sh e runner-utils.sh)
bootstrap_runner_libs

# Inicializa a biblioteca
init_common_lib "GitHub Actions Runner - Cleanup" "2.0.0"

log_step "Iniciando processo de limpeza do runner..."

# Verifica se o runner está configurado
if ! file_exists ".runner"; then
    log_warn "Nenhuma configuração de runner encontrada. Nada para limpar."
    exit 0
fi

# Valida variáveis necessárias para limpeza
validate_github_vars

# Constrói URL se necessário
build_github_url

# Obtém token de registro para remoção
log_step "Obtendo token para remoção do runner..."
REMOVAL_TOKEN=$(get_github_token "registration-token" "$GITHUB_URL" "$GITHUB_TOKEN")

# Remove o runner usando função segura da biblioteca
safe_remove_runner "$REMOVAL_TOKEN"

log_success "Processo de limpeza concluído!"
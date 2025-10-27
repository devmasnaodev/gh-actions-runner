# Biblioteca Comum - GitHub Actions Runner

Esta biblioteca fornece funções reutilizáveis para todos os scripts do projeto GitHub Actions Runner.

## 📁 Estrutura

```
files/
├── lib/
│   └── common.sh          # Biblioteca principal
├── entrypoint.sh          # Script principal (usa a lib)
├── cleanup.sh             # Script de limpeza (usa a lib)
└── demo-lib.sh            # Demonstração de uso
```

## 🚀 Como Usar

### 1. Carregando a Biblioteca

```bash
#!/bin/bash

# Carrega a biblioteca comum
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Inicializa a biblioteca (opcional, mas recomendado)
init_common_lib "Meu Script" "1.0.0"
```

### 2. Usando as Funções de Log

```bash
# Logs com diferentes níveis
log_info "Mensagem informativa"
log_success "Operação bem-sucedida"
log_warn "Mensagem de aviso"
log_error "Mensagem de erro"
log_debug "Informação de debug"
log_step "Etapa do processo"
log_header "Cabeçalho principal"

# Log com saída do script
log_error_and_exit "Erro crítico - saindo"

# Separadores visuais
log_separator
log_section "Título da Seção"
```

### 3. Validação de Variáveis

```bash
# Validar uma variável (obrigatória)
validate_var "MINHA_VARIAVEL"

# Validar uma variável (opcional)
validate_var "VARIAVEL_OPCIONAL" "false"

# Validar múltiplas variáveis de uma vez
validate_vars "VAR1" "VAR2" "VAR3"

# Validação específica para GitHub
validate_github_vars
```

### 4. Validação de Comandos

```bash
# Validar comando obrigatório
validate_command "docker"

# Validar comando opcional
validate_command "kubectl" "false"
```

### 5. Funções do GitHub

```bash
# Validar variáveis do GitHub (apenas PAT)
validate_github_vars

# Construir URL do GitHub automaticamente
build_github_url

# Obter token de registro/remoção
TOKEN=$(get_github_token "registration-token" "$GITHUB_URL" "$GITHUB_TOKEN")
```

### 6. Utilitários

```bash
# Verificar se arquivo existe
if file_exists "/path/to/file"; then
    log_success "Arquivo encontrado"
fi

# Criar diretório se não existir
ensure_directory "/path/to/dir" "755"

# Executar comando com retry
execute_with_retry 3 5 curl -o file.tar.gz "$URL"

# Limpeza de arquivos temporários
cleanup_temp_files "*.tar.gz"
```

## 📋 Funções Disponíveis

### Logs
- `log(message, level)` - Log genérico
- `log_info(message)` - Log informativo
- `log_success(message)` - Log de sucesso
- `log_warn(message)` - Log de aviso
- `log_error(message)` - Log de erro
- `log_debug(message)` - Log de debug
- `log_step(message)` - Log de etapa
- `log_header(message)` - Log de cabeçalho
- `log_error_and_exit(message)` - Log de erro e sai
- `log_separator(char, length)` - Separador visual
- `log_section(title, char)` - Seção com separadores

### Validação
- `validate_var(var_name, is_required)` - Valida variável
- `validate_vars(var1, var2, ...)` - Valida múltiplas variáveis
- `validate_command(cmd, is_required)` - Valida comando
- `validate_github_vars()` - Valida variáveis do GitHub

### GitHub
- `build_github_url()` - Constrói URL do GitHub
- `parse_github_url(url)` - Analisa URL do GitHub
- `get_github_token(type, url, token)` - Obtém token da API

### Utilitários
- `file_exists(path)` - Verifica se arquivo existe
- `ensure_directory(path, permissions)` - Cria diretório
- `execute_with_retry(attempts, delay, cmd...)` - Executa com retry
- `cleanup_temp_files(pattern)` - Limpa arquivos temporários
- `init_common_lib(name, version)` - Inicializa biblioteca

## 🎨 Cores e Símbolos

A biblioteca usa cores e emojis para melhorar a legibilidade:

| Nível | Cor | Emoji | Uso |
|-------|-----|--------|-----|
| ERROR | 🔴 Vermelho | ❌ | Erros |
| SUCCESS | 🟢 Verde | ✅ | Sucessos |
| WARN | 🟡 Amarelo | ⚠️ | Avisos |
| INFO | 🔵 Azul | ℹ️ | Informações |
| DEBUG | 🟣 Roxo | 🔍 | Debug |
| STEP | 🔵 Ciano | 🔄 | Etapas |
| HEADER | ⚪ Branco | 🚀 | Cabeçalhos |

## 🔧 Configuração

### Constantes Disponíveis

- `DEFAULT_RUNNER_VERSION` - Versão padrão do runner (2.329.0)
- Cores: `RED`, `GREEN`, `YELLOW`, `BLUE`, `PURPLE`, `CYAN`, `WHITE`, `NC`

### Variáveis Exportadas

A biblioteca exporta automaticamente as seguintes variáveis após `parse_github_url()`:
- `GITHUB_TYPE` - "organization" ou "repository"
- `GITHUB_ORG_NAME` - Nome da organização (se aplicável)
- `GITHUB_OWNER_NAME` - Nome do owner (se repositório)
- `GITHUB_REPO_NAME` - Nome do repositório (se aplicável)

## 🔄 Vantagens da Biblioteca

1. **Reutilização**: Evita duplicação de código
2. **Consistência**: Logs padronizados em todos os scripts
3. **Manutenibilidade**: Mudanças centralizadas
4. **Robustez**: Funções testadas e confiáveis
5. **Legibilidade**: Códigos mais limpos e organizados
6. **Extensibilidade**: Fácil adicionar novas funções
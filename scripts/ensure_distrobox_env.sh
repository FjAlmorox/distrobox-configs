#!/usr/bin/env bash
# ==============================================================================
# ensure_distrobox_env.sh
# 
# Script de automatización, inspección y aprovisionamiento de componentes para
# contenedores Distrobox en Fedora Workstation / Host Linux.
#
# Diseñado para ser invocado tanto por Agentes de IA como por Desarrolladores.
#
# Principios clave:
# 1. Ejecución 100% aislada: Las instalaciones y cambios se hacen DENTRO del contenedor.
# 2. Justificación obligatoria: Exige registrar 'POR QUÉ' y 'PARA QUÉ' se instala algo.
# 3. Inspección previa: Inspecciona runtimes y herramientas existentes antes de tocar nada.
# 4. Política Anti-Degradación: Impide degradar versiones de runtime arbitrariamente.
# 5. Prioridad a la versión estable más reciente (Latest Stable).
# 6. Comprobación y Smoke Test: Valida el componente inmediatamente tras la instalación.
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DISTROBOX_CONFIGS_DIR="$WORKSPACE_ROOT/distrobox-configs"

# Colores para salida de terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Valores por defecto
CONTAINER=""
ACTION="check"
COMPONENT=""
TARGET_VERSION=""
WHY=""
FOR_WHAT=""
PROJECT_DIR=""
FORCE_DOWNGRADE=false
VERBOSE=false

show_help() {
    cat << EOF
${BOLD}Uso:${NC} $(basename "$0") [opciones]

${BOLD}Opciones principales:${NC}
  -c, --container <nombre>     Nombre del contenedor Distrobox (node-dev, python-dev, java-dev, android-dev)
  -a, --action <acción>        Acción a realizar:
                                 • check   : Inspecciona el estado actual del contenedor y herramientas
                                 • install : Instala un componente/dependencia (requiere --why y --for-what)
                                 • verify  : Ejecuta smoke tests sobre el entorno o proyecto
  -p, --project-dir <ruta>     Ruta del proyecto a evaluar (dentro de \$HOME/Workspace)
  --component <nombre>         Componente a instalar/gestionar:
                                 • runtime (Node, Python, Java según contenedor)
                                 • system-pkg (paquete dnf del sistema dentro del contenedor)
                                 • uv-tool (herramienta CLI global en python-dev)
                                 • npm-global (paquete global npm/pnpm en node-dev)
  -v, --version <versión>      Versión deseada (por defecto: latest-stable)
  --why <motivo>               [OBLIGATORIO en install] Justificación: ¿Por qué es necesario?
  --for-what <propósito>       [OBLIGATORIO en install] Utilidad: ¿Para qué se va a usar?
  --force-downgrade            Permite forzar una versión inferior a la actualmente instalada
  --verbose                    Muestra trazas detalladas de depuración
  -h, --help                   Muestra esta ayuda y finaliza

${BOLD}Ejemplos de uso por un Agente de IA:${NC}
  1. Inspeccionar python-dev antes de trabajar en un backend:
     $(basename "$0") -c python-dev -a check

  2. Comprobar entorno para el frontend de un proyecto:
     $(basename "$0") -c node-dev -p "$WORKSPACE_ROOT/tale-forge/frontend" -a check

  3. Instalar una librería del sistema requerida por un paquete nativo de Python:
     $(basename "$0") -c python-dev -a install --component system-pkg --version "libpq-devel" \\
       --why "Compilación nativa del driver psycopg2 para conexión a PostgreSQL" \\
       --for-what "Permitir comunicación de SQLAlchemy con base de datos relacional"

  4. Actualizar o asegurar runtime de Node.js en node-dev:
     $(basename "$0") -c node-dev -a install --component runtime --version "24" \\
       --why "Requerido por Vite 6 y TypeScript 5.8 para soporte de imports nativos" \\
       --for-what "Compilación y bundle del frontend React"
EOF
}

log_info() {
    echo -e "${BLUE}ℹ️  [INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅ [OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠️  [WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}❌ [ERROR]${NC} $1" >&2
}

log_box() {
    echo -e "\n${CYAN}======================================================${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${CYAN}======================================================${NC}"
}

# Parseo de argumentos
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--container)
            CONTAINER="$2"
            shift 2
            ;;
        -a|--action)
            ACTION="$2"
            shift 2
            ;;
        -p|--project-dir)
            PROJECT_DIR="$2"
            shift 2
            ;;
        --component)
            COMPONENT="$2"
            shift 2
            ;;
        -v|--version)
            TARGET_VERSION="$2"
            shift 2
            ;;
        --why)
            WHY="$2"
            shift 2
            ;;
        --for-what)
            FOR_WHAT="$2"
            shift 2
            ;;
        --force-downgrade)
            FORCE_DOWNGRADE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Argumento desconocido: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validación de parámetros básicos
if [ -z "$CONTAINER" ]; then
    log_error "Debe especificar el contenedor objetivo con -c o --container (ej: node-dev, python-dev, java-dev, android-dev)."
    exit 1
fi

# Validar que el contenedor esté soportado en distrobox.ini
INI_FILE="$DISTROBOX_CONFIGS_DIR/distrobox.ini"
if [ -f "$INI_FILE" ]; then
    if ! grep -q "^\[$CONTAINER\]" "$INI_FILE"; then
        log_error "El contenedor '$CONTAINER' no está declarado en $INI_FILE."
        exit 1
    fi
fi

# Asegurar que distrobox está disponible en el host
if ! command -v distrobox >/dev/null 2>&1; then
    log_error "distrobox no está disponible en el sistema host. Instálelo con 'sudo dnf install distrobox'."
    exit 1
fi

# 1. Comprobar si el contenedor existe en distrobox list
check_or_create_container() {
    log_info "Verificando estado del contenedor '$CONTAINER' en Distrobox..."
    if ! distrobox list | grep -q "[[:space:]]$CONTAINER[[:space:]]"; then
        log_warn "El contenedor '$CONTAINER' no existe actualmente."
        log_info "Creando contenedor '$CONTAINER' usando distrobox-configs/create.sh..."
        if [ -x "$DISTROBOX_CONFIGS_DIR/create.sh" ]; then
            bash "$DISTROBOX_CONFIGS_DIR/create.sh" "$CONTAINER"
        else
            distrobox assemble create --file "$INI_FILE" --name "$CONTAINER"
        fi
        
        # Ejecutar provisioning inicial si existe setup.sh
        local setup_file="$DISTROBOX_CONFIGS_DIR/$CONTAINER/setup.sh"
        if [ -f "$setup_file" ]; then
            log_info "Ejecutando aprovisionamiento inicial (setup.sh) en '$CONTAINER'..."
            distrobox enter "$CONTAINER" -- bash -lc "bash '$setup_file'"
        fi
    else
        log_success "El contenedor '$CONTAINER' existe en Distrobox."
    fi
}

# Ejecutar comando dentro del contenedor de manera segura y no interactiva
run_in_container() {
    local cmd="$1"
    distrobox enter "$CONTAINER" -- bash -lc "$cmd"
}

# 2. Función de inspección de versiones y entorno
inspect_environment() {
    log_box "🔍 Inspección del Entorno: $CONTAINER"
    
    # Comprobar si change_version está instalado
    echo -e "${BOLD}1. Diagnóstico de runtime principal (change_version):${NC}"
    if run_in_container "command -v change_version >/dev/null 2>&1"; then
        run_in_container "change_version"
    else
        log_warn "change_version no encontrado en PATH del contenedor. Verificando herramientas base manualmente..."
        case "$CONTAINER" in
            node-dev)
                run_in_container "node -v 2>/dev/null || echo 'Node: No instalado'"
                run_in_container "pnpm -v 2>/dev/null || echo 'pnpm: No instalado'"
                run_in_container "bun -v 2>/dev/null || echo 'bun: No instalado'"
                ;;
            python-dev)
                run_in_container "python3 --version 2>/dev/null || echo 'Python: No instalado'"
                run_in_container "uv --version 2>/dev/null || echo 'uv: No instalado'"
                ;;
            java-dev)
                run_in_container "java -version 2>&1 | head -n 1 || echo 'Java: No instalado'"
                ;;
            android-dev)
                run_in_container "sdkmanager --version 2>/dev/null || echo 'sdkmanager: No instalado'"
                ;;
        esac
    fi

    # Comprobar configuración del proyecto si se especificó ruta
    if [ -n "$PROJECT_DIR" ]; then
        echo ""
        echo -e "${BOLD}2. Detección de configuración de proyecto en '$PROJECT_DIR':${NC}"
        if [ ! -d "$PROJECT_DIR" ]; then
            log_warn "El directorio de proyecto '$PROJECT_DIR' no existe en el sistema de archivos."
        else
            case "$CONTAINER" in
                node-dev)
                    if [ -f "$PROJECT_DIR/package.json" ]; then
                        log_info "package.json detectado."
                        if [ -f "$PROJECT_DIR/.nvmrc" ]; then
                            log_info "Versión requerida por .nvmrc: $(cat "$PROJECT_DIR/.nvmrc")"
                        fi
                        if [ -f "$PROJECT_DIR/.node-version" ]; then
                            log_info "Versión requerida por .node-version: $(cat "$PROJECT_DIR/.node-version")"
                        fi
                        # Mostrar scripts útiles
                        grep -E '"(scripts|dependencies|devDependencies)":' "$PROJECT_DIR/package.json" -A 5 2>/dev/null || true
                    fi
                    ;;
                python-dev)
                    if [ -f "$PROJECT_DIR/pyproject.toml" ]; then
                        log_info "pyproject.toml detectado."
                        grep -E 'requires-python' "$PROJECT_DIR/pyproject.toml" || true
                    fi
                    if [ -f "$PROJECT_DIR/.python-version" ]; then
                        log_info "Versión fijada por .python-version: $(cat "$PROJECT_DIR/.python-version")"
                    fi
                    ;;
                java-dev|android-dev)
                    if [ -f "$PROJECT_DIR/build.gradle.kts" ] || [ -f "$PROJECT_DIR/build.gradle" ]; then
                        log_info "Proyecto Gradle detectado."
                    fi
                    ;;
            esac
        fi
    fi
}

# 3. Lógica de comparación de versiones para evitar degradaciones
# Retorna: 0 si la versión actual es mayor o igual (no degradar), 1 si se permite actualizar/instalar
check_version_downgrade() {
    local current="$1"
    local requested="$2"

    if [ "$FORCE_DOWNGRADE" = true ]; then
        log_warn "Degradación forzada activada por el usuario/agente (--force-downgrade)."
        return 0
    fi

    # Si no hay versión previa, no hay degradación
    if [ -z "$current" ]; then
        return 0
    fi

    # Limpieza de prefijos como 'v' o 'Python '
    local clean_cur
    clean_cur=$(echo "$current" | grep -oE '[0-9]+(\.[0-9]+)*' | head -n 1)
    local clean_req
    clean_req=$(echo "$requested" | grep -oE '[0-9]+(\.[0-9]+)*' | head -n 1)

    if [ -z "$clean_cur" ] || [ -z "$clean_req" ]; then
        return 0
    fi

    if [ "$clean_cur" == "$clean_req" ]; then
        log_info "La versión solicitada ($clean_req) ya es la versión activa actual ($clean_cur). No requiere cambios."
        return 1
    fi

    # Comparar versiones usando sort -V
    local highest
    highest=$(printf "%s\n%s" "$clean_cur" "$clean_req" | sort -V | tail -n 1)

    if [ "$highest" == "$clean_cur" ]; then
        log_error "POLÍTICA ANTI-DEGRADACIÓN: La versión actual en el contenedor ($clean_cur) es SUPERIOR a la solicitada ($clean_req)."
        log_error "No se permite degradar el contenedor automáticamente."
        log_error "Si esta degradación es estrictamente necesaria por incompatibilidad del proyecto, pase el flag '--force-downgrade' junto con la justificación técnica."
        return 1
    else
        log_info "Actualización válida: versión actual ($clean_cur) -> nueva versión ($clean_req)."
        return 0
    fi
}

# 4. Proceso de instalación justificada
install_component() {
    log_box "📦 Instalación Justificada de Componente en: $CONTAINER"

    # Verificar justificación obligatoria
    if [ -z "$WHY" ] || [ -z "$FOR_WHAT" ]; then
        log_error "JUSTIFICACIÓN REQUERIDA OBLIGATORIA:"
        log_error "Cualquier instalación o cambio de configuración dentro de la Distrobox debe indicar:"
        log_error "  --why      : ¿Por qué es necesario este componente/cambio?"
        log_error "  --for-what : ¿Para qué tarea o funcionalidad se va a emplear?"
        exit 1
    fi

    echo -e "${BOLD}📋 Registro de Justificación Técnica:${NC}"
    echo -e "   • ${CYAN}Componente:${NC} $COMPONENT ${TARGET_VERSION:+(versión: $TARGET_VERSION)}"
    echo -e "   • ${CYAN}¿Por qué?  :${NC} $WHY"
    echo -e "   • ${CYAN}¿Para qué? :${NC} $FOR_WHAT"
    echo ""

    case "$COMPONENT" in
        runtime)
            case "$CONTAINER" in
                node-dev)
                    local current_node
                    current_node=$(run_in_container "node -v 2>/dev/null" || true)
                    local target="${TARGET_VERSION:-24}"
                    
                    if check_version_downgrade "$current_node" "$target"; then
                        log_info "Instalando/activando Node.js $target vía change_version..."
                        run_in_container "change_version '$target'"
                    fi
                    ;;
                python-dev)
                    local current_py
                    current_py=$(run_in_container "python3 --version 2>/dev/null" || true)
                    local target="${TARGET_VERSION:-3.13}"
                    
                    if check_version_downgrade "$current_py" "$target"; then
                        log_info "Instalando/activando Python $target vía change_version..."
                        run_in_container "change_version '$target'"
                    fi
                    ;;
                java-dev)
                    local current_java
                    current_java=$(run_in_container "java -version 2>&1 | head -n 1" || true)
                    local target="${TARGET_VERSION:-21}"
                    
                    if check_version_downgrade "$current_java" "$target"; then
                        log_info "Instalando/activando Java $target vía change_version..."
                        run_in_container "change_version '$target'"
                    fi
                    ;;
                android-dev)
                    local target="${TARGET_VERSION:-35}"
                    log_info "Instalando Android API $target vía change_version..."
                    run_in_container "change_version '$target'"
                    ;;
            esac
            ;;

        system-pkg)
            if [ -z "$TARGET_VERSION" ]; then
                log_error "Debe especificar el nombre del paquete del sistema en --version (ej: --version 'libpq-devel openssl-devel')."
                exit 1
            fi
            log_info "Comprobando paquetes del sistema dentro del contenedor Fedora..."
            # Instalar con sudo dnf dentro del contenedor (sin contraseña gracias a Distrobox)
            run_in_container "sudo dnf install -y $TARGET_VERSION"
            ;;

        uv-tool)
            if [ "$CONTAINER" != "python-dev" ]; then
                log_error "Las herramientas uv-tool sólo deben instalarse en el contenedor 'python-dev'."
                exit 1
            fi
            if [ -z "$TARGET_VERSION" ]; then
                log_error "Especifique el nombre de la herramienta uv a instalar en --version (ej: --version 'ruff')."
                exit 1
            fi
            log_info "Instalando herramienta global aislada con 'uv tool install $TARGET_VERSION'..."
            run_in_container "uv tool install --upgrade $TARGET_VERSION"
            ;;

        npm-global)
            if [ "$CONTAINER" != "node-dev" ]; then
                log_error "Los paquetes globales de npm/pnpm sólo deben instalarse en 'node-dev'."
                exit 1
            fi
            if [ -z "$TARGET_VERSION" ]; then
                log_error "Especifique el paquete a instalar en --version."
                exit 1
            fi
            log_info "Instalando paquete global con pnpm en 'node-dev'..."
            run_in_container "pnpm add -g $TARGET_VERSION"
            ;;

        *)
            log_error "Componente desconocido '$COMPONENT'. Opciones válidas: runtime, system-pkg, uv-tool, npm-global."
            exit 1
            ;;
    esac

    # Comprobación inmediata
    verify_component
}

# 5. Verificación / Smoke tests
verify_component() {
    log_box "🧪 Smoke Tests & Verificación Post-Instalación"
    case "$CONTAINER" in
        node-dev)
            log_info "Verificando suite Node.js, pnpm, bun..."
            run_in_container "node -v && pnpm -v && bun -v"
            log_success "Entorno node-dev operativo y validado."
            ;;
        python-dev)
            log_info "Verificando Python, uv y compilador C..."
            run_in_container "python3 --version && uv --version && gcc --version | head -n 1"
            log_success "Entorno python-dev operativo y validado."
            ;;
        java-dev)
            log_info "Verificando OpenJDK y Gradle..."
            run_in_container "java -version 2>&1 | head -n 1"
            log_success "Entorno java-dev operativo y validado."
            ;;
        android-dev)
            log_info "Verificando Android SDK Tools..."
            run_in_container "adb version | head -n 1"
            log_success "Entorno android-dev operativo y validado."
            ;;
    esac
}

# Flujo principal
check_or_create_container

case "$ACTION" in
    check)
        inspect_environment
        ;;
    install)
        install_component
        ;;
    verify)
        verify_component
        ;;
    *)
        log_error "Acción no reconocida: '$ACTION'. Use check, install o verify."
        exit 1
        ;;
esac

log_box "✨ Operación completada con éxito en '$CONTAINER'"
exit 0

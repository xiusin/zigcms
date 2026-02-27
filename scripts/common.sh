#!/bin/sh
# =============================================================================
# ZigCMS 通用脚本工具库
# =============================================================================
# 提供统一的颜色定义、错误处理和常用函数
# POSIX 兼容，支持 macOS 和 Linux
# =============================================================================

# 严格模式
set -e

# =============================================================================
# 颜色定义 (POSIX 兼容)
# =============================================================================
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    PURPLE=''
    CYAN=''
    WHITE=''
    BOLD=''
    NC=''
fi

# =============================================================================
# 图标定义 (Unicode)
# =============================================================================
CHECK_MARK="✓"
CROSS_MARK="✗"
WARNING_ICON="⚠"
INFO_ICON="ℹ"
ROCKET_ICON="🚀"
GEAR_ICON="⚙"
FOLDER_ICON="📁"
LOCK_ICON="🔐"
DOWNLOAD_ICON="📥"
TEST_ICON="🧪"
CLEAN_ICON="🧹"
BUILD_ICON="🔨"
WATCH_ICON="👀"
CLOCK_ICON="⏱"

# =============================================================================
# 全局变量
# =============================================================================
VERBOSE="${VERBOSE:-false}"
SCRIPT_START_TIME=""
OS_TYPE=""

# =============================================================================
# 输出函数 - 统一颜色输出
# =============================================================================

# 打印错误消息并退出
error_exit() {
    printf "${RED}${CROSS_MARK} 错误: %s${NC}\n" "$1" >&2
    exit "${2:-1}"
}

# 打印错误消息 (不退出)
error() {
    printf "${RED}${CROSS_MARK} %s${NC}\n" "$1" >&2
}

# 打印成功消息
success() {
    printf "${GREEN}${CHECK_MARK} %s${NC}\n" "$1"
}

# 打印警告消息
warning() {
    printf "${YELLOW}${WARNING_ICON} %s${NC}\n" "$1"
}

# 打印信息消息
info() {
    printf "${BLUE}${INFO_ICON} %s${NC}\n" "$1"
}

# 打印调试消息 (仅在 VERBOSE 模式)
debug() {
    if [ "$VERBOSE" = "true" ]; then
        printf "${CYAN}[DEBUG] %s${NC}\n" "$1"
    fi
}

# =============================================================================
# 进程管理工具
# =============================================================================

# 只关闭指定可执行路径的 zigcms 进程，避免误杀其他程序
kill_running_zigcms() {
    local exe_path="$1"
    if [ -z "$exe_path" ] || [ ! -x "$exe_path" ]; then
        return
    fi

    # pgrep -fl 会列出 PID 和完整命令行，精确匹配 exe_path
    if ! command_exists pgrep; then
        warning "pgrep 不可用，跳过进程清理"
        return
    fi

    local pids
    pids=$(pgrep -fl "$exe_path" | awk '{print $1}')
    if [ -z "$pids" ]; then
        return
    fi

    for pid in $pids; do
        if [ "$pid" != "$$" ]; then
            kill "$pid" 2>/dev/null || true
        fi
    done
}

# 打印标题
title() {
    printf "\n${BLUE}${BOLD}"
    printf "╔═══════════════════════════════════════════════════════════╗\n"
    printf "║ %-57s ║\n" "$1"
    printf "╚═══════════════════════════════════════════════════════════╝${NC}\n\n"
}

# 打印子标题
subtitle() {
    printf "${CYAN}${BOLD}▶ %s${NC}\n" "$1"
}

# 打印步骤
step() {
    printf "${PURPLE}  → %s${NC}\n" "$1"
}

# =============================================================================
# 错误处理函数
# =============================================================================

# 设置错误陷阱
setup_error_trap() {
    trap 'handle_error $? $LINENO' ERR 2>/dev/null || true
    trap 'cleanup_on_exit' EXIT
}

# 错误处理器
handle_error() {
    local exit_code="$1"
    local line_number="$2"
    error "脚本在第 ${line_number} 行发生错误 (退出码: ${exit_code})"
}

# 退出时清理
cleanup_on_exit() {
    local exit_code=$?
    if [ -n "$SCRIPT_START_TIME" ] && [ "$exit_code" -eq 0 ]; then
        show_elapsed_time
    fi
    return $exit_code
}

# =============================================================================
# 系统检测函数
# =============================================================================

# 检测操作系统类型
detect_os() {
    case "$(uname -s)" in
        Linux*)  OS_TYPE="linux" ;;
        Darwin*) OS_TYPE="macos" ;;
        MINGW*|MSYS*|CYGWIN*) OS_TYPE="windows" ;;
        *)       OS_TYPE="unknown" ;;
    esac
    debug "检测到操作系统: $OS_TYPE"
}

# 获取操作系统类型
get_os() {
    if [ -z "$OS_TYPE" ]; then
        detect_os
    fi
    echo "$OS_TYPE"
}

# =============================================================================
# 命令检查函数
# =============================================================================

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查命令并显示版本
check_command() {
    local cmd="$1"
    local required="${2:-true}"
    
    if command_exists "$cmd"; then
        local version
        version=$("$cmd" --version 2>/dev/null | head -1 || echo "版本未知")
        success "$cmd 已安装: $version"
        return 0
    else
        if [ "$required" = "true" ]; then
            error_exit "$cmd 未安装，请先安装后再运行"
        else
            warning "$cmd 未安装 (可选)"
            return 1
        fi
    fi
}

# 检查 Zig 编译器
check_zig() {
    if ! command_exists "zig"; then
        error_exit "Zig 编译器未安装\n请访问 https://ziglang.org/download/ 下载安装"
    fi
    local version
    version=$(zig version 2>/dev/null || echo "未知")
    success "Zig 编译器: $version"
}

# =============================================================================
# 文件和目录操作
# =============================================================================

# 检查文件是否存在
check_file() {
    local file="$1"
    if [ -f "$file" ]; then
        debug "文件存在: $file"
        return 0
    else
        debug "文件不存在: $file"
        return 1
    fi
}

# 检查目录是否存在
check_dir() {
    local dir="$1"
    if [ -d "$dir" ]; then
        debug "目录存在: $dir"
        return 0
    else
        debug "目录不存在: $dir"
        return 1
    fi
}

# 确保目录存在
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        debug "创建目录: $dir"
    fi
}

# 安全删除文件或目录
safe_remove() {
    local path="$1"
    if [ -e "$path" ]; then
        rm -rf "$path"
        debug "删除: $path"
    fi
}

# =============================================================================
# 环境配置函数
# =============================================================================

# 获取脚本目录
get_script_dir() {
    local script_path
    # POSIX 兼容方式获取脚本目录
    script_path="$(cd "$(dirname "$0")" && pwd)"
    echo "$script_path"
}

# 获取项目根目录
get_project_root() {
    local script_dir
    script_dir="$(get_script_dir)"
    dirname "$script_dir"
}

# 检查 .env 文件
check_env_file() {
    local project_root
    project_root="$(get_project_root)"
    
    if [ -f "$project_root/.env" ]; then
        debug ".env 文件已存在"
        return 0
    elif [ -f "$project_root/.env.example" ]; then
        cp "$project_root/.env.example" "$project_root/.env"
        success "已从 .env.example 创建 .env 文件"
        return 0
    else
        warning ".env 文件不存在"
        return 1
    fi
}

# 加载配置文件
load_config() {
    local config_file
    config_file="$(get_script_dir)/config.sh"
    
    if [ -f "$config_file" ]; then
        # shellcheck disable=SC1090
        . "$config_file"
        debug "已加载配置文件: $config_file"
    else
        debug "配置文件不存在，使用默认设置"
    fi
}

# =============================================================================
# 计时函数
# =============================================================================

# 开始计时
timer_start() {
    SCRIPT_START_TIME=$(date +%s)
}

# 显示耗时
show_elapsed_time() {
    if [ -z "$SCRIPT_START_TIME" ]; then
        return
    fi
    
    local end_time
    local duration
    local minutes
    local seconds
    
    end_time=$(date +%s)
    duration=$((end_time - SCRIPT_START_TIME))
    minutes=$((duration / 60))
    seconds=$((duration % 60))
    
    if [ "$minutes" -gt 0 ]; then
        success "${CLOCK_ICON} 耗时: ${minutes}分${seconds}秒"
    else
        success "${CLOCK_ICON} 耗时: ${seconds}秒"
    fi
}

# =============================================================================
# Zig 构建函数
# =============================================================================

# 执行 Zig 构建
zig_build() {
    debug "执行: zig build $*"
    if ! zig build "$@"; then
        error_exit "Zig 构建失败"
    fi
}

# 执行 Zig 测试
zig_test() {
    debug "执行: zig build test $*"
    if zig build test "$@"; then
        success "所有测试通过"
        return 0
    else
        warning "部分测试失败"
        return 1
    fi
}

# =============================================================================
# 参数解析函数
# =============================================================================

# 显示通用帮助信息
show_common_help() {
    local script_name="$1"
    local description="$2"
    
    cat << EOF
${script_name} - ${description}

通用选项:
  -h, --help      显示帮助信息
  -v, --verbose   详细输出模式
  --no-color      禁用彩色输出

EOF
}

# 解析通用参数
parse_common_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            --no-color)
                NO_COLOR="1"
                RED='' GREEN='' YELLOW='' BLUE='' PURPLE='' CYAN='' WHITE='' BOLD='' NC=''
                shift
                ;;
            *)
                break
                ;;
        esac
    done
}

# =============================================================================
# 初始化函数
# =============================================================================

# 初始化脚本环境
init_script() {
    detect_os
    load_config
    setup_error_trap
    timer_start
}

# =============================================================================
# 导出变量和函数 (供子脚本使用)
# =============================================================================
export VERBOSE
export OS_TYPE
export NO_COLOR

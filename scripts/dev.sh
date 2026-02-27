#!/bin/sh
# =============================================================================
# ZigCMS 开发环境启动脚本
# =============================================================================
# 支持文件监视热重载 (需要 fswatch)
# POSIX 兼容，支持 macOS 和 Linux
# =============================================================================

set -e

# 导入通用工具库
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/common.sh"

# =============================================================================
# 默认配置
# =============================================================================
DEFAULT_HOST="127.0.0.1"
DEFAULT_PORT="3000"
EXE_NAME="zigcms"

# =============================================================================
# 帮助信息
# =============================================================================
show_help() {
    cat << 'EOF'
ZigCMS 开发环境启动脚本

用法:
  ./dev.sh [选项]

选项:
  -h, --help          显示此帮助信息
  -v, --verbose       详细输出模式
  -p, --port PORT     指定服务器端口 (默认: 8080)
  -H, --host HOST     指定服务器主机 (默认: 127.0.0.1)
  --no-build          跳过构建步骤
  --clean             清理后重新构建
  --watch             启用文件监视热重载 (需要 fswatch)
  --no-color          禁用彩色输出

示例:
  ./dev.sh                        # 正常启动开发环境
  ./dev.sh --port 3000            # 指定端口启动
  ./dev.sh --watch                # 启用文件监视热重载
  ./dev.sh --clean                # 清理后构建并启动
  ./dev.sh --no-build             # 跳过构建直接启动

文件监视说明:
  --watch 选项需要安装 fswatch 工具:
  - macOS: brew install fswatch
  - Linux: apt install fswatch 或从源码编译

EOF
    exit 0
}

# =============================================================================
# 文件监视函数
# =============================================================================

# 检查 fswatch 是否可用
check_fswatch() {
    if command_exists "fswatch"; then
        success "fswatch 已安装"
        return 0
    else
        warning "fswatch 未安装，无法启用文件监视模式"
        info "安装方法:"
        info "  macOS: brew install fswatch"
        info "  Linux: apt install fswatch"
        return 1
    fi
}

# 启动文件监视器
start_file_watcher() {
    local exe_path="$1"
    local server_pid=""
    
    subtitle "${WATCH_ICON} 启动文件监视模式"
    info "修改源代码将自动重新构建并重启服务器"
    info "按 Ctrl+C 停止"
    printf "\n"
    
    # 启动初始服务器
    "$exe_path" &
    server_pid=$!
    success "服务器已启动 (PID: $server_pid)"
    
    # 监视文件变化
    fswatch -r . \
        --exclude=".zig-cache" \
        --exclude="zig-out" \
        --exclude="logs" \
        --exclude="*.log" \
        --exclude="*.tmp" \
        --exclude=".git" \
        --exclude="node_modules" \
        --exclude="*.db" \
        --exclude="*.db-*" \
        --latency=2 | while read -r changed_file; do
        
        printf "\n${YELLOW}${WATCH_ICON} 检测到文件变化: %s${NC}\n" "$changed_file"
        printf "${BLUE}🔄 重新构建并重启服务器...${NC}\n"
        
        # 停止当前服务器
        if [ -n "$server_pid" ]; then
            kill "$server_pid" 2>/dev/null || true
            wait "$server_pid" 2>/dev/null || true
        fi
        
        # 重新构建
        if zig build 2>&1; then
            # 启动新服务器
            "$exe_path" &
            server_pid=$!
            printf "${GREEN}${CHECK_MARK} 服务器重启成功 (PID: %s)${NC}\n" "$server_pid"
        else
            printf "${RED}${CROSS_MARK} 构建失败，等待下次文件变化...${NC}\n"
        fi
    done
}

# =============================================================================
# 主函数
# =============================================================================
main() {
    local host="$DEFAULT_HOST"
    local port="$DEFAULT_PORT"
    local no_build="false"
    local clean_build="false"
    local watch_mode="false"
    
    # 解析参数
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_help
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            -p|--port)
                port="$2"
                shift 2
                ;;
            -H|--host)
                host="$2"
                shift 2
                ;;
            --no-build)
                no_build="true"
                shift
                ;;
            --clean)
                clean_build="true"
                shift
                ;;
            --watch)
                watch_mode="true"
                shift
                ;;
            --no-color)
                NO_COLOR="1"
                RED='' GREEN='' YELLOW='' BLUE='' PURPLE='' CYAN='' WHITE='' BOLD='' NC=''
                shift
                ;;
            *)
                error_exit "未知参数: $1\n运行 './dev.sh --help' 查看帮助"
                ;;
        esac
    done
    
    # 初始化
    init_script
    
    # 显示标题
    title "启动 ZigCMS 开发环境"
    
    # 检查环境
    check_zig
    check_env_file || true
    
    # 检查文件监视模式
    if [ "$watch_mode" = "true" ]; then
        if ! check_fswatch; then
            watch_mode="false"
        fi
    fi
    
    # 构建项目
    if [ "$clean_build" = "true" ]; then
        subtitle "${CLEAN_ICON} 清理后重新构建"
        safe_remove ".zig-cache"
        safe_remove "zig-out"
        zig_build
    elif [ "$no_build" = "false" ]; then
        subtitle "${BUILD_ICON} 构建项目"
        zig_build
    else
        info "跳过构建步骤"
    fi
    
    # 检查可执行文件
    local exe_path="zig-out/bin/$EXE_NAME"
    if [ ! -f "$exe_path" ]; then
        error_exit "未找到可执行文件: $exe_path\n请先运行构建"
    fi
    success "可执行文件就绪: $exe_path"
    
    # 设置环境变量
    export ZIGCMS_HOST="$host"
    export ZIGCMS_API_PORT="$port"
    export ZIGCMS_ENV="development"
    
    debug "服务器配置: $host:$port"
    debug "环境: development"
    
    # 启动服务器
    if [ "$watch_mode" = "true" ]; then
        start_file_watcher "$exe_path"
    else
        subtitle "${ROCKET_ICON} 启动服务器"
        printf "${GREEN}服务器地址: http://%s:%s${NC}\n" "$host" "$port"
        printf "${YELLOW}按 Ctrl+C 停止服务器${NC}\n\n"
        
        # 直接执行服务器
        exec "$exe_path"
    fi
}

# 运行主函数
main "$@"

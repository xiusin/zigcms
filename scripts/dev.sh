#!/usr/bin/env bash
# ZigCMS 开发环境启动脚本
# 提供完整的开发环境支持

SCRIPT_DESCRIPTION="ZigCMS 开发环境启动脚本"

# 导入通用工具库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 默认配置
DEFAULT_PORT="8080"
DEFAULT_HOST="127.0.0.1"

# 初始化脚本环境
init_script_env

# 解析参数
parse_common_args "$@"

# 显示帮助信息
show_dev_help() {
    cat << EOF
${0} - ${SCRIPT_DESCRIPTION}

用法:
  ./${0} [选项]

选项:
  -h, --help          显示此帮助信息
  -v, --verbose       详细输出模式
  -p, --port PORT     指定服务器端口 (默认: ${DEFAULT_PORT})
  -H, --host HOST     指定服务器主机 (默认: ${DEFAULT_HOST})
  --no-build          跳过构建步骤
  --clean-build       清理后重新构建
  --watch             启用文件监听模式 (需要 fswatch)

示例:
  ./${0}                           # 正常启动开发环境
  ./${0} --port 3000               # 指定端口启动
  ./${0} --watch                   # 启用文件监听
  ./${0} --clean-build             # 清理后构建并启动

EOF
}

# 解析开发脚本特定参数
parse_dev_args() {
    PORT="$DEFAULT_PORT"
    HOST="$DEFAULT_HOST"
    NO_BUILD=false
    CLEAN_BUILD=false
    WATCH_MODE=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_dev_help
                exit 0
                ;;
            -p|--port)
                PORT="$2"
                shift 2
                ;;
            -H|--host)
                HOST="$2"
                shift 2
                ;;
            --no-build)
                NO_BUILD=true
                shift
                ;;
            --clean-build)
                CLEAN_BUILD=true
                shift
                ;;
            --watch)
                WATCH_MODE=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
}

# 主函数
main() {
    # 解析参数
    parse_dev_args "$@"

    title "启动 ZigCMS 开发环境"

    # 检查 Zig 环境
    check_zig

    # 检查 .env 文件
    check_env_file

    # 决定构建策略
    if [ "$CLEAN_BUILD" = true ]; then
        subtitle "🧹 清理后重新构建"
        safe_remove ".zig-cache"
        safe_remove "zig-out"
    elif [ "$NO_BUILD" = false ]; then
        subtitle "🔨 构建项目"
    fi

    # 构建项目（除非跳过）
    if [ "$NO_BUILD" = false ]; then
        timer_start
        zig_build
        timer_end
    fi

    # 检查可执行文件
    local exe_path="zig-out/bin/vendor"
    if [ ! -f "$exe_path" ]; then
        error_exit "未找到可执行文件: $exe_path"
    fi

    success "可执行文件就绪: $exe_path"

    # 设置环境变量
    export ZIGCMS_PORT="$PORT"
    export ZIGCMS_HOST="$HOST"
    export ZIGCMS_ENV="development"

    verbose_echo "服务器配置: $HOST:$PORT"
    verbose_echo "环境: development"

    # 文件监听模式
    if [ "$WATCH_MODE" = true ]; then
        if ! command -v fswatch &> /dev/null; then
            warning "fswatch 未安装，无法启用文件监听模式"
            warning "请安装 fswatch: brew install fswatch"
            WATCH_MODE=false
        fi
    fi

    if [ "$WATCH_MODE" = true ]; then
        subtitle "👀 启动文件监听模式"
        info "修改源代码将自动重启服务器"
        echo ""

        # 启动文件监听器
        (
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
                -l 2 | while read -r file; do
                echo -e "\n${YELLOW}📝 检测到文件变化: $file${NC}"
                echo -e "${BLUE}🔄 重启服务器...${NC}"

                # 杀死当前进程
                if [ ! -z "$SERVER_PID" ]; then
                    kill $SERVER_PID 2>/dev/null || true
                    wait $SERVER_PID 2>/dev/null || true
                fi

                # 重新构建
                if zig build 2>&1 | grep -q "error"; then
                    echo -e "${RED}❌ 构建失败，等待下次文件变化...${NC}"
                    continue
                fi

                # 启动新进程
                "$exe_path" &
                SERVER_PID=$!
                echo -e "${GREEN}✅ 服务器重启成功 (PID: $SERVER_PID)${NC}"
            done
        ) &

        WATCH_PID=$!
        verbose_echo "文件监听器 PID: $WATCH_PID"
    fi

    # 启动服务器
    subtitle "🎉 启动服务器"
    echo -e "${GREEN}服务器地址: http://$HOST:$PORT${NC}"
    echo -e "${YELLOW}按 Ctrl+C 停止服务器${NC}"
    echo ""

    # 启动服务器
    exec "$exe_path"
}

# 运行主函数
main "$@"

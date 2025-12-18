#!/usr/bin/env bash
# ZigCMS 清理脚本
# 智能清理构建文件、缓存和临时文件

SCRIPT_DESCRIPTION="ZigCMS 清理脚本"

# 导入通用工具库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 默认配置
DEFAULT_AGGRESSIVE=false

# 初始化脚本环境
init_script_env

# 解析参数
parse_common_args "$@"

# 显示清理帮助信息
show_clean_help() {
    cat << EOF
${0} - ${SCRIPT_DESCRIPTION}

用法:
  ./${0} [选项] [清理目标]

清理目标:
  all           清理所有 (默认)
  build         清理构建文件
  cache         清理缓存文件
  temp          清理临时文件
  logs          清理日志文件
  db            清理数据库文件

选项:
  -h, --help          显示此帮助信息
  -v, --verbose       详细输出模式
  -y, --yes           跳过确认提示
  --aggressive        激进清理模式 (清理更多文件)
  --dry-run           仅显示将要删除的文件，不实际删除

示例:
  ./${0}                     # 清理所有文件
  ./${0} build               # 只清理构建文件
  ./${0} cache --verbose     # 详细模式清理缓存
  ./${0} --dry-run           # 预览将要删除的文件
  ./${0} --aggressive        # 激进清理

EOF
}

# 解析清理脚本特定参数
parse_clean_args() {
    CLEAN_TARGET="all"
    SKIP_CONFIRM=false
    DRY_RUN=false
    AGGRESSIVE="$DEFAULT_AGGRESSIVE"

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_clean_help
                exit 0
                ;;
            -y|--yes)
                SKIP_CONFIRM=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --aggressive)
                AGGRESSIVE=true
                shift
                ;;
            all|build|cache|temp|logs|db)
                CLEAN_TARGET="$1"
                shift
                ;;
            *)
                error_exit "未知参数: $1"
                ;;
        esac
    done
}

# 显示清理摘要
show_cleanup_summary() {
    echo ""
    echo -e "${CYAN}清理摘要:${NC}"
    echo -e "  ${BLUE}目标:${NC} $CLEAN_TARGET"
    echo -e "  ${BLUE}模式:${NC} $([ "$AGGRESSIVE" = true ] && echo "激进" || echo "标准")"
    echo -e "  ${BLUE}操作:${NC} $([ "$DRY_RUN" = true ] && echo "预览" || echo "执行")"
}

# 清理构建相关文件
cleanup_build() {
    subtitle "🔨 清理构建文件"

    # Zig 构建缓存
    if [ -d ".zig-cache" ]; then
        verbose_echo "清理 .zig-cache 目录"
        safe_remove ".zig-cache"
    fi

    # 输出目录
    if [ -d "zig-out" ]; then
        verbose_echo "清理 zig-out 目录"
        safe_remove "zig-out"
    fi

    # CMake 构建文件 (如果存在)
    if [ -f "CMakeCache.txt" ] || [ -d "CMakeFiles" ]; then
        verbose_echo "清理 CMake 构建文件"
        safe_remove "CMakeCache.txt"
        safe_remove "CMakeFiles"
        safe_remove "cmake_install.cmake"
        safe_remove "Makefile"
    fi
}

# 清理缓存文件
cleanup_cache() {
    subtitle "💾 清理缓存文件"

    # 各种缓存目录
    local cache_dirs=(".cache" "__pycache__" ".pytest_cache" ".mypy_cache" ".vscode-test")

    for dir in "${cache_dirs[@]}"; do
        if [ -d "$dir" ]; then
            verbose_echo "清理 $dir 目录"
            safe_remove "$dir"
        fi
    done

    # 清理 macOS 缓存文件
    if [[ "$OSTYPE" == "darwin"* ]]; then
        find . -name ".DS_Store" -type f -delete 2>/dev/null || true
        find . -name "._*" -type f -delete 2>/dev/null || true
    fi

    # 清理临时文件
    find . -name "*.tmp" -type f -delete 2>/dev/null || true
    find . -name "*.temp" -type f -delete 2>/dev/null || true
    find . -name "*.bak" -type f -delete 2>/dev/null || true
}

# 清理临时文件
cleanup_temp() {
    subtitle "🗂️  清理临时文件"

    # 临时目录
    local temp_dirs=("tmp" "temp" ".tmp")

    for dir in "${temp_dirs[@]}"; do
        if [ -d "$dir" ]; then
            verbose_echo "清理 $dir 目录"
            safe_remove "$dir"
        fi
    done

    # 清理 PID 文件
    find . -name "*.pid" -type f -delete 2>/dev/null || true

    # 清理锁文件
    find . -name "*.lock" -type f -delete 2>/dev/null || true

    # 激进模式：清理更多临时文件
    if [ "$AGGRESSIVE" = true ]; then
        verbose_echo "激进模式：清理更多临时文件"
        find . -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
        find . -name "*.old" -type f -delete 2>/dev/null || true
        find . -name "*.orig" -type f -delete 2>/dev/null || true
    fi
}

# 清理日志文件
cleanup_logs() {
    subtitle "📝 清理日志文件"

    # 日志目录
    if [ -d "logs" ]; then
        verbose_echo "清理 logs 目录"
        if [ "$AGGRESSIVE" = true ]; then
            safe_remove "logs"
        else
            # 只删除旧的日志文件 (保留7天内的)
            find logs -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
            find logs -name "*.log.*" -type f -mtime +7 -delete 2>/dev/null || true
        fi
    fi

    # 清理其他日志文件
    find . -name "*.log" -type f -maxdepth 2 -delete 2>/dev/null || true
    find . -name "debug.log" -type f -delete 2>/dev/null || true
    find . -name "error.log" -type f -delete 2>/dev/null || true
}

# 清理数据库文件
cleanup_db() {
    subtitle "🗄️  清理数据库文件"

    # 测试数据库
    local db_files=("test.db" "test.db-*" "*.db" "*.sqlite" "*.sqlite3")

    for pattern in "${db_files[@]}"; do
        find . -name "$pattern" -type f -maxdepth 2 | while read -r file; do
            if [[ "$file" != *"zigcms.db"* ]]; then
                verbose_echo "清理数据库文件: $file"
                safe_remove "$file"
            fi
        done
    done

    # SQLite WAL 和 SHM 文件
    find . -name "*.db-wal" -type f -delete 2>/dev/null || true
    find . -name "*.db-shm" -type f -delete 2>/dev/null || true

    # 激进模式：清理所有数据库文件 (危险操作)
    if [ "$AGGRESSIVE" = true ]; then
        warning "激进模式：将清理所有数据库文件"
        if [ "$SKIP_CONFIRM" = false ]; then
            echo -e "${YELLOW}⚠️  这将删除所有数据库文件，确定要继续吗？(y/N)${NC}"
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                info "操作已取消"
                return
            fi
        fi

        find . -name "*.db" -type f -delete 2>/dev/null || true
        find . -name "*.sqlite*" -type f -delete 2>/dev/null || true
    fi
}

# 清理所有内容
cleanup_all() {
    subtitle "🧹 执行完整清理"

    cleanup_build
    echo ""
    cleanup_cache
    echo ""
    cleanup_temp
    echo ""
    cleanup_logs
    echo ""
    cleanup_db
}

# 显示磁盘使用情况
show_disk_usage() {
    if command -v df &> /dev/null; then
        echo ""
        echo -e "${CYAN}磁盘使用情况:${NC}"
        df -h . | tail -1 | awk '{print "  " $4 " 可用空间"}'
    fi

    if command -v du &> /dev/null; then
        local size
        size=$(du -sh . 2>/dev/null | cut -f1)
        echo -e "  ${BLUE}项目大小:${NC} $size"
    fi
}

# 主函数
main() {
    # 解析参数
    parse_clean_args "$@"

    title "清理 ZigCMS 构建和缓存文件"

    # 显示清理摘要
    show_cleanup_summary

    # 确认操作 (除非跳过)
    if [ "$DRY_RUN" = false ] && [ "$SKIP_CONFIRM" = false ]; then
        echo ""
        echo -e "${YELLOW}⚠️  这将删除指定的文件和目录，确定要继续吗？(y/N)${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            info "清理操作已取消"
            exit 0
        fi
    fi

    # 显示磁盘使用情况 (清理前)
    show_disk_usage

    # 开始计时
    timer_start

    # 执行清理
    case "$CLEAN_TARGET" in
        build)
            cleanup_build
            ;;
        cache)
            cleanup_cache
            ;;
        temp)
            cleanup_temp
            ;;
        logs)
            cleanup_logs
            ;;
        db)
            cleanup_db
            ;;
        all)
            cleanup_all
            ;;
        *)
            error_exit "未知的清理目标: $CLEAN_TARGET"
            ;;
    esac

    # 结束计时
    timer_end

    # 显示磁盘使用情况 (清理后)
    show_disk_usage

    if [ "$DRY_RUN" = true ]; then
        info "预览模式：以上是将被删除的文件"
    else
        success "清理完成"
    fi
}

# 运行主函数
main "$@"

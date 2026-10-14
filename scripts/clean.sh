#!/bin/sh
# =============================================================================
# ZigCMS 清理脚本
# =============================================================================
# 智能清理构建文件、缓存和临时文件
# POSIX 兼容，支持 macOS 和 Linux
# =============================================================================

set -e

# 导入通用工具库
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/common.sh"

# =============================================================================
# 帮助信息
# =============================================================================
show_help() {
    cat << 'EOF'
ZigCMS 清理脚本

用法:
  ./clean.sh [选项] [清理目标]

清理目标:
  all           清理所有 (默认)
  build         清理构建文件
  cache         清理缓存文件
  temp          清理临时文件
  logs          清理日志文件
  db            清理数据库文件 (不包括主数据库)

选项:
  -h, --help          显示此帮助信息
  -v, --verbose       详细输出模式
  -y, --yes           跳过确认提示
  --aggressive        激进清理模式 (清理更多文件)
  --dry-run           仅显示将要删除的文件，不实际删除
  --no-color          禁用彩色输出

示例:
  ./clean.sh                      # 清理所有文件
  ./clean.sh build                # 只清理构建文件
  ./clean.sh cache --verbose      # 详细模式清理缓存
  ./clean.sh --dry-run            # 预览将要删除的文件
  ./clean.sh --aggressive -y      # 激进清理，跳过确认

EOF
    exit 0
}

# =============================================================================
# 清理函数
# =============================================================================

# 清理构建文件
cleanup_build() {
    subtitle "${BUILD_ICON} 清理构建文件"
    
    # Zig 构建缓存
    if [ -d ".zig-cache" ]; then
        step "清理 .zig-cache"
        if [ "$DRY_RUN" = "true" ]; then
            info "[预览] 将删除: .zig-cache"
        else
            safe_remove ".zig-cache"
        fi
    fi
    
    # 输出目录
    if [ -d "zig-out" ]; then
        step "清理 zig-out"
        if [ "$DRY_RUN" = "true" ]; then
            info "[预览] 将删除: zig-out"
        else
            safe_remove "zig-out"
        fi
    fi
    
    success "构建文件清理完成"
}

# 清理缓存文件
cleanup_cache() {
    subtitle "💾 清理缓存文件"
    
    local cache_dirs=".cache __pycache__ .pytest_cache .mypy_cache .vscode-test"
    
    for dir in $cache_dirs; do
        if [ -d "$dir" ]; then
            step "清理 $dir"
            if [ "$DRY_RUN" = "true" ]; then
                info "[预览] 将删除: $dir"
            else
                safe_remove "$dir"
            fi
        fi
    done
    
    # 清理 macOS 特定文件
    if [ "$(get_os)" = "macos" ]; then
        step "清理 macOS 缓存文件"
        if [ "$DRY_RUN" = "false" ]; then
            find . -name ".DS_Store" -type f -delete 2>/dev/null || true
            find . -name "._*" -type f -delete 2>/dev/null || true
        fi
    fi
    
    success "缓存文件清理完成"
}

# 清理临时文件
cleanup_temp() {
    subtitle "🗂️  清理临时文件"
    
    local temp_dirs="tmp temp .tmp"
    
    for dir in $temp_dirs; do
        if [ -d "$dir" ]; then
            step "清理 $dir"
            if [ "$DRY_RUN" = "true" ]; then
                info "[预览] 将删除: $dir"
            else
                safe_remove "$dir"
            fi
        fi
    done
    
    # 清理临时文件
    if [ "$DRY_RUN" = "false" ]; then
        find . -name "*.tmp" -type f -delete 2>/dev/null || true
        find . -name "*.temp" -type f -delete 2>/dev/null || true
        find . -name "*.bak" -type f -delete 2>/dev/null || true
        find . -name "*.pid" -type f -delete 2>/dev/null || true
        find . -name "*.lock" -type f -delete 2>/dev/null || true
    fi
    
    # 激进模式
    if [ "$AGGRESSIVE" = "true" ] && [ "$DRY_RUN" = "false" ]; then
        step "激进模式: 清理更多临时文件"
        find . -name "*.old" -type f -delete 2>/dev/null || true
        find . -name "*.orig" -type f -delete 2>/dev/null || true
    fi
    
    success "临时文件清理完成"
}

# 清理日志文件
cleanup_logs() {
    subtitle "📝 清理日志文件"
    
    if [ -d "logs" ]; then
        if [ "$AGGRESSIVE" = "true" ]; then
            step "清理整个 logs 目录"
            if [ "$DRY_RUN" = "true" ]; then
                info "[预览] 将删除: logs"
            else
                safe_remove "logs"
            fi
        else
            step "清理旧日志文件 (保留7天内)"
            if [ "$DRY_RUN" = "false" ]; then
                find logs -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
                find logs -name "*.log.*" -type f -mtime +7 -delete 2>/dev/null || true
            fi
        fi
    fi
    
    # 清理根目录日志
    if [ "$DRY_RUN" = "false" ]; then
        find . -maxdepth 2 -name "*.log" -type f -delete 2>/dev/null || true
        find . -name "debug.log" -type f -delete 2>/dev/null || true
        find . -name "error.log" -type f -delete 2>/dev/null || true
    fi
    
    success "日志文件清理完成"
}

# 清理数据库文件
cleanup_db() {
    subtitle "🗄️  清理数据库文件"
    
    # 清理测试数据库和临时数据库
    step "清理测试数据库文件"
    
    if [ "$DRY_RUN" = "false" ]; then
        # 清理 WAL 和 SHM 文件
        find . -name "*.db-wal" -type f -delete 2>/dev/null || true
        find . -name "*.db-shm" -type f -delete 2>/dev/null || true
        
        # 清理测试数据库 (不删除主数据库 zigcms.db)
        find . -maxdepth 2 -name "test*.db" -type f -delete 2>/dev/null || true
    fi
    
    # 激进模式
    if [ "$AGGRESSIVE" = "true" ]; then
        warning "激进模式: 将清理所有数据库文件 (除主数据库外)"
        
        if [ "$SKIP_CONFIRM" = "false" ]; then
            printf "${YELLOW}⚠️  确定要继续吗？(y/N) ${NC}"
            read -r response
            case "$response" in
                [Yy]*)
                    ;;
                *)
                    info "操作已取消"
                    return
                    ;;
            esac
        fi
        
        if [ "$DRY_RUN" = "false" ]; then
            find . -maxdepth 2 -name "*.db" -type f ! -name "zigcms.db" -delete 2>/dev/null || true
            find . -maxdepth 2 -name "*.sqlite*" -type f -delete 2>/dev/null || true
        fi
    fi
    
    success "数据库文件清理完成"
}

# 清理所有
cleanup_all() {
    subtitle "${CLEAN_ICON} 执行完整清理"
    
    cleanup_build
    printf "\n"
    cleanup_cache
    printf "\n"
    cleanup_temp
    printf "\n"
    cleanup_logs
    printf "\n"
    cleanup_db
}

# 显示磁盘使用情况
show_disk_usage() {
    printf "\n${CYAN}磁盘使用情况:${NC}\n"
    
    if command_exists "df"; then
        local available
        available=$(df -h . 2>/dev/null | tail -1 | awk '{print $4}')
        printf "  可用空间: %s\n" "$available"
    fi
    
    if command_exists "du"; then
        local size
        size=$(du -sh . 2>/dev/null | cut -f1)
        printf "  项目大小: %s\n" "$size"
    fi
}

# =============================================================================
# 主函数
# =============================================================================
main() {
    local clean_target="all"
    SKIP_CONFIRM="false"
    DRY_RUN="false"
    AGGRESSIVE="false"
    
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
            -y|--yes)
                SKIP_CONFIRM="true"
                shift
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --aggressive)
                AGGRESSIVE="true"
                shift
                ;;
            --no-color)
                NO_COLOR="1"
                RED='' GREEN='' YELLOW='' BLUE='' PURPLE='' CYAN='' WHITE='' BOLD='' NC=''
                shift
                ;;
            all|build|cache|temp|logs|db)
                clean_target="$1"
                shift
                ;;
            *)
                error_exit "未知参数: $1\n运行 './clean.sh --help' 查看帮助"
                ;;
        esac
    done
    
    # 初始化
    init_script
    
    # 显示标题
    title "清理 ZigCMS 构建和缓存文件"
    
    # 显示清理摘要
    printf "${CYAN}清理摘要:${NC}\n"
    printf "  目标: %s\n" "$clean_target"
    printf "  模式: %s\n" "$([ "$AGGRESSIVE" = "true" ] && echo "激进" || echo "标准")"
    printf "  操作: %s\n" "$([ "$DRY_RUN" = "true" ] && echo "预览" || echo "执行")"
    printf "\n"
    
    # 确认操作
    if [ "$DRY_RUN" = "false" ] && [ "$SKIP_CONFIRM" = "false" ]; then
        printf "${YELLOW}⚠️  这将删除指定的文件和目录，确定要继续吗？(y/N) ${NC}"
        read -r response
        case "$response" in
            [Yy]*)
                ;;
            *)
                info "清理操作已取消"
                exit 0
                ;;
        esac
    fi
    
    # 显示清理前磁盘使用
    show_disk_usage
    
    printf "\n"
    
    # 执行清理
    case "$clean_target" in
        build)     cleanup_build ;;
        cache)     cleanup_cache ;;
        temp)      cleanup_temp ;;
        logs)      cleanup_logs ;;
        db)        cleanup_db ;;
        all)       cleanup_all ;;
        *)         error_exit "未知的清理目标: $clean_target" ;;
    esac
    
    # 显示清理后磁盘使用
    show_disk_usage
    
    # 显示结果
    show_elapsed_time
    
    if [ "$DRY_RUN" = "true" ]; then
        info "预览模式: 以上是将被删除的文件"
    else
        success "清理完成"
    fi
}

# 运行主函数
main "$@"

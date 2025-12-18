#!/usr/bin/env bash
# ZigCMS 构建脚本
# 支持多种构建模式和平台

SCRIPT_DESCRIPTION="ZigCMS 构建脚本"

# 导入通用工具库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 解析参数
parse_common_args "$@"

# 主函数
main() {
    local build_mode="${1:-debug}"
    local target="${2:-}"

    title "构建 ZigCMS (模式: $build_mode)"

    # 检查 Zig 环境
    check_zig

    # 检查 .env 文件
    check_env_file

    # 开始计时
    timer_start

    # 执行构建
    case "$build_mode" in
        debug)
            subtitle "🐛 调试模式构建"
            verbose_echo "构建参数: 调试模式，无优化"
            zig_build
            ;;
        release)
            subtitle "🚀 发布模式构建 (安全优化)"
            verbose_echo "构建参数: -Doptimize=ReleaseSafe"
            zig_build -Doptimize=ReleaseSafe
            ;;
        fast)
            subtitle "⚡ 发布模式构建 (性能优化)"
            verbose_echo "构建参数: -Doptimize=ReleaseFast"
            zig_build -Doptimize=ReleaseFast
            ;;
        small)
            subtitle "📦 发布模式构建 (体积优化)"
            verbose_echo "构建参数: -Doptimize=ReleaseSmall"
            zig_build -Doptimize=ReleaseSmall
            ;;
        clean)
            subtitle "🧹 清理后重新构建"
            verbose_echo "清理构建缓存..."
            safe_remove ".zig-cache"
            safe_remove "zig-out"
            zig_build
            ;;
        cross)
            if [ -z "$target" ]; then
                error_exit "交叉编译需要指定目标平台，例如: $0 cross x86_64-linux"
            fi
            subtitle "🔄 交叉编译到 $target"
            verbose_echo "构建参数: -Dtarget=$target"
            zig_build -Dtarget="$target"
            ;;
        *)
            error_exit "未知的构建模式: $build_mode"
            echo -e "${YELLOW}支持的模式:${NC}"
            echo "  debug    - 调试模式 (默认)"
            echo "  release  - 发布模式 (安全优化)"
            echo "  fast     - 发布模式 (性能优化)"
            echo "  small    - 发布模式 (体积优化)"
            echo "  clean    - 清理后重新构建"
            echo "  cross    - 交叉编译 (需要指定目标平台)"
            echo ""
            echo -e "${YELLOW}示例:${NC}"
            echo "  $0 debug"
            echo "  $0 release"
            echo "  $0 cross aarch64-linux"
            exit 1
            ;;
    esac

    # 显示构建结果
    if [ -d "zig-out" ]; then
        success "构建完成"
        info "输出目录: $(pwd)/zig-out/bin/"

        # 显示可执行文件信息
        if [ -d "zig-out/bin" ]; then
            echo -e "${CYAN}生成的可执行文件:${NC}"
            ls -la zig-out/bin/ | grep -v "^total" | while read -r line; do
                echo -e "  ${BLUE}$line${NC}"
            done
        fi

        # 保留构建产物历史
        manage_build_artifacts
    else
        error_exit "构建失败，未找到输出目录"
    fi

    # 结束计时
    timer_end

    # 记录构建日志
    enhanced_logging "INFO" "构建完成: 模式=$build_mode, 耗时=$SECONDS秒"
}

# 并行构建多个目标
build_parallel_targets() {
    local targets=("x86_64-linux" "aarch64-linux" "x86_64-macos" "aarch64-macos")
    local build_cmds=()

    for target in "${targets[@]}"; do
        build_cmds+=("zig build -Dtarget=$target")
    done

    verbose_echo "启动并行构建: ${targets[*]}"
    parallel_exec "${MAX_PARALLEL_JOBS:-2}" "${build_cmds[@]}"
}

# 管理构建产物历史
manage_build_artifacts() {
    if [ "${KEEP_BUILD_ARTIFACTS:-5}" -gt 0 ]; then
        local artifact_dir="artifacts"
        ensure_dir "$artifact_dir"

        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        local archive_name="zigcms_${timestamp}.tar.gz"

        verbose_echo "创建构建产物归档: $archive_name"

        # 创建归档
        if command -v tar &> /dev/null; then
            tar -czf "$artifact_dir/$archive_name" zig-out/ 2>/dev/null
        fi

        # 清理旧的归档
        local count
        count=$(find "$artifact_dir" -name "zigcms_*.tar.gz" | wc -l)
        if [ "$count" -gt "${KEEP_BUILD_ARTIFACTS:-5}" ]; then
            verbose_echo "清理旧的构建产物归档"
            find "$artifact_dir" -name "zigcms_*.tar.gz" -type f \
                | sort | head -n -"${KEEP_BUILD_ARTIFACTS:-5}" \
                | xargs rm -f 2>/dev/null || true
        fi
    fi
}

# 运行主函数
main "$@"

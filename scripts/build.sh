#!/bin/sh
# =============================================================================
# ZigCMS 构建脚本
# =============================================================================
# 支持多种构建模式: debug, release, fast, small, clean, cross
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
ZigCMS 构建脚本

用法:
  ./build.sh [选项] [模式] [目标平台]

构建模式:
  debug       调试模式构建 (默认)
  release     发布模式构建 (安全优化)
  fast        发布模式构建 (性能优化)
  small       发布模式构建 (体积优化)
  clean       清理后重新构建
  cross       交叉编译 (需要指定目标平台)

选项:
  -h, --help      显示此帮助信息
  -v, --verbose   详细输出模式
  --no-color      禁用彩色输出

交叉编译目标平台示例:
  x86_64-linux      Linux x86_64
  aarch64-linux     Linux ARM64
  x86_64-macos      macOS x86_64
  aarch64-macos     macOS ARM64 (Apple Silicon)
  x86_64-windows    Windows x86_64

示例:
  ./build.sh                      # 调试模式构建
  ./build.sh release              # 发布模式构建
  ./build.sh fast                 # 性能优化构建
  ./build.sh small                # 体积优化构建
  ./build.sh clean                # 清理后重新构建
  ./build.sh cross x86_64-linux   # 交叉编译到 Linux
  ./build.sh -v release           # 详细模式发布构建

EOF
    exit 0
}

# =============================================================================
# 构建函数
# =============================================================================

# 调试模式构建
build_debug() {
    subtitle "${BUILD_ICON} 调试模式构建"
    debug "构建参数: 无优化，包含调试信息"
    zig_build
}

# 发布模式构建 (安全优化)
build_release() {
    subtitle "${ROCKET_ICON} 发布模式构建 (安全优化)"
    debug "构建参数: -Doptimize=ReleaseSafe"
    zig_build -Doptimize=ReleaseSafe
}

# 发布模式构建 (性能优化)
build_fast() {
    subtitle "⚡ 发布模式构建 (性能优化)"
    debug "构建参数: -Doptimize=ReleaseFast"
    zig_build -Doptimize=ReleaseFast
}

# 发布模式构建 (体积优化)
build_small() {
    subtitle "📦 发布模式构建 (体积优化)"
    debug "构建参数: -Doptimize=ReleaseSmall"
    zig_build -Doptimize=ReleaseSmall
}

# 清理后重新构建
build_clean() {
    subtitle "${CLEAN_ICON} 清理后重新构建"
    
    step "清理 .zig-cache 目录"
    safe_remove ".zig-cache"
    
    step "清理 zig-out 目录"
    safe_remove "zig-out"
    
    step "重新构建"
    zig_build
}

# 交叉编译
build_cross() {
    local target="$1"
    
    if [ -z "$target" ]; then
        error_exit "交叉编译需要指定目标平台\n用法: ./build.sh cross <目标平台>\n示例: ./build.sh cross x86_64-linux"
    fi
    
    subtitle "🔄 交叉编译到 $target"
    debug "构建参数: -Dtarget=$target"
    zig_build -Dtarget="$target"
}

# 显示构建结果
show_build_result() {
    if [ -d "zig-out" ]; then
        success "构建完成"
        info "输出目录: $(pwd)/zig-out/"
        
        # 显示可执行文件
        if [ -d "zig-out/bin" ]; then
            printf "\n${CYAN}生成的可执行文件:${NC}\n"
            ls -la zig-out/bin/ 2>/dev/null | grep -v "^total" | while read -r line; do
                printf "  ${BLUE}%s${NC}\n" "$line"
            done
        fi
        
        # 显示库文件
        if [ -d "zig-out/lib" ]; then
            printf "\n${CYAN}生成的库文件:${NC}\n"
            ls -la zig-out/lib/ 2>/dev/null | grep -v "^total" | while read -r line; do
                printf "  ${BLUE}%s${NC}\n" "$line"
            done
        fi
    else
        error_exit "构建失败，未找到输出目录"
    fi
}

# =============================================================================
# 主函数
# =============================================================================
main() {
    local build_mode="debug"
    local cross_target=""
    
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
            --no-color)
                NO_COLOR="1"
                RED='' GREEN='' YELLOW='' BLUE='' PURPLE='' CYAN='' WHITE='' BOLD='' NC=''
                shift
                ;;
            debug|release|fast|small|clean|cross)
                build_mode="$1"
                shift
                # 如果是 cross 模式，获取目标平台
                if [ "$build_mode" = "cross" ] && [ $# -gt 0 ]; then
                    cross_target="$1"
                    shift
                fi
                ;;
            *)
                # 可能是交叉编译目标
                if [ "$build_mode" = "cross" ]; then
                    cross_target="$1"
                    shift
                else
                    error_exit "未知参数: $1\n运行 './build.sh --help' 查看帮助"
                fi
                ;;
        esac
    done
    
    # 初始化
    init_script
    
    # 显示标题
    title "构建 ZigCMS (模式: $build_mode)"
    
    # 检查环境
    check_zig
    check_env_file || true
    
    # 执行构建
    case "$build_mode" in
        debug)   build_debug ;;
        release) build_release ;;
        fast)    build_fast ;;
        small)   build_small ;;
        clean)   build_clean ;;
        cross)   build_cross "$cross_target" ;;
        *)
            error_exit "未知的构建模式: $build_mode"
            ;;
    esac
    
    # 显示结果
    show_build_result
    show_elapsed_time
}

# 运行主函数
main "$@"

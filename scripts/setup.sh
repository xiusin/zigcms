#!/bin/sh
# =============================================================================
# ZigCMS 项目初始化脚本
# =============================================================================
# 完整的项目设置和依赖检查
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
ZigCMS 项目初始化脚本

用法:
  ./setup.sh [选项]

选项:
  -h, --help          显示此帮助信息
  -v, --verbose       详细输出模式
  --no-auto-fix       禁用自动修复依赖问题
  --force             强制重新初始化 (跳过检查)
  --no-color          禁用彩色输出

示例:
  ./setup.sh                      # 完整项目初始化
  ./setup.sh --verbose            # 详细模式初始化
  ./setup.sh --no-auto-fix        # 不自动修复依赖问题
  ./setup.sh --force              # 强制重新初始化

EOF
    exit 0
}

# =============================================================================
# 检查函数
# =============================================================================

# 检查操作系统
check_os_info() {
    subtitle "🖥️  检查操作系统"
    
    local os_name
    os_name=$(get_os)
    
    case "$os_name" in
        linux)  success "Linux 系统" ;;
        macos)  success "macOS 系统" ;;
        windows) success "Windows 系统" ;;
        *)      warning "未知操作系统: $os_name" ;;
    esac
}

# 检查必要依赖
check_dependencies() {
    subtitle "📦 检查依赖"
    
    local missing_deps=""
    
    # 检查 Zig
    if command_exists "zig"; then
        local zig_version
        zig_version=$(zig version 2>/dev/null || echo "未知")
        success "Zig 编译器: $zig_version"
    else
        missing_deps="$missing_deps zig"
        error "Zig 编译器未安装"
    fi
    
    # 检查 Git
    if command_exists "git"; then
        local git_version
        git_version=$(git --version 2>/dev/null | head -1 || echo "未知")
        success "Git: $git_version"
    else
        missing_deps="$missing_deps git"
        error "Git 未安装"
    fi
    
    # 如果有缺失依赖
    if [ -n "$missing_deps" ]; then
        if [ "$AUTO_FIX" = "true" ]; then
            warning "尝试自动安装缺失依赖:$missing_deps"
            install_missing_deps "$missing_deps"
        else
            error_exit "缺失依赖:$missing_deps\n请手动安装后重试，或使用 --no-auto-fix 选项"
        fi
    fi
}

# 安装缺失依赖
install_missing_deps() {
    local deps="$1"
    local os_name
    os_name=$(get_os)
    
    for dep in $deps; do
        case "$dep" in
            zig)
                install_zig "$os_name"
                ;;
            git)
                install_git "$os_name"
                ;;
        esac
    done
}

# 安装 Zig
install_zig() {
    local os_name="$1"
    
    step "安装 Zig 编译器"
    
    case "$os_name" in
        macos)
            if command_exists "brew"; then
                brew install zig
            else
                error_exit "请先安装 Homebrew，然后运行: brew install zig"
            fi
            ;;
        linux)
            info "请访问 https://ziglang.org/download/ 下载安装 Zig"
            info "或使用包管理器安装"
            return 1
            ;;
        *)
            error_exit "不支持在此系统上自动安装 Zig"
            ;;
    esac
    
    if command_exists "zig"; then
        success "Zig 安装成功"
    else
        error_exit "Zig 安装失败"
    fi
}

# 安装 Git
install_git() {
    local os_name="$1"
    
    step "安装 Git"
    
    case "$os_name" in
        macos)
            if command_exists "brew"; then
                brew install git
            else
                error_exit "请先安装 Homebrew，然后运行: brew install git"
            fi
            ;;
        linux)
            if command_exists "apt-get"; then
                sudo apt-get update && sudo apt-get install -y git
            elif command_exists "yum"; then
                sudo yum install -y git
            elif command_exists "dnf"; then
                sudo dnf install -y git
            else
                error_exit "无法确定包管理器，请手动安装 Git"
            fi
            ;;
        *)
            error_exit "不支持在此系统上自动安装 Git"
            ;;
    esac
    
    if command_exists "git"; then
        success "Git 安装成功"
    else
        error_exit "Git 安装失败"
    fi
}

# 检查项目结构
check_project_structure() {
    subtitle "📁 检查项目结构"
    
    local required_files="main.zig build.zig README.md"
    local missing_files=""
    
    for file in $required_files; do
        if [ -f "$file" ]; then
            debug "文件存在: $file"
        else
            missing_files="$missing_files $file"
        fi
    done
    
    if [ -n "$missing_files" ]; then
        warning "缺少文件:$missing_files"
        if [ "$FORCE_INIT" = "false" ]; then
            error_exit "项目结构不完整，请检查项目文件"
        fi
    else
        success "项目结构完整"
    fi
}

# 创建必要目录
create_directories() {
    subtitle "📂 创建必要目录"
    
    local dirs="logs uploads tmp backups"
    
    for dir in $dirs; do
        ensure_dir "$dir"
        debug "目录就绪: $dir"
    done
    
    success "目录结构就绪"
}

# 设置权限
setup_permissions() {
    subtitle "🔐 设置权限"
    
    # 设置脚本执行权限
    if [ -d "scripts" ]; then
        chmod +x scripts/*.sh 2>/dev/null || true
        success "脚本权限已设置"
    fi
    
    # 设置配置文件权限
    if [ -f ".env" ]; then
        chmod 600 .env 2>/dev/null || true
        success "配置文件权限已设置"
    fi
}

# 检查数据库
check_database() {
    subtitle "🗄️  检查数据库"
    
    if [ -f "database_schema.sql" ]; then
        info "发现数据库模式文件"
        
        if [ -f "zigcms.db" ]; then
            success "数据库文件存在"
        else
            info "数据库文件将在首次运行时创建"
        fi
    else
        warning "未找到 database_schema.sql 文件"
    fi
}

# 测试构建
test_build() {
    subtitle "🔨 测试构建系统"
    
    if zig build --help > /dev/null 2>&1; then
        success "Zig 构建系统正常"
    else
        error_exit "Zig 构建系统异常"
    fi
    
    if [ "$FORCE_INIT" = "true" ]; then
        step "执行完整构建测试..."
        if zig build 2>&1; then
            success "项目构建成功"
        else
            warning "项目构建失败 (可能是正常的，依赖未完全配置)"
        fi
    fi
}

# 显示完成信息
show_completion() {
    printf "\n"
    printf "${GREEN}${BOLD}"
    printf "╔═══════════════════════════════════════════════════════════╗\n"
    printf "║           ✨ 项目初始化完成！                             ║\n"
    printf "╚═══════════════════════════════════════════════════════════╝${NC}\n"
    printf "\n"
    
    printf "${CYAN}🚀 快速开始:${NC}\n"
    printf "  ${YELLOW}开发模式:${NC} ./scripts/dev.sh\n"
    printf "  ${YELLOW}运行测试:${NC} ./scripts/test.sh\n"
    printf "  ${YELLOW}构建项目:${NC} ./scripts/build.sh release\n"
    printf "  ${YELLOW}查看帮助:${NC} make help\n"
    printf "\n"
    
    printf "${CYAN}📚 更多信息:${NC}\n"
    printf "  ${BLUE}文档:${NC} README.md\n"
    printf "  ${BLUE}配置:${NC} .env 文件\n"
    printf "  ${BLUE}构建:${NC} build.zig\n"
    
    if [ -f "USAGE_GUIDE.md" ]; then
        printf "  ${BLUE}使用指南:${NC} USAGE_GUIDE.md\n"
    fi
}

# =============================================================================
# 主函数
# =============================================================================
main() {
    AUTO_FIX="true"
    FORCE_INIT="false"
    
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
            --no-auto-fix)
                AUTO_FIX="false"
                shift
                ;;
            --force)
                FORCE_INIT="true"
                shift
                ;;
            --no-color)
                NO_COLOR="1"
                RED='' GREEN='' YELLOW='' BLUE='' PURPLE='' CYAN='' WHITE='' BOLD='' NC=''
                shift
                ;;
            *)
                error_exit "未知参数: $1\n运行 './setup.sh --help' 查看帮助"
                ;;
        esac
    done
    
    # 初始化
    init_script
    
    # 显示标题
    title "ZigCMS 项目初始化"
    
    # 执行检查和设置
    check_os_info
    printf "\n"
    
    check_dependencies
    printf "\n"
    
    check_project_structure
    printf "\n"
    
    create_directories
    printf "\n"
    
    setup_permissions
    printf "\n"
    
    check_env_file || true
    printf "\n"
    
    check_database
    printf "\n"
    
    test_build
    
    # 显示完成信息
    show_elapsed_time
    show_completion
}

# 运行主函数
main "$@"

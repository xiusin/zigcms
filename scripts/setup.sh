#!/usr/bin/env bash
# ZigCMS 项目初始化脚本
# 完整的项目设置和依赖检查

SCRIPT_DESCRIPTION="ZigCMS 项目初始化脚本"

# 导入通用工具库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 默认配置
DEFAULT_AUTO_FIX=true

# 初始化脚本环境
init_script_env

# 解析参数
parse_common_args "$@"

# 显示设置帮助信息
show_setup_help() {
    cat << EOF
${0} - ${SCRIPT_DESCRIPTION}

用法:
  ./${0} [选项]

选项:
  -h, --help          显示此帮助信息
  -v, --verbose       详细输出模式
  --no-auto-fix       禁用自动修复依赖问题
  --force             强制重新初始化 (跳过检查)

示例:
  ./${0}                     # 完整项目初始化
  ./${0} --verbose           # 详细模式初始化
  ./${0} --no-auto-fix       # 不自动修复依赖问题
  ./${0} --force             # 强制重新初始化

EOF
}

# 解析设置脚本特定参数
parse_setup_args() {
    AUTO_FIX="$DEFAULT_AUTO_FIX"
    FORCE_INIT=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_setup_help
                exit 0
                ;;
            --no-auto-fix)
                AUTO_FIX=false
                shift
                ;;
            --force)
                FORCE_INIT=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
}

# 检查操作系统
check_os() {
    subtitle "🖥️  检查操作系统"

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        success "Linux 系统"
        OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        success "macOS 系统"
        OS="macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        success "Windows 系统"
        OS="windows"
    else
        warning "未知操作系统: $OSTYPE"
        OS="unknown"
    fi

    verbose_echo "操作系统类型: $OS"
}

# 检查并安装依赖
check_and_install_dependencies() {
    local deps=("zig" "git")

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            warning "$dep 未安装"
            if [ "$AUTO_FIX" = true ]; then
                install_dependency "$dep"
            else
                error_exit "请先安装 $dep"
            fi
        else
            success "$dep 已安装"
        fi
    done
}

# 安装依赖 (仅在支持的系统上)
install_dependency() {
    local dep="$1"

    case "$dep" in
        zig)
            install_zig
            ;;
        git)
            install_git
            ;;
        *)
            warning "不支持自动安装: $dep"
            ;;
    esac
}

# 安装 Zig
install_zig() {
    subtitle "📥 安装 Zig"

    case "$OS" in
        macos)
            if command -v brew &> /dev/null; then
                info "使用 Homebrew 安装 Zig..."
                brew install zig
            else
                error_exit "macOS 上请先安装 Homebrew，然后运行: brew install zig"
            fi
            ;;
        linux)
            info "下载 Zig 二进制文件..."
            # 下载最新版本
            local zig_url="https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz"
            local zig_tar="zig-linux.tar.xz"

            if command -v curl &> /dev/null; then
                curl -L "$zig_url" -o "$zig_tar"
            elif command -v wget &> /dev/null; then
                wget "$zig_url" -O "$zig_tar"
            else
                error_exit "需要 curl 或 wget 来下载 Zig"
            fi

            tar -xf "$zig_tar"
            local zig_dir
            zig_dir=$(tar -tf "$zig_tar" | head -1 | cut -d'/' -f1)
            export PATH="$PWD/$zig_dir:$PATH"
            rm "$zig_tar"
            ;;
        *)
            error_exit "不支持在此系统上自动安装 Zig，请访问 https://ziglang.org/download/"
            ;;
    esac

    # 验证安装
    if command -v zig &> /dev/null; then
        success "Zig 安装成功: $(zig version)"
    else
        error_exit "Zig 安装失败"
    fi
}

# 安装 Git
install_git() {
    subtitle "📥 安装 Git"

    case "$OS" in
        macos)
            if command -v brew &> /dev/null; then
                brew install git
            else
                error_exit "请安装 Homebrew，然后运行: brew install git"
            fi
            ;;
        linux)
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y git
            elif command -v yum &> /dev/null; then
                sudo yum install -y git
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y git
            else
                error_exit "无法确定 Linux 包管理器，请手动安装 Git"
            fi
            ;;
        *)
            error_exit "不支持在此系统上自动安装 Git"
            ;;
    esac

    # 验证安装
    if command -v git &> /dev/null; then
        success "Git 安装成功"
    else
        error_exit "Git 安装失败"
    fi
}

# 检查项目结构
check_project_structure() {
    subtitle "📁 检查项目结构"

    local required_files=("main.zig" "build.zig" "README.md")
    local missing_files=()

    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done

    if [ ${#missing_files[@]} -gt 0 ]; then
        warning "缺少必要的文件: ${missing_files[*]}"
        if [ "$FORCE_INIT" = false ]; then
            error_exit "项目结构不完整，请检查项目文件"
        fi
    else
        success "项目结构完整"
    fi
}

# 设置项目权限
setup_permissions() {
    subtitle "🔐 设置项目权限"

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

# 初始化数据库 (如果需要)
init_database() {
    subtitle "🗄️  检查数据库"

    if [ -f "database_schema.sql" ]; then
        info "发现数据库模式文件"

        # 检查是否需要创建数据库
        if [ ! -f "zigcms.db" ] && [ ! -f ".env" ]; then
            warning "数据库文件不存在，可能需要在运行时创建"
        else
            success "数据库配置存在"
        fi
    else
        warning "未找到 database_schema.sql 文件"
    fi
}

# 测试构建
test_build() {
    subtitle "🔨 测试构建"

    if zig build --help > /dev/null 2>&1; then
        success "Zig 构建系统正常"
    else
        error_exit "Zig 构建系统异常"
    fi

    # 尝试构建项目 (可选)
    if [ "$FORCE_INIT" = true ]; then
        info "执行完整构建测试..."
        if zig build 2>&1; then
            success "项目构建成功"
        else
            warning "项目构建失败，但这可能是正常的 (依赖未完全配置)"
        fi
    fi
}

# 显示完成信息
show_completion_info() {
    echo ""
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════╗"
    echo "║     ✨ 项目初始化完成！               ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "${GREEN}🚀 快速开始:${NC}"
    echo -e "  ${YELLOW}开发模式:${NC} ./scripts/dev.sh"
    echo -e "  ${YELLOW}运行测试:${NC} ./scripts/test.sh"
    echo -e "  ${YELLOW}构建项目:${NC} ./scripts/build.sh release"
    echo -e "  ${YELLOW}查看帮助:${NC} make help"

    echo ""
    echo -e "${CYAN}📚 更多信息:${NC}"
    echo -e "  ${BLUE}文档:${NC} README.md"
    echo -e "  ${BLUE}配置:${NC} .env 文件"
    echo -e "  ${BLUE}构建:${NC} build.zig"

    if [ -f "USAGE_GUIDE.md" ]; then
        echo -e "  ${BLUE}使用指南:${NC} USAGE_GUIDE.md"
    fi
}

# 主函数
main() {
    # 解析参数
    parse_setup_args "$@"

    # 显示标题
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════╗"
    echo "║     ZigCMS 项目初始化脚本             ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}"

    # 开始计时
    timer_start

    # 1. 检查操作系统
    check_os

    # 2. 检查并安装依赖
    check_and_install_dependencies

    # 3. 检查项目结构
    check_project_structure

    # 4. 创建必要的目录
    create_dirs

    # 5. 设置项目权限
    setup_permissions

    # 6. 检查环境配置
    check_env_file

    # 7. 初始化数据库
    init_database

    # 8. 测试构建
    test_build

    # 结束计时
    timer_end

    # 显示完成信息
    show_completion_info
}

# 运行主函数
main "$@"

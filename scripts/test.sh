#!/bin/sh
# =============================================================================
# ZigCMS 测试脚本
# =============================================================================
# 运行单元测试和集成测试，报告覆盖率
# POSIX 兼容，支持 macOS 和 Linux
# =============================================================================

set -e

# 导入通用工具库
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/common.sh"

# =============================================================================
# 默认配置
# =============================================================================
DEFAULT_TEST_TYPE="unit"
DEFAULT_TIMEOUT="300"
COVERAGE_DIR="coverage"

# =============================================================================
# 帮助信息
# =============================================================================
show_help() {
    cat << 'EOF'
ZigCMS 测试脚本

用法:
  ./test.sh [选项] [测试类型]

测试类型:
  unit          运行单元测试 (默认)
  integration   运行集成测试
  all           运行所有测试
  coverage      生成覆盖率报告 (需要 kcov)

选项:
  -h, --help          显示此帮助信息
  -v, --verbose       详细输出模式
  --timeout SEC       设置测试超时时间 (秒, 默认: 300)
  --fail-fast         遇到第一个失败就停止
  --no-color          禁用彩色输出

示例:
  ./test.sh                       # 运行单元测试
  ./test.sh integration           # 运行集成测试
  ./test.sh all                   # 运行所有测试
  ./test.sh all --verbose         # 详细模式运行所有测试
  ./test.sh coverage              # 生成覆盖率报告
  ./test.sh --fail-fast           # 遇到失败立即停止

覆盖率报告说明:
  coverage 选项需要安装 kcov 工具:
  - macOS: brew install kcov
  - Linux: apt install kcov

EOF
    exit 0
}

# =============================================================================
# 测试函数
# =============================================================================

# 运行单元测试
run_unit_tests() {
    subtitle "${TEST_ICON} 运行单元测试"
    
    debug "执行: zig build test"
    
    if zig build test 2>&1; then
        success "单元测试通过"
        return 0
    else
        error "单元测试失败"
        return 1
    fi
}

# 运行集成测试
run_integration_tests() {
    subtitle "🔗 运行集成测试"
    
    # 检查集成测试目录
    if [ ! -d "tests/integration" ]; then
        warning "集成测试目录不存在: tests/integration"
        info "跳过集成测试"
        return 0
    fi
    
    debug "执行集成测试..."
    
    # 运行集成测试
    local test_result=0
    for test_file in tests/integration/*.zig; do
        if [ -f "$test_file" ]; then
            step "测试: $(basename "$test_file")"
            if ! zig build test 2>&1; then
                test_result=1
            fi
        fi
    done
    
    if [ "$test_result" -eq 0 ]; then
        success "集成测试通过"
    else
        error "集成测试失败"
    fi
    
    return $test_result
}

# 运行所有测试
run_all_tests() {
    subtitle "🎯 运行完整测试套件"
    
    local overall_result=0
    
    printf "\n${BLUE}阶段 1: 单元测试${NC}\n"
    if ! run_unit_tests; then
        overall_result=1
        if [ "$FAIL_FAST" = "true" ]; then
            return 1
        fi
    fi
    
    printf "\n${BLUE}阶段 2: 集成测试${NC}\n"
    if ! run_integration_tests; then
        overall_result=1
        if [ "$FAIL_FAST" = "true" ]; then
            return 1
        fi
    fi
    
    return $overall_result
}

# 生成覆盖率报告
run_coverage() {
    subtitle "📊 生成测试覆盖率报告"
    
    # 检查 kcov 是否安装
    if ! command_exists "kcov"; then
        error_exit "kcov 未安装，无法生成覆盖率报告\n安装方法:\n  macOS: brew install kcov\n  Linux: apt install kcov"
    fi
    
    success "kcov 已安装"
    
    # 清理旧的覆盖率报告
    safe_remove "$COVERAGE_DIR"
    ensure_dir "$COVERAGE_DIR"
    
    step "运行测试并收集覆盖率数据..."
    
    # 使用 kcov 运行测试
    if kcov \
        --include-path="$(pwd)" \
        --exclude-path="$(pwd)/.zig-cache" \
        --exclude-path="$(pwd)/zig-out" \
        --exclude-path="$(pwd)/tests" \
        "$COVERAGE_DIR" \
        zig build test 2>&1; then
        
        success "覆盖率报告生成完成"
        info "查看报告: file://$(pwd)/$COVERAGE_DIR/index.html"
        
        # 显示覆盖率摘要
        if [ -f "$COVERAGE_DIR/kcov-merged/coverage.json" ]; then
            printf "\n${CYAN}覆盖率摘要:${NC}\n"
            # 尝试解析覆盖率数据
            if command_exists "jq"; then
                local percent
                percent=$(jq -r '.percent_covered' "$COVERAGE_DIR/kcov-merged/coverage.json" 2>/dev/null || echo "N/A")
                printf "  总覆盖率: ${GREEN}%s%%${NC}\n" "$percent"
            fi
        fi
        
        return 0
    else
        error "覆盖率报告生成失败"
        return 1
    fi
}

# 显示测试统计
show_test_stats() {
    printf "\n${CYAN}测试统计:${NC}\n"
    
    # 显示系统信息
    if command_exists "uname"; then
        printf "  ${BLUE}系统:${NC} %s %s\n" "$(uname -s)" "$(uname -m)"
    fi
    
    if command_exists "zig"; then
        printf "  ${BLUE}Zig版本:${NC} %s\n" "$(zig version 2>/dev/null | head -1)"
    fi
}

# =============================================================================
# 主函数
# =============================================================================
main() {
    local test_type="$DEFAULT_TEST_TYPE"
    local timeout="$DEFAULT_TIMEOUT"
    FAIL_FAST="false"
    
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
            --timeout)
                timeout="$2"
                shift 2
                ;;
            --fail-fast)
                FAIL_FAST="true"
                shift
                ;;
            --no-color)
                NO_COLOR="1"
                RED='' GREEN='' YELLOW='' BLUE='' PURPLE='' CYAN='' WHITE='' BOLD='' NC=''
                shift
                ;;
            unit|integration|all|coverage)
                test_type="$1"
                shift
                ;;
            *)
                error_exit "未知参数: $1\n运行 './test.sh --help' 查看帮助"
                ;;
        esac
    done
    
    # 初始化
    init_script
    
    # 显示标题
    title "运行 ZigCMS 测试套件"
    
    # 检查环境
    check_zig
    check_env_file || true
    
    debug "测试类型: $test_type"
    debug "超时时间: ${timeout}秒"
    debug "快速失败: $FAIL_FAST"
    
    # 执行测试
    local test_result=0
    case "$test_type" in
        unit)
            run_unit_tests || test_result=$?
            ;;
        integration)
            run_integration_tests || test_result=$?
            ;;
        all)
            run_all_tests || test_result=$?
            ;;
        coverage)
            run_coverage || test_result=$?
            ;;
        *)
            error_exit "未知的测试类型: $test_type"
            ;;
    esac
    
    # 显示统计
    show_test_stats
    show_elapsed_time
    
    # 返回结果
    if [ "$test_result" -eq 0 ]; then
        printf "\n"
        success "测试套件执行完成"
    else
        printf "\n"
        warning "测试套件执行完成，但存在失败"
        exit "$test_result"
    fi
}

# 运行主函数
main "$@"

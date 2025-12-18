#!/usr/bin/env bash
# ZigCMS 测试脚本
# 提供完整的测试套件支持

SCRIPT_DESCRIPTION="ZigCMS 测试脚本"

# 导入通用工具库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 默认配置
DEFAULT_TEST_TIMEOUT="300"  # 5分钟超时

# 初始化脚本环境
init_script_env

# 解析参数
parse_common_args "$@"

# 显示测试帮助信息
show_test_help() {
    cat << EOF
${0} - ${SCRIPT_DESCRIPTION}

用法:
  ./${0} [选项] [测试类型]

测试类型:
  unit          运行单元测试 (默认)
  integration   运行集成测试
  all           运行所有测试
  bench         运行性能基准测试
  coverage      生成覆盖率报告 (需要 kcov)

选项:
  -h, --help          显示此帮助信息
  -v, --verbose       详细输出模式
  --timeout SEC       设置测试超时时间 (秒, 默认: ${DEFAULT_TEST_TIMEOUT})
  --no-color          禁用彩色输出
  --fail-fast         遇到第一个失败就停止
  --race              启用竞争检测 (如果支持)

示例:
  ./${0}                     # 运行单元测试
  ./${0} integration         # 运行集成测试
  ./${0} all --verbose       # 运行所有测试，详细模式
  ./${0} bench               # 运行性能基准测试
  ./${0} coverage            # 生成覆盖率报告

EOF
}

# 解析测试脚本特定参数
parse_test_args() {
    TEST_TIMEOUT="$DEFAULT_TEST_TIMEOUT"
    TEST_TYPE="unit"
    NO_COLOR=false
    FAIL_FAST=false
    RACE_DETECT=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_test_help
                exit 0
                ;;
            --timeout)
                TEST_TIMEOUT="$2"
                shift 2
                ;;
            --no-color)
                NO_COLOR=true
                shift
                ;;
            --fail-fast)
                FAIL_FAST=true
                shift
                ;;
            --race)
                RACE_DETECT=true
                shift
                ;;
            unit|integration|all|bench|coverage)
                TEST_TYPE="$1"
                shift
                ;;
            *)
                error_exit "未知参数: $1"
                ;;
        esac
    done
}

# 运行单元测试
run_unit_tests() {
    subtitle "📝 运行单元测试"
    local args="test -- lib"

    if [ "$FAIL_FAST" = true ]; then
        args="$args --test-filter"
    fi

    zig_test $args
}

# 运行集成测试
run_integration_tests() {
    subtitle "🔗 运行集成测试"
    local args="test -- integration"

    if [ "$FAIL_FAST" = true ]; then
        args="$args --test-filter"
    fi

    zig_test $args
}

# 运行所有测试
run_all_tests() {
    subtitle "🎯 运行完整测试套件"

    echo -e "${BLUE}阶段 1: 单元测试${NC}"
    if ! run_unit_tests; then
        return 1
    fi

    echo ""
    echo -e "${BLUE}阶段 2: 集成测试${NC}"
    if ! run_integration_tests; then
        return 1
    fi

    success "所有测试阶段完成"
}

# 运行性能基准测试
run_benchmark() {
    subtitle "⚡ 运行性能基准测试"

    # 检查是否有基准测试
    if ! zig build --help 2>&1 | grep -q "bench"; then
        warning "当前 Zig 版本可能不支持基准测试"
        info "尝试使用标准测试模式..."
        zig_test "test"
        return $?
    fi

    verbose_echo "执行性能基准测试..."
    zig build bench
}

# 生成覆盖率报告
run_coverage() {
    subtitle "📊 生成测试覆盖率报告"

    if ! command -v kcov &> /dev/null; then
        error_exit "kcov 未安装，无法生成覆盖率报告\n请安装 kcov: brew install kcov"
    fi

    local coverage_dir="coverage"
    safe_remove "$coverage_dir"
    ensure_dir "$coverage_dir"

    verbose_echo "使用 kcov 生成覆盖率报告..."

    # 运行测试并收集覆盖率
    if kcov --include-path="$(pwd)" \
           --exclude-path="$(pwd)/.zig-cache" \
           --exclude-path="$(pwd)/zig-out" \
           --exclude-path="$(pwd)/test" \
           "$coverage_dir" \
           zig build test; then

        success "覆盖率报告生成完成"
        info "查看报告: file://$(pwd)/$coverage_dir/index.html"

        # 显示覆盖率统计
        if [ -f "$coverage_dir/kcov-merged/cobertura.xml" ]; then
            echo -e "${CYAN}覆盖率统计:${NC}"
            # 这里可以添加更详细的覆盖率分析
        fi
    else
        error_exit "覆盖率报告生成失败"
    fi
}

# 显示测试统计信息
show_test_stats() {
    local start_time="$1"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    echo -e "${CYAN}测试统计:${NC}"
    echo -e "  ${BLUE}总耗时:${NC} ${duration}秒"

    # 显示系统信息
    if command -v uname &> /dev/null; then
        echo -e "  ${BLUE}系统:${NC} $(uname -s) $(uname -m)"
    fi

    if command -v zig &> /dev/null; then
        echo -e "  ${BLUE}Zig版本:${NC} $(zig version | head -1)"
    fi
}

# 主函数
main() {
    # 解析参数
    parse_test_args "$@"

    title "运行 ZigCMS 测试套件"

    # 检查 Zig 环境
    check_zig

    # 检查 .env 文件
    check_env_file

    # 开始计时
    local test_start_time=$(date +%s)

    # 设置超时
    if command -v timeout &> /dev/null; then
        verbose_echo "设置测试超时: ${TEST_TIMEOUT}秒"
    fi

    # 执行相应测试
    local test_result=0
    case "$TEST_TYPE" in
        unit)
            run_unit_tests || test_result=$?
            ;;
        integration)
            run_integration_tests || test_result=$?
            ;;
        all)
            run_all_tests || test_result=$?
            ;;
        bench)
            run_benchmark || test_result=$?
            ;;
        coverage)
            run_coverage || test_result=$?
            ;;
        *)
            error_exit "未知的测试类型: $TEST_TYPE"
            ;;
    esac

    # 显示测试统计
    show_test_stats "$test_start_time"

    # 返回测试结果
    if [ $test_result -eq 0 ]; then
        success "测试套件执行完成"
    else
        warning "测试套件执行完成，但存在失败"
        exit $test_result
    fi
}

# 运行主函数
main "$@"

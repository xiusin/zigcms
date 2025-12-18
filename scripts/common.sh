#!/usr/bin/env bash
# 通用脚本工具库
# 提供统一的颜色定义、错误处理和常用函数

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# 图标定义
readonly CHECK_MARK="✅"
readonly CROSS_MARK="❌"
readonly WARNING="⚠️"
readonly INFO="ℹ️"
readonly ROCKET="🚀"
readonly GEAR="⚙️"
readonly FOLDER="📁"
readonly LOCK="🔐"
readonly DOWNLOAD="📥"
readonly TEST="🧪"
readonly CLEAN="🧹"
readonly BUILD="🔨"

# 错误处理函数
error_exit() {
    local message="$1"
    echo -e "${RED}${CROSS_MARK} ${message}${NC}" >&2
    exit 1
}

# 成功消息
success() {
    local message="$1"
    echo -e "${GREEN}${CHECK_MARK} ${message}${NC}"
}

# 警告消息
warning() {
    local message="$1"
    echo -e "${YELLOW}${WARNING} ${message}${NC}"
}

# 信息消息
info() {
    local message="$1"
    echo -e "${BLUE}${INFO} ${message}${NC}"
}

# 标题
title() {
    local message="$1"
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════╗"
    printf "║ %-37s ║\n" "${message}"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}"
}

# 子标题
subtitle() {
    local message="$1"
    echo -e "${CYAN}${message}${NC}"
}

# 检查命令是否存在
check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        error_exit "$cmd 未安装"
    fi
    success "$cmd 已安装: $("$cmd" --version 2>/dev/null | head -1 || echo "版本信息不可用")"
}

# 检查文件是否存在
check_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        warning "$file 文件不存在"
        return 1
    fi
    success "$file 文件存在"
    return 0
}

# 检查目录是否存在，如果不存在则创建
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        success "创建目录: $dir"
    fi
}

# 安全删除文件/目录
safe_remove() {
    local path="$1"
    if [ -e "$path" ]; then
        rm -rf "$path"
        success "删除: $path"
    fi
}

# 配置文件加载函数
load_config() {
    local config_file="$SCRIPT_DIR/config.sh"
    if [ -f "$config_file" ]; then
        verbose_echo "加载配置文件: $config_file"
        # shellcheck disable=SC1090
        source "$config_file"
    else
        verbose_echo "配置文件不存在，使用默认设置"
    fi
}

# 重试机制
with_retry() {
    local max_attempts="${1:-3}"
    local delay="${2:-1}"
    local cmd="$3"
    local attempt=1

    while [ $attempt -le "$max_attempts" ]; do
        verbose_echo "执行尝试 $attempt/$max_attempts: $cmd"

        if eval "$cmd"; then
            return 0
        fi

        if [ $attempt -lt "$max_attempts" ]; then
            warning "命令失败，${delay}秒后重试..."
            sleep "$delay"
            delay=$((delay * 2))  # 指数退避
        fi

        attempt=$((attempt + 1))
    done

    error_exit "命令在 $max_attempts 次尝试后仍然失败"
}

# 并行执行函数
parallel_exec() {
    local max_jobs="${1:-4}"
    local cmds=("${@:2}")
    local pids=()
    local results=()

    # 启动并行任务
    for cmd in "${cmds[@]}"; do
        if [ ${#pids[@]} -ge "$max_jobs" ]; then
            # 等待一个任务完成
            wait "${pids[0]}"
            unset 'pids[0]'
            pids=("${pids[@]}")
        fi

        verbose_echo "启动并行任务: $cmd"
        eval "$cmd" &
        pids+=($!)
    done

    # 等待所有任务完成
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            results+=("任务 $pid 失败")
        fi
    done

    if [ ${#results[@]} -gt 0 ]; then
        error_exit "并行任务失败: ${results[*]}"
    fi
}

# 性能监控函数
start_performance_monitoring() {
    if [ "$ENABLE_PERFORMANCE_MONITORING" = "true" ]; then
        verbose_echo "启动性能监控"

        # 记录开始时间和资源使用
        PERF_START_TIME=$(date +%s)
        PERF_START_MEM=$(get_memory_usage)
        PERF_START_CPU=$(get_cpu_usage)

        # 在后台启动监控进程
        (
            while kill -0 $$ 2>/dev/null; do
                sleep "${METRICS_INTERVAL:-5}"
                log_performance_metrics
            done
        ) &
        PERF_MONITOR_PID=$!
    fi
}

stop_performance_monitoring() {
    if [ -n "$PERF_MONITOR_PID" ]; then
        kill "$PERF_MONITOR_PID" 2>/dev/null || true
        wait "$PERF_MONITOR_PID" 2>/dev/null || true

        # 计算并显示最终统计信息
        show_final_performance_stats
    fi
}

# 获取内存使用情况
get_memory_usage() {
    case "$OS" in
        macos)
            vm_stat | awk '/Pages active/ {print $3}' | tr -d '.'
            ;;
        linux)
            free | awk 'NR==2{printf "%.0f", $3*100/$2 }'
            ;;
        *)
            echo "0"
            ;;
    esac
}

# 获取CPU使用情况
get_cpu_usage() {
    case "$OS" in
        macos)
            ps -p $$ -o %cpu | tail -1 | tr -d ' '
            ;;
        linux)
            top -b -n1 | grep "Cpu(s)" | awk '{print $2 + $4}'
            ;;
        *)
            echo "0"
            ;;
    esac
}

# 记录性能指标
log_performance_metrics() {
    local current_time=$(date +%s)
    local elapsed=$((current_time - PERF_START_TIME))
    local current_mem=$(get_memory_usage)
    local current_cpu=$(get_cpu_usage)

    if [ "$LOG_LEVEL" = "debug" ] || [ "$VERBOSE" = true ]; then
        verbose_echo "性能指标 [$elapsed秒]: CPU=${current_cpu}%, MEM=${current_mem}KB"
    fi
}

# 显示最终性能统计
show_final_performance_stats() {
    local end_time=$(date +%s)
    local total_time=$((end_time - PERF_START_TIME))
    local end_mem=$(get_memory_usage)
    local end_cpu=$(get_cpu_usage)

    echo ""
    echo -e "${CYAN}📊 性能统计:${NC}"
    echo -e "  ${BLUE}总耗时:${NC} ${total_time}秒"
    echo -e "  ${BLUE}平均CPU:${NC} ${end_cpu}%"
    echo -e "  ${BLUE}内存使用:${NC} ${end_mem}KB"

    # 检查性能阈值
    if [ "$total_time" -gt "${BUILD_TIME_ERROR_THRESHOLD:-120000}" ]; then
        warning "执行时间超过阈值，可能存在性能问题"
    elif [ "$total_time" -gt "${BUILD_TIME_WARNING_THRESHOLD:-30000}" ]; then
        info "执行时间较长，建议优化"
    fi
}

# 增强的日志记录
enhanced_logging() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # 格式化日志消息
    local log_message="[$timestamp] [$level] $message"

    # 输出到控制台
    if [ "$LOG_TO_CONSOLE" = "true" ]; then
        case "$level" in
            ERROR) echo -e "${RED}${log_message}${NC}" ;;
            WARN)  echo -e "${YELLOW}${log_message}${NC}" ;;
            INFO)  echo -e "${BLUE}${log_message}${NC}" ;;
            DEBUG) echo -e "${CYAN}${log_message}${NC}" ;;
            *)     echo "$log_message" ;;
        esac
    fi

    # 输出到日志文件
    if [ -n "$LOG_FILE" ]; then
        ensure_dir "$(dirname "$LOG_FILE")"
        echo "$log_message" >> "$LOG_FILE"

        # 日志轮转
        rotate_log_if_needed
    fi
}

# 日志轮转
rotate_log_if_needed() {
    if [ -f "$LOG_FILE" ] && [ -n "$LOG_ROTATE_SIZE" ]; then
        local size_mb
        size_mb=$(du -m "$LOG_FILE" 2>/dev/null | cut -f1)

        if [ "$size_mb" -gt "${LOG_ROTATE_SIZE:-10}" ]; then
            verbose_echo "日志文件达到大小限制，开始轮转"

            # 重命名现有日志文件
            local i="${LOG_RETENTION_COUNT:-5}"
            while [ $i -gt 1 ]; do
                if [ -f "${LOG_FILE}.$((i-1))" ]; then
                    mv "${LOG_FILE}.$((i-1))" "${LOG_FILE}.$i"
                fi
                i=$((i-1))
            done

            # 创建新的日志文件
            mv "$LOG_FILE" "${LOG_FILE}.1"
        fi
    fi
}

# 网络请求函数（带重试）
http_request() {
    local url="$1"
    local output_file="$2"
    local max_attempts="${3:-${MAX_RETRY_ATTEMPTS:-3}}"

    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        error_exit "需要 curl 或 wget 进行网络请求"
    fi

    local attempt=1
    while [ $attempt -le "$max_attempts" ]; do
        verbose_echo "网络请求尝试 $attempt/$max_attempts: $url"

        if command -v curl &> /dev/null; then
            if curl -fsSL --connect-timeout "${NETWORK_TIMEOUT:-30}" \
                      --max-time "${NETWORK_TIMEOUT:-30}" \
                      "$url" -o "$output_file" 2>/dev/null; then
                return 0
            fi
        elif command -v wget &> /dev/null; then
            if wget -q --timeout="${NETWORK_TIMEOUT:-30}" "$url" -O "$output_file" 2>/dev/null; then
                return 0
            fi
        fi

        attempt=$((attempt + 1))
        if [ $attempt -le "$max_attempts" ]; then
            sleep 2
        fi
    done

    error_exit "网络请求失败: $url"
}

# 文件完整性验证
verify_file_integrity() {
    local file="$1"
    local expected_hash="$2"

    if [ "$VERIFY_FILE_INTEGRITY" = "true" ] && [ -n "$expected_hash" ]; then
        if command -v sha256sum &> /dev/null; then
            local actual_hash
            actual_hash=$(sha256sum "$file" | cut -d' ' -f1)
            if [ "$actual_hash" != "$expected_hash" ]; then
                error_exit "文件完整性验证失败: $file"
            fi
            verbose_echo "文件完整性验证通过: $file"
        fi
    fi
}

# 安全文件操作
secure_create_file() {
    local file="$1"
    local content="$2"

    # 创建临时文件
    local temp_file
    temp_file=$(mktemp)

    # 写入内容到临时文件
    echo "$content" > "$temp_file"

    # 原子性移动到目标位置
    mv "$temp_file" "$file"

    # 设置适当权限
    if [[ "$file" == *".sh" ]] || [[ "$file" == *".env" ]]; then
        chmod 755 "$file" 2>/dev/null || true
    fi
}

# 初始化脚本环境
init_script_env() {
    # 加载配置
    load_config

    # 设置日志
    if [ "$LOG_LEVEL" = "debug" ]; then
        VERBOSE=true
    fi

    # 启动性能监控
    start_performance_monitoring

    # 设置错误处理
    set -e
    trap 'stop_performance_monitoring' EXIT
}

# 清理脚本环境
cleanup_script_env() {
    stop_performance_monitoring
}

# 显示帮助信息
show_help() {
    local script_name="$1"
    local description="$2"

    cat << EOF
${script_name} - ${description}

用法:
  ./${script_name} [选项]

选项:
  -h, --help    显示此帮助信息
  -v, --verbose 详细输出模式

示例:
  ./${script_name}              # 正常运行
  ./${script_name} --verbose    # 详细模式

EOF
}

# 解析通用参数
parse_common_args() {
    VERBOSE=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help "$(basename "$0")" "$SCRIPT_DESCRIPTION"
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            *)
                break
                ;;
        esac
    done
}

# 详细输出
verbose_echo() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}[VERBOSE]${NC} $1"
    fi
}

# 计时开始
timer_start() {
    TIMER_START=$(date +%s)
}

# 计时结束并显示耗时
timer_end() {
    local end_time=$(date +%s)
    local duration=$((end_time - TIMER_START))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    if [ $minutes -gt 0 ]; then
        success "耗时: ${minutes}分${seconds}秒"
    else
        success "耗时: ${seconds}秒"
    fi
}

# Zig 相关函数
check_zig() {
    check_command "zig"
    verbose_echo "Zig 版本详情: $(zig version)"
}

# Zig 构建函数
zig_build() {
    local build_args="$*"
    verbose_echo "执行: zig build $build_args"

    if ! zig build $build_args; then
        error_exit "Zig 构建失败"
    fi
}

# Zig 测试函数
zig_test() {
    local test_args="$*"
    verbose_echo "执行: zig build test $test_args"

    if zig build test $test_args; then
        success "所有测试通过"
    else
        warning "部分测试失败"
        return 1
    fi
}

# 项目相关检查
check_env_file() {
    local project_root
    project_root="$(get_project_root)"

    if [ ! -f "$project_root/.env" ]; then
        if [ -f "$project_root/.env.example" ]; then
            cp "$project_root/.env.example" "$project_root/.env"
            success ".env 文件已从 .env.example 创建"
        else
            warning ".env 和 .env.example 文件都不存在"
            return 1
        fi
    else
        success ".env 文件已存在"
    fi
}

# 创建必要的目录
create_dirs() {
    local dirs=("logs" "uploads" "tmp" "backups")

    for dir in "${dirs[@]}"; do
        ensure_dir "$dir"
    done
}

# 设置脚本权限
set_script_permissions() {
    local scripts_dir
    scripts_dir="$(get_script_dir)"

    if [ -d "$scripts_dir" ]; then
        chmod +x "$scripts_dir"/*.sh 2>/dev/null || true
        success "脚本权限已设置"
    fi
}

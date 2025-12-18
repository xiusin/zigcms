# ZigCMS 脚本配置文件
# 这个文件包含了所有脚本的默认配置

# =============================================================================
# 构建配置
# =============================================================================

# 默认构建模式 (debug/release/fast/small)
DEFAULT_BUILD_MODE="debug"

# 默认构建超时时间（秒）
BUILD_TIMEOUT="600"

# 交叉编译目标平台
# 支持: x86_64-linux, aarch64-linux, x86_64-macos, aarch64-macos, x86_64-windows
CROSS_TARGETS="x86_64-linux aarch64-linux"

# 是否启用并行构建
PARALLEL_BUILD="true"

# 构建产物保留数量（用于历史版本管理）
KEEP_BUILD_ARTIFACTS="5"

# =============================================================================
# 开发环境配置
# =============================================================================

# 默认开发服务器配置
DEV_HOST="127.0.0.1"
DEV_PORT="8080"

# 文件监听配置
WATCH_EXCLUDE_PATTERNS=".zig-cache zig-out logs *.log tmp *.tmp .git node_modules *.db*"

# 热重载延迟时间（毫秒）
HOT_RELOAD_DELAY="1000"

# 自动重启最大尝试次数
MAX_RESTART_ATTEMPTS="10"

# =============================================================================
# 测试配置
# =============================================================================

# 默认测试类型
DEFAULT_TEST_TYPE="unit"

# 测试超时时间（秒）
TEST_TIMEOUT="300"

# 覆盖率报告配置
COVERAGE_DIR="coverage"
COVERAGE_EXCLUDE_PATTERNS=".zig-cache zig-out test external"

# 性能基准测试配置
BENCH_ITERATIONS="1000"
BENCH_WARMUP_ITERATIONS="100"

# 是否启用竞争检测（影响性能）
ENABLE_RACE_DETECTOR="false"

# =============================================================================
# 清理配置
# =============================================================================

# 默认清理目标
DEFAULT_CLEAN_TARGET="all"

# 日志文件保留天数
LOG_RETENTION_DAYS="7"

# 是否启用激进清理模式
AGGRESSIVE_CLEAN="false"

# 清理前是否总是显示确认提示
ALWAYS_CONFIRM_CLEAN="true"

# =============================================================================
# 依赖和环境配置
# =============================================================================

# 支持的包管理器（按优先级排序）
PACKAGE_MANAGERS="brew apt yum dnf pacman"

# Zig 版本要求
REQUIRED_ZIG_VERSION="0.13.0"

# 是否自动安装缺失依赖
AUTO_INSTALL_DEPS="true"

# 网络超时时间（秒）
NETWORK_TIMEOUT="30"

# 最大重试次数
MAX_RETRY_ATTEMPTS="3"

# =============================================================================
# 性能和监控配置
# =============================================================================

# 是否启用性能监控
ENABLE_PERFORMANCE_MONITORING="true"

# 性能指标收集间隔（秒）
METRICS_INTERVAL="5"

# 是否启用详细的内存使用统计
DETAILED_MEMORY_STATS="false"

# 构建性能阈值（毫秒）
BUILD_TIME_WARNING_THRESHOLD="30000"
BUILD_TIME_ERROR_THRESHOLD="120000"

# =============================================================================
# 日志配置
# =============================================================================

# 日志级别 (debug/info/warn/error)
LOG_LEVEL="info"

# 日志文件位置
LOG_FILE="logs/scripts.log"

# 日志轮转大小 (MB)
LOG_ROTATE_SIZE="10"

# 保留日志文件数量
LOG_RETENTION_COUNT="5"

# 是否同时输出到控制台
LOG_TO_CONSOLE="true"

# =============================================================================
# 安全配置
# =============================================================================

# 是否验证文件完整性
VERIFY_FILE_INTEGRITY="true"

# 敏感文件权限检查
CHECK_FILE_PERMISSIONS="true"

# 网络安全检查（证书验证等）
SECURE_NETWORK_REQUESTS="true"

# =============================================================================
# 自定义配置
# =============================================================================

# 用户自定义的环境变量
# CUSTOM_ENV_VARS="MY_VAR1=value1 MY_VAR2=value2"

# 自定义构建参数
# CUSTOM_BUILD_ARGS="--verbose"

# 自定义测试过滤器
# CUSTOM_TEST_FILTER=""

# 脚本扩展目录
# SCRIPTS_EXT_DIR="scripts/ext"

# ZigCMS 脚本系统使用指南

## 📖 概述

ZigCMS 脚本系统提供了一套完整的项目管理工具，支持构建、开发、测试、清理和初始化等全生命周期操作。所有脚本都经过深度优化，具备企业级功能特性。

### 🎯 核心特性

- **统一工具库**：所有脚本共享通用工具库，保证一致性和可维护性
- **配置文件系统**：通过配置文件灵活定制脚本行为，无需修改代码
- **智能错误处理**：自动重试、性能监控、详细错误报告
- **跨平台支持**：完美支持 macOS、Linux 等多种操作系统
- **企业级功能**：并行处理、性能监控、日志轮转、安全操作

## 🚀 快速开始

### 环境准备

```bash
# 克隆项目
git clone <repository-url>
cd zigcms

# 初始化项目环境
./scripts/setup.sh
```

### 常用命令

```bash
# 开发环境启动
./scripts/dev.sh

# 构建项目
./scripts/build.sh

# 运行测试
./scripts/test.sh

# 清理项目
./scripts/clean.sh
```

## 📋 脚本清单

| 脚本文件 | 功能描述 | 使用频率 |
|---------|---------|---------|
| `build.sh` | 项目构建和编译 | ⭐⭐⭐⭐⭐ |
| `dev.sh` | 开发环境启动 | ⭐⭐⭐⭐⭐ |
| `test.sh` | 测试执行和分析 | ⭐⭐⭐⭐ |
| `clean.sh` | 项目清理维护 | ⭐⭐⭐⭐ |
| `setup.sh` | 项目初始化 | ⭐⭐⭐ |
| `common.sh` | 通用工具库 | 🔧 |
| `config.sh` | 配置文件 | ⚙️ |

## 🏗️ 详细使用指南

### build.sh - 构建脚本

专业的项目构建工具，支持多种构建模式和交叉编译。

#### 基本用法

```bash
# 调试模式构建（默认）
./scripts/build.sh
./scripts/build.sh debug

# 发布模式构建
./scripts/build.sh release  # 安全优化
./scripts/build.sh fast     # 性能优化
./scripts/build.sh small    # 体积优化

# 交叉编译
./scripts/build.sh cross x86_64-linux
./scripts/build.sh cross aarch64-macos

# 并行构建多个平台
./scripts/build.sh parallel

# 清理后重新构建
./scripts/build.sh clean
```

#### 高级选项

```bash
# 详细输出
./scripts/build.sh --verbose release

# 帮助信息
./scripts/build.sh --help
```

#### 应用场景

- **日常开发**：`./scripts/build.sh debug` - 快速调试构建
- **发布准备**：`./scripts/build.sh release` - 生产环境构建
- **跨平台部署**：`./scripts/build.sh cross x86_64-linux` - Linux部署包
- **CI/CD集成**：`./scripts/build.sh fast` - 快速构建用于自动化测试

### dev.sh - 开发环境脚本

专为开发者优化的开发环境启动工具，提供热重载和调试支持。

#### 基本用法

```bash
# 启动开发服务器（默认8080端口）
./scripts/dev.sh

# 指定端口和主机
./scripts/dev.sh --port 3000 --host 0.0.0.0

# 启用文件监听热重载
./scripts/dev.sh --watch

# 跳过构建直接运行
./scripts/dev.sh --no-build
```

#### 高级选项

```bash
# 清理后构建并启动
./scripts/dev.sh --clean-build --watch

# 详细输出模式
./scripts/dev.sh --verbose --watch

# 帮助信息
./scripts/dev.sh --help
```

#### 应用场景

- **日常开发**：`./scripts/dev.sh --watch` - 热重载开发环境
- **API调试**：`./scripts/dev.sh --port 3000` - 自定义端口调试
- **团队协作**：`./scripts/dev.sh --host 0.0.0.0` - 局域网访问
- **性能调试**：`./scripts/dev.sh --verbose` - 详细日志分析

### test.sh - 测试脚本

完整的测试套件，支持单元测试、集成测试和覆盖率分析。

#### 基本用法

```bash
# 运行单元测试（默认）
./scripts/test.sh
./scripts/test.sh unit

# 运行集成测试
./scripts/test.sh integration

# 运行所有测试
./scripts/test.sh all

# 运行性能基准测试
./scripts/test.sh bench

# 生成覆盖率报告
./scripts/test.sh coverage
```

#### 高级选项

```bash
# 遇到失败立即停止
./scripts/test.sh --fail-fast all

# 设置超时时间（秒）
./scripts/test.sh --timeout 600 all

# 详细输出模式
./scripts/test.sh --verbose coverage

# 帮助信息
./scripts/test.sh --help
```

#### 应用场景

- **代码质量保证**：`./scripts/test.sh all` - 完整测试套件
- **持续集成**：`./scripts/test.sh --fail-fast unit` - CI流水线
- **代码覆盖分析**：`./scripts/test.sh coverage` - 覆盖率报告
- **性能回归测试**：`./scripts/test.sh bench` - 性能基准

### clean.sh - 清理脚本

智能的项目清理工具，支持分类清理和安全确认。

#### 基本用法

```bash
# 清理所有内容（默认）
./scripts/clean.sh
./scripts/clean.sh all

# 分类清理
./scripts/clean.sh build    # 清理构建文件
./scripts/clean.sh cache    # 清理缓存文件
./scripts/clean.sh temp     # 清理临时文件
./scripts/clean.sh logs     # 清理日志文件
./scripts/clean.sh db       # 清理数据库文件
```

#### 高级选项

```bash
# 预览清理内容（不实际删除）
./scripts/clean.sh --dry-run all

# 跳过确认提示
./scripts/clean.sh --yes build

# 激进清理模式
./scripts/clean.sh --aggressive logs

# 详细输出
./scripts/clean.sh --verbose all

# 帮助信息
./scripts/clean.sh --help
```

#### 应用场景

- **磁盘空间管理**：`./scripts/clean.sh all` - 定期清理
- **构建环境重置**：`./scripts/clean.sh build` - 解决构建问题
- **安全清理**：`./scripts/clean.sh --dry-run` - 确认清理内容
- **日志维护**：`./scripts/clean.sh logs` - 日志轮转

### setup.sh - 初始化脚本

一键项目初始化工具，自动检测和安装依赖。

#### 基本用法

```bash
# 完整项目初始化
./scripts/setup.sh

# 强制重新初始化
./scripts/setup.sh --force

# 禁用自动修复
./scripts/setup.sh --no-auto-fix
```

#### 高级选项

```bash
# 详细输出模式
./scripts/setup.sh --verbose

# 帮助信息
./scripts/setup.sh --help
```

#### 应用场景

- **新项目设置**：`./scripts/setup.sh` - 全新环境初始化
- **环境迁移**：`./scripts/setup.sh --force` - 重新配置环境
- **团队协作**：自动确保所有成员环境一致

## ⚙️ 配置系统

### config.sh - 配置文件

所有脚本行为都可以通过 `scripts/config.sh` 文件进行配置。

#### 配置分类

```bash
# =============================================================================
# 构建配置
# =============================================================================
DEFAULT_BUILD_MODE="debug"          # 默认构建模式
BUILD_TIMEOUT="600"                 # 构建超时时间
PARALLEL_BUILD="true"              # 启用并行构建
KEEP_BUILD_ARTIFACTS="5"           # 保留构建产物数量

# =============================================================================
# 开发环境配置
# =============================================================================
DEV_HOST="127.0.0.1"               # 开发服务器主机
DEV_PORT="8080"                    # 开发服务器端口
WATCH_EXCLUDE_PATTERNS=".zig-cache zig-out logs *.log"  # 文件监听排除模式
HOT_RELOAD_DELAY="1000"            # 热重载延迟(ms)

# =============================================================================
# 测试配置
# =============================================================================
DEFAULT_TEST_TYPE="unit"            # 默认测试类型
TEST_TIMEOUT="300"                  # 测试超时时间
COVERAGE_DIR="coverage"             # 覆盖率报告目录
ENABLE_RACE_DETECTOR="false"        # 启用竞争检测

# =============================================================================
# 清理配置
# =============================================================================
DEFAULT_CLEAN_TARGET="all"          # 默认清理目标
LOG_RETENTION_DAYS="7"              # 日志保留天数
AGGRESSIVE_CLEAN="false"            # 激进清理模式

# =============================================================================
# 性能和监控配置
# =============================================================================
ENABLE_PERFORMANCE_MONITORING="true"   # 启用性能监控
METRICS_INTERVAL="5"                   # 监控间隔(秒)
BUILD_TIME_WARNING_THRESHOLD="30000"   # 构建时间警告阈值(ms)

# =============================================================================
# 日志配置
# =============================================================================
LOG_LEVEL="info"                     # 日志级别 (debug/info/warn/error)
LOG_FILE="logs/scripts.log"          # 日志文件路径
LOG_ROTATE_SIZE="10"                 # 日志轮转大小(MB)
LOG_RETENTION_COUNT="5"              # 日志保留数量
LOG_TO_CONSOLE="true"                # 同时输出到控制台
```

#### 自定义配置

```bash
# 在 config.sh 中添加自定义配置
echo 'DEFAULT_BUILD_MODE="release"' >> scripts/config.sh
echo 'ENABLE_PERFORMANCE_MONITORING="true"' >> scripts/config.sh
```

### common.sh - 通用工具库

提供所有脚本共享的功能函数和工具。

#### 主要功能

- **错误处理**：统一的错误处理和重试机制
- **并行处理**：支持并行执行多个任务
- **性能监控**：实时监控系统资源使用
- **日志系统**：多级别日志记录和文件轮转
- **网络操作**：带重试的网络请求功能
- **文件操作**：安全的文件操作和完整性验证

## 🎭 常见使用场景

### 开发工作流

```bash
# 1. 初始化新项目
./scripts/setup.sh

# 2. 启动开发环境
./scripts/dev.sh --watch --port 3000

# 3. 运行测试
./scripts/test.sh all

# 4. 构建发布版本
./scripts/build.sh release

# 5. 生成覆盖率报告
./scripts/test.sh coverage
```

### CI/CD 集成

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup
        run: ./scripts/setup.sh --no-auto-fix
      - name: Test
        run: ./scripts/test.sh all --fail-fast
      - name: Build
        run: ./scripts/build.sh release
      - name: Coverage
        run: ./scripts/test.sh coverage
```

### 生产部署

```bash
# 1. 清理环境
./scripts/clean.sh build --yes

# 2. 并行构建多个平台
./scripts/build.sh parallel

# 3. 运行完整测试套件
./scripts/test.sh all --fail-fast

# 4. 生成覆盖率报告
./scripts/test.sh coverage

# 5. 清理临时文件
./scripts/clean.sh temp --aggressive
```

### 团队协作

```bash
# 团队成员加入项目
./scripts/setup.sh --force

# 开发环境配置
./scripts/dev.sh --watch --host 0.0.0.0 --port 8080

# 代码质量检查
./scripts/test.sh all
./scripts/test.sh coverage

# 构建部署包
./scripts/build.sh cross x86_64-linux
./scripts/build.sh cross aarch64-linux
```

### 维护和清理

```bash
# 定期维护
./scripts/clean.sh logs              # 清理旧日志
./scripts/clean.sh cache             # 清理缓存
./scripts/clean.sh build             # 清理构建文件

# 深度清理
./scripts/clean.sh --aggressive all  # 激进清理所有内容

# 安全清理（预览模式）
./scripts/clean.sh --dry-run all     # 查看将删除的内容
```

## 🔧 故障排除

### 常见问题

#### 构建失败

```bash
# 检查 Zig 版本
zig version

# 清理缓存后重新构建
./scripts/clean.sh build
./scripts/build.sh clean

# 详细输出调试
./scripts/build.sh --verbose debug
```

#### 测试失败

```bash
# 运行特定测试
./scripts/test.sh unit
./scripts/test.sh integration

# 检查测试依赖
./scripts/setup.sh --force

# 详细测试输出
./scripts/test.sh --verbose all
```

#### 脚本权限问题

```bash
# 修复脚本权限
chmod +x scripts/*.sh

# 重新初始化
./scripts/setup.sh --force
```

#### 配置问题

```bash
# 检查配置文件
cat scripts/config.sh

# 重置配置
cp scripts/config.sh scripts/config.sh.backup
# 编辑 config.sh 进行修改
```

#### 依赖安装失败

```bash
# 手动安装依赖
# macOS
brew install zig

# Ubuntu/Debian
sudo apt update && sudo apt install -y build-essential

# 然后重新运行
./scripts/setup.sh --force
```

### 日志分析

```bash
# 查看脚本日志
tail -f logs/scripts.log

# 启用详细日志
echo 'LOG_LEVEL="debug"' >> scripts/config.sh
./scripts/build.sh --verbose

# 性能监控日志
echo 'ENABLE_PERFORMANCE_MONITORING="true"' >> scripts/config.sh
```

## 📚 扩展和定制

### 添加新脚本

```bash
# 1. 创建新脚本
touch scripts/deploy.sh
chmod +x scripts/deploy.sh

# 2. 添加标准头部
cat > scripts/deploy.sh << 'EOF'
#!/usr/bin/env bash
# ZigCMS 部署脚本

SCRIPT_DESCRIPTION="ZigCMS 部署脚本"

# 导入通用工具库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 初始化脚本环境
init_script_env

# 解析参数
parse_common_args "$@"

# 主函数
main() {
    # 部署逻辑
    echo "部署功能待实现"
}

# 运行主函数
main "$@"
EOF
```

### 自定义配置

```bash
# 在 config.sh 中添加新配置项
echo '# 部署配置' >> scripts/config.sh
echo 'DEPLOY_TARGET="production"' >> scripts/config.sh
echo 'DEPLOY_METHOD="docker"' >> scripts/config.sh
```

### 扩展工具库

```bash
# 在 common.sh 中添加新函数
cat >> scripts/common.sh << 'EOF'

# 新增的工具函数
custom_function() {
    local param="$1"
    verbose_echo "执行自定义功能: $param"
    # 实现逻辑
}

# 导出函数供其他脚本使用
export -f custom_function
EOF
```

## 📞 技术支持

如遇到问题，请：

1. 查看脚本帮助：`./scripts/SCRIPT_NAME.sh --help`
2. 检查日志文件：`tail -f logs/scripts.log`
3. 启用详细模式：`./scripts/SCRIPT_NAME.sh --verbose`
4. 查看配置文件：`cat scripts/config.sh`

## 📝 更新日志

### v2.0.0 (最新)
- ✨ 重构脚本系统，支持配置文件
- 🚀 添加并行构建和热重载功能
- 📊 集成性能监控和覆盖率分析
- 🔄 实现智能重试和错误恢复
- 📝 完善日志系统和文档

### v1.0.0
- 🏗️ 基础构建、测试、清理功能
- 📦 简单的项目初始化
- 🔧 基本的错误处理

---

**ZigCMS 脚本系统** - 让开发更高效，让部署更可靠！🚀

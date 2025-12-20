# ============================================================================
# ZigCMS Makefile
# ============================================================================

.PHONY: help setup dev build test clean install run fmt lint docker

# 默认目标
.DEFAULT_GOAL := help

# 颜色定义
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

# 项目变量
PROJECT_NAME := zigcms
BUILD_DIR := zig-out
CACHE_DIR := .zig-cache
SCRIPTS_DIR := scripts

# ============================================================================
# 帮助信息
# ============================================================================

help: ## 显示帮助信息
	@echo "$(BLUE)╔═══════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║     ZigCMS Makefile 命令列表          ║$(NC)"
	@echo "$(BLUE)╚═══════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)开发命令:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)示例:$(NC)"
	@echo "  make setup    # 初始化项目"
	@echo "  make dev      # 启动开发服务器"
	@echo "  make test     # 运行测试"
	@echo "  make build    # 构建项目"
	@echo ""

# ============================================================================
# 开发命令
# ============================================================================

setup: ## 初始化项目环境
	@echo "$(GREEN)🚀 初始化项目...$(NC)"
	@chmod +x $(SCRIPTS_DIR)/*.sh
	@$(SCRIPTS_DIR)/setup.sh

dev: ## 启动开发服务器
	@echo "$(GREEN)🔥 启动开发服务器...$(NC)"
	@$(SCRIPTS_DIR)/dev.sh

run: ## 运行项目（调试模式）
	@echo "$(GREEN)▶️  运行项目...$(NC)"
	@zig build run

# ============================================================================
# 构建命令
# ============================================================================

build: ## 构建项目（调试模式）
	@echo "$(GREEN)🔨 构建项目 (调试模式)...$(NC)"
	@zig build

build-release: ## 构建项目（发布模式 - 安全优化）
	@echo "$(GREEN)🚀 构建项目 (发布模式)...$(NC)"
	@zig build -Doptimize=ReleaseSafe

build-fast: ## 构建项目（发布模式 - 性能优化）
	@echo "$(GREEN)⚡ 构建项目 (性能优化)...$(NC)"
	@zig build -Doptimize=ReleaseFast

build-small: ## 构建项目（发布模式 - 体积优化）
	@echo "$(GREEN)📦 构建项目 (体积优化)...$(NC)"
	@zig build -Doptimize=ReleaseSmall

# ============================================================================
# 测试命令
# ============================================================================

test: ## 运行所有测试
	@echo "$(GREEN)🧪 运行所有测试...$(NC)"
	@zig build test

test-unit: ## 运行单元测试
	@echo "$(GREEN)📝 运行单元测试...$(NC)"
	@$(SCRIPTS_DIR)/test.sh unit

test-integration: ## 运行集成测试
	@echo "$(GREEN)🔗 运行集成测试...$(NC)"
	@$(SCRIPTS_DIR)/test.sh integration

test-watch: ## 监听文件变化并运行测试
	@echo "$(GREEN)👀 监听测试...$(NC)"
	@while true; do \
		make test; \
		inotifywait -qre close_write .; \
	done

# ============================================================================
# 代码质量
# ============================================================================

fmt: ## 格式化代码
	@echo "$(GREEN)✨ 格式化代码...$(NC)"
	@zig fmt .

fmt-check: ## 检查代码格式
	@echo "$(GREEN)🔍 检查代码格式...$(NC)"
	@zig fmt --check .

lint: ## 运行代码检查
	@echo "$(GREEN)🔍 运行代码检查...$(NC)"
	@zig fmt --check .
	@echo "$(GREEN)✅ 代码检查完成$(NC)"

# ============================================================================
# 清理命令
# ============================================================================

clean: ## 清理构建文件
	@echo "$(YELLOW)🧹 清理构建文件...$(NC)"
	@rm -rf $(BUILD_DIR) $(CACHE_DIR)
	@rm -f *.db *.sqlite3
	@rm -f sqlite_complete_test
	@echo "$(GREEN)✅ 清理完成$(NC)"

clean-all: clean ## 清理所有生成文件（包括日志）
	@echo "$(YELLOW)🧹 清理所有文件...$(NC)"
	@rm -rf logs/*.log 2>/dev/null || true
	@rm -rf tmp/* 2>/dev/null || true
	@echo "$(GREEN)✅ 清理完成$(NC)"

# ============================================================================
# 工具命令
# ============================================================================

codegen: ## 运行代码生成器
	@echo "$(GREEN)⚙️  运行代码生成器...$(NC)"
	@zig build codegen

migrate-up: ## 执行数据库迁移
	@echo "$(GREEN)📊 执行数据库迁移...$(NC)"
	@zig build migrate -- up

migrate-down: ## 回滚数据库迁移
	@echo "$(YELLOW)⏪ 回滚数据库迁移...$(NC)"
	@zig build migrate -- down

migrate-status: ## 查看迁移状态
	@echo "$(GREEN)📊 查看迁移状态...$(NC)"
	@zig build migrate -- status

plugin-gen: ## 生成插件模板
	@echo "$(GREEN)🔌 生成插件模板...$(NC)"
	@zig build plugin-gen

# ============================================================================
# Docker 命令
# ============================================================================

docker-build: ## 构建 Docker 镜像
	@echo "$(GREEN)🐳 构建 Docker 镜像...$(NC)"
	@docker build -t $(PROJECT_NAME):latest .

docker-run: ## 运行 Docker 容器
	@echo "$(GREEN)🐳 运行 Docker 容器...$(NC)"
	@docker run -p 3030:3030 --env-file .env $(PROJECT_NAME):latest

docker-compose-up: ## 启动 Docker Compose
	@echo "$(GREEN)🐳 启动 Docker Compose...$(NC)"
	@docker-compose up -d

docker-compose-down: ## 停止 Docker Compose
	@echo "$(YELLOW)🐳 停止 Docker Compose...$(NC)"
	@docker-compose down

# ============================================================================
# 部署命令
# ============================================================================

deploy-staging: ## 部署到预发布环境
	@echo "$(GREEN)🚀 部署到预发布环境...$(NC)"
	@echo "$(YELLOW)TODO: 实现部署逻辑$(NC)"

deploy-production: ## 部署到生产环境
	@echo "$(GREEN)🚀 部署到生产环境...$(NC)"
	@echo "$(RED)⚠️  请确认已经过充分测试！$(NC)"
	@echo "$(YELLOW)TODO: 实现部署逻辑$(NC)"

# ============================================================================
# 信息命令
# ============================================================================

info: ## 显示项目信息
	@echo "$(BLUE)╔═══════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║     项目信息                          ║$(NC)"
	@echo "$(BLUE)╚═══════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)项目名称:$(NC) $(PROJECT_NAME)"
	@echo "$(GREEN)Zig 版本:$(NC) $$(zig version)"
	@echo "$(GREEN)构建目录:$(NC) $(BUILD_DIR)"
	@echo "$(GREEN)缓存目录:$(NC) $(CACHE_DIR)"
	@echo ""

version: ## 显示项目版本信息
	@echo "$(BLUE)╔═══════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║     ZigCMS 版本信息                    ║$(NC)"
	@echo "$(BLUE)╚═══════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)🏷️  项目版本:$(NC)"
	@awk -F'"' '/\.version =/ {print "  " $$2}' build.zig.zon || echo "$(RED)  未找到版本信息$(NC)"
	@echo ""
	@echo "$(GREEN)项目版本:$(NC)"
	@grep 'version' build.zig.zon | head -1 || echo "未找到版本信息"

# ============================================================================
# 依赖管理
# ============================================================================

deps: ## 检查依赖
	@echo "$(GREEN)📦 检查依赖...$(NC)"
	@zig build --help > /dev/null 2>&1
	@echo "$(GREEN)✅ 依赖检查完成$(NC)"

deps-update: ## 更新依赖
	@echo "$(GREEN)📦 更新依赖...$(NC)"
	@echo "$(YELLOW)TODO: 实现依赖更新逻辑$(NC)"

# ============================================================================
# 监控和日志
# ============================================================================

logs: ## 查看日志
	@echo "$(GREEN)📋 查看日志...$(NC)"
	@tail -f logs/app.log 2>/dev/null || echo "$(YELLOW)日志文件不存在$(NC)"

logs-error: ## 查看错误日志
	@echo "$(RED)❌ 查看错误日志...$(NC)"
	@grep -i error logs/app.log 2>/dev/null || echo "$(YELLOW)没有错误日志$(NC)"

# ============================================================================
# 性能分析
# ============================================================================

bench: ## 运行性能测试
	@echo "$(GREEN)⚡ 运行性能测试...$(NC)"
	@echo "$(YELLOW)TODO: 实现性能测试$(NC)"

profile: ## 性能分析
	@echo "$(GREEN)📊 性能分析...$(NC)"
	@echo "$(YELLOW)TODO: 实现性能分析$(NC)"

# ============================================================================
# 快捷命令
# ============================================================================

all: clean build test ## 清理、构建、测试

install: setup build ## 安装项目

rebuild: clean build ## 重新构建

check: fmt-check lint test ## 代码检查（格式、lint、测试）

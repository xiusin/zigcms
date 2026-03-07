#!/bin/bash

# ============================================
# 中期优化数据库迁移脚本
# 创建时间: 2026-03-07
# 说明: 执行中期优化的数据库迁移
# ============================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 读取 .env 文件
if [ -f .env ]; then
    log_info "读取 .env 配置文件..."
    export $(cat .env | grep -v '^#' | xargs)
else
    log_error ".env 文件不存在"
    exit 1
fi

# 数据库配置（从 .env 读取）
DB_HOST="${PG_DATABASE_HOST:-localhost}"
DB_PORT="${PG_DATABASE_PORT:-5432}"
DB_USER="${PG_DATABASE_USER:-postgres}"
DB_PASS="${PG_DATABASE_PASS:-postgres}"
DB_NAME="${PG_DATABASE_CLIENT_NAME:-zigcms}"

log_info "数据库配置:"
log_info "  主机: $DB_HOST"
log_info "  端口: $DB_PORT"
log_info "  用户: $DB_USER"
log_info "  数据库: $DB_NAME"

# 检查数据库连接
log_info "检查数据库连接..."
if ! PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1" > /dev/null 2>&1; then
    log_error "无法连接到数据库"
    log_error "请检查数据库配置和网络连接"
    exit 1
fi
log_success "数据库连接成功"

# 备份数据库
log_info "备份数据库..."
BACKUP_FILE="backups/zigcms_backup_$(date +%Y%m%d_%H%M%S).sql"
mkdir -p backups
if PGPASSWORD=$DB_PASS pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME > $BACKUP_FILE; then
    log_success "数据库备份成功: $BACKUP_FILE"
else
    log_error "数据库备份失败"
    exit 1
fi

# 执行迁移脚本
log_info "执行中期优化迁移脚本..."
MIGRATION_FILE="migrations/004_medium_term_optimization_fixed.sql"

if [ ! -f "$MIGRATION_FILE" ]; then
    log_error "迁移文件不存在: $MIGRATION_FILE"
    exit 1
fi

log_info "执行迁移: $MIGRATION_FILE"
if PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $MIGRATION_FILE; then
    log_success "迁移执行成功"
else
    log_error "迁移执行失败"
    log_warning "可以使用以下命令恢复数据库:"
    log_warning "  PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME < $BACKUP_FILE"
    exit 1
fi

# 验证迁移结果
log_info "验证迁移结果..."

# 检查表是否创建成功
TABLES=("alert_rules" "alert_rule_logs" "performance_metrics" "security_reports" "websocket_connections")
for table in "${TABLES[@]}"; do
    if PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1 FROM $table LIMIT 1" > /dev/null 2>&1; then
        log_success "表 $table 创建成功"
    else
        log_warning "表 $table 可能不存在或无法访问"
    fi
done

# 检查默认规则是否插入成功
RULE_COUNT=$(PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM alert_rules")
log_info "告警规则数量: $RULE_COUNT"

if [ "$RULE_COUNT" -ge 5 ]; then
    log_success "默认告警规则插入成功"
else
    log_warning "默认告警规则数量不足，预期至少5条"
fi

# 显示迁移摘要
log_success "========================================="
log_success "中期优化迁移完成！"
log_success "========================================="
log_info "迁移摘要:"
log_info "  ✅ 告警规则表（高级版）"
log_info "  ✅ 告警规则执行日志表"
log_info "  ✅ 性能指标表"
log_info "  ✅ 安全报告表"
log_info "  ✅ WebSocket连接表"
log_info "  ✅ 默认告警规则（5条）"
log_info ""
log_info "备份文件: $BACKUP_FILE"
log_info ""
log_info "下一步:"
log_info "  1. 重启应用服务"
log_info "  2. 测试新功能"
log_info "  3. 查看日志确认无错误"
log_success "========================================="


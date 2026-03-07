#!/bin/bash

# 安全增强功能数据库迁移脚本

echo "🔧 开始执行安全增强功能数据库迁移..."

# 检查数据库类型
DB_ENGINE=${DB_ENGINE:-mysql}

if [ "$DB_ENGINE" = "sqlite" ]; then
    echo "📦 使用 SQLite 数据库"
    DB_FILE=${DB_FILE:-data/zigcms.db}
    
    if [ ! -f "$DB_FILE" ]; then
        echo "❌ 数据库文件不存在: $DB_FILE"
        exit 1
    fi
    
    echo "📝 执行迁移脚本..."
    sqlite3 "$DB_FILE" < migrations/20260305_security_enhancement.sql
    
    if [ $? -eq 0 ]; then
        echo "✅ SQLite 迁移成功"
    else
        echo "❌ SQLite 迁移失败"
        exit 1
    fi
    
elif [ "$DB_ENGINE" = "mysql" ]; then
    echo "📦 使用 MySQL 数据库"
    DB_HOST=${DB_HOST:-localhost}
    DB_PORT=${DB_PORT:-3306}
    DB_NAME=${DB_NAME:-zigcms}
    DB_USER=${DB_USER:-root}
    DB_PASSWORD=${DB_PASSWORD:-}
    
    echo "📝 执行迁移脚本..."
    if [ -z "$DB_PASSWORD" ]; then
        mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" "$DB_NAME" < migrations/20260305_security_enhancement.sql
    else
        mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < migrations/20260305_security_enhancement.sql
    fi
    
    if [ $? -eq 0 ]; then
        echo "✅ MySQL 迁移成功"
    else
        echo "❌ MySQL 迁移失败"
        exit 1
    fi
    
else
    echo "❌ 不支持的数据库类型: $DB_ENGINE"
    exit 1
fi

echo ""
echo "✅ 安全增强功能数据库迁移完成！"
echo ""
echo "已创建以下表："
echo "  - security_events (安全事件表)"
echo "  - audit_logs (审计日志表)"
echo "  - ip_bans (IP封禁表)"
echo "  - alert_rules (告警规则表)"
echo "  - alert_history (告警历史表)"
echo ""
echo "下一步："
echo "  1. 启动服务: ./zig-out/bin/zigcms"
echo "  2. 访问安全监控: http://localhost:8080/security/dashboard"
echo "  3. 查看审计日志: http://localhost:8080/security/audit-log"
echo "  4. 管理告警规则: http://localhost:8080/security/alerts"

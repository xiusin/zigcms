# 中期优化数据库迁移指南

## 📋 概述

本指南说明如何执行中期优化的数据库迁移，包括告警规则配置、性能监控、安全报告等功能所需的数据库表。

**创建时间**: 2026-03-07  
**适用版本**: ZigCMS v1.0+  
**数据库**: PostgreSQL 12+

---

## 🎯 迁移内容

### 新增表

1. **alert_rules** - 告警规则表（高级版）
   - 支持 JSON 格式的条件和动作配置
   - 支持优先级和规则类型
   - 包含5条默认规则

2. **alert_rule_logs** - 告警规则执行日志表
   - 记录规则匹配和执行情况
   - 用于规则调试和性能分析

3. **performance_metrics** - 性能指标表
   - 持久化性能监控数据
   - 支持多种指标类型（counter, gauge, histogram, summary）

4. **security_reports** - 安全报告表
   - 保存生成的安全报告
   - 支持多种格式（HTML, PDF, Excel, JSON）

5. **websocket_connections** - WebSocket连接表
   - 管理 WebSocket 连接状态
   - 记录连接和心跳信息

### 表结构变更

- **security_alerts** - 添加 `rule_id` 字段（如果表存在）
  - 关联触发的告警规则

---

## ⚠️ 重要说明

### 1. 告警规则表升级

旧版本的 `alert_rules` 表（来自 `20260305_security_enhancement.sql`）使用简单字段存储规则：
```sql
threshold INT
time_window INT
```

新版本使用 JSON 格式存储复杂规则：
```sql
conditions JSON
actions JSON
```

**迁移脚本会自动处理**：
1. 备份旧表到 `alert_rules_backup_20260307`
2. 删除旧表
3. 创建新表
4. 插入默认规则

### 2. 数据库类型

本项目使用 **PostgreSQL**，不是 MySQL。迁移脚本已针对 PostgreSQL 进行优化。

---

## 🚀 执行迁移

### 方法 1: 使用自动化脚本（推荐）

```bash
# 1. 确保脚本有执行权限
chmod +x migrate-medium-term.sh

# 2. 执行迁移
./migrate-medium-term.sh
```

脚本会自动：
- ✅ 读取 `.env` 配置
- ✅ 检查数据库连接
- ✅ 备份数据库
- ✅ 执行迁移
- ✅ 验证结果

### 方法 2: 手动执行

```bash
# 1. 备份数据库
pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME > backup.sql

# 2. 执行迁移脚本
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f migrations/004_medium_term_optimization_fixed.sql

# 3. 验证结果
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) FROM alert_rules"
```

---

## ✅ 验证迁移

### 1. 检查表是否创建成功

```sql
SELECT 
  tablename,
  schemaname
FROM pg_tables
WHERE tablename IN (
  'alert_rules',
  'alert_rule_logs',
  'performance_metrics',
  'security_reports',
  'websocket_connections'
)
ORDER BY tablename;
```

预期结果：5个表

### 2. 检查默认规则

```sql
SELECT id, name, rule_type, level, enabled 
FROM alert_rules 
ORDER BY priority DESC;
```

预期结果：5条默认规则
- 暴力破解检测
- SQL注入检测
- XSS攻击检测
- 异常访问频率检测
- 敏感数据访问检测

### 3. 检查表结构

```sql
-- 查看 alert_rules 表结构
\d alert_rules

-- 查看 alert_rule_logs 表结构
\d alert_rule_logs

-- 查看 performance_metrics 表结构
\d performance_metrics

-- 查看 security_reports 表结构
\d security_reports

-- 查看 websocket_connections 表结构
\d websocket_connections
```

---

## 🔄 回滚迁移

如果迁移出现问题，可以使用备份恢复：

```bash
# 1. 恢复数据库
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME < backups/zigcms_backup_YYYYMMDD_HHMMSS.sql

# 2. 验证恢复
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) FROM alert_rules"
```

---

## 📊 默认告警规则说明

### 1. 暴力破解检测
- **规则类型**: brute_force
- **级别**: high
- **条件**: 5分钟内登录失败超过5次
- **动作**: 发送告警（WebSocket + Email）+ 封禁IP（1小时）

### 2. SQL注入检测
- **规则类型**: sql_injection
- **级别**: critical
- **条件**: 检测到SQL注入攻击
- **动作**: 发送告警（WebSocket + Email + SMS）+ 封禁IP（2小时）

### 3. XSS攻击检测
- **规则类型**: xss
- **级别**: high
- **条件**: 检测到XSS攻击
- **动作**: 发送告警（WebSocket + Email）+ 记录日志

### 4. 异常访问频率检测
- **规则类型**: rate_limit
- **级别**: medium
- **条件**: 1分钟内请求超过100次
- **动作**: 发送告警（WebSocket）+ 封禁IP（30分钟）

### 5. 敏感数据访问检测
- **规则类型**: sensitive_data
- **级别**: high
- **条件**: 访问敏感数据超过10次
- **动作**: 发送告警（WebSocket + Email）+ 通知管理员

---

## 🔧 配置说明

### 数据库配置（.env）

```env
# PostgreSQL 配置
PG_DATABASE_HOST=124.222.103.232
PG_DATABASE_PORT=5432
PG_DATABASE_USER=postgres
PG_DATABASE_PASS=postgres
PG_DATABASE_CLIENT_NAME=zigcms
PG_DATABASE_POOL_SIZE=10
```

### 告警规则 JSON 格式

#### 条件格式（conditions）

```json
{
  "conditions": [
    {
      "field": "event_type",
      "operator": "eq",
      "value": "login_failed"
    },
    {
      "field": "count",
      "operator": "gt",
      "value": 5,
      "logic": "and"
    }
  ]
}
```

**支持的操作符**:
- `eq` - 等于
- `ne` - 不等于
- `gt` - 大于
- `gte` - 大于等于
- `lt` - 小于
- `lte` - 小于等于
- `in` - 包含
- `not_in` - 不包含
- `contains` - 字符串包含
- `regex` - 正则匹配

#### 动作格式（actions）

```json
{
  "actions": [
    {
      "type": "alert",
      "params": {
        "level": "high",
        "message": "检测到暴力破解尝试",
        "channels": ["websocket", "email"]
      }
    },
    {
      "type": "block",
      "params": {
        "duration": 3600,
        "reason": "暴力破解"
      }
    }
  ]
}
```

**支持的动作类型**:
- `alert` - 发送告警
- `block` - 封禁IP
- `log` - 记录日志
- `notify` - 通知用户
- `webhook` - 调用Webhook

---

## 📝 注意事项

### 1. 数据库备份

**强烈建议在迁移前备份数据库**，迁移脚本会自动备份，但手动备份更安全：

```bash
pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME > manual_backup.sql
```

### 2. 旧规则迁移

如果你在旧版本中自定义了告警规则，需要手动迁移到新格式：

```sql
-- 查看旧规则
SELECT * FROM alert_rules_backup_20260307;

-- 手动转换为新格式并插入
INSERT INTO alert_rules (name, description, rule_type, level, conditions, actions, enabled)
VALUES (...);
```

### 3. 性能影响

新增的表会占用额外的存储空间和内存：
- `alert_rule_logs` - 建议定期清理（保留30天）
- `performance_metrics` - 建议定期清理（保留7天）
- `websocket_connections` - 自动清理断开的连接

### 4. 索引优化

迁移脚本已包含必要的索引，如果查询性能不佳，可以根据实际查询模式添加额外索引。

---

## 🐛 常见问题

### Q1: 迁移失败，提示表已存在

**原因**: 之前已经执行过部分迁移

**解决方案**:
```sql
-- 删除已存在的表（谨慎操作）
DROP TABLE IF EXISTS alert_rules CASCADE;
DROP TABLE IF EXISTS alert_rule_logs CASCADE;
-- ... 其他表

-- 重新执行迁移
```

### Q2: 无法连接到数据库

**原因**: 数据库配置错误或网络问题

**解决方案**:
1. 检查 `.env` 配置
2. 测试数据库连接：
   ```bash
   psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1"
   ```
3. 检查防火墙和网络

### Q3: 默认规则未插入

**原因**: JSON 格式不兼容或权限问题

**解决方案**:
1. 检查 PostgreSQL 版本（需要 9.4+）
2. 检查用户权限
3. 手动执行插入语句

### Q4: security_alerts 表不存在

**原因**: 未执行安全增强迁移

**解决方案**:
```bash
# 先执行安全增强迁移
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f migrations/20260305_security_enhancement.sql

# 再执行中期优化迁移
./migrate-medium-term.sh
```

---

## 📚 相关文档

1. **MEDIUM_TERM_OPTIMIZATION_COMPLETE.md** - 中期优化完成总结
2. **WEBSOCKET_IMPLEMENTATION_COMPLETE.md** - WebSocket 实现文档
3. **ALERT_RULE_COMPLETE.md** - 告警规则配置文档
4. **SECURITY_REPORT_COMPLETE.md** - 安全报告生成文档
5. **PERFORMANCE_MONITORING_COMPLETE.md** - 性能监控文档
6. **VIRTUAL_SCROLL_COMPLETE.md** - 虚拟滚动文档

---

## 🎉 迁移完成后

### 1. 重启应用

```bash
# 重启 ZigCMS 应用
zig build run
```

### 2. 测试新功能

- ✅ 访问告警规则配置页面：`/security/alert-rules`
- ✅ 访问安全报告页面：`/security/reports`
- ✅ 访问性能监控页面：`/monitoring/performance`
- ✅ 测试 WebSocket 实时推送
- ✅ 测试虚拟滚动列表

### 3. 查看日志

```bash
# 查看应用日志
tail -f logs/zigcms.log

# 查看数据库日志
tail -f /var/log/postgresql/postgresql-*.log
```

### 4. 监控性能

- 查看性能指标
- 查看告警规则执行日志
- 查看 WebSocket 连接状态

---

## 📞 技术支持

如果遇到问题，请：
1. 查看日志文件
2. 检查数据库连接
3. 查看相关文档
4. 联系技术支持

---

**迁移脚本版本**: 1.0  
**最后更新**: 2026-03-07  
**维护人员**: Kiro AI Assistant


-- ============================================
-- 中期优化数据库迁移脚本（修正版）
-- 创建时间: 2026-03-07
-- 说明: 升级告警规则表，添加中期优化相关表
-- ============================================

-- 1. 备份旧的告警规则表（如果存在）
CREATE TABLE IF NOT EXISTS `alert_rules_backup_20260307` LIKE `alert_rules`;
INSERT INTO `alert_rules_backup_20260307` SELECT * FROM `alert_rules`;

-- 2. 删除旧的告警规则表
DROP TABLE IF EXISTS `alert_rules`;

-- 3. 创建新的告警规则表（支持高级规则引擎）
CREATE TABLE IF NOT EXISTS `alert_rules` (
  `id` INT AUTO_INCREMENT PRIMARY KEY COMMENT '规则ID',
  `name` VARCHAR(100) NOT NULL COMMENT '规则名称',
  `description` TEXT COMMENT '规则描述',
  `rule_type` VARCHAR(50) NOT NULL COMMENT '规则类型: brute_force, sql_injection, xss, rate_limit, sensitive_data, etc.',
  `level` VARCHAR(20) NOT NULL COMMENT '告警级别: critical, high, medium, low',
  `priority` INT DEFAULT 100 COMMENT '优先级，数值越大优先级越高',
  `conditions` JSON NOT NULL COMMENT '触发条件（JSON格式）',
  `actions` JSON NOT NULL COMMENT '执行动作（JSON格式）',
  `enabled` BOOLEAN DEFAULT TRUE COMMENT '是否启用',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `created_by` INT COMMENT '创建人ID',
  `updated_by` INT COMMENT '更新人ID',
  INDEX `idx_rule_type` (`rule_type`),
  INDEX `idx_enabled` (`enabled`),
  INDEX `idx_priority` (`priority`),
  INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='告警规则表（高级版）';

-- 4. 插入默认告警规则
INSERT INTO `alert_rules` (`name`, `description`, `rule_type`, `level`, `priority`, `conditions`, `actions`, `enabled`) VALUES
-- 暴力破解检测
('暴力破解检测', '检测短时间内多次登录失败', 'brute_force', 'high', 100, 
 JSON_OBJECT(
   'conditions', JSON_ARRAY(
     JSON_OBJECT('field', 'event_type', 'operator', 'eq', 'value', 'login_failed'),
     JSON_OBJECT('field', 'count', 'operator', 'gt', 'value', 5, 'logic', 'and'),
     JSON_OBJECT('field', 'time_window', 'operator', 'lte', 'value', 300, 'logic', 'and')
   )
 ),
 JSON_OBJECT(
   'actions', JSON_ARRAY(
     JSON_OBJECT('type', 'alert', 'params', JSON_OBJECT('level', 'high', 'message', '检测到暴力破解尝试', 'channels', JSON_ARRAY('websocket', 'email'))),
     JSON_OBJECT('type', 'block', 'params', JSON_OBJECT('duration', 3600, 'reason', '暴力破解'))
   )
 ),
 TRUE),

-- SQL注入检测
('SQL注入检测', '检测SQL注入攻击', 'sql_injection', 'critical', 200,
 JSON_OBJECT(
   'conditions', JSON_ARRAY(
     JSON_OBJECT('field', 'event_type', 'operator', 'eq', 'value', 'sql_injection'),
     JSON_OBJECT('field', 'severity', 'operator', 'gte', 'value', 'high', 'logic', 'and')
   )
 ),
 JSON_OBJECT(
   'actions', JSON_ARRAY(
     JSON_OBJECT('type', 'alert', 'params', JSON_OBJECT('level', 'critical', 'message', '检测到SQL注入攻击', 'channels', JSON_ARRAY('websocket', 'email', 'sms'))),
     JSON_OBJECT('type', 'block', 'params', JSON_OBJECT('duration', 7200, 'reason', 'SQL注入攻击'))
   )
 ),
 TRUE),

-- XSS攻击检测
('XSS攻击检测', '检测跨站脚本攻击', 'xss', 'high', 150,
 JSON_OBJECT(
   'conditions', JSON_ARRAY(
     JSON_OBJECT('field', 'event_type', 'operator', 'eq', 'value', 'xss'),
     JSON_OBJECT('field', 'severity', 'operator', 'gte', 'value', 'medium', 'logic', 'and')
   )
 ),
 JSON_OBJECT(
   'actions', JSON_ARRAY(
     JSON_OBJECT('type', 'alert', 'params', JSON_OBJECT('level', 'high', 'message', '检测到XSS攻击', 'channels', JSON_ARRAY('websocket', 'email'))),
     JSON_OBJECT('type', 'log', 'params', JSON_OBJECT('level', 'warning', 'message', 'XSS攻击已记录'))
   )
 ),
 TRUE),

-- 异常访问频率检测
('异常访问频率检测', '检测异常高频访问', 'rate_limit', 'medium', 80,
 JSON_OBJECT(
   'conditions', JSON_ARRAY(
     JSON_OBJECT('field', 'request_count', 'operator', 'gt', 'value', 100),
     JSON_OBJECT('field', 'time_window', 'operator', 'lte', 'value', 60, 'logic', 'and')
   )
 ),
 JSON_OBJECT(
   'actions', JSON_ARRAY(
     JSON_OBJECT('type', 'alert', 'params', JSON_OBJECT('level', 'medium', 'message', '检测到异常高频访问', 'channels', JSON_ARRAY('websocket'))),
     JSON_OBJECT('type', 'block', 'params', JSON_OBJECT('duration', 1800, 'reason', '访问频率过高'))
   )
 ),
 TRUE),

-- 敏感数据访问检测
('敏感数据访问检测', '检测敏感数据的异常访问', 'sensitive_data', 'high', 120,
 JSON_OBJECT(
   'conditions', JSON_ARRAY(
     JSON_OBJECT('field', 'resource_type', 'operator', 'eq', 'value', 'sensitive'),
     JSON_OBJECT('field', 'access_count', 'operator', 'gt', 'value', 10, 'logic', 'and')
   )
 ),
 JSON_OBJECT(
   'actions', JSON_ARRAY(
     JSON_OBJECT('type', 'alert', 'params', JSON_OBJECT('level', 'high', 'message', '检测到敏感数据异常访问', 'channels', JSON_ARRAY('websocket', 'email'))),
     JSON_OBJECT('type', 'notify', 'params', JSON_OBJECT('users', JSON_ARRAY('admin'), 'message', '敏感数据访问告警'))
   )
 ),
 TRUE);

-- 5. 创建告警规则执行日志表
CREATE TABLE IF NOT EXISTS `alert_rule_logs` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '日志ID',
  `rule_id` INT NOT NULL COMMENT '规则ID',
  `rule_name` VARCHAR(100) NOT NULL COMMENT '规则名称',
  `matched` BOOLEAN NOT NULL COMMENT '是否匹配',
  `event_data` JSON COMMENT '事件数据',
  `actions_executed` JSON COMMENT '执行的动作',
  `execution_time` INT COMMENT '执行耗时（毫秒）',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  INDEX `idx_rule_id` (`rule_id`),
  INDEX `idx_matched` (`matched`),
  INDEX `idx_created_at` (`created_at`),
  FOREIGN KEY (`rule_id`) REFERENCES `alert_rules`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='告警规则执行日志表';

-- 6. 检查 security_alerts 表是否存在，如果存在则添加 rule_id 字段
SET @table_exists = (SELECT COUNT(*) FROM information_schema.TABLES 
                     WHERE TABLE_SCHEMA = DATABASE() 
                     AND TABLE_NAME = 'security_alerts');

SET @alter_sql = IF(@table_exists > 0,
  'ALTER TABLE `security_alerts` 
   ADD COLUMN IF NOT EXISTS `rule_id` INT COMMENT ''触发的规则ID'' AFTER `id`,
   ADD INDEX IF NOT EXISTS `idx_rule_id` (`rule_id`)',
  'SELECT ''security_alerts table does not exist, skipping...'' AS message');

PREPARE stmt FROM @alter_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 7. 创建性能指标表（用于持久化性能监控数据）
CREATE TABLE IF NOT EXISTS `performance_metrics` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '指标ID',
  `metric_name` VARCHAR(100) NOT NULL COMMENT '指标名称',
  `metric_type` VARCHAR(20) NOT NULL COMMENT '指标类型: counter, gauge, histogram, summary',
  `metric_value` DOUBLE NOT NULL COMMENT '指标值',
  `labels` JSON COMMENT '标签（JSON格式）',
  `timestamp` BIGINT NOT NULL COMMENT '时间戳（Unix时间戳）',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  INDEX `idx_metric_name` (`metric_name`),
  INDEX `idx_timestamp` (`timestamp`),
  INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='性能指标表';

-- 8. 创建安全报告表（用于保存生成的报告）
CREATE TABLE IF NOT EXISTS `security_reports` (
  `id` INT AUTO_INCREMENT PRIMARY KEY COMMENT '报告ID',
  `title` VARCHAR(200) NOT NULL COMMENT '报告标题',
  `report_type` VARCHAR(20) NOT NULL COMMENT '报告类型: daily, weekly, monthly, custom',
  `period` VARCHAR(100) NOT NULL COMMENT '报告周期',
  `start_date` DATE NOT NULL COMMENT '开始日期',
  `end_date` DATE NOT NULL COMMENT '结束日期',
  `format` VARCHAR(20) NOT NULL COMMENT '报告格式: html, pdf, excel, json',
  `content` LONGTEXT COMMENT '报告内容',
  `file_path` VARCHAR(500) COMMENT '文件路径',
  `file_size` BIGINT COMMENT '文件大小（字节）',
  `generated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '生成时间',
  `generated_by` INT COMMENT '生成人ID',
  INDEX `idx_report_type` (`report_type`),
  INDEX `idx_start_date` (`start_date`),
  INDEX `idx_end_date` (`end_date`),
  INDEX `idx_generated_at` (`generated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='安全报告表';

-- 9. 创建 WebSocket 连接表（用于管理 WebSocket 连接）
CREATE TABLE IF NOT EXISTS `websocket_connections` (
  `id` INT AUTO_INCREMENT PRIMARY KEY COMMENT '连接ID',
  `client_id` VARCHAR(50) NOT NULL UNIQUE COMMENT '客户端ID',
  `user_id` INT COMMENT '用户ID',
  `ip_address` VARCHAR(45) NOT NULL COMMENT 'IP地址',
  `user_agent` VARCHAR(500) COMMENT 'User Agent',
  `connected_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '连接时间',
  `last_heartbeat` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最后心跳时间',
  `disconnected_at` TIMESTAMP NULL COMMENT '断开时间',
  `status` VARCHAR(20) DEFAULT 'connected' COMMENT '状态: connected, disconnected',
  INDEX `idx_user_id` (`user_id`),
  INDEX `idx_status` (`status`),
  INDEX `idx_connected_at` (`connected_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='WebSocket连接表';

-- ============================================
-- 迁移完成
-- ============================================

-- 验证表是否创建成功
SELECT 
  TABLE_NAME,
  TABLE_ROWS,
  CREATE_TIME,
  TABLE_COMMENT
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN (
    'alert_rules',
    'alert_rule_logs',
    'performance_metrics',
    'security_reports',
    'websocket_connections'
  )
ORDER BY TABLE_NAME;

-- 显示告警规则数量
SELECT COUNT(*) AS rule_count FROM alert_rules;

-- 显示默认规则
SELECT id, name, rule_type, level, enabled FROM alert_rules ORDER BY priority DESC;


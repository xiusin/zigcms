-- 安全增强功能数据库迁移
-- 创建时间: 2026-03-05
-- 说明: 创建审计日志表和安全事件表

-- ============================================
-- 1. 审计日志表
-- ============================================
CREATE TABLE IF NOT EXISTS audit_logs (
    id INT PRIMARY KEY AUTO_INCREMENT COMMENT '日志ID',
    user_id INT NOT NULL COMMENT '用户ID',
    username VARCHAR(64) NOT NULL DEFAULT '' COMMENT '用户名',
    action VARCHAR(100) NOT NULL COMMENT '操作类型',
    resource_type VARCHAR(50) NOT NULL COMMENT '资源类型',
    resource_id INT DEFAULT NULL COMMENT '资源ID',
    resource_name VARCHAR(200) NOT NULL DEFAULT '' COMMENT '资源名称',
    description VARCHAR(500) NOT NULL DEFAULT '' COMMENT '操作描述',
    before_data TEXT NOT NULL DEFAULT '{}' COMMENT '操作前数据(JSON)',
    after_data TEXT NOT NULL DEFAULT '{}' COMMENT '操作后数据(JSON)',
    client_ip VARCHAR(45) NOT NULL DEFAULT '' COMMENT '客户端IP',
    user_agent VARCHAR(500) NOT NULL DEFAULT '' COMMENT 'User-Agent',
    result VARCHAR(20) NOT NULL DEFAULT 'success' COMMENT '操作结果(success/failed)',
    error_message VARCHAR(500) NOT NULL DEFAULT '' COMMENT '错误信息',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    
    -- 索引优化
    INDEX idx_user_id (user_id),
    INDEX idx_resource (resource_type, resource_id),
    INDEX idx_action (action),
    INDEX idx_created_at (created_at),
    INDEX idx_result (result),
    INDEX idx_client_ip (client_ip),
    
    -- 复合索引（常用查询组合）
    INDEX idx_user_created (user_id, created_at),
    INDEX idx_resource_created (resource_type, resource_id, created_at),
    INDEX idx_action_created (action, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='审计日志表';

-- ============================================
-- 2. 安全事件表
-- ============================================
CREATE TABLE IF NOT EXISTS security_events (
    id INT PRIMARY KEY AUTO_INCREMENT COMMENT '事件ID',
    event_type VARCHAR(50) NOT NULL COMMENT '事件类型',
    severity VARCHAR(20) NOT NULL COMMENT '严重程度(low/medium/high/critical)',
    user_id INT DEFAULT NULL COMMENT '用户ID',
    username VARCHAR(64) NOT NULL DEFAULT '' COMMENT '用户名',
    client_ip VARCHAR(45) NOT NULL DEFAULT '' COMMENT '客户端IP',
    path VARCHAR(500) NOT NULL DEFAULT '' COMMENT '请求路径',
    method VARCHAR(10) NOT NULL DEFAULT '' COMMENT '请求方法',
    description VARCHAR(500) NOT NULL DEFAULT '' COMMENT '事件描述',
    details TEXT NOT NULL DEFAULT '{}' COMMENT '事件详情(JSON)',
    is_blocked TINYINT NOT NULL DEFAULT 0 COMMENT '是否被阻止',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    
    -- 索引优化
    INDEX idx_event_type (event_type),
    INDEX idx_severity (severity),
    INDEX idx_user_id (user_id),
    INDEX idx_client_ip (client_ip),
    INDEX idx_created_at (created_at),
    INDEX idx_is_blocked (is_blocked),
    
    -- 复合索引（常用查询组合）
    INDEX idx_type_severity (event_type, severity),
    INDEX idx_ip_created (client_ip, created_at),
    INDEX idx_user_created (user_id, created_at),
    INDEX idx_severity_created (severity, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='安全事件表';

-- ============================================
-- 3. IP 封禁表
-- ============================================
CREATE TABLE IF NOT EXISTS ip_bans (
    id INT PRIMARY KEY AUTO_INCREMENT COMMENT '封禁ID',
    ip VARCHAR(45) NOT NULL COMMENT 'IP地址',
    reason VARCHAR(500) NOT NULL DEFAULT '' COMMENT '封禁原因',
    ban_type VARCHAR(20) NOT NULL DEFAULT 'auto' COMMENT '封禁类型(auto/manual)',
    banned_by INT DEFAULT NULL COMMENT '封禁操作人',
    banned_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '封禁时间',
    expires_at DATETIME DEFAULT NULL COMMENT '过期时间',
    is_permanent TINYINT NOT NULL DEFAULT 0 COMMENT '是否永久封禁',
    is_active TINYINT NOT NULL DEFAULT 1 COMMENT '是否生效',
    
    -- 索引优化
    UNIQUE KEY uk_ip (ip),
    INDEX idx_is_active (is_active),
    INDEX idx_expires_at (expires_at),
    INDEX idx_banned_at (banned_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='IP封禁表';

-- ============================================
-- 4. 告警规则表
-- ============================================
CREATE TABLE IF NOT EXISTS alert_rules (
    id INT PRIMARY KEY AUTO_INCREMENT COMMENT '规则ID',
    name VARCHAR(100) NOT NULL COMMENT '规则名称',
    event_type VARCHAR(50) NOT NULL COMMENT '事件类型',
    threshold INT NOT NULL DEFAULT 10 COMMENT '阈值',
    time_window INT NOT NULL DEFAULT 60 COMMENT '时间窗口(秒)',
    severity VARCHAR(20) NOT NULL DEFAULT 'medium' COMMENT '严重程度',
    alert_channels VARCHAR(200) NOT NULL DEFAULT 'email' COMMENT '告警渠道(email,sms,dingtalk)',
    is_enabled TINYINT NOT NULL DEFAULT 1 COMMENT '是否启用',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    
    -- 索引优化
    INDEX idx_event_type (event_type),
    INDEX idx_is_enabled (is_enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='告警规则表';

-- ============================================
-- 5. 告警历史表
-- ============================================
CREATE TABLE IF NOT EXISTS alert_history (
    id INT PRIMARY KEY AUTO_INCREMENT COMMENT '告警ID',
    rule_id INT NOT NULL COMMENT '规则ID',
    event_type VARCHAR(50) NOT NULL COMMENT '事件类型',
    severity VARCHAR(20) NOT NULL COMMENT '严重程度',
    message VARCHAR(500) NOT NULL COMMENT '告警消息',
    details TEXT NOT NULL DEFAULT '{}' COMMENT '告警详情(JSON)',
    alert_channels VARCHAR(200) NOT NULL DEFAULT '' COMMENT '告警渠道',
    is_sent TINYINT NOT NULL DEFAULT 0 COMMENT '是否已发送',
    sent_at DATETIME DEFAULT NULL COMMENT '发送时间',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    
    -- 索引优化
    INDEX idx_rule_id (rule_id),
    INDEX idx_event_type (event_type),
    INDEX idx_severity (severity),
    INDEX idx_created_at (created_at),
    INDEX idx_is_sent (is_sent)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='告警历史表';

-- ============================================
-- 6. 插入默认告警规则
-- ============================================
INSERT INTO alert_rules (name, event_type, threshold, time_window, severity, alert_channels) VALUES
('登录失败告警', 'login_failed', 5, 60, 'medium', 'email,dingtalk'),
('权限拒绝告警', 'permission_denied', 10, 60, 'medium', 'email'),
('SQL注入尝试告警', 'sql_injection_attempt', 1, 60, 'critical', 'email,sms,dingtalk'),
('XSS攻击尝试告警', 'xss_attack_attempt', 1, 60, 'high', 'email,dingtalk'),
('CSRF攻击尝试告警', 'csrf_attack_attempt', 1, 60, 'high', 'email,dingtalk'),
('速率限制触发告警', 'rate_limit_exceeded', 20, 60, 'medium', 'email'),
('异常访问告警', 'abnormal_access', 10, 60, 'high', 'email,dingtalk'),
('数据泄露风险告警', 'data_leak_risk', 1, 60, 'critical', 'email,sms,dingtalk');

-- ============================================
-- 7. 创建视图（便于查询）
-- ============================================

-- 审计日志统计视图
CREATE OR REPLACE VIEW v_audit_log_stats AS
SELECT 
    DATE(created_at) as date,
    user_id,
    username,
    action,
    resource_type,
    COUNT(*) as count,
    SUM(CASE WHEN result = 'success' THEN 1 ELSE 0 END) as success_count,
    SUM(CASE WHEN result = 'failed' THEN 1 ELSE 0 END) as failed_count
FROM audit_logs
GROUP BY DATE(created_at), user_id, username, action, resource_type;

-- 安全事件统计视图
CREATE OR REPLACE VIEW v_security_event_stats AS
SELECT 
    DATE(created_at) as date,
    event_type,
    severity,
    client_ip,
    COUNT(*) as count,
    SUM(CASE WHEN is_blocked = 1 THEN 1 ELSE 0 END) as blocked_count
FROM security_events
GROUP BY DATE(created_at), event_type, severity, client_ip;

-- ============================================
-- 8. 创建存储过程（数据清理）
-- ============================================

-- 清理过期审计日志（保留90天）
DELIMITER //
CREATE PROCEDURE sp_cleanup_audit_logs()
BEGIN
    DELETE FROM audit_logs 
    WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY);
END //
DELIMITER ;

-- 清理过期安全事件（保留30天）
DELIMITER //
CREATE PROCEDURE sp_cleanup_security_events()
BEGIN
    DELETE FROM security_events 
    WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY);
END //
DELIMITER ;

-- 清理过期IP封禁
DELIMITER //
CREATE PROCEDURE sp_cleanup_expired_bans()
BEGIN
    UPDATE ip_bans 
    SET is_active = 0 
    WHERE is_permanent = 0 
    AND expires_at < NOW() 
    AND is_active = 1;
END //
DELIMITER ;

-- ============================================
-- 9. 创建定时任务（需要 MySQL Event Scheduler）
-- ============================================

-- 启用事件调度器
SET GLOBAL event_scheduler = ON;

-- 每天凌晨2点清理过期数据
CREATE EVENT IF NOT EXISTS evt_daily_cleanup
ON SCHEDULE EVERY 1 DAY
STARTS TIMESTAMP(CURRENT_DATE) + INTERVAL 2 HOUR
DO
BEGIN
    CALL sp_cleanup_audit_logs();
    CALL sp_cleanup_security_events();
    CALL sp_cleanup_expired_bans();
END;

-- ============================================
-- 完成
-- ============================================

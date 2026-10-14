-- 审计日志表迁移
-- 创建时间: 2026-03-05
-- 说明: 创建审计日志表（原安全增强迁移精简版，仅保留审计日志相关）

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
-- 2. 审计日志统计视图
-- ============================================
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

-- ============================================
-- 3. 清理过期审计日志存储过程（保留90天）
-- ============================================
DELIMITER //
CREATE PROCEDURE sp_cleanup_audit_logs()
BEGIN
    DELETE FROM audit_logs
    WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY);
END //
DELIMITER ;

-- ============================================
-- 完成
-- ============================================

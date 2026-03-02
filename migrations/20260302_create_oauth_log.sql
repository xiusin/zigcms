-- 创建 OAuth 审计日志表（MySQL）
-- 记录所有 OAuth 登录、绑定、解绑、刷新操作

CREATE TABLE IF NOT EXISTS sys_oauth_log (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id INT DEFAULT NULL COMMENT '用户ID（未登录时为NULL）',
    provider VARCHAR(32) NOT NULL COMMENT 'OAuth提供商（feishu/github/wechat/qq）',
    action VARCHAR(32) NOT NULL COMMENT '操作类型（login/bind/unbind/refresh）',
    provider_user_id VARCHAR(128) DEFAULT '' COMMENT '第三方用户ID',
    ip_address VARCHAR(64) DEFAULT '' COMMENT '客户端IP地址',
    user_agent VARCHAR(500) DEFAULT '' COMMENT '客户端User-Agent',
    status TINYINT DEFAULT 1 COMMENT '操作状态（1成功/0失败）',
    error_msg VARCHAR(500) DEFAULT '' COMMENT '错误信息（失败时记录）',
    extra_data TEXT COMMENT '额外数据（JSON格式）',
    created_at BIGINT DEFAULT NULL COMMENT '操作时间戳'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='OAuth审计日志表';

-- 创建索引
CREATE INDEX idx_oauth_log_user_id ON sys_oauth_log(user_id);
CREATE INDEX idx_oauth_log_provider ON sys_oauth_log(provider);
CREATE INDEX idx_oauth_log_action ON sys_oauth_log(action);
CREATE INDEX idx_oauth_log_created_at ON sys_oauth_log(created_at);
CREATE INDEX idx_oauth_log_status ON sys_oauth_log(status);

-- 插入示例数据（可选）
-- INSERT INTO sys_oauth_log (user_id, provider, action, provider_user_id, ip_address, status, created_at)
-- VALUES (1, 'feishu', 'login', 'ou_xxxxxxxxxxxxx', '127.0.0.1', 1, UNIX_TIMESTAMP() * 1000);

-- 创建 OAuth 绑定表（MySQL）
-- 用于存储用户与第三方 OAuth 账户的绑定关系

CREATE TABLE IF NOT EXISTS sys_oauth_bind (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    provider VARCHAR(32) NOT NULL,
    provider_user_id VARCHAR(128) NOT NULL,
    nickname VARCHAR(128) DEFAULT '',
    avatar_url VARCHAR(500) DEFAULT '',
    email VARCHAR(128) DEFAULT '',
    access_token VARCHAR(500) DEFAULT '',
    refresh_token VARCHAR(500) DEFAULT '',
    token_expires_at BIGINT DEFAULT NULL,
    bind_time BIGINT DEFAULT NULL,
    last_login_time BIGINT DEFAULT NULL,
    status TINYINT DEFAULT 1,
    created_at BIGINT DEFAULT NULL,
    updated_at BIGINT DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 创建索引
CREATE INDEX idx_oauth_bind_user_id ON sys_oauth_bind(user_id);
CREATE INDEX idx_oauth_bind_provider ON sys_oauth_bind(provider);
CREATE UNIQUE INDEX idx_oauth_bind_provider_user ON sys_oauth_bind(provider, provider_user_id);

-- 插入示例数据（可选）
-- INSERT INTO sys_oauth_bind (user_id, provider, provider_user_id, nickname, email, bind_time, status) 
-- VALUES (1, 'feishu', 'ou_xxxxxxxxxxxxx', '张三', 'zhangsan@example.com', UNIX_TIMESTAMP() * 1000, 1);

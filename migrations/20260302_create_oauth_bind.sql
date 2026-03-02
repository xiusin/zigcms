-- 创建 OAuth 绑定表
-- 用于存储用户与第三方 OAuth 账户的绑定关系

CREATE TABLE IF NOT EXISTS sys_oauth_bind (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    provider TEXT NOT NULL,
    provider_user_id TEXT NOT NULL,
    nickname TEXT DEFAULT '',
    avatar_url TEXT DEFAULT '',
    email TEXT DEFAULT '',
    access_token TEXT DEFAULT '',
    refresh_token TEXT DEFAULT '',
    token_expires_at INTEGER,
    bind_time INTEGER,
    last_login_time INTEGER,
    status INTEGER DEFAULT 1,
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER DEFAULT (strftime('%s', 'now'))
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_oauth_bind_user_id ON sys_oauth_bind(user_id);
CREATE INDEX IF NOT EXISTS idx_oauth_bind_provider ON sys_oauth_bind(provider);
CREATE UNIQUE INDEX IF NOT EXISTS idx_oauth_bind_provider_user ON sys_oauth_bind(provider, provider_user_id);

-- 插入示例数据（可选）
-- INSERT INTO sys_oauth_bind (user_id, provider, provider_user_id, nickname, email, bind_time, status) 
-- VALUES (1, 'feishu', 'ou_xxxxxxxxxxxxx', '张三', 'zhangsan@example.com', strftime('%s', 'now'), 1);

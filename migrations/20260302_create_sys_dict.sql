-- 系统字典表
CREATE TABLE IF NOT EXISTS sys_dict (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category_code TEXT NOT NULL DEFAULT '',
    category_name TEXT NOT NULL DEFAULT '',
    dict_name TEXT NOT NULL DEFAULT '',
    dict_code TEXT NOT NULL DEFAULT '',
    remark TEXT NOT NULL DEFAULT '',
    status INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER,
    updated_at INTEGER
);

-- 字典项表
CREATE TABLE IF NOT EXISTS sys_dict_item (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    dict_id INTEGER NOT NULL DEFAULT 0,
    item_name TEXT NOT NULL DEFAULT '',
    item_value TEXT NOT NULL DEFAULT '',
    sort INTEGER NOT NULL DEFAULT 0,
    status INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER,
    updated_at INTEGER
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_sys_dict_category ON sys_dict(category_code);
CREATE INDEX IF NOT EXISTS idx_sys_dict_code ON sys_dict(dict_code);
CREATE INDEX IF NOT EXISTS idx_sys_dict_status ON sys_dict(status);
CREATE INDEX IF NOT EXISTS idx_sys_dict_item_dict_id ON sys_dict_item(dict_id);
CREATE INDEX IF NOT EXISTS idx_sys_dict_item_status ON sys_dict_item(status);

-- 插入示例数据
INSERT INTO sys_dict (category_code, category_name, dict_name, dict_code, remark, status, created_at) VALUES
('system', '系统配置', '用户状态', 'user_status', '用户账号状态', 1, strftime('%s', 'now') * 1000),
('system', '系统配置', '性别', 'gender', '用户性别', 1, strftime('%s', 'now') * 1000),
('business', '业务配置', '订单状态', 'order_status', '订单状态', 1, strftime('%s', 'now') * 1000);

INSERT INTO sys_dict_item (dict_id, item_name, item_value, sort, status, created_at) VALUES
(1, '正常', '1', 1, 1, strftime('%s', 'now') * 1000),
(1, '禁用', '0', 2, 1, strftime('%s', 'now') * 1000),
(2, '男', 'male', 1, 1, strftime('%s', 'now') * 1000),
(2, '女', 'female', 2, 1, strftime('%s', 'now') * 1000),
(2, '未知', 'unknown', 3, 1, strftime('%s', 'now') * 1000),
(3, '待支付', 'pending', 1, 1, strftime('%s', 'now') * 1000),
(3, '已支付', 'paid', 2, 1, strftime('%s', 'now') * 1000),
(3, '已发货', 'shipped', 3, 1, strftime('%s', 'now') * 1000),
(3, '已完成', 'completed', 4, 1, strftime('%s', 'now') * 1000),
(3, '已取消', 'cancelled', 5, 1, strftime('%s', 'now') * 1000);

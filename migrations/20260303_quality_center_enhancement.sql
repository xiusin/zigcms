-- 质量中心完善功能 - 核心表结构（MySQL）

-- 测试用例表
CREATE TABLE IF NOT EXISTS quality_test_cases (
    id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(200) NOT NULL,
    project_id INT NOT NULL,
    module_id INT NOT NULL,
    requirement_id INT DEFAULT NULL,
    priority VARCHAR(16) NOT NULL DEFAULT 'medium',
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    precondition TEXT NOT NULL,
    steps TEXT NOT NULL,
    expected_result TEXT NOT NULL,
    actual_result TEXT NOT NULL,
    assignee VARCHAR(64) DEFAULT NULL,
    tags TEXT NOT NULL,
    created_by VARCHAR(64) NOT NULL DEFAULT '',
    created_at DATETIME DEFAULT NULL,
    updated_at DATETIME DEFAULT NULL,
    INDEX idx_project_id (project_id),
    INDEX idx_module_id (module_id),
    INDEX idx_requirement_id (requirement_id),
    INDEX idx_status (status),
    INDEX idx_assignee (assignee),
    INDEX idx_created_at (created_at),
    INDEX idx_project_module (project_id, module_id),
    INDEX idx_status_assignee (status, assignee)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='测试用例表';

-- 测试执行记录表
CREATE TABLE IF NOT EXISTS quality_test_executions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    test_case_id INT NOT NULL,
    executor VARCHAR(64) NOT NULL,
    status VARCHAR(32) NOT NULL,
    actual_result TEXT NOT NULL,
    remark TEXT NOT NULL,
    duration_ms INT NOT NULL DEFAULT 0,
    executed_at DATETIME NOT NULL,
    INDEX idx_test_case_id (test_case_id),
    INDEX idx_executor (executor),
    INDEX idx_status (status),
    INDEX idx_executed_at (executed_at),
    INDEX idx_case_executor (test_case_id, executor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='测试执行记录表';

-- 项目表
CREATE TABLE IF NOT EXISTS quality_projects (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(200) NOT NULL,
    description VARCHAR(500) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'active',
    owner VARCHAR(64) NOT NULL DEFAULT '',
    members TEXT NOT NULL,
    settings TEXT NOT NULL,
    archived TINYINT NOT NULL DEFAULT 0,
    created_by VARCHAR(64) NOT NULL DEFAULT '',
    created_at DATETIME DEFAULT NULL,
    updated_at DATETIME DEFAULT NULL,
    INDEX idx_status (status),
    INDEX idx_owner (owner),
    INDEX idx_archived (archived),
    INDEX idx_status_archived (status, archived)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='项目表';

-- 模块表
CREATE TABLE IF NOT EXISTS quality_modules (
    id INT PRIMARY KEY AUTO_INCREMENT,
    project_id INT NOT NULL,
    parent_id INT DEFAULT NULL,
    name VARCHAR(200) NOT NULL,
    description VARCHAR(500) NOT NULL DEFAULT '',
    level INT NOT NULL DEFAULT 1,
    sort_order INT NOT NULL DEFAULT 0,
    created_by VARCHAR(64) NOT NULL DEFAULT '',
    created_at DATETIME DEFAULT NULL,
    updated_at DATETIME DEFAULT NULL,
    INDEX idx_project_id (project_id),
    INDEX idx_parent_id (parent_id),
    INDEX idx_level (level),
    INDEX idx_project_parent (project_id, parent_id),
    UNIQUE KEY uk_project_parent_name (project_id, parent_id, name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='模块表';

-- 需求表
CREATE TABLE IF NOT EXISTS quality_requirements (
    id INT PRIMARY KEY AUTO_INCREMENT,
    project_id INT NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    priority VARCHAR(16) NOT NULL DEFAULT 'medium',
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    assignee VARCHAR(64) DEFAULT NULL,
    estimated_cases INT NOT NULL DEFAULT 0,
    actual_cases INT NOT NULL DEFAULT 0,
    coverage_rate DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    created_by VARCHAR(64) NOT NULL DEFAULT '',
    created_at DATETIME DEFAULT NULL,
    updated_at DATETIME DEFAULT NULL,
    INDEX idx_project_id (project_id),
    INDEX idx_status (status),
    INDEX idx_assignee (assignee),
    INDEX idx_priority (priority),
    INDEX idx_project_status (project_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='需求表';

-- 反馈表
CREATE TABLE IF NOT EXISTS quality_feedbacks (
    id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    type VARCHAR(32) NOT NULL DEFAULT 'bug',
    severity VARCHAR(16) NOT NULL DEFAULT 'medium',
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    assignee VARCHAR(64) DEFAULT NULL,
    submitter VARCHAR(64) NOT NULL DEFAULT '',
    follow_ups TEXT NOT NULL,
    follow_count INT NOT NULL DEFAULT 0,
    last_follow_at DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT NULL,
    updated_at DATETIME DEFAULT NULL,
    INDEX idx_type (type),
    INDEX idx_severity (severity),
    INDEX idx_status (status),
    INDEX idx_assignee (assignee),
    INDEX idx_submitter (submitter),
    INDEX idx_status_assignee (status, assignee),
    INDEX idx_type_severity (type, severity)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='反馈表';

-- Bug 表
CREATE TABLE IF NOT EXISTS quality_bugs (
    id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    project_id INT NOT NULL,
    module_id INT DEFAULT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'open',
    severity VARCHAR(16) NOT NULL DEFAULT 'medium',
    assignee VARCHAR(64) DEFAULT NULL,
    reporter VARCHAR(64) NOT NULL DEFAULT '',
    created_at DATETIME DEFAULT NULL,
    updated_at DATETIME DEFAULT NULL,
    INDEX idx_project_id (project_id),
    INDEX idx_module_id (module_id),
    INDEX idx_status (status),
    INDEX idx_severity (severity),
    INDEX idx_assignee (assignee),
    INDEX idx_reporter (reporter)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Bug表';

-- 插入测试数据
INSERT INTO quality_projects (name, description, status, owner, members, settings, created_by, created_at) VALUES
('电商系统', '电商平台核心系统', 'active', 'admin', '[]', '{}', 'admin', NOW()),
('支付系统', '支付网关和结算系统', 'active', 'admin', '[]', '{}', 'admin', NOW()),
('物流系统', '物流跟踪和配送系统', 'active', 'admin', '[]', '{}', 'admin', NOW());

INSERT INTO quality_modules (project_id, parent_id, name, description, level, sort_order, created_by, created_at) VALUES
-- 电商系统模块
(1, NULL, '用户模块', '用户注册、登录、个人中心', 1, 1, 'admin', NOW()),
(1, 1, '用户注册', '用户注册功能', 2, 1, 'admin', NOW()),
(1, 1, '用户登录', '用户登录功能', 2, 2, 'admin', NOW()),
(1, NULL, '商品模块', '商品管理、搜索、详情', 1, 2, 'admin', NOW()),
(1, 4, '商品列表', '商品列表展示', 2, 1, 'admin', NOW()),
(1, 4, '商品详情', '商品详情页', 2, 2, 'admin', NOW()),
(1, NULL, '订单模块', '订单创建、支付、查询', 1, 3, 'admin', NOW()),
-- 支付系统模块
(2, NULL, '支付网关', '支付接口对接', 1, 1, 'admin', NOW()),
(2, NULL, '结算系统', '商户结算', 1, 2, 'admin', NOW()),
-- 物流系统模块
(3, NULL, '物流跟踪', '物流信息查询', 1, 1, 'admin', NOW());

INSERT INTO quality_test_cases (title, project_id, module_id, priority, status, precondition, steps, expected_result, assignee, tags, created_by, created_at) VALUES
-- 用户注册测试用例
('正常注册流程', 1, 2, 'high', 'pending', '用户未注册', '1. 打开注册页面\n2. 输入手机号\n3. 输入验证码\n4. 设置密码\n5. 点击注册', '注册成功，跳转到首页', 'tester1', '["smoke", "regression"]', 'admin', NOW()),
('手机号格式校验', 1, 2, 'medium', 'pending', '用户未注册', '1. 打开注册页面\n2. 输入非法手机号\n3. 点击获取验证码', '提示手机号格式错误', 'tester1', '["validation"]', 'admin', NOW()),
('验证码校验', 1, 2, 'high', 'pending', '用户未注册', '1. 打开注册页面\n2. 输入正确手机号\n3. 输入错误验证码\n4. 点击注册', '提示验证码错误', 'tester1', '["security"]', 'admin', NOW()),
-- 用户登录测试用例
('正常登录流程', 1, 3, 'high', 'passed', '用户已注册', '1. 打开登录页面\n2. 输入手机号\n3. 输入密码\n4. 点击登录', '登录成功，跳转到首页', 'tester1', '["smoke"]', 'admin', NOW()),
('密码错误', 1, 3, 'high', 'passed', '用户已注册', '1. 打开登录页面\n2. 输入正确手机号\n3. 输入错误密码\n4. 点击登录', '提示密码错误', 'tester1', '["security"]', 'admin', NOW()),
-- 商品列表测试用例
('商品列表展示', 1, 5, 'high', 'pending', '系统有商品数据', '1. 打开商品列表页\n2. 查看商品展示', '正确展示商品列表', 'tester2', '["smoke"]', 'admin', NOW()),
('商品搜索', 1, 5, 'medium', 'pending', '系统有商品数据', '1. 打开商品列表页\n2. 输入关键字\n3. 点击搜索', '展示匹配的商品', 'tester2', '["search"]', 'admin', NOW()),
-- 商品详情测试用例
('商品详情展示', 1, 6, 'high', 'pending', '商品存在', '1. 点击商品\n2. 查看详情页', '正确展示商品详情', 'tester2', '["smoke"]', 'admin', NOW()),
('加入购物车', 1, 6, 'high', 'pending', '用户已登录', '1. 打开商品详情\n2. 选择规格\n3. 点击加入购物车', '成功加入购物车', 'tester2', '["cart"]', 'admin', NOW()),
-- 订单模块测试用例
('创建订单', 1, 7, 'high', 'pending', '购物车有商品', '1. 打开购物车\n2. 选择商品\n3. 点击结算\n4. 填写地址\n5. 提交订单', '订单创建成功', 'tester3', '["smoke"]', 'admin', NOW());

-- 继续插入更多测试用例以达到 50 个
INSERT INTO quality_test_cases (title, project_id, module_id, priority, status, precondition, steps, expected_result, assignee, tags, created_by, created_at) VALUES
('订单支付', 1, 7, 'high', 'pending', '订单已创建', '1. 打开订单详情\n2. 选择支付方式\n3. 确认支付', '支付成功', 'tester3', '["payment"]', 'admin', NOW()),
('订单查询', 1, 7, 'medium', 'pending', '用户有订单', '1. 打开订单列表\n2. 查看订单', '正确展示订单列表', 'tester3', '["query"]', 'admin', NOW()),
('订单取消', 1, 7, 'medium', 'pending', '订单未支付', '1. 打开订单详情\n2. 点击取消订单', '订单取消成功', 'tester3', '["cancel"]', 'admin', NOW()),
-- 支付系统测试用例
('支付宝支付', 2, 8, 'high', 'pending', '订单已创建', '1. 选择支付宝\n2. 跳转支付宝\n3. 完成支付', '支付成功', 'tester4', '["alipay"]', 'admin', NOW()),
('微信支付', 2, 8, 'high', 'pending', '订单已创建', '1. 选择微信支付\n2. 扫码支付\n3. 完成支付', '支付成功', 'tester4', '["wechat"]', 'admin', NOW()),
('支付超时', 2, 8, 'medium', 'pending', '订单已创建', '1. 选择支付方式\n2. 等待超时', '订单自动取消', 'tester4', '["timeout"]', 'admin', NOW()),
('支付回调', 2, 8, 'high', 'pending', '支付完成', '1. 支付成功\n2. 接收回调', '订单状态更新', 'tester4', '["callback"]', 'admin', NOW()),
-- 结算系统测试用例
('商户结算', 2, 9, 'high', 'pending', '有待结算订单', '1. 打开结算页面\n2. 选择结算周期\n3. 生成结算单', '结算单生成成功', 'tester5', '["settlement"]', 'admin', NOW()),
('结算审核', 2, 9, 'medium', 'pending', '结算单已生成', '1. 打开结算单\n2. 审核结算单\n3. 确认结算', '结算完成', 'tester5', '["audit"]', 'admin', NOW()),
-- 物流系统测试用例
('物流查询', 3, 10, 'high', 'pending', '订单已发货', '1. 打开订单详情\n2. 点击查看物流\n3. 查看物流信息', '正确展示物流信息', 'tester6', '["logistics"]', 'admin', NOW()),
('物流更新', 3, 10, 'medium', 'pending', '订单已发货', '1. 物流状态变更\n2. 系统接收推送', '物流信息更新', 'tester6', '["update"]', 'admin', NOW());

-- 继续插入更多测试用例
INSERT INTO quality_test_cases (title, project_id, module_id, priority, status, precondition, steps, expected_result, assignee, tags, created_by, created_at) VALUES
('用户信息修改', 1, 1, 'medium', 'pending', '用户已登录', '1. 打开个人中心\n2. 修改昵称\n3. 保存', '修改成功', 'tester1', '["profile"]', 'admin', NOW()),
('密码修改', 1, 1, 'high', 'pending', '用户已登录', '1. 打开密码修改页\n2. 输入旧密码\n3. 输入新密码\n4. 确认', '密码修改成功', 'tester1', '["security"]', 'admin', NOW()),
('头像上传', 1, 1, 'low', 'pending', '用户已登录', '1. 打开个人中心\n2. 点击头像\n3. 选择图片\n4. 上传', '头像上传成功', 'tester1', '["upload"]', 'admin', NOW()),
('商品分类', 1, 4, 'medium', 'pending', '系统有分类数据', '1. 打开商品列表\n2. 选择分类\n3. 查看商品', '展示该分类商品', 'tester2', '["category"]', 'admin', NOW()),
('商品排序', 1, 5, 'low', 'pending', '商品列表有数据', '1. 打开商品列表\n2. 选择排序方式', '商品按选择方式排序', 'tester2', '["sort"]', 'admin', NOW()),
('商品筛选', 1, 5, 'medium', 'pending', '商品列表有数据', '1. 打开商品列表\n2. 选择筛选条件', '展示符合条件的商品', 'tester2', '["filter"]', 'admin', NOW()),
('商品收藏', 1, 6, 'low', 'pending', '用户已登录', '1. 打开商品详情\n2. 点击收藏', '收藏成功', 'tester2', '["favorite"]', 'admin', NOW()),
('商品评价', 1, 6, 'medium', 'pending', '用户已购买', '1. 打开订单详情\n2. 点击评价\n3. 填写评价\n4. 提交', '评价成功', 'tester2', '["review"]', 'admin', NOW()),
('购物车数量修改', 1, 7, 'medium', 'pending', '购物车有商品', '1. 打开购物车\n2. 修改数量', '数量修改成功', 'tester3', '["cart"]', 'admin', NOW()),
('购物车删除', 1, 7, 'low', 'pending', '购物车有商品', '1. 打开购物车\n2. 删除商品', '删除成功', 'tester3', '["cart"]', 'admin', NOW()),
('地址管理', 1, 7, 'medium', 'pending', '用户已登录', '1. 打开地址管理\n2. 添加地址\n3. 保存', '地址添加成功', 'tester3', '["address"]', 'admin', NOW()),
('优惠券使用', 1, 7, 'medium', 'pending', '用户有优惠券', '1. 创建订单\n2. 选择优惠券\n3. 提交订单', '优惠券使用成功', 'tester3', '["coupon"]', 'admin', NOW()),
('订单退款', 1, 7, 'high', 'pending', '订单已支付', '1. 打开订单详情\n2. 申请退款\n3. 填写原因\n4. 提交', '退款申请成功', 'tester3', '["refund"]', 'admin', NOW()),
('退款审核', 1, 7, 'high', 'pending', '退款已申请', '1. 打开退款列表\n2. 审核退款\n3. 确认', '退款审核完成', 'tester3', '["refund"]', 'admin', NOW()),
('银行卡支付', 2, 8, 'medium', 'pending', '订单已创建', '1. 选择银行卡支付\n2. 输入卡号\n3. 完成支付', '支付成功', 'tester4', '["bank"]', 'admin', NOW()),
('支付密码验证', 2, 8, 'high', 'pending', '用户设置支付密码', '1. 选择支付方式\n2. 输入支付密码\n3. 确认', '验证成功', 'tester4', '["security"]', 'admin', NOW()),
('支付限额', 2, 8, 'medium', 'pending', '订单金额超限', '1. 选择支付方式\n2. 确认支付', '提示超过限额', 'tester4', '["limit"]', 'admin', NOW()),
('结算对账', 2, 9, 'high', 'pending', '结算周期结束', '1. 生成对账单\n2. 核对数据', '对账单正确', 'tester5', '["reconciliation"]', 'admin', NOW()),
('结算报表', 2, 9, 'medium', 'pending', '有结算数据', '1. 打开报表页面\n2. 选择时间范围\n3. 生成报表', '报表生成成功', 'tester5', '["report"]', 'admin', NOW()),
('物流签收', 3, 10, 'high', 'pending', '订单已发货', '1. 物流签收\n2. 系统接收通知', '订单状态更新为已签收', 'tester6', '["sign"]', 'admin', NOW()),
('物流异常', 3, 10, 'medium', 'pending', '订单已发货', '1. 物流异常\n2. 系统接收通知', '订单状态更新为异常', 'tester6', '["exception"]', 'admin', NOW()),
('物流退回', 3, 10, 'medium', 'pending', '订单已发货', '1. 物流退回\n2. 系统接收通知', '订单状态更新为退回', 'tester6', '["return"]', 'admin', NOW()),
('批量发货', 3, 10, 'medium', 'pending', '有待发货订单', '1. 选择订单\n2. 批量发货', '发货成功', 'tester6', '["batch"]', 'admin', NOW()),
('物流公司切换', 3, 10, 'low', 'pending', '订单已发货', '1. 打开订单详情\n2. 切换物流公司', '切换成功', 'tester6', '["switch"]', 'admin', NOW()),
('物流费用计算', 3, 10, 'medium', 'pending', '创建订单', '1. 选择收货地址\n2. 查看运费', '运费计算正确', 'tester6', '["fee"]', 'admin', NOW()),
('物流轨迹查询', 3, 10, 'high', 'pending', '订单已发货', '1. 打开订单详情\n2. 查看物流轨迹', '展示完整物流轨迹', 'tester6', '["track"]', 'admin', NOW()),
('物流时效查询', 3, 10, 'low', 'pending', '订单已发货', '1. 查看预计送达时间', '展示预计时间', 'tester6', '["time"]', 'admin', NOW()),
('物流投诉', 3, 10, 'medium', 'pending', '订单已发货', '1. 打开订单详情\n2. 点击投诉\n3. 填写原因\n4. 提交', '投诉提交成功', 'tester6', '["complaint"]', 'admin', NOW()),
('物流评价', 3, 10, 'low', 'pending', '订单已签收', '1. 打开订单详情\n2. 评价物流\n3. 提交', '评价成功', 'tester6', '["review"]', 'admin', NOW());

-- 插入需求数据
INSERT INTO quality_requirements (project_id, title, description, priority, status, assignee, estimated_cases, created_by, created_at) VALUES
(1, '用户注册功能', '实现用户通过手机号注册账号', 'high', 'completed', 'dev1', 5, 'admin', NOW()),
(1, '用户登录功能', '实现用户通过手机号和密码登录', 'high', 'completed', 'dev1', 5, 'admin', NOW()),
(1, '商品列表展示', '实现商品列表页面，支持搜索和筛选', 'high', 'in_test', 'dev2', 10, 'admin', NOW()),
(1, '商品详情页', '实现商品详情页面，支持加入购物车', 'high', 'in_test', 'dev2', 8, 'admin', NOW()),
(1, '订单创建流程', '实现订单创建、支付、查询功能', 'high', 'developing', 'dev3', 15, 'admin', NOW()),
(2, '支付网关对接', '对接支付宝、微信支付', 'high', 'in_test', 'dev4', 12, 'admin', NOW()),
(2, '商户结算系统', '实现商户结算和对账功能', 'medium', 'developing', 'dev5', 10, 'admin', NOW()),
(3, '物流跟踪功能', '实现物流信息查询和推送', 'high', 'in_test', 'dev6', 8, 'admin', NOW());

-- 插入反馈数据
INSERT INTO quality_feedbacks (title, content, type, severity, status, assignee, submitter, follow_ups, created_at) VALUES
('登录页面加载慢', '登录页面首次加载需要 5 秒，体验很差', 'bug', 'high', 'in_progress', 'dev1', 'user1', '[]', NOW()),
('商品图片显示不全', '商品详情页图片只显示一半', 'bug', 'medium', 'pending', NULL, 'user2', '[]', NOW()),
('希望增加商品对比功能', '希望能够对比多个商品的参数', 'feature', 'low', 'pending', NULL, 'user3', '[]', NOW()),
('支付成功后页面卡住', '支付成功后页面一直转圈，无法跳转', 'bug', 'critical', 'resolved', 'dev4', 'user4', '[{"time":"2026-03-01 10:00:00","user":"dev4","content":"已修复，等待测试"}]', NOW()),
('物流信息更新不及时', '物流信息 24 小时才更新一次', 'improvement', 'medium', 'in_progress', 'dev6', 'user5', '[]', NOW());

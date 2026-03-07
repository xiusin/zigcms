-- RBAC 权限控制系统数据库迁移
-- 创建时间: 2026-03-07

-- 1. 角色表
CREATE TABLE IF NOT EXISTS `sys_roles` (
  `id` INT PRIMARY KEY AUTO_INCREMENT COMMENT '角色ID',
  `code` VARCHAR(50) NOT NULL UNIQUE COMMENT '角色代码',
  `name` VARCHAR(100) NOT NULL COMMENT '角色名称',
  `description` TEXT COMMENT '角色描述',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 1-启用, 0-禁用',
  `sort_order` INT NOT NULL DEFAULT 0 COMMENT '排序',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  INDEX `idx_code` (`code`),
  INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='系统角色表';

-- 2. 权限表
CREATE TABLE IF NOT EXISTS `sys_permissions` (
  `id` INT PRIMARY KEY AUTO_INCREMENT COMMENT '权限ID',
  `code` VARCHAR(100) NOT NULL UNIQUE COMMENT '权限代码',
  `name` VARCHAR(100) NOT NULL COMMENT '权限名称',
  `description` TEXT COMMENT '权限描述',
  `resource` VARCHAR(50) NOT NULL COMMENT '资源类型',
  `action` VARCHAR(50) NOT NULL COMMENT '操作类型',
  `category` VARCHAR(50) NOT NULL DEFAULT 'general' COMMENT '权限分类',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 1-启用, 0-禁用',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  INDEX `idx_code` (`code`),
  INDEX `idx_resource` (`resource`),
  INDEX `idx_category` (`category`),
  INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='系统权限表';

-- 3. 角色权限关联表
CREATE TABLE IF NOT EXISTS `sys_role_permissions` (
  `id` INT PRIMARY KEY AUTO_INCREMENT COMMENT 'ID',
  `role_id` INT NOT NULL COMMENT '角色ID',
  `permission_id` INT NOT NULL COMMENT '权限ID',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  UNIQUE KEY `uk_role_permission` (`role_id`, `permission_id`),
  INDEX `idx_role_id` (`role_id`),
  INDEX `idx_permission_id` (`permission_id`),
  CONSTRAINT `fk_role_permission_role` FOREIGN KEY (`role_id`) REFERENCES `sys_roles` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_role_permission_permission` FOREIGN KEY (`permission_id`) REFERENCES `sys_permissions` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='角色权限关联表';

-- 4. 用户角色关联表
CREATE TABLE IF NOT EXISTS `sys_user_roles` (
  `id` INT PRIMARY KEY AUTO_INCREMENT COMMENT 'ID',
  `user_id` INT NOT NULL COMMENT '用户ID',
  `role_id` INT NOT NULL COMMENT '角色ID',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  UNIQUE KEY `uk_user_role` (`user_id`, `role_id`),
  INDEX `idx_user_id` (`user_id`),
  INDEX `idx_role_id` (`role_id`),
  CONSTRAINT `fk_user_role_role` FOREIGN KEY (`role_id`) REFERENCES `sys_roles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户角色关联表';

-- 5. 插入默认角色
INSERT INTO `sys_roles` (`code`, `name`, `description`, `status`, `sort_order`) VALUES
('super_admin', '超级管理员', '拥有所有权限', 1, 1),
('admin', '管理员', '拥有大部分管理权限', 1, 2),
('quality_manager', '质量经理', '质量中心管理权限', 1, 3),
('tester', '测试人员', '测试用例执行权限', 1, 4),
('developer', '开发人员', '基础查看和反馈权限', 1, 5),
('viewer', '访客', '只读权限', 1, 6);

-- 6. 插入质量中心权限
INSERT INTO `sys_permissions` (`code`, `name`, `description`, `resource`, `action`, `category`) VALUES
-- 测试用例权限
('quality:test_case:view', '查看测试用例', '查看测试用例列表和详情', 'test_case', 'view', 'quality'),
('quality:test_case:create', '创建测试用例', '创建新的测试用例', 'test_case', 'create', 'quality'),
('quality:test_case:update', '更新测试用例', '编辑测试用例信息', 'test_case', 'update', 'quality'),
('quality:test_case:delete', '删除测试用例', '删除测试用例', 'test_case', 'delete', 'quality'),
('quality:test_case:execute', '执行测试用例', '执行测试用例并记录结果', 'test_case', 'execute', 'quality'),
('quality:test_case:batch_delete', '批量删除测试用例', '批量删除多个测试用例', 'test_case', 'batch_delete', 'quality'),
('quality:test_case:batch_update', '批量更新测试用例', '批量更新多个测试用例', 'test_case', 'batch_update', 'quality'),

-- 项目权限
('quality:project:view', '查看项目', '查看项目列表和详情', 'project', 'view', 'quality'),
('quality:project:create', '创建项目', '创建新项目', 'project', 'create', 'quality'),
('quality:project:update', '更新项目', '编辑项目信息', 'project', 'update', 'quality'),
('quality:project:delete', '删除项目', '删除项目', 'project', 'delete', 'quality'),
('quality:project:archive', '归档项目', '归档项目', 'project', 'archive', 'quality'),

-- 模块权限
('quality:module:view', '查看模块', '查看模块列表和详情', 'module', 'view', 'quality'),
('quality:module:create', '创建模块', '创建新模块', 'module', 'create', 'quality'),
('quality:module:update', '更新模块', '编辑模块信息', 'module', 'update', 'quality'),
('quality:module:delete', '删除模块', '删除模块', 'module', 'delete', 'quality'),
('quality:module:move', '移动模块', '移动模块位置', 'module', 'move', 'quality'),

-- 需求权限
('quality:requirement:view', '查看需求', '查看需求列表和详情', 'requirement', 'view', 'quality'),
('quality:requirement:create', '创建需求', '创建新需求', 'requirement', 'create', 'quality'),
('quality:requirement:update', '更新需求', '编辑需求信息', 'requirement', 'update', 'quality'),
('quality:requirement:delete', '删除需求', '删除需求', 'requirement', 'delete', 'quality'),
('quality:requirement:link', '关联需求', '关联需求到测试用例', 'requirement', 'link', 'quality'),

-- 反馈权限
('quality:feedback:view', '查看反馈', '查看反馈列表和详情', 'feedback', 'view', 'quality'),
('quality:feedback:create', '创建反馈', '创建新反馈', 'feedback', 'create', 'quality'),
('quality:feedback:update', '更新反馈', '编辑反馈信息', 'feedback', 'update', 'quality'),
('quality:feedback:delete', '删除反馈', '删除反馈', 'feedback', 'delete', 'quality'),
('quality:feedback:assign', '分配反馈', '分配反馈给处理人', 'feedback', 'assign', 'quality'),
('quality:feedback:follow_up', '跟进反馈', '添加反馈跟进记录', 'feedback', 'follow_up', 'quality'),
('quality:feedback:comment', '评论反馈', '添加反馈评论', 'feedback', 'comment', 'quality'),

-- 统计权限
('quality:statistics:view', '查看统计', '查看质量统计数据', 'statistics', 'view', 'quality'),
('quality:statistics:export', '导出统计', '导出统计报表', 'statistics', 'export', 'quality'),

-- AI 生成权限
('quality:ai:generate', 'AI生成', '使用AI生成测试用例', 'ai', 'generate', 'quality');

-- 7. 为超级管理员分配所有权限
INSERT INTO `sys_role_permissions` (`role_id`, `permission_id`)
SELECT 
  (SELECT id FROM sys_roles WHERE code = 'super_admin'),
  id
FROM sys_permissions;

-- 8. 为管理员分配大部分权限（除了删除和批量操作）
INSERT INTO `sys_role_permissions` (`role_id`, `permission_id`)
SELECT 
  (SELECT id FROM sys_roles WHERE code = 'admin'),
  id
FROM sys_permissions
WHERE code NOT LIKE '%:delete' 
  AND code NOT LIKE '%:batch_delete';

-- 9. 为质量经理分配质量中心管理权限
INSERT INTO `sys_role_permissions` (`role_id`, `permission_id`)
SELECT 
  (SELECT id FROM sys_roles WHERE code = 'quality_manager'),
  id
FROM sys_permissions
WHERE category = 'quality'
  AND code NOT LIKE '%:batch_delete';

-- 10. 为测试人员分配测试相关权限
INSERT INTO `sys_role_permissions` (`role_id`, `permission_id`)
SELECT 
  (SELECT id FROM sys_roles WHERE code = 'tester'),
  id
FROM sys_permissions
WHERE code IN (
  'quality:test_case:view',
  'quality:test_case:create',
  'quality:test_case:update',
  'quality:test_case:execute',
  'quality:project:view',
  'quality:module:view',
  'quality:requirement:view',
  'quality:feedback:view',
  'quality:feedback:create',
  'quality:feedback:comment',
  'quality:statistics:view'
);

-- 11. 为开发人员分配基础权限
INSERT INTO `sys_role_permissions` (`role_id`, `permission_id`)
SELECT 
  (SELECT id FROM sys_roles WHERE code = 'developer'),
  id
FROM sys_permissions
WHERE code IN (
  'quality:test_case:view',
  'quality:project:view',
  'quality:module:view',
  'quality:requirement:view',
  'quality:feedback:view',
  'quality:feedback:create',
  'quality:feedback:comment',
  'quality:statistics:view'
);

-- 12. 为访客分配只读权限
INSERT INTO `sys_role_permissions` (`role_id`, `permission_id`)
SELECT 
  (SELECT id FROM sys_roles WHERE code = 'viewer'),
  id
FROM sys_permissions
WHERE code LIKE '%:view';

-- 13. 创建权限缓存表（可选，用于性能优化）
CREATE TABLE IF NOT EXISTS `sys_user_permission_cache` (
  `user_id` INT PRIMARY KEY COMMENT '用户ID',
  `permissions` TEXT NOT NULL COMMENT '权限列表（JSON）',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  INDEX `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户权限缓存表';

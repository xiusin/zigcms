-- 质量中心菜单配置
-- 创建时间: 2026-03-06
-- 说明: 为质量中心模块添加菜单项

-- 1. 添加质量中心一级菜单（目录）
INSERT INTO sys_menu (menu_name, pid, menu_type, path, component, icon, sort, is_hide, status, created_at, updated_at)
VALUES ('质量中心', 0, 1, '/quality-center', NULL, 'icon-check-circle', 50, 0, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());

-- 获取刚插入的质量中心菜单ID（假设为 @quality_center_id）
SET @quality_center_id = LAST_INSERT_ID();

-- 2. 添加质量中心子菜单

-- 2.1 Dashboard（仪表盘）
INSERT INTO sys_menu (menu_name, pid, menu_type, path, component, icon, sort, is_hide, status, created_at, updated_at)
VALUES ('质量概览', @quality_center_id, 2, '/quality-center/dashboard', '@/views/quality-center/dashboard/index.vue', 'icon-dashboard', 1, 0, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());

-- 2.2 项目管理
INSERT INTO sys_menu (menu_name, pid, menu_type, path, component, icon, sort, is_hide, status, created_at, updated_at)
VALUES ('项目管理', @quality_center_id, 2, '/quality-center/project', '@/views/quality-center/project/index.vue', 'icon-folder', 2, 0, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());

-- 2.3 模块管理
INSERT INTO sys_menu (menu_name, pid, menu_type, path, component, icon, sort, is_hide, status, created_at, updated_at)
VALUES ('模块管理', @quality_center_id, 2, '/quality-center/module', '@/views/quality-center/module/index.vue', 'icon-apps', 3, 0, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());

-- 2.4 需求管理
INSERT INTO sys_menu (menu_name, pid, menu_type, path, component, icon, sort, is_hide, status, created_at, updated_at)
VALUES ('需求管理', @quality_center_id, 2, '/quality-center/requirement', '@/views/quality-center/requirement/index.vue', 'icon-file-text', 4, 0, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());

-- 2.5 测试用例
INSERT INTO sys_menu (menu_name, pid, menu_type, path, component, icon, sort, is_hide, status, created_at, updated_at)
VALUES ('测试用例', @quality_center_id, 2, '/quality-center/test-case', '@/views/quality-center/test-case/index.vue', 'icon-list', 5, 0, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());

-- 2.6 反馈管理
INSERT INTO sys_menu (menu_name, pid, menu_type, path, component, icon, sort, is_hide, status, created_at, updated_at)
VALUES ('反馈管理', @quality_center_id, 2, '/quality-center/feedback', '@/views/quality-center/feedback/index.vue', 'icon-message', 6, 0, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());

-- 2.7 思维导图
INSERT INTO sys_menu (menu_name, pid, menu_type, path, component, icon, sort, is_hide, status, created_at, updated_at)
VALUES ('思维导图', @quality_center_id, 2, '/quality-center/mindmap', '@/views/quality-center/mindmap/index.vue', 'icon-mind-mapping', 7, 0, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());

-- 3. 为超级管理员角色分配质量中心菜单权限
-- 假设超级管理员角色ID为1
INSERT INTO sys_role_menu (role_id, menu_id)
SELECT 1, id FROM sys_menu WHERE pid = @quality_center_id OR id = @quality_center_id;

-- 4. 验证插入结果
SELECT 
    m1.id AS menu_id,
    m1.menu_name,
    m1.pid,
    m1.menu_type,
    m1.path,
    m1.component,
    m1.icon,
    m1.sort,
    m2.menu_name AS parent_name
FROM sys_menu m1
LEFT JOIN sys_menu m2 ON m1.pid = m2.id
WHERE m1.id = @quality_center_id OR m1.pid = @quality_center_id
ORDER BY m1.pid, m1.sort;

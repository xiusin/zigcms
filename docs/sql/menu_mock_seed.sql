-- ===========================================
-- ZigCMS 菜单与权限初始数据脚本
-- 涵盖：业务管理、系统管理、运营管理、报表统计、安全运维
-- ===========================================

START TRANSACTION;

-- 清理旧数据（可选，根据需求决定是否保留）
-- DELETE FROM sys_menu;

-- 1) 一级目录 (pid = 0, menu_type = 1)
INSERT INTO sys_menu (id, pid, menu_name, menu_type, icon, path, component, sort, status) VALUES
(1, 0, '业务管理', 1, 'icon-apps', '/business', '', 10, 1),
(2, 0, '系统管理', 1, 'icon-settings', '/system', '', 100, 1),
(3, 0, '运营管理', 1, 'icon-operation', '/operation', '', 20, 1),
(4, 0, '报表统计', 1, 'icon-chart', '/report', '', 30, 1),
(5, 0, '安全运维', 1, 'icon-safe', '/security', '', 90, 1);

-- 2) 业务管理子菜单 (pid = 1, menu_type = 2)
INSERT INTO sys_menu (id, pid, menu_name, menu_type, icon, path, component, sort, status) VALUES
(11, 1, '数据概览', 2, 'icon-dashboard', '/business/overview', '@/views/business/overview/overview.vue', 1, 1),
(12, 1, '会员管理', 2, 'icon-user', '/business/member', '@/views/business/member/member.vue', 2, 1),
(13, 1, '订单管理', 2, 'icon-shopping-cart', '/business/order', '@/views/business/order/order.vue', 3, 1),
(14, 1, '工具箱', 2, 'icon-tool', '/business/toolbox', '@/views/business/toolbox/toolbox.vue', 4, 1),
(15, 1, '优惠活动', 2, 'icon-star', '/business/promotion', '@/views/business/promotion/promotion.vue', 5, 1),
(16, 1, '机器管理', 2, 'icon-mobile', '/business/machine', '@/views/business/machine/machine.vue', 6, 1),
(17, 1, '收入管理', 2, 'icon-money', '/business/income', '@/views/business/income/income.vue', 7, 1);

-- 3) 系统管理子菜单 (pid = 2, menu_type = 2)
INSERT INTO sys_menu (id, pid, menu_name, menu_type, icon, path, component, sort, status) VALUES
(21, 2, '菜单管理', 2, 'icon-menu', '/system/menu', '@/views/system-manage/menu/menu.vue', 1, 1),
(22, 2, '配置管理', 2, 'icon-settings', '/system/config', '@/views/system-manage/config/config.vue', 2, 1),
(23, 2, '支付配置', 2, 'icon-pay', '/system/payment', '@/views/system-manage/payment/payment.vue', 3, 1),
(24, 2, '版本管理', 2, 'icon-history', '/system/version', '@/views/system-manage/version/version.vue', 4, 1),
(25, 2, '管理员', 2, 'icon-user', '/system/admin', '@/views/system-manage/admin/admin.vue', 5, 1),
(26, 2, '组织架构', 2, 'icon-user-group', '/system/organization', '@/views/system/organization/index.vue', 6, 1),
(27, 2, '角色管理', 2, 'icon-skin', '/system/role', '@/views/system/role-manage/table-manage.vue', 7, 1);

-- 4) 运营管理子菜单 (pid = 3, menu_type = 2)
INSERT INTO sys_menu (id, pid, menu_name, menu_type, icon, path, component, sort, status) VALUES
(31, 3, '任务管理', 2, 'icon-clock', '/operation/task', '@/views/operation/task/task.vue', 1, 1),
(32, 3, '插件管理', 2, 'icon-apps', '/operation/plugin', '@/views/operation/plugin/plugin.vue', 2, 1);

-- 5) 报表统计子菜单 (pid = 4, menu_type = 2)
INSERT INTO sys_menu (id, pid, menu_name, menu_type, icon, path, component, sort, status) VALUES
(41, 4, '报表统计', 2, 'icon-bar-chart', '/report/statistics', '@/views/report/statistics/statistics.vue', 1, 1);

-- 6) 安全运维子菜单 (pid = 5, menu_type = 2)
INSERT INTO sys_menu (id, pid, menu_name, menu_type, icon, path, component, sort, status) VALUES
(51, 5, '日志管理', 2, 'icon-file', '/security/log', '@/views/security/log/log.vue', 1, 1),
(52, 5, '黑名单', 2, 'icon-close-circle', '/security/blacklist', '@/views/security/blacklist/blacklist.vue', 2, 1);

-- 7) 为重点菜单生成按钮权限 (menu_type = 3)
INSERT INTO sys_menu (pid, menu_name, menu_type, perms, sort, status) VALUES
(12, '会员查询', 3, 'btn:query', 1, 1),
(12, '会员编辑', 3, 'btn:edit', 2, 1),
(12, '会员导出', 3, 'btn:export', 3, 1),
(13, '订单查询', 3, 'btn:query', 1, 1),
(13, '订单发货', 3, 'btn:edit', 2, 1),
(13, '订单导出', 3, 'btn:export', 3, 1);

COMMIT;

-- ecom-admin 组织架构联调 mock 数据（MySQL）
-- 用途：快速初始化 角色 / 部门 / 管理员 / 管理员角色关系

START TRANSACTION;

-- 1) 角色数据
INSERT INTO sys_role (id, role_name, role_key, sort, status, remark, data_scope)
VALUES
  (1, '超级管理员', 'super_admin', 1, 1, '系统内置角色', 1),
  (2, '运营主管', 'ops_manager', 2, 1, '组织架构联调用角色', 1),
  (3, '客服专员', 'customer_service', 3, 1, '组织架构联调用角色', 1)
ON DUPLICATE KEY UPDATE
  role_name = VALUES(role_name),
  role_key = VALUES(role_key),
  sort = VALUES(sort),
  status = VALUES(status),
  remark = VALUES(remark),
  data_scope = VALUES(data_scope);

-- 2) 部门数据
INSERT INTO sys_dept (id, parent_id, dept_name, dept_code, leader, phone, email, sort, status, remark)
VALUES
  (1, 0, '总部', 'HQ', '系统管理员', '13800000001', 'hq@zigcms.local', 1, 1, '根部门'),
  (2, 1, '运营中心', 'OPS', '运营负责人', '13800000002', 'ops@zigcms.local', 2, 1, '组织架构联调部门'),
  (3, 1, '客服中心', 'CS', '客服负责人', '13800000003', 'cs@zigcms.local', 3, 1, '组织架构联调部门')
ON DUPLICATE KEY UPDATE
  parent_id = VALUES(parent_id),
  dept_name = VALUES(dept_name),
  dept_code = VALUES(dept_code),
  leader = VALUES(leader),
  phone = VALUES(phone),
  email = VALUES(email),
  sort = VALUES(sort),
  status = VALUES(status),
  remark = VALUES(remark);

-- 3) 管理员数据（默认密码：123456，MD5: e10adc3949ba59abbe56e057f20f883e）
INSERT INTO sys_admin (
  id,
  username,
  nickname,
  password_hash,
  mobile,
  email,
  avatar,
  gender,
  dept_id,
  position_id,
  status,
  remark
)
VALUES
  (1, 'admin', '系统管理员', 'e10adc3949ba59abbe56e057f20f883e', '13800001001', 'admin@zigcms.local', '', 1, 1, NULL, 1, '系统内置账号'),
  (2, 'ops_admin', '运营管理员', 'e10adc3949ba59abbe56e057f20f883e', '13800001002', 'ops_admin@zigcms.local', '', 1, 2, NULL, 1, '组织架构联调账号'),
  (3, 'cs_admin', '客服管理员', 'e10adc3949ba59abbe56e057f20f883e', '13800001003', 'cs_admin@zigcms.local', '', 2, 3, NULL, 1, '组织架构联调账号')
ON DUPLICATE KEY UPDATE
  nickname = VALUES(nickname),
  password_hash = VALUES(password_hash),
  mobile = VALUES(mobile),
  email = VALUES(email),
  gender = VALUES(gender),
  dept_id = VALUES(dept_id),
  status = VALUES(status),
  remark = VALUES(remark);

-- 4) 管理员角色关系
INSERT INTO sys_admin_role (admin_id, role_id)
SELECT 1, 1
WHERE NOT EXISTS (
  SELECT 1 FROM sys_admin_role WHERE admin_id = 1 AND role_id = 1
);

INSERT INTO sys_admin_role (admin_id, role_id)
SELECT 2, 2
WHERE NOT EXISTS (
  SELECT 1 FROM sys_admin_role WHERE admin_id = 2 AND role_id = 2
);

INSERT INTO sys_admin_role (admin_id, role_id)
SELECT 3, 3
WHERE NOT EXISTS (
  SELECT 1 FROM sys_admin_role WHERE admin_id = 3 AND role_id = 3
);

COMMIT;

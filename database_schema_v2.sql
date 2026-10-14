-- ===========================================
-- ZigCMS 新业务表结构（sys/biz/op）
-- 生成时间: 2026-02-27
-- ===========================================

CREATE DATABASE IF NOT EXISTS zigcms
CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE zigcms;

-- =========================
-- 组织 / 权限基础
-- =========================
CREATE TABLE IF NOT EXISTS sys_dept (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  parent_id BIGINT NOT NULL DEFAULT 0,
  dept_name VARCHAR(128) NOT NULL,
  dept_code VARCHAR(64) NOT NULL,
  leader VARCHAR(64) NOT NULL DEFAULT '',
  phone VARCHAR(32) NOT NULL DEFAULT '',
  email VARCHAR(128) NOT NULL DEFAULT '',
  sort INT NOT NULL DEFAULT 0,
  status TINYINT NOT NULL DEFAULT 1,
  remark VARCHAR(500) NOT NULL DEFAULT '',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  UNIQUE KEY uk_sys_dept_code (dept_code),
  KEY idx_sys_dept_parent (parent_id),
  KEY idx_sys_dept_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sys_position (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  dept_id BIGINT NOT NULL,
  position_name VARCHAR(128) NOT NULL,
  position_code VARCHAR(64) NOT NULL,
  description VARCHAR(500) NOT NULL DEFAULT '',
  sort INT NOT NULL DEFAULT 0,
  status TINYINT NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  UNIQUE KEY uk_sys_position_code (position_code),
  KEY idx_sys_position_dept (dept_id),
  KEY idx_sys_position_status (status),
  CONSTRAINT fk_sys_position_dept FOREIGN KEY (dept_id) REFERENCES sys_dept(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sys_role (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  role_name VARCHAR(128) NOT NULL,
  role_key VARCHAR(64) NOT NULL,
  sort INT NOT NULL DEFAULT 0,
  status TINYINT NOT NULL DEFAULT 1,
  remark VARCHAR(500) NOT NULL DEFAULT '',
  data_scope TINYINT NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  UNIQUE KEY uk_sys_role_key (role_key),
  KEY idx_sys_role_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sys_menu (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  pid BIGINT NOT NULL DEFAULT 0,
  menu_name VARCHAR(128) NOT NULL,
  menu_type TINYINT NOT NULL COMMENT '1目录 2菜单 3按钮',
  icon VARCHAR(128) NOT NULL DEFAULT '',
  path VARCHAR(255) NOT NULL DEFAULT '',
  component VARCHAR(255) NOT NULL DEFAULT '',
  perms VARCHAR(128) NOT NULL DEFAULT '',
  sort INT NOT NULL DEFAULT 0,
  is_hide TINYINT NOT NULL DEFAULT 0,
  is_cache TINYINT NOT NULL DEFAULT 0,
  status TINYINT NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  KEY idx_sys_menu_pid (pid),
  KEY idx_sys_menu_type (menu_type),
  KEY idx_sys_menu_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sys_permission (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  perm_name VARCHAR(128) NOT NULL,
  perm_code VARCHAR(128) NOT NULL,
  menu_id BIGINT NULL,
  perm_type TINYINT NOT NULL DEFAULT 2 COMMENT '1菜单 2按钮 3数据',
  sort INT NOT NULL DEFAULT 0,
  status TINYINT NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_sys_perm_code (perm_code),
  KEY idx_sys_perm_menu (menu_id),
  CONSTRAINT fk_sys_perm_menu FOREIGN KEY (menu_id) REFERENCES sys_menu(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sys_role_menu (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  role_id BIGINT NOT NULL,
  menu_id BIGINT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_sys_role_menu (role_id, menu_id),
  KEY idx_sys_role_menu_role (role_id),
  KEY idx_sys_role_menu_menu (menu_id),
  CONSTRAINT fk_sys_role_menu_role FOREIGN KEY (role_id) REFERENCES sys_role(id),
  CONSTRAINT fk_sys_role_menu_menu FOREIGN KEY (menu_id) REFERENCES sys_menu(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sys_role_permission (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  role_id BIGINT NOT NULL,
  permission_id BIGINT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_sys_role_perm (role_id, permission_id),
  KEY idx_sys_role_perm_role (role_id),
  KEY idx_sys_role_perm_perm (permission_id),
  CONSTRAINT fk_sys_role_perm_role FOREIGN KEY (role_id) REFERENCES sys_role(id),
  CONSTRAINT fk_sys_role_perm_perm FOREIGN KEY (permission_id) REFERENCES sys_permission(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sys_admin (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(64) NOT NULL,
  nickname VARCHAR(64) NOT NULL DEFAULT '',
  password_hash VARCHAR(255) NOT NULL,
  mobile VARCHAR(32) NOT NULL DEFAULT '',
  email VARCHAR(128) NOT NULL DEFAULT '',
  avatar VARCHAR(255) NOT NULL DEFAULT '',
  gender TINYINT NOT NULL DEFAULT 0,
  dept_id BIGINT NULL,
  position_id BIGINT NULL,
  status TINYINT NOT NULL DEFAULT 1,
  remark VARCHAR(500) NOT NULL DEFAULT '',
  last_login DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  UNIQUE KEY uk_sys_admin_username (username),
  KEY idx_sys_admin_dept (dept_id),
  KEY idx_sys_admin_status (status),
  CONSTRAINT fk_sys_admin_dept FOREIGN KEY (dept_id) REFERENCES sys_dept(id),
  CONSTRAINT fk_sys_admin_position FOREIGN KEY (position_id) REFERENCES sys_position(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sys_admin_role (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  admin_id BIGINT NOT NULL,
  role_id BIGINT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_sys_admin_role (admin_id, role_id),
  CONSTRAINT fk_sys_admin_role_admin FOREIGN KEY (admin_id) REFERENCES sys_admin(id),
  CONSTRAINT fk_sys_admin_role_role FOREIGN KEY (role_id) REFERENCES sys_role(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================
-- 会员管理（业务）
-- =========================
CREATE TABLE IF NOT EXISTS biz_member (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NULL,
  username VARCHAR(64) NOT NULL DEFAULT '',
  nickname VARCHAR(64) NOT NULL,
  mobile VARCHAR(32) NOT NULL,
  email VARCHAR(128) NOT NULL DEFAULT '',
  avatar VARCHAR(255) NOT NULL DEFAULT '',
  gender TINYINT NOT NULL DEFAULT 0,
  level TINYINT NOT NULL DEFAULT 1,
  balance DECIMAL(14,2) NOT NULL DEFAULT 0,
  total_consume DECIMAL(14,2) NOT NULL DEFAULT 0,
  total_order INT NOT NULL DEFAULT 0,
  points INT NOT NULL DEFAULT 0,
  status TINYINT NOT NULL DEFAULT 1,
  source VARCHAR(32) NOT NULL DEFAULT 'PC',
  last_login DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  KEY idx_biz_member_mobile (mobile),
  KEY idx_biz_member_level (level),
  KEY idx_biz_member_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS biz_member_tag (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  tag_name VARCHAR(64) NOT NULL,
  color VARCHAR(32) NOT NULL DEFAULT 'blue',
  sort INT NOT NULL DEFAULT 0,
  status TINYINT NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_biz_member_tag_name (tag_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS biz_member_tag_rel (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  member_id BIGINT NOT NULL,
  tag_id BIGINT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_biz_member_tag_rel (member_id, tag_id),
  CONSTRAINT fk_biz_member_tag_rel_member FOREIGN KEY (member_id) REFERENCES biz_member(id),
  CONSTRAINT fk_biz_member_tag_rel_tag FOREIGN KEY (tag_id) REFERENCES biz_member_tag(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS biz_member_balance_log (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  member_id BIGINT NOT NULL,
  change_type VARCHAR(16) NOT NULL COMMENT 'add/reduce',
  amount DECIMAL(14,2) NOT NULL,
  payment_method VARCHAR(32) NOT NULL DEFAULT '',
  remark VARCHAR(500) NOT NULL DEFAULT '',
  operator_id BIGINT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_biz_member_balance_log_member (member_id),
  CONSTRAINT fk_biz_member_balance_member FOREIGN KEY (member_id) REFERENCES biz_member(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS biz_member_point_log (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  member_id BIGINT NOT NULL,
  change_type VARCHAR(16) NOT NULL COMMENT 'add/reduce',
  points INT NOT NULL,
  remark VARCHAR(500) NOT NULL DEFAULT '',
  operator_id BIGINT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_biz_member_point_log_member (member_id),
  CONSTRAINT fk_biz_member_point_member FOREIGN KEY (member_id) REFERENCES biz_member(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================
-- 配置管理 / 字典管理
-- =========================
CREATE TABLE IF NOT EXISTS sys_config (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  config_name VARCHAR(128) NOT NULL,
  config_key VARCHAR(128) NOT NULL,
  config_group VARCHAR(64) NOT NULL DEFAULT 'basic',
  config_type VARCHAR(32) NOT NULL DEFAULT 'text',
  config_value LONGTEXT NULL,
  description VARCHAR(500) NOT NULL DEFAULT '',
  sort INT NOT NULL DEFAULT 0,
  status TINYINT NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_sys_config_key (config_key),
  KEY idx_sys_config_group (config_group),
  KEY idx_sys_config_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sys_dict (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  category_code VARCHAR(64) NOT NULL,
  dict_name VARCHAR(128) NOT NULL,
  dict_code VARCHAR(64) NOT NULL,
  remark VARCHAR(500) NOT NULL DEFAULT '',
  status TINYINT NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_sys_dict_code (dict_code),
  KEY idx_sys_dict_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sys_dict_item (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  dict_id BIGINT NOT NULL,
  item_name VARCHAR(128) NOT NULL,
  item_value VARCHAR(128) NOT NULL,
  sort INT NOT NULL DEFAULT 0,
  status TINYINT NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_sys_dict_item_dict (dict_id),
  KEY idx_sys_dict_item_status (status),
  CONSTRAINT fk_sys_dict_item_dict FOREIGN KEY (dict_id) REFERENCES sys_dict(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================
-- 任务管理
-- =========================
CREATE TABLE IF NOT EXISTS op_task (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  task_name VARCHAR(128) NOT NULL,
  task_type TINYINT NOT NULL COMMENT '1定时 2延迟 3循环 4手动',
  group_name VARCHAR(64) NOT NULL DEFAULT 'default',
  target VARCHAR(255) NOT NULL,
  params_json JSON NULL,
  cron VARCHAR(64) NOT NULL DEFAULT '',
  delay_seconds INT NOT NULL DEFAULT 0,
  timeout_seconds INT NOT NULL DEFAULT 300,
  retry INT NOT NULL DEFAULT 0,
  description VARCHAR(500) NOT NULL DEFAULT '',
  status TINYINT NOT NULL DEFAULT 1,
  last_run_time DATETIME NULL,
  next_run_time DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  KEY idx_op_task_type (task_type),
  KEY idx_op_task_status (status),
  KEY idx_op_task_next_run (next_run_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS op_task_log (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  task_id BIGINT NOT NULL,
  task_name VARCHAR(128) NOT NULL,
  start_time DATETIME NOT NULL,
  end_time DATETIME NULL,
  duration_ms INT NOT NULL DEFAULT 0,
  status VARCHAR(16) NOT NULL COMMENT 'success/failed',
  result TEXT NULL,
  error_message TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_op_task_log_task (task_id),
  KEY idx_op_task_log_status (status),
  CONSTRAINT fk_op_task_log_task FOREIGN KEY (task_id) REFERENCES op_task(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS op_task_schedule_log (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  task_id BIGINT NOT NULL,
  task_name VARCHAR(128) NOT NULL,
  schedule_time DATETIME NOT NULL,
  execute_time DATETIME NULL,
  status VARCHAR(16) NOT NULL COMMENT 'waiting/completed/failed',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_op_task_schedule_task (task_id),
  KEY idx_op_task_schedule_status (status),
  CONSTRAINT fk_op_task_schedule_task FOREIGN KEY (task_id) REFERENCES op_task(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

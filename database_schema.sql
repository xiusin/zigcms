-- ===========================================
-- ZigCMS 数据库建表语句 (MySQL)
-- 生成时间: 2025-12-13
-- ===========================================

-- 首先创建数据库
CREATE DATABASE IF NOT EXISTS zigcms
CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE zigcms;

-- 管理员表
CREATE TABLE IF NOT EXISTS zigcms.admin (
    id INT AUTO_INCREMENT NOT NULL,
    username VARCHAR(255) NOT NULL DEFAULT '',
    phone VARCHAR(255) NOT NULL DEFAULT '',
    email VARCHAR(255) NOT NULL DEFAULT '',
    password VARCHAR(255) NOT NULL DEFAULT '',
    create_time BIGINT,
    update_time BIGINT,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 分类表
CREATE TABLE IF NOT EXISTS zigcms.category (
    id INT AUTO_INCREMENT NOT NULL,
    name VARCHAR(255) NOT NULL DEFAULT '',
    parent_id INT NOT NULL DEFAULT 0,
    sort INT NOT NULL DEFAULT 0,
    status INT NOT NULL DEFAULT 0,
    create_time BIGINT,
    update_time BIGINT,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 菜单表
CREATE TABLE IF NOT EXISTS zigcms.menu (
    id INT AUTO_INCREMENT NOT NULL,
    name VARCHAR(255) NOT NULL DEFAULT '',
    parent_id INT NOT NULL DEFAULT 0,
    url VARCHAR(255) NOT NULL DEFAULT '',
    icon VARCHAR(255) NOT NULL DEFAULT '',
    sort INT NOT NULL DEFAULT 0,
    status INT NOT NULL DEFAULT 0,
    create_time BIGINT,
    update_time BIGINT,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 角色表
CREATE TABLE IF NOT EXISTS zigcms.role (
    id INT AUTO_INCREMENT NOT NULL,
    name VARCHAR(255) NOT NULL DEFAULT '',
    code VARCHAR(255) NOT NULL DEFAULT '',
    description VARCHAR(255) NOT NULL DEFAULT '',
    permissions VARCHAR(255) NOT NULL DEFAULT '[]',
    data_scope INT NOT NULL DEFAULT 1,
    sort INT NOT NULL DEFAULT 0,
    status INT NOT NULL DEFAULT 1,
    remark VARCHAR(255) NOT NULL DEFAULT '',
    create_time BIGINT,
    update_time BIGINT,
    is_delete INT NOT NULL DEFAULT 0,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 部门表
CREATE TABLE IF NOT EXISTS zigcms.department (
    id INT AUTO_INCREMENT NOT NULL,
    name VARCHAR(255) NOT NULL DEFAULT '',
    code VARCHAR(255) NOT NULL DEFAULT '',
    parent_id INT NOT NULL DEFAULT 0,
    leader_id INT,
    phone VARCHAR(255) NOT NULL DEFAULT '',
    email VARCHAR(255) NOT NULL DEFAULT '',
    sort INT NOT NULL DEFAULT 0,
    status INT NOT NULL DEFAULT 1,
    remark VARCHAR(255) NOT NULL DEFAULT '',
    create_time BIGINT,
    update_time BIGINT,
    is_delete INT NOT NULL DEFAULT 0,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 职位表
CREATE TABLE IF NOT EXISTS zigcms.position (
    id INT AUTO_INCREMENT NOT NULL,
    name VARCHAR(255) NOT NULL DEFAULT '',
    code VARCHAR(255) NOT NULL DEFAULT '',
    department_id INT,
    level INT NOT NULL DEFAULT 1,
    sort INT NOT NULL DEFAULT 0,
    status INT NOT NULL DEFAULT 1,
    description VARCHAR(255) NOT NULL DEFAULT '',
    remark VARCHAR(255) NOT NULL DEFAULT '',
    create_time BIGINT,
    update_time BIGINT,
    is_delete INT NOT NULL DEFAULT 0,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 员工表
CREATE TABLE IF NOT EXISTS zigcms.employee (
    id INT AUTO_INCREMENT NOT NULL,
    employee_no VARCHAR(255) NOT NULL DEFAULT '',
    name VARCHAR(255) NOT NULL DEFAULT '',
    gender INT NOT NULL DEFAULT 0,
    phone VARCHAR(255) NOT NULL DEFAULT '',
    email VARCHAR(255) NOT NULL DEFAULT '',
    id_card VARCHAR(255) NOT NULL DEFAULT '',
    department_id INT,
    position_id INT,
    role_id INT,
    leader_id INT,
    hire_date BIGINT,
    avatar VARCHAR(255) NOT NULL DEFAULT '',
    status INT NOT NULL DEFAULT 1,
    sort INT NOT NULL DEFAULT 0,
    remark VARCHAR(255) NOT NULL DEFAULT '',
    create_time BIGINT,
    update_time BIGINT,
    is_delete INT NOT NULL DEFAULT 0,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 文章表
CREATE TABLE IF NOT EXISTS zigcms.article (
    id INT AUTO_INCREMENT NOT NULL,
    title VARCHAR(255) NOT NULL DEFAULT '',
    keyword VARCHAR(255) NOT NULL DEFAULT '',
    description LONGTEXT,
    content LONGTEXT,
    image_url VARCHAR(255) NOT NULL DEFAULT '',
    video_url VARCHAR(255) NOT NULL DEFAULT '',
    category_id INT NOT NULL DEFAULT 0,
    article_type VARCHAR(255) NOT NULL DEFAULT '',
    comment_switch INT NOT NULL DEFAULT 0,
    recomment_type INT NOT NULL DEFAULT 0,
    tags VARCHAR(255) NOT NULL DEFAULT '',
    status INT NOT NULL DEFAULT 0,
    sort INT NOT NULL DEFAULT 0,
    view_count INT NOT NULL DEFAULT 0,
    create_time BIGINT,
    update_time BIGINT,
    is_delete INT NOT NULL DEFAULT 0,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Banner表
CREATE TABLE IF NOT EXISTS zigcms.banner (
    id INT AUTO_INCREMENT NOT NULL,
    title VARCHAR(255) NOT NULL DEFAULT '',
    image_url VARCHAR(255) NOT NULL DEFAULT '',
    link_url VARCHAR(255) NOT NULL DEFAULT '',
    sort INT NOT NULL DEFAULT 0,
    status INT NOT NULL DEFAULT 0,
    create_time BIGINT,
    update_time BIGINT,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 设置表
CREATE TABLE IF NOT EXISTS zigcms.setting (
    key VARCHAR(255) NOT NULL DEFAULT '',
    value VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 任务表
CREATE TABLE IF NOT EXISTS zigcms.task (
    id INT AUTO_INCREMENT NOT NULL,
    name VARCHAR(255) NOT NULL DEFAULT '',
    cron VARCHAR(255) NOT NULL DEFAULT '',
    command VARCHAR(255) NOT NULL DEFAULT '',
    status INT NOT NULL DEFAULT 0,
    last_run BIGINT,
    next_run BIGINT,
    create_time BIGINT,
    update_time BIGINT,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 上传文件表
CREATE TABLE IF NOT EXISTS zigcms.upload (
    id INT AUTO_INCREMENT NOT NULL,
    original_name VARCHAR(255) NOT NULL DEFAULT '',
    path VARCHAR(255) NOT NULL DEFAULT '',
    md5 VARCHAR(255) NOT NULL DEFAULT '',
    ext VARCHAR(255) NOT NULL DEFAULT '',
    size INT NOT NULL DEFAULT 0,
    upload_type INT NOT NULL DEFAULT 0,
    url VARCHAR(255) NOT NULL DEFAULT '',
    create_time BIGINT,
    update_time BIGINT,
    is_delete INT NOT NULL DEFAULT 0,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 添加外键约束
ALTER TABLE zigcms.employee ADD CONSTRAINT fk_employee_department
FOREIGN KEY (department_id) REFERENCES zigcms.department(id) ON DELETE SET NULL;

ALTER TABLE zigcms.employee ADD CONSTRAINT fk_employee_position
FOREIGN KEY (position_id) REFERENCES zigcms.position(id) ON DELETE SET NULL;

ALTER TABLE zigcms.employee ADD CONSTRAINT fk_employee_role
FOREIGN KEY (role_id) REFERENCES zigcms.role(id) ON DELETE SET NULL;

ALTER TABLE zigcms.employee ADD CONSTRAINT fk_employee_leader
FOREIGN KEY (leader_id) REFERENCES zigcms.employee(id) ON DELETE SET NULL;

ALTER TABLE zigcms.position ADD CONSTRAINT fk_position_department
FOREIGN KEY (department_id) REFERENCES zigcms.department(id) ON DELETE SET NULL;

ALTER TABLE zigcms.department ADD CONSTRAINT fk_department_parent
FOREIGN KEY (parent_id) REFERENCES zigcms.department(id) ON DELETE CASCADE;

ALTER TABLE zigcms.department ADD CONSTRAINT fk_department_leader
FOREIGN KEY (leader_id) REFERENCES zigcms.employee(id) ON DELETE SET NULL;

ALTER TABLE zigcms.article ADD CONSTRAINT fk_article_category
FOREIGN KEY (category_id) REFERENCES zigcms.category(id) ON DELETE CASCADE;

-- 创建索引以提高查询性能
CREATE INDEX idx_admin_username ON zigcms.admin(username);
CREATE INDEX idx_admin_phone ON zigcms.admin(phone);
CREATE INDEX idx_admin_email ON zigcms.admin(email);

CREATE INDEX idx_category_parent_id ON zigcms.category(parent_id);
CREATE INDEX idx_category_status ON zigcms.category(status);

CREATE INDEX idx_menu_parent_id ON zigcms.menu(parent_id);
CREATE INDEX idx_menu_status ON zigcms.menu(status);

CREATE INDEX idx_role_code ON zigcms.role(code);
CREATE INDEX idx_role_status ON zigcms.role(status);

CREATE INDEX idx_department_parent_id ON zigcms.department(parent_id);
CREATE INDEX idx_department_leader_id ON zigcms.department(leader_id);
CREATE INDEX idx_department_status ON zigcms.department(status);

CREATE INDEX idx_position_department_id ON zigcms.position(department_id);
CREATE INDEX idx_position_status ON zigcms.position(status);

CREATE INDEX idx_employee_department_id ON zigcms.employee(department_id);
CREATE INDEX idx_employee_position_id ON zigcms.employee(position_id);
CREATE INDEX idx_employee_role_id ON zigcms.employee(role_id);
CREATE INDEX idx_employee_leader_id ON zigcms.employee(leader_id);
CREATE INDEX idx_employee_employee_no ON zigcms.employee(employee_no);
CREATE INDEX idx_employee_status ON zigcms.employee(status);

CREATE INDEX idx_article_category_id ON zigcms.article(category_id);
CREATE INDEX idx_article_status ON zigcms.article(status);
CREATE INDEX idx_article_create_time ON zigcms.article(create_time);

CREATE INDEX idx_banner_status ON zigcms.banner(status);
CREATE INDEX idx_banner_sort ON zigcms.banner(sort);

CREATE INDEX idx_task_status ON zigcms.task(status);
CREATE INDEX idx_task_next_run ON zigcms.task(next_run);

CREATE INDEX idx_upload_md5 ON zigcms.upload(md5);
CREATE INDEX idx_upload_upload_type ON zigcms.upload(upload_type);
CREATE INDEX idx_upload_is_delete ON zigcms.upload(is_delete);

/*
执行说明:
1. 按照表创建顺序执行建表语句（先创建没有外键依赖的表）
2. 然后执行外键约束添加语句
3. 最后执行索引创建语句

建表顺序建议:
1. admin, setting, task, upload
2. category, menu, role
3. department, position
4. employee (依赖department, position, role)
5. article (依赖category)
6. banner

创建完成后，可以使用以下SQL验证表结构:
SHOW TABLES;
DESCRIBE zigcms.admin;
SHOW CREATE TABLE zigcms.employee;
*/

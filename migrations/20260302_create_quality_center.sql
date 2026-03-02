-- 质量中心模块表结构（MySQL）

-- 定时报表
CREATE TABLE IF NOT EXISTS scheduled_reports (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(200) NOT NULL DEFAULT '',
    description VARCHAR(500) NOT NULL DEFAULT '',
    report_type VARCHAR(32) NOT NULL DEFAULT 'daily',
    schedule VARCHAR(100) NOT NULL DEFAULT '',
    modules TEXT NOT NULL,
    recipients TEXT NOT NULL,
    format VARCHAR(16) NOT NULL DEFAULT 'pdf',
    watermark_enabled TINYINT NOT NULL DEFAULT 1,
    enabled TINYINT NOT NULL DEFAULT 1,
    last_run_at DATETIME DEFAULT NULL,
    next_run_at DATETIME DEFAULT NULL,
    last_status VARCHAR(32) NOT NULL DEFAULT '',
    created_by VARCHAR(64) NOT NULL DEFAULT '',
    created_at DATETIME DEFAULT NULL,
    updated_at DATETIME DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 报表执行历史
CREATE TABLE IF NOT EXISTS report_history (
    id INT PRIMARY KEY AUTO_INCREMENT,
    report_id INT NOT NULL DEFAULT 0,
    report_name VARCHAR(200) NOT NULL DEFAULT '',
    status VARCHAR(32) NOT NULL DEFAULT 'running',
    format VARCHAR(16) NOT NULL DEFAULT 'pdf',
    file_url VARCHAR(500) NOT NULL DEFAULT '',
    file_size INT NOT NULL DEFAULT 0,
    recipients TEXT NOT NULL,
    sent_count INT NOT NULL DEFAULT 0,
    error_message VARCHAR(500) NOT NULL DEFAULT '',
    started_at DATETIME DEFAULT NULL,
    finished_at DATETIME DEFAULT NULL,
    duration_ms INT NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 报表模板
CREATE TABLE IF NOT EXISTS report_templates (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(200) NOT NULL DEFAULT '',
    description VARCHAR(500) NOT NULL DEFAULT '',
    blocks TEXT NOT NULL,
    orientation VARCHAR(16) NOT NULL DEFAULT 'portrait',
    watermark TINYINT NOT NULL DEFAULT 0,
    header_text VARCHAR(200) NOT NULL DEFAULT '',
    footer_text VARCHAR(200) NOT NULL DEFAULT '',
    is_default TINYINT NOT NULL DEFAULT 0,
    created_by VARCHAR(64) NOT NULL DEFAULT '',
    created_at DATETIME DEFAULT NULL,
    updated_at DATETIME DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 邮件模板
CREATE TABLE IF NOT EXISTS email_templates (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(200) NOT NULL DEFAULT '',
    subject VARCHAR(300) NOT NULL DEFAULT '',
    body_html TEXT NOT NULL,
    variables TEXT NOT NULL,
    is_default TINYINT NOT NULL DEFAULT 0,
    scene VARCHAR(32) NOT NULL DEFAULT 'custom',
    created_by VARCHAR(64) NOT NULL DEFAULT '',
    created_at DATETIME DEFAULT NULL,
    updated_at DATETIME DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 关联记录
CREATE TABLE IF NOT EXISTS quality_link_records (
    id INT PRIMARY KEY AUTO_INCREMENT,
    source_type VARCHAR(32) NOT NULL DEFAULT '',
    source_id INT NOT NULL DEFAULT 0,
    source_title VARCHAR(200) NOT NULL DEFAULT '',
    target_type VARCHAR(32) NOT NULL DEFAULT '',
    target_id INT NOT NULL DEFAULT 0,
    target_title VARCHAR(200) NOT NULL DEFAULT '',
    link_type VARCHAR(32) NOT NULL DEFAULT '',
    created_by VARCHAR(64) NOT NULL DEFAULT '',
    created_at DATETIME DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 活动记录
CREATE TABLE IF NOT EXISTS quality_activities (
    id INT PRIMARY KEY AUTO_INCREMENT,
    type VARCHAR(32) NOT NULL DEFAULT '',
    title VARCHAR(200) NOT NULL DEFAULT '',
    description VARCHAR(500) NOT NULL DEFAULT '',
    module VARCHAR(64) NOT NULL DEFAULT '',
    user_name VARCHAR(64) NOT NULL DEFAULT '',
    user_avatar VARCHAR(300) NOT NULL DEFAULT '',
    related_id INT DEFAULT NULL,
    related_type VARCHAR(32) NOT NULL DEFAULT '',
    created_at DATETIME DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- AI 洞察
CREATE TABLE IF NOT EXISTS quality_ai_insights (
    id INT PRIMARY KEY AUTO_INCREMENT,
    type VARCHAR(32) NOT NULL DEFAULT 'suggestion',
    severity VARCHAR(16) NOT NULL DEFAULT 'medium',
    title VARCHAR(200) NOT NULL DEFAULT '',
    description VARCHAR(500) NOT NULL DEFAULT '',
    module VARCHAR(64) NOT NULL DEFAULT '',
    action_url VARCHAR(300) NOT NULL DEFAULT '',
    action_text VARCHAR(64) NOT NULL DEFAULT '',
    created_at DATETIME DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- AI 分析历史
CREATE TABLE IF NOT EXISTS quality_ai_analyses (
    id INT PRIMARY KEY AUTO_INCREMENT,
    task_id VARCHAR(64) NOT NULL DEFAULT '',
    analysis_type VARCHAR(32) NOT NULL DEFAULT 'custom',
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    question VARCHAR(500) NOT NULL DEFAULT '',
    module VARCHAR(64) NOT NULL DEFAULT '',
    summary TEXT NOT NULL,
    details TEXT NOT NULL,
    suggestions TEXT NOT NULL,
    risk_score INT NOT NULL DEFAULT 0,
    duration_ms INT NOT NULL DEFAULT 0,
    created_at DATETIME DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 索引
CREATE INDEX idx_scheduled_reports_enabled ON scheduled_reports(enabled);
CREATE INDEX idx_report_history_report_id ON report_history(report_id);
CREATE INDEX idx_report_history_status ON report_history(status);
CREATE INDEX idx_link_records_source ON quality_link_records(source_type, source_id);
CREATE INDEX idx_link_records_target ON quality_link_records(target_type, target_id);
CREATE INDEX idx_link_records_type ON quality_link_records(link_type);
CREATE INDEX idx_activities_type ON quality_activities(type);
CREATE INDEX idx_ai_insights_type ON quality_ai_insights(type);
CREATE INDEX idx_ai_analyses_task_id ON quality_ai_analyses(task_id);

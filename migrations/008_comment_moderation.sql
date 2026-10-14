-- 评论审核系统数据库迁移
-- 创建时间: 2026-03-07

-- 1. 敏感词表
CREATE TABLE IF NOT EXISTS `sensitive_words` (
  `id` INT PRIMARY KEY AUTO_INCREMENT COMMENT '敏感词ID',
  `word` VARCHAR(100) NOT NULL COMMENT '敏感词',
  `category` VARCHAR(50) NOT NULL DEFAULT 'general' COMMENT '分类: political-政治, porn-色情, violence-暴力, ad-广告, abuse-辱骂, general-通用',
  `level` TINYINT NOT NULL DEFAULT 1 COMMENT '严重程度: 1-低, 2-中, 3-高',
  `action` VARCHAR(20) NOT NULL DEFAULT 'replace' COMMENT '处理方式: replace-替换, block-拦截, review-人工审核',
  `replacement` VARCHAR(100) DEFAULT '***' COMMENT '替换文本',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 1-启用, 0-禁用',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  UNIQUE KEY `uk_word` (`word`),
  INDEX `idx_category` (`category`),
  INDEX `idx_level` (`level`),
  INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='敏感词表';

-- 2. 审核规则表
CREATE TABLE IF NOT EXISTS `moderation_rules` (
  `id` INT PRIMARY KEY AUTO_INCREMENT COMMENT '规则ID',
  `name` VARCHAR(100) NOT NULL COMMENT '规则名称',
  `description` TEXT COMMENT '规则描述',
  `rule_type` VARCHAR(50) NOT NULL COMMENT '规则类型: sensitive_word-敏感词, length-长度, frequency-频率, user_level-用户等级',
  `conditions` JSON NOT NULL COMMENT '规则条件（JSON格式）',
  `action` VARCHAR(20) NOT NULL DEFAULT 'review' COMMENT '处理方式: auto_approve-自动通过, auto_reject-自动拒绝, review-人工审核',
  `priority` INT NOT NULL DEFAULT 0 COMMENT '优先级（数字越大优先级越高）',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 1-启用, 0-禁用',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  INDEX `idx_rule_type` (`rule_type`),
  INDEX `idx_priority` (`priority`),
  INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='审核规则表';

-- 3. 审核记录表
CREATE TABLE IF NOT EXISTS `moderation_logs` (
  `id` INT PRIMARY KEY AUTO_INCREMENT COMMENT '审核记录ID',
  `content_type` VARCHAR(50) NOT NULL COMMENT '内容类型: comment-评论, feedback-反馈, requirement-需求',
  `content_id` INT NOT NULL COMMENT '内容ID',
  `content_text` TEXT NOT NULL COMMENT '内容文本',
  `user_id` INT NOT NULL COMMENT '用户ID',
  `status` VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT '审核状态: pending-待审核, approved-已通过, rejected-已拒绝, auto_approved-自动通过, auto_rejected-自动拒绝',
  `matched_words` JSON COMMENT '匹配的敏感词（JSON数组）',
  `matched_rules` JSON COMMENT '匹配的规则（JSON数组）',
  `auto_action` VARCHAR(20) COMMENT '自动处理方式',
  `reviewer_id` INT COMMENT '审核人ID',
  `review_reason` TEXT COMMENT '审核理由',
  `reviewed_at` TIMESTAMP NULL COMMENT '审核时间',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  INDEX `idx_content` (`content_type`, `content_id`),
  INDEX `idx_user_id` (`user_id`),
  INDEX `idx_status` (`status`),
  INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='审核记录表';

-- 4. 用户信用表
CREATE TABLE IF NOT EXISTS `user_credits` (
  `user_id` INT PRIMARY KEY COMMENT '用户ID',
  `credit_score` INT NOT NULL DEFAULT 100 COMMENT '信用分（0-100）',
  `violation_count` INT NOT NULL DEFAULT 0 COMMENT '违规次数',
  `last_violation_at` TIMESTAMP NULL COMMENT '最后违规时间',
  `status` VARCHAR(20) NOT NULL DEFAULT 'normal' COMMENT '状态: normal-正常, warning-警告, restricted-受限, banned-封禁',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  INDEX `idx_credit_score` (`credit_score`),
  INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户信用表';

-- 5. 插入默认敏感词（示例）
INSERT INTO `sensitive_words` (`word`, `category`, `level`, `action`) VALUES
-- 政治类
('敏感词1', 'political', 3, 'block'),
('敏感词2', 'political', 3, 'block'),

-- 色情类
('色情词1', 'porn', 3, 'block'),
('色情词2', 'porn', 3, 'block'),

-- 暴力类
('暴力词1', 'violence', 2, 'review'),
('暴力词2', 'violence', 2, 'review'),

-- 广告类
('加微信', 'ad', 1, 'replace'),
('加QQ', 'ad', 1, 'replace'),
('联系方式', 'ad', 1, 'review'),

-- 辱骂类
('傻逼', 'abuse', 2, 'replace'),
('垃圾', 'abuse', 1, 'replace'),
('白痴', 'abuse', 2, 'replace');

-- 6. 插入默认审核规则
INSERT INTO `moderation_rules` (`name`, `description`, `rule_type`, `conditions`, `action`, `priority`) VALUES
-- 敏感词规则
('高危敏感词拦截', '包含高危敏感词的内容直接拦截', 'sensitive_word', 
 JSON_OBJECT('level', 3), 'auto_reject', 100),

('中危敏感词审核', '包含中危敏感词的内容需要人工审核', 'sensitive_word', 
 JSON_OBJECT('level', 2), 'review', 80),

('低危敏感词替换', '包含低危敏感词的内容自动替换后通过', 'sensitive_word', 
 JSON_OBJECT('level', 1), 'auto_approve', 60),

-- 长度规则
('内容过短拦截', '内容长度小于5个字符的拦截', 'length', 
 JSON_OBJECT('min_length', 5), 'auto_reject', 50),

('内容过长审核', '内容长度超过1000个字符的需要审核', 'length', 
 JSON_OBJECT('max_length', 1000), 'review', 40),

-- 频率规则
('高频发布审核', '1分钟内发布超过5条评论的需要审核', 'frequency', 
 JSON_OBJECT('time_window', 60, 'max_count', 5), 'review', 70),

-- 用户等级规则
('新用户审核', '注册时间小于7天的用户评论需要审核', 'user_level', 
 JSON_OBJECT('min_register_days', 7), 'review', 30),

('低信用用户审核', '信用分低于60的用户评论需要审核', 'user_level', 
 JSON_OBJECT('min_credit_score', 60), 'review', 90);

-- 7. 创建审核统计视图
CREATE OR REPLACE VIEW `moderation_stats` AS
SELECT 
  DATE(created_at) as date,
  status,
  COUNT(*) as count,
  COUNT(DISTINCT user_id) as user_count
FROM moderation_logs
GROUP BY DATE(created_at), status;

-- 8. 创建用户违规统计视图
CREATE OR REPLACE VIEW `user_violation_stats` AS
SELECT 
  user_id,
  COUNT(*) as total_violations,
  SUM(CASE WHEN status = 'rejected' THEN 1 ELSE 0 END) as rejected_count,
  SUM(CASE WHEN status = 'auto_rejected' THEN 1 ELSE 0 END) as auto_rejected_count,
  MAX(created_at) as last_violation_at
FROM moderation_logs
WHERE status IN ('rejected', 'auto_rejected')
GROUP BY user_id;

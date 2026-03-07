-- 反馈评论表迁移
-- 创建时间: 2026-03-07

-- 创建反馈评论表
CREATE TABLE IF NOT EXISTS feedback_comments (
    id INT AUTO_INCREMENT PRIMARY KEY COMMENT '评论ID',
    feedback_id INT NOT NULL COMMENT '反馈ID',
    parent_id INT NULL COMMENT '父评论ID（回复时使用）',
    author VARCHAR(100) NOT NULL COMMENT '评论者',
    content TEXT NOT NULL COMMENT '评论内容',
    attachments JSON NULL COMMENT '附件列表（JSON数组）',
    created_at BIGINT NOT NULL COMMENT '创建时间（Unix时间戳）',
    updated_at BIGINT NOT NULL COMMENT '更新时间（Unix时间戳）',
    
    INDEX idx_feedback_id (feedback_id),
    INDEX idx_parent_id (parent_id),
    INDEX idx_author (author),
    INDEX idx_created_at (created_at),
    
    FOREIGN KEY (feedback_id) REFERENCES feedbacks(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_id) REFERENCES feedback_comments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='反馈评论表';

-- 创建评论统计触发器（更新反馈的评论数）
DELIMITER $$

CREATE TRIGGER after_comment_insert
AFTER INSERT ON feedback_comments
FOR EACH ROW
BEGIN
    -- 更新反馈的跟进次数（复用 follow_count 字段）
    UPDATE feedbacks 
    SET follow_count = follow_count + 1,
        last_follow_at = NEW.created_at
    WHERE id = NEW.feedback_id;
END$$

CREATE TRIGGER after_comment_delete
AFTER DELETE ON feedback_comments
FOR EACH ROW
BEGIN
    -- 更新反馈的跟进次数
    UPDATE feedbacks 
    SET follow_count = GREATEST(0, follow_count - 1)
    WHERE id = OLD.feedback_id;
END$$

DELIMITER ;

-- 插入测试数据
INSERT INTO feedback_comments (feedback_id, parent_id, author, content, attachments, created_at, updated_at) VALUES
(1, NULL, '张三', '这个问题我也遇到过，建议优先处理', '[]', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(1, 1, '李四', '同意，已经影响到多个用户了', '[]', UNIX_TIMESTAMP(), UNIX_TIMESTAMP()),
(1, NULL, '王五', '我这边也有类似情况', '[{"name":"screenshot.png","url":"/uploads/screenshot.png","size":102400}]', UNIX_TIMESTAMP(), UNIX_TIMESTAMP());

-- 验证数据
SELECT 
    c.id,
    c.feedback_id,
    c.parent_id,
    c.author,
    c.content,
    c.attachments,
    FROM_UNIXTIME(c.created_at) as created_at,
    f.title as feedback_title
FROM feedback_comments c
LEFT JOIN feedbacks f ON c.feedback_id = f.id
ORDER BY c.created_at DESC;

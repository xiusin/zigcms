/**
 * 审核系统类型定义
 */

/**
 * 审核动作
 */
export type ModerationAction = 'auto_approve' | 'auto_reject' | 'review';

/**
 * 审核状态
 */
export type ModerationStatus = 'pending' | 'approved' | 'rejected' | 'auto_approved' | 'auto_rejected';

/**
 * 内容类型
 */
export type ContentType = 'comment' | 'feedback' | 'requirement';

/**
 * 敏感词分类
 */
export type SensitiveWordCategory = 'political' | 'porn' | 'violence' | 'ad' | 'abuse' | 'general';

/**
 * 敏感词处理方式
 */
export type SensitiveWordAction = 'replace' | 'block' | 'review';

/**
 * 审核规则类型
 */
export type RuleType = 'sensitive_word' | 'length' | 'frequency' | 'user_level';

/**
 * 用户信用状态
 */
export type UserCreditStatus = 'normal' | 'warning' | 'restricted' | 'banned';

/**
 * 匹配的敏感词
 */
export interface MatchedWord {
  word: string;
  start_pos: number;
  end_pos: number;
  category: SensitiveWordCategory;
  level: number;
  action: SensitiveWordAction;
}

/**
 * 审核结果
 */
export interface ModerationResult {
  action: ModerationAction;
  reason: string;
  matched_words: MatchedWord[];
  matched_rules: string[];
  cleaned_text?: string;
}

/**
 * 审核上下文
 */
export interface ModerationContext {
  content_text: string;
  user_id: number;
  user_register_days?: number;
  user_credit_score?: number;
  recent_comment_count?: number;
}

/**
 * 审核记录
 */
export interface ModerationLog {
  id: number;
  content_type: ContentType;
  content_id: number;
  content_text: string;
  user_id: number;
  status: ModerationStatus;
  matched_words?: MatchedWord[];
  matched_rules?: string[];
  auto_action?: ModerationAction;
  reviewer_id?: number;
  review_reason?: string;
  reviewed_at?: string;
  created_at: string;
}

/**
 * 敏感词
 */
export interface SensitiveWord {
  id: number;
  word: string;
  category: SensitiveWordCategory;
  level: number;
  action: SensitiveWordAction;
  replacement: string;
  status: number;
  created_at: string;
  updated_at: string;
}

/**
 * 审核规则
 */
export interface ModerationRule {
  id: number;
  name: string;
  description: string;
  rule_type: RuleType;
  conditions: Record<string, any>;
  action: ModerationAction;
  priority: number;
  status: number;
  created_at: string;
  updated_at: string;
}

/**
 * 用户信用
 */
export interface UserCredit {
  user_id: number;
  credit_score: number;
  violation_count: number;
  last_violation_at?: string;
  status: UserCreditStatus;
  updated_at: string;
}

/**
 * 审核统计
 */
export interface ModerationStats {
  total: number;
  pending: number;
  approved: number;
  rejected: number;
  auto_approved: number;
  auto_rejected: number;
}

/**
 * 审核请求参数
 */
export interface CheckContentRequest {
  content_text: string;
  user_id: number;
  user_register_days?: number;
  user_credit_score?: number;
  recent_comment_count?: number;
}

/**
 * 审核操作请求参数
 */
export interface ReviewRequest {
  reviewer_id: number;
  review_reason: string;
}

/**
 * 敏感词创建请求参数
 */
export interface CreateSensitiveWordRequest {
  word: string;
  category: SensitiveWordCategory;
  level: number;
  action: SensitiveWordAction;
  replacement?: string;
}

/**
 * 敏感词更新请求参数
 */
export interface UpdateSensitiveWordRequest {
  word?: string;
  category?: SensitiveWordCategory;
  level?: number;
  action?: SensitiveWordAction;
  replacement?: string;
  status?: number;
}

/**
 * 敏感词批量导入请求参数
 */
export interface BatchImportSensitiveWordsRequest {
  words: Array<{
    word: string;
    category: SensitiveWordCategory;
    level: number;
    action: SensitiveWordAction;
    replacement?: string;
  }>;
}

/**
 * 审核规则创建请求参数
 */
export interface CreateModerationRuleRequest {
  name: string;
  description: string;
  rule_type: RuleType;
  conditions: Record<string, any>;
  action: ModerationAction;
  priority: number;
}

/**
 * 审核规则更新请求参数
 */
export interface UpdateModerationRuleRequest {
  name?: string;
  description?: string;
  rule_type?: RuleType;
  conditions?: Record<string, any>;
  action?: ModerationAction;
  priority?: number;
  status?: number;
}

/**
 * 分页查询参数
 */
export interface ModerationQueryParams {
  page?: number;
  page_size?: number;
  status?: ModerationStatus;
  content_type?: ContentType;
  start_date?: string;
  end_date?: string;
  keyword?: string;
}

/**
 * 敏感词查询参数
 */
export interface SensitiveWordQueryParams {
  page?: number;
  page_size?: number;
  category?: SensitiveWordCategory;
  level?: number;
  keyword?: string;
}

/**
 * 审核规则查询参数
 */
export interface ModerationRuleQueryParams {
  page?: number;
  page_size?: number;
  rule_type?: RuleType;
  status?: number;
}

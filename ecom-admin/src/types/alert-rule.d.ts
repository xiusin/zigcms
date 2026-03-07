/**
 * 告警规则类型定义
 */

export type AlertLevel = 'critical' | 'high' | 'medium' | 'low';

export type RuleType =
  | 'brute_force'
  | 'sql_injection'
  | 'xss'
  | 'csrf'
  | 'rate_limit'
  | 'abnormal_access'
  | 'data_leak'
  | 'permission_denied'
  | 'custom';

export type ConditionOperator =
  | 'eq'
  | 'ne'
  | 'gt'
  | 'lt'
  | 'gte'
  | 'lte'
  | 'contains'
  | 'regex';

export type LogicOperator = 'and' | 'or';

export type ActionType = 'alert' | 'block' | 'notify' | 'log';

export interface RuleCondition {
  field: string;
  operator: ConditionOperator;
  value: any;
  logic?: LogicOperator;
}

export interface RuleAction {
  action_type: ActionType;
  params: Record<string, any>;
}

export interface AlertRule {
  id?: number;
  name: string;
  description: string;
  rule_type: RuleType;
  level: AlertLevel;
  conditions: string | RuleCondition[];
  actions: string | RuleAction[];
  enabled: boolean;
  priority: number;
  created_by?: number;
  created_at?: string;
  updated_at?: string;
}

export interface CreateAlertRuleDto {
  name: string;
  description: string;
  rule_type: RuleType;
  level: AlertLevel;
  conditions: RuleCondition[];
  actions: RuleAction[];
  enabled?: boolean;
  priority?: number;
}

export interface UpdateAlertRuleDto extends Partial<CreateAlertRuleDto> {
  id: number;
}

export interface TestAlertRuleDto {
  test_data: Record<string, any>;
}

export interface TestAlertRuleResult {
  matched: boolean;
}

export interface AlertRuleListQuery {
  rule_type?: RuleType;
  enabled?: boolean;
  page?: number;
  page_size?: number;
}

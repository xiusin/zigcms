/**
 * 告警规则 API
 */
import request from '@/utils/request';
import type {
  AlertRule,
  CreateAlertRuleDto,
  UpdateAlertRuleDto,
  TestAlertRuleDto,
  TestAlertRuleResult,
  AlertRuleListQuery,
} from '@/types/alert-rule';

/**
 * 获取告警规则列表
 */
export function getAlertRules(params?: AlertRuleListQuery) {
  return request.get<AlertRule[]>('/api/security/alert-rules', { params });
}

/**
 * 获取启用的告警规则
 */
export function getEnabledAlertRules() {
  return request.get<AlertRule[]>('/api/security/alert-rules/enabled');
}

/**
 * 获取告警规则详情
 */
export function getAlertRule(id: number) {
  return request.get<AlertRule>(`/api/security/alert-rules/${id}`);
}

/**
 * 创建告警规则
 */
export function createAlertRule(data: CreateAlertRuleDto) {
  return request.post<AlertRule>('/api/security/alert-rules', data);
}

/**
 * 更新告警规则
 */
export function updateAlertRule(id: number, data: UpdateAlertRuleDto) {
  return request.put<AlertRule>(`/api/security/alert-rules/${id}`, data);
}

/**
 * 删除告警规则
 */
export function deleteAlertRule(id: number) {
  return request.delete(`/api/security/alert-rules/${id}`);
}

/**
 * 启用告警规则
 */
export function enableAlertRule(id: number) {
  return request.post(`/api/security/alert-rules/${id}/enable`);
}

/**
 * 禁用告警规则
 */
export function disableAlertRule(id: number) {
  return request.post(`/api/security/alert-rules/${id}/disable`);
}

/**
 * 测试告警规则
 */
export function testAlertRule(id: number, data: TestAlertRuleDto) {
  return request.post<TestAlertRuleResult>(`/api/security/alert-rules/${id}/test`, data);
}

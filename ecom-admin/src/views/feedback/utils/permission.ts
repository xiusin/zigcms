/**
 * 反馈系统权限检查工具
 * 提供反馈相关的权限检查函数
 * @module feedback/utils/permission
 */

import { computed } from 'vue';
import type { FeedbackPermission } from '../constants/permissions';
import { FeedbackPermissions, RolePermissionMap } from '../constants/permissions';
import useUserStore from '@/store/modules/user';
import type { Feedback } from '@/api/feedback';

/**
 * 角色 ID 常量
 * 与后端角色定义保持一致
 */
export const RoleIds = {
  /** 超级管理员 */
  SUPER_ADMIN: 1,
  /** 管理员 */
  ADMIN: 2,
  /** 普通用户 */
  USER: 3,
} as const;

/**
 * 检查当前用户是否拥有指定权限
 * 管理员(role_id=1)拥有所有权限
 * @param permission 权限标识
 * @returns 是否拥有权限
 */
export function checkPermission(permission: FeedbackPermission): boolean {
  const userStore = useUserStore();

  // 超级管理员拥有所有权限
  if (userStore.role_id === RoleIds.SUPER_ADMIN) {
    return true;
  }

  // 检查用户按钮权限列表
  if (userStore.buttons && userStore.buttons.length > 0) {
    return userStore.buttons.includes(permission);
  }

  // 基于角色的默认权限检查
  const userPermissions = getCurrentUserPermissions();
  return userPermissions.includes(permission);
}

/**
 * 获取当前用户的权限列表
 * @returns 权限列表
 */
export function getCurrentUserPermissions(): FeedbackPermission[] {
  const userStore = useUserStore();

  // 超级管理员拥有所有权限
  if (userStore.role_id === RoleIds.SUPER_ADMIN) {
    return Object.values(FeedbackPermissions);
  }

  // 管理员拥有所有反馈权限
  if (userStore.role_id === RoleIds.ADMIN) {
    return [...RolePermissionMap.ADMIN];
  }

  // 普通用户仅拥有基础权限
  return [...RolePermissionMap.USER];
}

/**
 * 检查当前用户是否为管理员
 * @returns 是否为管理员
 */
export function isAdmin(): boolean {
  const userStore = useUserStore();
  return userStore.role_id === RoleIds.SUPER_ADMIN || userStore.role_id === RoleIds.ADMIN;
}

/**
 * 检查当前用户是否为超级管理员
 * @returns 是否为超级管理员
 */
export function isSuperAdmin(): boolean {
  const userStore = useUserStore();
  return userStore.role_id === RoleIds.SUPER_ADMIN;
}

/**
 * 获取当前用户ID
 * @returns 用户ID
 */
export function getCurrentUserId(): number | undefined {
  const userStore = useUserStore();
  return userStore.id;
}

/**
 * 检查是否有指定反馈权限
 * 支持针对具体反馈对象的权限检查
 * @param permission 权限标识
 * @param feedback 反馈对象（可选）
 * @returns 是否拥有权限
 */
export function checkFeedbackPermission(
  permission: FeedbackPermission,
  feedback?: Feedback
): boolean {
  // 首先检查基础权限
  if (!checkPermission(permission)) {
    return false;
  }

  // 如果有反馈对象，进行更细粒度的检查
  if (feedback) {
    const currentUserId = getCurrentUserId();

    switch (permission) {
      case FeedbackPermissions.EDIT:
        // 编辑权限：创建者、管理员、指派人可以编辑
        return canEditFeedback(feedback);

      case FeedbackPermissions.DELETE:
        // 删除权限：创建者或管理员可以删除
        return canDeleteFeedback(feedback);

      case FeedbackPermissions.STATUS_CHANGE:
        // 状态变更权限：处理人或管理员
        return canChangeStatus(feedback);

      case FeedbackPermissions.ASSIGN:
        // 指派权限：管理员或处理人
        return isAdmin() || feedback.handler_id === currentUserId;

      default:
        return true;
    }
  }

  return true;
}

/**
 * 检查是否能编辑反馈
 * 规则：创建者、管理员、指派人可以编辑
 * @param feedback 反馈对象
 * @returns 是否能编辑
 */
export function canEditFeedback(feedback: Feedback): boolean {
  const currentUserId = getCurrentUserId();

  // 管理员可以编辑所有反馈
  if (isAdmin()) {
    return true;
  }

  // 创建者可以编辑自己的反馈
  if (feedback.creator_id === currentUserId) {
    return true;
  }

  // 指派人可以编辑被指派的反馈
  if (feedback.handler_id === currentUserId) {
    return true;
  }

  return false;
}

/**
 * 检查是否能删除反馈
 * 规则：创建者（仅待处理状态）或管理员可以删除
 * @param feedback 反馈对象
 * @returns 是否能删除
 */
export function canDeleteFeedback(feedback: Feedback): boolean {
  const currentUserId = getCurrentUserId();

  // 管理员可以删除所有反馈
  if (isAdmin()) {
    return true;
  }

  // 创建者只能在待处理状态下删除自己的反馈
  if (feedback.creator_id === currentUserId && feedback.status === 0) {
    return true;
  }

  return false;
}

/**
 * 检查是否能更改反馈状态
 * 规则：处理人、管理员可以更改状态
 * @param feedback 反馈对象
 * @returns 是否能更改状态
 */
export function canChangeStatus(feedback: Feedback): boolean {
  const currentUserId = getCurrentUserId();

  // 管理员可以更改所有反馈状态
  if (isAdmin()) {
    return true;
  }

  // 指派的处理人可以更改状态
  if (feedback.handler_id === currentUserId) {
    return true;
  }

  // 创建者可以关闭自己的反馈
  if (feedback.creator_id === currentUserId) {
    return true;
  }

  return false;
}

/**
 * 检查是否能删除评论
 * 规则：评论作者、管理员可以删除
 * @param commentUserId 评论作者ID
 * @returns 是否能删除
 */
export function canDeleteComment(commentUserId: number): boolean {
  const currentUserId = getCurrentUserId();

  // 管理员可以删除所有评论
  if (isAdmin()) {
    return true;
  }

  // 评论作者可以删除自己的评论
  if (commentUserId === currentUserId) {
    return true;
  }

  return false;
}

/**
 * 检查是否能管理标签
 * 规则：仅管理员可以管理标签
 * @returns 是否能管理标签
 */
export function canManageTags(): boolean {
  return checkPermission(FeedbackPermissions.TAG_MANAGE);
}

/**
 * 检查是否能查看统计
 * 规则：管理员可以查看所有统计，普通用户只能查看相关统计
 * @returns 是否能查看统计
 */
export function canViewStatistics(): boolean {
  return checkPermission(FeedbackPermissions.STATISTICS_VIEW);
}

/**
 * 检查是否能指派反馈
 * 规则：管理员或处理人可以指派
 * @returns 是否能指派
 */
export function canAssignFeedback(): boolean {
  return checkPermission(FeedbackPermissions.ASSIGN);
}

/**
 * 检查是否能创建反馈
 * @returns 是否能创建
 */
export function canCreateFeedback(): boolean {
  return checkPermission(FeedbackPermissions.CREATE);
}

/**
 * 创建响应式权限检查组合式函数
 * 用于在 Vue 组件中进行响应式权限检查
 */
export function useFeedbackPermission() {
  const userStore = useUserStore();

  // 响应式权限检查
  const hasPermission = (permission: FeedbackPermission) => {
    return computed(() => checkPermission(permission));
  };

  // 响应式管理员检查
  const isAdminRef = computed(() => isAdmin());

  // 响应式超级管理员检查
  const isSuperAdminRef = computed(() => isSuperAdmin());

  // 响应式当前用户ID
  const currentUserId = computed(() => getCurrentUserId());

  return {
    hasPermission,
    isAdmin: isAdminRef,
    isSuperAdmin: isSuperAdminRef,
    currentUserId,
    checkFeedbackPermission,
    canEditFeedback,
    canDeleteFeedback,
    canChangeStatus,
    canDeleteComment,
    canManageTags,
    canViewStatistics,
    canAssignFeedback,
    canCreateFeedback,
  };
}

/**
 * 批量检查权限
 * 检查是否拥有多个权限中的任意一个（some）或全部（every）
 * @param permissions 权限列表
 * @param mode 检查模式：some-任意一个，every-全部
 * @returns 是否满足权限要求
 */
export function checkPermissions(
  permissions: FeedbackPermission[],
  mode: 'some' | 'every' = 'some'
): boolean {
  if (mode === 'every') {
    return permissions.every((p) => checkPermission(p));
  }
  return permissions.some((p) => checkPermission(p));
}

/**
 * 获取反馈操作权限状态
 * 返回一个对象，包含该反馈的所有操作权限状态
 * @param feedback 反馈对象
 * @returns 权限状态对象
 */
export function getFeedbackActionPermissions(feedback: Feedback): {
  canEdit: boolean;
  canDelete: boolean;
  canChangeStatus: boolean;
  canAssign: boolean;
  canManageTags: boolean;
} {
  return {
    canEdit: canEditFeedback(feedback),
    canDelete: canDeleteFeedback(feedback),
    canChangeStatus: canChangeStatus(feedback),
    canAssign: canAssignFeedback() && isAdmin(),
    canManageTags: canManageTags(),
  };
}

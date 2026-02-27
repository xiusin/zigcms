/**
 * 反馈系统权限常量定义
 * 定义反馈系统相关的所有权限标识符
 * @module feedback/constants/permissions
 */

/** 反馈系统权限前缀 */
export const FEEDBACK_PERMISSION_PREFIX = 'feedback:';

/**
 * 反馈系统权限常量枚举
 * 包含所有反馈相关的操作权限
 */
export const FeedbackPermissions = {
  /** 创建反馈权限 */
  CREATE: `${FEEDBACK_PERMISSION_PREFIX}create`,
  /** 编辑反馈权限 */
  EDIT: `${FEEDBACK_PERMISSION_PREFIX}edit`,
  /** 删除反馈权限 */
  DELETE: `${FEEDBACK_PERMISSION_PREFIX}delete`,
  /** 指派反馈权限 */
  ASSIGN: `${FEEDBACK_PERMISSION_PREFIX}assign`,
  /** 更改状态权限 */
  STATUS_CHANGE: `${FEEDBACK_PERMISSION_PREFIX}status:change`,
  /** 管理标签权限 */
  TAG_MANAGE: `${FEEDBACK_PERMISSION_PREFIX}tag:manage`,
  /** 查看统计权限 */
  STATISTICS_VIEW: `${FEEDBACK_PERMISSION_PREFIX}statistics:view`,
  /** 删除评论权限（他人评论） */
  COMMENT_DELETE: `${FEEDBACK_PERMISSION_PREFIX}comment:delete`,
} as const;

/**
 * 反馈系统权限类型
 * 用于类型检查和自动补全
 */
export type FeedbackPermission = typeof FeedbackPermissions[keyof typeof FeedbackPermissions];

/**
 * 角色权限映射
 * 定义不同角色拥有的权限集合
 */
export const RolePermissionMap = {
  /**
   * 普通用户权限
   * - 创建反馈
   * - 编辑自己的反馈
   * - 评论
   * - 订阅
   */
  USER: [
    FeedbackPermissions.CREATE,
  ],

  /**
   * 处理人权限
   * - 包含普通用户所有权限
   * - 编辑被指派的反馈
   * - 更改状态
   * - 评论
   */
  HANDLER: [
    FeedbackPermissions.CREATE,
    FeedbackPermissions.EDIT,
    FeedbackPermissions.STATUS_CHANGE,
    FeedbackPermissions.ASSIGN,
  ],

  /**
   * 管理员权限
   * - 所有操作权限
   * - 删除反馈
   * - 管理标签
   * - 删除他人评论
   */
  ADMIN: [
    FeedbackPermissions.CREATE,
    FeedbackPermissions.EDIT,
    FeedbackPermissions.DELETE,
    FeedbackPermissions.ASSIGN,
    FeedbackPermissions.STATUS_CHANGE,
    FeedbackPermissions.TAG_MANAGE,
    FeedbackPermissions.STATISTICS_VIEW,
    FeedbackPermissions.COMMENT_DELETE,
  ],
} as const;

/**
 * 权限描述映射
 * 用于权限管理界面显示
 */
export const PermissionDescriptions: Record<FeedbackPermission, string> = {
  [FeedbackPermissions.CREATE]: '创建反馈',
  [FeedbackPermissions.EDIT]: '编辑反馈',
  [FeedbackPermissions.DELETE]: '删除反馈',
  [FeedbackPermissions.ASSIGN]: '指派反馈',
  [FeedbackPermissions.STATUS_CHANGE]: '更改反馈状态',
  [FeedbackPermissions.TAG_MANAGE]: '管理标签',
  [FeedbackPermissions.STATISTICS_VIEW]: '查看统计报表',
  [FeedbackPermissions.COMMENT_DELETE]: '删除他人评论',
};

/**
 * 获取权限描述
 * @param permission 权限标识
 * @returns 权限描述文本
 */
export function getPermissionDescription(permission: FeedbackPermission): string {
  return PermissionDescriptions[permission] || permission;
}

/**
 * 获取角色拥有的所有权限
 * @param role 角色类型
 * @returns 权限列表
 */
export function getRolePermissions(role: keyof typeof RolePermissionMap): FeedbackPermission[] {
  return [...RolePermissionMap[role]];
}

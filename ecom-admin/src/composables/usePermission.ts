/**
 * 权限控制组合式函数
 * 用于检查用户权限和角色
 */

import { computed } from 'vue';
import { useUserStore } from '@/store';

export interface PermissionOptions {
  /**
   * 需要的权限列表（满足任一即可）
   */
  permissions?: string[];
  
  /**
   * 需要的角色列表（满足任一即可）
   */
  roles?: string[];
  
  /**
   * 是否需要同时满足权限和角色
   */
  requireAll?: boolean;
}

export function usePermission() {
  const userStore = useUserStore();
  
  /**
   * 当前用户信息
   */
  const currentUser = computed(() => userStore.userInfo);
  
  /**
   * 当前用户角色
   */
  const currentRole = computed(() => userStore.role || 'guest');
  
  /**
   * 当前用户权限列表
   */
  const currentPermissions = computed(() => userStore.permissions || []);
  
  /**
   * 检查是否有指定权限
   */
  const hasPermission = (permission: string): boolean => {
    // 超级管理员拥有所有权限
    if (currentRole.value === 'super_admin') {
      return true;
    }
    
    return currentPermissions.value.includes(permission);
  };
  
  /**
   * 检查是否有任一权限
   */
  const hasAnyPermission = (permissions: string[]): boolean => {
    if (permissions.length === 0) return true;
    
    // 超级管理员拥有所有权限
    if (currentRole.value === 'super_admin') {
      return true;
    }
    
    return permissions.some(permission => currentPermissions.value.includes(permission));
  };
  
  /**
   * 检查是否有所有权限
   */
  const hasAllPermissions = (permissions: string[]): boolean => {
    if (permissions.length === 0) return true;
    
    // 超级管理员拥有所有权限
    if (currentRole.value === 'super_admin') {
      return true;
    }
    
    return permissions.every(permission => currentPermissions.value.includes(permission));
  };
  
  /**
   * 检查是否有指定角色
   */
  const hasRole = (role: string): boolean => {
    // 超级管理员拥有所有角色
    if (currentRole.value === 'super_admin') {
      return true;
    }
    
    // 支持通配符 *
    if (role === '*') {
      return true;
    }
    
    return currentRole.value === role;
  };
  
  /**
   * 检查是否有任一角色
   */
  const hasAnyRole = (roles: string[]): boolean => {
    if (roles.length === 0) return true;
    
    // 超级管理员拥有所有角色
    if (currentRole.value === 'super_admin') {
      return true;
    }
    
    // 支持通配符 *
    if (roles.includes('*')) {
      return true;
    }
    
    return roles.includes(currentRole.value);
  };
  
  /**
   * 综合权限检查
   */
  const checkPermission = (options: PermissionOptions): boolean => {
    const { permissions = [], roles = [], requireAll = false } = options;
    
    // 超级管理员拥有所有权限
    if (currentRole.value === 'super_admin') {
      return true;
    }
    
    const hasRequiredPermissions = permissions.length === 0 || hasAnyPermission(permissions);
    const hasRequiredRoles = roles.length === 0 || hasAnyRole(roles);
    
    if (requireAll) {
      return hasRequiredPermissions && hasRequiredRoles;
    }
    
    return hasRequiredPermissions || hasRequiredRoles;
  };
  
  /**
   * 检查是否是资源所有者
   */
  const isOwner = (createdBy: string): boolean => {
    return currentUser.value?.username === createdBy;
  };
  
  /**
   * 检查是否可以编辑资源
   */
  const canEdit = (createdBy: string, requiredRoles: string[] = []): boolean => {
    // 超级管理员和管理员可以编辑所有资源
    if (hasAnyRole(['super_admin', 'admin'])) {
      return true;
    }
    
    // 检查是否有必需的角色
    if (requiredRoles.length > 0 && !hasAnyRole(requiredRoles)) {
      return false;
    }
    
    // 检查是否是资源所有者
    return isOwner(createdBy);
  };
  
  /**
   * 检查是否可以删除资源
   */
  const canDelete = (createdBy: string): boolean => {
    // 只有超级管理员和管理员可以删除
    return hasAnyRole(['super_admin', 'admin']);
  };
  
  return {
    // 用户信息
    currentUser,
    currentRole,
    currentPermissions,
    
    // 权限检查
    hasPermission,
    hasAnyPermission,
    hasAllPermissions,
    
    // 角色检查
    hasRole,
    hasAnyRole,
    
    // 综合检查
    checkPermission,
    
    // 资源权限
    isOwner,
    canEdit,
    canDelete,
  };
}

/**
 * 需求管理权限
 */
export function useRequirementPermission() {
  const permission = usePermission();
  
  return {
    ...permission,
    
    /**
     * 是否可以创建需求
     */
    canCreate: computed(() => {
      return permission.hasAnyRole(['super_admin', 'admin', 'tester']);
    }),
    
    /**
     * 是否可以使用 AI 生成
     */
    canUseAI: computed(() => {
      return permission.hasAnyRole(['super_admin', 'admin', 'tester']);
    }),
    
    /**
     * 是否可以导入导出
     */
    canImportExport: computed(() => {
      return permission.hasAnyRole(['super_admin', 'admin', 'tester']);
    }),
    
    /**
     * 是否可以关联测试用例
     */
    canLinkTestCase: computed(() => {
      return permission.hasAnyRole(['super_admin', 'admin', 'tester', 'developer']);
    }),
    
    /**
     * 是否可以批量操作
     */
    canBatchOperate: computed(() => {
      return permission.hasAnyRole(['super_admin', 'admin']);
    }),
  };
}

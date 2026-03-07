/**
 * 权限指令
 * 用法：v-permission="'quality:test_case:create'"
 * 或：v-permission="['quality:test_case:create', 'quality:test_case:update']"
 */

import type { Directive, DirectiveBinding } from 'vue';
import { useUserStore } from '@/store/modules/user';

function checkPermission(el: HTMLElement, binding: DirectiveBinding) {
  const { value } = binding;
  const userStore = useUserStore();
  
  // 超级管理员拥有所有权限
  if (userStore.isSuperAdmin) {
    return;
  }
  
  let hasPermission = false;
  
  if (typeof value === 'string') {
    // 单个权限
    hasPermission = userStore.hasPermission(value);
  } else if (Array.isArray(value)) {
    // 多个权限（满足任一即可）
    hasPermission = value.some(permission => userStore.hasPermission(permission));
  }
  
  if (!hasPermission) {
    // 移除元素
    el.parentNode?.removeChild(el);
  }
}

export const permission: Directive = {
  mounted(el: HTMLElement, binding: DirectiveBinding) {
    checkPermission(el, binding);
  },
  updated(el: HTMLElement, binding: DirectiveBinding) {
    checkPermission(el, binding);
  }
};

/**
 * 权限指令（需要所有权限）
 * 用法：v-permission-all="['quality:test_case:create', 'quality:test_case:update']"
 */
export const permissionAll: Directive = {
  mounted(el: HTMLElement, binding: DirectiveBinding) {
    const { value } = binding;
    const userStore = useUserStore();
    
    // 超级管理员拥有所有权限
    if (userStore.isSuperAdmin) {
      return;
    }
    
    let hasPermission = false;
    
    if (Array.isArray(value)) {
      // 需要所有权限
      hasPermission = value.every(permission => userStore.hasPermission(permission));
    }
    
    if (!hasPermission) {
      el.parentNode?.removeChild(el);
    }
  }
};

/**
 * 角色指令
 * 用法：v-role="'admin'"
 * 或：v-role="['admin', 'manager']"
 */
export const role: Directive = {
  mounted(el: HTMLElement, binding: DirectiveBinding) {
    const { value } = binding;
    const userStore = useUserStore();
    
    let hasRole = false;
    
    if (typeof value === 'string') {
      // 单个角色
      hasRole = userStore.hasRole(value);
    } else if (Array.isArray(value)) {
      // 多个角色（满足任一即可）
      hasRole = value.some(roleName => userStore.hasRole(roleName));
    }
    
    if (!hasRole) {
      el.parentNode?.removeChild(el);
    }
  }
};

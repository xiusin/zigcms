import { DirectiveBinding } from 'vue';
import { useUserStore } from '@/store';
import { intersection } from 'lodash';
import {
  getPermissionCache,
  setPermissionCache,
} from '@/utils/permission-cache';

/**
 * 权限指令 v-permission
 * 支持两种模式：
 * 1. 角色权限检查：v-permission="['admin','user']" - 检查用户角色是否包含指定角色
 * 2. 按钮权限检查：v-permission="'btn:add'" - 检查用户按钮权限是否包含指定权限
 * 3. 多种按钮权限：v-permission="['btn:add','btn:edit']" - 检查用户是否拥有任一指定按钮权限
 *
 * 支持权限缓存，减少权限请求次数
 */
function removeElement(el: HTMLElement) {
  if (el.parentNode) {
    el.parentNode.removeChild(el);
  }
}

function checkPermission(el: HTMLElement, binding: DirectiveBinding) {
  const { value } = binding;
  const userStore = useUserStore();
  const { role_ids, buttons, role_id, pages } = userStore;

  // 初始化权限缓存（如果用户信息中包含权限但缓存中没有）
  const cachedPermissions = getPermissionCache();
  if (!cachedPermissions && (buttons || pages)) {
    setPermissionCache({
      buttons: buttons || [],
      pages: pages || [],
      role_ids: role_ids || [],
    });
  }

  // 超级管理员拥有所有权限
  if (role_id === 1) {
    return;
  }

  if (!value) {
    return;
  }

  // 处理字符串形式 - 按钮权限
  if (typeof value === 'string') {
    // 按钮权限检查
    if (value.startsWith('btn:')) {
      const btnPermission = value;
      // 优先使用用户store中的权限，其次使用缓存
      const permissionList = buttons || cachedPermissions?.buttons || [];
      if (permissionList.length > 0) {
        if (!permissionList.includes(btnPermission)) {
          removeElement(el);
        }
      } else {
        // 没有按钮权限配置时，可以选择隐藏或显示
        // 默认隐藏没有明确授权的按钮
        removeElement(el);
      }
      return;
    }
    // 角色权限检查（单个角色）
    if (role_ids && Array.isArray(role_ids)) {
      if (!role_ids.includes(value)) {
        removeElement(el);
      }
    }
    return;
  }

  // 处理数组形式
  if (Array.isArray(value) && value.length > 0) {
    // 检查是否包含按钮权限（以 btn: 开头）
    const btnPermissions = value.filter(
      (item) => typeof item === 'string' && item.startsWith('btn:')
    );
    const rolePermissions = value.filter(
      (item) => typeof item === 'string' && !item.startsWith('btn:')
    );

    // 按钮权限检查：用户拥有数组中任一按钮权限即可显示
    if (btnPermissions.length > 0) {
      const permissionList = buttons || cachedPermissions?.buttons || [];
      if (permissionList.length > 0) {
        const hasBtnPermission = btnPermissions.some((btn) =>
          permissionList.includes(btn)
        );
        if (!hasBtnPermission) {
          // 没有按钮权限，隐藏元素
          // 但如果用户有角色权限，则仍然显示
          const hasRolePermission =
            rolePermissions.length === 0 ||
            (role_ids &&
              Array.isArray(role_ids) &&
              intersection(role_ids, rolePermissions).length > 0);

          if (!hasRolePermission) {
            removeElement(el);
          }
        }
      } else {
        // 没有按钮权限配置
        const hasRolePermission =
          rolePermissions.length === 0 ||
          (role_ids &&
            Array.isArray(role_ids) &&
            intersection(role_ids, rolePermissions).length > 0);

        if (!hasRolePermission) {
          removeElement(el);
        }
      }
      return;
    }

    // 纯角色权限检查
    if (value.length > 0) {
      const hasPermission = intersection(role_ids, value).length > 0;
      if (!hasPermission) {
        removeElement(el);
      }
    }
  }
}

export default {
  mounted(el: HTMLElement, binding: DirectiveBinding) {
    checkPermission(el, binding);
  },
  updated(el: HTMLElement, binding: DirectiveBinding) {
    checkPermission(el, binding);
  },
};

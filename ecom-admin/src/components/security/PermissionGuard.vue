<template>
  <div v-if="hasPermission" class="permission-guard">
    <slot />
  </div>
  <div v-else-if="showFallback" class="permission-denied">
    <slot name="fallback">
      <a-empty description="您没有权限访问此内容">
        <template #image>
          <icon-lock />
        </template>
      </a-empty>
    </slot>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useUserStore } from '@/store/modules/user';
import { IconLock } from '@arco-design/web-vue/es/icon';

interface Props {
  /** 需要的权限（单个） */
  permission?: string;
  /** 需要的权限（多个，满足任一即可） */
  permissions?: string[];
  /** 是否需要所有权限 */
  requireAll?: boolean;
  /** 是否显示无权限提示 */
  showFallback?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  requireAll: false,
  showFallback: true
});

const userStore = useUserStore();

// 检查是否有权限
const hasPermission = computed(() => {
  // 超级管理员拥有所有权限
  if (userStore.isSuperAdmin) {
    return true;
  }
  
  // 单个权限检查
  if (props.permission) {
    return userStore.hasPermission(props.permission);
  }
  
  // 多个权限检查
  if (props.permissions && props.permissions.length > 0) {
    if (props.requireAll) {
      // 需要所有权限
      return props.permissions.every(p => userStore.hasPermission(p));
    } else {
      // 需要任一权限
      return props.permissions.some(p => userStore.hasPermission(p));
    }
  }
  
  // 没有指定权限，默认允许
  return true;
});
</script>

<style scoped lang="less">
.permission-guard {
  width: 100%;
  height: 100%;
}

.permission-denied {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 200px;
  padding: 40px 20px;
  
  :deep(.arco-empty) {
    .arco-empty-image {
      font-size: 64px;
      color: var(--color-text-4);
    }
  }
}
</style>

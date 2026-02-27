<template>
  <div class="icon-selector">
    <a-trigger
      v-model:popup-visible="popupVisible"
      trigger="click"
      :popup-style="{ padding: '10px' }"
    >
      <div class="icon-selector-trigger">
        <a-input
          :model-value="modelValue"
          :placeholder="placeholder"
          :allow-clear="allowClear"
          readonly
          @clear="handleClear"
        >
          <template #prefix>
            <component :is="currentIcon" v-if="modelValue" />
            <icon-menu v-else />
          </template>
        </a-input>
      </div>
      <template #content>
        <div class="icon-selector-popup">
          <div class="icon-search">
            <a-input-search
              v-model="searchText"
              placeholder="搜索图标"
              allow-clear
              @search="handleSearch"
            />
          </div>
          <div class="icon-tabs">
            <a-tabs v-model:active-tab="activeTab" size="small">
              <a-tab-pane key="common" title="常用">
                <div class="icon-list">
                  <div
                    v-for="icon in commonIcons"
                    :key="icon.name"
                    class="icon-item"
                    :class="{ active: modelValue === icon.name }"
                    @click="handleSelect(icon.name)"
                  >
                    <component :is="icon.name" />
                    <span class="icon-name">{{ icon.label }}</span>
                  </div>
                </div>
              </a-tab-pane>
              <a-tab-pane key="all" title="全部">
                <div class="icon-list">
                  <div
                    v-for="icon in filteredIcons"
                    :key="icon.name"
                    class="icon-item"
                    :class="{ active: modelValue === icon.name }"
                    @click="handleSelect(icon.name)"
                  >
                    <component :is="icon.name" />
                    <span class="icon-name">{{ icon.label }}</span>
                  </div>
                </div>
              </a-tab-pane>
            </a-tabs>
          </div>
        </div>
      </template>
    </a-trigger>
  </div>
</template>

<script setup lang="ts">
  import { ref, computed, watch } from 'vue';
  import * as ArcoIcons from '@arco-design/web-vue/es/icon';

  interface Props {
    modelValue?: string;
    placeholder?: string;
    allowClear?: boolean;
  }

  const props = withDefaults(defineProps<Props>(), {
    modelValue: '',
    placeholder: '请选择图标',
    allowClear: true,
  });

  const emit = defineEmits(['update:modelValue', 'change']);

  const popupVisible = ref(false);
  const searchText = ref('');
  const activeTab = ref('common');

  // 图标映射表
  const iconMap: Record<string, string> = {};
  Object.keys(ArcoIcons).forEach((key) => {
    if (key.startsWith('Icon')) {
      const iconName = `icon${key.slice(4).toLowerCase()}`;
      iconMap[iconName] = key;
    }
  });

  // 常用图标列表
  const commonIcons = [
    { name: 'icon-home', label: '首页' },
    { name: 'icon-dashboard', label: '仪表盘' },
    { name: 'icon-user', label: '用户' },
    { name: 'icon-user-group', label: '用户组' },
    { name: 'icon-settings', label: '设置' },
    { name: 'icon-menu', label: '菜单' },
    { name: 'icon-tool', label: '工具' },
    { name: 'icon-lock', label: '锁定' },
    { name: 'icon-unlock', label: '解锁' },
    { name: 'icon-file', label: '文件' },
    { name: 'icon-folder', label: '文件夹' },
    { name: 'icon-folder-open', label: '打开文件夹' },
    { name: 'icon-file-add', label: '添加文件' },
    { name: 'icon-delete', label: '删除' },
    { name: 'icon-edit', label: '编辑' },
    { name: 'icon-plus', label: '添加' },
    { name: 'icon-minus', label: '减少' },
    { name: 'icon-search', label: '搜索' },
    { name: 'icon-download', label: '下载' },
    { name: 'icon-upload', label: '上传' },
    { name: 'icon-eye', label: '查看' },
    { name: 'icon-eye-invisible', label: '隐藏' },
    { name: 'icon-star', label: '星星' },
    { name: 'icon-star-fill', label: '星星填充' },
    { name: 'icon-heart', label: '爱心' },
    { name: 'icon-heart-fill', label: '爱心填充' },
    { name: 'icon-link', label: '链接' },
    { name: 'icon-apps', label: '应用' },
    { name: 'icon-calendar', label: '日历' },
    { name: 'icon-clock-circle', label: '时钟' },
    { name: 'icon-notification', label: '通知' },
    { name: 'icon-message', label: '消息' },
    { name: 'icon-cart', label: '购物车' },
    { name: 'icon-shopping-cart', label: '订单' },
    { name: 'icon-money', label: '金钱' },
    { name: 'icon-schedule', label: '日程' },
    { name: 'icon-tag', label: '标签' },
    { name: 'icon-bookmark', label: '书签' },
    { name: 'icon-history', label: '历史' },
    { name: 'icon-refresh', label: '刷新' },
    { name: 'icon-share', label: '分享' },
    { name: 'icon-export', label: '导出' },
    { name: 'icon-import', label: '导入' },
    { name: 'icon-lock', label: '锁定' },
    { name: 'icon-unlock', label: '解锁' },
    { name: 'icon-safe', label: '安全' },
    { name: 'icon-warning', label: '警告' },
    { name: 'icon-info', label: '信息' },
    { name: 'icon-check-circle', label: '成功' },
    { name: 'icon-close-circle', label: '错误' },
  ];

  // 全部图标列表
  const allIcons = computed(() => {
    return Object.keys(iconMap).map((name) => ({
      name,
      label: name.replace('icon', ''),
    }));
  });

  // 过滤后的图标列表
  const filteredIcons = computed(() => {
    if (!searchText.value) {
      return allIcons.value;
    }
    const search = searchText.value.toLowerCase();
    return allIcons.value.filter(
      (icon) =>
        icon.name.toLowerCase().includes(search) ||
        icon.label.toLowerCase().includes(search)
    );
  });

  // 当前选中的图标
  const currentIcon = computed(() => {
    if (!props.modelValue) return null;
    const iconKey = iconMap[props.modelValue];
    return iconKey ? ArcoIcons[iconKey] : null;
  });

  const handleSelect = (iconName: string) => {
    emit('update:modelValue', iconName);
    emit('change', iconName);
    popupVisible.value = false;
    searchText.value = '';
  };

  const handleClear = () => {
    emit('update:modelValue', '');
    emit('change', '');
  };

  const handleSearch = () => {
    // 搜索功能已在计算属性中实现
  };

  watch(popupVisible, (visible) => {
    if (!visible) {
      searchText.value = '';
    }
  });
</script>

<style scoped lang="less">
  .icon-selector {
    width: 100%;
  }

  .icon-selector-trigger {
    width: 100%;
  }

  .icon-selector-popup {
    width: 400px;
    max-height: 400px;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  .icon-search {
    padding-bottom: 10px;
    border-bottom: 1px solid var(--color-border-1);
  }

  .icon-tabs {
    flex: 1;
    overflow: hidden;
    margin-top: 10px;
  }

  .icon-list {
    display: grid;
    grid-template-columns: repeat(5, 1fr);
    gap: 8px;
    max-height: 280px;
    overflow-y: auto;
    padding: 4px;
  }

  .icon-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 8px 4px;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.2s;
    border: 1px solid transparent;

    &:hover {
      background-color: var(--color-fill-2);
    }

    &.active {
      background-color: var(--color-primary-light-1);
      border-color: var(--color-primary);
    }

    .arco-icon {
      font-size: 20px;
      margin-bottom: 4px;
    }

    .icon-name {
      font-size: 10px;
      color: var(--color-text-3);
      text-align: center;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      max-width: 100%;
    }
  }
</style>

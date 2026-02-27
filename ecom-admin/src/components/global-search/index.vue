<template>
  <a-modal
    v-model:visible="visible"
    :footer="false"
    :closable="false"
    :mask-closable="true"
    width="600px"
    :body-style="{ padding: 0 }"
    unmount-on-close
  >
    <div class="global-search">
      <div class="search-input-wrapper">
        <icon-search class="search-icon" />
        <input
          ref="searchInput"
          v-model="keyword"
          class="search-input"
          placeholder="搜索菜单、功能..."
          @input="handleSearch"
          @keydown.down.prevent="handleArrowDown"
          @keydown.up.prevent="handleArrowUp"
          @keydown.enter="handleEnter"
        />
        <div class="search-shortcut">ESC</div>
      </div>

      <div v-if="keyword" class="search-results">
        <div v-if="filteredResults.length === 0" class="no-results">
          <icon-empty />
          <div>未找到相关结果</div>
        </div>

        <div v-else class="results-list">
          <div
            v-for="(item, index) in filteredResults"
            :key="item.path"
            class="result-item"
            :class="{ active: activeIndex === index }"
            @click="handleSelect(item)"
            @mouseenter="activeIndex = index"
          >
            <div class="result-icon">
              <component :is="item.icon || 'icon-apps'" />
            </div>
            <div class="result-content">
              <div
                class="result-title"
                v-html="highlightKeyword(item.title)"
              ></div>
              <div class="result-path">{{ item.breadcrumb }}</div>
            </div>
            <icon-right class="result-arrow" />
          </div>
        </div>
      </div>

      <div v-else class="search-tips">
        <div class="tip-item"> <kbd>↑</kbd> <kbd>↓</kbd> 导航 </div>
        <div class="tip-item"> <kbd>Enter</kbd> 选择 </div>
        <div class="tip-item"> <kbd>ESC</kbd> 关闭 </div>
      </div>
    </div>
  </a-modal>
</template>

<script setup lang="ts">
  import { ref, computed, watch, onMounted, onUnmounted, nextTick } from 'vue';
  import { useRouter } from 'vue-router';
  import { useAppStore } from '@/store';

  const router = useRouter();
  const appStore = useAppStore();

  const visible = ref(false);
  const keyword = ref('');
  const activeIndex = ref(0);
  const searchInput = ref<HTMLInputElement>();

  // 搜索数据源
  const searchData = ref([
    {
      title: '数据概览',
      path: '/business/overview',
      icon: 'icon-dashboard',
      breadcrumb: '业务管理 / 数据概览',
    },
    {
      title: '会员管理',
      path: '/business/member',
      icon: 'icon-user',
      breadcrumb: '业务管理 / 会员管理',
    },
    {
      title: '订单管理',
      path: '/business/order',
      icon: 'icon-ordered-list',
      breadcrumb: '业务管理 / 订单管理',
    },
    {
      title: '菜单管理',
      path: '/system-manage/menu',
      icon: 'icon-menu',
      breadcrumb: '系统设置 / 菜单管理',
    },
    {
      title: '配置管理',
      path: '/system-manage/config',
      icon: 'icon-settings',
      breadcrumb: '系统设置 / 配置管理',
    },
    {
      title: '支付配置',
      path: '/system-manage/payment',
      icon: 'icon-alipay-circle',
      breadcrumb: '系统设置 / 支付配置',
    },
    {
      title: '管理员',
      path: '/system-manage/admin',
      icon: 'icon-user-group',
      breadcrumb: '系统设置 / 管理员',
    },
    {
      title: '任务管理',
      path: '/operation-manage/task',
      icon: 'icon-clock-circle',
      breadcrumb: '运营管理 / 任务管理',
    },
    {
      title: '插件管理',
      path: '/operation-manage/plugin',
      icon: 'icon-apps',
      breadcrumb: '运营管理 / 插件管理',
    },
    {
      title: '日志管理',
      path: '/security/log',
      icon: 'icon-file',
      breadcrumb: '安全运维 / 日志管理',
    },
    {
      title: '黑名单',
      path: '/security/blacklist',
      icon: 'icon-close-circle',
      breadcrumb: '安全运维 / 黑名单',
    },
  ]);

  // 过滤结果
  const filteredResults = computed(() => {
    if (!keyword.value) return [];
    const kw = keyword.value.toLowerCase();
    return searchData.value.filter(
      (item) =>
        item.title.toLowerCase().includes(kw) ||
        item.breadcrumb.toLowerCase().includes(kw)
    );
  });

  // 选择结果
  const handleSelect = (item: any) => {
    router.push(item.path);
    visible.value = false;
    keyword.value = '';
  };

  // 高亮关键词
  const highlightKeyword = (text: string) => {
    if (!keyword.value) return text;
    const regex = new RegExp(`(${keyword.value})`, 'gi');
    return text.replace(regex, '<span class="highlight">$1</span>');
  };

  // 搜索处理
  const handleSearch = () => {
    activeIndex.value = 0;
  };

  // 键盘导航
  const handleArrowDown = () => {
    if (activeIndex.value < filteredResults.value.length - 1) {
      activeIndex.value += 1;
    }
  };

  const handleArrowUp = () => {
    if (activeIndex.value > 0) {
      activeIndex.value -= 1;
    }
  };

  const handleEnter = () => {
    if (filteredResults.value[activeIndex.value]) {
      handleSelect(filteredResults.value[activeIndex.value]);
    }
  };

  // 打开搜索
  const open = () => {
    visible.value = true;
    nextTick(() => {
      searchInput.value?.focus();
    });
  };

  // 关闭搜索
  const close = () => {
    visible.value = false;
    keyword.value = '';
    activeIndex.value = 0;
  };

  // 监听可见性变化
  watch(visible, (val) => {
    if (val) {
      nextTick(() => {
        searchInput.value?.focus();
      });
    } else {
      keyword.value = '';
      activeIndex.value = 0;
    }
  });

  // 快捷键监听
  const handleKeydown = (e: KeyboardEvent) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
      e.preventDefault();
      open();
    }
    if (e.key === 'Escape' && visible.value) {
      close();
    }
  };

  onMounted(() => {
    window.addEventListener('keydown', handleKeydown);
  });

  onUnmounted(() => {
    window.removeEventListener('keydown', handleKeydown);
  });

  defineExpose({ open, close });
</script>

<style scoped lang="less">
  .global-search {
    .search-input-wrapper {
      display: flex;
      align-items: center;
      padding: 16px 20px;
      border-bottom: 1px solid var(--color-border-2);

      .search-icon {
        font-size: 20px;
        color: var(--color-text-3);
        margin-right: 12px;
      }

      .search-input {
        flex: 1;
        border: none;
        outline: none;
        font-size: 16px;
        color: var(--color-text-1);
        background: transparent;

        &::placeholder {
          color: var(--color-text-3);
        }
      }

      .search-shortcut {
        padding: 4px 8px;
        background: var(--color-fill-2);
        border-radius: 4px;
        font-size: 12px;
        color: var(--color-text-3);
      }
    }

    .search-results {
      max-height: 400px;
      overflow-y: auto;

      .no-results {
        padding: 60px 20px;
        text-align: center;
        color: var(--color-text-3);

        .arco-icon {
          font-size: 48px;
          margin-bottom: 12px;
          opacity: 0.3;
        }
      }

      .results-list {
        padding: 8px;

        .result-item {
          display: flex;
          align-items: center;
          padding: 12px;
          border-radius: 6px;
          cursor: pointer;
          transition: all 0.2s;

          &:hover,
          &.active {
            background: var(--color-fill-2);
          }

          .result-icon {
            width: 36px;
            height: 36px;
            display: flex;
            align-items: center;
            justify-content: center;
            background: var(--color-fill-3);
            border-radius: 6px;
            margin-right: 12px;
            font-size: 18px;
            color: var(--color-text-2);
          }

          .result-content {
            flex: 1;
            min-width: 0;

            .result-title {
              font-size: 14px;
              font-weight: 500;
              color: var(--color-text-1);
              margin-bottom: 4px;

              :deep(.highlight) {
                color: var(--color-primary);
                background: var(--color-primary-light-1);
                padding: 0 2px;
                border-radius: 2px;
              }
            }

            .result-path {
              font-size: 12px;
              color: var(--color-text-3);
            }
          }

          .result-arrow {
            font-size: 14px;
            color: var(--color-text-4);
          }
        }
      }
    }

    .search-tips {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 24px;
      padding: 20px;
      border-top: 1px solid var(--color-border-2);

      .tip-item {
        display: flex;
        align-items: center;
        gap: 8px;
        font-size: 12px;
        color: var(--color-text-3);

        kbd {
          padding: 4px 8px;
          background: var(--color-fill-2);
          border: 1px solid var(--color-border-2);
          border-radius: 4px;
          font-family: monospace;
          font-size: 12px;
        }
      }
    }
  }
</style>

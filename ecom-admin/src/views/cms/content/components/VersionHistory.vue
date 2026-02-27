<template>
  <div class="version-container">
    <a-spin :loading="loading">
      <a-timeline>
        <a-timeline-item
          v-for="version in versions"
          :key="version.id"
          :label="version.created_at"
        >
          <div class="version-item">
            <div class="version-header">
              <a-space>
                <a-tag color="blue">v{{ version.version }}</a-tag>
                <span class="version-user">{{ version.created_by_name }}</span>
              </a-space>
              <a-space>
                <a-button
                  type="text"
                  size="small"
                  @click="handleCompare(version)"
                >
                  对比
                </a-button>
                <a-popconfirm
                  content="确定回滚到此版本吗？"
                  @ok="handleRollback(version)"
                >
                  <a-button type="text" size="small" status="warning">
                    回滚
                  </a-button>
                </a-popconfirm>
              </a-space>
            </div>
            <div v-if="version.remark" class="version-remark">
              {{ version.remark }}
            </div>
          </div>
        </a-timeline-item>
      </a-timeline>

      <a-empty
        v-if="!loading && versions.length === 0"
        description="暂无版本记录"
      />
    </a-spin>

    <!-- 版本对比弹窗 -->
    <a-modal
      v-model:visible="compareVisible"
      title="版本对比"
      width="900px"
      :footer="false"
    >
      <a-spin :loading="compareLoading">
        <div class="compare-container">
          <div class="compare-side">
            <h4>当前版本</h4>
            <div class="compare-content">
              <div
                v-for="(value, key) in currentData"
                :key="key"
                class="compare-field"
              >
                <div class="field-label">{{ key }}:</div>
                <div class="field-value">{{ formatValue(value) }}</div>
              </div>
            </div>
          </div>
          <div class="compare-divider"></div>
          <div class="compare-side">
            <h4>版本 v{{ compareVersion?.version }}</h4>
            <div class="compare-content">
              <div
                v-for="(value, key) in compareData"
                :key="key"
                class="compare-field"
                :class="{ changed: isChanged(key) }"
              >
                <div class="field-label">{{ key }}:</div>
                <div class="field-value">{{ formatValue(value) }}</div>
              </div>
            </div>
          </div>
        </div>
      </a-spin>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, onMounted } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import { getContentVersions, rollbackContentVersion } from '@/api/cms';
  import type { ContentVersion } from '@/types/cms';

  interface Props {
    modelId: number;
    contentId: number;
  }

  const props = defineProps<Props>();
  const emit = defineEmits<{
    (e: 'rollback'): void;
  }>();

  const loading = ref(false);
  const versions = ref<ContentVersion[]>([]);

  // 对比
  const compareVisible = ref(false);
  const compareLoading = ref(false);
  const compareVersion = ref<ContentVersion>();
  const currentData = ref<Record<string, any>>({});
  const compareData = ref<Record<string, any>>({});

  // 加载版本列表
  const fetchVersions = async () => {
    loading.value = true;
    try {
      const res = await getContentVersions(props.modelId, props.contentId);
      versions.value = res.data || [];
    } catch (error) {
      Message.error('加载失败');
    } finally {
      loading.value = false;
    }
  };

  // 对比版本
  const handleCompare = async (version: ContentVersion) => {
    compareVersion.value = version;
    compareLoading.value = true;
    compareVisible.value = true;

    try {
      // 获取当前版本和历史版本数据
      currentData.value = versions.value[0]?.data || {};
      compareData.value = version.data || {};
    } catch (error) {
      Message.error('加载对比数据失败');
    } finally {
      compareLoading.value = false;
    }
  };

  // 回滚版本
  const handleRollback = async (version: ContentVersion) => {
    try {
      await rollbackContentVersion(
        props.modelId,
        props.contentId,
        version.version
      );
      Message.success('回滚成功');
      emit('rollback');
      await fetchVersions();
    } catch (error) {
      Message.error('回滚失败');
    }
  };

  // 判断字段是否变更
  const isChanged = (key: string) => {
    return (
      JSON.stringify(currentData.value[key]) !==
      JSON.stringify(compareData.value[key])
    );
  };

  // 格式化值
  const formatValue = (value: any) => {
    if (value === null || value === undefined) return '-';
    if (typeof value === 'object') return JSON.stringify(value, null, 2);
    return String(value);
  };

  onMounted(() => {
    fetchVersions();
  });
</script>

<style scoped lang="less">
  .version-container {
    padding: 20px;
  }

  .version-item {
    .version-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 8px;

      .version-user {
        color: var(--color-text-2);
      }
    }

    .version-remark {
      color: var(--color-text-3);
      font-size: 14px;
    }
  }

  .compare-container {
    display: flex;
    gap: 20px;

    .compare-side {
      flex: 1;

      h4 {
        margin-bottom: 16px;
        padding-bottom: 8px;
        border-bottom: 1px solid var(--color-border);
      }

      .compare-content {
        max-height: 500px;
        overflow-y: auto;

        .compare-field {
          padding: 8px;
          margin-bottom: 8px;
          border-radius: 4px;

          &.changed {
            background: #fff7e6;
            border-left: 3px solid #faad14;
          }

          .field-label {
            font-weight: 500;
            margin-bottom: 4px;
            color: var(--color-text-2);
          }

          .field-value {
            color: var(--color-text-1);
            white-space: pre-wrap;
            word-break: break-all;
          }
        }
      }
    }

    .compare-divider {
      width: 1px;
      background: var(--color-border);
    }
  }
</style>

<template>
  <div class="cms-dashboard">
    <a-row :gutter="16">
      <!-- 统计卡片 -->
      <a-col :span="6">
        <a-card :bordered="false" class="stat-card">
          <a-statistic title="内容总数" :value="stats.totalContents">
            <template #prefix>
              <icon-file />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :span="6">
        <a-card :bordered="false" class="stat-card">
          <a-statistic title="已发布" :value="stats.publishedContents">
            <template #prefix>
              <icon-check-circle />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :span="6">
        <a-card :bordered="false" class="stat-card">
          <a-statistic title="待审批" :value="stats.pendingApprovals">
            <template #prefix>
              <icon-clock-circle />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :span="6">
        <a-card :bordered="false" class="stat-card">
          <a-statistic title="媒体文件" :value="stats.totalMedia">
            <template #prefix>
              <icon-image />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
    </a-row>

    <a-row :gutter="16" style="margin-top: 16px">
      <!-- 最近内容 -->
      <a-col :span="12">
        <a-card title="最近内容" :bordered="false">
          <a-list :data="recentContents" :loading="loading">
            <template #item="{ item }">
              <a-list-item>
                <a-list-item-meta
                  :title="item.title"
                  :description="item.model_name"
                >
                  <template #avatar>
                    <a-avatar><icon-file /></a-avatar>
                  </template>
                </a-list-item-meta>
                <template #actions>
                  <a-tag :color="getStatusColor(item.status)">
                    {{ getStatusText(item.status) }}
                  </a-tag>
                </template>
              </a-list-item>
            </template>
          </a-list>
        </a-card>
      </a-col>

      <!-- 待审批内容 -->
      <a-col :span="12">
        <a-card title="待审批内容" :bordered="false">
          <a-list :data="pendingApprovals" :loading="loading">
            <template #item="{ item }">
              <a-list-item>
                <a-list-item-meta
                  :title="item.content_title"
                  :description="item.workflow_name"
                />
                <template #actions>
                  <a-button type="text" size="small" @click="handleApprove">
                    审批
                  </a-button>
                </template>
              </a-list-item>
            </template>
          </a-list>
        </a-card>
      </a-col>
    </a-row>

    <a-row :gutter="16" style="margin-top: 16px">
      <!-- 快捷操作 -->
      <a-col :span="24">
        <a-card title="快捷操作" :bordered="false">
          <a-space size="large">
            <a-button type="primary" @click="$router.push('/cms/model')">
              <template #icon><icon-plus /></template>
              创建模型
            </a-button>
            <a-button @click="$router.push('/cms/category')">
              <template #icon><icon-folder /></template>
              管理分类
            </a-button>
            <a-button @click="$router.push('/cms/media')">
              <template #icon><icon-upload /></template>
              上传文件
            </a-button>
            <a-button @click="$router.push('/cms/workflow')">
              <template #icon><icon-settings /></template>
              配置工作流
            </a-button>
          </a-space>
        </a-card>
      </a-col>
    </a-row>
  </div>
</template>

<script setup lang="ts">
  import { ref, onMounted } from 'vue';
  import { useRouter } from 'vue-router';
  import { Message } from '@arco-design/web-vue';
  import {
    IconFile,
    IconCheckCircle,
    IconClockCircle,
    IconImage,
    IconPlus,
    IconFolder,
    IconUpload,
    IconSettings,
  } from '@arco-design/web-vue/es/icon';

  const router = useRouter();
  const loading = ref(false);

  const stats = ref({
    totalContents: 35,
    publishedContents: 25,
    pendingApprovals: 3,
    totalMedia: 30,
  });

  const recentContents = ref([
    { id: 1, title: '示例文章1', model_name: '文章', status: 2 },
    { id: 2, title: '示例文章2', model_name: '文章', status: 0 },
    { id: 3, title: '示例产品1', model_name: '产品', status: 2 },
  ]);

  const pendingApprovals = ref([
    { id: 1, content_title: '待审批文章', workflow_name: '文章审批流程' },
  ]);

  const getStatusColor = (status: number) => {
    const colors = { 0: 'gray', 1: 'orange', 2: 'green', 3: 'blue' };
    return colors[status] || 'gray';
  };

  const getStatusText = (status: number) => {
    const texts = { 0: '草稿', 1: '待审核', 2: '已发布', 3: '已归档' };
    return texts[status] || '未知';
  };

  const handleApprove = () => {
    router.push('/cms/workflow');
  };

  onMounted(() => {
    // 数据已在 ref 中初始化
  });
</script>

<style scoped lang="less">
  .cms-dashboard {
    padding: 20px;

    .stat-card {
      :deep(.arco-statistic) {
        .arco-statistic-title {
          font-size: 14px;
          color: var(--color-text-2);
        }
        .arco-statistic-value {
          font-size: 28px;
          font-weight: 600;
        }
      }
    }
  }
</style>

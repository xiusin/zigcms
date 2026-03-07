<template>
  <div class="sensitive-words">
    <a-card title="敏感词管理" :bordered="false">
      <!-- 操作栏 -->
      <div class="action-bar">
        <a-space>
          <a-button type="primary" @click="handleCreate">
            <template #icon><icon-plus /></template>
            添加敏感词
          </a-button>
          <a-button @click="handleBatchImport">
            <template #icon><icon-upload /></template>
            批量导入
          </a-button>
          <a-button @click="handleExport">
            <template #icon><icon-download /></template>
            导出
          </a-button>
        </a-space>
      </div>

      <!-- 筛选条件 -->
      <a-form :model="queryParams" layout="inline" class="filter-form">
        <a-form-item label="分类">
          <a-select
            v-model="queryParams.category"
            placeholder="请选择分类"
            style="width: 150px"
            allow-clear
          >
            <a-option value="political">政治</a-option>
            <a-option value="porn">色情</a-option>
            <a-option value="violence">暴力</a-option>
            <a-option value="ad">广告</a-option>
            <a-option value="abuse">辱骂</a-option>
            <a-option value="general">通用</a-option>
          </a-select>
        </a-form-item>

        <a-form-item label="等级">
          <a-select
            v-model="queryParams.level"
            placeholder="请选择等级"
            style="width: 150px"
            allow-clear
          >
            <a-option :value="1">低危 (1)</a-option>
            <a-option :value="2">中危 (2)</a-option>
            <a-option :value="3">高危 (3)</a-option>
          </a-select>
        </a-form-item>

        <a-form-item label="关键词">
          <a-input
            v-model="queryParams.keyword"
            placeholder="请输入关键词"
            style="width: 200px"
            allow-clear
          />
        </a-form-item>

        <a-form-item>
          <a-space>
            <a-button type="primary" @click="handleSearch">
              <template #icon><icon-search /></template>
              查询
            </a-button>
            <a-button @click="handleReset">
              <template #icon><icon-refresh /></template>
              重置
            </a-button>
          </a-space>
        </a-form-item>
      </a-form>

      <!-- 敏感词列表 -->
      <a-table
        :columns="columns"
        :data="tableData"
        :loading="loading"
        :pagination="pagination"
        @page-change="handlePageChange"
        @page-size-change="handlePageSizeChange"
        row-key="id"
      >
        <template #category="{ record }">
          <a-tag :color="getCategoryColor(record.category)">
            {{ getCategoryText(record.category) }}
          </a-tag>
        </template>

        <template #level="{ record }">
          <a-tag :color="getLevelColor(record.level)">
            {{ getLevelText(record.level) }}
          </a-tag>
        </template>

        <template #action="{ record }">
          <a-tag>{{ getActionText(record.action) }}</a-tag>
        </template>

        <template #status="{ record }">
          <a-switch
            :model-value="record.status === 1"
            @change="(value) => handleToggleStatus(record, value)"
          />
        </template>

        <template #created_at="{ record }">
          {{ formatDateTime(record.created_at) }}
        </template>

        <template #actions="{ record }">
          <a-space>
            <a-button
              type="text"
              size="small"
              @click="handleEdit(record)"
            >
              <template #icon><icon-edit /></template>
              编辑
            </a-button>
            <a-popconfirm
              content="确定要删除这个敏感词吗？"
              @ok="handleDelete(record)"
            >
              <a-button
                type="text"
                size="small"
                status="danger"
              >
                <template #icon><icon-delete /></template>
                删除
              </a-button>
            </a-popconfirm>
          </a-space>
        </template>
      </a-table>
    </a-card>

    <!-- 添加/编辑对话框 -->
    <a-modal
      v-model:visible="formVisible"
      :title="formMode === 'create' ? '添加敏感词' : '编辑敏感词'"
      @ok="handleFormSubmit"
      @cancel="handleFormCancel"
      width="600px"
    >
      <a-form :model="formData" layout="vertical">
        <a-form-item label="敏感词" required>
          <a-input
            v-model="formData.word"
            placeholder="请输入敏感词"
            :max-length="100"
          />
        </a-form-item>

        <a-form-item label="分类" required>
          <a-select
            v-model="formData.category"
            placeholder="请选择分类"
          >
            <a-option value="political">政治</a-option>
            <a-option value="porn">色情</a-option>
            <a-option value="violence">暴力</a-option>
            <a-option value="ad">广告</a-option>
            <a-option value="abuse">辱骂</a-option>
            <a-option value="general">通用</a-option>
          </a-select>
        </a-form-item>

        <a-form-item label="等级" required>
          <a-select
            v-model="formData.level"
            placeholder="请选择等级"
          >
            <a-option :value="1">低危 (1)</a-option>
            <a-option :value="2">中危 (2)</a-option>
            <a-option :value="3">高危 (3)</a-option>
          </a-select>
        </a-form-item>

        <a-form-item label="处理方式" required>
          <a-select
            v-model="formData.action"
            placeholder="请选择处理方式"
          >
            <a-option value="replace">替换</a-option>
            <a-option value="block">拦截</a-option>
            <a-option value="review">人工审核</a-option>
          </a-select>
        </a-form-item>

        <a-form-item
          v-if="formData.action === 'replace'"
          label="替换文本"
        >
          <a-input
            v-model="formData.replacement"
            placeholder="请输入替换文本"
            :max-length="100"
          />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 批量导入对话框 -->
    <a-modal
      v-model:visible="importVisible"
      title="批量导入敏感词"
      @ok="handleImportSubmit"
      @cancel="handleImportCancel"
      width="600px"
    >
      <a-form layout="vertical">
        <a-form-item label="导入格式说明">
          <a-alert type="info">
            每行一个敏感词，格式：敏感词,分类,等级,处理方式,替换文本<br />
            示例：傻逼,abuse,2,replace,***
          </a-alert>
        </a-form-item>

        <a-form-item label="敏感词列表" required>
          <a-textarea
            v-model="importText"
            placeholder="请输入敏感词列表"
            :rows="10"
            :max-length="10000"
            show-word-limit
          />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { Message } from '@arco-design/web-vue';
import { sensitiveWordApi } from '@/api/moderation';
import type {
  SensitiveWord,
  CreateSensitiveWordRequest,
  UpdateSensitiveWordRequest,
  SensitiveWordQueryParams,
} from '@/types/moderation';
import dayjs from 'dayjs';

// 查询参数
const queryParams = reactive<SensitiveWordQueryParams>({
  page: 1,
  page_size: 20,
});

// 表格数据
const tableData = ref<SensitiveWord[]>([]);
const loading = ref(false);

// 分页
const pagination = reactive({
  current: 1,
  pageSize: 20,
  total: 0,
  showTotal: true,
  showPageSize: true,
});

// 表格列
const columns = [
  { title: 'ID', dataIndex: 'id', width: 80 },
  { title: '敏感词', dataIndex: 'word', width: 150 },
  { title: '分类', dataIndex: 'category', slotName: 'category', width: 120 },
  { title: '等级', dataIndex: 'level', slotName: 'level', width: 100 },
  { title: '处理方式', dataIndex: 'action', slotName: 'action', width: 120 },
  { title: '替换文本', dataIndex: 'replacement', width: 120 },
  { title: '状态', dataIndex: 'status', slotName: 'status', width: 100 },
  { title: '创建时间', dataIndex: 'created_at', slotName: 'created_at', width: 180 },
  { title: '操作', slotName: 'actions', width: 150, fixed: 'right' },
];

// 表单
const formVisible = ref(false);
const formMode = ref<'create' | 'edit'>('create');
const formData = reactive<CreateSensitiveWordRequest | UpdateSensitiveWordRequest>({
  word: '',
  category: 'general',
  level: 1,
  action: 'replace',
  replacement: '***',
});
const currentId = ref<number>();

// 导入
const importVisible = ref(false);
const importText = ref('');

// 加载列表数据
const loadData = async () => {
  loading.value = true;
  try {
    const { items, total } = await sensitiveWordApi.getList(queryParams);
    tableData.value = items;
    pagination.total = total;
  } catch (error) {
    Message.error('加载数据失败');
    console.error('加载数据失败:', error);
  } finally {
    loading.value = false;
  }
};

// 搜索
const handleSearch = () => {
  queryParams.page = 1;
  pagination.current = 1;
  loadData();
};

// 重置
const handleReset = () => {
  Object.assign(queryParams, {
    page: 1,
    page_size: 20,
    category: undefined,
    level: undefined,
    keyword: undefined,
  });
  pagination.current = 1;
  loadData();
};

// 分页变化
const handlePageChange = (page: number) => {
  queryParams.page = page;
  pagination.current = page;
  loadData();
};

const handlePageSizeChange = (pageSize: number) => {
  queryParams.page_size = pageSize;
  queryParams.page = 1;
  pagination.pageSize = pageSize;
  pagination.current = 1;
  loadData();
};

// 添加
const handleCreate = () => {
  formMode.value = 'create';
  Object.assign(formData, {
    word: '',
    category: 'general',
    level: 1,
    action: 'replace',
    replacement: '***',
  });
  formVisible.value = true;
};

// 编辑
const handleEdit = (record: SensitiveWord) => {
  formMode.value = 'edit';
  currentId.value = record.id;
  Object.assign(formData, {
    word: record.word,
    category: record.category,
    level: record.level,
    action: record.action,
    replacement: record.replacement,
  });
  formVisible.value = true;
};

// 提交表单
const handleFormSubmit = async () => {
  if (!formData.word?.trim()) {
    Message.warning('请输入敏感词');
    return;
  }

  try {
    if (formMode.value === 'create') {
      await sensitiveWordApi.create(formData as CreateSensitiveWordRequest);
      Message.success('添加成功');
    } else {
      await sensitiveWordApi.update(currentId.value!, formData as UpdateSensitiveWordRequest);
      Message.success('更新成功');
    }
    formVisible.value = false;
    loadData();
  } catch (error) {
    Message.error('操作失败');
    console.error('操作失败:', error);
  }
};

// 取消表单
const handleFormCancel = () => {
  formVisible.value = false;
};

// 删除
const handleDelete = async (record: SensitiveWord) => {
  try {
    await sensitiveWordApi.delete(record.id);
    Message.success('删除成功');
    loadData();
  } catch (error) {
    Message.error('删除失败');
    console.error('删除失败:', error);
  }
};

// 切换状态
const handleToggleStatus = async (record: SensitiveWord, value: boolean) => {
  try {
    await sensitiveWordApi.update(record.id, { status: value ? 1 : 0 });
    Message.success('状态已更新');
    loadData();
  } catch (error) {
    Message.error('状态更新失败');
    console.error('状态更新失败:', error);
  }
};

// 批量导入
const handleBatchImport = () => {
  importText.value = '';
  importVisible.value = true;
};

// 提交导入
const handleImportSubmit = async () => {
  if (!importText.value.trim()) {
    Message.warning('请输入敏感词列表');
    return;
  }

  try {
    const lines = importText.value.trim().split('\n');
    const words = lines.map((line) => {
      const parts = line.split(',');
      return {
        word: parts[0]?.trim() || '',
        category: (parts[1]?.trim() || 'general') as any,
        level: parseInt(parts[2]?.trim() || '1'),
        action: (parts[3]?.trim() || 'replace') as any,
        replacement: parts[4]?.trim() || '***',
      };
    }).filter((word) => word.word);

    await sensitiveWordApi.batchImport({ words });
    Message.success(`成功导入 ${words.length} 个敏感词`);
    importVisible.value = false;
    loadData();
  } catch (error) {
    Message.error('导入失败');
    console.error('导入失败:', error);
  }
};

// 取消导入
const handleImportCancel = () => {
  importVisible.value = false;
};

// 导出
const handleExport = async () => {
  try {
    const blob = await sensitiveWordApi.export(queryParams);
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `sensitive-words-${dayjs().format('YYYY-MM-DD')}.csv`;
    a.click();
    window.URL.revokeObjectURL(url);
    Message.success('导出成功');
  } catch (error) {
    Message.error('导出失败');
    console.error('导出失败:', error);
  }
};

// 获取分类颜色
const getCategoryColor = (category: string) => {
  const colors: Record<string, string> = {
    political: 'red',
    porn: 'magenta',
    violence: 'orange',
    ad: 'blue',
    abuse: 'cyan',
    general: 'gray',
  };
  return colors[category] || 'gray';
};

// 获取分类文本
const getCategoryText = (category: string) => {
  const texts: Record<string, string> = {
    political: '政治',
    porn: '色情',
    violence: '暴力',
    ad: '广告',
    abuse: '辱骂',
    general: '通用',
  };
  return texts[category] || category;
};

// 获取等级颜色
const getLevelColor = (level: number) => {
  if (level >= 3) return 'red';
  if (level >= 2) return 'orange';
  return 'blue';
};

// 获取等级文本
const getLevelText = (level: number) => {
  const texts: Record<number, string> = {
    1: '低危',
    2: '中危',
    3: '高危',
  };
  return texts[level] || `等级${level}`;
};

// 获取处理方式文本
const getActionText = (action: string) => {
  const texts: Record<string, string> = {
    replace: '替换',
    block: '拦截',
    review: '人工审核',
  };
  return texts[action] || action;
};

// 格式化日期时间
const formatDateTime = (dateTime: string) => {
  return dayjs(dateTime).format('YYYY-MM-DD HH:mm:ss');
};

// 初始化
onMounted(() => {
  loadData();
});
</script>

<style scoped lang="scss">
.sensitive-words {
  .action-bar {
    margin-bottom: 16px;
  }

  .filter-form {
    margin-bottom: 16px;
  }
}
</style>

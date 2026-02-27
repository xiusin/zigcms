<template>
  <div class="tag-management-container">
    <!-- 页面头部 -->
    <div class="page-header">
      <div class="header-left">
        <h2 class="page-title">标签管理</h2>
        <a-tag color="arcoblue" class="count-tag">
          共 {{ tagList.length }} 个标签
        </a-tag>
      </div>
      <div class="header-right">
        <!-- 【权限控制】仅管理员可创建标签 -->
        <a-button v-if="canManageTags" type="primary" @click="handleCreate">
          <template #icon><icon-plus /></template>
          新建标签
        </a-button>
      </div>
    </div>

    <!-- 【权限控制】权限检查：仅管理员可访问 -->
    <template v-if="canManageTags">
      <!-- 空状态 -->
      <a-empty v-if="!loading && tagList.length === 0" description="暂无标签">
        <a-button type="primary" @click="handleCreate">创建标签</a-button>
      </a-empty>

      <!-- 标签卡片网格 -->
      <a-row v-else :gutter="[16, 16]" class="tag-grid">
        <a-col
          v-for="tag in tagList"
          :key="tag.id"
          :xs="24"
          :sm="12"
          :md="8"
          :lg="6"
          :xl="6"
        >
          <a-card
            class="tag-card"
            hoverable
            @click="handleCardClick(tag)"
          >
            <div class="tag-card-content">
              <!-- 标签颜色块 -->
              <div
                class="tag-color-block"
                :style="{ backgroundColor: tag.color }"
              >
                <span class="tag-initial">{{ tag.name.charAt(0) }}</span>
              </div>

              <!-- 标签信息 -->
              <div class="tag-info">
                <div class="tag-name-row">
                  <span class="tag-name">{{ tag.name }}</span>
                  <a-tag size="small" class="usage-count">
                    {{ tag.usage_count || 0 }} 个反馈
                  </a-tag>
                </div>
                <p class="tag-description">{{ tag.description || '暂无描述' }}</p>
                <p class="tag-time">创建于 {{ formatDate(tag.created_at) }}</p>
              </div>

              <!-- 【权限控制】操作按钮 - 仅管理员可见 -->
              <div v-if="canManageTags" class="tag-actions">
                <a-space>
                  <a-button
                    type="text"
                    size="small"
                    @click.stop="handleEdit(tag)"
                  >
                    <template #icon><icon-edit /></template>
                    编辑
                  </a-button>
                  <a-button
                    type="text"
                    size="small"
                    status="danger"
                    @click.stop="handleDelete(tag)"
                  >
                    <template #icon><icon-delete /></template>
                    删除
                  </a-button>
                </a-space>
              </div>
            </div>
          </a-card>
        </a-col>
      </a-row>

      <!-- 加载状态 -->
      <div v-if="loading" class="loading-wrapper">
        <a-spin size="large" tip="加载中..." />
      </div>
    </template>

    <!-- 【权限控制】无权限提示 -->
    <a-result
      v-else
      status="403"
      title="无权限访问"
      subtitle="仅管理员可访问标签管理页面"
    >
      <template #extra>
        <a-button type="primary" @click="$router.back()">返回</a-button>
        <a-button @click="goToFeedbackList">返回反馈列表</a-button>
      </template>
    </a-result>

    <!-- 【权限控制】新建/编辑标签弹窗 - 仅管理员可见 -->
    <a-modal
      v-if="canManageTags"
      v-model:visible="modalVisible"
      :title="isEditing ? '编辑标签' : '新建标签'"
      :width="480"
      :mask-closable="false"
      :ok-loading="submitLoading"
      @ok="handleModalOk"
      @cancel="handleModalCancel"
    >
      <a-form
        ref="formRef"
        :model="formData"
        :rules="formRules"
        layout="vertical"
      >
        <a-form-item field="name" label="标签名称" required>
          <a-input
            v-model="formData.name"
            placeholder="请输入标签名称"
            allow-clear
            :max-length="20"
            show-word-limit
          />
        </a-form-item>

        <a-form-item field="color" label="标签颜色" required>
          <div class="color-picker-wrapper">
            <!-- 预设颜色 -->
            <div class="preset-colors">
              <div
                v-for="color in presetColors"
                :key="color"
                class="color-item"
                :class="{ active: formData.color === color }"
                :style="{ backgroundColor: color }"
                @click="formData.color = color"
              />
            </div>
            <!-- 自定义颜色 -->
            <div class="custom-color">
              <span class="color-label">自定义:</span>
              <a-input
                v-model="formData.color"
                placeholder="#165DFF"
                style="width: 120px"
              />
              <input
                v-model="formData.color"
                type="color"
                class="color-input"
              />
            </div>
          </div>
        </a-form-item>

        <a-form-item field="description" label="标签描述">
          <a-textarea
            v-model="formData.description"
            placeholder="请输入标签描述（可选）"
            :max-length="100"
            show-word-limit
            :auto-size="{ minRows: 2, maxRows: 4 }"
          />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 【权限控制】删除确认弹窗 - 仅管理员可见 -->
    <a-modal
      v-if="canManageTags"
      v-model:visible="deleteModalVisible"
      title="确认删除"
      :width="400"
      :mask-closable="false"
      @ok="handleDeleteConfirm"
      @cancel="deleteModalVisible = false"
    >
      <a-space direction="vertical" fill>
        <p>确定要删除标签 "{{ deletingTag?.name }}" 吗？</p>
        <a-alert
          v-if="deletingTag?.usage_count && deletingTag.usage_count > 0"
          type="warning"
          :content="`该标签已关联 ${deletingTag.usage_count} 个反馈，删除前请先移除关联`"
        />
      </a-space>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { Message, Modal } from '@arco-design/web-vue';
import {
  IconPlus,
  IconEdit,
  IconDelete,
} from '@arco-design/web-vue/es/icon';
import {
  getTagList,
  createTag,
  updateTag,
  deleteTag,
} from '@/api/feedback';
import type { Tag, CreateTagParams, UpdateTagParams } from '@/api/feedback';
import type { HttpResponse } from '@/api/request';
// 【权限控制】导入权限检查工具
import { useFeedbackPermission, canManageTags } from '../utils/permission';
import { FeedbackPermissions } from '../constants/permissions';

const router = useRouter();

// 【权限控制】使用权限检查组合式函数
const { hasPermission: checkPermission } = useFeedbackPermission();

// ========== 权限控制 ==========

/** 是否有管理标签权限 */
const canManageTags = computed(() => checkPermission(FeedbackPermissions.TAG_MANAGE).value);

// ========== 状态定义 ==========

/** 加载状态 */
const loading = ref(false);

/** 标签列表 */
const tagList = ref<Tag[]>([]);

/** 弹窗可见性 */
const modalVisible = ref(false);

/** 删除弹窗可见性 */
const deleteModalVisible = ref(false);

/** 提交加载状态 */
const submitLoading = ref(false);

/** 是否编辑模式 */
const isEditing = ref(false);

/** 当前编辑的标签ID */
const editingTagId = ref<number | null>(null);

/** 正在删除的标签 */
const deletingTag = ref<Tag | null>(null);

/** 表单引用 */
const formRef = ref<any>(null);

/** 表单数据 */
const formData = reactive<CreateTagParams>({
  name: '',
  color: '#165DFF',
  description: '',
});

/** 预设颜色列表 */
const presetColors = [
  '#165DFF', // 蓝色
  '#00B42A', // 绿色
  '#FF7D00', // 橙色
  '#F53F3F', // 红色
  '#FADC19', // 黄色
  '#722ED1', // 紫色
  '#14C9C9', // 青色
  '#F77234', // 珊瑚色
  '#86909C', // 灰色
  '#EB0AA4', // 粉色
];

/** 表单验证规则 */
const formRules = {
  name: [
    { required: true, message: '请输入标签名称' },
    { maxLength: 20, message: '标签名称最多20个字符' },
    {
      validator: (value: string, callback: (error?: string) => void) => {
        if (!value || value.trim() === '') {
          callback('标签名称不能为空');
          return;
        }
        // 检查名称唯一性（排除当前编辑的标签）
        const isDuplicate = tagList.value.some(
          (tag) =>
            tag.name.toLowerCase() === value.trim().toLowerCase() &&
            tag.id !== editingTagId.value
        );
        if (isDuplicate) {
          callback('标签名称已存在');
          return;
        }
        callback();
      },
    },
  ],
  color: [{ required: true, message: '请选择标签颜色' }],
};

// ========== 方法定义 ==========

/** 加载标签列表 */
const loadTagList = async () => {
  // 【权限控制】检查权限
  if (!canManageTags.value) {
    return;
  }

  loading.value = true;
  try {
    const res: HttpResponse = await getTagList({
      page: 1,
      pageSize: 100,
    });
    if (res.code === 0) {
      tagList.value = res.data.list || [];
    } else {
      Message.error(res.msg || '加载标签列表失败');
    }
  } catch (error) {
    console.error('加载标签列表失败:', error);
    Message.error('加载标签列表失败');
  } finally {
    loading.value = false;
  }
};

/** 格式化日期 */
const formatDate = (dateStr: string): string => {
  if (!dateStr) return '';
  const date = new Date(dateStr);
  return date.toLocaleDateString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
};

/** 新建标签 */
const handleCreate = () => {
  // 【权限控制】检查权限
  if (!canManageTags.value) {
    Message.error('您没有创建标签的权限');
    return;
  }

  isEditing.value = false;
  editingTagId.value = null;
  formData.name = '';
  formData.color = '#165DFF';
  formData.description = '';
  modalVisible.value = true;
};

/** 编辑标签 */
const handleEdit = (tag: Tag) => {
  // 【权限控制】检查权限
  if (!canManageTags.value) {
    Message.error('您没有编辑标签的权限');
    return;
  }

  isEditing.value = true;
  editingTagId.value = tag.id;
  formData.name = tag.name;
  formData.color = tag.color;
  formData.description = tag.description || '';
  modalVisible.value = true;
};

/** 删除标签 */
const handleDelete = (tag: Tag) => {
  // 【权限控制】检查权限
  if (!canManageTags.value) {
    Message.error('您没有删除标签的权限');
    return;
  }

  deletingTag.value = tag;
  deleteModalVisible.value = true;
};

/** 确认删除 */
const handleDeleteConfirm = async () => {
  // 【权限控制】检查权限
  if (!canManageTags.value) {
    Message.error('您没有删除标签的权限');
    return;
  }

  if (!deletingTag.value) return;

  // 如果有关联反馈，阻止删除
  if (deletingTag.value.usage_count && deletingTag.value.usage_count > 0) {
    Message.warning('该标签有关联反馈，请先移除关联后再删除');
    deleteModalVisible.value = false;
    return;
  }

  try {
    const res: HttpResponse = await deleteTag(deletingTag.value.id);
    if (res.code === 0) {
      Message.success('删除成功');
      loadTagList();
    } else {
      Message.error(res.msg || '删除失败');
    }
  } catch (error) {
    console.error('删除标签失败:', error);
    Message.error('删除失败');
  } finally {
    deleteModalVisible.value = false;
    deletingTag.value = null;
  }
};

/** 点击卡片 - 跳转到反馈列表并筛选 */
const handleCardClick = (tag: Tag) => {
  router.push({
    path: '/feedback/list',
    query: { tag_id: tag.id.toString() },
  });
};

/** 返回反馈列表 */
const goToFeedbackList = () => {
  router.push('/feedback/list');
};

/** 弹窗确认 */
const handleModalOk = async () => {
  // 【权限控制】检查权限
  if (!canManageTags.value) {
    Message.error('您没有管理标签的权限');
    return;
  }

  const valid = await formRef.value?.validate();
  if (valid) return;

  submitLoading.value = true;
  try {
    let res: HttpResponse;

    if (isEditing.value && editingTagId.value) {
      // 更新标签
      const params: UpdateTagParams = {
        id: editingTagId.value,
        name: formData.name.trim(),
        color: formData.color,
        description: formData.description?.trim(),
      };
      res = await updateTag(params);
    } else {
      // 创建标签
      const params: CreateTagParams = {
        name: formData.name.trim(),
        color: formData.color,
        description: formData.description?.trim(),
      };
      res = await createTag(params);
    }

    if (res.code === 0) {
      Message.success(isEditing.value ? '更新成功' : '创建成功');
      modalVisible.value = false;
      loadTagList();
    } else {
      Message.error(res.msg || (isEditing.value ? '更新失败' : '创建失败'));
    }
  } catch (error) {
    console.error(isEditing.value ? '更新标签失败:' : '创建标签失败:', error);
    Message.error(isEditing.value ? '更新失败' : '创建失败');
  } finally {
    submitLoading.value = false;
  }
};

/** 弹窗取消 */
const handleModalCancel = () => {
  modalVisible.value = false;
  formRef.value?.resetFields();
};

// ========== 生命周期 ==========

onMounted(() => {
  loadTagList();
});
</script>

<style scoped lang="less">
.tag-management-container {
  padding: 20px;
  background: var(--color-fill-2);
  min-height: calc(100vh - 60px);

  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;

    .header-left {
      display: flex;
      align-items: center;
      gap: 12px;

      .page-title {
        margin: 0;
        font-size: 20px;
        font-weight: 500;
        color: var(--color-text-1);
      }

      .count-tag {
        font-size: 12px;
      }
    }
  }

  .tag-grid {
    margin-bottom: 20px;
  }

  .tag-card {
    cursor: pointer;
    transition: all 0.3s ease;

    &:hover {
      transform: translateY(-2px);
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
    }

    :deep(.arco-card-body) {
      padding: 16px;
    }

    .tag-card-content {
      display: flex;
      flex-direction: column;
      gap: 12px;

      .tag-color-block {
        width: 48px;
        height: 48px;
        border-radius: 8px;
        display: flex;
        align-items: center;
        justify-content: center;
        flex-shrink: 0;

        .tag-initial {
          font-size: 20px;
          font-weight: 600;
          color: #fff;
          text-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
        }
      }

      .tag-info {
        flex: 1;
        min-width: 0;

        .tag-name-row {
          display: flex;
          align-items: center;
          gap: 8px;
          margin-bottom: 8px;

          .tag-name {
            font-size: 16px;
            font-weight: 500;
            color: var(--color-text-1);
          }

          .usage-count {
            font-size: 12px;
          }
        }

        .tag-description {
          margin: 0 0 8px;
          font-size: 13px;
          color: var(--color-text-2);
          line-height: 1.5;
          display: -webkit-box;
          -webkit-line-clamp: 2;
          -webkit-box-orient: vertical;
          overflow: hidden;
        }

        .tag-time {
          margin: 0;
          font-size: 12px;
          color: var(--color-text-3);
        }
      }

      .tag-actions {
        display: flex;
        justify-content: flex-end;
        padding-top: 12px;
        border-top: 1px solid var(--color-border-2);
      }
    }
  }

  .loading-wrapper {
    display: flex;
    justify-content: center;
    align-items: center;
    padding: 40px;
  }
}

// 颜色选择器样式
.color-picker-wrapper {
  display: flex;
  flex-direction: column;
  gap: 12px;

  .preset-colors {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;

    .color-item {
      width: 28px;
      height: 28px;
      border-radius: 4px;
      cursor: pointer;
      transition: all 0.2s ease;
      border: 2px solid transparent;

      &:hover {
        transform: scale(1.1);
      }

      &.active {
        border-color: var(--color-primary);
        box-shadow: 0 0 0 2px var(--color-primary-light-1);
      }
    }
  }

  .custom-color {
    display: flex;
    align-items: center;
    gap: 8px;

    .color-label {
      font-size: 13px;
      color: var(--color-text-2);
    }

    .color-input {
      width: 32px;
      height: 32px;
      padding: 0;
      border: none;
      border-radius: 4px;
      cursor: pointer;
      background: none;

      &::-webkit-color-swatch-wrapper {
        padding: 0;
      }

      &::-webkit-color-swatch {
        border: 1px solid var(--color-border-2);
        border-radius: 4px;
      }
    }
  }
}
</style>

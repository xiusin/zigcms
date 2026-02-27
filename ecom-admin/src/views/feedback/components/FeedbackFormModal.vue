<template>
  <a-modal
    :visible="visible"
    :width="800"
    :mask-closable="false"
    :esc-to-close="false"
    :ok-loading="submitLoading"
    @ok="handleSubmit"
    @cancel="handleCancel"
  >
    <template #title>
      <div class="modal-title">
        <span>{{ modalTitle }}</span>
        <a-tag v-if="isEdit && formData.id" color="arcoblue" size="small">
          #{{ formData.id }}
        </a-tag>
      </div>
    </template>

    <a-form
      ref="formRef"
      :model="formData"
      :rules="formRules"
      layout="vertical"
      class="feedback-form"
    >
      <!-- 标题 -->
      <a-form-item field="title" label="标题" required>
        <a-input
          v-model="formData.title"
          placeholder="请输入反馈标题"
          :max-length="200"
          show-word-limit
        />
      </a-form-item>

      <!-- 类型和优先级 -->
      <a-row :gutter="16">
        <a-col :span="12">
          <a-form-item field="type" label="类型" required>
            <a-select
              v-model="formData.type"
              placeholder="请选择反馈类型"
              allow-clear
            >
              <a-option
                v-for="item in typeOptions"
                :key="item.value"
                :value="item.value"
              >
                {{ item.label }}
              </a-option>
            </a-select>
          </a-form-item>
        </a-col>
        <a-col :span="12">
          <a-form-item field="priority" label="优先级" required>
            <a-select
              v-model="formData.priority"
              placeholder="请选择优先级"
              allow-clear
            >
              <a-option
                v-for="item in priorityOptions"
                :key="item.value"
                :value="item.value"
              >
                <a-space>
                  <a-badge :color="item.color" />
                  {{ item.label }}
                </a-space>
              </a-option>
            </a-select>
          </a-form-item>
        </a-col>
      </a-row>

      <!-- 描述 -->
      <a-form-item field="content" label="描述" required>
        <div class="editor-wrapper">
          <Toolbar
            :editor="editorRef"
            :default-config="toolbarConfig"
            mode="default"
            class="editor-toolbar"
          />
          <Editor
            v-model="formData.content"
            :default-config="editorConfig"
            mode="default"
            class="editor-content"
            @on-created="handleEditorCreated"
          />
        </div>
      </a-form-item>

      <!-- 标签 -->
      <a-form-item field="tag_ids" label="标签">
        <a-select
          v-model="formData.tag_ids"
          placeholder="请选择或创建标签"
          multiple
          allow-clear
          allow-create
          :max-tag-count="3"
          @search="handleTagSearch"
        >
          <a-option
            v-for="item in tagOptions"
            :key="item.id"
            :value="item.id"
          >
            <a-space>
              <a-badge :color="item.color" />
              {{ item.name }}
            </a-space>
          </a-option>
        </a-select>
      </a-form-item>

      <!-- 附件 -->
      <a-form-item field="attachments" label="附件">
        <a-upload
          v-model:file-list="fileList"
          action="/api/uploadFile"
          :headers="uploadHeaders"
          multiple
          :limit="10"
          accept=".jpg,.jpeg,.png,.gif,.pdf,.doc,.docx,.xls,.xlsx,.zip,.rar"
          @success="handleUploadSuccess"
          @error="handleUploadError"
          @before-remove="handleBeforeRemove"
        >
          <template #upload-button>
            <a-button type="dashed">
              <template #icon>
                <icon-upload />
              </template>
              上传附件
            </a-button>
          </template>
        </a-upload>
      </a-form-item>

      <!-- 指派（仅编辑模式） -->
      <a-form-item v-if="isEdit" field="handler_id" label="指派给">
        <a-select
          v-model="formData.handler_id"
          placeholder="请选择处理人"
          allow-clear
          allow-search
          :loading="userLoading"
          @search="handleUserSearch"
        >
          <a-option
            v-for="item in userOptions"
            :key="item.id"
            :value="item.id"
          >
            <a-space>
              <a-avatar :size="24" :src="item.avatar">
                <icon-user v-if="!item.avatar" />
              </a-avatar>
              {{ item.name }}
            </a-space>
          </a-option>
        </a-select>
      </a-form-item>
    </a-form>

    <template #footer>
      <a-space>
        <a-button @click="handleCancel">取消</a-button>
        <a-button type="secondary" :loading="draftLoading" @click="handleSaveDraft">
          保存草稿
        </a-button>
        <a-button type="primary" :loading="submitLoading" @click="handleSubmit">
          {{ isEdit ? '保存' : '提交' }}
        </a-button>
      </a-space>
    </template>
  </a-modal>
</template>

<script lang="ts" setup>
import { ref, reactive, computed, watch, onBeforeUnmount } from 'vue';
import { Message, type FormInstance, type FileItem } from '@arco-design/web-vue';
import { IconUpload, IconUser } from '@arco-design/web-vue/es/icon';
import { Editor, Toolbar } from '@wangeditor/editor-for-vue';
import type { IDomEditor, IEditorConfig, IToolbarConfig } from '@wangeditor/editor';
import '@wangeditor/editor/dist/css/style.css';
import {
  createFeedback,
  updateFeedback,
  getTagList,
  type CreateFeedbackParams,
  type UpdateFeedbackParams,
  type Tag,
  FeedbackType,
  FeedbackPriority,
} from '@/api/feedback';
import { getToken } from '@/utils/auth';
import request from '@/api/request';

// ========== 类型定义 ==========

interface Props {
  visible: boolean;
  mode: 'create' | 'edit';
  feedbackData?: Partial<FeedbackFormData>;
}

interface FeedbackFormData {
  id?: number;
  title: string;
  content: string;
  type: number | undefined;
  priority: number | undefined;
  tag_ids: number[];
  attachments: string[];
  handler_id?: number;
}

interface UserOption {
  id: number;
  name: string;
  avatar?: string;
}

// ========== Props & Emits ==========

const props = withDefaults(defineProps<Props>(), {
  visible: false,
  mode: 'create',
  feedbackData: () => ({}),
});

const emit = defineEmits<{
  'update:visible': [value: boolean];
  submit: [data: FeedbackFormData];
  cancel: [];
}>();

// ========== 响应式数据 ==========

const formRef = ref<FormInstance>();
const submitLoading = ref(false);
const draftLoading = ref(false);
const userLoading = ref(false);
const editorRef = ref<IDomEditor | null>(null);
const fileList = ref<FileItem[]>([]);
const tagOptions = ref<Tag[]>([]);
const userOptions = ref<UserOption[]>([]);

// 表单数据
const formData = reactive<FeedbackFormData>({
  title: '',
  content: '',
  type: undefined,
  priority: undefined,
  tag_ids: [],
  attachments: [],
  handler_id: undefined,
});

// ========== 计算属性 ==========

const isEdit = computed(() => props.mode === 'edit');

const modalTitle = computed(() => (isEdit.value ? '编辑反馈' : '创建反馈'));

const uploadHeaders = computed(() => ({
  Authorization: getToken(),
}));

// 反馈类型选项
const typeOptions = [
  { label: '功能建议', value: FeedbackType.FEATURE },
  { label: 'Bug报告', value: FeedbackType.BUG },
  { label: '性能优化', value: FeedbackType.PERFORMANCE },
  { label: 'UI/UX改进', value: FeedbackType.UX },
  { label: '文档改进', value: FeedbackType.OTHER },
  { label: '安全问题', value: FeedbackType.OTHER },
];

// 优先级选项
const priorityOptions = [
  { label: '紧急', value: FeedbackPriority.URGENT, color: '#f53f3f' },
  { label: '高', value: FeedbackPriority.HIGH, color: '#ff7d00' },
  { label: '中', value: FeedbackPriority.MEDIUM, color: '#ffb800' },
  { label: '低', value: FeedbackPriority.LOW, color: '#00b42a' },
];

// 表单验证规则
const formRules = {
  title: [
    { required: true, message: '请输入反馈标题' },
    { minLength: 2, message: '标题至少2个字符' },
    { maxLength: 200, message: '标题最多200个字符' },
  ],
  type: [{ required: true, message: '请选择反馈类型' }],
  priority: [{ required: true, message: '请选择优先级' }],
  content: [
    { required: true, message: '请输入反馈描述' },
    {
      validator: (value: string) => {
        const text = value?.replace(/<[^>]*>/g, '').trim();
        return text?.length >= 10;
      },
      message: '描述至少10个字符',
    },
  ],
};

// 编辑器配置
const toolbarConfig: Partial<IToolbarConfig> = {
  excludeKeys: ['fullScreen'],
};

const editorConfig: Partial<IEditorConfig> = {
  placeholder: '请输入反馈描述，支持 Markdown 语法...',
  MENU_CONF: {
    uploadImage: {
      server: '/api/uploadFile',
      headers: {
        Authorization: getToken(),
      },
      fieldName: 'file',
      customInsert(res: any, insertFn: any) {
        if (res.code === 200) {
          insertFn(res.data.url, res.data.alt || '', res.data.href || res.data.url);
        } else {
          Message.error(res.msg || '图片上传失败');
        }
      },
    },
    uploadVideo: {
      server: '/api/uploadFile',
      headers: {
        Authorization: getToken(),
      },
      fieldName: 'file',
    },
  },
};

// ========== 方法 ==========

// 编辑器创建完成
const handleEditorCreated = (editor: IDomEditor) => {
  editorRef.value = editor;
};

// 获取标签列表
const fetchTagList = async (keyword?: string) => {
  try {
    const res = await getTagList({
      keyword,
      page: 1,
      pageSize: 50,
    });
    if (res.code === 200) {
      tagOptions.value = res.data?.list || [];
    }
  } catch (error) {
    console.error('获取标签列表失败:', error);
  }
};

// 搜索标签
const handleTagSearch = (keyword: string) => {
  fetchTagList(keyword);
};

// 搜索用户
const handleUserSearch = async (keyword: string) => {
  userLoading.value = true;
  try {
    const res = await request('/api/user/search', { keyword });
    if (res.code === 200) {
      userOptions.value = res.data?.list || [];
    }
  } catch (error) {
    console.error('搜索用户失败:', error);
  } finally {
    userLoading.value = false;
  }
};

// 上传成功
const handleUploadSuccess = (fileItem: FileItem) => {
  if (fileItem.response?.code === 200) {
    const url = fileItem.response.data?.url;
    if (url && !formData.attachments.includes(url)) {
      formData.attachments.push(url);
    }
    Message.success('上传成功');
  } else {
    Message.error(fileItem.response?.msg || '上传失败');
  }
};

// 上传失败
const handleUploadError = (fileItem: FileItem) => {
  Message.error(fileItem.response?.msg || '上传失败，请重试');
};

// 删除前确认
const handleBeforeRemove = (file: FileItem) => {
  return new Promise<boolean>((resolve) => {
    if (file.status === 'done' && file.response?.data?.url) {
      const url = file.response.data.url;
      const index = formData.attachments.indexOf(url);
      if (index > -1) {
        formData.attachments.splice(index, 1);
      }
    }
    resolve(true);
  });
};

// 重置表单
const resetForm = () => {
  formData.title = '';
  formData.content = '';
  formData.type = undefined;
  formData.priority = undefined;
  formData.tag_ids = [];
  formData.attachments = [];
  formData.handler_id = undefined;
  formData.id = undefined;
  fileList.value = [];
  formRef.value?.resetFields();
};

// 填充表单数据
const fillFormData = (data: Partial<FeedbackFormData>) => {
  if (data.id) formData.id = data.id;
  if (data.title) formData.title = data.title;
  if (data.content) formData.content = data.content;
  if (data.type !== undefined) formData.type = data.type;
  if (data.priority !== undefined) formData.priority = data.priority;
  if (data.tag_ids) formData.tag_ids = data.tag_ids;
  if (data.attachments) {
    formData.attachments = data.attachments;
    // 转换附件为文件列表
    fileList.value = data.attachments.map((url, index) => ({
      uid: String(index),
      name: url.split('/').pop() || `附件${index + 1}`,
      url,
      status: 'done',
    }));
  }
  if (data.handler_id) formData.handler_id = data.handler_id;
};

// 保存草稿
const handleSaveDraft = async () => {
  const valid = await formRef.value?.validate();
  if (valid) return;

  draftLoading.value = true;
  try {
    const params: CreateFeedbackParams = {
      title: formData.title,
      content: formData.content,
      type: formData.type as number,
      priority: formData.priority,
      tag_ids: formData.tag_ids,
      attachments: formData.attachments,
    };

    const res = await createFeedback(params);
    if (res.code === 200) {
      Message.success('草稿保存成功');
      emit('submit', { ...formData });
      handleClose();
    }
  } catch (error) {
    console.error('保存草稿失败:', error);
  } finally {
    draftLoading.value = false;
  }
};

// 提交表单
const handleSubmit = async () => {
  const valid = await formRef.value?.validate();
  if (valid) return;

  submitLoading.value = true;
  try {
    let res;
    if (isEdit.value && formData.id) {
      // 编辑模式
      const params: UpdateFeedbackParams = {
        id: formData.id,
        title: formData.title,
        content: formData.content,
        type: formData.type,
        priority: formData.priority,
        tag_ids: formData.tag_ids,
        attachments: formData.attachments,
      };
      if (formData.handler_id !== undefined) {
        params.handler_id = formData.handler_id;
      }
      res = await updateFeedback(params);
    } else {
      // 创建模式
      const params: CreateFeedbackParams = {
        title: formData.title,
        content: formData.content,
        type: formData.type as number,
        priority: formData.priority,
        tag_ids: formData.tag_ids,
        attachments: formData.attachments,
      };
      res = await createFeedback(params);
    }

    if (res.code === 200) {
      Message.success(isEdit.value ? '更新成功' : '创建成功');
      emit('submit', { ...formData });
      handleClose();
    }
  } catch (error) {
    console.error(isEdit.value ? '更新失败:' : '创建失败:', error);
  } finally {
    submitLoading.value = false;
  }
};

// 取消
const handleCancel = () => {
  emit('cancel');
  handleClose();
};

// 关闭弹窗
const handleClose = () => {
  emit('update:visible', false);
  resetForm();
};

// ========== 监听器 ==========

// 监听 visible 变化
watch(
  () => props.visible,
  (val) => {
    if (val) {
      fetchTagList();
      if (isEdit.value && props.feedbackData) {
        fillFormData(props.feedbackData);
      } else {
        resetForm();
      }
    }
  },
  { immediate: true }
);

// 监听 feedbackData 变化
watch(
  () => props.feedbackData,
  (val) => {
    if (isEdit.value && val && props.visible) {
      fillFormData(val);
    }
  },
  { deep: true }
);

// 组件卸载前销毁编辑器
onBeforeUnmount(() => {
  if (editorRef.value) {
    editorRef.value.destroy();
    editorRef.value = null;
  }
});
</script>

<style lang="less" scoped>
.modal-title {
  display: flex;
  align-items: center;
  gap: 8px;
}

.feedback-form {
  :deep(.arco-form-item) {
    margin-bottom: 20px;
  }
}

.editor-wrapper {
  border: 1px solid var(--color-border-2);
  border-radius: 4px;
  overflow: hidden;

  .editor-toolbar {
    border-bottom: 1px solid var(--color-border-2);
  }

  .editor-content {
    min-height: 200px;
    max-height: 400px;
    overflow-y: auto;
  }
}

:deep(.w-e-text-container) {
  min-height: 200px !important;
}
</style>

<template>
  <a-modal
    :visible="visible"
    :title="modalTitle"
    :width="600"
    :mask-closable="false"
    :unmount-on-close="true"
    @cancel="handleCancel"
    @before-ok="handleBeforeOk"
    @update:visible="(val) => emit('update:visible', val)"
  >
    <a-form
      ref="formRef"
      :model="formData"
      :rules="formRules"
      layout="vertical"
    >
      <a-form-item field="title" label="标题" required>
        <a-input
          v-model="formData.title"
          placeholder="请输入反馈标题"
          :max-length="100"
          show-word-limit
        />
      </a-form-item>

      <a-form-item field="content" label="内容" required>
        <a-textarea
          v-model="formData.content"
          placeholder="请详细描述您的反馈..."
          :rows="5"
          :max-length="2000"
          show-word-limit
        />
      </a-form-item>

      <a-row :gutter="16">
        <a-col :span="12">
          <a-form-item field="type" label="类型" required>
            <a-select v-model="formData.type" placeholder="请选择类型">
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
            <a-select v-model="formData.priority" placeholder="请选择优先级">
              <a-option
                v-for="item in priorityOptions"
                :key="item.value"
                :value="item.value"
              >
                <span :style="{ color: item.color }">●</span> {{ item.label }}
              </a-option>
            </a-select>
          </a-form-item>
        </a-col>
      </a-row>

      <a-form-item field="tag_ids" label="标签">
        <a-select
          v-model="formData.tag_ids"
          placeholder="请选择标签"
          multiple
          allow-clear
          :loading="tagLoading"
        >
          <a-option
            v-for="tag in tagList"
            :key="tag.id"
            :value="tag.id"
          >
            <span
              class="tag-dot"
              :style="{ backgroundColor: tag.color }"
            ></span>
            {{ tag.name }}
          </a-option>
        </a-select>
      </a-form-item>

      <a-form-item field="attachments" label="附件">
        <a-upload
          v-model:file-list="fileList"
          list-type="picture-card"
          action="/api/upload/image"
          :limit="5"
          accept="image/*"
          @success="handleUploadSuccess"
          @error="handleUploadError"
        />
      </a-form-item>
    </a-form>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { Message } from '@arco-design/web-vue';
import type { FormInstance } from '@arco-design/web-vue/es/form';
import type { FileItem } from '@arco-design/web-vue/es/upload';
import { useFeedbackStore } from '@/store/modules/feedback';
import type { CreateFeedbackParams, UpdateFeedbackParams, Feedback } from '@/api/feedback';
import {
  FeedbackType,
  FeedbackPriority,
} from '@/api/feedback';

/** Props 定义 */
interface Props {
  /** 弹窗可见性 */
  visible: boolean;
  /** 编辑的反馈 ID */
  feedbackId?: number;
}

const props = defineProps<Props>();

/** Emits 定义 */
const emit = defineEmits<{
  (e: 'update:visible', visible: boolean): void;
  (e: 'success'): void;
}>();

/** Store */
const feedbackStore = useFeedbackStore();

/** 表单引用 */
const formRef = ref<FormInstance>();

/** 表单数据 */
const formData = ref<{
  id?: number;
  title: string;
  content: string;
  type: number;
  priority: number;
  tag_ids: number[];
  attachments: string[];
}>({
  title: '',
  content: '',
  type: FeedbackType.FEATURE,
  priority: FeedbackPriority.MEDIUM,
  tag_ids: [],
  attachments: [],
});

/** 文件列表 */
const fileList = ref<FileItem[]>([]);

/** 标签加载状态 */
const tagLoading = ref(false);

/** 标签列表 */
const tagList = ref<Array<{ id: number; name: string; color: string }>>([]);

/** 弹窗标题 */
const modalTitle = computed(() => {
  return props.feedbackId ? '编辑反馈' : '新建反馈';
});

/** 类型选项 */
const typeOptions = [
  { value: FeedbackType.FEATURE, label: '功能建议' },
  { value: FeedbackType.BUG, label: 'Bug 反馈' },
  { value: FeedbackType.PERFORMANCE, label: '性能问题' },
  { value: FeedbackType.UX, label: '用户体验' },
  { value: FeedbackType.OTHER, label: '其他' },
];

/** 优先级选项 */
const priorityOptions = [
  { value: FeedbackPriority.URGENT, label: '紧急', color: '#f53f3f' },
  { value: FeedbackPriority.HIGH, label: '高', color: '#ff7d00' },
  { value: FeedbackPriority.MEDIUM, label: '中', color: '#fadc19' },
  { value: FeedbackPriority.LOW, label: '低', color: '#00b42a' },
];

/** 表单校验规则 */
const formRules = {
  title: [
    { required: true, message: '请输入标题' },
    { maxLength: 100, message: '标题长度不能超过100个字符' },
  ],
  content: [
    { required: true, message: '请输入内容' },
    { maxLength: 2000, message: '内容长度不能超过2000个字符' },
  ],
  type: [{ required: true, message: '请选择类型' }],
  priority: [{ required: true, message: '请选择优先级' }],
};

/** 加载标签列表 */
const loadTags = async () => {
  tagLoading.value = true;
  try {
    const res = await feedbackStore.fetchTagList();
    if (res.code === 0) {
      tagList.value = res.data.list || [];
    }
  } finally {
    tagLoading.value = false;
  }
};

/** 加载反馈详情 */
const loadFeedbackDetail = async () => {
  if (!props.feedbackId) return;

  try {
    const res = await feedbackStore.fetchFeedbackDetail(props.feedbackId);
    if (res.code === 0) {
      const feedback = res.data.feedback;
      formData.value = {
        id: feedback.id,
        title: feedback.title,
        content: feedback.content,
        type: feedback.type,
        priority: feedback.priority,
        tag_ids: feedback.tag_ids || [],
        attachments: feedback.attachments || [],
      };

      // 设置文件列表
      if (feedback.attachments) {
        fileList.value = feedback.attachments.map((url, index) => ({
          uid: String(index),
          name: `附件${index + 1}`,
          url,
          status: 'done',
        }));
      }
    }
  } catch (error) {
    Message.error('加载反馈详情失败');
  }
};

/** 处理上传成功 */
const handleUploadSuccess = (fileItem: FileItem) => {
  if (fileItem.response) {
    const url = fileItem.response.data?.url || fileItem.response.url;
    if (url) {
      formData.value.attachments.push(url);
    }
  }
};

/** 处理上传失败 */
const handleUploadError = (fileItem: FileItem) => {
  Message.error(`上传失败: ${fileItem.name}`);
};

/** 处理取消 */
const handleCancel = () => {
  emit('update:visible', false);
  resetForm();
};

/** 处理确认前 */
const handleBeforeOk = async (done: (closed: boolean) => void) => {
  const result = await formRef.value?.validate();
  if (result) {
    done(false);
    return;
  }

  try {
    if (props.feedbackId) {
      // 编辑模式
      const params: UpdateFeedbackParams = {
        id: props.feedbackId,
        title: formData.value.title,
        content: formData.value.content,
        type: formData.value.type,
        priority: formData.value.priority,
        tag_ids: formData.value.tag_ids,
        attachments: formData.value.attachments,
      };
      const res = await feedbackStore.updateFeedback(params);
      if (res.code === 0) {
        Message.success('更新成功');
        emit('success');
        done(true);
      } else {
        Message.error(res.msg || '更新失败');
        done(false);
      }
    } else {
      // 新建模式
      const params: CreateFeedbackParams = {
        title: formData.value.title,
        content: formData.value.content,
        type: formData.value.type,
        priority: formData.value.priority,
        tag_ids: formData.value.tag_ids,
        attachments: formData.value.attachments,
      };
      const res = await feedbackStore.createFeedback(params);
      if (res.code === 0) {
        Message.success('创建成功');
        emit('success');
        done(true);
      } else {
        Message.error(res.msg || '创建失败');
        done(false);
      }
    }
  } catch (error) {
    Message.error('操作失败');
    done(false);
  }
};

/** 重置表单 */
const resetForm = () => {
  formData.value = {
    title: '',
    content: '',
    type: FeedbackType.FEATURE,
    priority: FeedbackPriority.MEDIUM,
    tag_ids: [],
    attachments: [],
  };
  fileList.value = [];
  formRef.value?.resetFields();
};

/** 监听 visible 变化 */
watch(
  () => props.visible,
  (newVal) => {
    if (newVal) {
      loadTags();
      if (props.feedbackId) {
        loadFeedbackDetail();
      } else {
        resetForm();
      }
    }
  }
);
</script>

<style scoped lang="less">
.tag-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  margin-right: 6px;
}
</style>

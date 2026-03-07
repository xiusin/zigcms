<template>
  <div class="rich-text-editor">
    <div ref="editorRef" class="editor-container"></div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount, watch } from 'vue';
import Quill from 'quill';
import 'quill/dist/quill.snow.css';
import { Message } from '@arco-design/web-vue';

interface Props {
  modelValue: string;
  placeholder?: string;
  readonly?: boolean;
  height?: string;
}

interface Emits {
  (e: 'update:modelValue', value: string): void;
  (e: 'change', value: string): void;
}

const props = withDefaults(defineProps<Props>(), {
  placeholder: '请输入内容...',
  readonly: false,
  height: '300px',
});

const emit = defineEmits<Emits>();

const editorRef = ref<HTMLElement>();
let quill: Quill | null = null;

// 初始化编辑器
onMounted(() => {
  if (!editorRef.value) return;

  // 配置工具栏
  const toolbarOptions = [
    ['bold', 'italic', 'underline', 'strike'],
    ['blockquote', 'code-block'],
    [{ header: 1 }, { header: 2 }],
    [{ list: 'ordered' }, { list: 'bullet' }],
    [{ indent: '-1' }, { indent: '+1' }],
    [{ size: ['small', false, 'large', 'huge'] }],
    [{ header: [1, 2, 3, 4, 5, 6, false] }],
    [{ color: [] }, { background: [] }],
    [{ align: [] }],
    ['link', 'image'],
    ['clean'],
  ];

  // 创建编辑器实例
  quill = new Quill(editorRef.value, {
    theme: 'snow',
    placeholder: props.placeholder,
    readOnly: props.readonly,
    modules: {
      toolbar: toolbarOptions,
    },
  });

  // 设置初始内容
  if (props.modelValue) {
    quill.root.innerHTML = props.modelValue;
  }

  // 监听内容变化
  quill.on('text-change', () => {
    if (!quill) return;
    const html = quill.root.innerHTML;
    emit('update:modelValue', html);
    emit('change', html);
  });

  // 自定义图片上传
  const toolbar = quill.getModule('toolbar');
  toolbar.addHandler('image', handleImageUpload);

  // 设置编辑器高度
  if (editorRef.value) {
    const editor = editorRef.value.querySelector('.ql-editor') as HTMLElement;
    if (editor) {
      editor.style.minHeight = props.height;
    }
  }
});

// 监听外部值变化
watch(
  () => props.modelValue,
  (newValue) => {
    if (!quill) return;
    const currentValue = quill.root.innerHTML;
    if (newValue !== currentValue) {
      quill.root.innerHTML = newValue || '';
    }
  }
);

// 监听只读状态变化
watch(
  () => props.readonly,
  (newValue) => {
    if (!quill) return;
    quill.enable(!newValue);
  }
);

// 处理图片上传
const handleImageUpload = () => {
  const input = document.createElement('input');
  input.setAttribute('type', 'file');
  input.setAttribute('accept', 'image/*');
  input.click();

  input.onchange = async () => {
    const file = input.files?.[0];
    if (!file) return;

    // 验证文件大小（最大 5MB）
    if (file.size > 5 * 1024 * 1024) {
      Message.error('图片大小不能超过 5MB');
      return;
    }

    // 验证文件类型
    if (!file.type.startsWith('image/')) {
      Message.error('只能上传图片文件');
      return;
    }

    try {
      // 转换为 Base64（实际项目中应该上传到服务器）
      const reader = new FileReader();
      reader.onload = (e) => {
        const base64 = e.target?.result as string;
        insertImage(base64);
      };
      reader.readAsDataURL(file);
    } catch (error) {
      Message.error('图片上传失败');
      console.error(error);
    }
  };
};

// 插入图片
const insertImage = (url: string) => {
  if (!quill) return;
  const range = quill.getSelection();
  if (range) {
    quill.insertEmbed(range.index, 'image', url);
    quill.setSelection(range.index + 1, 0);
  }
};

// 清理
onBeforeUnmount(() => {
  if (quill) {
    quill = null;
  }
});


// 导出方法供外部使用
defineExpose({
  getContent: () => quill?.root.innerHTML || '',
  setContent: (html: string) => {
    if (quill) {
      quill.root.innerHTML = html;
    }
  },
  clear: () => {
    if (quill) {
      quill.setText('');
    }
  },
});
</script>

<style scoped lang="less">
.rich-text-editor {
  :deep(.ql-container) {
    font-size: 14px;
  }

  :deep(.ql-editor) {
    min-height: 300px;
    max-height: 600px;
    overflow-y: auto;

    p {
      margin: 0 0 8px 0;
    }

    img {
      max-width: 100%;
      border-radius: 4px;
    }
  }

  :deep(.ql-toolbar) {
    border-top-left-radius: 4px;
    border-top-right-radius: 4px;
  }

  :deep(.ql-container) {
    border-bottom-left-radius: 4px;
    border-bottom-right-radius: 4px;
  }
}
</style>

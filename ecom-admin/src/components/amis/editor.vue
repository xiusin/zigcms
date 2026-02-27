<template>
  <div class="amis-editor-container">
    <div class="editor-header">
      <a-space>
        <a-button type="primary" @click="handlePreview">
          <icon-eye /> 预览
        </a-button>
        <a-button @click="handleCopy"> <icon-copy /> 复制配置 </a-button>
        <a-button @click="handleExport"> <icon-download /> 导出JSON </a-button>
        <a-button type="secondary" @click="handleImport">
          <icon-upload /> 导入JSON
        </a-button>
      </a-space>
      <a-select
        v-model="theme"
        style="width: 120px"
        @change="handleThemeChange"
      >
        <a-option value="cxd">默认白</a-option>
        <a-option value="dark">暗黑</a-option>
        <a-option value="antd">AntD</a-option>
      </a-select>
    </div>

    <div class="editor-content">
      <div class="editor-panel">
        <div class="json-editor-wrapper">
          <div class="editor-toolbar">
            <a-button size="mini" @click="formatJson">格式化</a-button>
            <a-button size="mini" @click="compressJson">压缩</a-button>
            <a-button size="mini" @click="validateJson">校验</a-button>
          </div>
          <div class="editor-status">
            <span v-if="jsonValid" class="status-valid">✓ JSON 格式正确</span>
            <span v-else class="status-invalid">✗ JSON 格式错误</span>
            <span v-if="jsonError" class="error-msg">{{ jsonError }}</span>
          </div>
          <textarea
            ref="editorRef"
            v-model="jsonContent"
            class="json-editor"
            placeholder="请输入 amis JSON 配置..."
            @input="handleJsonChange"
          ></textarea>
        </div>
      </div>

      <a-modal
        v-model:visible="previewVisible"
        title="预览效果"
        :width="900"
        :footer="false"
      >
        <AmisRenderer
          :schema="previewSchema"
          :theme="theme"
          :theme-color="themeColor"
        />
      </a-modal>

      <a-modal
        v-model:visible="importVisible"
        title="导入JSON"
        @ok="handleImportConfirm"
      >
        <a-textarea
          v-model="importJson"
          :rows="15"
          placeholder="请粘贴JSON配置"
        />
      </a-modal>
    </div>
  </div>
</template>

<script setup lang="ts">
  import { ref, watch, computed } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import AmisRenderer from './index.vue';

  interface Props {
    /** 初始 schema */
    modelValue?: Record<string, any>;
  }

  const props = withDefaults(defineProps<Props>(), {
    modelValue: () => ({}),
  });

  const emit = defineEmits<{
    (e: 'update:modelValue', value: Record<string, any>): void;
    (e: 'change', value: Record<string, any>): void;
    (e: 'save', value: Record<string, any>): void;
  }>();

  const editorRef = ref<HTMLTextAreaElement | null>(null);
  const theme = ref('cxd');
  const themeColor = ref('#165DFF');
  const previewVisible = ref(false);
  const previewSchema = ref<Record<string, any>>({});
  const importVisible = ref(false);
  const importJson = ref('');
  const jsonContent = ref('');
  const jsonValid = ref(true);
  const jsonError = ref('');

  // 初始化 JSON 内容
  const initJson = () => {
    if (props.modelValue && Object.keys(props.modelValue).length > 0) {
      jsonContent.value = JSON.stringify(props.modelValue, null, 2);
    } else {
      jsonContent.value = JSON.stringify(
        {
          type: 'page',
          title: '新页面',
          body: 'Hello World',
        },
        null,
        2
      );
    }
  };

  // 解析 JSON
  const parseJson = (): Record<string, any> | null => {
    try {
      const result = JSON.parse(jsonContent.value);
      jsonValid.value = true;
      jsonError.value = '';
      return result;
    } catch (e: any) {
      jsonValid.value = false;
      jsonError.value = e.message;
      return null;
    }
  };

  // JSON 变化处理
  const handleJsonChange = () => {
    const schema = parseJson();
    if (schema) {
      emit('update:modelValue', schema);
      emit('change', schema);
    }
  };

  // 格式化 JSON
  const formatJson = () => {
    const schema = parseJson();
    if (schema) {
      jsonContent.value = JSON.stringify(schema, null, 2);
      Message.success('已格式化');
    } else {
      Message.error('JSON 格式错误，无法格式化');
    }
  };

  // 压缩 JSON
  const compressJson = () => {
    const schema = parseJson();
    if (schema) {
      jsonContent.value = JSON.stringify(schema);
      Message.success('已压缩');
    } else {
      Message.error('JSON 格式错误，无法压缩');
    }
  };

  // 校验 JSON
  const validateJson = () => {
    const schema = parseJson();
    if (schema) {
      Message.success('JSON 格式正确');
    } else {
      Message.error(`JSON 格式错误: ${jsonError.value}`);
    }
  };

  // 主题切换
  const handleThemeChange = () => {
    // 主题变化时重新渲染
  };

  // 预览
  const handlePreview = () => {
    const schema = parseJson();
    if (schema) {
      previewSchema.value = schema;
      previewVisible.value = true;
    } else {
      Message.error('请先修正 JSON 格式错误');
    }
  };

  // 复制配置
  const handleCopy = () => {
    const json = JSON.stringify(props.modelValue, null, 2);
    if (navigator.clipboard) {
      navigator.clipboard.writeText(json).then(() => {
        Message.success('配置已复制到剪贴板');
      });
    }
  };

  // 导出JSON
  const handleExport = () => {
    const json = JSON.stringify(props.modelValue, null, 2);
    const blob = new Blob([json], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'page-schema.json';
    a.click();
    URL.revokeObjectURL(url);
    Message.success('导出成功');
  };

  // 导入JSON
  const handleImport = () => {
    importJson.value = '';
    importVisible.value = true;
  };

  // 确认导入
  const handleImportConfirm = () => {
    try {
      const schema = JSON.parse(importJson.value);
      jsonContent.value = JSON.stringify(schema, null, 2);
      emit('update:modelValue', schema);
      emit('change', schema);
      importVisible.value = false;
      Message.success('导入成功');
    } catch (error) {
      Message.error('JSON格式不正确');
    }
  };

  // 监听 props 变化
  watch(
    () => props.modelValue,
    (newVal) => {
      if (newVal && Object.keys(newVal).length > 0) {
        jsonContent.value = JSON.stringify(newVal, null, 2);
      }
    },
    { immediate: true, deep: true }
  );

  initJson();

  defineExpose({
    /** 获取当前值 */
    getValue: () => props.modelValue,
    /** 设置值 */
    setValue: (value: Record<string, any>) => {
      jsonContent.value = JSON.stringify(value, null, 2);
      emit('update:modelValue', value);
    },
  });
</script>

<style scoped>
  .amis-editor-container {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: #fff;
  }

  .editor-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 16px;
    border-bottom: 1px solid #e5e6e8;
    background: #f7f8fa;
  }

  .editor-content {
    flex: 1;
    overflow: hidden;
  }

  .editor-panel {
    height: 100%;
    padding: 0;
  }

  .json-editor-wrapper {
    display: flex;
    flex-direction: column;
    height: 100%;
    padding: 0;
  }

  .editor-toolbar {
    padding: 8px 12px;
    border-bottom: 1px solid #e5e6e8;
    background: #fafafa;
  }

  .editor-status {
    padding: 4px 12px;
    font-size: 12px;
    border-bottom: 1px solid #e5e6e8;
    background: #fafafa;
  }

  .status-valid {
    color: #00b42a;
  }

  .status-invalid {
    color: #f53f3f;
  }

  .error-msg {
    margin-left: 12px;
    color: #f53f3f;
  }

  .json-editor {
    flex: 1;
    width: 100%;
    min-height: 500px;
    padding: 12px;
    border: none;
    resize: none;
    font-family: 'Monaco', 'Menlo', 'Ubuntu', 'Consolas', monospace;
    font-size: 13px;
    line-height: 1.5;
    background: #1e1e1e;
    color: #d4d4d4;
    outline: none;
  }

  .json-editor:focus {
    outline: none;
  }
</style>

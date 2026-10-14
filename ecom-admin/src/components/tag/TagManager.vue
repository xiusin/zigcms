<template>
  <div class="tag-manager">
    <div class="tag-list">
      <a-tag
        v-for="tag in tags"
        :key="tag"
        closable
        :color="getTagColor(tag)"
        @close="handleRemove(tag)"
      >
        {{ tag }}
      </a-tag>

      <a-input
        v-if="inputVisible"
        ref="inputRef"
        v-model="inputValue"
        size="small"
        style="width: 100px"
        @press-enter="handleInputConfirm"
        @blur="handleInputConfirm"
      />

      <a-button
        v-else
        size="small"
        type="dashed"
        @click="showInput"
      >
        <template #icon><icon-plus /></template>
        添加标签
      </a-button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, nextTick } from 'vue';
import { Message } from '@arco-design/web-vue';

interface Props {
  modelValue: string[];
  maxTags?: number;
}

interface Emits {
  (e: 'update:modelValue', tags: string[]): void;
  (e: 'change', tags: string[]): void;
}

const props = withDefaults(defineProps<Props>(), {
  maxTags: 10,
});

const emit = defineEmits<Emits>();

const tags = ref<string[]>(props.modelValue || []);
const inputVisible = ref(false);
const inputValue = ref('');
const inputRef = ref();

// 预定义标签颜色
const TAG_COLORS = [
  'blue',
  'green',
  'orange',
  'red',
  'purple',
  'cyan',
  'magenta',
  'gold',
];

// 获取标签颜色
const getTagColor = (tag: string): string => {
  const hash = tag.split('').reduce((acc, char) => {
    return char.charCodeAt(0) + ((acc << 5) - acc);
  }, 0);
  return TAG_COLORS[Math.abs(hash) % TAG_COLORS.length];
};

// 显示输入框
const showInput = () => {
  if (tags.value.length >= props.maxTags) {
    Message.warning(`最多只能添加 ${props.maxTags} 个标签`);
    return;
  }

  inputVisible.value = true;
  nextTick(() => {
    inputRef.value?.focus();
  });
};

// 确认输入
const handleInputConfirm = () => {
  const value = inputValue.value.trim();

  if (value) {
    // 验证标签是否已存在
    if (tags.value.includes(value)) {
      Message.warning('标签已存在');
    } else if (tags.value.length >= props.maxTags) {
      Message.warning(`最多只能添加 ${props.maxTags} 个标签`);
    } else {
      tags.value.push(value);
      emit('update:modelValue', tags.value);
      emit('change', tags.value);
    }
  }

  inputVisible.value = false;
  inputValue.value = '';
};

// 删除标签
const handleRemove = (tag: string) => {
  const index = tags.value.indexOf(tag);
  if (index > -1) {
    tags.value.splice(index, 1);
    emit('update:modelValue', tags.value);
    emit('change', tags.value);
  }
};
</script>

<style scoped lang="less">
.tag-manager {
  .tag-list {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    align-items: center;
  }
}
</style>

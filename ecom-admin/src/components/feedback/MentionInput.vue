<template>
  <div class="mention-input">
    <a-textarea
      ref="textareaRef"
      v-model="inputValue"
      :placeholder="placeholder"
      :auto-size="autoSize"
      :max-length="maxLength"
      :show-word-limit="showWordLimit"
      @input="handleInput"
      @keydown="handleKeydown"
    />
    
    <!-- @提及下拉菜单 -->
    <div
      v-if="showMentionMenu"
      class="mention-menu"
      :style="mentionMenuStyle"
    >
      <a-list
        :data="filteredUsers"
        size="small"
        :max-height="200"
        :virtual-list-props="{ height: 200 }"
      >
        <template #item="{ item, index }">
          <a-list-item
            :class="{ 'is-active': index === activeIndex }"
            @click="handleSelectUser(item)"
            @mouseenter="activeIndex = index"
          >
            <a-list-item-meta>
              <template #avatar>
                <a-avatar :size="24">
                  {{ item.name.charAt(0) }}
                </a-avatar>
              </template>
              <template #title>
                {{ item.name }}
              </template>
              <template #description>
                {{ item.role }}
              </template>
            </a-list-item-meta>
          </a-list-item>
        </template>
      </a-list>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, nextTick } from 'vue';

interface User {
  id: number;
  name: string;
  role: string;
}

interface Props {
  modelValue: string;
  placeholder?: string;
  autoSize?: boolean | { minRows?: number; maxRows?: number };
  maxLength?: number;
  showWordLimit?: boolean;
  users?: User[];
}

const props = withDefaults(defineProps<Props>(), {
  placeholder: '输入 @ 提及用户...',
  autoSize: true,
  maxLength: 1000,
  showWordLimit: true,
  users: () => [],
});

const emit = defineEmits<{
  'update:modelValue': [value: string];
  mention: [user: User];
}>();

const textareaRef = ref();
const inputValue = ref(props.modelValue);
const showMentionMenu = ref(false);
const mentionMenuStyle = ref({});
const activeIndex = ref(0);
const mentionKeyword = ref('');
const mentionStartPos = ref(0);

// 默认用户列表（如果没有传入）
const defaultUsers: User[] = [
  { id: 1, name: '张三', role: '开发工程师' },
  { id: 2, name: '李四', role: '测试工程师' },
  { id: 3, name: '王五', role: '产品经理' },
  { id: 4, name: '赵六', role: '设计师' },
  { id: 5, name: '钱七', role: '运维工程师' },
];

const allUsers = computed(() => props.users.length > 0 ? props.users : defaultUsers);

// 过滤用户列表
const filteredUsers = computed(() => {
  if (!mentionKeyword.value) {
    return allUsers.value;
  }
  
  const keyword = mentionKeyword.value.toLowerCase();
  return allUsers.value.filter(
    (user) =>
      user.name.toLowerCase().includes(keyword) ||
      user.role.toLowerCase().includes(keyword)
  );
});

// 处理输入
const handleInput = (value: string) => {
  inputValue.value = value;
  emit('update:modelValue', value);
  
  // 检测 @ 符号
  const textarea = textareaRef.value?.$el?.querySelector('textarea');
  if (!textarea) return;
  
  const cursorPos = textarea.selectionStart;
  const textBeforeCursor = value.substring(0, cursorPos);
  const lastAtIndex = textBeforeCursor.lastIndexOf('@');
  
  if (lastAtIndex !== -1) {
    const textAfterAt = textBeforeCursor.substring(lastAtIndex + 1);
    
    // 检查 @ 后面是否有空格或换行
    if (!textAfterAt.includes(' ') && !textAfterAt.includes('\n')) {
      mentionKeyword.value = textAfterAt;
      mentionStartPos.value = lastAtIndex;
      showMentionMenu.value = true;
      activeIndex.value = 0;
      
      // 计算菜单位置
      nextTick(() => {
        updateMenuPosition(textarea, cursorPos);
      });
      
      return;
    }
  }
  
  showMentionMenu.value = false;
};

// 更新菜单位置
const updateMenuPosition = (textarea: HTMLTextAreaElement, cursorPos: number) => {
  // 创建临时元素来计算光标位置
  const div = document.createElement('div');
  const style = window.getComputedStyle(textarea);
  
  // 复制样式
  ['font', 'letterSpacing', 'whiteSpace', 'lineHeight', 'padding'].forEach((prop) => {
    div.style[prop as any] = style[prop as any];
  });
  
  div.style.position = 'absolute';
  div.style.visibility = 'hidden';
  div.style.width = `${textarea.clientWidth}px`;
  div.textContent = textarea.value.substring(0, cursorPos);
  
  document.body.appendChild(div);
  
  const span = document.createElement('span');
  span.textContent = textarea.value.substring(cursorPos) || '.';
  div.appendChild(span);
  
  const { offsetTop, offsetLeft } = span;
  document.body.removeChild(div);
  
  // 设置菜单位置
  mentionMenuStyle.value = {
    top: `${offsetTop + 24}px`,
    left: `${offsetLeft}px`,
  };
};

// 处理键盘事件
const handleKeydown = (e: KeyboardEvent) => {
  if (!showMentionMenu.value) return;
  
  switch (e.key) {
    case 'ArrowDown':
      e.preventDefault();
      activeIndex.value = Math.min(activeIndex.value + 1, filteredUsers.value.length - 1);
      break;
      
    case 'ArrowUp':
      e.preventDefault();
      activeIndex.value = Math.max(activeIndex.value - 1, 0);
      break;
      
    case 'Enter':
      if (filteredUsers.value.length > 0) {
        e.preventDefault();
        handleSelectUser(filteredUsers.value[activeIndex.value]);
      }
      break;
      
    case 'Escape':
      e.preventDefault();
      showMentionMenu.value = false;
      break;
  }
};

// 选择用户
const handleSelectUser = (user: User) => {
  const beforeMention = inputValue.value.substring(0, mentionStartPos.value);
  const afterMention = inputValue.value.substring(
    mentionStartPos.value + mentionKeyword.value.length + 1
  );
  
  const newValue = `${beforeMention}@${user.name} ${afterMention}`;
  inputValue.value = newValue;
  emit('update:modelValue', newValue);
  emit('mention', user);
  
  showMentionMenu.value = false;
  
  // 恢复焦点
  nextTick(() => {
    const textarea = textareaRef.value?.$el?.querySelector('textarea');
    if (textarea) {
      const newCursorPos = beforeMention.length + user.name.length + 2;
      textarea.focus();
      textarea.setSelectionRange(newCursorPos, newCursorPos);
    }
  });
};

// 监听外部值变化
watch(
  () => props.modelValue,
  (newValue) => {
    if (newValue !== inputValue.value) {
      inputValue.value = newValue;
    }
  }
);
</script>

<style scoped lang="less">
.mention-input {
  position: relative;
  
  .mention-menu {
    position: absolute;
    z-index: 1000;
    background: var(--color-bg-popup);
    border: 1px solid var(--color-border);
    border-radius: 4px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    max-width: 300px;
    
    :deep(.arco-list-item) {
      cursor: pointer;
      padding: 8px 12px;
      
      &:hover,
      &.is-active {
        background: var(--color-fill-2);
      }
    }
    
    :deep(.arco-list-item-meta-title) {
      font-size: 14px;
      font-weight: 500;
    }
    
    :deep(.arco-list-item-meta-description) {
      font-size: 12px;
      color: var(--color-text-3);
    }
  }
}
</style>

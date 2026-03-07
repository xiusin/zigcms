import { onMounted, onUnmounted } from 'vue';

export interface KeyboardShortcut {
  key: string;
  ctrl?: boolean;
  shift?: boolean;
  alt?: boolean;
  meta?: boolean;
  handler: (event: KeyboardEvent) => void;
  description?: string;
}

export function useKeyboardShortcuts(shortcuts: KeyboardShortcut[]) {
  const handleKeyDown = (event: KeyboardEvent) => {
    for (const shortcut of shortcuts) {
      const keyMatch = event.key.toLowerCase() === shortcut.key.toLowerCase();
      const ctrlMatch = shortcut.ctrl === undefined || event.ctrlKey === shortcut.ctrl;
      const shiftMatch = shortcut.shift === undefined || event.shiftKey === shortcut.shift;
      const altMatch = shortcut.alt === undefined || event.altKey === shortcut.alt;
      const metaMatch = shortcut.meta === undefined || event.metaKey === shortcut.meta;

      if (keyMatch && ctrlMatch && shiftMatch && altMatch && metaMatch) {
        event.preventDefault();
        shortcut.handler(event);
        break;
      }
    }
  };

  onMounted(() => {
    document.addEventListener('keydown', handleKeyDown);
  });

  onUnmounted(() => {
    document.removeEventListener('keydown', handleKeyDown);
  });

  return {
    shortcuts,
  };
}

// 预定义的快捷键
export const commonShortcuts = {
  // 搜索
  search: {
    key: 'f',
    ctrl: true,
    description: '聚焦搜索框',
  },
  // 刷新
  refresh: {
    key: 'r',
    ctrl: true,
    description: '刷新列表',
  },
  // 新建
  create: {
    key: 'n',
    ctrl: true,
    description: '新建项目',
  },
  // 保存
  save: {
    key: 's',
    ctrl: true,
    description: '保存',
  },
  // 取消
  cancel: {
    key: 'Escape',
    description: '取消/关闭',
  },
  // 全选
  selectAll: {
    key: 'a',
    ctrl: true,
    description: '全选',
  },
  // 删除
  delete: {
    key: 'Delete',
    description: '删除选中项',
  },
  // 上一页
  prevPage: {
    key: 'ArrowLeft',
    alt: true,
    description: '上一页',
  },
  // 下一页
  nextPage: {
    key: 'ArrowRight',
    alt: true,
    description: '下一页',
  },
  // 帮助
  help: {
    key: '?',
    shift: true,
    description: '显示快捷键帮助',
  },
};

// 快捷键帮助对话框
export function showShortcutsHelp(shortcuts: KeyboardShortcut[]) {
  const helpText = shortcuts
    .filter((s) => s.description)
    .map((s) => {
      const keys = [];
      if (s.ctrl) keys.push('Ctrl');
      if (s.shift) keys.push('Shift');
      if (s.alt) keys.push('Alt');
      if (s.meta) keys.push('Meta');
      keys.push(s.key);
      return `${keys.join(' + ')}: ${s.description}`;
    })
    .join('\n');

  alert(`快捷键帮助:\n\n${helpText}`);
}

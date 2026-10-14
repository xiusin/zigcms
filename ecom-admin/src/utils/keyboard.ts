/**
 * 键盘快捷键工具
 * 提供全局键盘快捷键注册和管理
 */

export type KeyboardEventHandler = (event: KeyboardEvent) => void | boolean;

export interface ShortcutConfig {
  key: string;
  ctrl?: boolean;
  shift?: boolean;
  alt?: boolean;
  meta?: boolean;
  handler: KeyboardEventHandler;
  description?: string;
  preventDefault?: boolean;
  stopPropagation?: boolean;
}

class KeyboardShortcutManager {
  private shortcuts: Map<string, ShortcutConfig> = new Map();
  private isListening: boolean = false;

  /**
   * 生成快捷键标识
   */
  private generateKey(config: ShortcutConfig): string {
    const parts: string[] = [];

    if (config.ctrl) parts.push('ctrl');
    if (config.shift) parts.push('shift');
    if (config.alt) parts.push('alt');
    if (config.meta) parts.push('meta');
    parts.push(config.key.toLowerCase());

    return parts.join('+');
  }

  /**
   * 检查事件是否匹配快捷键
   */
  private matchesShortcut(event: KeyboardEvent, config: ShortcutConfig): boolean {
    const keyMatch = event.key.toLowerCase() === config.key.toLowerCase();
    const ctrlMatch = config.ctrl ? event.ctrlKey || event.metaKey : !event.ctrlKey && !event.metaKey;
    const shiftMatch = config.shift ? event.shiftKey : !event.shiftKey;
    const altMatch = config.alt ? event.altKey : !event.altKey;

    return keyMatch && ctrlMatch && shiftMatch && altMatch;
  }

  /**
   * 全局键盘事件处理
   */
  private handleKeyDown = (event: KeyboardEvent): void => {
    // 忽略输入框中的快捷键（除了 Esc）
    const target = event.target as HTMLElement;
    const isInput = ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName);
    const isContentEditable = target.isContentEditable;

    if ((isInput || isContentEditable) && event.key !== 'Escape') {
      return;
    }

    // 遍历所有快捷键
    for (const [, config] of this.shortcuts) {
      if (this.matchesShortcut(event, config)) {
        // 阻止默认行为
        if (config.preventDefault !== false) {
          event.preventDefault();
        }

        // 阻止事件冒泡
        if (config.stopPropagation) {
          event.stopPropagation();
        }

        // 执行处理函数
        const result = config.handler(event);

        // 如果处理函数返回 false，停止后续处理
        if (result === false) {
          break;
        }
      }
    }
  };

  /**
   * 注册快捷键
   */
  register(config: ShortcutConfig): () => void {
    const key = this.generateKey(config);

    // 如果已存在，先注销
    if (this.shortcuts.has(key)) {
      console.warn(`快捷键 ${key} 已存在，将被覆盖`);
    }

    this.shortcuts.set(key, config);

    // 如果还没开始监听，启动监听
    if (!this.isListening) {
      this.startListening();
    }

    // 返回注销函数
    return () => this.unregister(key);
  }

  /**
   * 注销快捷键
   */
  unregister(key: string): void {
    this.shortcuts.delete(key);

    // 如果没有快捷键了，停止监听
    if (this.shortcuts.size === 0) {
      this.stopListening();
    }
  }

  /**
   * 注销所有快捷键
   */
  unregisterAll(): void {
    this.shortcuts.clear();
    this.stopListening();
  }

  /**
   * 开始监听键盘事件
   */
  private startListening(): void {
    if (!this.isListening) {
      document.addEventListener('keydown', this.handleKeyDown);
      this.isListening = true;
    }
  }

  /**
   * 停止监听键盘事件
   */
  private stopListening(): void {
    if (this.isListening) {
      document.removeEventListener('keydown', this.handleKeyDown);
      this.isListening = false;
    }
  }

  /**
   * 获取所有已注册的快捷键
   */
  getShortcuts(): ShortcutConfig[] {
    return Array.from(this.shortcuts.values());
  }

  /**
   * 格式化快捷键显示文本
   */
  formatShortcut(config: ShortcutConfig): string {
    const parts: string[] = [];

    if (config.ctrl) parts.push('Ctrl');
    if (config.shift) parts.push('Shift');
    if (config.alt) parts.push('Alt');
    if (config.meta) parts.push('Meta');
    parts.push(config.key.toUpperCase());

    return parts.join(' + ');
  }
}

// 全局快捷键管理器实例
export const keyboard = new KeyboardShortcutManager();

/**
 * 常用快捷键配置
 */
export const CommonShortcuts = {
  /**
   * Ctrl+S 保存
   */
  save: (handler: KeyboardEventHandler): ShortcutConfig => ({
    key: 's',
    ctrl: true,
    handler,
    description: '保存',
  }),

  /**
   * Ctrl+F 搜索
   */
  search: (handler: KeyboardEventHandler): ShortcutConfig => ({
    key: 'f',
    ctrl: true,
    handler,
    description: '搜索',
  }),

  /**
   * Esc 关闭/取消
   */
  escape: (handler: KeyboardEventHandler): ShortcutConfig => ({
    key: 'Escape',
    handler,
    description: '关闭/取消',
  }),

  /**
   * Ctrl+Enter 提交
   */
  submit: (handler: KeyboardEventHandler): ShortcutConfig => ({
    key: 'Enter',
    ctrl: true,
    handler,
    description: '提交',
  }),

  /**
   * Ctrl+Z 撤销
   */
  undo: (handler: KeyboardEventHandler): ShortcutConfig => ({
    key: 'z',
    ctrl: true,
    handler,
    description: '撤销',
  }),

  /**
   * Ctrl+Y 重做
   */
  redo: (handler: KeyboardEventHandler): ShortcutConfig => ({
    key: 'y',
    ctrl: true,
    handler,
    description: '重做',
  }),

  /**
   * Ctrl+A 全选
   */
  selectAll: (handler: KeyboardEventHandler): ShortcutConfig => ({
    key: 'a',
    ctrl: true,
    handler,
    description: '全选',
  }),

  /**
   * Delete 删除
   */
  delete: (handler: KeyboardEventHandler): ShortcutConfig => ({
    key: 'Delete',
    handler,
    description: '删除',
  }),
};

/**
 * Vue 组合式 API Hook
 * 在组件中使用快捷键
 */
export function useKeyboardShortcut(
  config: ShortcutConfig | ShortcutConfig[]
): () => void {
  const configs = Array.isArray(config) ? config : [config];
  const unregisterFns: Array<() => void> = [];

  // 注册快捷键
  configs.forEach((cfg) => {
    const unregister = keyboard.register(cfg);
    unregisterFns.push(unregister);
  });

  // 返回注销函数
  return () => {
    unregisterFns.forEach((fn) => fn());
  };
}

/**
 * 快捷键帮助面板数据
 */
export interface ShortcutHelpItem {
  category: string;
  shortcuts: Array<{
    keys: string;
    description: string;
  }>;
}

/**
 * 获取快捷键帮助数据
 */
export function getShortcutHelp(): ShortcutHelpItem[] {
  return [
    {
      category: '通用',
      shortcuts: [
        { keys: 'Ctrl + S', description: '保存' },
        { keys: 'Ctrl + F', description: '搜索' },
        { keys: 'Esc', description: '关闭弹窗/取消操作' },
        { keys: 'Ctrl + Enter', description: '提交表单' },
      ],
    },
    {
      category: '编辑',
      shortcuts: [
        { keys: 'Ctrl + Z', description: '撤销' },
        { keys: 'Ctrl + Y', description: '重做' },
        { keys: 'Ctrl + A', description: '全选' },
        { keys: 'Delete', description: '删除' },
      ],
    },
    {
      category: '导航',
      shortcuts: [
        { keys: 'Ctrl + ←', description: '返回上一页' },
        { keys: 'Ctrl + →', description: '前进下一页' },
        { keys: 'Ctrl + Home', description: '回到顶部' },
        { keys: 'Ctrl + End', description: '滚动到底部' },
      ],
    },
  ];
}

// 导出默认对象
export default {
  keyboard,
  CommonShortcuts,
  useKeyboardShortcut,
  getShortcutHelp,
};

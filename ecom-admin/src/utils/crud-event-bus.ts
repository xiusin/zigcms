/**
 * CRUD 事件总线
 * 用于 CRUD 组件与其他页面之间的通信
 */

/* eslint-disable max-classes-per-file */

type EventCallback = (...args: any[]) => void;

class CrudEventBus {
  private events: Map<string, EventCallback[]> = new Map();

  // 订阅事件
  on(event: string, callback: EventCallback) {
    if (!this.events.has(event)) {
      this.events.set(event, []);
    }
    this.events.get(event)?.push(callback);
  }

  // 取消订阅
  off(event: string, callback?: EventCallback) {
    if (!callback) {
      this.events.delete(event);
      return;
    }
    const callbacks = this.events.get(event);
    if (callbacks) {
      const index = callbacks.indexOf(callback);
      if (index > -1) {
        callbacks.splice(index, 1);
      }
    }
  }

  // 触发事件
  emit(event: string, ...args: any[]) {
    const callbacks = this.events.get(event);
    if (callbacks) {
      callbacks.forEach((callback) => callback(...args));
    }
  }

  // 一次性订阅
  once(event: string, callback: EventCallback) {
    const onceCallback = (...args: any[]) => {
      callback(...args);
      this.off(event, onceCallback);
    };
    this.on(event, onceCallback);
  }

  // 清空所有事件
  clear() {
    this.events.clear();
  }
}

// 全局事件总线实例
export const crudEventBus = new CrudEventBus();

// 预定义事件类型
export const CrudEvents = {
  // 数据操作事件
  DATA_LOADED: 'crud:data:loaded',
  DATA_ADDED: 'crud:data:added',
  DATA_UPDATED: 'crud:data:updated',
  DATA_DELETED: 'crud:data:deleted',
  DATA_BULK_ACTION: 'crud:data:bulk',

  // 选择事件
  SELECTION_CHANGED: 'crud:selection:changed',
  ROW_CLICKED: 'crud:row:clicked',

  // 状态事件
  LOADING_START: 'crud:loading:start',
  LOADING_END: 'crud:loading:end',
  ERROR: 'crud:error',

  // 刷新事件
  REFRESH: 'crud:refresh',
  RELOAD: 'crud:reload',
} as const;

/**
 * CRUD 状态管理
 */
interface CrudState {
  loading: boolean;
  data: any[];
  total: number;
  page: number;
  pageSize: number;
  selectedRows: any[];
  filters: Record<string, any>;
}

class CrudStateManager {
  private states: Map<string, CrudState> = new Map();

  // 初始化状态
  init(id: string, initialState?: Partial<CrudState>) {
    this.states.set(id, {
      loading: false,
      data: [],
      total: 0,
      page: 1,
      pageSize: 10,
      selectedRows: [],
      filters: {},
      ...initialState,
    });
  }

  // 获取状态
  get(id: string): CrudState | undefined {
    return this.states.get(id);
  }

  // 更新状态
  update(id: string, updates: Partial<CrudState>) {
    const state = this.states.get(id);
    if (state) {
      Object.assign(state, updates);
      // 触发状态变化事件
      crudEventBus.emit(`crud:state:${id}`, state);
    }
  }

  // 删除状态
  remove(id: string) {
    this.states.delete(id);
  }

  // 清空所有状态
  clear() {
    this.states.clear();
  }
}

export const crudStateManager = new CrudStateManager();

/**
 * CRUD 数据联动管理
 */
interface LinkageRule {
  source: string; // 源 CRUD ID
  target: string; // 目标 CRUD ID
  sourceField: string; // 源字段
  targetField: string; // 目标字段
  transform?: (value: any) => any; // 数据转换
}

class CrudLinkageManager {
  private rules: LinkageRule[] = [];

  // 添加联动规则
  addRule(rule: LinkageRule) {
    this.rules.push(rule);
  }

  // 移除联动规则
  removeRule(source: string, target: string) {
    this.rules = this.rules.filter(
      (rule) => !(rule.source === source && rule.target === target)
    );
  }

  // 触发联动
  trigger(source: string, data: any) {
    const relatedRules = this.rules.filter((rule) => rule.source === source);
    relatedRules.forEach((rule) => {
      const value = data[rule.sourceField];
      const transformedValue = rule.transform ? rule.transform(value) : value;
      // 触发目标 CRUD 刷新
      crudEventBus.emit(`crud:linkage:${rule.target}`, {
        field: rule.targetField,
        value: transformedValue,
      });
    });
  }

  // 清空规则
  clear() {
    this.rules = [];
  }
}

export const crudLinkageManager = new CrudLinkageManager();

/**
 * CRUD 实例管理器
 */
interface CrudInstance {
  id: string;
  config: any;
  refresh: () => void;
  reload: () => void;
  getSelectedRows: () => any[];
  clearSelection: () => void;
}

class CrudInstanceManager {
  private instances: Map<string, CrudInstance> = new Map();

  register(instance: CrudInstance) {
    this.instances.set(instance.id, instance);
  }

  unregister(id: string) {
    this.instances.delete(id);
  }

  get(id: string): CrudInstance | undefined {
    return this.instances.get(id);
  }

  // 刷新指定 CRUD
  refresh(id: string) {
    const instance = this.instances.get(id);
    if (instance) {
      instance.refresh();
    }
  }

  // 重新加载指定 CRUD
  reload(id: string) {
    const instance = this.instances.get(id);
    if (instance) {
      instance.reload();
    }
  }

  // 获取选中行
  getSelectedRows(id: string): any[] {
    const instance = this.instances.get(id);
    return instance ? instance.getSelectedRows() : [];
  }

  // 清空选择
  clearSelection(id: string) {
    const instance = this.instances.get(id);
    if (instance) {
      instance.clearSelection();
    }
  }

  clear() {
    this.instances.clear();
  }
}

export const crudInstanceManager = new CrudInstanceManager();

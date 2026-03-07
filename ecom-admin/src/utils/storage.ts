/**
 * 本地存储工具
 * 提供 localStorage 和 sessionStorage 的封装
 * 支持表格状态记忆、用户偏好设置等
 */

export type StorageType = 'local' | 'session';

/**
 * 表格列配置
 */
export interface TableColumnConfig {
  dataIndex: string;
  visible: boolean;
  width?: number;
  fixed?: 'left' | 'right' | boolean;
  sortOrder?: 'ascend' | 'descend' | '';
}

/**
 * 表格状态
 */
export interface TableState {
  columns?: TableColumnConfig[];
  pageSize?: number;
  filters?: Record<string, any>;
  sorter?: {
    field: string;
    direction: 'ascend' | 'descend' | '';
  };
}

/**
 * 用户偏好设置
 */
export interface UserPreferences {
  theme?: 'light' | 'dark' | 'auto';
  language?: string;
  sidebarCollapsed?: boolean;
  tablePageSize?: number;
  [key: string]: any;
}

class StorageManager {
  private prefix: string = 'quality-center-';

  /**
   * 生成存储键
   */
  private getKey(key: string): string {
    return `${this.prefix}${key}`;
  }

  /**
   * 获取存储对象
   */
  private getStorage(type: StorageType): Storage {
    return type === 'local' ? localStorage : sessionStorage;
  }

  /**
   * 设置数据
   */
  set<T = any>(key: string, value: T, type: StorageType = 'local'): void {
    try {
      const storage = this.getStorage(type);
      const serialized = JSON.stringify(value);
      storage.setItem(this.getKey(key), serialized);
    } catch (error) {
      console.error('存储数据失败:', error);
    }
  }

  /**
   * 获取数据
   */
  get<T = any>(key: string, defaultValue?: T, type: StorageType = 'local'): T | undefined {
    try {
      const storage = this.getStorage(type);
      const item = storage.getItem(this.getKey(key));

      if (item === null) {
        return defaultValue;
      }

      return JSON.parse(item) as T;
    } catch (error) {
      console.error('读取数据失败:', error);
      return defaultValue;
    }
  }

  /**
   * 移除数据
   */
  remove(key: string, type: StorageType = 'local'): void {
    try {
      const storage = this.getStorage(type);
      storage.removeItem(this.getKey(key));
    } catch (error) {
      console.error('移除数据失败:', error);
    }
  }

  /**
   * 清空所有数据
   */
  clear(type: StorageType = 'local'): void {
    try {
      const storage = this.getStorage(type);
      const keys = Object.keys(storage);

      keys.forEach((key) => {
        if (key.startsWith(this.prefix)) {
          storage.removeItem(key);
        }
      });
    } catch (error) {
      console.error('清空数据失败:', error);
    }
  }

  /**
   * 检查键是否存在
   */
  has(key: string, type: StorageType = 'local'): boolean {
    const storage = this.getStorage(type);
    return storage.getItem(this.getKey(key)) !== null;
  }

  /**
   * 获取所有键
   */
  keys(type: StorageType = 'local'): string[] {
    const storage = this.getStorage(type);
    const keys = Object.keys(storage);

    return keys
      .filter((key) => key.startsWith(this.prefix))
      .map((key) => key.replace(this.prefix, ''));
  }

  // ==================== 表格状态管理 ====================

  /**
   * 保存表格状态
   */
  saveTableState(tableId: string, state: TableState): void {
    this.set(`table-state-${tableId}`, state);
  }

  /**
   * 获取表格状态
   */
  getTableState(tableId: string): TableState | undefined {
    return this.get<TableState>(`table-state-${tableId}`);
  }

  /**
   * 移除表格状态
   */
  removeTableState(tableId: string): void {
    this.remove(`table-state-${tableId}`);
  }

  /**
   * 保存表格列配置
   */
  saveTableColumns(tableId: string, columns: TableColumnConfig[]): void {
    const state = this.getTableState(tableId) || {};
    state.columns = columns;
    this.saveTableState(tableId, state);
  }

  /**
   * 获取表格列配置
   */
  getTableColumns(tableId: string): TableColumnConfig[] | undefined {
    const state = this.getTableState(tableId);
    return state?.columns;
  }

  /**
   * 保存表格分页大小
   */
  saveTablePageSize(tableId: string, pageSize: number): void {
    const state = this.getTableState(tableId) || {};
    state.pageSize = pageSize;
    this.saveTableState(tableId, state);
  }

  /**
   * 获取表格分页大小
   */
  getTablePageSize(tableId: string, defaultSize: number = 20): number {
    const state = this.getTableState(tableId);
    return state?.pageSize || defaultSize;
  }

  /**
   * 保存表格筛选条件
   */
  saveTableFilters(tableId: string, filters: Record<string, any>): void {
    const state = this.getTableState(tableId) || {};
    state.filters = filters;
    this.saveTableState(tableId, state);
  }

  /**
   * 获取表格筛选条件
   */
  getTableFilters(tableId: string): Record<string, any> | undefined {
    const state = this.getTableState(tableId);
    return state?.filters;
  }

  /**
   * 保存表格排序
   */
  saveTableSorter(tableId: string, field: string, direction: 'ascend' | 'descend' | ''): void {
    const state = this.getTableState(tableId) || {};
    state.sorter = { field, direction };
    this.saveTableState(tableId, state);
  }

  /**
   * 获取表格排序
   */
  getTableSorter(tableId: string): { field: string; direction: 'ascend' | 'descend' | '' } | undefined {
    const state = this.getTableState(tableId);
    return state?.sorter;
  }

  // ==================== 用户偏好设置 ====================

  /**
   * 保存用户偏好
   */
  savePreferences(preferences: Partial<UserPreferences>): void {
    const current = this.getPreferences();
    const updated = { ...current, ...preferences };
    this.set('user-preferences', updated);
  }

  /**
   * 获取用户偏好
   */
  getPreferences(): UserPreferences {
    return this.get<UserPreferences>('user-preferences', {});
  }

  /**
   * 获取单个偏好设置
   */
  getPreference<T = any>(key: string, defaultValue?: T): T | undefined {
    const preferences = this.getPreferences();
    return (preferences[key] as T) || defaultValue;
  }

  /**
   * 设置单个偏好
   */
  setPreference(key: string, value: any): void {
    this.savePreferences({ [key]: value });
  }

  /**
   * 移除用户偏好
   */
  removePreferences(): void {
    this.remove('user-preferences');
  }

  // ==================== 最近访问记录 ====================

  /**
   * 添加最近访问记录
   */
  addRecentVisit(item: { id: string | number; name: string; type: string; timestamp?: number }): void {
    const recent = this.getRecentVisits();
    const timestamp = item.timestamp || Date.now();

    // 移除重复项
    const filtered = recent.filter((r) => !(r.id === item.id && r.type === item.type));

    // 添加到开头
    filtered.unshift({ ...item, timestamp });

    // 限制数量（最多 20 条）
    const limited = filtered.slice(0, 20);

    this.set('recent-visits', limited);
  }

  /**
   * 获取最近访问记录
   */
  getRecentVisits(): Array<{ id: string | number; name: string; type: string; timestamp: number }> {
    return this.get('recent-visits', []);
  }

  /**
   * 清空最近访问记录
   */
  clearRecentVisits(): void {
    this.remove('recent-visits');
  }

  // ==================== 草稿保存 ====================

  /**
   * 保存草稿
   */
  saveDraft(key: string, data: any): void {
    this.set(`draft-${key}`, {
      data,
      timestamp: Date.now(),
    });
  }

  /**
   * 获取草稿
   */
  getDraft<T = any>(key: string): { data: T; timestamp: number } | undefined {
    return this.get(`draft-${key}`);
  }

  /**
   * 移除草稿
   */
  removeDraft(key: string): void {
    this.remove(`draft-${key}`);
  }

  /**
   * 获取所有草稿
   */
  getAllDrafts(): Array<{ key: string; data: any; timestamp: number }> {
    const keys = this.keys();
    const draftKeys = keys.filter((key) => key.startsWith('draft-'));

    return draftKeys.map((key) => {
      const draft = this.getDraft(key.replace('draft-', ''));
      return {
        key: key.replace('draft-', ''),
        data: draft?.data,
        timestamp: draft?.timestamp || 0,
      };
    });
  }

  /**
   * 清空所有草稿
   */
  clearAllDrafts(): void {
    const keys = this.keys();
    const draftKeys = keys.filter((key) => key.startsWith('draft-'));

    draftKeys.forEach((key) => {
      this.remove(key);
    });
  }
}

// 全局存储管理器实例
export const storage = new StorageManager();

/**
 * Vue 组合式 API Hook
 * 在组件中使用存储
 */
export function useStorage() {
  return {
    set: storage.set.bind(storage),
    get: storage.get.bind(storage),
    remove: storage.remove.bind(storage),
    clear: storage.clear.bind(storage),
    has: storage.has.bind(storage),
    keys: storage.keys.bind(storage),
  };
}

/**
 * Vue 组合式 API Hook
 * 在组件中使用表格状态
 */
export function useTableState(tableId: string) {
  return {
    saveState: (state: TableState) => storage.saveTableState(tableId, state),
    getState: () => storage.getTableState(tableId),
    removeState: () => storage.removeTableState(tableId),
    saveColumns: (columns: TableColumnConfig[]) => storage.saveTableColumns(tableId, columns),
    getColumns: () => storage.getTableColumns(tableId),
    savePageSize: (pageSize: number) => storage.saveTablePageSize(tableId, pageSize),
    getPageSize: (defaultSize?: number) => storage.getTablePageSize(tableId, defaultSize),
    saveFilters: (filters: Record<string, any>) => storage.saveTableFilters(tableId, filters),
    getFilters: () => storage.getTableFilters(tableId),
    saveSorter: (field: string, direction: 'ascend' | 'descend' | '') =>
      storage.saveTableSorter(tableId, field, direction),
    getSorter: () => storage.getTableSorter(tableId),
  };
}

// 导出默认对象
export default {
  storage,
  useStorage,
  useTableState,
};

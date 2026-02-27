/**
 * CRUD 插件系统
 * 支持功能扩展和自定义增强
 */

import type { CrudConfig } from './amis-crud-generator';

export interface CrudPlugin {
  name: string;
  version?: string;
  install: (config: CrudConfig) => CrudConfig;
  beforeRequest?: (data: any) => any;
  afterResponse?: (data: any) => any;
  onError?: (error: any) => void;
}

class CrudPluginManager {
  private plugins: Map<string, CrudPlugin> = new Map();

  // 注册插件
  register(plugin: CrudPlugin) {
    if (this.plugins.has(plugin.name)) {
      console.warn(`插件 ${plugin.name} 已存在，将被覆盖`);
    }
    this.plugins.set(plugin.name, plugin);
  }

  // 卸载插件
  unregister(name: string) {
    this.plugins.delete(name);
  }

  // 应用插件
  apply(config: CrudConfig, pluginNames?: string[]): CrudConfig {
    let result = { ...config };
    const plugins = pluginNames
      ? pluginNames.map((name) => this.plugins.get(name)).filter(Boolean)
      : Array.from(this.plugins.values());

    plugins.forEach((plugin) => {
      if (plugin) {
        result = plugin.install(result);
      }
    });

    return result;
  }

  // 获取插件
  get(name: string): CrudPlugin | undefined {
    return this.plugins.get(name);
  }

  // 列出所有插件
  list(): CrudPlugin[] {
    return Array.from(this.plugins.values());
  }
}

export const crudPluginManager = new CrudPluginManager();

// ==================== 内置插件 ====================

/**
 * 软删除插件
 * 删除时标记为已删除，而不是物理删除
 */
export const softDeletePlugin: CrudPlugin = {
  name: 'softDelete',
  version: '1.0.0',
  install: (config) => ({
    ...config,
    enableDelete: false, // 禁用默认删除
    customActions: [
      ...(config.customActions || []),
      {
        label: '删除',
        icon: 'delete',
        level: 'danger',
        position: 'row',
        visible: (row) => !row.deleted_at,
        onClick: async (row) => {
          // 软删除：更新 deleted_at 字段
          await fetch(`${config.api}/${row.id}`, {
            method: 'PUT',
            body: JSON.stringify({ deleted_at: new Date().toISOString() }),
          });
        },
      },
      {
        label: '恢复',
        icon: 'undo',
        level: 'success',
        position: 'row',
        visible: (row) => !!row.deleted_at,
        onClick: async (row) => {
          await fetch(`${config.api}/${row.id}`, {
            method: 'PUT',
            body: JSON.stringify({ deleted_at: null }),
          });
        },
      },
    ],
  }),
};

/**
 * 审计日志插件
 * 自动记录创建人、创建时间、修改人、修改时间
 */
export const auditLogPlugin: CrudPlugin = {
  name: 'auditLog',
  version: '1.0.0',
  install: (config) => ({
    ...config,
    fields: [
      ...config.fields,
      {
        name: 'created_by',
        label: '创建人',
        type: 'text',
        hideInForm: true,
      },
      {
        name: 'created_at',
        label: '创建时间',
        type: 'datetime',
        hideInForm: true,
      },
      {
        name: 'updated_by',
        label: '修改人',
        type: 'text',
        hideInForm: true,
      },
      {
        name: 'updated_at',
        label: '修改时间',
        type: 'datetime',
        hideInForm: true,
      },
    ],
    events: {
      ...config.events,
      onAdd: async (data) => {
        const username = localStorage.getItem('username') || 'system';
        data.created_by = username;
        data.created_at = new Date().toISOString();
        await config.events?.onAdd?.(data);
      },
      onEdit: async (data) => {
        const username = localStorage.getItem('username') || 'system';
        data.updated_by = username;
        data.updated_at = new Date().toISOString();
        await config.events?.onEdit?.(data);
      },
    },
  }),
};

/**
 * 数据缓存插件
 * 缓存列表数据，减少 API 请求
 */
export const cachePlugin: CrudPlugin = {
  name: 'cache',
  version: '1.0.0',
  install: (config) => {
    const cacheKey = `crud_cache_${config.api}`;
    const cacheDuration = 5 * 60 * 1000; // 5分钟

    return {
      ...config,
      events: {
        ...config.events,
        onLoad: (data) => {
          // 缓存数据
          localStorage.setItem(
            cacheKey,
            JSON.stringify({
              data,
              timestamp: Date.now(),
            })
          );
          config.events?.onLoad?.(data);
        },
      },
      dataTransform: {
        ...config.dataTransform,
        request: (data) => {
          // 检查缓存
          const cached = localStorage.getItem(cacheKey);
          if (cached) {
            const { data: cachedData, timestamp } = JSON.parse(cached);
            if (Date.now() - timestamp < cacheDuration) {
              return cachedData;
            }
          }
          return config.dataTransform?.request?.(data) || data;
        },
      },
    };
  },
};

/**
 * 乐观锁插件
 * 防止并发编辑冲突
 */
export const optimisticLockPlugin: CrudPlugin = {
  name: 'optimisticLock',
  version: '1.0.0',
  install: (config) => ({
    ...config,
    fields: [
      ...config.fields,
      {
        name: 'version',
        label: '版本号',
        type: 'number',
        hidden: true,
        hideInForm: true,
      },
    ],
    events: {
      ...config.events,
      onEdit: async (data) => {
        // 检查版本号
        const current = await fetch(`${config.api}/${data.id}`).then((r) =>
          r.json()
        );
        if (current.version !== data.version) {
          throw new Error('数据已被其他用户修改，请刷新后重试');
        }
        data.version = (data.version || 0) + 1;
        await config.events?.onEdit?.(data);
      },
    },
  }),
};

/**
 * 数据加密插件
 * 敏感字段自动加密/解密
 */
export const encryptPlugin: CrudPlugin = {
  name: 'encrypt',
  version: '1.0.0',
  install: (config) => {
    const encryptFields = config.fields
      .filter((f) => f.name.includes('password') || f.name.includes('secret'))
      .map((f) => f.name);

    return {
      ...config,
      dataTransform: {
        ...config.dataTransform,
        request: (data) => {
          const encrypted = { ...data };
          encryptFields.forEach((field) => {
            if (encrypted[field]) {
              // 简单 Base64 加密（实际应使用更安全的加密算法）
              encrypted[field] = btoa(encrypted[field]);
            }
          });
          return config.dataTransform?.request?.(encrypted) || encrypted;
        },
        response: (data) => {
          const decrypted = { ...data };
          if (decrypted.items) {
            decrypted.items = decrypted.items.map((item: any) => {
              const decryptedItem = { ...item };
              encryptFields.forEach((field) => {
                if (decryptedItem[field]) {
                  try {
                    decryptedItem[field] = atob(decryptedItem[field]);
                  } catch (e) {
                    // 解密失败，保持原值
                  }
                }
              });
              return decryptedItem;
            });
          }
          return config.dataTransform?.response?.(decrypted) || decrypted;
        },
      },
    };
  },
};

/**
 * 字段脱敏插件
 * 列表中隐藏敏感信息
 */
export const maskPlugin: CrudPlugin = {
  name: 'mask',
  version: '1.0.0',
  install: (config) => ({
    ...config,
    dataTransform: {
      ...config.dataTransform,
      response: (data) => {
        if (data.items) {
          data.items = data.items.map((item: any) => {
            const masked = { ...item };
            // 手机号脱敏
            if (masked.mobile) {
              masked.mobile = masked.mobile.replace(
                /(\d{3})\d{4}(\d{4})/,
                '$1****$2'
              );
            }
            // 身份证脱敏
            if (masked.id_card) {
              masked.id_card = masked.id_card.replace(
                /(\d{6})\d{8}(\d{4})/,
                '$1********$2'
              );
            }
            // 邮箱脱敏
            if (masked.email) {
              masked.email = masked.email.replace(/(.{2}).*(@.*)/, '$1***$2');
            }
            return masked;
          });
        }
        return config.dataTransform?.response?.(data) || data;
      },
    },
  }),
};

/**
 * 自动保存插件
 * 表单自动保存草稿
 */
export const autoSavePlugin: CrudPlugin = {
  name: 'autoSave',
  version: '1.0.0',
  install: (config) => {
    const draftKey = `crud_draft_${config.api}`;
    let saveTimer: any;

    return {
      ...config,
      events: {
        ...config.events,
        onInit: () => {
          // 恢复草稿
          const draft = localStorage.getItem(draftKey);
          if (draft) {
            console.log('发现草稿数据:', JSON.parse(draft));
          }
          config.events?.onInit?.(config);
        },
        onAdd: async (data) => {
          // 保存草稿
          clearTimeout(saveTimer);
          saveTimer = setTimeout(() => {
            localStorage.setItem(draftKey, JSON.stringify(data));
          }, 1000);
          await config.events?.onAdd?.(data);
        },
        onAddSuccess: () => {
          // 清除草稿
          localStorage.removeItem(draftKey);
          config.events?.onAddSuccess?.(config);
        },
      },
    };
  },
};

// 注册所有内置插件
crudPluginManager.register(softDeletePlugin);
crudPluginManager.register(auditLogPlugin);
crudPluginManager.register(cachePlugin);
crudPluginManager.register(optimisticLockPlugin);
crudPluginManager.register(encryptPlugin);
crudPluginManager.register(maskPlugin);
crudPluginManager.register(autoSavePlugin);

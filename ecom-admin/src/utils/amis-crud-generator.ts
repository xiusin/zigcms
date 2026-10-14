/**
 * Amis CRUD 配置生成器
 * 根据字段配置自动生成完整的 CRUD Schema
 * 支持字典数据自动加载、缓存和映射
 */

export interface FieldConfig {
  name: string;
  label: string;
  type:
    | 'text'
    | 'number'
    | 'email'
    | 'phone'
    | 'select'
    | 'date'
    | 'datetime'
    | 'switch'
    | 'textarea'
    | 'image'
    | 'file'
    | 'radio'
    | 'checkbox'
    | 'color';
  dict?: string;
  dictOptions?: Array<{ label: string; value: any }>;
  required?: boolean;
  searchable?: boolean;
  sortable?: boolean;
  width?: number;
  placeholder?: string;
  quickEdit?: boolean;
  editable?: boolean; // 行内编辑
  hidden?: boolean;
  hideInForm?: boolean;
  hideInFilter?: boolean;
  defaultValue?: any;
  multiple?: boolean;
  format?: string;
  maxLength?: number;
  min?: number;
  max?: number;
  // 关联数据
  relation?: {
    api: string;
    labelField: string;
    valueField: string;
    searchable?: boolean;
    pagination?: boolean;
  };
}

export interface CrudConfig {
  title: string;
  api: string;
  fields: FieldConfig[];
  idField?: string;
  enableAdd?: boolean;
  enableEdit?: boolean;
  enableDelete?: boolean;
  enableBulk?: boolean;
  enableFilter?: boolean;
  pageSize?: number;
  perPageAvailable?: number[];
  // 第一阶段功能
  editMode?: 'modal' | 'drawer' | 'inline'; // 编辑模式
  columnSettings?: boolean; // 列配置
  export?: {
    enabled?: boolean;
    formats?: Array<'excel' | 'csv' | 'pdf'>;
    filename?: string;
  };
  import?: {
    enabled?: boolean;
    template?: string;
  };
  headerToolbar?: any[]; // 自定义工具栏
  // 第二阶段功能
  virtual?: boolean; // 虚拟滚动
  virtualThreshold?: number; // 虚拟滚动阈值
  draggable?: boolean; // 拖拽排序
  dragHandle?: boolean; // 显示拖拽手柄
  onDragEnd?: (from: number, to: number) => void; // 拖拽结束回调
  bulkActions?: Array<{
    label: string;
    action: string;
    confirm?: boolean;
    api?: string;
    form?: FieldConfig[];
  }>; // 批量操作配置
  // 第三阶段功能
  statistics?: Array<{
    label: string;
    field: string;
    type: 'count' | 'sum' | 'avg' | 'max' | 'min';
    format?: 'number' | 'money' | 'percent';
  }>; // 统计卡片
  charts?: {
    enabled?: boolean;
    types?: Array<'line' | 'bar' | 'pie'>;
    position?: 'top' | 'bottom';
  }; // 图表
  tree?: {
    enabled?: boolean;
    parentField?: string;
    childrenField?: string;
    expandLevel?: number;
  }; // 树形数据
  permissions?: {
    add?: string;
    edit?: string;
    delete?: string;
    export?: string;
    import?: string;
    rowPermissions?: (row: any) => {
      edit?: boolean;
      delete?: boolean;
    };
  }; // 权限控制
  responsive?: boolean; // 响应式布局
  // 业务交互功能
  events?: {
    onInit?: (data: any) => void; // 初始化完成
    onLoad?: (data: any) => void; // 数据加载完成
    onAdd?: (data: any) => void | Promise<void>; // 新增前
    onAddSuccess?: (data: any) => void; // 新增成功
    onEdit?: (data: any) => void | Promise<void>; // 编辑前
    onEditSuccess?: (data: any) => void; // 编辑成功
    onDelete?: (data: any) => boolean | Promise<boolean>; // 删除前确认
    onDeleteSuccess?: (data: any) => void; // 删除成功
    onBulkAction?: (action: string, data: any[]) => void; // 批量操作
    onRowClick?: (row: any) => void; // 行点击
    onSelectionChange?: (rows: any[]) => void; // 选择变化
  };
  dataTransform?: {
    request?: (data: any) => any; // 请求数据转换
    response?: (data: any) => any; // 响应数据转换
  };
  linkage?: {
    // 数据联动
    source?: string; // 数据源字段
    target?: string; // 目标字段
    api?: string; // 联动 API
    condition?: (row: any) => boolean; // 联动条件
  }[];
  validation?: {
    // 自定义验证
    rules?: Record<string, (value: any, data: any) => string | undefined>;
  };
  customActions?: Array<{
    // 自定义操作按钮
    label: string;
    icon?: string;
    level?: 'primary' | 'success' | 'warning' | 'danger' | 'link';
    position?: 'toolbar' | 'row'; // 工具栏或行操作
    visible?: (row?: any) => boolean;
    className?: string;
    actionType?: 'dialog' | 'drawer' | 'ajax' | 'link' | 'url';
    dialog?: any;
    drawer?: any;
    api?: string;
    confirmText?: string;
    link?: string;
    url?: string;
    visibleOn?: string;
    hiddenOn?: string;
    onClick?: (row?: any) => void | Promise<void>;
  }>;
}

/**
 * 字典数据缓存类
 */
class DictCache {
  private cache: Map<string, any[]> = new Map();

  private loading: Map<string, Promise<any[]>> = new Map();

  async get(dictCode: string): Promise<any[]> {
    if (this.cache.has(dictCode)) {
      return this.cache.get(dictCode) || [];
    }

    if (this.loading.has(dictCode)) {
      return this.loading.get(dictCode) || Promise.resolve([]);
    }

    const loadPromise = this.loadDict(dictCode);
    this.loading.set(dictCode, loadPromise);

    try {
      const data = await loadPromise;
      this.cache.set(dictCode, data);
      return data;
    } finally {
      this.loading.delete(dictCode);
    }
  }

  // eslint-disable-next-line class-methods-use-this
  private async loadDict(dictCode: string): Promise<any[]> {
    try {
      const response = await fetch(
        `/api/system/dict/items?dict_code=${dictCode}`
      );
      const result = await response.json();

      if (result.code !== 0) {
        console.error(`获取字典数据失败: ${dictCode}`, result.message);
        return [];
      }

      const items = result.data?.list || [];
      return items.map((item: any) => ({
        label: item.item_name,
        value: item.item_value,
        ...item,
      }));
    } catch (error) {
      console.error(`获取字典数据异常: ${dictCode}`, error);
      return [];
    }
  }

  clear(dictCode?: string) {
    if (dictCode) {
      this.cache.delete(dictCode);
    } else {
      this.cache.clear();
    }
  }

  async preload(dictCodes: string[]) {
    await Promise.all(dictCodes.map((code) => this.get(code)));
  }
}

/**
 * 生成统计卡片
 */
function generateStatistics(
  statistics: CrudConfig['statistics'],
  api: string
): any {
  if (!statistics || statistics.length === 0) return null;

  return {
    type: 'cards',
    className: 'mb-4',
    columnsCount: statistics.length > 4 ? 4 : statistics.length,
    card: {
      body: statistics.map((stat) => ({
        type: 'container',
        body: [
          {
            type: 'tpl',
            tpl: stat.label,
            className: 'text-muted',
          },
          {
            type: 'tpl',
            // eslint-disable-next-line no-template-curly-in-string
            tpl: `<%= ${stat.field} %>`,
            className: 'text-lg font-bold',
          },
        ],
      })),
    },
    source: {
      method: 'get',
      url: `${api}/statistics`,
    },
  };
}

/**
 * 生成图表
 */
function generateCharts(charts: CrudConfig['charts'], api: string): any {
  if (!charts?.enabled) return null;

  const chartTypes = charts.types || ['line'];
  const chartConfigs = chartTypes.map((type) => {
    let titleText = '趋势图';
    if (type === 'bar') titleText = '柱状图';
    if (type === 'pie') titleText = '饼图';

    const config: any = {
      type: 'chart',
      api: `${api}/chart?type=${type}`,
      config: {
        title: { text: titleText },
        tooltip: {},
        legend: {},
      },
    };

    if (type === 'pie') {
      config.config.series = [{ type: 'pie' }];
    } else {
      config.config.xAxis = { type: 'category' };
      config.config.yAxis = {};
      config.config.series = [{ type }];
    }

    return config;
  });

  return {
    type: 'grid',
    className: 'mb-4',
    columns: chartConfigs,
  };
}

const dictCache = new DictCache();

function generateFormItem(field: FieldConfig): any {
  const base = {
    name: field.name,
    label: field.label,
    required: field.required,
    placeholder: field.placeholder || `请输入${field.label}`,
    value: field.defaultValue,
  };

  switch (field.type) {
    case 'text':
      return { ...base, type: 'input-text', maxLength: field.maxLength };
    case 'number':
      return { ...base, type: 'input-number', min: field.min, max: field.max };
    case 'email':
      return { ...base, type: 'input-email', validations: { isEmail: true } };
    case 'phone':
      return {
        ...base,
        type: 'input-text',
        validations: { isPhoneNumber: true },
      };
    case 'select': {
      let source;
      if (field.relation) {
        source = {
          method: 'get',
          url: field.relation.api,
          adaptor: `
            const items = payload.data?.list || payload.data?.items || [];
            return {
              options: items.map(item => ({
                label: item.${field.relation.labelField},
                value: item.${field.relation.valueField}
              }))
            };
          `,
        };
      } else if (field.dict) {
        source = {
          method: 'get',
          url: `/api/system/dict/items?dict_code=${field.dict}`,
          adaptor: `
            const items = payload.data?.list || [];
            return {
              options: items.map(item => ({
                label: item.item_name,
                value: item.item_value
              }))
            };
          `,
        };
      }

      return {
        ...base,
        type: 'select',
        multiple: field.multiple,
        source,
        options: field.dictOptions,
        searchable: field.relation?.searchable,
        autoComplete: field.relation
          ? {
              method: 'get',
              url: `${field.relation.api}?keyword=$term`,
            }
          : undefined,
      };
    }
    case 'radio':
      return {
        ...base,
        type: 'radios',
        source: field.dict
          ? {
              method: 'get',
              url: `/api/system/dict/items?dict_code=${field.dict}`,
              adaptor: `
                const items = payload.data?.list || [];
                return {
                  options: items.map(item => ({
                    label: item.item_name,
                    value: item.item_value
                  }))
                };
              `,
            }
          : undefined,
        options: field.dictOptions,
      };
    case 'checkbox':
      return {
        ...base,
        type: 'checkboxes',
        source: field.dict
          ? {
              method: 'get',
              url: `/api/system/dict/items?dict_code=${field.dict}`,
              adaptor: `
                const items = payload.data?.list || [];
                return {
                  options: items.map(item => ({
                    label: item.item_name,
                    value: item.item_value
                  }))
                };
              `,
            }
          : undefined,
        options: field.dictOptions,
      };
    case 'date':
      return {
        ...base,
        type: 'input-date',
        format: field.format || 'YYYY-MM-DD',
      };
    case 'datetime':
      return {
        ...base,
        type: 'input-datetime',
        format: field.format || 'YYYY-MM-DD HH:mm:ss',
      };
    case 'switch':
      return {
        ...base,
        type: 'switch',
        trueValue: 1,
        falseValue: 0,
        value: field.defaultValue ?? 1,
      };
    case 'textarea':
      return {
        ...base,
        type: 'textarea',
        maxLength: field.maxLength || 500,
      };
    case 'image':
      return {
        ...base,
        type: 'input-image',
        limit: 1,
        receiver: '/api/upload/image',
      };
    case 'file':
      return {
        ...base,
        type: 'input-file',
        maxSize: 10485760,
        receiver: '/api/upload/file',
      };
    case 'color':
      return {
        ...base,
        type: 'input-color',
        format: field.format || 'hex',
        presetColors: [
          '#1677ff',
          '#00b42a',
          '#ff7d00',
          '#f53f3f',
          '#722ed1',
          '#0fc6c2',
          '#f5319d',
          '#3491fa',
          '#14c9c9',
          '#f759ab',
        ],
      };
    default:
      return { ...base, type: 'input-text' };
  }
}

/**
 * 生成快速编辑配置
 */
function generateQuickEdit(field: FieldConfig): any {
  // 对于 switch 类型，保持点击即切换
  if (field.type === 'switch') {
    return {
      type: 'switch',
      trueValue: 1,
      falseValue: 0,
      quickEdit: {
        mode: 'inline',
        saveImmediately: true,
        // eslint-disable-next-line no-template-curly-in-string
        api: 'put:${api}/${id}',
        type: 'switch',
        trueValue: 1,
        falseValue: 0,
      },
    };
  }

  // 其他类型使用 popOver 模式，需要点击才能编辑
  const quickEditBase = {
    mode: 'popOver',
    saveImmediately: {
      // eslint-disable-next-line no-template-curly-in-string
      api: 'put:${api}/${id}',
    },
    popOverClassName: 'quick-edit-popover',
  };

  switch (field.type) {
    case 'text':
      return {
        quickEdit: {
          ...quickEditBase,
          type: 'input-text',
          placeholder: `请输入${field.label}`,
        },
        className: 'editable-cell',
      };
    case 'number':
      return {
        quickEdit: {
          ...quickEditBase,
          type: 'input-number',
          placeholder: `请输入${field.label}`,
        },
        className: 'editable-cell',
      };
    case 'select':
      return {
        type: 'mapping',
        quickEdit: {
          ...quickEditBase,
          type: 'select',
          placeholder: `请选择${field.label}`,
          source: field.dict
            ? `/api/system/dict/items?dict_code=${field.dict}`
            : undefined,
          options: field.dictOptions,
        },
        source: field.dict
          ? {
              method: 'get',
              url: `/api/system/dict/items?dict_code=${field.dict}`,
              adaptor: `
                const items = payload.data?.list || [];
                const map = {};
                items.forEach(item => {
                  map[item.item_value] = item.item_name;
                });
                return { map };
              `,
            }
          : undefined,
        className: 'editable-cell',
      };
    case 'date':
      return {
        quickEdit: {
          ...quickEditBase,
          type: 'input-date',
          format: field.format || 'YYYY-MM-DD',
          placeholder: `请选择${field.label}`,
        },
        className: 'editable-cell',
      };
    case 'datetime':
      return {
        quickEdit: {
          ...quickEditBase,
          type: 'input-datetime',
          format: field.format || 'YYYY-MM-DD HH:mm:ss',
          placeholder: `请选择${field.label}`,
        },
        className: 'editable-cell',
      };
    default:
      return null;
  }
}

function generateColumn(field: FieldConfig): any {
  const base = {
    name: field.name,
    label: field.label,
    width: field.width,
    sortable: field.sortable,
  };

  // 行内编辑支持
  if (field.editable || field.quickEdit) {
    const quickEdit = generateQuickEdit(field);
    if (quickEdit) {
      return { ...base, ...quickEdit };
    }
  }

  switch (field.type) {
    case 'select':
    case 'radio':
      return {
        ...base,
        type: 'mapping',
        source: field.dict
          ? {
              method: 'get',
              url: `/api/system/dict/items?dict_code=${field.dict}`,
              adaptor: `
                const items = payload.data?.list || [];
                const map = {};
                items.forEach(item => {
                  map[item.item_value] = item.item_name;
                });
                return { map };
              `,
            }
          : undefined,
        map: field.dictOptions?.reduce((acc, opt) => {
          acc[opt.value] = opt.label;
          return acc;
        }, {} as Record<string, string>),
      };
    case 'checkbox':
      return {
        ...base,
        type: 'each',
        items: {
          type: 'mapping',
          source: field.dict
            ? {
                method: 'get',
                url: `/api/system/dict/items?dict_code=${field.dict}`,
                adaptor: `
                  const items = payload.data?.list || [];
                  const map = {};
                  items.forEach(item => {
                    map[item.item_value] = item.item_name;
                  });
                  return { map };
                `,
              }
            : undefined,
          map: field.dictOptions?.reduce((acc, opt) => {
            acc[opt.value] = opt.label;
            return acc;
          }, {} as Record<string, string>),
        },
      };
    case 'date':
      return {
        ...base,
        type: 'date',
        format: field.format || 'YYYY-MM-DD',
      };
    case 'datetime':
      return {
        ...base,
        type: 'datetime',
        format: field.format || 'YYYY-MM-DD HH:mm:ss',
      };
    case 'switch':
      return {
        ...base,
        type: 'switch',
        trueValue: 1,
        falseValue: 0,
        quickEdit: field.quickEdit
          ? {
              mode: 'inline',
              type: 'switch',
              trueValue: 1,
              falseValue: 0,
              saveImmediately: true,
            }
          : undefined,
      };
    case 'image':
      return {
        ...base,
        type: 'image',
        thumbMode: 'cover',
        thumbRatio: '1:1',
        enlargeAble: true,
      };
    case 'color':
      return {
        ...base,
        type: 'tpl',
        tpl: `<span style="display:inline-flex;align-items:center;gap:6px;">
          <span style="width:20px;height:20px;border-radius:4px;background-color:${`\${${field.name}}`};border:1px solid #e5e6eb;"></span>
          <span>${`\${${field.name}}`}</span>
        </span>`,
      };
    default:
      return base;
  }
}

function generateFilter(fields: FieldConfig[]): any {
  const filterFields = fields.filter(
    (f) => f.searchable && !f.hideInFilter && !f.hidden
  );

  if (filterFields.length === 0) return null;

  return {
    title: '筛选',
    submitText: '查询',
    body: filterFields.map((field) => {
      const item = generateFormItem(field);
      item.required = false;
      return item;
    }),
  };
}

function generateForm(fields: FieldConfig[], isEdit = false): any {
  const formFields = fields.filter((f) => !f.hideInForm && !f.hidden);

  return {
    type: 'form',
    // eslint-disable-next-line no-template-curly-in-string
    api: isEdit ? 'put:${api}/${id}' : 'post:${api}',
    body: formFields.map((field) => generateFormItem(field)),
  };
}

export async function generateCrudSchema(config: CrudConfig): Promise<any> {
  const {
    title,
    api,
    fields,
    idField = 'id',
    enableAdd = true,
    enableEdit = true,
    enableDelete = true,
    enableBulk = true,
    enableFilter = true,
    pageSize = 10,
    perPageAvailable = [10, 20, 50, 100],
    editMode = 'modal',
    columnSettings = true,
    export: exportConfig,
    import: importConfig,
    headerToolbar: customHeaderToolbar,
    // 第二阶段
    virtual = false,
    draggable = false,
    dragHandle = true,
    bulkActions: customBulkActions,
    // 第三阶段
    statistics,
    charts,
    tree,
    permissions,
    responsive = false,
    // 自定义操作
    customActions,
  } = config;

  const dictCodes = fields.filter((f) => f.dict).map((f) => f.dict as string);
  if (dictCodes.length > 0) {
    await dictCache.preload(dictCodes);
  }

  // 拖拽排序支持
  let columns = fields
    .filter((f) => !f.hidden)
    .map((field) => generateColumn(field));

  if (draggable && dragHandle) {
    columns = [
      {
        type: 'text',
        label: '',
        width: 50,
        className: 'drag-handle',
        body: '<i class="fa fa-bars"></i>',
      },
      ...columns,
    ];
  }

  const operationButtons: any[] = [];
  if (enableEdit) {
    const editButton: any = {
      label: '编辑',
      type: 'button',
      level: 'link',
    };

    // 权限控制
    if (permissions?.edit) {
      // eslint-disable-next-line no-template-curly-in-string
      editButton.visibleOn = `this.permissions && this.permissions.includes('${permissions.edit}')`;
    }
    if (permissions?.rowPermissions) {
      // eslint-disable-next-line no-template-curly-in-string
      editButton.hiddenOn = '${!canEdit}';
    }

    if (editMode === 'drawer') {
      editButton.actionType = 'drawer';
      editButton.drawer = {
        title: `编辑${title}`,
        size: 'lg',
        resizable: true,
        body: generateForm(fields, true),
      };
    } else {
      editButton.actionType = 'dialog';
      editButton.dialog = {
        title: `编辑${title}`,
        size: 'full',
        body: generateForm(fields, true),
      };
    }

    operationButtons.push(editButton);
  }
  if (enableDelete) {
    const deleteButton: any = {
      label: '删除',
      type: 'button',
      level: 'link',
      className: 'text-danger',
      actionType: 'ajax',
      confirmText: `确定要删除该${title}吗？`,
      // eslint-disable-next-line no-template-curly-in-string
      api: `delete:${api}/$${idField}`,
    };

    // 权限控制
    if (permissions?.delete) {
      // eslint-disable-next-line no-template-curly-in-string
      deleteButton.visibleOn = `this.permissions && this.permissions.includes('${permissions.delete}')`;
    }
    if (permissions?.rowPermissions) {
      // eslint-disable-next-line no-template-curly-in-string
      deleteButton.hiddenOn = '${!canDelete}';
    }

    operationButtons.push(deleteButton);
  }

  // 添加自定义操作按钮
  if (customActions && customActions.length > 0) {
    customActions.forEach((action, index) => {
      if (action.position === 'row' || !action.position) {
        const button: any = {
          label: action.label,
          type: 'button',
          level: action.level || 'link',
        };

        if (action.icon) {
          button.icon = action.icon;
        }

        if (action.className) {
          button.className = action.className;
        }

        if (action.actionType === 'dialog' && action.dialog) {
          button.actionType = 'dialog';
          button.dialog = action.dialog;
        } else if (action.actionType === 'drawer' && action.drawer) {
          button.actionType = 'drawer';
          button.drawer = action.drawer;
        } else if (action.actionType === 'ajax' && action.api) {
          button.actionType = 'ajax';
          button.api = action.api;
          button.confirmText = action.confirmText;
        } else if (action.actionType === 'link' && action.link) {
          button.actionType = 'link';
          button.link = action.link;
        } else if (action.actionType === 'url' && action.url) {
          button.actionType = 'url';
          button.url = action.url;
        } else {
          // 使用 amis 事件机制
          button.actionType = 'dispatchEvent';
          button.events = {
            click: {
              actions: [
                {
                  actionType: 'custom',
                  script: `const event = new CustomEvent('amis:customAction', { detail: { action: '${action.label}', index: ${index}, row: event.data } }); window.dispatchEvent(event);`,
                },
              ],
            },
          };
        }

        if (action.visibleOn) {
          button.visibleOn = action.visibleOn;
        }
        if (action.hiddenOn) {
          button.hiddenOn = action.hiddenOn;
        }

        operationButtons.push(button);
      }
    });
  }

  if (operationButtons.length > 0) {
    columns.push({
      type: 'operation',
      label: '操作',
      width: 150,
      buttons: operationButtons,
    });
  }

  // 构建工具栏
  const headerToolbar: any[] = customHeaderToolbar || [];

  if (!customHeaderToolbar) {
    // 新增按钮
    if (enableAdd) {
      const addButton: any = {
        type: 'button',
        label: `新增${title}`,
        level: 'primary',
        icon: 'fa fa-plus',
      };

      if (editMode === 'drawer') {
        addButton.actionType = 'drawer';
        addButton.drawer = {
          title: `新增${title}`,
          size: 'lg',
          resizable: true,
          body: generateForm(fields, false),
        };
      } else {
        addButton.actionType = 'dialog';
        addButton.dialog = {
          title: `新增${title}`,
          size: 'full',
          body: generateForm(fields, false),
        };
      }

      headerToolbar.push(addButton);
    }

    // 导入按钮
    if (importConfig?.enabled) {
      headerToolbar.push({
        type: 'button',
        label: '导入',
        icon: 'fa fa-upload',
        actionType: 'dialog',
        dialog: {
          title: '导入数据',
          size: 'md',
          body: {
            type: 'form',
            api: `post:${api}/import`,
            body: [
              {
                type: 'alert',
                level: 'info',
                body: '请先下载模板，按照模板格式填写数据后上传',
              },
              importConfig.template
                ? {
                    type: 'button',
                    label: '下载模板',
                    level: 'link',
                    url: importConfig.template,
                    blank: true,
                  }
                : null,
              {
                type: 'input-file',
                name: 'file',
                label: '选择文件',
                accept: '.xlsx,.xls,.csv',
                required: true,
                receiver: `${api}/import`,
              },
            ].filter(Boolean),
          },
        },
      });
    }

    // 导出按钮
    if (exportConfig?.enabled) {
      const formats = exportConfig.formats || ['excel'];
      if (formats.length === 1) {
        headerToolbar.push({
          type: 'button',
          label: '导出',
          icon: 'fa fa-download',
          actionType: 'download',
          api: `${api}/export?format=${formats[0]}`,
        });
      } else {
        headerToolbar.push({
          type: 'dropdown-button',
          label: '导出',
          icon: 'fa fa-download',
          buttons: formats.map((format) => ({
            type: 'button',
            label: format.toUpperCase(),
            actionType: 'download',
            api: `${api}/export?format=${format}`,
          })),
        });
      }
    }

    // 批量操作
    if (enableBulk) {
      headerToolbar.push('bulkActions');
    }

    // 列配置
    if (columnSettings) {
      headerToolbar.push('columns-toggler');
    }

    // 刷新按钮
    headerToolbar.push('reload');
  }

  // 批量操作配置
  const bulkActionsConfig: any[] = [];
  if (customBulkActions && customBulkActions.length > 0) {
    customBulkActions.forEach((action) => {
      const bulkAction: any = {
        label: action.label,
        actionType: action.form ? 'dialog' : 'ajax',
      };

      if (action.form) {
        bulkAction.dialog = {
          title: action.label,
          size: 'md',
          body: {
            type: 'form',
            api: action.api || `post:${api}/bulk/${action.action}`,
            body: action.form.map((field) => generateFormItem(field)),
          },
        };
      } else {
        bulkAction.api = action.api || `post:${api}/bulk/${action.action}`;
        if (action.confirm) {
          bulkAction.confirmText = `确定要执行该操作吗？`;
        }
      }

      bulkActionsConfig.push(bulkAction);
    });
  } else if (enableBulk) {
    bulkActionsConfig.push({
      label: '批量删除',
      actionType: 'ajax',
      api: `delete:${api}/batch`,
      confirmText: '确定要删除选中的数据吗？',
    });
  }

  // 构建页面 body
  const pageBody: any[] = [];

  // 统计卡片
  if (statistics) {
    const statsCard = generateStatistics(statistics, api);
    if (statsCard) pageBody.push(statsCard);
  }

  // 图表
  if (charts?.enabled) {
    const chartsGrid = generateCharts(charts, api);
    if (chartsGrid) pageBody.push(chartsGrid);
  }

  // CRUD 表格
  const crudConfig: any = {
    type: 'crud',
    syncLocation: false,
    // eslint-disable-next-line no-template-curly-in-string
    api: `${api}?page=$page&perPage=$perPage`,
    headerToolbar,
    filter: enableFilter ? generateFilter(fields) : undefined,
    columns,
    perPageAvailable,
    perPage: pageSize,
    quickSaveApi: `put:${api}/$${idField}`,
    quickSaveItemApi: `put:${api}/$${idField}`,
    // 虚拟滚动
    autoFillHeight: virtual,
    // 拖拽排序
    draggable,
    itemDraggableOn: draggable,
    saveOrderApi: draggable ? `post:${api}/order` : undefined,
    bulkActions: bulkActionsConfig.length > 0 ? bulkActionsConfig : undefined,
  };

  // 树形数据 - Amis CRUD 不支持树形模式，改用普通表格
  // 如需树形展示，请使用独立的 tree 组件
  if (tree?.enabled) {
    // 仅保留配置，不改变 mode
    crudConfig.footable = false;
  }

  // 响应式
  if (responsive) {
    crudConfig.footerToolbar = ['switch-per-page', 'pagination'];
    crudConfig.autoGenerateFilter = true;
  }

  pageBody.push(crudConfig);

  return {
    type: 'page',
    title,
    body: pageBody.length === 1 ? pageBody[0] : pageBody,
  };
}

export function clearDictCache(dictCode?: string) {
  dictCache.clear(dictCode);
}

export function preloadDictData(dictCodes: string[]) {
  return dictCache.preload(dictCodes);
}

/**
 * Amis 类型定义
 */

/** Amis Schema 基本结构 */
export interface AmisSchema {
  /** 页面类型 */
  type: string;
  /** 标题 */
  title?: string;
  /** 内容区域 */
  body?: any;
  /** 工具栏 */
  toolbar?: any;
  /** 底部 */
  footer?: any;
  /** 样式 */
  className?: string;
  /** 其他属性 */
  [key: string]: any;
}

/** 页面配置 */
export interface PageConfig {
  id?: number;
  /** 页面名称 */
  page_name: string;
  /** 页面编码 */
  page_code: string;
  /** 页面描述 */
  description?: string;
  /** Schema JSON */
  schema_json: AmisSchema;
  /** 页面分类 */
  category_id?: number;
  /** 状态 */
  status: number;
  /** 创建人 */
  create_user_id?: number;
  /** 创建时间 */
  created_at?: string;
  /** 更新时间 */
  updated_at?: string;
}

/** 页面分类 */
export interface PageCategory {
  id: number;
  /** 分类名称 */
  category_name: string;
  /** 分类编码 */
  category_code: string;
  /** 父级ID */
  parent_id?: number;
  /** 排序 */
  sort?: number;
  /** 状态 */
  status: number;
}

/** Amis 组件属性 */
export interface AmisProps {
  /** Schema 配置 */
  schema?: AmisSchema;
  /** 主题 */
  theme?: 'cxd' | 'dark' | 'antd';
  /** 容器ID */
  containerId?: string;
}

/** Amis 编辑器属性 */
export interface AmisEditorProps {
  /** Schema 配置 */
  modelValue?: AmisSchema;
  /** 主题 */
  theme?: 'cxd' | 'dark' | 'antd';
}

/** 常用 Schema 模板 */
export const SchemaTemplates = {
  /** 空页面 */
  blankPage: {
    type: 'page',
    title: '新页面',
    body: 'Hello World',
  } as AmisSchema,

  /** 表单页面 */
  formPage: {
    type: 'page',
    title: '表单页面',
    body: {
      type: 'form',
      mode: 'horizontal',
      api: '/api/save',
      body: [
        {
          type: 'input-text',
          name: 'name',
          label: '名称',
          required: true,
        },
        {
          type: 'input-text',
          name: 'email',
          label: '邮箱',
          required: true,
        },
      ],
      actions: [
        {
          type: 'submit',
          label: '提交',
          level: 'primary',
        },
        {
          type: 'reset',
          label: '重置',
        },
      ],
    },
  } as AmisSchema,

  /** 表格页面 */
  tablePage: {
    type: 'page',
    title: '表格页面',
    body: {
      type: 'crud',
      api: '/api/list',
      columns: [
        {
          name: 'id',
          label: 'ID',
        },
        {
          name: 'name',
          label: '名称',
        },
        {
          name: 'status',
          label: '状态',
        },
        {
          type: 'operation',
          label: '操作',
          buttons: [
            {
              label: '编辑',
              type: 'button',
              actionType: 'dialog',
              dialog: {
                title: '编辑',
                body: {
                  type: 'form',
                  body: [
                    {
                      type: 'input-text',
                      name: 'name',
                      label: '名称',
                    },
                  ],
                },
              },
            },
            {
              label: '删除',
              type: 'button',
              level: 'danger',
            },
          ],
        },
      ],
    },
  } as AmisSchema,

  /** 详情页面 */
  detailPage: {
    type: 'page',
    title: '详情页面',
    body: {
      type: 'detail',
      api: '/api/detail',
      mode: 'horizontal',
      body: [
        {
          name: 'id',
          label: 'ID',
        },
        {
          name: 'name',
          label: '名称',
        },
        {
          name: 'email',
          label: '邮箱',
        },
        {
          name: 'status',
          label: '状态',
        },
      ],
    },
  } as AmisSchema,
};

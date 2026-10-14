<template>
  <div class="cms-model-page">
    <AmisRenderer :schema="schema" />
  </div>
</template>

<script setup lang="ts">
  import AmisRenderer from '@/components/amis/index.vue';

  const schema = {
    type: 'page',
    title: '内容模型管理',
    subTitle: '定义内容结构，配置字段类型和验证规则',
    body: {
      type: 'crud',
      api: '/api/cms/models',
      syncLocation: false,
      perPageAvailable: [10, 20, 50, 100],
      defaultParams: {
        pageSize: 20,
      },
      headerToolbar: [
        {
          type: 'button',
          label: '新增模型',
          actionType: 'dialog',
          level: 'primary',
          icon: 'fa fa-plus',
          dialog: {
            title: '新增内容模型',
            size: 'lg',
            body: {
              type: 'form',
              api: 'post:/api/cms/models',
              body: [
                {
                  type: 'input-text',
                  name: 'name',
                  label: '模型名称',
                  required: true,
                  placeholder: '如：文章、产品、案例',
                  validations: {
                    maxLength: 50,
                  },
                },
                {
                  type: 'input-text',
                  name: 'slug',
                  label: '模型标识',
                  required: true,
                  placeholder: '英文标识，如：article',
                  validations: {
                    isAlphanumeric: true,
                    maxLength: 50,
                  },
                  description: '创建后不可修改，用于 API 路径和数据表名',
                },
                {
                  type: 'textarea',
                  name: 'description',
                  label: '模型描述',
                  placeholder: '简要描述该模型的用途',
                  maxLength: 500,
                },
                {
                  type: 'group',
                  label: '功能配置',
                  body: [
                    {
                      type: 'switch',
                      name: 'enable_category',
                      label: '启用分类',
                      value: true,
                      description: '是否为该模型启用分类功能',
                    },
                    {
                      type: 'switch',
                      name: 'enable_tag',
                      label: '启用标签',
                      value: true,
                      description: '是否为该模型启用标签功能',
                    },
                    {
                      type: 'switch',
                      name: 'enable_version',
                      label: '启用版本控制',
                      value: false,
                      description: '保存内容修改历史，支持版本回滚',
                    },
                    {
                      type: 'switch',
                      name: 'enable_i18n',
                      label: '启用多语言',
                      value: false,
                      description: '支持内容多语言翻译',
                    },
                  ],
                },
              ],
            },
          },
        },
        'reload',
        'filter-toggler',
      ],
      filter: {
        body: [
          {
            type: 'input-text',
            name: 'keyword',
            label: '关键词',
            placeholder: '搜索模型名称或标识',
            clearable: true,
          },
          {
            type: 'select',
            name: 'status',
            label: '状态',
            options: [
              { label: '全部', value: '' },
              { label: '启用', value: 1 },
              { label: '禁用', value: 0 },
            ],
          },
        ],
      },
      footerToolbar: ['statistics', 'switch-per-page', 'pagination'],
      columns: [
        {
          name: 'id',
          label: 'ID',
          width: 80,
          sortable: true,
        },
        {
          name: 'name',
          label: '模型名称',
          searchable: true,
        },
        {
          name: 'slug',
          label: '模型标识',
          type: 'tpl',
          tpl: '<code class="text-primary">${slug}</code>',
        },
        {
          name: 'description',
          label: '描述',
          type: 'tpl',
          tpl: '${description || "-"}',
        },
        {
          name: 'fields',
          label: '字段数量',
          type: 'tpl',
          tpl: '<span class="badge badge-info">${fields ? fields.length : 0} 个</span>',
          width: 100,
        },
        {
          name: 'content_count',
          label: '内容数量',
          type: 'tpl',
          tpl: '${content_count || 0}',
          width: 100,
        },
        {
          name: 'status',
          label: '状态',
          type: 'mapping',
          map: {
            1: '<span class="label label-success">启用</span>',
            0: '<span class="label label-default">禁用</span>',
          },
          width: 80,
        },
        {
          name: 'created_at',
          label: '创建时间',
          type: 'datetime',
          width: 180,
          sortable: true,
        },
        {
          type: 'operation',
          label: '操作',
          width: 280,
          buttons: [
            {
              type: 'button',
              label: '字段',
              level: 'link',
              icon: 'fa fa-list',
              actionType: 'drawer',
              drawer: {
                title: '字段管理 - ${name}',
                size: 'lg',
                resizable: true,
                body: {
                  type: 'service',
                  api: '/api/cms/models/${id}',
                  body: {
                    type: 'page',
                    body: [
                      {
                        type: 'alert',
                        level: 'warning',
                        body: '字段变更会影响已有数据，请谨慎操作。删除字段会同时删除该字段的所有数据。',
                      },
                      {
                        type: 'crud',
                        draggable: true,
                        syncLocation: false,
                        api: {
                          method: 'get',
                          url: '/api/cms/models/${id}',
                          adaptor:
                            'return { data: { items: payload.data.fields || [], total: (payload.data.fields || []).length } }',
                        },
                        saveOrderApi: {
                          method: 'post',
                          url: '/api/cms/models/${id}/fields/sort',
                        },
                        headerToolbar: [
                          {
                            type: 'button',
                            label: '字段模板',
                            actionType: 'drawer',
                            icon: 'fa fa-magic',
                            drawer: {
                              title: '字段模板库',
                              size: 'xl',
                              closeOnOutside: false,
                              body: {
                                type: 'page',
                                className: 'field-template-library',
                                css: {
                                  '.field-template-library': {
                                    background: '#f5f7fa',
                                    padding: '0',
                                  },
                                  '.template-header': {
                                    background:
                                      'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                                    padding: '24px',
                                    color: '#fff',
                                    marginBottom: '24px',
                                  },
                                  '.template-stats': {
                                    display: 'flex',
                                    gap: '16px',
                                    marginTop: '16px',
                                  },
                                  '.stat-item': {
                                    background: 'rgba(255,255,255,0.2)',
                                    padding: '12px 20px',
                                    borderRadius: '8px',
                                    backdropFilter: 'blur(10px)',
                                  },
                                  '.template-card': {
                                    background: '#fff',
                                    borderRadius: '12px',
                                    padding: '20px',
                                    boxShadow: '0 2px 8px rgba(0,0,0,0.08)',
                                    transition: 'all 0.3s ease',
                                    border: '1px solid #e8e8e8',
                                    height: '100%',
                                  },
                                  '.template-card:hover': {
                                    transform: 'translateY(-4px)',
                                    boxShadow: '0 8px 24px rgba(0,0,0,0.12)',
                                    borderColor: '#667eea',
                                  },
                                  '.template-icon': {
                                    width: '48px',
                                    height: '48px',
                                    borderRadius: '12px',
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'center',
                                    fontSize: '24px',
                                    marginBottom: '16px',
                                  },
                                  '.template-title': {
                                    fontSize: '16px',
                                    fontWeight: '600',
                                    color: '#1f2937',
                                    marginBottom: '8px',
                                  },
                                  '.template-key': {
                                    fontSize: '12px',
                                    color: '#667eea',
                                    background: '#f0f4ff',
                                    padding: '2px 8px',
                                    borderRadius: '4px',
                                    fontFamily: 'monospace',
                                    display: 'inline-block',
                                    marginBottom: '12px',
                                  },
                                  '.template-desc': {
                                    fontSize: '14px',
                                    color: '#6b7280',
                                    lineHeight: '1.6',
                                    marginBottom: '16px',
                                    minHeight: '44px',
                                  },
                                  '.template-meta': {
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'space-between',
                                    paddingTop: '16px',
                                    borderTop: '1px solid #f3f4f6',
                                  },
                                  '.template-type': {
                                    fontSize: '12px',
                                    padding: '4px 12px',
                                    borderRadius: '12px',
                                    fontWeight: '500',
                                  },
                                  '.tabs-container': {
                                    background: '#fff',
                                    borderRadius: '12px',
                                    padding: '24px',
                                    margin: '0 24px 24px',
                                  },
                                },
                                body: [
                                  {
                                    type: 'container',
                                    className: 'template-header',
                                    body: [
                                      {
                                        type: 'tpl',
                                        tpl: '<h2 style="margin:0;font-size:24px;font-weight:600;">字段模板库</h2>',
                                      },
                                      {
                                        type: 'tpl',
                                        tpl: '<p style="margin:8px 0 0;opacity:0.9;font-size:14px;">精选 30+ 个常用字段模板，快速构建内容模型</p>',
                                      },
                                      {
                                        type: 'container',
                                        className: 'template-stats',
                                        body: [
                                          {
                                            type: 'tpl',
                                            tpl: '<div class="stat-item"><div style="font-size:20px;font-weight:600;">30+</div><div style="font-size:12px;opacity:0.8;margin-top:4px;">模板数量</div></div>',
                                          },
                                          {
                                            type: 'tpl',
                                            tpl: '<div class="stat-item"><div style="font-size:20px;font-weight:600;">6</div><div style="font-size:12px;opacity:0.8;margin-top:4px;">分类</div></div>',
                                          },
                                          {
                                            type: 'tpl',
                                            tpl: '<div class="stat-item"><div style="font-size:20px;font-weight:600;">20+</div><div style="font-size:12px;opacity:0.8;margin-top:4px;">字段类型</div></div>',
                                          },
                                        ],
                                      },
                                    ],
                                  },
                                  {
                                    type: 'container',
                                    className: 'tabs-container',
                                    body: {
                                      type: 'tabs',
                                      tabsMode: 'line',
                                      tabs: [
                                        {
                                          title: '📝 基础字段',
                                          body: {
                                            type: 'grid',
                                            columns: [
                                              {
                                                body: {
                                                  type: 'container',
                                                  className: 'template-card',
                                                  body: [
                                                    {
                                                      type: 'tpl',
                                                      tpl: '<div class="template-icon" style="background:linear-gradient(135deg,#667eea,#764ba2);color:#fff;"><i class="fa fa-font"></i></div>',
                                                    },
                                                    {
                                                      type: 'tpl',
                                                      tpl: '<div class="template-title">标题</div>',
                                                    },
                                                    {
                                                      type: 'tpl',
                                                      tpl: '<div class="template-key">title</div>',
                                                    },
                                                    {
                                                      type: 'tpl',
                                                      tpl: '<div class="template-desc">单行文本字段，必填且可搜索，适用于文章、产品等内容的主标题</div>',
                                                    },
                                                    {
                                                      type: 'container',
                                                      className:
                                                        'template-meta',
                                                      body: [
                                                        {
                                                          type: 'tpl',
                                                          tpl: '<span class="template-type" style="background:#e0e7ff;color:#667eea;">text</span>',
                                                        },
                                                        {
                                                          type: 'button',
                                                          label: '使用',
                                                          level: 'primary',
                                                          size: 'sm',
                                                          actionType: 'dialog',
                                                          dialog: {
                                                            title:
                                                              '创建字段 - 标题',
                                                            size: 'lg',
                                                            body: {
                                                              type: 'form',
                                                              api: 'post:/api/cms/models/${model_id}/fields',
                                                              body: [
                                                                {
                                                                  type: 'input-text',
                                                                  name: 'label',
                                                                  label:
                                                                    '字段名称',
                                                                  required:
                                                                    true,
                                                                  value: '标题',
                                                                },
                                                                {
                                                                  type: 'input-text',
                                                                  name: 'key',
                                                                  label:
                                                                    '字段标识',
                                                                  required:
                                                                    true,
                                                                  value:
                                                                    'title',
                                                                },
                                                                {
                                                                  type: 'hidden',
                                                                  name: 'type',
                                                                  value: 'text',
                                                                },
                                                                {
                                                                  type: 'switch',
                                                                  name: 'required',
                                                                  label: '必填',
                                                                  value: true,
                                                                },
                                                                {
                                                                  type: 'switch',
                                                                  name: 'searchable',
                                                                  label:
                                                                    '可搜索',
                                                                  value: true,
                                                                },
                                                                {
                                                                  type: 'input-text',
                                                                  name: 'placeholder',
                                                                  label:
                                                                    '占位提示',
                                                                  value:
                                                                    '请输入标题',
                                                                },
                                                              ],
                                                            },
                                                          },
                                                        },
                                                      ],
                                                    },
                                                  ],
                                                },
                                                md: 4,
                                              },
                                              {
                                                body: {
                                                  type: 'container',
                                                  className: 'template-card',
                                                  body: [
                                                    {
                                                      type: 'tpl',
                                                      tpl: '<div class="template-icon" style="background:linear-gradient(135deg,#667eea,#764ba2);color:#fff;"><i class="fa fa-heading"></i></div>',
                                                    },
                                                    {
                                                      type: 'tpl',
                                                      tpl: '<div class="template-title">副标题</div>',
                                                    },
                                                    {
                                                      type: 'tpl',
                                                      tpl: '<div class="template-key">subtitle</div>',
                                                    },
                                                    {
                                                      type: 'tpl',
                                                      tpl: '<div class="template-desc">单行文本字段，可选，用于补充说明主标题或作为摘要</div>',
                                                    },
                                                    {
                                                      type: 'container',
                                                      className:
                                                        'template-meta',
                                                      body: [
                                                        {
                                                          type: 'tpl',
                                                          tpl: '<span class="template-type" style="background:#e0e7ff;color:#667eea;">text</span>',
                                                        },
                                                        {
                                                          type: 'button',
                                                          label: '使用',
                                                          level: 'primary',
                                                          size: 'sm',
                                                          actionType: 'dialog',
                                                          dialog: {
                                                            title:
                                                              '创建字段 - 副标题',
                                                            size: 'lg',
                                                            body: {
                                                              type: 'form',
                                                              api: 'post:/api/cms/models/${model_id}/fields',
                                                              body: [
                                                                {
                                                                  type: 'input-text',
                                                                  name: 'label',
                                                                  label:
                                                                    '字段名称',
                                                                  required:
                                                                    true,
                                                                  value:
                                                                    '副标题',
                                                                },
                                                                {
                                                                  type: 'input-text',
                                                                  name: 'key',
                                                                  label:
                                                                    '字段标识',
                                                                  required:
                                                                    true,
                                                                  value:
                                                                    'subtitle',
                                                                },
                                                                {
                                                                  type: 'hidden',
                                                                  name: 'type',
                                                                  value: 'text',
                                                                },
                                                                {
                                                                  type: 'input-text',
                                                                  name: 'placeholder',
                                                                  label:
                                                                    '占位提示',
                                                                  value:
                                                                    '请输入副标题',
                                                                },
                                                              ],
                                                            },
                                                          },
                                                        },
                                                      ],
                                                    },
                                                  ],
                                                },
                                                md: 4,
                                              },
                                              {
                                                body: {
                                                  type: 'container',
                                                  className: 'template-card',
                                                  body: [
                                                    {
                                                      type: 'tpl',
                                                      tpl: '<div class="template-icon" style="background:linear-gradient(135deg,#667eea,#764ba2);color:#fff;"><i class="fa fa-align-left"></i></div>',
                                                    },
                                                    {
                                                      type: 'tpl',
                                                      tpl: '<div class="template-title">描述</div>',
                                                    },
                                                    {
                                                      type: 'tpl',
                                                      tpl: '<div class="template-key">description</div>',
                                                    },
                                                    {
                                                      type: 'tpl',
                                                      tpl: '<div class="template-desc">多行文本字段，用于输入较长的描述性文字内容</div>',
                                                    },
                                                    {
                                                      type: 'container',
                                                      className:
                                                        'template-meta',
                                                      body: [
                                                        {
                                                          type: 'tpl',
                                                          tpl: '<span class="template-type" style="background:#e0e7ff;color:#667eea;">textarea</span>',
                                                        },
                                                        {
                                                          type: 'button',
                                                          label: '使用',
                                                          level: 'primary',
                                                          size: 'sm',
                                                          actionType: 'dialog',
                                                          dialog: {
                                                            title:
                                                              '创建字段 - 描述',
                                                            size: 'lg',
                                                            body: {
                                                              type: 'form',
                                                              api: 'post:/api/cms/models/${model_id}/fields',
                                                              body: [
                                                                {
                                                                  type: 'input-text',
                                                                  name: 'label',
                                                                  label:
                                                                    '字段名称',
                                                                  required:
                                                                    true,
                                                                  value: '描述',
                                                                },
                                                                {
                                                                  type: 'input-text',
                                                                  name: 'key',
                                                                  label:
                                                                    '字段标识',
                                                                  required:
                                                                    true,
                                                                  value:
                                                                    'description',
                                                                },
                                                                {
                                                                  type: 'hidden',
                                                                  name: 'type',
                                                                  value:
                                                                    'textarea',
                                                                },
                                                                {
                                                                  type: 'input-text',
                                                                  name: 'placeholder',
                                                                  label:
                                                                    '占位提示',
                                                                  value:
                                                                    '请输入描述',
                                                                },
                                                              ],
                                                            },
                                                          },
                                                        },
                                                      ],
                                                    },
                                                  ],
                                                },
                                                md: 4,
                                              },
                                            ],
                                            gap: 'lg',
                                          },
                                        },
                                        {
                                          title: '🖼️ 媒体字段',
                                          body: {
                                            type: 'tpl',
                                            tpl: '<div style="padding:40px;text-align:center;color:#9ca3af;">更多模板开发中...</div>',
                                          },
                                        },
                                        {
                                          title: '🔢 数值字段',
                                          body: {
                                            type: 'tpl',
                                            tpl: '<div style="padding:40px;text-align:center;color:#9ca3af;">更多模板开发中...</div>',
                                          },
                                        },
                                        {
                                          title: '📅 时间字段',
                                          body: {
                                            type: 'tpl',
                                            tpl: '<div style="padding:40px;text-align:center;color:#9ca3af;">更多模板开发中...</div>',
                                          },
                                        },
                                        {
                                          title: '✅ 选择字段',
                                          body: {
                                            type: 'tpl',
                                            tpl: '<div style="padding:40px;text-align:center;color:#9ca3af;">更多模板开发中...</div>',
                                          },
                                        },
                                        {
                                          title: '⚙️ 其他字段',
                                          body: {
                                            type: 'tpl',
                                            tpl: '<div style="padding:40px;text-align:center;color:#9ca3af;">更多模板开发中...</div>',
                                          },
                                        },
                                      ],
                                    },
                                  },
                                ],
                              },
                            },
                          },
                          {
                            type: 'button',
                            label: '导入字段',
                            actionType: 'dialog',
                            icon: 'fa fa-upload',
                            dialog: {
                              title: '导入字段配置',
                              body: {
                                type: 'form',
                                api: 'post:/api/cms/models/${id}/fields/import',
                                body: [
                                  {
                                    type: 'alert',
                                    level: 'info',
                                    body: '支持导入 JSON 格式的字段配置文件',
                                  },
                                  {
                                    type: 'input-file',
                                    name: 'file',
                                    label: '选择文件',
                                    accept: '.json',
                                    required: true,
                                  },
                                ],
                              },
                            },
                          },
                          {
                            type: 'button',
                            label: '导出字段',
                            icon: 'fa fa-download',
                            actionType: 'download',
                            api: '/api/cms/models/${id}/fields/export',
                          },
                          {
                            type: 'button',
                            label: '新增字段',
                            actionType: 'dialog',
                            level: 'primary',
                            icon: 'fa fa-plus',
                            dialog: {
                              title: '新增字段',
                              size: 'lg',
                              body: {
                                type: 'form',
                                api: 'post:/api/cms/models/${id}/fields',
                                body: [
                                  {
                                    type: 'select',
                                    name: 'template',
                                    label: '字段模板',
                                    placeholder: '选择常用字段模板快速创建',
                                    clearable: true,
                                    options: [
                                      { label: '标题字段', value: 'title' },
                                      {
                                        label: '描述字段',
                                        value: 'description',
                                      },
                                      { label: '封面图', value: 'cover' },
                                      { label: '排序', value: 'sort' },
                                      { label: '状态', value: 'status' },
                                      {
                                        label: '发布时间',
                                        value: 'publish_time',
                                      },
                                    ],
                                    onChange: `
                                      const templates = {
                                        title: { label: '标题', key: 'title', type: 'text', required: true, searchable: true, placeholder: '请输入标题' },
                                        description: { label: '描述', key: 'description', type: 'textarea', placeholder: '请输入描述' },
                                        cover: { label: '封面图', key: 'cover', type: 'image', placeholder: '上传封面图' },
                                        sort: { label: '排序', key: 'sort', type: 'number', default_value: '0', placeholder: '数字越大越靠前' },
                                        status: { label: '状态', key: 'status', type: 'switch', default_value: '1' },
                                        publish_time: { label: '发布时间', key: 'publish_time', type: 'datetime', placeholder: '选择发布时间' }
                                      };
                                      if (value && templates[value]) {
                                        const t = templates[value];
                                        this.setValues(t);
                                      }
                                    `,
                                  },
                                  {
                                    type: 'divider',
                                  },
                                  {
                                    type: 'grid',
                                    columns: [
                                      {
                                        body: [
                                          {
                                            type: 'input-text',
                                            name: 'label',
                                            label: '字段名称',
                                            required: true,
                                            placeholder: '如：文章标题',
                                          },
                                          {
                                            type: 'input-text',
                                            name: 'key',
                                            label: '字段标识',
                                            required: true,
                                            placeholder: '英文标识，如：title',
                                            description: '创建后不可修改',
                                            validations: {
                                              isAlphanumeric: true,
                                            },
                                          },
                                          {
                                            type: 'select',
                                            name: 'type',
                                            label: '字段类型',
                                            required: true,
                                            description: '创建后不可修改',
                                            options: [
                                              {
                                                label: '单行文本',
                                                value: 'text',
                                              },
                                              {
                                                label: '多行文本',
                                                value: 'textarea',
                                              },
                                              {
                                                label: '富文本',
                                                value: 'richtext',
                                              },
                                              {
                                                label: 'Markdown',
                                                value: 'markdown',
                                              },
                                              {
                                                label: '数字',
                                                value: 'number',
                                              },
                                              { label: '金额', value: 'money' },
                                              {
                                                label: '百分比',
                                                value: 'percent',
                                              },
                                              { label: '日期', value: 'date' },
                                              {
                                                label: '日期时间',
                                                value: 'datetime',
                                              },
                                              {
                                                label: '时间范围',
                                                value: 'daterange',
                                              },
                                              {
                                                label: '下拉选择',
                                                value: 'select',
                                              },
                                              {
                                                label: '单选框',
                                                value: 'radio',
                                              },
                                              {
                                                label: '多选框',
                                                value: 'checkbox',
                                              },
                                              {
                                                label: '开关',
                                                value: 'switch',
                                              },
                                              { label: '图片', value: 'image' },
                                              { label: '文件', value: 'file' },
                                              { label: '视频', value: 'video' },
                                              {
                                                label: '关联内容',
                                                value: 'relation',
                                              },
                                              { label: 'JSON', value: 'json' },
                                              { label: '颜色', value: 'color' },
                                              {
                                                label: '评分',
                                                value: 'rating',
                                              },
                                            ],
                                          },
                                        ],
                                      },
                                      {
                                        body: [
                                          {
                                            type: 'switch',
                                            name: 'required',
                                            label: '必填',
                                            value: false,
                                          },
                                          {
                                            type: 'switch',
                                            name: 'unique',
                                            label: '唯一',
                                            value: false,
                                            description: '该字段值不能重复',
                                          },
                                          {
                                            type: 'switch',
                                            name: 'searchable',
                                            label: '可搜索',
                                            value: false,
                                            description: '在内容列表中可搜索',
                                          },
                                        ],
                                      },
                                    ],
                                  },
                                  {
                                    type: 'divider',
                                  },
                                  {
                                    type: 'input-text',
                                    name: 'default_value',
                                    label: '默认值',
                                    placeholder: '字段的默认值',
                                  },
                                  {
                                    type: 'input-text',
                                    name: 'placeholder',
                                    label: '占位提示',
                                    placeholder: '输入框的占位提示文字',
                                  },
                                  {
                                    type: 'textarea',
                                    name: 'help_text',
                                    label: '帮助说明',
                                    placeholder: '字段的帮助说明文字',
                                    maxLength: 200,
                                  },
                                  {
                                    type: 'divider',
                                    label: '验证规则',
                                  },
                                  {
                                    type: 'grid',
                                    columns: [
                                      {
                                        body: [
                                          {
                                            type: 'input-number',
                                            name: 'validation_rules.min_length',
                                            label: '最小长度',
                                            placeholder: '文本最小长度',
                                            visibleOn:
                                              'this.type === "text" || this.type === "textarea"',
                                          },
                                          {
                                            type: 'input-number',
                                            name: 'validation_rules.min',
                                            label: '最小值',
                                            placeholder: '数字最小值',
                                            visibleOn:
                                              'this.type === "number" || this.type === "money" || this.type === "percent"',
                                          },
                                        ],
                                      },
                                      {
                                        body: [
                                          {
                                            type: 'input-number',
                                            name: 'validation_rules.max_length',
                                            label: '最大长度',
                                            placeholder: '文本最大长度',
                                            visibleOn:
                                              'this.type === "text" || this.type === "textarea"',
                                          },
                                          {
                                            type: 'input-number',
                                            name: 'validation_rules.max',
                                            label: '最大值',
                                            placeholder: '数字最大值',
                                            visibleOn:
                                              'this.type === "number" || this.type === "money" || this.type === "percent"',
                                          },
                                        ],
                                      },
                                    ],
                                  },
                                  {
                                    type: 'combo',
                                    name: 'options',
                                    label: '选项配置',
                                    multiple: true,
                                    draggable: true,
                                    addable: true,
                                    removable: true,
                                    visibleOn:
                                      'this.type === "select" || this.type === "radio" || this.type === "checkbox"',
                                    items: [
                                      {
                                        type: 'input-text',
                                        name: 'label',
                                        placeholder: '选项名称',
                                        required: true,
                                      },
                                      {
                                        type: 'input-text',
                                        name: 'value',
                                        placeholder: '选项值',
                                        required: true,
                                      },
                                    ],
                                  },
                                ],
                              },
                            },
                          },
                        ],
                        columns: [
                          {
                            name: 'label',
                            label: '字段名称',
                            width: 150,
                          },
                          {
                            name: 'key',
                            label: '字段标识',
                            type: 'tpl',
                            tpl: '<code class="text-primary">${key}</code>',
                            width: 120,
                          },
                          {
                            name: 'type',
                            label: '字段类型',
                            type: 'mapping',
                            map: {
                              text: '单行文本',
                              textarea: '多行文本',
                              richtext: '富文本',
                              markdown: 'Markdown',
                              number: '数字',
                              money: '金额',
                              percent: '百分比',
                              date: '日期',
                              datetime: '日期时间',
                              daterange: '时间范围',
                              select: '下拉选择',
                              radio: '单选框',
                              checkbox: '多选框',
                              switch: '开关',
                              image: '图片',
                              file: '文件',
                              video: '视频',
                              relation: '关联内容',
                              json: 'JSON',
                              color: '颜色',
                              rating: '评分',
                            },
                            width: 100,
                          },
                          {
                            name: 'required',
                            label: '必填',
                            type: 'status',
                            width: 60,
                          },
                          {
                            name: 'unique',
                            label: '唯一',
                            type: 'status',
                            width: 60,
                          },
                          {
                            name: 'searchable',
                            label: '可搜索',
                            type: 'status',
                            width: 80,
                          },
                          {
                            name: 'default_value',
                            label: '默认值',
                            type: 'tpl',
                            tpl: '${default_value || "-"}',
                            width: 100,
                          },
                          {
                            type: 'operation',
                            label: '操作',
                            width: 200,
                            buttons: [
                              {
                                label: '复制',
                                type: 'button',
                                level: 'link',
                                icon: 'fa fa-copy',
                                actionType: 'dialog',
                                dialog: {
                                  title: '复制字段',
                                  body: {
                                    type: 'form',
                                    api: 'post:/api/cms/models/${model_id}/fields',
                                    initApi:
                                      '/api/cms/models/${model_id}/fields/${id}',
                                    body: [
                                      {
                                        type: 'input-text',
                                        name: 'label',
                                        label: '字段名称',
                                        required: true,
                                      },
                                      {
                                        type: 'input-text',
                                        name: 'key',
                                        label: '字段标识',
                                        required: true,
                                        description: '需要使用新的标识',
                                      },
                                    ],
                                  },
                                },
                                tooltip: '复制字段',
                              },
                              {
                                label: '编辑',
                                type: 'button',
                                level: 'link',
                                actionType: 'dialog',
                                dialog: {
                                  title: '编辑字段',
                                  size: 'lg',
                                  body: {
                                    type: 'form',
                                    api: 'put:/api/cms/models/${model_id}/fields/${id}',
                                    initApi:
                                      '/api/cms/models/${model_id}/fields/${id}',
                                    body: [
                                      {
                                        type: 'input-text',
                                        name: 'label',
                                        label: '字段名称',
                                        required: true,
                                      },
                                      {
                                        type: 'static',
                                        name: 'key',
                                        label: '字段标识',
                                        description: '字段标识不可修改',
                                      },
                                      {
                                        type: 'static',
                                        name: 'type',
                                        label: '字段类型',
                                        description: '字段类型不可修改',
                                      },
                                      {
                                        type: 'switch',
                                        name: 'required',
                                        label: '必填',
                                      },
                                      {
                                        type: 'switch',
                                        name: 'unique',
                                        label: '唯一',
                                      },
                                      {
                                        type: 'switch',
                                        name: 'searchable',
                                        label: '可搜索',
                                      },
                                      {
                                        type: 'input-text',
                                        name: 'default_value',
                                        label: '默认值',
                                      },
                                      {
                                        type: 'input-text',
                                        name: 'placeholder',
                                        label: '占位提示',
                                      },
                                      {
                                        type: 'textarea',
                                        name: 'help_text',
                                        label: '帮助说明',
                                      },
                                    ],
                                  },
                                },
                              },
                              {
                                label: '删除',
                                type: 'button',
                                level: 'link',
                                className: 'text-danger',
                                actionType: 'ajax',
                                confirmText:
                                  '删除字段将删除所有内容中的该字段数据，确定删除吗？',
                                api: 'delete:/api/cms/models/${model_id}/fields/${id}',
                              },
                            ],
                          },
                        ],
                      },
                    ],
                  },
                },
              },
              tooltip: '管理字段',
            },
            {
              type: 'button',
              label: '内容',
              level: 'link',
              icon: 'fa fa-file-text',
              actionType: 'url',
              url: '/cms/content/${id}',
              blank: false,
              tooltip: '管理内容',
            },
            {
              type: 'button',
              label: '编辑',
              level: 'link',
              icon: 'fa fa-edit',
              actionType: 'dialog',
              dialog: {
                title: '编辑模型',
                size: 'lg',
                body: {
                  type: 'form',
                  api: 'put:/api/cms/models/${id}',
                  initApi: '/api/cms/models/${id}',
                  body: [
                    {
                      type: 'input-text',
                      name: 'name',
                      label: '模型名称',
                      required: true,
                    },
                    {
                      type: 'static',
                      name: 'slug',
                      label: '模型标识',
                      description: '模型标识不可修改',
                    },
                    {
                      type: 'textarea',
                      name: 'description',
                      label: '模型描述',
                    },
                    {
                      type: 'group',
                      label: '功能配置',
                      body: [
                        {
                          type: 'switch',
                          name: 'enable_category',
                          label: '启用分类',
                        },
                        {
                          type: 'switch',
                          name: 'enable_tag',
                          label: '启用标签',
                        },
                        {
                          type: 'switch',
                          name: 'enable_version',
                          label: '启用版本控制',
                        },
                        {
                          type: 'switch',
                          name: 'enable_i18n',
                          label: '启用多语言',
                        },
                      ],
                    },
                    {
                      type: 'switch',
                      name: 'status',
                      label: '状态',
                    },
                  ],
                },
              },
            },
            {
              type: 'button',
              label: '删除',
              level: 'link',
              className: 'text-danger',
              icon: 'fa fa-trash',
              actionType: 'ajax',
              confirmText:
                '确定要删除该模型吗？删除后相关内容也将被删除，此操作不可恢复！',
              api: 'delete:/api/cms/models/${id}',
              visibleOn: 'this.content_count === 0',
            },
            {
              type: 'button',
              label: '删除',
              level: 'link',
              disabled: true,
              icon: 'fa fa-trash',
              tooltip: '该模型下还有内容，无法删除',
              visibleOn: 'this.content_count > 0',
            },
          ],
        },
      ],
    },
  };
</script>

<style scoped>
  .cms-model-page {
    padding: 20px;
  }
</style>

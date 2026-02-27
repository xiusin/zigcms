<template>
  <div class="cms-content-page">
    <AmisRenderer v-if="schema" :schema="schema" />
    <a-spin v-else :loading="true" style="width: 100%; height: 400px" />
  </div>
</template>

<script setup lang="ts">
  import { ref, onMounted, computed } from 'vue';
  import { useRoute, useRouter } from 'vue-router';
  import { Message } from '@arco-design/web-vue';
  import AmisRenderer from '@/components/amis/index.vue';
  import { getModelDetail } from '@/api/cms';
  import type { ContentModel, ModelField } from '@/types/cms';

  const route = useRoute();
  const router = useRouter();
  const modelId = Number(route.params.modelId);

  const model = ref<ContentModel | null>(null);
  const loading = ref(false);

  // 根据字段类型生成 Amis 表单项
  const generateFormItem = (field: ModelField) => {
    const baseConfig: any = {
      name: `fields.${field.key}`,
      label: field.label,
      required: field.required,
      placeholder: field.placeholder,
      description: field.help_text,
    };

    // 根据字段类型生成不同的表单组件
    switch (field.type) {
      case 'text':
        return {
          ...baseConfig,
          type: 'input-text',
          maxLength: field.validation_rules?.max_length,
          minLength: field.validation_rules?.min_length,
        };

      case 'textarea':
        return {
          ...baseConfig,
          type: 'textarea',
          maxLength: field.validation_rules?.max_length,
          minLength: field.validation_rules?.min_length,
        };

      case 'richtext':
        return {
          ...baseConfig,
          type: 'input-rich-text',
          vendor: 'tinymce',
        };

      case 'markdown':
        return {
          ...baseConfig,
          type: 'editor',
          language: 'markdown',
        };

      case 'number':
        return {
          ...baseConfig,
          type: 'input-number',
          min: field.validation_rules?.min,
          max: field.validation_rules?.max,
        };

      case 'money':
        return {
          ...baseConfig,
          type: 'input-number',
          prefix: '¥',
          precision: 2,
          min: field.validation_rules?.min || 0,
        };

      case 'percent':
        return {
          ...baseConfig,
          type: 'input-number',
          suffix: '%',
          min: 0,
          max: 100,
        };

      case 'date':
        return {
          ...baseConfig,
          type: 'input-date',
          format: 'YYYY-MM-DD',
        };

      case 'datetime':
        return {
          ...baseConfig,
          type: 'input-datetime',
          format: 'YYYY-MM-DD HH:mm:ss',
        };

      case 'time_range':
        return {
          ...baseConfig,
          type: 'input-datetime-range',
        };

      case 'select':
        return {
          ...baseConfig,
          type: 'select',
          options: field.options || [],
        };

      case 'radio':
        return {
          ...baseConfig,
          type: 'radios',
          options: field.options || [],
        };

      case 'checkbox':
        return {
          ...baseConfig,
          type: 'checkboxes',
          options: field.options || [],
        };

      case 'switch':
        return {
          ...baseConfig,
          type: 'switch',
        };

      case 'image':
        return {
          ...baseConfig,
          type: 'input-image',
          receiver: '/api/cms/media/upload',
          accept: 'image/*',
        };

      case 'file':
        return {
          ...baseConfig,
          type: 'input-file',
          receiver: '/api/cms/media/upload',
        };

      case 'video':
        return {
          ...baseConfig,
          type: 'input-file',
          receiver: '/api/cms/media/upload',
          accept: 'video/*',
        };

      case 'color':
        return {
          ...baseConfig,
          type: 'input-color',
        };

      case 'rating':
        return {
          ...baseConfig,
          type: 'input-rating',
        };

      case 'json':
        return {
          ...baseConfig,
          type: 'editor',
          language: 'json',
        };

      case 'relation':
        return {
          ...baseConfig,
          type: 'select',
          source: `/api/cms/contents/${field.validation_rules?.relation_model}`,
          labelField: 'title',
          valueField: 'id',
        };

      default:
        return {
          ...baseConfig,
          type: 'input-text',
        };
    }
  };

  // 根据字段类型生成表格列
  const generateTableColumn = (field: ModelField) => {
    const baseConfig: any = {
      name: `fields.${field.key}`,
      label: field.label,
      searchable: field.searchable,
    };

    switch (field.type) {
      case 'image':
        return {
          ...baseConfig,
          type: 'image',
          thumbMode: 'cover',
          thumbRatio: '1:1',
        };

      case 'switch':
        return {
          ...baseConfig,
          type: 'status',
        };

      case 'date':
      case 'datetime':
        return {
          ...baseConfig,
          type: 'datetime',
          format: field.type === 'date' ? 'YYYY-MM-DD' : 'YYYY-MM-DD HH:mm:ss',
        };

      case 'money':
        return {
          ...baseConfig,
          type: 'tpl',
          tpl: '¥${fields.' + field.key + '}',
        };

      case 'richtext':
      case 'markdown':
      case 'json':
        return {
          ...baseConfig,
          type: 'tpl',
          tpl: '-',
        };

      default:
        return baseConfig;
    }
  };

  const schema = computed(() => {
    if (!model.value) return null;

    const formItems = model.value.fields.map(generateFormItem);
    const tableColumns = model.value.fields
      .filter((f) => !['richtext', 'markdown', 'json'].includes(f.type))
      .slice(0, 5)
      .map(generateTableColumn);

    return {
      type: 'page',
      title: `${model.value.name}管理`,
      subTitle: model.value.description,
      toolbar: [
        {
          type: 'button',
          label: '返回模型列表',
          icon: 'fa fa-arrow-left',
          actionType: 'link',
          link: '/cms/model',
        },
      ],
      body: {
        type: 'crud',
        api: `/api/cms/contents/${modelId}`,
        syncLocation: false,
        autoGenerateFilter: true,
        perPageAvailable: [10, 20, 50, 100],
        defaultParams: {
          pageSize: 20,
        },
        quickSaveApi: `/api/cms/contents/${modelId}/\${id}`,
        quickSaveItemApi: `/api/cms/contents/${modelId}/\${id}`,
        headerToolbar: [
          {
            type: 'button',
            label: '新增内容',
            actionType: 'dialog',
            level: 'primary',
            icon: 'fa fa-plus',
            dialog: {
              title: `新增${model.value.name}`,
              size: 'lg',
              body: {
                type: 'form',
                api: `post:/api/cms/contents/${modelId}`,
                body: [
                  ...(model.value.enable_category
                    ? [
                        {
                          type: 'select',
                          name: 'category_id',
                          label: '分类',
                          source: {
                            method: 'get',
                            url: '/api/cms/categories',
                            adaptor:
                              'return { options: payload.data.map(item => ({ label: item.name, value: item.id })) }',
                          },
                          required: true,
                        },
                      ]
                    : []),
                  ...(model.value.enable_tag
                    ? [
                        {
                          type: 'select',
                          name: 'tag_ids',
                          label: '标签',
                          source: {
                            method: 'get',
                            url: '/api/cms/tags',
                            adaptor:
                              'return { options: payload.data.items.map(item => ({ label: item.name, value: item.id })) }',
                          },
                          multiple: true,
                        },
                      ]
                    : []),
                  ...formItems,
                  {
                    type: 'select',
                    name: 'status',
                    label: '状态',
                    value: 0,
                    options: [
                      { label: '草稿', value: 0 },
                      { label: '待审核', value: 1 },
                      { label: '已发布', value: 2 },
                    ],
                  },
                ],
              },
            },
          },
          {
            type: 'button',
            label: '批量发布',
            actionType: 'ajax',
            api: `post:/api/cms/contents/${modelId}/batch/publish`,
            confirmText: '确定要批量发布选中的内容吗？',
          },
          {
            type: 'button',
            label: '批量删除',
            actionType: 'ajax',
            api: `post:/api/cms/contents/${modelId}/batch/delete`,
            confirmText: '确定要批量删除选中的内容吗？',
            level: 'danger',
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
              placeholder: '搜索内容',
              clearable: true,
            },
            ...(model.value.enable_category
              ? [
                  {
                    type: 'select',
                    name: 'category_id',
                    label: '分类',
                    source: '/api/cms/categories/tree',
                  },
                ]
              : []),
            {
              type: 'select',
              name: 'status',
              label: '状态',
              options: [
                { label: '全部', value: '' },
                { label: '草稿', value: 0 },
                { label: '待审核', value: 1 },
                { label: '已发布', value: 2 },
                { label: '已归档', value: 3 },
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
          ...tableColumns,
          ...(model.value.enable_category
            ? [
                {
                  name: 'category_name',
                  label: '分类',
                  width: 120,
                },
              ]
            : []),
          ...(model.value.enable_tag
            ? [
                {
                  name: 'tags',
                  label: '标签',
                  type: 'each',
                  items: {
                    type: 'tpl',
                    tpl: '<span class="badge" style="background-color: ${color}">${name}</span> ',
                  },
                  width: 150,
                },
              ]
            : []),
          {
            name: 'status',
            label: '状态',
            type: 'mapping',
            map: {
              0: '<span class="label label-default">草稿</span>',
              1: '<span class="label label-warning">待审核</span>',
              2: '<span class="label label-success">已发布</span>',
              3: '<span class="label label-info">已归档</span>',
            },
            width: 100,
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
              ...(model.value.enable_version
                ? [
                    {
                      type: 'button',
                      label: '版本',
                      level: 'link',
                      icon: 'fa fa-history',
                      actionType: 'dialog',
                      dialog: {
                        title: '版本历史',
                        size: 'lg',
                        body: {
                          type: 'service',
                          api: `/api/cms/contents/${modelId}/\${id}/versions`,
                          body: {
                            type: 'table',
                            columns: [
                              { name: 'version', label: '版本号' },
                              { name: 'change_summary', label: '变更摘要' },
                              {
                                name: 'created_at',
                                label: '创建时间',
                                type: 'datetime',
                              },
                              {
                                type: 'operation',
                                label: '操作',
                                buttons: [
                                  {
                                    type: 'button',
                                    label: '回滚',
                                    level: 'link',
                                    actionType: 'ajax',
                                    confirmText: '确定要回滚到此版本吗？',
                                    api: `post:/api/cms/contents/${modelId}/\${id}/versions/\${version_id}/rollback`,
                                  },
                                ],
                              },
                            ],
                          },
                        },
                      },
                    },
                  ]
                : []),
              {
                type: 'button',
                label: '编辑',
                level: 'link',
                icon: 'fa fa-edit',
                actionType: 'dialog',
                dialog: {
                  title: `编辑${model.value.name}`,
                  size: 'lg',
                  body: {
                    type: 'form',
                    api: `put:/api/cms/contents/${modelId}/\${id}`,
                    initApi: `/api/cms/contents/${modelId}/\${id}`,
                    body: [
                      ...(model.value.enable_category
                        ? [
                            {
                              type: 'select',
                              name: 'category_id',
                              label: '分类',
                              source: '/api/cms/categories/tree',
                              required: true,
                            },
                          ]
                        : []),
                      ...(model.value.enable_tag
                        ? [
                            {
                              type: 'select',
                              name: 'tag_ids',
                              label: '标签',
                              source: '/api/cms/tags',
                              multiple: true,
                              labelField: 'name',
                              valueField: 'id',
                            },
                          ]
                        : []),
                      ...formItems,
                      {
                        type: 'select',
                        name: 'status',
                        label: '状态',
                        options: [
                          { label: '草稿', value: 0 },
                          { label: '待审核', value: 1 },
                          { label: '已发布', value: 2 },
                          { label: '已归档', value: 3 },
                        ],
                      },
                    ],
                  },
                },
              },
              {
                type: 'button',
                label: '发布',
                level: 'link',
                icon: 'fa fa-send',
                actionType: 'ajax',
                confirmText: '确定要发布该内容吗？',
                api: `post:/api/cms/contents/${modelId}/\${id}/publish`,
                visibleOn: 'this.status !== 2',
              },
              {
                type: 'button',
                label: '下线',
                level: 'link',
                icon: 'fa fa-download',
                actionType: 'ajax',
                confirmText: '确定要下线该内容吗？',
                api: `post:/api/cms/contents/${modelId}/\${id}/unpublish`,
                visibleOn: 'this.status === 2',
              },
              {
                type: 'button',
                label: '删除',
                level: 'link',
                className: 'text-danger',
                icon: 'fa fa-trash',
                actionType: 'ajax',
                confirmText: '确定要删除该内容吗？',
                api: `delete:/api/cms/contents/${modelId}/\${id}`,
              },
            ],
          },
        ],
      },
    };
  });

  const loadModel = async () => {
    loading.value = true;
    try {
      const res = await getModelDetail(modelId);
      model.value = res.data.data;
    } catch (error) {
      Message.error('加载模型失败');
      router.push('/cms/model');
    } finally {
      loading.value = false;
    }
  };

  onMounted(() => {
    loadModel();
  });
</script>

<style scoped>
  .cms-content-page {
    padding: 20px;
  }
</style>

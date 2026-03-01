<template>
  <div class="suite-list">
    <AmisCRUD
      :schema="schema"
      :api="'/api/auto-test/suite/list'"
      :columns="columns"
      :search-schema="searchSchema"
      title="测试套件"
    />
  </div>
</template>

<script setup lang="ts">
// 列表列配置
const columns = [
  {
    name: 'id',
    label: 'ID',
    width: 80,
  },
  {
    name: 'suite_name',
    label: '套件名称',
    searchable: true,
  },
  {
    name: 'suite_key',
    label: '套件标识',
  },
  {
    name: 'description',
    label: '描述',
    ellipsis: true,
  },
  {
    name: 'case_count',
    label: '用例数量',
    width: 100,
  },
  {
    name: 'status',
    label: '状态',
    type: 'status',
    map: {
      1: { label: '启用', value: 1 },
      0: { label: '禁用', value: 0 },
    },
  },
  {
    name: 'created_at',
    label: '创建时间',
    type: 'datetime',
  },
  {
    type: 'operation',
    label: '操作',
    width: 220,
    buttons: [
      {
        type: 'button',
        label: '编辑',
        level: 'link',
        actionType: 'dialog',
        dialog: {
          title: '编辑测试套件',
          body: {
            type: 'form',
            api: 'put:/api/auto-test/suite/$id',
            body: [
              {
                type: 'input-text',
                name: 'suite_name',
                label: '套件名称',
                required: true,
              },
              {
                type: 'input-text',
                name: 'suite_key',
                label: '套件标识',
                required: true,
              },
              {
                type: 'textarea',
                name: 'description',
                label: '描述',
              },
            ],
          },
        },
      },
      {
        type: 'button',
        label: '执行套件',
        level: 'primary',
        actionType: 'ajax',
        confirmText: '确认执行此测试套件？',
        api: 'post:/api/auto-test/suite/execute/$id',
      },
      {
        type: 'button',
        label: '删除',
        level: 'link',
        className: 'text-danger',
        actionType: 'ajax',
        confirmText: '确认删除此套件？',
        api: 'delete:/api/auto-test/suite/$id',
      },
    ],
  },
];

// 搜索表单配置
const searchSchema = {
  type: 'form',
  body: [
    {
      type: 'input-text',
      name: 'suite_name',
      label: '套件名称',
      placeholder: '请输入套件名称',
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
};

// 页面配置
const schema = {
  type: 'page',
  title: '测试套件管理',
  subTitle: '管理测试用例套件',
  body: [],
};
</script>

<style scoped>
.suite-list {
  height: 100%;
}
</style>

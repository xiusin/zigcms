<template>
  <div class="case-list">
    <AmisCRUD
      :schema="schema"
      :api="'/api/auto-test/case/list'"
      :columns="columns"
      :search-schema="searchSchema"
      title="测试用例"
    />
  </div>
</template>

<script setup lang="ts">
import { h } from 'vue';

// 列表列配置
const columns = [
  {
    name: 'id',
    label: 'ID',
    width: 80,
    sortable: true,
  },
  {
    name: 'case_name',
    label: '用例名称',
    searchable: true,
  },
  {
    name: 'case_type',
    label: '用例类型',
    type: 'mapping',
    map: {
      unit: '<span class="label label-info">单元测试</span>',
      integration: '<span class="label label-success">集成测试</span>',
      e2e: '<span class="label label-warning">E2E测试</span>',
    },
  },
  {
    name: 'priority',
    label: '优先级',
    type: 'mapping',
    map: {
      high: '<span class="text-danger">高</span>',
      medium: '<span class="text-warning">中</span>',
      low: '<span class="text-gray">低</span>',
    },
  },
  {
    name: 'status',
    label: '状态',
    type: 'status',
    map: {
      1: { label: '正常', value: 1 },
      0: { label: '禁用', value: 0 },
    },
  },
  {
    name: 'created_at',
    label: '创建时间',
    type: 'datetime',
    sortable: true,
  },
  {
    type: 'operation',
    label: '操作',
    width: 180,
    buttons: [
      {
        type: 'button',
        label: '编辑',
        level: 'link',
        actionType: 'dialog',
        dialog: {
          title: '编辑测试用例',
          body: {
            type: 'form',
            api: 'put:/api/auto-test/case/$id',
            body: [
              {
                type: 'input-text',
                name: 'case_name',
                label: '用例名称',
                required: true,
              },
              {
                type: 'select',
                name: 'case_type',
                label: '用例类型',
                options: [
                  { label: '单元测试', value: 'unit' },
                  { label: '集成测试', value: 'integration' },
                  { label: 'E2E测试', value: 'e2e' },
                ],
              },
              {
                type: 'select',
                name: 'priority',
                label: '优先级',
                options: [
                  { label: '高', value: 'high' },
                  { label: '中', value: 'medium' },
                  { label: '低', value: 'low' },
                ],
              },
            ],
          },
        },
      },
      {
        type: 'button',
        label: '执行',
        level: 'primary',
        actionType: 'ajax',
        confirmText: '确认执行此用例？',
        api: 'post:/api/auto-test/case/execute/$id',
      },
      {
        type: 'button',
        label: '删除',
        level: 'link',
        className: 'text-danger',
        actionType: 'ajax',
        confirmText: '确认删除此用例？',
        api: 'delete:/api/auto-test/case/$id',
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
      name: 'case_name',
      label: '用例名称',
      placeholder: '请输入用例名称',
    },
    {
      type: 'select',
      name: 'case_type',
      label: '用例类型',
      options: [
        { label: '全部', value: '' },
        { label: '单元测试', value: 'unit' },
        { label: '集成测试', value: 'integration' },
        { label: 'E2E测试', value: 'e2e' },
      ],
    },
    {
      type: 'select',
      name: 'priority',
      label: '优先级',
      options: [
        { label: '全部', value: '' },
        { label: '高', value: 'high' },
        { label: '中', value: 'medium' },
        { label: '低', value: 'low' },
      ],
    },
  ],
};

// 页面配置
const schema = {
  type: 'page',
  title: '测试用例管理',
  subTitle: '管理自动化测试用例',
  body: [],
};
</script>

<style scoped>
.case-list {
  height: 100%;
}
</style>

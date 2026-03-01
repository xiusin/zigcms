<template>
  <div class="execution-list">
    <AmisCRUD
      :schema="schema"
      :api="'/api/auto-test/execution/list'"
      :columns="columns"
      :search-schema="searchSchema"
      title="执行记录"
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
    name: 'execution_no',
    label: '执行编号',
    width: 180,
  },
  {
    name: 'case_name',
    label: '用例名称',
  },
  {
    name: 'execute_type',
    label: '执行类型',
    type: 'mapping',
    map: {
      manual: '<span class="label label-info">手动</span>',
      scheduled: '<span class="label label-success">定时</span>',
      api: '<span class="label label-warning">API触发</span>',
    },
  },
  {
    name: 'status',
    label: '执行状态',
    type: 'mapping',
    map: {
      pending: '<span class="text-gray">等待中</span>',
      running: '<span class="text-primary">执行中</span>',
      success: '<span class="text-success">成功</span>',
      failed: '<span class="text-danger">失败</span>',
    },
  },
  {
    name: 'duration',
    label: '耗时(秒)',
    width: 100,
  },
  {
    name: 'executor',
    label: '执行人',
  },
  {
    name: 'executed_at',
    label: '执行时间',
    type: 'datetime',
  },
  {
    type: 'operation',
    label: '操作',
    width: 150,
    buttons: [
      {
        type: 'button',
        label: '查看详情',
        level: 'link',
        actionType: 'link',
        link: '/auto-test/execution/detail/$id',
      },
      {
        type: 'button',
        label: '重新执行',
        level: 'primary',
        actionType: 'ajax',
        api: 'post:/api/auto-test/execution/retry/$id',
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
      name: 'execution_no',
      label: '执行编号',
      placeholder: '请输入执行编号',
    },
    {
      type: 'select',
      name: 'status',
      label: '执行状态',
      options: [
        { label: '全部', value: '' },
        { label: '等待中', value: 'pending' },
        { label: '执行中', value: 'running' },
        { label: '成功', value: 'success' },
        { label: '失败', value: 'failed' },
      ],
    },
  ],
};

// 页面配置
const schema = {
  type: 'page',
  title: '测试执行记录',
  subTitle: '查看测试用例执行历史',
  body: [],
};
</script>

<style scoped>
.execution-list {
  height: 100%;
}
</style>

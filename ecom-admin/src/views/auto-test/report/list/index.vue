<template>
  <div class="report-list">
    <AmisCRUD
      :schema="schema"
      :api="'/api/auto-test/report/list'"
      :columns="columns"
      :search-schema="searchSchema"
      title="测试报告"
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
    name: 'report_no',
    label: '报告编号',
    width: 180,
  },
  {
    name: 'report_name',
    label: '报告名称',
  },
  {
    name: 'total_cases',
    label: '总用例数',
    width: 100,
  },
  {
    name: 'passed',
    label: '通过',
    width: 80,
    type: 'mapping',
    map: {
      0: '<span class="text-success">0</span>',
    },
  },
  {
    name: 'failed',
    label: '失败',
    width: 80,
    type: 'mapping',
    map: {
      0: '<span class="text-gray">0</span>',
      1: '<span class="text-danger">$value</span>',
    },
  },
  {
    name: 'pass_rate',
    label: '通过率',
    width: 100,
    type: 'progress',
  },
  {
    name: 'created_at',
    label: '生成时间',
    type: 'datetime',
  },
  {
    type: 'operation',
    label: '操作',
    width: 180,
    buttons: [
      {
        type: 'button',
        label: '查看详情',
        level: 'link',
        actionType: 'link',
        link: '/auto-test/report/detail/$id',
      },
      {
        type: 'button',
        label: '导出PDF',
        level: 'link',
        actionType: 'download',
        api: 'get:/api/auto-test/report/export/$id',
      },
      {
        type: 'button',
        label: '删除',
        level: 'link',
        className: 'text-danger',
        actionType: 'ajax',
        confirmText: '确认删除此报告？',
        api: 'delete:/api/auto-test/report/$id',
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
      name: 'report_name',
      label: '报告名称',
      placeholder: '请输入报告名称',
    },
    {
      type: 'input-date-range',
      name: 'date_range',
      label: '时间范围',
    },
  ],
};

// 页面配置
const schema = {
  type: 'page',
  title: '测试报告',
  subTitle: '查看测试执行报告',
  body: [],
};
</script>

<style scoped>
.report-list {
  height: 100%;
}
</style>

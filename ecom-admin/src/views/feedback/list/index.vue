<template>
  <div class="feedback-list-page">
    <AmisRenderer
      v-if="pageSchema"
      :schema="pageSchema"
      @event="handleAmisEvent"
    />

    <!-- 弹窗组件 - 这些使用 Vue 组件 -->
    <FeedbackFormModal
      v-model:visible="formModalVisible"
      :feedback-id="editingFeedbackId"
      @success="handleFormSuccess"
    />

    <AssignModal
      v-model:visible="assignModalVisible"
      :feedback-ids="assignFeedbackIds"
      @success="handleAssignSuccess"
    />

    <StatusModal
      v-model:visible="statusModalVisible"
      :feedback-ids="statusFeedbackIds"
      @success="handleStatusSuccess"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { Message } from '@arco-design/web-vue';
import { AmisRenderer } from '@/components/amis';
import { useFeedbackStore } from '@/store/modules/feedback';
import FeedbackFormModal from './components/FeedbackFormModal.vue';
import AssignModal from './components/AssignModal.vue';
import StatusModal from './components/StatusModal.vue';
import type { Feedback } from '@/api/feedback';
import {
  canEditFeedback,
  canDeleteFeedback,
  canChangeStatus as checkCanChangeStatus,
} from '../utils/permission';

const router = useRouter();
const feedbackStore = useFeedbackStore();

// 弹窗控制
const formModalVisible = ref(false);
const editingFeedbackId = ref<number | undefined>(undefined);
const assignModalVisible = ref(false);
const assignFeedbackIds = ref<number[]>([]);
const statusModalVisible = ref(false);
const statusFeedbackIds = ref<number[]>([]);

// 页面 Schema
const pageSchema = ref<any>(null);

// 生成完整的 AMIS 页面 Schema
const generatePageSchema = () => {
  return {
    type: 'page',
    title: '',
    body: {
      type: 'crud',
      name: 'feedbackCrud',
      syncLocation: false,
      
      // API 配置 - 使用 GET 请求，参数通过 URL 传递
      api: {
        method: 'get',
        url: '/api/feedback/list?page=${page}&pageSize=${perPage}&keyword=${keyword | default:""}&status=${status | default:""}&priority=${priority | default:""}&type=${type | default:""}',
        adaptor: `
          const list = payload.data?.list || [];
          const total = payload.data?.total || 0;
          return {
            status: (payload.code === 0 || payload.code === 200) ? 0 : payload.code,
            msg: payload.msg,
            data: {
              items: list,
              total: total
            }
          };
        `,
      },

      // 分页配置
      perPage: 20,
      perPageAvailable: [10, 20, 50, 100],
      footerToolbar: ['switch-per-page', 'pagination'],

      // 头部工具栏
      headerToolbar: [
        // 标题和统计
        {
          type: 'tpl',
          tpl: '<span style="font-size: 16px; font-weight: 500;">反馈列表</span>',
        },
        {
          type: 'tpl',
          tpl: '<span style="margin-left: 8px; color: #86909c;">共 ${total} 条</span>',
        },
        'bulkActions',
        {
          type: 'button',
          label: '新建反馈',
          level: 'primary',
          icon: 'fa fa-plus',
          actionType: 'custom',
          onEvent: {
            click: {
              actions: [
                {
                  actionType: 'broadcast',
                  eventName: 'feedback:create',
                },
              ],
            },
          },
        },
        {
          type: 'button',
          label: '刷新',
          icon: 'fa fa-refresh',
          actionType: 'reload',
          target: 'feedbackCrud',
        },
        {
          type: 'button',
          label: '导出',
          icon: 'fa fa-download',
          actionType: 'ajax',
          api: {
            method: 'post',
            url: '/api/feedback/export',
          },
          onEvent: {
            success: {
              actions: [
                {
                  actionType: 'toast',
                  args: {
                    msg: '导出成功',
                    level: 'success',
                  },
                },
              ],
            },
          },
        },
      ],

      // 批量操作
      bulkActions: [
        {
          type: 'button',
          label: '批量删除',
          level: 'danger',
          confirmText: '确定要删除选中的 ${ids|raw|count} 条反馈吗？',
          actionType: 'ajax',
          api: {
            method: 'delete',
            url: '/api/feedback/batch/delete',
            data: {
              ids: '${ids|raw}',
            },
          },
          onEvent: {
            success: {
              actions: [
                {
                  actionType: 'reload',
                  target: 'feedbackCrud',
                },
                {
                  actionType: 'toast',
                  args: {
                    msg: '批量删除成功',
                    level: 'success',
                  },
                },
              ],
            },
          },
        },
      ],

      // 筛选表单
      filter: {
        title: '高级筛选',
        submitText: '查询',
        resetText: '重置',
        body: [
          {
            type: 'input-text',
            name: 'keyword',
            label: '关键词',
            placeholder: '搜索标题、描述...',
            clearable: true,
          },
          {
            type: 'select',
            name: 'status',
            label: '状态',
            multiple: true,
            clearable: true,
            options: [
              { label: '待处理', value: 0 },
              { label: '处理中', value: 1 },
              { label: '已解决', value: 2 },
              { label: '已关闭', value: 3 },
              { label: '已拒绝', value: 4 },
            ],
          },
          {
            type: 'select',
            name: 'priority',
            label: '优先级',
            multiple: true,
            clearable: true,
            options: [
              { label: '紧急', value: 0 },
              { label: '高', value: 1 },
              { label: '中', value: 2 },
              { label: '低', value: 3 },
            ],
          },
          {
            type: 'select',
            name: 'type',
            label: '类型',
            multiple: true,
            clearable: true,
            options: [
              { label: '功能建议', value: 0 },
              { label: 'Bug 反馈', value: 1 },
              { label: '性能问题', value: 2 },
              { label: '用户体验', value: 3 },
              { label: '其他', value: 4 },
            ],
          },
        ],
      },

      // 表格列配置
      columns: [
        {
          type: 'checkbox',
          name: 'id',
        },
        {
          name: 'id',
          label: 'ID',
          width: 60,
          sortable: true,
        },
        {
          name: 'title',
          label: '标题',
          width: 280,
          type: 'tpl',
          tpl: `
            <div>
              <a href="#/feedback/detail/${'${id}'}" style="color: #165dff; text-decoration: none;">${'${title}'}</a>
              ${'${IF(ARRAYLENGTH(tags) > 0, CONCAT("<div style=\\"margin-top: 4px;\\">", ARRAYMAP(tags, item => CONCAT("<span style=\\"display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 12px; color: #fff; background-color: ", item.color, "; margin-right: 4px;\\">", item.name, "</span>")), "</div>"), "")'}
            </div>
          `,
        },
        {
          name: 'type',
          label: '类型',
          width: 100,
          type: 'mapping',
          map: {
            0: '<span style="padding: 2px 8px; border-radius: 4px; font-size: 12px; background-color: #e8f3ff; color: #165dff;">功能建议</span>',
            1: '<span style="padding: 2px 8px; border-radius: 4px; font-size: 12px; background-color: #ffece8; color: #f53f3f;">Bug 反馈</span>',
            2: '<span style="padding: 2px 8px; border-radius: 4px; font-size: 12px; background-color: #fff3e8; color: #ff7d00;">性能问题</span>',
            3: '<span style="padding: 2px 8px; border-radius: 4px; font-size: 12px; background-color: #f5e8ff; color: #722ed1;">用户体验</span>',
            4: '<span style="padding: 2px 8px; border-radius: 4px; font-size: 12px; background-color: #f2f3f5; color: #86909c;">其他</span>',
          },
        },
        {
          name: 'status',
          label: '状态',
          width: 100,
          type: 'mapping',
          map: {
            0: '<span style="padding: 2px 8px; border-radius: 4px; font-size: 12px; background-color: #f2f3f5; color: #86909c;">待处理</span>',
            1: '<span style="padding: 2px 8px; border-radius: 4px; font-size: 12px; background-color: #e8f3ff; color: #165dff;">处理中</span>',
            2: '<span style="padding: 2px 8px; border-radius: 4px; font-size: 12px; background-color: #e8ffea; color: #00b42a;">已解决</span>',
            3: '<span style="padding: 2px 8px; border-radius: 4px; font-size: 12px; background-color: #f2f3f5; color: #86909c;">已关闭</span>',
            4: '<span style="padding: 2px 8px; border-radius: 4px; font-size: 12px; background-color: #ffece8; color: #f53f3f;">已拒绝</span>',
          },
        },
        {
          name: 'priority',
          label: '优先级',
          width: 80,
          type: 'mapping',
          map: {
            0: '<span style="padding: 2px 8px; border-radius: 4px; font-size: 12px; background-color: #ffece8; color: #f53f3f;">紧急</span>',
            1: '<span style="padding: 2px 8px; border-radius: 4px; font-size: 12px; background-color: #fff3e8; color: #ff7d00;">高</span>',
            2: '<span style="padding: 2px 8px; border-radius: 4px; font-size: 12px; background-color: #fffce8; color: #f7ba1e;">中</span>',
            3: '<span style="padding: 2px 8px; border-radius: 4px; font-size: 12px; background-color: #e8ffea; color: #00b42a;">低</span>',
          },
        },
        {
          name: 'creator_name',
          label: '创建者',
          width: 120,
          type: 'tpl',
          tpl: `
            <div style="display: flex; align-items: center; gap: 8px;">
              <img src="${'${creator_avatar || "https://joeschmoe.io/api/v1/random"}'}" style="width: 24px; height: 24px; border-radius: 50%;">
              <span>${'${creator_name}'}</span>
            </div>
          `,
        },
        {
          name: 'created_at',
          label: '创建时间',
          width: 160,
          type: 'datetime',
          format: 'YYYY-MM-DD HH:mm',
          sortable: true,
        },
        {
          name: 'handler_name',
          label: '指派给',
          width: 120,
          type: 'tpl',
          tpl: `
            ${'${IF(handler_name, CONCAT("<div style=\\"display: flex; align-items: center; gap: 8px;\\"><img style=\\"width: 24px; height: 24px; border-radius: 50%;\\" src=\\"", handler_avatar || "https://joeschmoe.io/api/v1/random", "\\"><span>", handler_name, "</span></div>"), "<span style=\\"color: #86909c;\\">未指派</span>")'}
          `,
        },
        {
          type: 'operation',
          label: '操作',
          width: 200,
          fixed: 'right',
          buttons: [
            {
              type: 'button',
              label: '编辑',
              level: 'link',
              size: 'sm',
              actionType: 'broadcast',
              eventName: 'feedback:edit',
            },
            {
              type: 'button',
              label: '状态',
              level: 'link',
              size: 'sm',
              actionType: 'broadcast',
              eventName: 'feedback:status',
            },
            {
              type: 'button',
              label: '删除',
              level: 'link',
              className: 'text-danger',
              size: 'sm',
              confirmText: '确定要删除该反馈吗？',
              actionType: 'ajax',
              api: {
                method: 'delete',
                url: '/api/feedback/delete/${id}',
              },
              onEvent: {
                success: {
                  actions: [
                    {
                      actionType: 'reload',
                      target: 'feedbackCrud',
                    },
                    {
                      actionType: 'toast',
                      args: {
                        msg: '删除成功',
                        level: 'success',
                      },
                    },
                  ],
                },
              },
            },
          ],
        },
      ],

      // 行点击事件
      itemAction: {
        type: 'button',
        actionType: 'broadcast',
        eventName: 'feedback:view',
      },

      // 空数据提示
      placeholder: {
        type: 'tpl',
        tpl: `
          <div style="text-align: center; padding: 40px;">
            <div style="font-size: 48px; margin-bottom: 16px;">📭</div>
            <div style="font-size: 16px; color: #1d2129; margin-bottom: 8px;">暂无反馈数据</div>
            <div style="font-size: 14px; color: #86909c;">点击"新建反馈"按钮创建第一条反馈</div>
          </div>
        `,
      },
    },
  };
};

// 处理 AMIS 事件
const handleAmisEvent = (event: any) => {
  const { type, data } = event;
  
  switch (type) {
    case 'feedback:create':
      handleCreate();
      break;
    case 'feedback:edit':
      if (data?.row) {
        handleEdit(data.row);
      }
      break;
    case 'feedback:view':
      if (data?.row) {
        handleView(data.row);
      }
      break;
    case 'feedback:status':
      if (data?.row) {
        handleChangeStatus(data.row);
      }
      break;
  }
};

// 处理函数
const handleCreate = () => {
  editingFeedbackId.value = undefined;
  formModalVisible.value = true;
};

const handleEdit = (feedback: Feedback) => {
  if (!canEditFeedback(feedback)) {
    Message.error('您没有编辑该反馈的权限');
    return;
  }
  editingFeedbackId.value = feedback.id;
  formModalVisible.value = true;
};

const handleView = (feedback: Feedback) => {
  router.push(`/feedback/detail/${feedback.id}`);
};

const handleChangeStatus = (feedback: Feedback) => {
  if (!checkCanChangeStatus(feedback)) {
    Message.error('您没有更改该反馈状态的权限');
    return;
  }
  statusFeedbackIds.value = [feedback.id];
  statusModalVisible.value = true;
};

const handleFormSuccess = () => {
  formModalVisible.value = false;
  // 刷新 AMIS 表格
  window.dispatchEvent(new CustomEvent('amis:feedback:reload'));
};

const handleAssignSuccess = () => {
  assignModalVisible.value = false;
  window.dispatchEvent(new CustomEvent('amis:feedback:reload'));
};

const handleStatusSuccess = () => {
  statusModalVisible.value = false;
  window.dispatchEvent(new CustomEvent('amis:feedback:reload'));
};

onMounted(() => {
  pageSchema.value = generatePageSchema();
});
</script>

<style scoped lang="less">
.feedback-list-page {
  padding: 20px;
}
</style>

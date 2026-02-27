/**
 * 反馈列表 AMIS Schema 配置
 * 使用 AMIS JSON Schema 定义反馈列表的 CRUD 界面
 * 包含高级特性：动态渲染、公式表达式、事件动作系统、条件渲染等
 * 【权限控制】支持基于权限的按钮显示/隐藏
 */

import type { Feedback } from '@/api/feedback';
import {
  FeedbackStatus,
  FeedbackPriority,
  FeedbackType,
} from '@/api/feedback';

/** Schema 配置选项 */
export interface SchemaOptions {
  /** 编辑回调 */
  onEdit?: (feedback: Feedback) => void;
  /** 删除回调 */
  onDelete?: (feedback: Feedback) => void;
  /** 指派回调 */
  onAssign?: (feedback: Feedback) => void;
  /** 更改状态回调 */
  onChangeStatus?: (feedback: Feedback) => void;
  /** 查看详情回调 */
  onView?: (feedback: Feedback) => void;
  /** 【权限控制】权限配置 */
  permissions?: {
    canEdit?: boolean;
    canDelete?: boolean;
    canAssign?: boolean;
    canChangeStatus?: boolean;
  };
}

/**
 * 生成反馈列表 AMIS Schema
 * 使用 AMIS CRUD 组件的高级配置实现完整的列表功能
 *
 * 高级特性说明：
 * 1. 动态 Schema：通过 api 配置实现运行时数据加载
 * 2. 公式表达式：使用 ${xxx} 语法实现动态渲染
 * 3. 事件动作系统：onEvent + actions 实现交互逻辑
 * 4. 条件渲染：visibleOn、disabledOn 实现权限控制
 * 5. 数据映射：api.data、adaptor 实现数据转换
 * 6. 【权限控制】基于权限的操作按钮显示/隐藏
 */
export function generateFeedbackListSchema(options: SchemaOptions = {}) {
  const { onEdit, onDelete, onAssign, onChangeStatus, onView, permissions = {} } = options;
  const { canEdit = true, canDelete = true, canAssign = true, canChangeStatus = true } = permissions;

  return {
    type: 'page',
    title: '',
    body: {
      type: 'crud',
      name: 'feedbackCrud',
      // 【高级特性】同步 URL 参数，实现页面刷新后保留筛选状态
      syncLocation: false,

      // 【高级特性】API 配置，支持动态数据加载
      api: {
        method: 'get',
        url: '/api/feedback/list',
        // 【高级特性】数据适配器，转换后端数据格式为 AMIS 需要的格式
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
        // 【高级特性】请求数据映射，自动附加分页参数
        data: {
          page: '${page}',
          pageSize: '${perPage}',
          // 【高级特性】公式表达式，动态附加筛选参数
          keyword: '${keyword | default:""}',
          status: '${status | default:undefined}',
          priority: '${priority | default:undefined}',
          type: '${type | default:undefined}',
          handler_id: '${handler_id | default:undefined}',
        },
      },

      // 【高级特性】快速保存 API，支持行内编辑
      quickSaveApi: {
        method: 'put',
        url: '/api/feedback/update',
        data: {
          id: '${id}',
          '&': '$$',
        },
      },

      // 分页配置
      perPage: 20,
      perPageAvailable: [10, 20, 50, 100],
      footerToolbar: ['switch-per-page', 'pagination'],

      // 【高级特性】批量操作配置
      // 【权限控制】根据权限显示批量操作按钮
      bulkActions: [
        // 【权限控制】批量删除 - 仅管理员
        canDelete && {
          type: 'button',
          label: '批量删除',
          level: 'danger',
          // 【高级特性】确认对话框
          confirmText: '确定要删除选中的 ${ids|raw|count} 条反馈吗？',
          actionType: 'ajax',
          api: {
            method: 'delete',
            url: '/api/feedback/batch',
            data: {
              ids: '${ids|raw}',
            },
          },
          // 【高级特性】成功后刷新列表
          onEvent: {
            success: {
              actions: [
                {
                  actionType: 'reload',
                  componentId: 'feedbackCrud',
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
        // 【权限控制】批量更改状态 - 有状态变更权限
        canChangeStatus && {
          type: 'button',
          label: '批量更改状态',
          level: 'primary',
          actionType: 'dialog',
          dialog: {
            title: '批量更改状态',
            size: 'sm',
            body: {
              type: 'form',
              api: {
                method: 'post',
                url: '/api/feedback/batchUpdateStatus',
                data: {
                  ids: '${ids|raw}',
                  status: '${status}',
                  remark: '${remark}',
                },
              },
              body: [
                {
                  type: 'select',
                  name: 'status',
                  label: '新状态',
                  required: true,
                  options: [
                    { label: '待处理', value: 0 },
                    { label: '处理中', value: 1 },
                    { label: '已解决', value: 2 },
                    { label: '已关闭', value: 3 },
                    { label: '已拒绝', value: 4 },
                  ],
                },
                {
                  type: 'textarea',
                  name: 'remark',
                  label: '备注',
                  placeholder: '请输入状态变更备注（可选）',
                },
              ],
            },
            onEvent: {
              confirm: {
                actions: [
                  {
                    actionType: 'reload',
                    componentId: 'feedbackCrud',
                  },
                ],
              },
            },
          },
        },
      ].filter(Boolean),

      // 头部工具栏
      headerToolbar: [
        // 【高级特性】列配置切换器
        'columns-toggler',
        // 【高级特性】刷新按钮
        'reload',
      ],

      // 【高级特性】筛选表单配置
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

      // 【高级特性】表格列配置，使用多种列类型和渲染方式
      columns: [
        // 选择列
        {
          type: 'checkbox',
          name: 'id',
        },
        // ID 列
        {
          name: 'id',
          label: 'ID',
          width: 60,
          sortable: true,
        },
        // 【高级特性】标题列 - 使用链接和自定义渲染
        {
          name: 'title',
          label: '标题',
          width: 280,
          // 【高级特性】使用 tpl 类型自定义渲染
          type: 'tpl',
          tpl: `
            <div class="feedback-title-cell">
              <a href="#/feedback/detail/${'${id}'}" class="feedback-link" title="${'${title}'}">
                ${'${title}'}
              </a>
              ${'${IF(ARRAYLENGTH(tags) > 0, CONCAT("<div class=\\"tag-list\\">", ARRAYMAP(tags, item => CONCAT("<span class=\\"tag-badge\\" style=\\"background:", item.color, "\\">", item.name, "</span>")), "</div>"), "")'}
            </div>
          `,
          // 【高级特性】点击行触发事件
          onEvent: {
            click: {
              actions: [
                {
                  actionType: 'custom',
                  script: `
                    window.dispatchEvent(new CustomEvent('amis:feedback:view', {
                      detail: { id: event.data.id, row: event.data }
                    }));
                  `,
                },
              ],
            },
          },
        },
        // 【高级特性】类型列 - 使用 mapping 映射
        {
          name: 'type',
          label: '类型',
          width: 100,
          type: 'mapping',
          map: {
            0: '<span class="badge badge-feature">功能建议</span>',
            1: '<span class="badge badge-bug">Bug 反馈</span>',
            2: '<span class="badge badge-performance">性能问题</span>',
            3: '<span class="badge badge-ux">用户体验</span>',
            4: '<span class="badge badge-other">其他</span>',
          },
        },
        // 【高级特性】状态列 - 使用 mapping 和颜色标识
        {
          name: 'status',
          label: '状态',
          width: 100,
          type: 'mapping',
          map: {
            0: '<span class="status-badge status-pending">待处理</span>',
            1: '<span class="status-badge status-processing">处理中</span>',
            2: '<span class="status-badge status-resolved">已解决</span>',
            3: '<span class="status-badge status-closed">已关闭</span>',
            4: '<span class="status-badge status-rejected">已拒绝</span>',
          },
        },
        // 【高级特性】优先级列 - 带颜色标识
        {
          name: 'priority',
          label: '优先级',
          width: 80,
          type: 'mapping',
          map: {
            0: '<span class="priority-badge priority-urgent">紧急</span>',
            1: '<span class="priority-badge priority-high">高</span>',
            2: '<span class="priority-badge priority-medium">中</span>',
            3: '<span class="priority-badge priority-low">低</span>',
          },
        },
        // 【高级特性】标签列 - 使用 each 循环渲染
        {
          name: 'tags',
          label: '标签',
          width: 150,
          type: 'each',
          className: 'tag-list',
          items: {
            type: 'tpl',
            tpl: '<span class="tag-badge" style="background-color: ${color}">${name}</span>',
          },
          placeholder: '-',
        },
        // 【高级特性】创建者列 - 自定义头像+名称渲染
        {
          name: 'creator_name',
          label: '创建者',
          width: 120,
          type: 'tpl',
          tpl: `
            <div class="user-cell">
              <img class="user-avatar" src="${'${creator_avatar || "https://joeschmoe.io/api/v1/random"}'}">
              <span class="user-name">${'${creator_name}'}</span>
            </div>
          `,
        },
        // 创建时间列
        {
          name: 'created_at',
          label: '创建时间',
          width: 160,
          type: 'datetime',
          format: 'YYYY-MM-DD HH:mm',
          sortable: true,
        },
        // 【高级特性】指派者列 - 条件渲染
        {
          name: 'handler_name',
          label: '指派给',
          width: 120,
          type: 'tpl',
          tpl: `
            ${'${IF(handler_name, CONCAT("<div class=\\"user-cell\\"><img class=\\"user-avatar\\" src=\\"", handler_avatar || "https://joeschmoe.io/api/v1/random", "\\"><span class=\\"user-name\\">", handler_name, "</span></div>"), "<span class=\\"text-muted\\">未指派</span>")'}
          `,
        },
        // 【高级特性】操作列 - 使用事件动作系统
        // 【权限控制】根据权限显示/隐藏操作按钮
        {
          type: 'operation',
          label: '操作',
          width: 180,
          fixed: 'right',
          buttons: [
            // 【权限控制】编辑按钮
            canEdit && {
              type: 'button',
              label: '编辑',
              level: 'link',
              size: 'sm',
              // 【高级特性】触发自定义事件
              onEvent: {
                click: {
                  actions: [
                    {
                      actionType: 'custom',
                      script: `
                        window.dispatchEvent(new CustomEvent('amis:feedback:edit', {
                          detail: { id: event.data.id, row: event.data }
                        }));
                      `,
                    },
                  ],
                },
              },
            },
            // 【权限控制】指派按钮 - 仅当未指派时显示
            canAssign && {
              type: 'button',
              label: '指派',
              level: 'link',
              size: 'sm',
              // 【高级特性】条件渲染 - 仅当未指派时显示
              visibleOn: '!data.handler_id',
              onEvent: {
                click: {
                  actions: [
                    {
                      actionType: 'custom',
                      script: `
                        window.dispatchEvent(new CustomEvent('amis:feedback:assign', {
                          detail: { id: event.data.id, row: event.data }
                        }));
                      `,
                    },
                  ],
                },
              },
            },
            // 【权限控制】状态按钮
            canChangeStatus && {
              type: 'button',
              label: '状态',
              level: 'link',
              size: 'sm',
              onEvent: {
                click: {
                  actions: [
                    {
                      actionType: 'custom',
                      script: `
                        window.dispatchEvent(new CustomEvent('amis:feedback:status', {
                          detail: { id: event.data.id, row: event.data }
                        }));
                      `,
                    },
                  ],
                },
              },
            },
            // 【权限控制】删除按钮
            canDelete && {
              type: 'button',
              label: '删除',
              level: 'link',
              className: 'text-danger',
              size: 'sm',
              // 【高级特性】确认对话框
              confirmText: '确定要删除该反馈吗？',
              onEvent: {
                click: {
                  actions: [
                    {
                      actionType: 'ajax',
                      api: {
                        method: 'delete',
                        url: '/api/feedback/delete',
                        data: {
                          id: '${id}',
                        },
                      },
                    },
                    {
                      actionType: 'reload',
                      componentId: 'feedbackCrud',
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
          ].filter(Boolean),
        },
      ],

      // 【高级特性】行点击事件
      itemAction: {
        type: 'button',
        onEvent: {
          click: {
            actions: [
              {
                actionType: 'custom',
                script: `
                  window.dispatchEvent(new CustomEvent('amis:feedback:view', {
                    detail: { id: event.data.id, row: event.data }
                  }));
                `,
              },
            ],
          },
        },
      },

      // 【高级特性】行样式 - 根据优先级设置不同背景色
      rowClassNameExpr: `
        ${'${IF(priority === 0, "row-urgent", IF(priority === 1, "row-high", ""))}'}
      `,

      // 【高级特性】空数据提示
      placeholder: {
        type: 'tpl',
        tpl: `
          <div class="empty-state">
            <div class="empty-icon">📭</div>
            <div class="empty-text">暂无反馈数据</div>
            <div class="empty-desc">点击"新建反馈"按钮创建第一条反馈</div>
          </div>
        `,
      },

      // 【高级特性】加载中状态
      loadingConfig: {
        text: '加载中...',
      },
    },

    // 【高级特性】自定义 CSS 样式
    css: `
      .feedback-title-cell {
        display: flex;
        flex-direction: column;
        gap: 4px;
      }
      .feedback-link {
        color: #165dff;
        text-decoration: none;
        font-weight: 500;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
      }
      .feedback-link:hover {
        text-decoration: underline;
      }
      .tag-list {
        display: flex;
        flex-wrap: wrap;
        gap: 4px;
      }
      .tag-badge {
        display: inline-block;
        padding: 2px 8px;
        border-radius: 4px;
        font-size: 12px;
        color: #fff;
        white-space: nowrap;
      }
      .user-cell {
        display: flex;
        align-items: center;
        gap: 8px;
      }
      .user-avatar {
        width: 24px;
        height: 24px;
        border-radius: 50%;
        object-fit: cover;
      }
      .user-name {
        font-size: 14px;
        color: #1d2129;
      }
      .status-badge {
        display: inline-block;
        padding: 2px 8px;
        border-radius: 4px;
        font-size: 12px;
        font-weight: 500;
      }
      .status-pending {
        background-color: #f2f3f5;
        color: #86909c;
      }
      .status-processing {
        background-color: #e8f3ff;
        color: #165dff;
      }
      .status-resolved {
        background-color: #e8ffea;
        color: #00b42a;
      }
      .status-closed {
        background-color: #f2f3f5;
        color: #86909c;
      }
      .status-rejected {
        background-color: #ffece8;
        color: #f53f3f;
      }
      .priority-badge {
        display: inline-block;
        padding: 2px 8px;
        border-radius: 4px;
        font-size: 12px;
        font-weight: 500;
      }
      .priority-urgent {
        background-color: #ffece8;
        color: #f53f3f;
      }
      .priority-high {
        background-color: #fff3e8;
        color: #ff7d00;
      }
      .priority-medium {
        background-color: #fffce8;
        color: #f7ba1e;
      }
      .priority-low {
        background-color: #e8ffea;
        color: #00b42a;
      }
      .badge {
        display: inline-block;
        padding: 2px 8px;
        border-radius: 4px;
        font-size: 12px;
      }
      .badge-feature {
        background-color: #e8f3ff;
        color: #165dff;
      }
      .badge-bug {
        background-color: #ffece8;
        color: #f53f3f;
      }
      .badge-performance {
        background-color: #fff3e8;
        color: #ff7d00;
      }
      .badge-ux {
        background-color: #f5e8ff;
        color: #722ed1;
      }
      .badge-other {
        background-color: #f2f3f5;
        color: #86909c;
      }
      .text-danger {
        color: #f53f3f;
      }
      .text-muted {
        color: #86909c;
      }
      .row-urgent {
        background-color: #fff8f7 !important;
      }
      .row-high {
        background-color: #fffbf5 !important;
      }
      .empty-state {
        text-align: center;
        padding: 40px;
      }
      .empty-icon {
        font-size: 48px;
        margin-bottom: 16px;
      }
      .empty-text {
        font-size: 16px;
        color: #1d2129;
        margin-bottom: 8px;
      }
      .empty-desc {
        font-size: 14px;
        color: #86909c;
      }
    `,
  };
}

/**
 * 生成反馈详情 Schema
 * 用于详情页展示
 */
export function generateFeedbackDetailSchema(feedbackId: number) {
  return {
    type: 'page',
    title: '反馈详情',
    // 【高级特性】初始化 API，页面加载时自动获取数据
    initApi: {
      method: 'get',
      url: '/api/feedback/detail',
      data: {
        id: feedbackId,
      },
      adaptor: `
        return {
          status: (payload.code === 0 || payload.code === 200) ? 0 : payload.code,
          msg: payload.msg,
          data: payload.data?.feedback || {}
        };
      `,
    },
    body: [
      // 基本信息卡片
      {
        type: 'card',
        title: '基本信息',
        body: {
          type: 'form',
          mode: 'horizontal',
          horizontal: {
            left: 3,
            right: 9,
          },
          body: [
            {
              type: 'static',
              name: 'title',
              label: '标题',
            },
            {
              type: 'static',
              name: 'content',
              label: '内容',
            },
            {
              type: 'mapping',
              name: 'type',
              label: '类型',
              map: {
                0: '功能建议',
                1: 'Bug 反馈',
                2: '性能问题',
                3: '用户体验',
                4: '其他',
              },
            },
            {
              type: 'mapping',
              name: 'status',
              label: '状态',
              map: {
                0: '<span class="status-badge status-pending">待处理</span>',
                1: '<span class="status-badge status-processing">处理中</span>',
                2: '<span class="status-badge status-resolved">已解决</span>',
                3: '<span class="status-badge status-closed">已关闭</span>',
                4: '<span class="status-badge status-rejected">已拒绝</span>',
              },
            },
            {
              type: 'mapping',
              name: 'priority',
              label: '优先级',
              map: {
                0: '<span class="priority-badge priority-urgent">紧急</span>',
                1: '<span class="priority-badge priority-high">高</span>',
                2: '<span class="priority-badge priority-medium">中</span>',
                3: '<span class="priority-badge priority-low">低</span>',
              },
            },
            {
              type: 'tpl',
              name: 'tags',
              label: '标签',
              tpl: `
                <div class="tag-list">
                  ${'${ARRAYMAP(tags, item => CONCAT("<span class=\\"tag-badge\\" style=\\"background:", item.color, "\\">", item.name, "</span>"))'}
                </div>
              `,
            },
            {
              type: 'tpl',
              name: 'creator_name',
              label: '创建者',
              tpl: `
                <div class="user-cell">
                  <img class="user-avatar" src="${'${creator_avatar || "https://joeschmoe.io/api/v1/random"}'}">
                  <span>${'${creator_name}'}</span>
                </div>
              `,
            },
            {
              type: 'static',
              name: 'created_at',
              label: '创建时间',
              format: 'YYYY-MM-DD HH:mm:ss',
            },
          ],
        },
      },
      // 评论列表
      {
        type: 'card',
        title: '评论记录',
        className: 'mt-4',
        body: {
          type: 'crud',
          api: {
            method: 'get',
            url: '/api/feedback/comment/list',
            data: {
              feedback_id: feedbackId,
              page: '${page}',
              pageSize: '${perPage}',
            },
          },
          columns: [
            {
              name: 'user_name',
              label: '评论者',
              type: 'tpl',
              tpl: `
                <div class="user-cell">
                  <img class="user-avatar" src="${'${user_avatar || "https://joeschmoe.io/api/v1/random"}'}">
                  <span>${'${user_name}'}</span>
                </div>
              `,
            },
            {
              name: 'content',
              label: '内容',
            },
            {
              name: 'type',
              label: '类型',
              type: 'mapping',
              map: {
                0: '普通评论',
                1: '内部备注',
                2: '系统通知',
              },
            },
            {
              name: 'created_at',
              label: '时间',
              type: 'datetime',
              format: 'YYYY-MM-DD HH:mm',
            },
          ],
        },
      },
    ],
  };
}

/**
 * 生成反馈表单 Schema
 * 用于新建/编辑反馈
 */
export function generateFeedbackFormSchema(isEdit = false) {
  return {
    type: 'form',
    // 【高级特性】根据是否编辑模式选择不同 API
    api: isEdit
      ? {
        method: 'put',
        url: '/api/feedback/update',
        data: {
          id: '${id}',
          '&': '$$',
        },
      }
      : {
        method: 'post',
        url: '/api/feedback/create',
        data: {
          '&': '$$',
        },
      },
    body: [
      {
        type: 'hidden',
        name: 'id',
        // 【高级特性】编辑模式下显示，新增模式下隐藏
        visibleOn: '${id}',
      },
      {
        type: 'input-text',
        name: 'title',
        label: '标题',
        required: true,
        placeholder: '请输入反馈标题',
        validations: {
          maxLength: 100,
        },
        validationErrors: {
          maxLength: '标题长度不能超过100个字符',
        },
      },
      {
        type: 'textarea',
        name: 'content',
        label: '内容',
        required: true,
        placeholder: '请详细描述您的反馈...',
        rows: 5,
        validations: {
          maxLength: 2000,
        },
        validationErrors: {
          maxLength: '内容长度不能超过2000个字符',
        },
      },
      {
        type: 'select',
        name: 'type',
        label: '类型',
        required: true,
        options: [
          { label: '功能建议', value: 0 },
          { label: 'Bug 反馈', value: 1 },
          { label: '性能问题', value: 2 },
          { label: '用户体验', value: 3 },
          { label: '其他', value: 4 },
        ],
      },
      {
        type: 'select',
        name: 'priority',
        label: '优先级',
        required: true,
        options: [
          { label: '紧急', value: 0 },
          { label: '高', value: 1 },
          { label: '中', value: 2, selected: true },
          { label: '低', value: 3 },
        ],
      },
      {
        type: 'select',
        name: 'tag_ids',
        label: '标签',
        multiple: true,
        clearable: true,
        // 【高级特性】从 API 加载选项
        source: {
          method: 'get',
          url: '/api/feedback/tag/list',
          adaptor: `
            const list = payload.data?.list || [];
            return {
              options: list.map(item => ({
                label: item.name,
                value: item.id
              }))
            };
          `,
        },
      },
      {
        type: 'input-image',
        name: 'attachments',
        label: '附件',
        multiple: true,
        receiver: '/api/upload/image',
        placeholder: '支持上传图片附件',
      },
    ],
    // 【高级特性】提交成功后的动作
    onEvent: {
      submitSucc: {
        actions: [
          {
            actionType: 'toast',
            args: {
              msg: isEdit ? '更新成功' : '创建成功',
              level: 'success',
            },
          },
          {
            actionType: 'closeDialog',
          },
          {
            actionType: 'reload',
            componentId: 'feedbackCrud',
          },
        ],
      },
    },
  };
}

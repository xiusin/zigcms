export const complexSchema = {
  type: 'page',
  title: '用户管理',
  body: {
    type: 'crud',
    syncLocation: false,
    api: '/api/mock/users',
    headerToolbar: [
      {
        type: 'button',
        label: '新增用户',
        actionType: 'dialog',
        level: 'primary',
        dialog: {
          title: '新增用户',
          body: {
            type: 'form',
            api: 'post:/api/mock/users',
            body: [
              {
                type: 'input-text',
                name: 'username',
                label: '用户名',
                required: true,
              },
              {
                type: 'input-email',
                name: 'email',
                label: '邮箱',
                required: true,
              },
              {
                type: 'input-text',
                name: 'phone',
                label: '手机号',
                required: true,
              },
              {
                type: 'select',
                name: 'role',
                label: '角色',
                required: true,
                options: [
                  { label: '管理员', value: 'admin' },
                  { label: '普通用户', value: 'user' },
                ],
              },
            ],
          },
        },
      },
      'bulkActions',
      'reload',
    ],
    filter: {
      title: '搜索',
      body: [
        {
          type: 'input-text',
          name: 'keyword',
          label: '关键词',
          placeholder: '请输入用户名或邮箱',
        },
        {
          type: 'select',
          name: 'role',
          label: '角色',
          placeholder: '请选择角色',
          options: [
            { label: '管理员', value: 'admin' },
            { label: '普通用户', value: 'user' },
          ],
        },
      ],
    },
    columns: [
      {
        name: 'id',
        label: 'ID',
        width: 60,
      },
      {
        name: 'username',
        label: '用户名',
        searchable: true,
      },
      {
        name: 'email',
        label: '邮箱',
      },
      {
        name: 'phone',
        label: '手机号',
      },
      {
        name: 'role',
        label: '角色',
        type: 'mapping',
        map: {
          admin: "<span class='label label-success'>管理员</span>",
          user: "<span class='label label-info'>普通用户</span>",
        },
      },
      {
        name: 'status',
        label: '状态',
        type: 'switch',
        quickEdit: {
          mode: 'inline',
          type: 'switch',
          saveImmediately: true,
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
        buttons: [
          {
            label: '编辑',
            type: 'button',
            actionType: 'dialog',
            dialog: {
              title: '编辑用户',
              body: {
                type: 'form',
                api: 'put:/api/mock/users/$id',
                body: [
                  {
                    type: 'input-text',
                    name: 'username',
                    label: '用户名',
                    required: true,
                  },
                  {
                    type: 'input-email',
                    name: 'email',
                    label: '邮箱',
                    required: true,
                  },
                  {
                    type: 'input-text',
                    name: 'phone',
                    label: '手机号',
                    required: true,
                  },
                  {
                    type: 'select',
                    name: 'role',
                    label: '角色',
                    required: true,
                    options: [
                      { label: '管理员', value: 'admin' },
                      { label: '普通用户', value: 'user' },
                    ],
                  },
                ],
              },
            },
          },
          {
            label: '删除',
            type: 'button',
            level: 'danger',
            actionType: 'ajax',
            confirmText: '确定要删除该用户吗？',
            api: 'delete:/api/mock/users/$id',
          },
        ],
      },
    ],
  },
};

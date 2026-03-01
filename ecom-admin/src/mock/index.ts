/**
 * Mock 数据汇总文件
 * 包含所有业务模块的 Mock 数据
 * 使用方式：在开发环境中替换实际的 API 请求
 */

import Mock from 'mockjs';
import { complexSchema } from './complex-schema';
import cmsMock from './cms';
import feedbackMock from './feedback';
import feedbackNotificationMock from './feedback-notification';
import oauthMock from './oauth';
import autoTestMock from './auto-test';
import qualityCenterMock from './quality-center';

// 注册 CMS Mock
cmsMock.forEach((item) => {
  Mock.mock(new RegExp(item.url), item.method, item.response);
});

// 注册反馈系统 Mock
feedbackMock.forEach((item: any) => {
  Mock.mock(new RegExp(item.url), item.method, item.response);
});

// 注册反馈通知 Mock
feedbackNotificationMock.forEach((item: any) => {
  Mock.mock(new RegExp(item.url), item.method, item.response);
});

// 注册 OAuth Mock
oauthMock.forEach((item: any) => {
  Mock.mock(new RegExp(item.url), item.method, item.response);
});

// 注册自动化测试系统 Mock
autoTestMock.forEach((item: any) => {
  Mock.mock(new RegExp(item.url), item.method, item.response);
});

// 注册质量中心 Mock
qualityCenterMock.forEach((item: any) => {
  Mock.mock(new RegExp(item.url), item.method, item.response);
});

// 设置 Mock 随机数的全局种子，保证数据一致性
Mock.Random.extend({
  phone() {
    const phonePrefix = [
      '132',
      '135',
      '136',
      '138',
      '139',
      '150',
      '151',
      '152',
      '153',
      '155',
      '156',
      '158',
      '159',
      '170',
      '176',
      '178',
      '180',
      '181',
      '182',
      '183',
      '184',
      '185',
      '186',
      '187',
      '188',
      '189',
    ];
    return this.pick(phonePrefix) + this.string('numeric', 8);
  },
  idCard() {
    const prefix = [
      '110',
      '120',
      '130',
      '140',
      '150',
      '210',
      '220',
      '230',
      '310',
      '320',
      '330',
      '340',
      '350',
      '360',
      '370',
      '410',
      '420',
      '430',
      '440',
      '500',
      '510',
      '520',
      '530',
      '610',
    ];
    const addrCode = this.pick(prefix) + String(Mock.Random.natural(100, 999));
    const birthCode = Mock.Random.date('yyyyMMdd').replace(/-/g, '');
    const seqCode = String(Mock.Random.natural(100, 999));
    return addrCode + birthCode + seqCode;
  },
});

// 公共响应格式
const responseSuccess = (data: any, msg = 'success') => ({
  code: 200,
  msg,
  data,
});

const responsePage = (list: any[], page = 1, pageSize = 10) => ({
  code: 200,
  msg: 'success',
  data: {
    list,
    pagination: {
      page,
      pageSize,
      total: list.length,
    },
  },
});

// ==================== 低代码示例 ====================
export const mockLowcodeSchema = () => {
  return responseSuccess({
    type: 'page',
    title: '用户管理系统',
    subTitle: '完整的用户增删改查示例',
    body: [
      {
        type: 'grid',
        columns: [
          {
            md: 3,
            body: [
              {
                type: 'card',
                header: {
                  title: '总用户数',
                  subTitle: '截止今日',
                },
                body: {
                  type: 'tpl',
                  tpl: '<div style="font-size: 32px; font-weight: bold; color: var(--color-primary);">1,234</div>',
                },
              },
            ],
          },
          {
            md: 3,
            body: [
              {
                type: 'card',
                header: {
                  title: '活跃用户',
                  subTitle: '最近7天',
                },
                body: {
                  type: 'tpl',
                  tpl: '<div style="font-size: 32px; font-weight: bold; color: var(--color-success);">856</div>',
                },
              },
            ],
          },
          {
            md: 3,
            body: [
              {
                type: 'card',
                header: {
                  title: '新增用户',
                  subTitle: '今日',
                },
                body: {
                  type: 'tpl',
                  tpl: '<div style="font-size: 32px; font-weight: bold; color: var(--color-warning);">45</div>',
                },
              },
            ],
          },
          {
            md: 3,
            body: [
              {
                type: 'card',
                header: {
                  title: '禁用用户',
                  subTitle: '当前',
                },
                body: {
                  type: 'tpl',
                  tpl: '<div style="font-size: 32px; font-weight: bold; color: var(--color-danger);">12</div>',
                },
              },
            ],
          },
        ],
      },
      {
        type: 'divider',
      },
      {
        type: 'crud',
        syncLocation: false,
        api: '/api/mock/users',
        headerToolbar: [
          'bulkActions',
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
                    placeholder: '请输入用户名',
                  },
                  {
                    type: 'input-email',
                    name: 'email',
                    label: '邮箱',
                    required: true,
                    placeholder: '请输入邮箱',
                  },
                  {
                    type: 'input-text',
                    name: 'phone',
                    label: '手机号',
                    required: true,
                    placeholder: '请输入手机号',
                    validations: {
                      isPhoneNumber: true,
                    },
                  },
                  {
                    type: 'select',
                    name: 'role',
                    label: '角色',
                    required: true,
                    options: [
                      { label: '管理员', value: 'admin' },
                      { label: '普通用户', value: 'user' },
                      { label: '访客', value: 'guest' },
                    ],
                  },
                  {
                    type: 'select',
                    name: 'status',
                    label: '状态',
                    value: 1,
                    options: [
                      { label: '启用', value: 1 },
                      { label: '禁用', value: 0 },
                    ],
                  },
                  {
                    type: 'textarea',
                    name: 'remark',
                    label: '备注',
                    placeholder: '请输入备注信息',
                    maxLength: 200,
                  },
                ],
              },
            },
          },
          {
            type: 'button',
            label: '批量导入',
            actionType: 'dialog',
            dialog: {
              title: '批量导入用户',
              body: {
                type: 'form',
                body: [
                  {
                    type: 'input-file',
                    name: 'file',
                    label: '选择文件',
                    accept: '.xlsx,.xls',
                    receiver: '/api/mock/upload',
                  },
                ],
              },
            },
          },
          'reload',
          {
            type: 'export-excel',
            label: '导出Excel',
          },
        ],
        footerToolbar: ['statistics', 'switch-per-page', 'pagination'],
        columns: [
          {
            name: 'id',
            label: 'ID',
            width: 80,
            sortable: true,
          },
          {
            name: 'username',
            label: '用户名',
            searchable: true,
          },
          {
            name: 'email',
            label: '邮箱',
            searchable: true,
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
              guest: "<span class='label label-default'>访客</span>",
            },
          },
          {
            name: 'status',
            label: '状态',
            type: 'status',
            quickEdit: {
              type: 'switch',
              mode: 'inline',
              saveImmediately: true,
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
            width: 200,
            buttons: [
              {
                type: 'button',
                label: '详情',
                level: 'link',
                actionType: 'dialog',
                dialog: {
                  title: '用户详情',
                  body: {
                    type: 'form',
                    api: 'get:/api/mock/users/$id',
                    body: [
                      {
                        type: 'static',
                        name: 'username',
                        label: '用户名',
                      },
                      {
                        type: 'static',
                        name: 'email',
                        label: '邮箱',
                      },
                      {
                        type: 'static',
                        name: 'phone',
                        label: '手机号',
                      },
                      {
                        type: 'static',
                        name: 'role',
                        label: '角色',
                      },
                      {
                        type: 'static',
                        name: 'remark',
                        label: '备注',
                      },
                    ],
                  },
                },
              },
              {
                type: 'button',
                label: '编辑',
                level: 'link',
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
                          { label: '访客', value: 'guest' },
                        ],
                      },
                      {
                        type: 'textarea',
                        name: 'remark',
                        label: '备注',
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
                actionType: 'ajax',
                confirmText: '确定要删除该用户吗？',
                api: 'delete:/api/mock/users/$id',
              },
            ],
          },
        ],
      },
    ],
  });
};

// 导入复杂 Schema
export const mockComplexLowcodeSchema = () => {
  return responseSuccess(complexSchema);
};

// ==================== 字典管理 ====================
export const mockDictList = () => {
  return responseSuccess({
    list: [
      {
        id: 1,
        category_code: 'system',
        category_name: '系统配置',
        dict_name: '用户状态',
        dict_code: 'user_status',
        remark: '用户账号状态',
        status: 1,
        created_at: '2024-01-01 10:00:00',
      },
      {
        id: 2,
        category_code: 'system',
        category_name: '系统配置',
        dict_name: '性别',
        dict_code: 'gender',
        remark: '用户性别',
        status: 1,
        created_at: '2024-01-01 10:00:00',
      },
      {
        id: 3,
        category_code: 'business',
        category_name: '业务配置',
        dict_name: '订单状态',
        dict_code: 'order_status',
        remark: '订单状态枚举',
        status: 1,
        created_at: '2024-01-02 10:00:00',
      },
      {
        id: 4,
        category_code: 'business',
        category_name: '业务配置',
        dict_name: '支付方式',
        dict_code: 'payment_method',
        remark: '支付方式枚举',
        status: 1,
        created_at: '2024-01-02 10:00:00',
      },
      {
        id: 5,
        category_code: 'user',
        category_name: '用户相关',
        dict_name: '会员等级',
        dict_code: 'member_level',
        remark: '会员等级分类',
        status: 1,
        created_at: '2024-01-03 10:00:00',
      },
      {
        id: 6,
        category_code: 'order',
        category_name: '订单相关',
        dict_name: '配送方式',
        dict_code: 'delivery_method',
        remark: '配送方式枚举',
        status: 1,
        created_at: '2024-01-03 10:00:00',
      },
    ],
    total: 6,
  });
};

export const mockDictItems = (options: any) => {
  const url = options.url || '';
  const dictCodeMatch = url.match(/dict_code=([^&]+)/);
  const dictIdMatch = options.body ? JSON.parse(options.body).dict_id : null;

  const dictCode = dictCodeMatch ? dictCodeMatch[1] : '';
  const dictId = dictIdMatch;

  // 根据字典编码返回数据
  if (dictCode === 'user_role') {
    return responseSuccess({
      list: [
        {
          id: 1,
          dict_id: 99,
          item_name: '管理员',
          item_value: 'admin',
          sort: 1,
          status: 1,
        },
        {
          id: 2,
          dict_id: 99,
          item_name: '普通用户',
          item_value: 'user',
          sort: 2,
          status: 1,
        },
        {
          id: 3,
          dict_id: 99,
          item_name: '访客',
          item_value: 'guest',
          sort: 3,
          status: 1,
        },
      ],
    });
  }

  // 根据字典 ID 返回数据
  const itemsMap: any = {
    1: [
      {
        id: 1,
        dict_id: 1,
        item_name: '正常',
        item_value: '1',
        sort: 1,
        status: 1,
      },
      {
        id: 2,
        dict_id: 1,
        item_name: '禁用',
        item_value: '0',
        sort: 2,
        status: 1,
      },
      {
        id: 3,
        dict_id: 1,
        item_name: '锁定',
        item_value: '2',
        sort: 3,
        status: 1,
      },
    ],
    2: [
      {
        id: 4,
        dict_id: 2,
        item_name: '男',
        item_value: '1',
        sort: 1,
        status: 1,
      },
      {
        id: 5,
        dict_id: 2,
        item_name: '女',
        item_value: '2',
        sort: 2,
        status: 1,
      },
      {
        id: 6,
        dict_id: 2,
        item_name: '保密',
        item_value: '0',
        sort: 3,
        status: 1,
      },
    ],
    3: [
      {
        id: 7,
        dict_id: 3,
        item_name: '待支付',
        item_value: '1',
        sort: 1,
        status: 1,
      },
      {
        id: 8,
        dict_id: 3,
        item_name: '已支付',
        item_value: '2',
        sort: 2,
        status: 1,
      },
      {
        id: 9,
        dict_id: 3,
        item_name: '配送中',
        item_value: '3',
        sort: 3,
        status: 1,
      },
      {
        id: 10,
        dict_id: 3,
        item_name: '已完成',
        item_value: '4',
        sort: 4,
        status: 1,
      },
      {
        id: 11,
        dict_id: 3,
        item_name: '已取消',
        item_value: '0',
        sort: 5,
        status: 1,
      },
    ],
    4: [
      {
        id: 12,
        dict_id: 4,
        item_name: '微信支付',
        item_value: 'wechat',
        sort: 1,
        status: 1,
      },
      {
        id: 13,
        dict_id: 4,
        item_name: '支付宝',
        item_value: 'alipay',
        sort: 2,
        status: 1,
      },
      {
        id: 14,
        dict_id: 4,
        item_name: '银行卡',
        item_value: 'bank',
        sort: 3,
        status: 1,
      },
    ],
    5: [
      {
        id: 15,
        dict_id: 5,
        item_name: '普通会员',
        item_value: '1',
        sort: 1,
        status: 1,
      },
      {
        id: 16,
        dict_id: 5,
        item_name: '银卡会员',
        item_value: '2',
        sort: 2,
        status: 1,
      },
      {
        id: 17,
        dict_id: 5,
        item_name: '金卡会员',
        item_value: '3',
        sort: 3,
        status: 1,
      },
      {
        id: 18,
        dict_id: 5,
        item_name: '钻石会员',
        item_value: '4',
        sort: 4,
        status: 1,
      },
    ],
    6: [
      {
        id: 19,
        dict_id: 6,
        item_name: '快递配送',
        item_value: 'express',
        sort: 1,
        status: 1,
      },
      {
        id: 20,
        dict_id: 6,
        item_name: '上门自提',
        item_value: 'pickup',
        sort: 2,
        status: 1,
      },
      {
        id: 21,
        dict_id: 6,
        item_name: '同城配送',
        item_value: 'local',
        sort: 3,
        status: 1,
      },
    ],
  };

  return responseSuccess({
    list: itemsMap[dictId] || [],
  });
};

// ==================== 登录相关 ====================
export const mockLogin = () => {
  return {
    code: 200,
    msg: '登录成功',
    data: {
      token: `mock_token_${Mock.Random.guid()}`,
      userInfo: {
        userId: 1,
        username: 'admin',
        nickname: '系统管理员',
        avatar:
          'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png',
        email: 'admin@example.com',
        mobile: '13800138000',
        department_id: 1,
        department_name: '总部',
        role_ids: [1],
        role_text: '超级管理员',
        status: 1,
        created_at: '2023-01-01 00:00:00',
      },
      expire: 1728000000, // 7天过期
    },
  };
};

export const mockRefreshInfo = () => {
  return {
    code: 200,
    msg: 'success',
    data: {
      userId: 1,
      username: 'admin',
      nickname: '系统管理员',
      avatar:
        'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png',
      email: 'admin@example.com',
      mobile: '13800138000',
      department_id: 1,
      department_name: '总部',
      role_ids: [1],
      role_text: '超级管理员',
      status: 1,
    },
  };
};

// ==================== 用户管理 ====================
export const mockMemberList = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'username': '@cname',
        'nickname': '@cname',
        'mobile': '@phone',
        'email': '@email',
        'role_ids': [1],
        'role_text': '管理员',
        'department_id': 1,
        'department_name': '总部',
        'status|0-1': 1,
        'created_at': '@datetime',
        'password': '******',
      },
    ],
  });

  return responsePage(list);
};

export const mockMemberSave = () => {
  return responseSuccess({ id: Mock.Random.guid() }, '保存成功');
};

export const mockMemberDelete = () => {
  return responseSuccess(null, '删除成功');
};

export const mockMemberSet = () => {
  return responseSuccess(null, '设置成功');
};

// ==================== 角色管理 ====================
export const mockRoleList = () => {
  const { list } = Mock.mock({
    'list|10': [
      {
        'id|+1': 1,
        'role_name': '@cword(2,4)',
        'role_key': '@word',
        'description': '@cparagraph(1)',
        'pages|3-8': ['@cword(2,4)'],
        'business_user_name': '@cname',
        'status|0-1': 1,
        'created_at': '@datetime',
        'updated_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

export const mockRoleSave = () => {
  return responseSuccess({ id: Mock.Random.guid() }, '保存成功');
};

export const mockRoleDelete = () => {
  return responseSuccess(null, '删除成功');
};

export const mockRoleInfo = () => {
  return responseSuccess({
    id: 1,
    role_name: '管理员',
    role_key: 'admin',
    description: '系统管理员角色',
    pages: ['user', 'role', 'department'],
    status: 1,
  });
};

// ==================== 部门管理 ====================
export const mockDepartmentList = () => {
  const { list } = Mock.mock({
    'list|15': [
      {
        'id|+1': 1,
        'name': '@cword(2,6)',
        'parent_id': 0,
        'leader': '@cname',
        'phone': '@phone',
        'email': '@email',
        'sort|1-100': 1,
        'status|0-1': 1,
        'created_at': '@datetime',
      },
    ],
  });

  // 添加子部门
  list.forEach((item: any) => {
    if (item.id <= 5) {
      item.children = Mock.mock({
        'list|2-4': [
          {
            'id|+1': item.id * 100,
            'name': '@cword(2,4)部',
            'parent_id': item.id,
            'leader': '@cname',
            'phone': '@phone',
            'email': '@email',
            'sort|1-100': 1,
            'status|0-1': 1,
            'created_at': '@datetime',
          },
        ],
      }).list;
    }
  });

  return responseSuccess(list);
};

export const mockDepartmentSave = () => {
  return responseSuccess({ id: Mock.Random.guid() }, '保存成功');
};

export const mockDepartmentDel = () => {
  return responseSuccess(null, '删除成功');
};

// ==================== 供应商管理 ====================
export const mockSupplierList = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'supplier_name': '@ccompany',
        'contact_person': '@cname',
        'contact_phone': '@phone',
        'address': '@province@city@county',
        'status|0-1': 1,
        'created_at': '@datetime',
        'updated_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

export const mockSupplierSave = () => {
  return responseSuccess({ id: Mock.Random.guid() }, '保存成功');
};

export const mockSupplierDelete = () => {
  return responseSuccess(null, '删除成功');
};

export const mockChangeUserState = () => {
  return responseSuccess(null, '状态更新成功');
};

// ==================== 仓库产品 ====================
export const mockWarehouseProductList = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'product_name': '@cword(2,8)商品',
        'product_code': '@word(10)',
        'sku_code': '@word(8)',
        'category': '@word(2,4)',
        'brand': '@cword(2,4)',
        'color': '@color',
        'size': '@word(2,4)',
        'stock_num|0-1000': 100,
        'position_id': 1,
        'position_name': 'A区-01-01',
        'warehouse_name': '@word(2,4)仓库',
        'price|1-1000.2': 100,
        'cost_price|1-500.2': 50,
        'image_url': 'https://via.placeholder.com/150',
        'status|0-1': 1,
        'created_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

export const mockWarehouseProductInfo = () => {
  return responseSuccess({
    id: 1,
    product_name: '测试商品',
    product_code: 'PROD001',
    sku_code: 'SKU001',
    category: '服装',
    brand: '品牌A',
    color: '红色',
    size: 'L',
    stock_num: 100,
    position_id: 1,
    position_name: 'A区-01-01',
    warehouse_name: '主仓库',
    price: 199.0,
    cost_price: 99.0,
    image_url: 'https://via.placeholder.com/150',
    description: '商品描述',
    status: 1,
  });
};

export const mockWarehouseProductSave = () => {
  return responseSuccess({ id: Mock.Random.guid() }, '保存成功');
};

export const mockWarehouseProductDelete = () => {
  return responseSuccess(null, '删除成功');
};

export const mockWarehouseProductShelveList = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'product_name': '@cword(2,8)商品',
        'product_code': '@word(10)',
        'sku_code': '@word(8)',
        'stock_num|0-1000': 100,
        'shelve_num|0-100': 50,
        'warehouse_name': '@word(2,4)仓库',
        'position_name': 'A区-01-01',
        'created_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

export const mockWarehouseProductOffShelf = () => {
  return responseSuccess(null, '下架成功');
};

export const mockWarehouseProductShelve = () => {
  return responseSuccess(null, '上架成功');
};

export const mockWarehouseProductOutboundList = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'order_no': 'OUT@datetime("yyyyMMddHHmmss")',
        'product_name': '@cword(2,8)商品',
        'sku_code': '@word(8)',
        'num|1-100': 10,
        'express_no': '@word(12)',
        'express_company': '@word(2,4)快递',
        'receiver_name': '@cname',
        'receiver_phone': '@phone',
        'receiver_address': '@province@city@county',
        'status|0-3': 1,
        'outbound_time': '@datetime',
        'created_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

export const mockWarehouseProductRefund = () => {
  return responseSuccess(null, '退货成功');
};

export const mockWarehouseProductDetailList = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'product_name': '@cword(2,8)商品',
        'product_code': '@word(10)',
        'sku_code': '@word(8)',
        'stock_num|0-1000': 100,
        'available_num|0-1000': 80,
        'locked_num|0-100': 20,
        'warehouse_name': '@word(2,4)仓库',
        'position_name': 'A区-01-01',
        'updated_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

export const mockWarehouseProductUpdateExpressNo = () => {
  return responseSuccess(null, '更新成功');
};

export const mockWarehouseProductUpdateReceiver = () => {
  return responseSuccess(null, '更新成功');
};

export const mockWarehouseProductBatchModifyPosition = () => {
  return responseSuccess(null, '批量修改成功');
};

// ==================== 订单管理 ====================
export const mockOrderList = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'order_no': 'ORD@datetime("yyyyMMddHHmmss")',
        'product_name': '@cword(2,8)商品',
        'sku_code': '@word(8)',
        'num|1-100': 10,
        'price|1-1000.2': 100,
        'total_price|1-10000.2': 1000,
        'user_name': '@cname',
        'user_phone': '@phone',
        'user_address': '@province@city@county',
        'status|0-5': 1,
        'pay_time': '@datetime',
        'created_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

// ==================== 提单管理 ====================
export const mockPickupList = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'pickup_no': 'PK@datetime("yyyyMMddHHmmss")',
        'order_no': 'ORD@datetime("yyyyMMddHHmmss")',
        'product_name': '@cword(2,8)商品',
        'sku_code': '@word(8)',
        'num|1-100': 10,
        'warehouse_name': '@word(2,4)仓库',
        'receiver_name': '@cname',
        'receiver_phone': '@phone',
        'status|0-3': 1,
        'created_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

export const mockPickupSave = () => {
  return responseSuccess({ id: Mock.Random.guid() }, '保存成功');
};

// ==================== 需求管理 ====================
export const mockDemandList = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'demand_no': 'DM@datetime("yyyyMMddHHmmss")',
        'product_name': '@cword(2,8)商品',
        'sku_code': '@word(8)',
        'num|1-100': 10,
        'warehouse_name': '@word(2,4)仓库',
        'expected_date': '@date',
        'status|0-3': 1,
        'created_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

export const mockDemandInfo = () => {
  return responseSuccess({
    id: 1,
    demand_no: 'DM2024010100001',
    product_name: '测试商品',
    sku_code: 'SKU001',
    num: 100,
    warehouse_id: 1,
    warehouse_name: '主仓库',
    expected_date: '2024-01-15',
    remark: '备注信息',
    status: 1,
    created_at: '2024-01-01 00:00:00',
  });
};

export const mockDemandSave = () => {
  return responseSuccess({ id: Mock.Random.guid() }, '保存成功');
};

export const mockDemandProducts = () => {
  return responseSuccess(
    Mock.mock({
      'list|10': [
        {
          'id|+1': 1,
          'product_name': '@cword(2,8)商品',
          'sku_code': '@word(8)',
          'stock_num|0-1000': 100,
        },
      ],
    }).list
  );
};

export const mockDemandTemplate = () => {
  return responseSuccess({
    template_id: 1,
    template_name: '标准需求模板',
    fields: [
      { field: 'product_name', label: '商品名称', type: 'text' },
      { field: 'sku_code', label: 'SKU编码', type: 'text' },
      { field: 'num', label: '数量', type: 'number' },
      { field: 'expected_date', label: '期望日期', type: 'date' },
      { field: 'remark', label: '备注', type: 'textarea' },
    ],
  });
};

// ==================== 退货管理 ====================
export const mockRefundList = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'refund_no': 'RF@datetime("yyyyMMddHHmmss")',
        'order_no': 'ORD@datetime("yyyyMMddHHmmss")',
        'product_name': '@cword(2,8)商品',
        'sku_code': '@word(8)',
        'num|1-100': 10,
        'refund_reason': '@cword(3,8)',
        'status|0-3': 1,
        'created_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

export const mockRefundSubmit = () => {
  return responseSuccess({ id: Mock.Random.guid() }, '提交成功');
};

export const mockRefundTable = () => {
  return responseSuccess(null, '操作成功');
};

// ==================== 审批管理 ====================
export const mockApprovalList = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'approval_no': 'AP@datetime("yyyyMMddHHmmss")',
        'title': '@cword(4,10)审批',
        'type|1-5': 1,
        'applicant': '@cname',
        'status|0-3': 1,
        'created_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

export const mockApprovalSave = () => {
  return responseSuccess({ id: Mock.Random.guid() }, '保存成功');
};

// ==================== 流量管理 ====================
export const mockFlowList = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'date': '@date',
        'pv|1000-100000': 10000,
        'uv|500-50000': 5000,
        'ip|500-50000': 5000,
        'bounce_rate|0-100': 30,
        'avg_stay_time|10-300': 120,
        'channel': '@word(2,4)',
        'created_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

// ==================== 品牌管理 ====================
export const mockBrandList = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'brand_name': '@cword(2,6)',
        'brand_code': '@word',
        'logo': 'https://via.placeholder.com/150',
        'description': '@cparagraph(1)',
        'status|0-1': 1,
        'created_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

export const mockBrandSave = () => {
  return responseSuccess({ id: Mock.Random.guid() }, '保存成功');
};

// ==================== 模板管理 ====================
export const mockTemplateList = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'template_name': '@cword(4,10)模板',
        'template_code': '@word',
        'type|1-3': 1,
        'content': '@cparagraph(2)',
        'status|0-1': 1,
        'created_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

export const mockTemplateSave = () => {
  return responseSuccess({ id: Mock.Random.guid() }, '保存成功');
};

// ==================== 日志管理 ====================
export const mockLogList = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'username': '@cname',
        'module': '@word(2,4)',
        'operation': '@cword(2,6)',
        'method': 'POST',
        'ip': '@ip',
        'location': '@province@city',
        'status|0-1': 1,
        'remark': '@cparagraph(1)',
        'created_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

// ==================== 任务中心 ====================
export const mockTaskCenterAdCreateList = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'task_id': '@guid',
        'task_name': '创建广告任务',
        'status|0-3': 1,
        'total|10-100': 50,
        'success|0-50': 40,
        'fail|0-10': 5,
        'pending|0-10': 5,
        'created_at': '@datetime',
        'finished_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

export const mockTaskCenterAdCreateDetail = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'ad_name': '@cword(4,10)广告',
        'ad_id': '@guid',
        'status|0-3': 1,
        'error_msg': '',
        'created_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

export const mockTaskCenterResendAd = () => {
  return responseSuccess(null, '重新发送成功');
};

export const mockTaskCenterAdEditList = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'task_id': '@guid',
        'task_name': '编辑广告任务',
        'status|0-3': 1,
        'total|10-100': 50,
        'success|0-50': 40,
        'fail|0-10': 5,
        'created_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

export const mockTaskCenterAdEditDetails = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'ad_name': '@cword(4,10)广告',
        'old_value': '旧值',
        'new_value': '新值',
        'status|0-3': 1,
        'error_msg': '',
        'created_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

export const mockTaskCenterResendEditTask = () => {
  return responseSuccess(null, '重新发送成功');
};

export const mockTaskCenterAdCopyList = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'task_id': '@guid',
        'task_name': '复制广告任务',
        'status|0-3': 1,
        'total|10-100': 50,
        'success|0-50': 40,
        'created_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

export const mockTaskCenterAdCopyDetails = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'source_ad_name': '源广告',
        'target_ad_name': '目标广告',
        'status|0-3': 1,
        'error_msg': '',
        'created_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

export const mockTaskCenterResendCopyTask = () => {
  return responseSuccess(null, '重新发送成功');
};

export const mockTaskCenterDownLoadTask = () => {
  const { list } = Mock.mock({
    'list|20': [
      {
        'id|+1': 1,
        'task_id': '@guid',
        'task_name': '下载任务',
        'file_name': '导出数据.xlsx',
        'status|0-3': 1,
        'file_size': '10MB',
        'download_url': '#',
        'created_at': '@datetime',
      },
    ],
  });

  return responsePage(list);
};

export const mockTaskCenterReDownLoadTask = () => {
  return responseSuccess(null, '重新下载成功');
};

// ==================== 报表统计 ====================
export const mockOperationReportStatistics = () => {
  return responseSuccess({
    total_order: 12580,
    total_amount: 2580000,
    total_user: 8560,
    today_order: 156,
    today_amount: 28000,
    yesterday_order: 142,
    yesterday_amount: 25000,
    week_order: 980,
    week_amount: 180000,
    month_order: 4250,
    month_amount: 780000,
  });
};

export const mockCommonOverview = () => {
  return responseSuccess({
    total: 12580,
    yesterday: 142,
    today: 156,
    week: 980,
    month: 4250,
    growth: 9.86,
  });
};

export const mockV2PlanDataOverview = () => {
  return responseSuccess({
    overview: {
      total: 12580,
      yesterday: 142,
      today: 156,
      growth: 9.86,
    },
    trend: Mock.mock({
      'list|30': [
        {
          'date': '@date',
          'value|100-10000': 1000,
        },
      ],
    }).list,
  });
};

// ==================== 系统设置 ====================
export const mockSystemSettingInfo = () => {
  return responseSuccess({
    system_name: '电商管理系统',
    system_logo: 'https://via.placeholder.com/150',
    copyright: '© 2024 公司名称',
    icp_number: 'ICP证123456号',
    version: '1.0.8',
  });
};

export const mockSystemSetting = () => {
  return responseSuccess(null, '保存成功');
};

// ==================== 媒体账户 ====================
export const mockMediaAccountList = () => {
  return responseSuccess(
    Mock.mock({
      'list|10': [
        {
          'id|+1': 1,
          'account_id': '@guid',
          'account_name': '@cword(2,6)账户',
          'media_type|1-5': 1,
          'status|0-1': 1,
        },
      ],
    }).list
  );
};

// ==================== 水印设置 ====================
export const mockGetWatermark = () => {
  return responseSuccess({
    open: true,
    text: '内部资料',
    position: 'center',
    opacity: 0.3,
  });
};

export const mockSetWatermark = () => {
  return responseSuccess(null, '设置成功');
};

export const mockSetWaterMarkState = () => {
  return responseSuccess(null, '设置成功');
};

// ==================== 内容数据 ====================
export const mockContentData = () => {
  return responseSuccess(
    Mock.mock({
      'list|12': [
        {
          'month': '@date("MM")月',
          'value|1000-10000': 5000,
        },
      ],
    }).list
  );
};

export const mockPopularList = () => {
  return responseSuccess(
    Mock.mock({
      'list|10': [
        {
          'key|+1': 1,
          'title': '@ctitle(10,30)',
          'clickNumber|1000-100000': 10000,
          'increases|0-100': 10,
        },
      ],
    }).list
  );
};

// ==================== 消息列表 ====================
export const mockMessageList = () => {
  return responseSuccess(
    Mock.mock({
      'list|15': [
        {
          'id|+1': 1,
          'type': '@word(2,4)',
          'title': '@ctitle(10,20)',
          'subTitle': '@cparagraph(1)',
          'avatar': 'https://via.placeholder.com/40',
          'content': '@cparagraph(2)',
          'time': '@datetime',
          'status|0-1': 1,
          'messageType|1-5': 1,
        },
      ],
    }).list
  );
};

export const mockMessageRead = () => {
  return responseSuccess(null, '设置已读成功');
};

export const mockChatList = () => {
  return responseSuccess(
    Mock.mock({
      'list|10': [
        {
          'id|+1': 1,
          'username': '@cname',
          'content': '@cparagraph(1)',
          'time': '@datetime',
          'isCollect|true-false': false,
        },
      ],
    }).list
  );
};

// ==================== 产品详情选项 ====================
export const mockProductDetailOptionList = () => {
  return responseSuccess(
    Mock.mock({
      'list|10': [
        {
          'id|+1': 1,
          'option_name': '@cword(2,4)',
          'option_value': '@word',
          'sort|1-100': 1,
          'status|0-1': 1,
        },
      ],
    }).list
  );
};

export const mockProductDetailOptionSave = () => {
  return responseSuccess({ id: Mock.Random.guid() }, '保存成功');
};

export const mockProductDetailOptionDelete = () => {
  return responseSuccess(null, '删除成功');
};

// ==================== 密码重置 ====================
export const mockResetPassword = () => {
  return responseSuccess(null, '密码重置成功');
};

// 导出所有 Mock 数据
export default {
  // 登录
  mockLogin,
  mockRefreshInfo,

  // 用户管理
  mockMemberList,
  mockMemberSave,
  mockMemberDelete,
  mockMemberSet,

  // 角色管理
  mockRoleList,
  mockRoleSave,
  mockRoleDelete,
  mockRoleInfo,

  // 部门管理
  mockDepartmentList,
  mockDepartmentSave,
  mockDepartmentDel,

  // 供应商管理
  mockSupplierList,
  mockSupplierSave,
  mockSupplierDelete,
  mockChangeUserState,

  // 仓库产品
  mockWarehouseProductList,
  mockWarehouseProductInfo,
  mockWarehouseProductSave,
  mockWarehouseProductDelete,
  mockWarehouseProductShelveList,
  mockWarehouseProductOffShelf,
  mockWarehouseProductShelve,
  mockWarehouseProductOutboundList,
  mockWarehouseProductRefund,
  mockWarehouseProductDetailList,
  mockWarehouseProductUpdateExpressNo,
  mockWarehouseProductUpdateReceiver,
  mockWarehouseProductBatchModifyPosition,

  // 订单管理
  mockOrderList,

  // 提单管理
  mockPickupList,
  mockPickupSave,

  // 需求管理
  mockDemandList,
  mockDemandInfo,
  mockDemandSave,
  mockDemandProducts,
  mockDemandTemplate,

  // 退货管理
  mockRefundList,
  mockRefundSubmit,
  mockRefundTable,

  // 审批管理
  mockApprovalList,
  mockApprovalSave,

  // 流量管理
  mockFlowList,

  // 品牌管理
  mockBrandList,
  mockBrandSave,

  // 模板管理
  mockTemplateList,
  mockTemplateSave,

  // 日志管理
  mockLogList,

  // 任务中心
  mockTaskCenterAdCreateList,
  mockTaskCenterAdCreateDetail,
  mockTaskCenterResendAd,
  mockTaskCenterAdEditList,
  mockTaskCenterAdEditDetails,
  mockTaskCenterResendEditTask,
  mockTaskCenterAdCopyList,
  mockTaskCenterAdCopyDetails,
  mockTaskCenterResendCopyTask,
  mockTaskCenterDownLoadTask,
  mockTaskCenterReDownLoadTask,

  // 报表统计
  mockOperationReportStatistics,
  mockCommonOverview,
  mockV2PlanDataOverview,

  // 系统设置
  mockSystemSettingInfo,
  mockSystemSetting,

  // 媒体账户
  mockMediaAccountList,

  // 水印设置
  mockGetWatermark,
  mockSetWatermark,
  mockSetWaterMarkState,

  // 内容数据
  mockContentData,
  mockPopularList,

  // 消息列表
  mockMessageList,
  mockMessageRead,
  mockChatList,

  // 产品详情选项
  mockProductDetailOptionList,
  mockProductDetailOptionSave,
  mockProductDetailOptionDelete,

  // 密码重置
  mockResetPassword,

  // 低代码示例
  mockLowcodeSchema,
  mockComplexLowcodeSchema,
  // 字典管理
  mockDictList,
  mockDictItems,
};

// ==================== Mock 接口注册 ====================
if (import.meta.env.DEV) {
  // 低代码示例 Schema
  Mock.mock('/api/lowcode/demo-schema', 'get', mockComplexLowcodeSchema);

  // 字典管理
  Mock.mock(/\/api\/system\/dict\/list(\?.*)?$/, 'get', mockDictList);
  Mock.mock(/\/api\/system\/dict\/items(\?.*)?$/, 'get', mockDictItems);
  Mock.mock('/api/system/dict/save', 'post', () => responseSuccess({}));
  Mock.mock('/api/system/dict/set', 'post', () => responseSuccess({}));
  Mock.mock('/api/system/dict/delete', 'post', () => responseSuccess({}));
  Mock.mock('/api/system/dict/item/save', 'post', () => responseSuccess({}));
  Mock.mock('/api/system/dict/item/set', 'post', () => responseSuccess({}));
  Mock.mock('/api/system/dict/item/delete', 'post', () => responseSuccess({}));

  // 用户列表 CRUD
  Mock.mock(/\/api\/mock\/users(\?.*)?$/, 'get', () => {
    const { list } = Mock.mock({
      'list|15': [
        {
          'id|+1': 1,
          'username': '@name',
          'email': '@email',
          'phone': '@phone',
          'role|1': ['admin', 'user', 'guest'],
          'status|0-1': 1,
          'created_at': '@datetime',
          'remark': '@sentence',
        },
      ],
    });
    return responseSuccess({
      items: list,
      total: 15,
    });
  });

  Mock.mock(/\/api\/mock\/users\/\d+$/, 'get', (options: any) => {
    const id = options.url.match(/\/api\/mock\/users\/(\d+)$/)[1];
    return responseSuccess({
      id: Number(id),
      username: Mock.Random.name(),
      email: Mock.Random.email(),
      phone: Mock.Random.phone(),
      role: Mock.Random.pick(['admin', 'user', 'guest']),
      status: 1,
      created_at: Mock.Random.datetime(),
      remark: Mock.Random.sentence(),
    });
  });

  Mock.mock('/api/mock/users', 'post', responseSuccess(true, '创建成功'));
  Mock.mock(
    /\/api\/mock\/users\/\d+$/,
    'put',
    responseSuccess(true, '更新成功')
  );
  Mock.mock(
    /\/api\/mock\/users\/\d+$/,
    'delete',
    responseSuccess(true, '删除成功')
  );

  // 商品列表 CRUD
  Mock.mock(/\/api\/mock\/products(\?.*)?$/, 'get', () => {
    const { list } = Mock.mock({
      'list|20': [
        {
          'id|+1': 1,
          'name': '@ctitle(5, 10)',
          'price|100-9999': 100,
          'category|1': ['electronics', 'clothing', 'food', 'books'],
          'status|0-1': 1,
          'created_at': '@datetime',
        },
      ],
    });
    return responseSuccess({ items: list, total: 20 });
  });

  // 订单列表 CRUD
  Mock.mock(/\/api\/mock\/orders(\?.*)?$/, 'get', () => {
    const { list } = Mock.mock({
      'list|25': [
        {
          'id|+1': 1,
          'order_no': '@id',
          'user_name': '@cname',
          'amount|100-9999': 100,
          'status|1': ['pending', 'paid', 'shipped', 'completed', 'cancelled'],
          'created_at': '@datetime',
        },
      ],
    });
    return responseSuccess({ items: list, total: 25 });
  });

  // 文章列表 CRUD
  Mock.mock(/\/api\/mock\/articles(\?.*)?$/, 'get', () => {
    const { list } = Mock.mock({
      'list|15': [
        {
          'id|+1': 1,
          'title': '@ctitle(10, 20)',
          'author_id|1-10': 1,
          'category_id|1-5': 1,
          'status|0-1': 1,
          'created_at': '@datetime',
        },
      ],
    });
    return responseSuccess({ items: list, total: 15 });
  });

  // 菜单列表 CRUD
  Mock.mock(/\/api\/mock\/menus(\?.*)?$/, 'get', () => {
    const { list } = Mock.mock({
      'list|10': [
        {
          'id|+1': 1,
          'name': '@ctitle(3, 6)',
          'icon':
            '@pick(["icon-home", "icon-user", "icon-settings", "icon-file"])',
          'sort|1-100': 1,
          'status|0-1': 1,
        },
      ],
    });
    return responseSuccess({ items: list, total: 10 });
  });

  // 销售数据 CRUD
  Mock.mock(/\/api\/mock\/sales(\?.*)?$/, 'get', () => {
    const { list } = Mock.mock({
      'list|30': [
        {
          'id|+1': 1,
          'date': '@date',
          'product': '@ctitle(5, 10)',
          'amount|100-9999': 100,
          'quantity|1-100': 1,
        },
      ],
    });
    return responseSuccess({ items: list, total: 30 });
  });

  // 销售统计
  Mock.mock('/api/mock/sales/statistics', 'get', () => {
    return responseSuccess({
      total_amount: 1234567,
      order_count: 1234,
      avg_amount: 1000,
      max_amount: 9999,
    });
  });

  // 部门列表（树形）
  Mock.mock(/\/api\/mock\/departments(\?.*)?$/, 'get', () => {
    return responseSuccess({
      items: [
        {
          id: 1,
          name: '总公司',
          manager: '张三',
          employee_count: 100,
          status: 1,
          children: [
            {
              id: 2,
              name: '技术部',
              manager: '李四',
              employee_count: 50,
              status: 1,
              parent_id: 1,
              children: [
                {
                  id: 3,
                  name: '前端组',
                  manager: '王五',
                  employee_count: 20,
                  status: 1,
                  parent_id: 2,
                },
                {
                  id: 4,
                  name: '后端组',
                  manager: '赵六',
                  employee_count: 30,
                  status: 1,
                  parent_id: 2,
                },
              ],
            },
            {
              id: 5,
              name: '市场部',
              manager: '孙七',
              employee_count: 30,
              status: 1,
              parent_id: 1,
            },
            {
              id: 6,
              name: '财务部',
              manager: '周八',
              employee_count: 20,
              status: 1,
              parent_id: 1,
            },
          ],
        },
      ],
      total: 6,
    });
  });

  // 文档列表 CRUD
  Mock.mock(/\/api\/mock\/documents(\?.*)?$/, 'get', () => {
    const { list } = Mock.mock({
      'list|15': [
        {
          'id|+1': 1,
          'title': '@ctitle(10, 20)',
          'author': '@cname',
          'status|0-1': 1,
          'created_at': '@datetime',
        },
      ],
    });
    return responseSuccess({ items: list, total: 15 });
  });

  // 分类列表（关联数据）
  Mock.mock(/\/api\/mock\/categories(\?.*)?$/, 'get', () => {
    return responseSuccess({
      items: [
        { id: 1, name: '技术' },
        { id: 2, name: '生活' },
        { id: 3, name: '娱乐' },
        { id: 4, name: '新闻' },
        { id: 5, name: '其他' },
      ],
      total: 5,
    });
  });

  // 通用 POST/PUT/DELETE
  Mock.mock(
    /\/api\/mock\/(products|orders|articles|menus|sales|departments|documents)$/,
    'post',
    responseSuccess(true, '创建成功')
  );
  Mock.mock(
    /\/api\/mock\/(products|orders|articles|menus|sales|departments|documents)\/\d+$/,
    'put',
    responseSuccess(true, '更新成功')
  );
  Mock.mock(
    /\/api\/mock\/(products|orders|articles|menus|sales|departments|documents)\/\d+$/,
    'delete',
    responseSuccess(true, '删除成功')
  );
  Mock.mock(
    /\/api\/mock\/(products|orders|articles|menus|sales|departments|documents)\/batch$/,
    'delete',
    responseSuccess(true, '批量删除成功')
  );
  Mock.mock(
    /\/api\/mock\/(products|orders|articles|menus|sales|departments|documents)\/order$/,
    'post',
    responseSuccess(true, '排序保存成功')
  );
}

// ==================== 业务交互演示 Mock 数据 ====================

// 部门树形数据
Mock.mock(/\/api\/department\/tree(\?.*)?$/, 'get', () => {
  return responseSuccess({
    items: [
      {
        id: 1,
        name: '总公司',
        code: 'HQ',
        status: 1,
        children: [
          {
            id: 2,
            name: '技术部',
            code: 'TECH',
            status: 1,
            parent_id: 1,
            children: [
              { id: 3, name: '前端组', code: 'FE', status: 1, parent_id: 2 },
              { id: 4, name: '后端组', code: 'BE', status: 1, parent_id: 2 },
              { id: 5, name: '测试组', code: 'QA', status: 1, parent_id: 2 },
            ],
          },
          {
            id: 6,
            name: '销售部',
            code: 'SALES',
            status: 1,
            parent_id: 1,
            children: [
              { id: 7, name: '华东区', code: 'EAST', status: 1, parent_id: 6 },
              { id: 8, name: '华南区', code: 'SOUTH', status: 1, parent_id: 6 },
            ],
          },
          {
            id: 9,
            name: '市场部',
            code: 'MKT',
            status: 1,
            parent_id: 1,
          },
          {
            id: 10,
            name: '财务部',
            code: 'FIN',
            status: 1,
            parent_id: 1,
          },
        ],
      },
    ],
    total: 10,
  });
});

// 用户列表
Mock.mock(/\/api\/member\/list(\?.*)?$/, 'get', () => {
  const { list } = Mock.mock({
    'list|50': [
      {
        'id|+1': 1,
        'username': '@name',
        'nickname': '@cname',
        'mobile': '@phone',
        'email': '@email',
        'dept_id|1-10': 1,
        'status|0-1': 1,
        'login_count|10-500': 100,
        'last_login': '@datetime',
        'created_at': '@datetime',
      },
    ],
  });
  return responseSuccess({ items: list, total: 50 });
});

// 分类列表
Mock.mock(/\/api\/category\/list(\?.*)?$/, 'get', () => {
  return responseSuccess({
    items: [
      { id: 1, name: '电子产品', sort: 1, status: 1 },
      { id: 2, name: '服装鞋包', sort: 2, status: 1 },
      { id: 3, name: '食品饮料', sort: 3, status: 1 },
      { id: 4, name: '家居用品', sort: 4, status: 1 },
      { id: 5, name: '图书音像', sort: 5, status: 1 },
    ],
    total: 5,
  });
});

// 商品列表
Mock.mock(/\/api\/product\/list(\?.*)?$/, 'get', () => {
  const { list } = Mock.mock({
    'list|30': [
      {
        'id|+1': 1,
        'name': '@ctitle(5, 15)',
        'price|100-9999': 100,
        'stock|0-1000': 100,
        'category_id|1-5': 1,
        'status|0-1': 1,
        'created_at': '@datetime',
      },
    ],
  });
  return responseSuccess({ items: list, total: 30 });
});

// 操作日志
Mock.mock(/\/api\/operation\/log(\?.*)?$/, 'get', () => {
  const actions = ['新增', '编辑', '删除', '查看', '导出', '导入'];
  const modules = ['用户管理', '部门管理', '商品管理', '订单管理', '系统设置'];
  const { list } = Mock.mock({
    'list|100': [
      {
        'id|+1': 1,
        'username': '@cname',
        'action|1': actions,
        'module|1': modules,
        'ip': '@ip',
        'created_at': '@datetime',
      },
    ],
  });
  return responseSuccess({ items: list, total: 100 });
});

// 销售数据
Mock.mock(/\/api\/sales\/list(\?.*)?$/, 'get', () => {
  const { list } = Mock.mock({
    'list|100': [
      {
        'id|+1': 1,
        'order_no': '@guid',
        'product_name': '@ctitle(5, 10)',
        'amount|100-9999': 100,
        'created_at': '@datetime',
      },
    ],
  });
  return responseSuccess({ items: list, total: 100 });
});

// 导出接口
Mock.mock(/\/api\/product\/export$/, 'post', () => {
  return responseSuccess({ url: '/mock/export.csv' }, '导出成功');
});

// 页面配置管理
const pages: any[] = [
  {
    id: 1,
    name: '用户列表',
    code: 'user_list',
    schema: { type: 'page', title: '用户列表', body: [] },
    created_at: '2026-02-24 08:00:00',
    updated_at: '2026-02-24 08:00:00',
  },
  {
    id: 2,
    name: '订单管理',
    code: 'order_manage',
    schema: { type: 'page', title: '订单管理', body: [] },
    created_at: '2026-02-24 08:00:00',
    updated_at: '2026-02-24 08:00:00',
  },
];

Mock.mock(/\/api\/page\/list(\?.*)?$/, 'get', () => {
  return responseSuccess({ items: pages, total: pages.length });
});

// ==================== 页面配置 Mock API (已移除) ====================
// 编辑器相关功能已删除

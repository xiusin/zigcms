/**
 * Mock 数据 - 用于 Vite Mock 插件
 * 键为 API 路径，值为响应数据或函数
 */

type MockResponse = any;

// 响应格式化
const success = (data: any, msg = 'success'): MockResponse => ({
  code: 200,
  msg,
  data,
});

const pageSuccess = (list: any[], page = 1, pageSize = 10): MockResponse => ({
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

// 生成随机数据辅助函数
const randomId = () => Math.floor(Math.random() * 10000) + 1;
const randomDate = () =>
  new Date(Date.now() - Math.random() * 30 * 24 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 19)
    .replace('T', ' ');
const randomName = () =>
  ['张三', '李四', '王五', '赵六', '钱七', '孙八', '周九', '吴十'][
  Math.floor(Math.random() * 8)
  ];
const randomPhone = () => `138${Math.floor(Math.random() * 100000000)}`;

// Mock 数据映射
export const mockData: Record<
  string,
  MockResponse | ((req?: any) => MockResponse)
> = {
  // 登录
  '/api/system/member/login': {
    code: 200,
    msg: '登录成功',
    data: {
      token: `mock_token_${randomId()}`,
      userId: 1,
      username: 'admin',
      nickname: '系统管理员',
      avatar:
        'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png',
      email: 'admin@example.com',
      mobile: '13800138000',
      department_id: 1,
      department_name: '总部',
      role_id: 1,
      role_ids: [1],
      role_text: '超级管理员',
      status: 1,
      pages: ['dashboard', 'user', 'role', 'department', 'order', 'warehouse'],
      created_at: '2023-01-01 00:00:00',
      expire: 1728000000,
    },
  },

  '/api/member/refreshInfo': {
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
      pages: ['system', 'user', 'role', 'department', 'order', 'product'],
      buttons: [
        'btn:add',
        'btn:edit',
        'btn:delete',
        'btn:export',
        'btn:import',
        'btn:query',
      ],
    },
  },

  // 权限刷新
  '/api/member/refreshPermissions': success(
    {
      pages: ['system', 'user', 'role', 'department', 'order', 'product'],
      buttons: [
        'btn:add',
        'btn:edit',
        'btn:delete',
        'btn:export',
        'btn:import',
        'btn:query',
      ],
      role_ids: [1],
    },
    '权限刷新成功'
  ),

  // 用户管理
  '/api/member/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      username: randomName(),
      nickname: randomName(),
      mobile: randomPhone(),
      email: `user${i + 1}@example.com`,
      role_ids: [1],
      role_text: '管理员',
      department_id: 1,
      department_name: '总部',
      status: 1,
      created_at: randomDate(),
      password: '******',
    }))
  ),

  '/api/member/save': success({ id: randomId() }, '保存成功'),
  '/api/member/delete': success(null, '删除成功'),
  '/api/member/set': success(null, '设置成功'),

  // 角色管理
  '/api/system/role/list': pageSuccess(
    Array.from({ length: 10 }, (_, i) => ({
      id: i + 1,
      role_name: ['管理员', '普通用户', '审核员', '运营员', '财务'][i % 5],
      role_key: `role_${i + 1}`,
      description: '角色描述',
      pages: ['user', 'role', 'department'],
      business_user_name: randomName(),
      status: 1,
      created_at: randomDate(),
      updated_at: randomDate(),
    }))
  ),

  '/api/system/role/save': success({ id: randomId() }, '保存成功'),
  '/api/system/role/delete': success(null, '删除成功'),
  '/api/system/role/info': success({
    id: 1,
    role_name: '管理员',
    role_key: 'admin',
    description: '系统管理员角色',
    pages: ['user', 'role', 'department'],
    button_perms: [
      'btn:add',
      'btn:edit',
      'btn:delete',
      'btn:export',
      'btn:query',
    ],
    status: 1,
  }),
  // 角色按钮权限配置
  '/api/system/role/button-perms': success([
    { label: '新增', value: 'btn:add' },
    { label: '编辑', value: 'btn:edit' },
    { label: '删除', value: 'btn:delete' },
    { label: '导出', value: 'btn:export' },
    { label: '导入', value: 'btn:import' },
    { label: '查询', value: 'btn:query' },
    { label: '详情', value: 'btn:detail' },
    { label: '审核', value: 'btn:audit' },
    { label: '启用', value: 'btn:enable' },
    { label: '禁用', value: 'btn:disable' },
    { label: '分配权限', value: 'btn:permission' },
    { label: '重置密码', value: 'btn:resetPwd' },
  ]),

  // 部门管理
  '/api/department/list': success(
    Array.from({ length: 15 }, (_, i) => ({
      id: i + 1,
      name: ['总部', '研发部', '运营部', '财务部', '市场部'][i % 5],
      parent_id: i < 5 ? 0 : (i % 5) + 1,
      leader: randomName(),
      phone: randomPhone(),
      email: `dept${i + 1}@example.com`,
      sort: i + 1,
      status: 1,
      created_at: randomDate(),
    }))
  ),

  '/api/department/save': success({ id: randomId() }, '保存成功'),
  '/api/department/del': success(null, '删除成功'),

  // 供应商管理
  '/api/supplierList': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      supplier_name: `供应商${i + 1}`,
      contact_person: randomName(),
      contact_phone: randomPhone(),
      address: '广东省深圳市南山区',
      status: 1,
      created_at: randomDate(),
      updated_at: randomDate(),
    }))
  ),

  '/api/supplierSave': success({ id: randomId() }, '保存成功'),
  '/api/supplierDelete': success(null, '删除成功'),
  '/api/changeUserState': success(null, '状态更新成功'),

  // 仓库产品
  '/api/warehouse/product/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      product_name: `商品${i + 1}`,
      product_code: `PROD${String(i + 1).padStart(6, '0')}`,
      sku_code: `SKU${String(i + 1).padStart(6, '0')}`,
      category: ['服装', '数码', '食品', '家居'][i % 4],
      brand: `品牌${(i % 4) + 1}`,
      color: ['红色', '蓝色', '黑色', '白色'][i % 4],
      size: ['S', 'M', 'L', 'XL'][i % 4],
      stock_num: Math.floor(Math.random() * 1000),
      position_id: (i % 10) + 1,
      position_name: `A区-${String((i % 10) + 1).padStart(2, '0')}-01`,
      warehouse_name: '主仓库',
      price: Math.floor(Math.random() * 1000) + 100,
      cost_price: Math.floor(Math.random() * 500) + 50,
      image_url: 'https://via.placeholder.com/150',
      status: 1,
      created_at: randomDate(),
    }))
  ),

  '/api/warehouse/product/info': success({
    id: 1,
    product_id: 1,
    product_no: 'P2024001',
    product_name: 'LV经典款手提包',
    brand_name: 'LV',
    style_name: '经典款',
    element_name: '皮革',
    color_name: '黑色',
    size_name: 'M',
    quality_name: '全新',
    supplier_name: '供应商A',
    dimension: '30*20*15cm',
    public_price: '25800.00',
    price: '19800.00',
    in_warehouse_price: '15000.00',
    outbound_price: '18800.00',
    in_warehouse_type_text: '供应商直供',
    sale_channel_text: '直播带货',
    main_anchor_name: '主播A',
    sec_anchor_name: '场控B',
    instruction: '出库用于直播销售',
    remark: '备注信息',
    user_name: '张三',
    created_at: randomDate(),
    accessories: ['防尘袋', '说明书', '发票'],
    accessories_instruction: '配件齐全',
    main_imgurl: 'https://via.placeholder.com/150',
    detail_image_urls: {
      主图: ['https://via.placeholder.com/150'],
      正面图: [],
      背面图: [],
      五金图: [],
      底面图: [],
      内衬图: [],
      LOGO: [],
      配件图: [],
      瑕疵图: [],
    },
  }),

  '/api/warehouse/product/save': success({ id: randomId() }, '保存成功'),
  '/api/warehouse/product/delete': success(null, '删除成功'),
  '/api/warehouse/product/shelve-list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      product_name: `商品${i + 1}`,
      product_code: `PROD${String(i + 1).padStart(6, '0')}`,
      sku_code: `SKU${String(i + 1).padStart(6, '0')}`,
      stock_num: Math.floor(Math.random() * 1000),
      shelve_num: Math.floor(Math.random() * 100),
      warehouse_name: '主仓库',
      position_name: `A区-${String((i % 10) + 1).padStart(2, '0')}-01`,
      created_at: randomDate(),
    }))
  ),

  '/api/warehouse/product/off-shelf': success(null, '下架成功'),
  '/api/warehouse/product/shelve': success(null, '上架成功'),

  '/api/warehouse/product/outbound-list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      order_no: `OUT${new Date().getTime()}${i}`,
      product_name: `商品${i + 1}`,
      sku_code: `SKU${String(i + 1).padStart(6, '0')}`,
      num: Math.floor(Math.random() * 100) + 1,
      express_no: `${Math.floor(Math.random() * 1000000000000)}`,
      express_company: ['顺丰', '圆通', '中通', '韵达'][i % 4],
      receiver_name: randomName(),
      receiver_phone: randomPhone(),
      receiver_address: '广东省深圳市南山区',
      status: Math.floor(Math.random() * 4),
      outbound_time: randomDate(),
      created_at: randomDate(),
    }))
  ),

  '/api/warehouse/product/refund': success(null, '退货成功'),
  '/api/warehouse/product/update-express-no': success(null, '更新成功'),
  '/api/warehouse/product/update-receiver': success(null, '更新成功'),
  '/api/warehouse/product/batch/modify-position': success(null, '批量修改成功'),
  '/api/warehouse/product/detail-list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      product_name: `商品${i + 1}`,
      product_code: `PROD${String(i + 1).padStart(6, '0')}`,
      sku_code: `SKU${String(i + 1).padStart(6, '0')}`,
      stock_num: Math.floor(Math.random() * 1000),
      available_num: Math.floor(Math.random() * 800),
      locked_num: Math.floor(Math.random() * 200),
      warehouse_name: '主仓库',
      position_name: `A区-${String((i % 10) + 1).padStart(2, '0')}-01`,
      updated_at: randomDate(),
    }))
  ),

  // 订单管理
  '/api/order/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      order_no: `ORD${new Date().getTime()}${i}`,
      product_name: `商品${i + 1}`,
      sku_code: `SKU${String(i + 1).padStart(6, '0')}`,
      num: Math.floor(Math.random() * 100) + 1,
      price: Math.floor(Math.random() * 1000) + 100,
      total_price: Math.floor(Math.random() * 10000) + 1000,
      user_name: randomName(),
      user_phone: randomPhone(),
      user_address: '广东省深圳市',
      status: Math.floor(Math.random() * 6),
      pay_time: randomDate(),
      created_at: randomDate(),
    }))
  ),

  // 提单管理
  '/api/pickup/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      pickup_no: `PK${new Date().getTime()}${i}`,
      order_no: `ORD${new Date().getTime()}${i}`,
      product_name: `商品${i + 1}`,
      sku_code: `SKU${String(i + 1).padStart(6, '0')}`,
      num: Math.floor(Math.random() * 100) + 1,
      warehouse_name: '主仓库',
      receiver_name: randomName(),
      receiver_phone: randomPhone(),
      status: Math.floor(Math.random() * 4),
      created_at: randomDate(),
    }))
  ),

  '/api/pickup/save': success({ id: randomId() }, '保存成功'),

  // 需求管理
  '/api/demand/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      demand_no: `DM${new Date().getTime()}${i}`,
      product_name: `商品${i + 1}`,
      sku_code: `SKU${String(i + 1).padStart(6, '0')}`,
      num: Math.floor(Math.random() * 100) + 1,
      warehouse_name: '主仓库',
      expected_date: new Date(
        Date.now() + Math.random() * 30 * 24 * 60 * 60 * 1000
      )
        .toISOString()
        .slice(0, 10),
      status: Math.floor(Math.random() * 4),
      created_at: randomDate(),
    }))
  ),

  '/api/demand/info': success({
    id: 1,
    demand_no: 'DM2024010100001',
    product_name: '测试商品',
    sku_code: 'SKU000001',
    num: 100,
    warehouse_id: 1,
    warehouse_name: '主仓库',
    expected_date: '2024-01-15',
    remark: '备注信息',
    status: 1,
    created_at: '2024-01-01 00:00:00',
  }),

  '/api/demand/save': success({ id: randomId() }, '保存成功'),
  '/api/demand/products': success(
    Array.from({ length: 10 }, (_, i) => ({
      id: i + 1,
      product_name: `商品${i + 1}`,
      sku_code: `SKU${String(i + 1).padStart(6, '0')}`,
      stock_num: Math.floor(Math.random() * 1000),
    }))
  ),

  '/api/demand/template': success({
    template_id: 1,
    template_name: '标准需求模板',
    fields: [
      { field: 'product_name', label: '商品名称', type: 'text' },
      { field: 'sku_code', label: 'SKU编码', type: 'text' },
      { field: 'num', label: '数量', type: 'number' },
      { field: 'expected_date', label: '期望日期', type: 'date' },
      { field: 'remark', label: '备注', type: 'textarea' },
    ],
  }),

  // 退货管理
  '/api/refund/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      refund_no: `RF${new Date().getTime()}${i}`,
      order_no: `ORD${new Date().getTime()}${i}`,
      product_name: `商品${i + 1}`,
      sku_code: `SKU${String(i + 1).padStart(6, '0')}`,
      num: Math.floor(Math.random() * 100) + 1,
      refund_reason: '质量问题',
      status: Math.floor(Math.random() * 4),
      created_at: randomDate(),
    }))
  ),

  '/api/refund/submit': success({ id: randomId() }, '提交成功'),
  '/api/refund/table': success(null, '操作成功'),

  // 审批管理
  '/api/approval/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      approval_id: i + 1,
      product_id: 100 + i,
      product_no: `P${2024001 + i}`,
      type_name: ['出库申请', '入库申请', '退货申请', '调拨申请', '盘点申请'][
        i % 5
      ],
      brand_name: ['LV', 'Gucci', 'Prada', 'Hermès', 'Chanel'][i % 5],
      style_name: ['经典款', '限量款', '特别款', '周年款', '联名款'][i % 5],
      element_name: ['金属', '皮革', '帆布', '丝绸', '羊毛'][i % 5],
      color_name: ['黑色', '白色', '红色', '蓝色', '金色'][i % 5],
      size_name: ['S', 'M', 'L', 'XL', 'XXL'][i % 5],
      quality_name: ['全新', '九成新', '八成新', '七成新', '六成新'][i % 5],
      in_warehouse_price: (Math.random() * 10000 + 1000).toFixed(2),
      price: (Math.random() * 20000 + 2000).toFixed(2),
      outbound_price: (Math.random() * 15000 + 1500).toFixed(2),
      public_price: (Math.random() * 25000 + 2500).toFixed(2),
      user_name: randomName(),
      created_at: randomDate(),
      status_text: ['待审核', '已通过', '已拒绝', '已取消'][
        Math.floor(Math.random() * 4)
      ],
      approval_user_name: ['管理员', '审核员', '主管'][i % 3],
      pickup_num: i % 3 === 0 ? 0 : Math.floor(Math.random() * 10),
    }))
  ),

  '/api/approval/save': success({ id: randomId() }, '保存成功'),

  // 流量管理
  '/api/flow/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      date: new Date(Date.now() - i * 24 * 60 * 60 * 1000)
        .toISOString()
        .slice(0, 10),
      pv: Math.floor(Math.random() * 100000) + 10000,
      uv: Math.floor(Math.random() * 50000) + 5000,
      ip: Math.floor(Math.random() * 50000) + 5000,
      bounce_rate: Math.floor(Math.random() * 100),
      avg_stay_time: Math.floor(Math.random() * 300) + 60,
      channel: ['抖音', '快手', '微信', '微博'][i % 4],
      created_at: randomDate(),
    }))
  ),

  // 字典管理
  '/api/dict/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      dict_name: `字典${i + 1}`,
      dict_code: `dict_${i + 1}`,
      description: '字典描述',
      status: 1,
      created_at: randomDate(),
    }))
  ),

  '/api/dict/save': success({ id: randomId() }, '保存成功'),
  '/api/dict/styles': success(
    Array.from({ length: 10 }, (_, i) => ({
      id: i + 1,
      name: `样式${i + 1}`,
      value: `style_${i + 1}`,
    }))
  ),

  // 品牌管理
  '/api/brand/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      brand_name: `品牌${i + 1}`,
      brand_code: `BRAND${String(i + 1).padStart(6, '0')}`,
      logo: 'https://via.placeholder.com/150',
      description: '品牌描述',
      status: 1,
      created_at: randomDate(),
    }))
  ),

  '/api/brand/save': success({ id: randomId() }, '保存成功'),

  // 模板管理
  '/api/template/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      template_name: `模板${i + 1}`,
      template_code: `TPL${String(i + 1).padStart(6, '0')}`,
      type: (i % 3) + 1,
      content: '模板内容',
      status: 1,
      created_at: randomDate(),
    }))
  ),

  '/api/template/save': success({ id: randomId() }, '保存成功'),

  // 日志管理
  '/api/system/log/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      user_text: randomName(),
      company_name: ['测试公司A', '测试公司B', '测试公司C'][i % 3],
      company_type: ['企业', '个人', '政府'][i % 3],
      opt_menu: ['用户管理', '角色管理', '订单管理', '系统设置'][i % 4],
      opt_target: ['用户张三', '角色管理员', '订单#12345', '系统配置'][i % 4],
      opt_action: ['登录', '新增', '编辑', '删除', '导出'][i % 5],
      opt_info: '对用户进行了编辑操作，修改了用户状态和角色信息',
      ip: `192.168.1.${Math.floor(Math.random() * 255)}`,
      opt_time: randomDate(),
      browser: ['Chrome', 'Firefox', 'Safari', 'Edge'][i % 4],
      os: ['Windows 10', 'macOS', 'Linux', 'iOS'][i % 4],
      device_type: ['PC', 'Mobile', 'Tablet'][i % 3],
      request_params: JSON.stringify({ id: i + 1, status: 1 }),
      response_data: JSON.stringify({ code: 200, msg: 'success' }),
    }))
  ),
  '/api/system/log/export': success(
    { url: '/downloads/operation_log.xlsx' },
    '导出成功'
  ),

  // 审计日志统计
  '/api/system/log/statistics': success({
    // 统计概览
    total: 15680,
    today: 328,
    activeUsers: 156,
    errors: 23,
    // 操作类型分布（饼图数据）
    actionDistribution: [
      { name: '登录', value: 4520 },
      { name: '新增', value: 3210 },
      { name: '编辑', value: 2890 },
      { name: '删除', value: 890 },
      { name: '导出', value: 2150 },
      { name: '查看', value: 2020 },
    ],
    // 最近7天趋势（折线图数据）
    trendData: [
      { date: '2026-02-16', count: 280 },
      { date: '2026-02-17', count: 320 },
      { date: '2026-02-18', count: 290 },
      { date: '2026-02-19', count: 350 },
      { date: '2026-02-20', count: 310 },
      { date: '2026-02-21', count: 380 },
      { date: '2026-02-22', count: 328 },
    ],
  }),

  // 日志清理
  '/api/system/log/clean': success(null, '日志清理成功'),

  // 日志归档
  '/api/system/log/archive': success(
    { url: '/downloads/log_archive_2026_01.zip' },
    '归档成功'
  ),

  // 任务中心 - 广告创建
  '/api/taskCenter/adCreateList': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      task_id: `task_${randomId()}`,
      task_name: '创建广告任务',
      status: Math.floor(Math.random() * 4),
      total: Math.floor(Math.random() * 100) + 10,
      success: Math.floor(Math.random() * 50) + 10,
      fail: Math.floor(Math.random() * 10),
      pending: Math.floor(Math.random() * 10),
      created_at: randomDate(),
      finished_at: randomDate(),
    }))
  ),

  '/api/taskCenter/adCreateDetail': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      ad_name: `广告${i + 1}`,
      ad_id: `ad_${randomId()}`,
      status: Math.floor(Math.random() * 4),
      error_msg: '',
      created_at: randomDate(),
    }))
  ),

  '/api/taskCenter/resendAd': success(null, '重新发送成功'),

  // 任务中心 - 广告编辑
  '/api/taskCenter/adEditList': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      task_id: `task_${randomId()}`,
      task_name: '编辑广告任务',
      status: Math.floor(Math.random() * 4),
      total: Math.floor(Math.random() * 100) + 10,
      success: Math.floor(Math.random() * 50) + 10,
      fail: Math.floor(Math.random() * 10),
      created_at: randomDate(),
    }))
  ),

  '/api/taskCenter/adEditDetails': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      ad_name: `广告${i + 1}`,
      old_value: '旧值',
      new_value: '新值',
      status: Math.floor(Math.random() * 4),
      error_msg: '',
      created_at: randomDate(),
    }))
  ),

  '/api/taskCenter/resendEditTask': success(null, '重新发送成功'),

  // 任务中心 - 广告复制
  '/api/taskCenter/adCopyList': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      task_id: `task_${randomId()}`,
      task_name: '复制广告任务',
      status: Math.floor(Math.random() * 4),
      total: Math.floor(Math.random() * 100) + 10,
      success: Math.floor(Math.random() * 50) + 10,
      created_at: randomDate(),
    }))
  ),

  '/api/taskCenter/adCopyDetails': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      source_ad_name: `源广告${i + 1}`,
      target_ad_name: `目标广告${i + 1}`,
      status: Math.floor(Math.random() * 4),
      error_msg: '',
      created_at: randomDate(),
    }))
  ),

  '/api/taskCenter/resendCopyTask': success(null, '重新发送成功'),

  // 任务中心 - 下载任务
  '/api/taskCenter/downLoadTask': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      task_id: `task_${randomId()}`,
      task_name: '下载任务',
      file_name: `导出数据${i + 1}.xlsx`,
      status: Math.floor(Math.random() * 4),
      file_size: `${Math.floor(Math.random() * 50) + 1}MB`,
      download_url: '#',
      created_at: randomDate(),
    }))
  ),

  '/api/taskCenter/reDownLoadTask': success(null, '重新下载成功'),

  // 报表统计
  '/api/operation/reportStatistics': success({
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
  }),

  '/api/common/overview': success({
    total: 12580,
    yesterday: 142,
    today: 156,
    week: 980,
    month: 4250,
    growth: 9.86,
  }),

  '/api/v2/planDataOverview': success({
    overview: {
      total: 12580,
      yesterday: 142,
      today: 156,
      growth: 9.86,
    },
    trend: Array.from({ length: 30 }, (_, i) => ({
      date: new Date(Date.now() - (29 - i) * 24 * 60 * 60 * 1000)
        .toISOString()
        .slice(0, 10),
      value: Math.floor(Math.random() * 10000) + 1000,
    })),
  }),

  // 系统设置
  '/api/systemSettingInfo': success({
    system_name: '电商管理系统',
    system_logo: 'https://via.placeholder.com/150',
    copyright: '© 2024 公司名称',
    icp_number: 'ICP证123456号',
    version: '1.0.8',
  }),

  '/api/systemSetting': success(null, '保存成功'),

  // 媒体账户
  '/api/mediaAccountList': success(
    Array.from({ length: 10 }, (_, i) => ({
      id: i + 1,
      account_id: `acc_${randomId()}`,
      account_name: `账户${i + 1}`,
      media_type: (i % 5) + 1,
      status: 1,
    }))
  ),

  // 水印设置
  '/api/getWatermark': success({
    open: true,
    text: '内部资料',
    position: 'center',
    opacity: 0.3,
  }),

  '/api/setWatermark': success(null, '设置成功'),
  '/api/setWatermarkOpen': success(null, '设置成功'),

  // 内容数据
  '/api/content-data': success(
    Array.from({ length: 12 }, (_, i) => ({
      month: `${i + 1}月`,
      value: Math.floor(Math.random() * 10000) + 1000,
    }))
  ),

  '/api/popular/list': success(
    Array.from({ length: 10 }, (_, i) => ({
      key: i + 1,
      title: `热门内容${i + 1}`,
      clickNumber: Math.floor(Math.random() * 100000) + 10000,
      increases: Math.floor(Math.random() * 100),
    }))
  ),

  // 消息列表
  '/api/message/list': success([
    {
      id: 1,
      type: 'message',
      title: '您有新订单',
      subTitle: '订单通知',
      content: '订单号：202401150001 已创建',
      time: randomDate(),
      status: 0,
      messageType: 1,
    },
    {
      id: 2,
      type: 'message',
      title: '支付成功',
      subTitle: '支付通知',
      content: '订单号：202401150002 已支付成功',
      time: randomDate(),
      status: 0,
      messageType: 2,
    },
    {
      id: 3,
      type: 'notice',
      title: '系统更新',
      subTitle: '系统公告',
      content: '系统将于今晚22:00进行维护',
      time: randomDate(),
      status: 1,
      messageType: 3,
    },
    {
      id: 4,
      type: 'notice',
      title: '新功能上线',
      subTitle: '功能公告',
      content: '订单导出功能已上线',
      time: randomDate(),
      status: 1,
      messageType: 4,
    },
    {
      id: 5,
      type: 'todo',
      title: '待审核：出库申请',
      subTitle: '待办事项',
      content: '申请人：张三，申请商品：LV手提包',
      time: randomDate(),
      status: 0,
      messageType: 5,
    },
    {
      id: 6,
      type: 'todo',
      title: '待审核：入库申请',
      subTitle: '待办事项',
      content: '申请人：李四，申请商品：Gucci背包',
      time: randomDate(),
      status: 0,
      messageType: 5,
    },
    {
      id: 7,
      type: 'todo',
      title: '待审核：退货申请',
      subTitle: '待办事项',
      content: '申请人：王五，申请退货：Prada钱包',
      time: randomDate(),
      status: 0,
      messageType: 5,
    },
    {
      id: 8,
      type: 'todo',
      title: '待审批：调拨申请',
      subTitle: '待办事项',
      content: '申请人：赵六，申请调拨：Hermès围巾',
      time: randomDate(),
      status: 1,
      messageType: 5,
    },
    {
      id: 9,
      type: 'message',
      title: '订单发货',
      subTitle: '物流通知',
      content: '订单号：202401150003 已发货',
      time: randomDate(),
      status: 1,
      messageType: 1,
    },
    {
      id: 10,
      type: 'message',
      title: '订单完成',
      subTitle: '完成通知',
      content: '订单号：202401150004 已完成',
      time: randomDate(),
      status: 1,
      messageType: 1,
    },
  ]),

  '/api/message/read': success(null, '设置已读成功'),
  '/api/chat/list': success(
    Array.from({ length: 10 }, (_, i) => ({
      id: i + 1,
      username: randomName(),
      content: '聊天内容',
      time: randomDate(),
      isCollect: Math.random() > 0.5,
    }))
  ),

  // 产品详情选项
  '/api/product/detail/option/list': success(
    Array.from({ length: 10 }, (_, i) => ({
      id: i + 1,
      option_name: `选项${i + 1}`,
      option_value: `value_${i + 1}`,
      sort: i + 1,
      status: 1,
    }))
  ),

  '/api/product/detail/option/save': success({ id: randomId() }, '保存成功'),
  '/api/product/detail/option/delete': success(null, '删除成功'),

  // 密码重置
  '/api/system/admin/resetPassword': success(null, '密码重置成功'),

  // ========== 业务管理模块 ==========

  // 会员管理
  '/api/business/member/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      user_id: 1000 + i,
      username: randomName(),
      nickname: `昵称${i + 1}`,
      mobile: randomPhone(),
      email: `user${i + 1}@example.com`,
      avatar:
        'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png',
      gender: Math.floor(Math.random() * 3),
      level: Math.floor(Math.random() * 5) + 1,
      level_name: ['普通会员', '铜牌会员', '银牌会员', '金牌会员', '钻石会员'][
        Math.floor(Math.random() * 5)
      ],
      balance: Math.floor(Math.random() * 10000),
      total_consume: Math.floor(Math.random() * 50000),
      total_order: Math.floor(Math.random() * 100),
      points: Math.floor(Math.random() * 10000),
      status: Math.floor(Math.random() * 2),
      source: ['PC', 'H5', 'APP', '小程序'][Math.floor(Math.random() * 4)],
      last_login: randomDate(),
      created_at: randomDate(),
    }))
  ),
  '/api/business/member/save': success({ id: randomId() }, '保存成功'),
  '/api/business/member/delete': success(null, '删除成功'),
  '/api/business/member/set': success(null, '设置成功'),

  // 订单管理
  '/api/business/order/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      order_no: `ORD${new Date().getTime()}${i}`,
      product_name: `商品${i + 1}`,
      product_image: 'https://via.placeholder.com/150',
      sku_info: `规格: ${['红色/M', '蓝色/L', '黑色/XL', '白色/S'][i % 4]}`,
      num: Math.floor(Math.random() * 10) + 1,
      price: Math.floor(Math.random() * 1000) + 100,
      total_price: Math.floor(Math.random() * 10000) + 1000,
      discount_price: Math.floor(Math.random() * 500),
      actual_price: Math.floor(Math.random() * 8000) + 500,
      user_name: randomName(),
      user_phone: randomPhone(),
      user_address: [
        '广东省深圳市南山区',
        '北京市朝阳区',
        '上海市浦东新区',
        '杭州市西湖区',
      ][i % 4],
      pay_type: Math.floor(Math.random() * 4) + 1,
      pay_time: randomDate(),
      status: Math.floor(Math.random() * 6) + 1,
      remark: '',
      created_at: randomDate(),
    }))
  ),
  '/api/business/order/detail': success({
    id: 1,
    order_no: 'ORD2024010100001',
    product_name: '测试商品',
    sku_info: '红色/M',
    num: 2,
    price: 199.0,
    total_price: 398.0,
    discount_price: 0,
    actual_price: 398.0,
    user_name: '张三',
    user_phone: '13800138000',
    user_address: '广东省深圳市南山区',
    pay_type: 1,
    pay_time: '2024-01-01 10:00:00',
    status: 2,
    remark: '',
    created_at: '2024-01-01 09:30:00',
  }),
  '/api/business/order/save': success({ id: randomId() }, '保存成功'),
  '/api/business/order/delete': success(null, '删除成功'),
  '/api/business/order/set': success(null, '设置成功'),

  // 工具箱 - 功能模块
  '/api/business/toolbox/module/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      module_name: [
        '智能客服',
        '营销工具',
        '数据分析',
        '订单管理',
        '会员管理',
        '报表导出',
        'API接口',
        '短信通知',
      ][i % 8],
      module_code: `module_${i + 1}`,
      module_icon: 'icon-tool',
      description: `功能模块${i + 1}的描述说明`,
      category: Math.floor(Math.random() * 4) + 1,
      category_name: ['核心功能', '增值服务', '数据分析', '集成服务'][
        Math.floor(Math.random() * 4)
      ],
      is_package: Math.floor(Math.random() * 2),
      package_price: Math.floor(Math.random() * 1000) + 100,
      single_price: Math.floor(Math.random() * 500) + 50,
      price_config: {
        month_price: Math.floor(Math.random() * 100) + 10,
        quarter_price: Math.floor(Math.random() * 300) + 30,
        year_price: Math.floor(Math.random() * 1000) + 100,
        lifetime_price: Math.floor(Math.random() * 5000) + 500,
      },
      usage_count: Math.floor(Math.random() * 10000),
      status: 1,
      created_at: randomDate(),
    }))
  ),
  '/api/business/toolbox/module/save': success({ id: randomId() }, '保存成功'),
  '/api/business/toolbox/module/delete': success(null, '删除成功'),
  '/api/business/toolbox/package/list': pageSuccess(
    Array.from({ length: 10 }, (_, i) => ({
      id: i + 1,
      package_name: ['基础版', '标准版', '高级版', '旗舰版', '定制版'][i % 5],
      package_code: `package_${i + 1}`,
      description: `套餐${i + 1}的描述说明`,
      modules: [1, 2, 3, 4, 5].slice(0, Math.floor(Math.random() * 5) + 1),
      price: Math.floor(Math.random() * 5000) + 500,
      discount: Math.floor(Math.random() * 30),
      status: 1,
      created_at: randomDate(),
    }))
  ),
  '/api/business/toolbox/package/save': success({ id: randomId() }, '保存成功'),

  // 优惠活动
  '/api/business/promotion/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      activity_name: [
        '满减活动',
        '折扣活动',
        '秒杀活动',
        '拼团活动',
        '抽奖活动',
        '积分兑换',
      ][i % 6],
      activity_type: (i % 6) + 1,
      activity_code: `ACT${new Date().getTime()}${i}`,
      description: '活动描述说明',
      start_time: new Date(
        Date.now() - Math.random() * 15 * 24 * 60 * 60 * 1000
      )
        .toISOString()
        .slice(0, 19)
        .replace('T', ' '),
      end_time: new Date(Date.now() + Math.random() * 15 * 24 * 60 * 60 * 1000)
        .toISOString()
        .slice(0, 19)
        .replace('T', ' '),
      target_users: '全部用户',
      coupon_count: Math.floor(Math.random() * 1000),
      used_count: Math.floor(Math.random() * 500),
      order_count: Math.floor(Math.random() * 200),
      sales_amount: Math.floor(Math.random() * 100000),
      status: Math.floor(Math.random() * 3),
      created_at: randomDate(),
    }))
  ),
  '/api/business/promotion/save': success({ id: randomId() }, '保存成功'),
  '/api/business/promotion/delete': success(null, '删除成功'),
  '/api/business/promotion/set': success(null, '设置成功'),

  // 机器管理
  '/api/business/machine/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      machine_code: `MCH${String(i + 1).padStart(8, '0')}`,
      machine_name: `机器${i + 1}`,
      machine_type: Math.floor(Math.random() * 3) + 1,
      machine_type_name: ['PC端', '手机端', '平板端'][
        Math.floor(Math.random() * 3)
      ],
      device_id: `device_${Math.floor(Math.random() * 100000)}`,
      bind_user: randomName(),
      bind_order: i % 3 === 0 ? `ORD${new Date().getTime()}${i}` : null,
      expire_time: new Date(
        Date.now() + Math.random() * 30 * 24 * 60 * 60 * 1000
      )
        .toISOString()
        .slice(0, 19)
        .replace('T', ' '),
      is_trial: i % 3 === 0 ? 0 : 1,
      trial_days: i % 3 === 0 ? 0 : Math.floor(Math.random() * 30),
      status: Math.floor(Math.random() * 3),
      last_login: randomDate(),
      created_at: randomDate(),
    }))
  ),
  '/api/business/machine/save': success({ id: randomId() }, '保存成功'),
  '/api/business/machine/delete': success(null, '删除成功'),
  '/api/business/machine/bind': success(null, '绑定成功'),
  '/api/business/machine/unbind': success(null, '解绑成功'),
  '/api/business/machine/renew': success(null, '续期成功'),

  // 收入管理
  '/api/business/income/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      order_no: `ORD${new Date().getTime()}${i}`,
      user_name: randomName(),
      user_phone: randomPhone(),
      income_type: Math.floor(Math.random() * 4) + 1,
      income_type_name: ['商品销售', '套餐销售', '续费收入', '其他收入'][
        Math.floor(Math.random() * 4)
      ],
      amount: Math.floor(Math.random() * 10000) + 100,
      cost_amount: Math.floor(Math.random() * 5000),
      profit_amount: Math.floor(Math.random() * 5000),
      status: Math.floor(Math.random() * 3) + 1,
      settle_status: Math.floor(Math.random() * 2),
      settle_time: randomDate(),
      created_at: randomDate(),
    }))
  ),
  '/api/business/income/statistics': success({
    total_income: 2580000,
    month_income: 256000,
    today_income: 12580,
    pending_settle: 35000,
    total_profit: 1280000,
  }),
  '/api/business/income/withdraw/list': pageSuccess(
    Array.from({ length: 10 }, (_, i) => ({
      id: i + 1,
      withdraw_no: `WD${new Date().getTime()}${i}`,
      user_name: randomName(),
      amount: Math.floor(Math.random() * 10000) + 100,
      fee: Math.floor(Math.random() * 100),
      actual_amount: Math.floor(Math.random() * 9900) + 100,
      bank_name: ['中国银行', '工商银行', '建设银行', '农业银行'][i % 4],
      bank_account: `****${Math.floor(Math.random() * 10000)}`,
      status: Math.floor(Math.random() * 4),
      created_at: randomDate(),
    }))
  ),

  // ========== 系统设置模块 ==========

  // 菜单管理
  '/api/system/menu/tree': success([
    {
      id: 1,
      title: '系统管理',
      icon: 'icon-settings',
      children: [
        { id: 11, title: '成员管理', icon: 'icon-user-group' },
        { id: 12, title: '角色管理', icon: 'icon-skin' },
        { id: 13, title: '供应商管理', icon: 'icon-archive' },
        { id: 14, title: '菜单管理', icon: 'icon-menu' },
        { id: 15, title: '管理员管理', icon: 'icon-user' },
        { id: 16, title: '操作记录', icon: 'icon-code-block' },
      ],
    },
    {
      id: 2,
      title: '业务管理',
      icon: 'icon-apps',
      children: [
        { id: 21, title: '数据概览', icon: 'icon-dashboard' },
        { id: 22, title: '会员管理', icon: 'icon-user' },
        { id: 23, title: '订单管理', icon: 'icon-file' },
        { id: 24, title: '机器管理', icon: 'icon-desktop' },
        { id: 25, title: '收入管理', icon: 'icon-money-circle' },
        { id: 26, title: '工具箱', icon: 'icon-tool' },
        { id: 27, title: '优惠活动', icon: 'icon-gift' },
      ],
    },
    {
      id: 3,
      title: '运营管理',
      icon: 'icon-command',
      children: [
        { id: 31, title: '插件管理', icon: 'icon-apps' },
        { id: 32, title: '定时任务', icon: 'icon-clock-circle' },
      ],
    },
    {
      id: 4,
      title: '安全中心',
      icon: 'icon-safe',
      children: [{ id: 41, title: '黑名单管理', icon: 'icon-lock' }],
    },
    {
      id: 5,
      title: '报表中心',
      icon: 'icon-bar-chart',
      children: [{ id: 51, title: '数据统计', icon: 'icon-line-chart' }],
    },
  ]),
  '/api/system/menu/list': success({
    list: [
      {
        id: 1,
        pid: 0,
        menu_name: '业务管理',
        icon: 'icon-apps',
        menu_type: 1,
        path: '/business',
        component: '',
        sort: 1,
        is_hide: 0,
        is_cache: 0,
        status: 1,
        created_at: randomDate(),
        children: [
          {
            id: 11,
            pid: 1,
            menu_name: '数据概览',
            icon: 'icon-dashboard',
            menu_type: 2,
            path: '/business/overview',
            component: '@/views/business/overview/overview.vue',
            sort: 1,
            is_hide: 0,
            is_cache: 0,
            status: 1,
            children: [],
          },
          {
            id: 12,
            pid: 1,
            menu_name: '会员管理',
            icon: 'icon-user',
            menu_type: 2,
            path: '/business/member',
            component: '@/views/business/member/member.vue',
            sort: 2,
            is_hide: 0,
            is_cache: 0,
            status: 1,
            children: [],
          },
          {
            id: 13,
            pid: 1,
            menu_name: '订单管理',
            icon: 'icon-shopping-cart',
            menu_type: 2,
            path: '/business/order',
            component: '@/views/business/order/order.vue',
            sort: 3,
            is_hide: 0,
            is_cache: 0,
            status: 1,
            children: [],
          },
          {
            id: 14,
            pid: 1,
            menu_name: '工具箱',
            icon: 'icon-tool',
            menu_type: 2,
            path: '/business/toolbox',
            component: '@/views/business/toolbox/toolbox.vue',
            sort: 4,
            is_hide: 0,
            is_cache: 0,
            status: 1,
            children: [],
          },
          {
            id: 15,
            pid: 1,
            menu_name: '优惠活动',
            icon: 'icon-star',
            menu_type: 2,
            path: '/business/promotion',
            component: '@/views/business/promotion/promotion.vue',
            sort: 5,
            is_hide: 0,
            is_cache: 0,
            status: 1,
            children: [],
          },
          {
            id: 16,
            pid: 1,
            menu_name: '机器管理',
            icon: 'icon-mobile',
            menu_type: 2,
            path: '/business/machine',
            component: '@/views/business/machine/machine.vue',
            sort: 6,
            is_hide: 0,
            is_cache: 0,
            status: 1,
            children: [],
          },
          {
            id: 17,
            pid: 1,
            menu_name: '收入管理',
            icon: 'icon-money',
            menu_type: 2,
            path: '/business/income',
            component: '@/views/business/income/income.vue',
            sort: 7,
            is_hide: 0,
            is_cache: 0,
            status: 1,
            children: [],
          },
        ],
      },
      {
        id: 2,
        pid: 0,
        menu_name: '系统管理',
        icon: 'icon-settings',
        menu_type: 1,
        path: '/system',
        component: '',
        sort: 2,
        is_hide: 0,
        is_cache: 0,
        status: 1,
        created_at: randomDate(),
        children: [
          {
            id: 21,
            pid: 2,
            menu_name: '菜单管理',
            icon: 'icon-menu',
            menu_type: 2,
            path: '/system/menu',
            component: '@/views/system-manage/menu/menu.vue',
            sort: 1,
            is_hide: 0,
            is_cache: 0,
            status: 1,
            children: [],
          },
          {
            id: 22,
            pid: 2,
            menu_name: '配置管理',
            icon: 'icon-settings',
            menu_type: 2,
            path: '/system/config',
            component: '@/views/system-manage/config/config.vue',
            sort: 2,
            is_hide: 0,
            is_cache: 0,
            status: 1,
            children: [],
          },
          {
            id: 23,
            pid: 2,
            menu_name: '支付配置',
            icon: 'icon-pay',
            menu_type: 2,
            path: '/system/payment',
            component: '@/views/system-manage/payment/payment.vue',
            sort: 3,
            is_hide: 0,
            is_cache: 0,
            status: 1,
            children: [],
          },
          {
            id: 24,
            pid: 2,
            menu_name: '版本管理',
            icon: 'icon-history',
            menu_type: 2,
            path: '/system/version',
            component: '@/views/system-manage/version/version.vue',
            sort: 4,
            is_hide: 0,
            is_cache: 0,
            status: 1,
            children: [],
          },
          {
            id: 25,
            pid: 2,
            menu_name: '管理员',
            icon: 'icon-user',
            menu_type: 2,
            path: '/system/admin',
            component: '@/views/system-manage/admin/admin.vue',
            sort: 5,
            is_hide: 0,
            is_cache: 0,
            status: 1,
            children: [],
          },
        ],
      },
      {
        id: 3,
        pid: 0,
        menu_name: '运营管理',
        icon: 'icon-operation',
        menu_type: 1,
        path: '/operation',
        component: '',
        sort: 3,
        is_hide: 0,
        is_cache: 0,
        status: 1,
        created_at: randomDate(),
        children: [
          {
            id: 31,
            pid: 3,
            menu_name: '任务管理',
            icon: 'icon-clock',
            menu_type: 2,
            path: '/operation/task',
            component: '@/views/operation/task/task.vue',
            sort: 1,
            is_hide: 0,
            is_cache: 0,
            status: 1,
            children: [],
          },
          {
            id: 32,
            pid: 3,
            menu_name: '插件管理',
            icon: 'icon-apps',
            menu_type: 2,
            path: '/operation/plugin',
            component: '@/views/operation/plugin/plugin.vue',
            sort: 2,
            is_hide: 0,
            is_cache: 0,
            status: 1,
            children: [],
          },
        ],
      },
      {
        id: 4,
        pid: 0,
        menu_name: '报表统计',
        icon: 'icon-chart',
        menu_type: 1,
        path: '/report',
        component: '',
        sort: 4,
        is_hide: 0,
        is_cache: 0,
        status: 1,
        created_at: randomDate(),
        children: [
          {
            id: 41,
            pid: 4,
            menu_name: '报表统计',
            icon: 'icon-bar-chart',
            menu_type: 2,
            path: '/report/statistics',
            component: '@/views/report/statistics/statistics.vue',
            sort: 1,
            is_hide: 0,
            is_cache: 0,
            status: 1,
            children: [],
          },
        ],
      },
      {
        id: 5,
        pid: 0,
        menu_name: '安全运维',
        icon: 'icon-safe',
        menu_type: 1,
        path: '/security',
        component: '',
        sort: 5,
        is_hide: 0,
        is_cache: 0,
        status: 1,
        created_at: randomDate(),
        children: [
          {
            id: 51,
            pid: 5,
            menu_name: '日志管理',
            icon: 'icon-file',
            menu_type: 2,
            path: '/security/log',
            component: '@/views/security/log/log.vue',
            sort: 1,
            is_hide: 0,
            is_cache: 0,
            status: 1,
            children: [],
          },
          {
            id: 52,
            pid: 5,
            menu_name: '黑名单',
            icon: 'icon-close-circle',
            menu_type: 2,
            path: '/security/blacklist',
            component: '@/views/security/blacklist/blacklist.vue',
            sort: 2,
            is_hide: 0,
            is_cache: 0,
            status: 1,
            children: [],
          },
        ],
      },
    ],
    pagination: { page: 1, pageSize: 10, total: 5 },
  }),
  '/api/system/menu/save': success({ id: randomId() }, '保存成功'),
  '/api/system/menu/delete': success(null, '删除成功'),
  '/api/system/menu/set': success(null, '设置成功'),

  // 配置管理
  '/api/system/config/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      config_name: [
        '系统名称',
        '系统Logo',
        '版权信息',
        'ICP备案号',
        '客服电话',
        '客服邮箱',
        '用户协议',
        '隐私政策',
        '短信签名',
        '邮件配置',
      ][i % 10],
      config_key: `config_${i + 1}`,
      config_type: (i % 4) + 1,
      config_value: i < 5 ? 'test_value' : '',
      description: '配置说明',
      sort: i + 1,
      is_hide: i % 3 === 0 ? 1 : 0,
      status: 1,
      created_at: randomDate(),
    }))
  ),
  '/api/system/config/save': success({ id: randomId() }, '保存成功'),
  '/api/system/config/delete': success(null, '删除成功'),
  '/api/system/config/set': success(null, '设置成功'),

  // 支付配置
  '/api/system/payment/list': pageSuccess(
    Array.from({ length: 10 }, (_, i) => ({
      id: i + 1,
      pay_type: i + 1,
      channel_name: [
        '微信支付',
        '支付宝',
        '银行卡',
        '余额支付',
        'Apple Pay',
        '银联支付',
        'PayPal',
        '京东支付',
        'Google Pay',
        '抖音支付',
      ][i],
      mch_id: `mch_${randomId()}`,
      app_id: `app_${randomId()}`,
      fee_rate: [0.6, 0.6, 0.3, 0, 0.15, 0.35, 3.5, 0.5, 0.15, 0.6][i],
      sort: i + 1,
      status: i < 6 ? 1 : 0,
      created_at: randomDate(),
    }))
  ),
  '/api/system/payment/save': success({ id: randomId() }, '保存成功'),
  '/api/system/payment/delete': success(null, '删除成功'),
  '/api/system/payment/set': success(null, '设置成功'),

  // 版本管理
  '/api/system/version/list': pageSuccess(
    Array.from({ length: 15 }, (_, i) => ({
      id: i + 1,
      version: `1.${i}.${Math.floor(Math.random() * 10)}`,
      version_type: (() => {
        if (i === 0) return 1;
        if (i < 5) return 2;
        return 3;
      })(),
      force_update: i === 0 ? 1 : 0,
      min_version: i > 0 ? `1.${i - 1}.0` : '',
      title: `版本更新${i + 1}`,
      content: '1. 新增功能\n2. 优化体验\n3. 修复问题',
      download_url: 'https://example.com/download',
      file_size: `${Math.floor(Math.random() * 100) + 10}MB`,
      md5: Math.random().toString(36).substring(2),
      status: i === 0 ? 1 : 0,
      release_time: randomDate(),
      created_at: randomDate(),
    }))
  ),
  '/api/system/version/save': success({ id: randomId() }, '保存成功'),
  '/api/system/version/delete': success(null, '删除成功'),
  '/api/system/version/set': success(null, '设置成功'),

  // 管理员
  '/api/system/admin/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      username:
        ['admin', 'manager', 'operator', 'finance', 'viewer'][i % 5] + (i + 1),
      nickname: ['系统管理员', '运营经理', '财务专员', '客服主管', '市场专员'][
        i % 5
      ],
      mobile: randomPhone(),
      email: `admin${i + 1}@example.com`,
      avatar:
        'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png',
      gender: Math.floor(Math.random() * 3),
      role_id: (i % 5) + 1,
      role_name: [
        '超级管理员',
        '运营管理员',
        '财务管理员',
        '客服管理员',
        '只读用户',
      ][i % 5],
      last_login: randomDate(),
      status: 1,
      created_at: randomDate(),
    }))
  ),
  '/api/system/admin/save': success({ id: randomId() }, '保存成功'),
  '/api/system/admin/delete': success(null, '删除成功'),
  '/api/system/admin/set': success(null, '设置成功'),

  // ========== 报表统计模块 ==========

  // 报表统计
  '/api/report/statistics': success({
    total_order: 12580,
    total_amount: 2580000,
    total_user: 8560,
    today_order: 156,
    today_amount: 28000,
    yesterday_order: 142,
    yesterday_amount: 25000,
    active_user: 3250,
    growth: 9.86,
  }),
  '/api/report/order/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      order_no: `ORD${new Date().getTime()}${i}`,
      product_name: `商品${i + 1}`,
      price: Math.floor(Math.random() * 1000) + 100,
      num: Math.floor(Math.random() * 10) + 1,
      total_price: Math.floor(Math.random() * 10000) + 1000,
      user_name: randomName(),
      user_phone: randomPhone(),
      created_at: randomDate(),
      status: Math.floor(Math.random() * 5) + 1,
    }))
  ),
  '/api/report/product/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      product_name: `商品${i + 1}`,
      sales_count: Math.floor(Math.random() * 1000),
      sales_amount: Math.floor(Math.random() * 100000),
      return_count: Math.floor(Math.random() * 50),
      created_at: randomDate(),
    }))
  ),
  '/api/report/region/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      region_name: [
        '广东',
        '北京',
        '上海',
        '浙江',
        '江苏',
        '四川',
        '湖北',
        '湖南',
        '福建',
        '山东',
        '河南',
        '河北',
        '辽宁',
        '陕西',
        '安徽',
      ][i % 15],
      order_count: Math.floor(Math.random() * 1000),
      order_amount: Math.floor(Math.random() * 100000),
      user_count: Math.floor(Math.random() * 500),
    }))
  ),
  '/api/report/module/list': pageSuccess(
    Array.from({ length: 10 }, (_, i) => ({
      id: i + 1,
      module_name: [
        '智能客服',
        '营销工具',
        '数据分析',
        '订单管理',
        '会员管理',
        '报表导出',
        'API接口',
        '短信通知',
        '邮件推送',
        'CRM客户管理',
      ][i],
      usage_count: Math.floor(Math.random() * 10000),
      usage_amount: Math.floor(Math.random() * 100000),
      active_users: Math.floor(Math.random() * 1000),
    }))
  ),

  // ========== 运营管理模块 ==========

  // 任务管理
  '/api/operation/task/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      task_name: [
        '数据同步任务',
        '订单处理任务',
        '消息推送任务',
        '数据统计任务',
        '清理缓存任务',
        '备份数据库任务',
        '发送邮件任务',
        '报表生成任务',
      ][i % 8],
      task_type: (i % 4) + 1,
      group_name: ['default', 'order', 'data', 'system'][i % 4],
      target: `app\\job\\TestJob${i + 1}`,
      params: JSON.stringify({ id: i + 1 }),
      cron: i % 4 === 0 ? '0 * * * *' : '',
      timeout: Math.floor(Math.random() * 600) + 60,
      delay: i % 4 === 1 ? Math.floor(Math.random() * 3600) : 0,
      retry: Math.floor(Math.random() * 3),
      status: Math.floor(Math.random() * 2),
      last_run_time: randomDate(),
      created_at: randomDate(),
    }))
  ),
  '/api/operation/task/save': success({ id: randomId() }, '保存成功'),
  '/api/operation/task/delete': success(null, '删除成功'),
  '/api/operation/task/set': success(null, '设置成功'),
  '/api/operation/task/run': success(null, '任务已触发'),

  // 插件管理
  '/api/operation/plugin/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      name: [
        '微信登录',
        '支付宝支付',
        '短信验证码',
        '邮件推送',
        '数据分析',
        '营销弹窗',
        '客服聊天',
        'SEO优化',
        'API集成',
        '数据导出',
        '批量处理',
        '自动化运维',
      ][i % 12],
      identifier: `plugin_${i + 1}`,
      version: `${Math.floor(Math.random() * 3) + 1}.${Math.floor(
        Math.random() * 10
      )}.${Math.floor(Math.random() * 10)}`,
      logo: 'https://via.placeholder.com/150',
      plugin_type: (i % 5) + 1,
      author: ['官方', '第三方', '社区'][i % 3],
      price: [0, 0, 99, 199, 299, 0][i % 6],
      downloads: Math.floor(Math.random() * 10000),
      rating: Math.floor(Math.random() * 2) + 4,
      description: `插件${i + 1}的描述说明`,
      features: '功能1\n功能2\n功能3',
      status: Math.floor(Math.random() * 2),
      install_time: randomDate(),
      created_at: randomDate(),
    }))
  ),
  '/api/operation/plugin/install': success(null, '安装成功'),
  '/api/operation/plugin/uninstall': success(null, '卸载成功'),
  '/api/operation/plugin/saveConfig': success(null, '配置保存成功'),

  // ========== 安全运维模块 ==========

  // 日志管理
  '/api/security/log/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      username: randomName(),
      module: ['用户管理', '订单管理', '商品管理', '系统设置', '财务管理'][
        i % 5
      ],
      log_type: ['login', 'create', 'update', 'delete', 'query', 'export'][
        i % 6
      ],
      description: '操作描述',
      method: ['GET', 'POST', 'PUT', 'DELETE'][i % 4],
      url: '/api/test',
      params: JSON.stringify({ id: i + 1 }),
      response: '{"code": 200, "msg": "success"}',
      ip: `192.168.1.${Math.floor(Math.random() * 255)}`,
      location: '广东省深圳市',
      user_agent: 'Mozilla/5.0',
      execution_time: Math.floor(Math.random() * 1000),
      status: Math.floor(Math.random() * 2),
      created_at: randomDate(),
    }))
  ),

  // 黑名单
  '/api/security/blacklist/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      user_id: 1000 + i,
      username: randomName(),
      avatar:
        'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png',
      block_type: (i % 4) + 1,
      reason: ['违规操作', '恶意退款', '刷单行为', '发布违规内容'][i % 4],
      ip: `192.168.1.${Math.floor(Math.random() * 255)}`,
      device_id: `device_${Math.floor(Math.random() * 100000)}`,
      start_time: randomDate(),
      end_time: new Date(Date.now() + Math.random() * 30 * 24 * 60 * 60 * 1000)
        .toISOString()
        .slice(0, 19)
        .replace('T', ' '),
      evidence: '违规证据',
      remark: '备注信息',
      status: i % 3 === 0 ? 0 : 1,
      operator: 'admin',
      created_at: randomDate(),
    }))
  ),
  '/api/security/blacklist/save': success({ id: randomId() }, '保存成功'),
  '/api/security/blacklist/delete': success(null, '删除成功'),
  '/api/security/blacklist/set': success(null, '设置成功'),
  '/api/security/blacklist/add': success({ id: randomId() }, '添加成功'),

  // ========== 业务模块补充 ==========

  // 数据概览 - 订单列表
  '/api/business/overview/orderList': pageSuccess(
    Array.from({ length: 10 }, (_, i) => ({
      id: i + 1,
      order_no: `ORD${new Date().getTime()}${i}`,
      product_name: `商品${i + 1}`,
      user_name: randomName(),
      total_price: Math.floor(Math.random() * 10000) + 100,
      status: Math.floor(Math.random() * 6) + 1,
      created_at: randomDate(),
    }))
  ),

  // 工具箱 - 功能列表
  '/api/business/toolbox/list': pageSuccess(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      module_name: [
        '智能客服',
        '营销工具',
        '数据分析',
        '订单管理',
        '会员管理',
        '报表导出',
        'API接口',
        '短信通知',
      ][i % 8],
      module_code: `module_${i + 1}`,
      icon: 'icon-tool',
      description: `功能模块${i + 1}的描述说明`,
      category: Math.floor(Math.random() * 4) + 1,
      category_name: ['核心功能', '增值服务', '数据分析', '集成服务'][
        Math.floor(Math.random() * 4)
      ],
      is_package: Math.floor(Math.random() * 2),
      usage_count: Math.floor(Math.random() * 10000),
      status: 1,
      created_at: randomDate(),
    }))
  ),
  '/api/business/toolbox/savePrice': success(null, '价格设置成功'),

  // 机器管理 - 统计
  '/api/business/machine/stats': success({
    total: Math.floor(Math.random() * 500) + 100,
    active: Math.floor(Math.random() * 300) + 50,
    inactive: Math.floor(Math.random() * 100) + 10,
    trial: Math.floor(Math.random() * 50) + 5,
  }),

  // 订单管理 - 简单列表(用于下拉选择)
  '/api/business/order/simpleList': success(
    Array.from({ length: 20 }, (_, i) => ({
      id: i + 1,
      order_no: `ORD${new Date().getTime()}${i}`,
      product_name: `商品${i + 1}`,
      user_name: randomName(),
      total_price: Math.floor(Math.random() * 10000) + 100,
    }))
  ),

  // 收入管理 - 提现
  '/api/business/income/withdraw': success(
    { id: randomId() },
    '提现申请已提交'
  ),

  // 会员管理 - 批量操作
  '/api/business/member/batchEnable': success(null, '批量启用成功'),
  '/api/business/member/batchDisable': success(null, '批量禁用成功'),
  '/api/business/member/batchDelete': success(null, '批量删除成功'),
  '/api/business/member/pointRecharge': success(null, '积分充值成功'),
  '/api/business/member/balanceRecharge': success(null, '余额充值成功'),
  '/api/business/member/export': success(
    { url: '/downloads/member_export.xlsx' },
    '导出成功'
  ),
  '/api/business/member/tag/add': success({ id: randomId() }, '标签添加成功'),

  // 订单管理
  '/api/business/order/export': success(
    { url: '/downloads/order_export.xlsx' },
    '导出成功'
  ),
  '/api/business/order/exportOne': success(
    { url: '/downloads/order_detail.xlsx' },
    '导出成功'
  ),
  '/api/business/order/process': success(null, '订单处理成功'),
  '/api/business/order/refund': success(null, '退款成功'),
  '/api/business/order/remark': success(null, '备注保存成功'),

  // 收入管理
  '/api/business/income/export': success(
    { url: '/downloads/income_export.xlsx' },
    '导出成功'
  ),

  // 机器管理
  '/api/business/machine/export': success(
    { url: '/downloads/machine_export.xlsx' },
    '导出成功'
  ),

  // 菜单管理
  '/api/system/menu/export': success(
    { url: '/downloads/menu_export.json' },
    '导出成功'
  ),

  // 配置管理
  '/api/system/config/export': success(
    { url: '/downloads/config_export.json' },
    '导出成功'
  ),
  '/api/system/config/import': success({ count: 15 }, '导入成功'),

  // 支付配置
  '/api/system/payment/test': success(
    { success: true, message: '连接正常' },
    '测试成功'
  ),

  // 管理员
  '/api/system/admin/resetPassword': success(null, '密码重置成功'),

  // 报表统计
  '/api/report/statistics/export': success(
    { url: '/downloads/statistics_export.xlsx' },
    '导出成功'
  ),

  // 日志管理
  '/api/security/log/export': success(
    { url: '/downloads/log_export.xlsx' },
    '导出成功'
  ),
  '/api/security/log/clear': success(null, '日志清空成功'),
  '/api/security/log/archive': success(null, '日志归档成功'),

  // 黑名单
  '/api/security/blacklist/export': success(
    { url: '/downloads/blacklist_export.xlsx' },
    '导出成功'
  ),
  '/api/security/blacklist/import': success({ count: 50 }, '导入成功'),

  // ========== 激活码管理 ==========
  '/api/activation/list': pageSuccess(
    Array.from({ length: 10 }, (_, i) => ({
      id: i + 1,
      code: `ACT-${Math.random()
        .toString(36)
        .substring(2, 8)
        .toUpperCase()}-${Math.random()
          .toString(36)
          .substring(2, 8)
          .toUpperCase()}`,
      bind_type: (i % 3) + 1,
      bind_id: i + 1,
      product_id: (i % 5) + 1,
      product_name: [
        '高级版功能',
        '专业版功能',
        '企业版功能',
        'API接口权限',
        '数据导出功能',
      ][i % 5],
      used_count: i % 3,
      max_count: 3,
      status: i % 4,
      expire_time:
        i % 2 === 0
          ? '永久有效'
          : `2024-${String(12 - i).padStart(2, '0')}-31 23:59:59`,
      created_at: randomDate(),
      remark: i % 2 === 0 ? '备注信息' : '',
    }))
  ),
  '/api/activation/generate': success(
    Array.from({ length: 5 }, (_, i) => ({
      id: i + 100,
      code: `ACT-${Math.random()
        .toString(36)
        .substring(2, 8)
        .toUpperCase()}-${Math.random()
          .toString(36)
          .substring(2, 8)
          .toUpperCase()}`,
    })),
    '激活码生成成功'
  ),
  '/api/activation/disable': success(null, '激活码已禁用'),
  '/api/activation/enable': success(null, '激活码已启用'),
  '/api/activation/delete': success(null, '激活码已删除'),
  '/api/activation/verify': success(
    {
      valid: true,
      product_name: '高级版功能',
      expire_time: '永久有效',
      remaining_count: 3,
    },
    '激活码验证成功'
  ),

  // ========== 反馈系统 ==========
  '/api/feedback/list': (req: any) => {
    const url = new URL(req.url, 'http://localhost');
    const page = Number(url.searchParams.get('page')) || 1;
    const pageSize = Number(url.searchParams.get('pageSize')) || 20;
    const keyword = url.searchParams.get('keyword') || '';
    const status = url.searchParams.get('status');
    const priority = url.searchParams.get('priority');
    const type = url.searchParams.get('type');

    // 生成反馈数据
    const feedbackStatuses = [
      { id: 0, name: '待处理', color: '#86909c' },
      { id: 1, name: '处理中', color: '#165dff' },
      { id: 2, name: '已解决', color: '#00b42a' },
      { id: 3, name: '已关闭', color: '#86909c' },
      { id: 4, name: '已拒绝', color: '#f53f3f' },
    ];

    const feedbackPriorities = [
      { id: 0, name: '紧急', color: '#f53f3f' },
      { id: 1, name: '高', color: '#ff7d00' },
      { id: 2, name: '中', color: '#f7ba1e' },
      { id: 3, name: '低', color: '#00b42a' },
    ];

    const feedbackTypes = [
      { id: 0, name: '功能建议' },
      { id: 1, name: 'Bug 反馈' },
      { id: 2, name: '性能问题' },
      { id: 3, name: '用户体验' },
      { id: 4, name: '其他' },
    ];

    const mockUsers = [
      { id: 1, name: '张三', avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png' },
      { id: 2, name: '李四', avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png' },
      { id: 3, name: '王五', avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png' },
      { id: 4, name: '赵六', avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png' },
      { id: 5, name: '钱七', avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png' },
    ];

    const titles = [
      '登录页面加载缓慢', '订单导出功能报错', '建议增加批量操作功能',
      '用户头像上传失败', '报表统计页面显示异常', '希望增加暗黑模式',
      '移动端适配问题', '数据导入功能优化建议', '权限管理功能缺陷',
      '系统通知无法接收', '搜索功能不够精确', '建议增加数据备份功能',
      '页面样式错乱', '导出Excel格式错误', '希望增加多语言支持',
      '密码重置邮件收不到', '商品图片显示问题', '订单状态更新延迟',
      '建议增加操作日志', '库存同步异常', '用户注册验证码问题',
      '支付接口调用失败', '建议增加数据筛选功能', '页面刷新后数据丢失',
      '菜单权限配置不生效', '希望增加快捷键支持', '表格列宽无法调整',
      '文件上传大小限制问题', '建议增加数据可视化', '系统响应速度优化',
    ];

    let list = Array.from({ length: 50 }, (_, i) => {
      const status = feedbackStatuses[Math.floor(Math.random() * feedbackStatuses.length)];
      const priority = feedbackPriorities[Math.floor(Math.random() * feedbackPriorities.length)];
      const type = feedbackTypes[Math.floor(Math.random() * feedbackTypes.length)];
      const creator = mockUsers[Math.floor(Math.random() * mockUsers.length)];
      const handler = Math.random() > 0.3 ? mockUsers[Math.floor(Math.random() * mockUsers.length)] : null;
      const hasTags = Math.random() > 0.5;
      const tags = hasTags ? [
        { id: 1, name: '功能建议', color: '#165dff' },
        { id: 2, name: 'Bug报告', color: '#f53f3f' },
        { id: 3, name: '性能优化', color: '#722ed1' },
      ].slice(0, Math.floor(Math.random() * 3) + 1) : [];

      return {
        id: i + 1,
        title: titles[i % titles.length] || `反馈标题 ${i + 1}`,
        description: '在使用系统时遇到了这个问题，希望能尽快解决。',
        type: type.id,
        status: status.id,
        status_name: status.name,
        status_color: status.color,
        priority: priority.id,
        priority_name: priority.name,
        priority_color: priority.color,
        tags,
        tag_ids: tags.map((t: any) => t.id),
        creator_id: creator.id,
        creator_name: creator.name,
        creator_avatar: creator.avatar,
        handler_id: handler?.id,
        handler_name: handler?.name,
        handler_avatar: handler?.avatar,
        view_count: Math.floor(Math.random() * 1000),
        comment_count: Math.floor(Math.random() * 20),
        attachment_count: Math.floor(Math.random() * 3),
        created_at: randomDate(),
        updated_at: randomDate(),
      };
    });

    // 关键词搜索
    if (keyword) {
      list = list.filter((item) =>
        item.title.toLowerCase().includes(keyword.toLowerCase())
      );
    }

    // 状态筛选
    if (status !== undefined && status !== null && status !== '') {
      list = list.filter((item) => item.status === Number(status));
    }

    // 优先级筛选
    if (priority !== undefined && priority !== null && priority !== '') {
      list = list.filter((item) => item.priority === Number(priority));
    }

    // 类型筛选
    if (type !== undefined && type !== null && type !== '') {
      list = list.filter((item) => item.type === Number(type));
    }

    // 排序
    list.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());

    const start = (page - 1) * pageSize;
    const end = start + pageSize;
    const pageList = list.slice(start, end);

    return {
      code: 200,
      msg: 'success',
      data: {
        list: pageList,
        total: list.length,
      },
    };
  },

  '/api/feedback/detail/1': success({
    id: 1,
    title: '登录页面加载缓慢',
    description: '在使用系统时，登录页面加载时间超过5秒，影响用户体验。',
    type: 1,
    status: 0,
    status_name: '待处理',
    status_color: '#86909c',
    priority: 1,
    priority_name: '高',
    priority_color: '#ff7d00',
    tags: [
      { id: 1, name: '功能建议', color: '#165dff' },
      { id: 2, name: '性能优化', color: '#722ed1' },
    ],
    tag_ids: [1, 2],
    creator_id: 1,
    creator_name: '张三',
    creator_avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png',
    handler_id: 2,
    handler_name: '李四',
    handler_avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png',
    view_count: 156,
    comment_count: 5,
    attachment_count: 2,
    attachments: [],
    created_at: '2024-01-15 10:30:00',
    updated_at: '2024-01-15 14:20:00',
  }),

  '/api/feedback/create': success({ id: 51 }, '创建成功'),
  '/api/feedback/update/1': success(null, '更新成功'),
  '/api/feedback/delete/1': success(null, '删除成功'),
  '/api/feedback/export': success({ url: '/downloads/feedback_export.xlsx' }, '导出成功'),
  '/api/feedback/batch/delete': success({ deleted_count: 2 }, '批量删除成功'),

  // 反馈状态列表
  '/api/feedback/statuses': success([
    { id: 0, name: '待处理', color: '#86909c', description: '反馈已提交，等待处理' },
    { id: 1, name: '处理中', color: '#165dff', description: '正在处理中' },
    { id: 2, name: '已解决', color: '#00b42a', description: '问题已解决' },
    { id: 3, name: '已关闭', color: '#86909c', description: '反馈已关闭' },
    { id: 4, name: '已拒绝', color: '#f53f3f', description: '反馈被拒绝' },
  ]),

  // 反馈优先级列表
  '/api/feedback/priorities': success([
    { id: 0, name: '紧急', color: '#f53f3f', level: 1, description: '需要立即处理' },
    { id: 1, name: '高', color: '#ff7d00', level: 2, description: '需要优先处理' },
    { id: 2, name: '中', color: '#f7ba1e', level: 3, description: '正常处理' },
    { id: 3, name: '低', color: '#00b42a', level: 4, description: '可以延后处理' },
  ]),

  // 反馈类型列表
  '/api/feedback/types': success([
    { id: 0, name: '功能建议' },
    { id: 1, name: 'Bug 反馈' },
    { id: 2, name: '性能问题' },
    { id: 3, name: '用户体验' },
    { id: 4, name: '其他' },
  ]),

  // 反馈统计
  '/api/feedback/statistics': success({
    total: 156,
    pending: 45,
    processing: 32,
    resolved: 56,
    closed: 15,
    rejected: 8,
    urgent: 12,
    high: 38,
    today_new: 5,
    week_new: 23,
    avg_resolve_time: 48,
    satisfaction_rate: 92,
  }),

  // 反馈评论列表
  '/api/feedback/comments/1': success([
    {
      id: 1,
      feedback_id: 1,
      content: '收到，我们会尽快处理这个问题。',
      author_id: 2,
      author_name: '李四',
      author_avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png',
      parent_id: null,
      is_internal: false,
      created_at: '2024-01-15 11:00:00',
    },
    {
      id: 2,
      feedback_id: 1,
      content: '能否提供更多详细信息？比如浏览器版本、网络环境等。',
      author_id: 3,
      author_name: '王五',
      author_avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png',
      parent_id: 1,
      reply_to: '李四',
      is_internal: false,
      created_at: '2024-01-15 12:30:00',
    },
  ]),

  // 反馈标签列表
  '/api/feedback/tags': success([
    { id: 1, name: '功能建议', color: '#165dff', description: '新功能或改进建议', count: 25, status: 1 },
    { id: 2, name: 'Bug报告', color: '#f53f3f', description: '系统缺陷或错误报告', count: 38, status: 1 },
    { id: 3, name: '性能优化', color: '#722ed1', description: '性能相关问题', count: 15, status: 1 },
    { id: 4, name: 'UI/UX改进', color: '#0fc6c2', description: '界面或体验改进', count: 12, status: 1 },
    { id: 5, name: '文档改进', color: '#14c9c9', description: '文档相关问题', count: 8, status: 1 },
    { id: 6, name: '安全问题', color: '#f53f3f', description: '安全漏洞或风险', count: 5, status: 1 },
  ]),
};

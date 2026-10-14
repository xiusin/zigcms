/**
 * 数据库字段说明文档
 * 本文档整理系统中各个模块的数据表字段定义
 */

/**
 * 用户/成员管理模块 (member)
 * 表名: tb_member / sys_user
 */
export interface MemberFields {
  // 基础字段
  id: number; // 用户ID
  username: string; // 用户名（登录账号）
  nickname?: string; // 昵称
  realname?: string; // 真实姓名
  password?: string; // 密码（加密存储）
  mobile?: string; // 手机号
  email?: string; // 邮箱
  avatar?: string; // 头像URL

  // 组织字段
  department_id?: number; // 部门ID
  department_name?: string; // 部门名称

  // 角色字段
  role_id?: number; // 主角色ID
  role_ids?: number[]; // 角色ID列表（多角色）
  role_text?: string; // 角色名称

  // 状态字段
  status: number; // 状态: 0-禁用 1-正常
  state?: number; // 在职状态: 0-离职 1-在职
  is_assistant?: number; // 是否为助理: 0-否 1-是

  // 飞书/企业微信关联
  qy_wchat_id?: string; // 企业微信ID
  feishu_user_id?: string; // 飞书用户ID
  feishu_open_id?: string; // 飞书OpenID

  // 时间字段
  add_time?: string; // 创建时间
  update_time?: string; // 更新时间
  entry_time?: string; // 入职时间
  leave_time?: string; // 离职时间

  // 其他字段
  group_id?: number; // 用户组ID
  company_id?: number; // 公司ID
  create_user_id?: number; // 创建人ID
}

/**
 * 角色管理模块 (role)
 * 表名: tb_role / sys_role
 */
export interface RoleFields {
  id: number; // 角色ID
  role_name: string; // 角色名称
  role_key?: string; // 角色标识（如：admin, user）
  description?: string; // 角色描述
  remark?: string; // 备注
  sort?: number; // 排序（数字越小越靠前）

  // 权限字段
  pages?: string[]; // 页面权限列表
  menu_ids?: number[]; // 菜单ID列表
  button_perms?: string[]; // 按钮权限列表（如：btn:add, btn:edit）

  // 状态字段
  status: number; // 状态: 0-禁用 1-正常

  // 时间字段
  created_at?: string; // 创建时间
  updated_at?: string; // 更新时间
}

/**
 * 部门管理模块 (department)
 * 表名: tb_department / sys_department
 */
export interface DepartmentFields {
  id: number; // 部门ID
  name: string; // 部门名称
  parent_id: number; // 父部门ID（0为顶级）
  leader?: string; // 负责人
  phone?: string; // 联系电话
  email?: string; // 邮箱
  sort?: number; // 排序
  status: number; // 状态: 0-禁用 1-正常

  // 扩展字段
  level?: number; // 部门层级
  path?: string; // 部门路径（如：0-1-5）
  manager_id?: number; // 部门经理ID

  // 时间字段
  created_at?: string; // 创建时间
  updated_at?: string; // 更新时间
}

/**
 * 菜单管理模块 (menu)
 * 表名: tb_menu / sys_menu
 */
export interface MenuFields {
  id: number; // 菜单ID
  parent_id: number; // 父菜单ID
  name?: string; // 菜单名称（用于路由）
  title: string; // 菜单标题（显示名称）
  path: string; // 路由路径
  component?: string; // 组件路径（如：@/views/system/user）
  icon?: string; // 菜单图标（如：icon-user）
  menu_type?: number; // 菜单类型: 1-目录 2-菜单 3-按钮

  // 显示控制
  is_show?: number; // 是否显示: 0-隐藏 1-显示
  is_cache?: number; // 是否缓存: 0-不缓存 1-缓存
  is_frame?: number; // 是否外链: 0-内嵌 1-外链
  hidden?: number; // 隐藏菜单: 0-显示 1-隐藏
  hide_children?: number; // 隐藏子菜单: 0-显示 1-隐藏

  // 权限字段
  perms?: string; // 权限标识（如：system:user:list）
  roles?: string[]; // 允许的角色

  // 排序
  sort?: number; // 排序

  // 状态
  status?: number; // 状态: 0-禁用 1-正常

  // 扩展
  redirect?: string; // 默认跳转路径
  keep_alive?: boolean; // 是否保持缓存

  // 时间字段
  created_at?: string; // 创建时间
  updated_at?: string; // 更新时间
}

/**
 * 操作日志模块 (log)
 * 表名: tb_operation_log / sys_log
 */
export interface OperationLogFields {
  id: number; // 日志ID
  user_id: number; // 操作人ID
  user_text?: string; // 操作人名称

  // 操作信息
  opt_menu: string; // 操作模块
  opt_target?: string; // 操作对象
  opt_action?: string; // 操作动作（登录、新增、编辑、删除、导出、查看）
  opt_info?: string; // 操作内容

  // 公司信息
  company_id?: number; // 公司ID
  company_name?: string; // 公司名称
  company_type?: string; // 公司类型

  // 网络信息
  ip: string; // 操作IP
  location?: string; // IP归属地
  browser?: string; // 浏览器
  os?: string; // 操作系统
  device_type?: string; // 设备类型（PC、Mobile、Tablet）

  // 请求信息
  request_params?: string; // 请求参数（JSON格式）
  response_data?: string; // 响应结果（JSON格式）

  // 状态
  status?: number; // 状态: 0-失败 1-成功

  // 时间
  opt_time: string; // 操作时间
  created_at?: string; // 创建时间
}

/**
 * 订单管理模块 (order)
 * 表名: tb_order / ecom_order
 */
export interface OrderFields {
  id: number; // 订单ID
  order_no: string; // 订单编号

  // 商品信息
  product_id?: number; // 商品ID
  product_name?: string; // 商品名称
  product_image?: string; // 商品图片

  // 用户信息
  user_id?: number; // 用户ID
  user_name?: string; // 用户名称

  // 金额信息
  total_price: number; // 订单总价
  pay_price?: number; // 实付金额
  discount_price?: number; // 优惠金额

  // 支付信息
  pay_type?: number; // 支付方式: 1-微信 2-支付宝 3-银行卡
  pay_time?: string; // 支付时间

  // 状态信息
  status: number; // 订单状态: 1-待付款 2-待发货 3-待收货 4-已完成 5-已取消 6-已退款
  refund_status?: number; // 退款状态: 0-未退款 1-退款中 2-已退款

  // 物流信息
  express_company?: string; // 快递公司
  express_no?: string; // 快递单号

  // 时间字段
  created_at?: string; // 创建时间
  updated_at?: string; // 更新时间
  pay_at?: string; // 支付时间
  deliver_at?: string; // 发货时间
  finish_at?: string; // 完成时间
}

/**
 * 商品管理模块 (product)
 * 表名: tb_product / ecom_product
 */
export interface ProductFields {
  id: number; // 商品ID
  product_name: string; // 商品名称
  product_code?: string; // 商品编码
  category_id?: number; // 分类ID
  category_name?: string; // 分类名称

  // 价格信息
  price: number; // 商品价格
  original_price?: number; // 原价
  cost_price?: number; // 成本价

  // 库存信息
  stock?: number; // 库存数量
  stock_warning?: number; // 库存预警值

  // 商品信息
  image?: string; // 商品图片
  images?: string[]; // 商品图片集
  description?: string; // 商品描述
  unit?: string; // 单位

  // 状态
  status: number; // 状态: 0-下架 1-上架
  is_delete?: number; // 是否删除: 0-正常 1-删除

  // 时间字段
  created_at?: string; // 创建时间
  updated_at?: string; // 更新时间
}

/**
 * 会员管理模块 (member)
 * 表名: tb_member / ecom_member
 */
export interface EcomMemberFields {
  id: number; // 会员ID
  member_name?: string; // 会员名称
  nickname?: string; // 昵称
  mobile?: string; // 手机号
  email?: string; // 邮箱
  avatar?: string; // 头像

  // 会员等级
  level_id?: number; // 等级ID
  level_name?: string; // 等级名称
  points?: number; // 积分

  // 账户信息
  balance?: number; // 账户余额
  freeze_balance?: number; // 冻结金额

  // 状态
  status: number; // 状态: 0-禁用 1-正常

  // 实名认证
  real_name?: string; // 真实姓名
  id_card?: string; // 身份证号
  is_real_verify?: number; // 是否实名认证: 0-否 1-是

  // 时间字段
  created_at?: string; // 注册时间
  updated_at?: string; // 更新时间
  last_login_time?: string; // 最后登录时间
}

/**
 * 供应商管理模块 (supplier)
 * 表名: tb_supplier / ecom_supplier
 */
export interface SupplierFields {
  id: number; // 供应商ID
  supplier_name: string; // 供应商名称
  supplier_code?: string; // 供应商编码
  contact?: string; // 联系人
  phone?: string; // 联系电话
  email?: string; // 邮箱
  address?: string; // 地址

  // 经营信息
  business_license?: string; // 营业执照
  license_image?: string; // 执照图片

  // 状态
  status: number; // 状态: 0-禁用 1-正常

  // 时间字段
  created_at?: string; // 创建时间
  updated_at?: string; // 更新时间
}

/**
 * 系统配置模块 (config)
 * 表名: tb_config / sys_config
 */
export interface ConfigFields {
  id: number; // 配置ID
  config_key: string; // 配置键（如：site_name）
  config_value: string; // 配置值
  config_name?: string; // 配置名称
  config_group?: string; // 配置分组
  config_type?: string; // 配置类型: text-文本 textarea-文本域 select-下拉单选 switch-开关
  options?: string; // 选项列表（JSON格式，用于select类型）
  remark?: string; // 备注
  sort?: number; // 排序
  status?: number; // 状态: 0-禁用 1-正常

  // 时间字段
  created_at?: string; // 创建时间
  updated_at?: string; // 更新时间
}

/**
 * 字典管理模块 (dict)
 * 表名: tb_dict / sys_dict
 */
export interface DictFields {
  id: number; // 字典ID
  dict_name: string; // 字典名称
  dict_code: string; // 字典编码
  description?: string; // 描述
  status: number; // 状态: 0-禁用 1-正常
  created_at?: string; // 创建时间
}

/**
 * 字典项管理模块 (dict_item)
 * 表名: tb_dict_item / sys_dict_item
 */
export interface DictItemFields {
  id: number; // 字典项ID
  dict_id: number; // 字典ID
  item_text: string; // 字典项文本
  item_value: string; // 字典项值
  sort?: number; // 排序
  status?: number; // 状态: 0-禁用 1-正常
  remark?: string; // 备注
}

/**
 * 通用状态码
 */
export const CommonStatus = {
  DISABLED: 0, // 禁用
  ENABLED: 1, // 启用
} as const;

/**
 * 菜单类型
 */
export const MenuType = {
  DIRECTORY: 1, // 目录
  MENU: 2, // 菜单
  BUTTON: 3, // 按钮
} as const;

/**
 * 订单状态
 */
export const OrderStatus = {
  PENDING_PAY: 1, // 待付款
  PENDING_DELIVER: 2, // 待发货
  PENDING_RECEIVE: 3, // 待收货
  COMPLETED: 4, // 已完成
  CANCELLED: 5, // 已取消
  REFUNDED: 6, // 已退款
} as const;

/**
 * 操作日志动作
 */
export const LogAction = {
  LOGIN: '登录',
  ADD: '新增',
  EDIT: '编辑',
  DELETE: '删除',
  EXPORT: '导出',
  IMPORT: '导入',
  VIEW: '查看',
  AUDIT: '审核',
} as const;

/**
 * 按钮权限标识
 */
export const ButtonPerms = {
  ADD: 'btn:add', // 新增
  EDIT: 'btn:edit', // 编辑
  DELETE: 'btn:delete', // 删除
  EXPORT: 'btn:export', // 导出
  IMPORT: 'btn:import', // 导入
  QUERY: 'btn:query', // 查询
  DETAIL: 'btn:detail', // 详情
  AUDIT: 'btn:audit', // 审核
  ENABLE: 'btn:enable', // 启用
  DISABLE: 'btn:disable', // 禁用
  PERMISSION: 'btn:permission', // 分配权限
  RESET_PWD: 'btn:resetPwd', // 重置密码
} as const;

// ========== 业务管理模块 ==========

/**
 * 业务会员管理模块 (business_member)
 * 表名: tb_business_member / business_member
 * 用户端会员，与系统用户(member)区分
 */
export interface BusinessMemberFields {
  // 基础字段
  id: number; // 会员ID
  user_id: number; // 关联用户ID
  username: string; // 用户名
  nickname?: string; // 昵称
  mobile?: string; // 手机号
  email?: string; // 邮箱
  avatar?: string; // 头像URL

  // 会员等级
  gender?: number; // 性别: 0-未知 1-男 2-女
  level?: number; // 会员等级
  level_name?: string; // 会员等级名称

  // 资产字段
  balance?: number; // 账户余额
  total_consume?: number; // 累计消费金额
  total_order?: number; // 累计订单数
  points?: number; // 积分

  // 状态字段
  status: number; // 状态: 0-禁用 1-正常

  // 来源字段
  source?: string; // 注册来源: PC/H5/APP/小程序
  last_login?: string; // 最后登录时间

  // 时间字段
  created_at?: string; // 创建时间
}

/**
 * 工具箱模块 (toolbox_module)
 * 表名: tb_toolbox_module
 */
export interface ToolModuleFields {
  // 基础字段
  id: number; // 模块ID
  module_name: string; // 模块名称
  module_code: string; // 模块代码
  module_icon?: string; // 模块图标
  description?: string; // 模块描述

  // 分类字段
  category?: number; // 分类ID
  category_name?: string; // 分类名称

  // 价格字段
  is_package?: number; // 是否套餐: 0-单卖 1-套餐
  package_price?: number; // 套餐价格
  single_price?: number; // 单个价格
  price_config?: {
    month_price?: number; // 月付价格
    quarter_price?: number; // 季付价格
    year_price?: number; // 年付价格
    lifetime_price?: number; // 终身价格
  };

  // 统计字段
  usage_count?: number; // 使用次数
  status?: number; // 状态: 0-禁用 1-启用
  created_at?: string; // 创建时间
}

/**
 * 工具箱套餐 (toolbox_package)
 * 表名: tb_toolbox_package
 */
export interface ToolPackageFields {
  // 基础字段
  id: number; // 套餐ID
  package_name: string; // 套餐名称
  package_code: string; // 套餐代码
  description?: string; // 套餐描述
  modules?: number[]; // 包含的模块ID列表

  // 价格字段
  price?: number; // 价格
  discount?: number; // 折扣(百分比)

  // 状态字段
  status?: number; // 状态: 0-禁用 1-启用
  created_at?: string; // 创建时间
}

/**
 * 优惠活动 (promotion)
 * 表名: tb_promotion / promotion_activity
 */
export interface PromotionFields {
  // 基础字段
  id: number; // 活动ID
  activity_name: string; // 活动名称
  activity_type: number; // 活动类型: 1-满减 2-折扣 3-秒杀 4-拼团 5-抽奖 6-积分兑换
  activity_code: string; // 活动编码
  description?: string; // 活动描述

  // 时间字段
  start_time: string; // 开始时间
  end_time: string; // 结束时间

  // 规则字段
  rules?: string; // 活动规则(JSON)
  condition?: string; // 参与条件

  // 状态字段
  status?: number; // 状态: 0-禁用 1-启用 2-进行中 3-已结束
  created_at?: string; // 创建时间
}

/**
 * 优惠活动类型
 */
export const PromotionType = {
  FULL_REDUCE: 1, // 满减
  DISCOUNT: 2, // 折扣
  SECKILL: 3, // 秒杀
  GROUP: 4, // 拼团
  LOTTERY: 5, // 抽奖
  POINTS_EXCHANGE: 6, // 积分兑换
} as const;

// ========== 报表统计模块 ==========

/**
 * 报表统计概览 (report_statistics)
 * 数据来源: 聚合统计
 */
export interface ReportStatisticsFields {
  // 订单统计
  total_order: number; // 累计订单数
  total_amount: number; // 累计金额
  today_order: number; // 今日订单
  today_amount: number; // 今日金额
  yesterday_order: number; // 昨日订单
  yesterday_amount: number; // 昨日金额

  // 用户统计
  total_user: number; // 累计用户
  active_user: number; // 活跃用户

  // 增长指标
  growth?: number; // 增长率(%)
}

/**
 * 订单统计 (report_order)
 * 表名: report_order / order_statistics
 */
export interface ReportOrderFields {
  // 基础字段
  id: number; // 记录ID
  order_no: string; // 订单号

  // 商品信息
  product_name?: string; // 商品名称
  price?: number; // 单价
  num?: number; // 数量
  total_price?: number; // 总价

  // 用户信息
  user_name?: string; // 用户名
  user_phone?: string; // 用户电话

  // 状态字段
  status: number; // 订单状态

  // 时间字段
  created_at?: string; // 下单时间
}

/**
 * 商品统计 (report_product)
 * 表名: report_product / product_statistics
 */
export interface ReportProductFields {
  // 基础字段
  id: number; // 记录ID
  product_name: string; // 商品名称

  // 销售统计
  sales_count?: number; // 销售数量
  sales_amount?: number; // 销售金额

  // 退货统计
  return_count?: number; // 退货数量

  // 时间字段
  created_at?: string; // 统计时间
}

/**
 * 区域统计 (report_region)
 * 表名: report_region / region_statistics
 */
export interface ReportRegionFields {
  // 基础字段
  id: number; // 记录ID
  region_name: string; // 区域名称

  // 区域统计
  order_count?: number; // 订单数
  order_amount?: number; // 订单金额
  user_count?: number; // 用户数
}

/**
 * 模块统计 (report_module)
 * 表名: report_module / module_statistics
 */
export interface ReportModuleFields {
  // 基础字段
  id: number; // 记录ID
  module_name: string; // 模块名称

  // 使用统计
  usage_count?: number; // 使用次数
  usage_amount?: number; // 使用收入

  // 用户统计
  user_count?: number; // 使用用户数
}

// ========== 运营管理模块 ==========

/**
 * 任务调度 (task)
 * 表名: tb_task / system_task
 */
export interface TaskFields {
  // 基础字段
  id: number; // 任务ID
  task_name: string; // 任务名称
  task_type: number; // 任务类型: 1-同步 2-处理 3-推送 4-统计 5-清理 6-备份
  group_name?: string; // 任务组名
  target: string; // 执行目标(类名)
  params?: string; // 执行参数(JSON)

  // 执行配置
  cron?: string; // Cron表达式
  timeout?: number; // 超时时间(秒)
  delay?: number; // 延迟执行(毫秒)
  retry?: number; // 重试次数

  // 状态字段
  status: number; // 状态: 0-禁用 1-启用

  // 运行信息
  last_run_time?: string; // 上次执行时间
  created_at?: string; // 创建时间
}

/**
 * 任务类型
 */
export const TaskType = {
  SYNC: 1, // 同步任务
  PROCESS: 2, // 处理任务
  PUSH: 3, // 推送任务
  STATISTICS: 4, // 统计任务
  CLEAN: 5, // 清理任务
  BACKUP: 6, // 备份任务
} as const;

/**
 * 插件管理 (plugin)
 * 表名: tb_plugin / system_plugin
 */
export interface PluginFields {
  // 基础字段
  id: number; // 插件ID
  name: string; // 插件名称
  identifier: string; // 插件标识符
  version?: string; // 版本号
  logo?: string; // 插件logo
  plugin_type?: number; // 插件类型

  // 作者信息
  author?: string; // 作者
  price?: number; // 价格(0为免费)

  // 统计信息
  downloads?: number; // 下载量
  rating?: number; // 评分(1-5)

  // 内容字段
  description?: string; // 插件描述
  features?: string; // 功能特性(换行分隔)

  // 状态字段
  status: number; // 状态: 0-禁用 1-启用
  install_time?: string; // 安装时间
  created_at?: string; // 创建时间
}

/**
 * 插件类型
 */
export const PluginType = {
  LOGIN: 1, // 登录插件
  PAYMENT: 2, // 支付插件
  NOTIFICATION: 3, // 通知插件
  ANALYTICS: 4, // 分析插件
  MARKETING: 5, // 营销插件
} as const;

// ========== 安全运维模块 ==========

/**
 * 黑名单管理 (blacklist)
 * 表名: tb_blacklist / security_blacklist
 */
export interface BlacklistFields {
  // 基础字段
  id: number; // 黑名单ID
  target_type: number; // 目标类型: 1-IP 2-手机号 3-邮箱 4-用户ID
  target_value: string; // 目标值

  // 原因字段
  reason?: string; // 拉黑原因
  operator_id?: number; // 操作人ID
  operator_name?: string; // 操作人名称

  // 状态字段
  status: number; // 状态: 0-已解除 1-生效中

  // 时间字段
  expire_time?: string; // 过期时间(永久拉黑为空)
  created_at?: string; // 创建时间
}

/**
 * 黑名单目标类型
 */
export const BlacklistType = {
  IP: 1, // IP地址
  MOBILE: 2, // 手机号
  EMAIL: 3, // 邮箱
  USER_ID: 4, // 用户ID
} as const;

/**
 * 登录日志 (login_log)
 * 表名: tb_login_log / security_login_log
 */
export interface LoginLogFields {
  // 基础字段
  id: number; // 日志ID
  username?: string; // 用户名
  user_id?: number; // 用户ID

  // 登录信息
  ip?: string; // IP地址
  address?: string; // IP归属地
  device?: string; // 设备信息
  browser?: string; // 浏览器
  os?: string; // 操作系统

  // 状态字段
  status: number; // 登录状态: 0-失败 1-成功
  fail_reason?: string; // 失败原因

  // 时间字段
  login_time?: string; // 登录时间
  logout_time?: string; // 登出时间
}

/**
 * 系统日志 (system_log)
 * 表名: tb_system_log / security_system_log
 */
export interface SystemLogFields {
  // 基础字段
  id: number; // 日志ID

  // 操作信息
  username?: string; // 操作人
  module?: string; // 操作模块
  action?: string; // 操作类型
  method?: string; // 请求方法
  url?: string; // 请求URL

  // 请求信息
  params?: string; // 请求参数
  response?: string; // 响应结果

  // 状态字段
  status?: number; // 操作状态: 0-失败 1-成功

  // 耗时
  duration?: number; // 执行时长(毫秒)

  // 时间字段
  created_at?: string; // 操作时间
}

// ========== 仓库管理模块 ==========

/**
 * 仓库商品 (warehouse_product)
 * 表名: tb_warehouse_product / warehouse_product
 */
export interface WarehouseProductFields {
  // 基础字段
  id: number; // 商品ID
  product_name: string; // 商品名称
  product_code?: string; // 商品编码
  barcode?: string; // 条码

  // 分类信息
  category_id?: number; // 分类ID
  category_name?: string; // 分类名称

  // 品牌信息
  brand_id?: number; // 品牌ID
  brand_name?: string; // 品牌名称

  // 库存信息
  stock?: number; // 库存数量
  lock_stock?: number; // 锁定库存
  available_stock?: number; // 可用库存

  // 价格信息
  price?: number; // 售价
  cost_price?: number; // 成本价

  // 状态字段
  status?: number; // 状态: 0-下架 1-上架
  is_delete?: number; // 是否删除: 0-是 1-否

  // 位置信息
  position?: string; // 库位

  // 图片信息
  image?: string; // 商品图片
  images?: string[]; // 商品图片组

  // 时间字段
  created_at?: string; // 创建时间
  updated_at?: string; // 更新时间
}

/**
 * 仓库上架商品 (warehouse_shelve)
 * 表名: tb_warehouse_shelve / warehouse_shelve_product
 */
export interface WarehouseShelveFields {
  // 基础字段
  id: number; // 记录ID
  product_id: number; // 商品ID
  product_name: string; // 商品名称
  sku_info?: string; // SKU信息

  // 库存信息
  quantity?: number; // 数量
  price?: number; // 单价

  // 状态字段
  status?: number; // 状态: 1-待上架 2-已上架 3-已下架

  // 时间字段
  shelve_time?: string; // 上架时间
  created_at?: string; // 创建时间
}

/**
 * 出库记录 (warehouse_outbound)
 * 表名: tb_warehouse_outbound / warehouse_outbound_record
 */
export interface WarehouseOutboundFields {
  // 基础字段
  id: number; // 出库ID
  outbound_no: string; // 出库单号
  product_id: number; // 商品ID
  product_name: string; // 商品名称
  sku_info?: string; // SKU信息

  // 出库信息
  quantity: number; // 出库数量
  price?: number; // 单价
  total_price?: number; // 总价

  // 物流信息
  express_no?: string; // 快递单号
  express_company?: string; // 快递公司

  // 收货信息
  receiver_name?: string; // 收货人
  receiver_phone?: string; // 收货电话
  receiver_address?: string; // 收货地址

  // 状态字段
  status?: number; // 状态: 1-待出库 2-已出库 3-运输中 4-已签收

  // 时间字段
  outbound_time?: string; // 出库时间
  created_at?: string; // 创建时间
}

// ========== 订单模块 ==========

/**
 * 订单管理 (order)
 * 表名: tb_order / order_main
 */
export interface OrderMainFields {
  // 基础字段
  id: number; // 订单ID
  order_no: string; // 订单编号
  product_id?: number; // 商品ID
  product_name: string; // 商品名称

  // 商品信息
  product_image?: string; // 商品图片
  sku_info?: string; // SKU信息
  num?: number; // 数量
  price?: number; // 单价
  total_price?: number; // 总价

  // 优惠信息
  discount_price?: number; // 优惠金额
  actual_price?: number; // 实付金额

  // 用户信息
  user_id?: number; // 用户ID
  user_name?: string; // 用户名
  user_phone?: string; // 用户电话
  user_address?: string; // 用户地址

  // 支付信息
  pay_type?: number; // 支付方式
  pay_time?: string; // 支付时间

  // 状态字段
  status: number; // 订单状态: 1-待付款 2-待发货 3-待收货 4-已完成 5-已取消 6-已退款
  remark?: string; // 备注

  // 时间字段
  created_at?: string; // 创建时间
  updated_at?: string; // 更新时间
}

/**
 * 提货管理 (pickup)
 * 表名: tb_pickup / order_pickup
 */
export interface PickupFields {
  // 基础字段
  id: number; // 提货ID
  pickup_no: string; // 提货单号
  order_id?: number; // 关联订单ID
  order_no?: string; // 订单编号

  // 商品信息
  product_name?: string; // 商品名称
  quantity?: number; // 提货数量
  price?: number; // 单价

  // 提货信息
  pickup_code?: string; // 提货码
  pickup_time?: string; // 提货时间

  // 状态字段
  status: number; // 状态: 1-待提货 2-已提货 3-已过期
  created_at?: string; // 创建时间
}

/**
 * 需求管理 (demand)
 * 表名: tb_demand / product_demand
 */
export interface DemandFields {
  // 基础字段
  id: number; // 需求ID
  demand_no: string; // 需求单号
  title?: string; // 需求标题
  demand_type?: number; // 需求类型

  // 商品信息
  product_ids?: number[]; // 关联商品ID列表
  products?: string; // 商品信息(JSON)

  // 需求描述
  description?: string; // 需求描述
  attachment?: string; // 附件

  // 状态字段
  status?: number; // 状态: 1-待处理 2-处理中 3-已完成 4-已拒绝
  priority?: number; // 优先级: 1-低 2-中 3-高 4-紧急

  // 申请人
  apply_user_id?: number; // 申请人ID
  apply_user_name?: string; // 申请人

  // 时间字段
  created_at?: string; // 创建时间
  completed_at?: string; // 完成时间
}

/**
 * 退款管理 (refund)
 * 表名: tb_refund / order_refund
 */
export interface RefundFields {
  // 基础字段
  id: number; // 退款ID
  refund_no: string; // 退款单号
  order_id: number; // 订单ID
  order_no?: string; // 订单编号

  // 退款信息
  refund_amount: number; // 退款金额
  refund_reason?: string; // 退款原因
  refund_remark?: string; // 退款备注

  // 状态字段
  status: number; // 状态: 1-待审核 2-审核通过 3-审核拒绝 4-已退款
  audit_time?: string; // 审核时间
  audit_remark?: string; // 审核备注

  // 时间字段
  created_at?: string; // 申请时间
  updated_at?: string; // 更新时间
}

/**
 * 审批管理 (approval)
 * 表名: tb_approval / workflow_approval
 */
export interface ApprovalFields {
  // 基础字段
  id: number; // 审批ID
  approval_no: string; // 审批单号
  title?: string; // 审批标题
  type?: number; // 审批类型: 1-请假 2-报销 3-采购 4-其他

  // 审批内容
  content?: string; // 审批内容
  amount?: number; // 金额
  attachment?: string; // 附件

  // 申请人
  apply_user_id?: number; // 申请人ID
  apply_user_name?: string; // 申请人名称

  // 审批流程
  current_step?: number; // 当前步骤
  approver_ids?: number[]; // 审批人ID列表
  approver_names?: string; // 审批人名称

  // 状态字段
  status: number; // 状态: 1-待审批 2-审批中 3-已通过 4-已拒绝

  // 时间字段
  created_at?: string; // 创建时间
  approved_at?: string; // 审批时间
}

/**
 * 审批类型
 */
export const ApprovalType = {
  LEAVE: 1, // 请假
  EXPENSE: 2, // 报销
  PURCHASE: 3, // 采购
  OTHER: 4, // 其他
} as const;

/**
 * 流程管理 (flow)
 * 表名: tb_flow / workflow_flow
 */
export interface FlowFields {
  // 基础字段
  id: number; // 流程ID
  flow_name: string; // 流程名称
  flow_code: string; // 流程编码
  flow_type?: number; // 流程类型

  // 流程配置
  nodes?: string; // 节点配置(JSON)
  edges?: string; // 边配置(JSON)

  // 状态字段
  status?: number; // 状态: 0-禁用 1-启用

  // 时间字段
  created_at?: string; // 创建时间
  updated_at?: string; // 更新时间
}

// ========== 运营任务中心模块 ==========

/**
 * 广告创建任务 (ad_create)
 * 表名: tb_ad_create / task_ad_create
 */
export interface AdCreateTaskFields {
  // 基础字段
  id: number; // 任务ID
  task_name: string; // 任务名称
  ad_account_id?: number; // 广告账户ID

  // 广告信息
  ad_name?: string; // 广告名称
  ad_type?: number; // 广告类型
  budget?: number; // 预算

  // 状态字段
  status?: number; // 状态: 1-待执行 2-执行中 3-成功 4-失败

  // 统计
  success_count?: number; // 成功数
  fail_count?: number; // 失败数

  // 时间字段
  execute_time?: string; // 执行时间
  completed_time?: string; // 完成时间
  created_at?: string; // 创建时间
}

/**
 * 广告编辑任务 (ad_edit)
 * 表名: tb_ad_edit / task_ad_edit
 */
export interface AdEditTaskFields {
  // 基础字段
  id: number; // 任务ID
  task_name: string; // 任务名称
  ad_id?: number; // 广告ID

  // 编辑内容
  edit_content?: string; // 编辑内容(JSON)

  // 状态字段
  status?: number; // 状态: 1-待执行 2-执行中 3-成功 4-失败

  // 时间字段
  execute_time?: string; // 执行时间
  created_at?: string; // 创建时间
}

/**
 * 广告复制任务 (ad_copy)
 * 表名: tb_ad_copy / task_ad_copy
 */
export interface AdCopyTaskFields {
  // 基础字段
  id: number; // 任务ID
  task_name: string; // 任务名称
  source_ad_id?: number; // 源广告ID
  copy_count?: number; // 复制数量

  // 状态字段
  status?: number; // 状态: 1-待执行 2-执行中 3-成功 4-失败

  // 时间字段
  execute_time?: string; // 执行时间
  created_at?: string; // 创建时间
}

/**
 * 广告下载任务 (ad_download)
 * 表名: tb_ad_download / task_ad_download
 */
export interface AdDownloadTaskFields {
  // 基础字段
  id: number; // 任务ID
  task_name: string; // 任务名称
  ad_ids?: number[]; // 广告ID列表
  download_url?: string; // 下载地址

  // 状态字段
  status?: number; // 状态: 1-待执行 2-执行中 3-成功 4-失败

  // 时间字段
  execute_time?: string; // 执行时间
  created_at?: string; // 创建时间
}

/**
 * 任务状态
 */
export const TaskStatus = {
  PENDING: 1, // 待执行
  RUNNING: 2, // 执行中
  SUCCESS: 3, // 成功
  FAILED: 4, // 失败
} as const;

// ========== 基础数据模块 ==========

/**
 * 字典管理 (dict)
 * 表名: tb_dict / system_dict
 */
export interface SystemDictFields {
  // 基础字段
  id: number; // 字典ID
  dict_name: string; // 字典名称
  dict_code: string; // 字典编码
  dict_type?: string; // 字典类型
  description?: string; // 描述
  is_system?: number; // 是否系统内置: 0-否 1-是

  // 状态字段
  status?: number; // 状态: 0-禁用 1-启用

  // 时间字段
  created_at?: string; // 创建时间
  updated_at?: string; // 更新时间
}

/**
 * 字典项 (dict_item)
 * 表名: tb_dict_item / system_dict_item
 */
export interface SystemDictItemFields {
  // 基础字段
  id: number; // 字典项ID
  dict_id: number; // 字典ID
  item_text: string; // 字典项文本
  item_value: string; // 字典项值
  sort?: number; // 排序
  status?: number; // 状态: 0-禁用 1-启用
  remark?: string; // 备注
}

/**
 * 品牌管理 (brand)
 * 表名: tb_brand / product_brand
 */
export interface BrandFields {
  // 基础字段
  id: number; // 品牌ID
  brand_name: string; // 品牌名称
  brand_code?: string; // 品牌编码
  logo?: string; // 品牌logo
  description?: string; // 品牌描述

  // 状态字段
  status?: number; // 状态: 0-禁用 1-启用
  sort?: number; // 排序

  // 时间字段
  created_at?: string; // 创建时间
  updated_at?: string; // 更新时间
}

/**
 * 模板管理 (template)
 * 表名: tb_template / system_template
 */
export interface TemplateFields {
  // 基础字段
  id: number; // 模板ID
  template_name: string; // 模板名称
  template_code: string; // 模板编码
  template_type?: number; // 模板类型: 1-消息模板 2-邮件模板 3-短信模板

  // 模板内容
  title?: string; // 标题
  content?: string; // 内容
  variables?: string; // 变量配置(JSON)

  // 状态字段
  status?: number; // 状态: 0-禁用 1-启用

  // 时间字段
  created_at?: string; // 创建时间
  updated_at?: string; // 更新时间
}

/**
 * 模板类型
 */
export const TemplateType = {
  MESSAGE: 1, // 消息模板
  EMAIL: 2, // 邮件模板
  SMS: 3, // 短信模板
} as const;

// ========== 财务管理模块 ==========

/**
 * 收入管理 (income)
 * 表名: tb_income / finance_income
 */
export interface IncomeFields {
  // 基础字段
  id: number; // 收入ID
  income_no: string; // 收入单号
  income_type: number; // 收入类型: 1-订单收入 2-充值 3-退款

  // 金额信息
  amount: number; // 金额
  actual_amount?: number; // 实际金额
  fee?: number; // 手续费

  // 关联信息
  order_id?: number; // 订单ID
  order_no?: string; // 订单编号
  user_id?: number; // 用户ID
  user_name?: string; // 用户名称

  // 支付信息
  pay_type?: number; // 支付方式
  transaction_id?: string; // 交易流水号

  // 状态字段
  status: number; // 状态: 1-待确认 2-已确认 3-已取消

  // 时间字段
  income_time?: string; // 收入时间
  created_at?: string; // 创建时间
}

/**
 * 收入类型
 */
export const IncomeType = {
  ORDER: 1, // 订单收入
  RECHARGE: 2, // 充值
  REFUND: 3, // 退款(负收入)
} as const;

/**
 * 提现管理 (withdraw)
 * 表名: tb_withdraw / finance_withdraw
 */
export interface WithdrawFields {
  // 基础字段
  id: number; // 提现ID
  withdraw_no: string; // 提现单号

  // 用户信息
  user_id: number; // 用户ID
  user_name?: string; // 用户名称
  account_type?: number; // 账户类型: 1-余额 2-佣金

  // 金额信息
  amount: number; // 提现金额
  fee?: number; // 手续费
  actual_amount?: number; // 实际到账

  // 收款信息
  bank_name?: string; // 银行名称
  bank_account?: string; // 银行账号
  account_name?: string; // 账户名称
  ifsc_code?: string; // IFSC代码

  // 状态字段
  status: number; // 状态: 1-待审核 2-审核通过 3-审核拒绝 4-已打款 5-打款失败
  remark?: string; // 备注

  // 审核信息
  auditor_id?: number; // 审核人ID
  auditor_name?: string; // 审核人名称
  audit_time?: string; // 审核时间
  audit_remark?: string; // 审核备注

  // 打款信息
  transfer_time?: string; // 打款时间

  // 时间字段
  created_at?: string; // 申请时间
  updated_at?: string; // 更新时间
}

/**
 * 提现状态
 */
export const WithdrawStatus = {
  PENDING: 1, // 待审核
  APPROVED: 2, // 审核通过
  REJECTED: 3, // 审核拒绝
  PAID: 4, // 已打款
  FAILED: 5, // 打款失败
} as const;

// ========== 设备管理模块 ==========

/**
 * 设备管理 (machine)
 * 表名: tb_machine / device_machine
 */
export interface MachineFields {
  // 基础字段
  id: number; // 设备ID
  machine_no: string; // 设备编号
  machine_name?: string; // 设备名称
  machine_type?: number; // 设备类型

  // 设备信息
  model?: string; // 型号
  sn?: string; // 序列号
  imei?: string; // IMEI
  mac?: string; // MAC地址

  // 绑定信息
  user_id?: number; // 绑定用户ID
  user_name?: string; // 绑定用户名称
  bind_time?: string; // 绑定时间

  // 授权信息
  expire_time?: string; // 过期时间
  is_activated?: number; // 是否激活: 0-否 1-是
  activated_time?: string; // 激活时间

  // 状态字段
  status: number; // 状态: 0-离线 1-在线 2-故障
  online_status?: number; // 在线状态: 0-离线 1-在线

  // 位置信息
  location?: string; // 位置
  last_online_time?: string; // 最后在线时间

  // 时间字段
  created_at?: string; // 创建时间
  updated_at?: string; // 更新时间
}

/**
 * 设备类型
 */
export const MachineType = {
  PHONE: 1, // 手机
  TABLET: 2, // 平板
  PC: 3, // 电脑
  POS: 4, // POS机
  IOT: 5, // IoT设备
} as const;

// ========== 消息模块 ==========

/**
 * 消息管理 (message)
 * 表名: tb_message / system_message
 */
export interface MessageFields {
  // 基础字段
  id: number; // 消息ID
  title?: string; // 消息标题
  content: string; // 消息内容
  message_type: number; // 消息类型: 1-系统通知 2-订单通知 3-账户通知 4-营销消息

  // 发送者
  sender_id?: number; // 发送者ID
  sender_name?: string; // 发送者名称

  // 接收者
  receiver_id?: number; // 接收者ID
  receiver_type?: number; // 接收者类型: 1-个人 2-全员

  // 状态字段
  is_read?: number; // 是否已读: 0-否 1-是
  read_time?: string; // 阅读时间

  // 跳转信息
  link_url?: string; // 跳转链接
  link_type?: number; // 链接类型

  // 时间字段
  send_time?: string; // 发送时间
  created_at?: string; // 创建时间
}

/**
 * 消息类型
 */
export const MessageType = {
  SYSTEM: 1, // 系统通知
  ORDER: 2, // 订单通知
  ACCOUNT: 3, // 账户通知
  MARKETING: 4, // 营销消息
} as const;

/**
 * 聊天记录 (chat)
 * 表名: tb_chat / im_chat
 */
export interface ChatFields {
  // 基础字段
  id: number; // 消息ID
  session_id?: string; // 会话ID

  // 发送者
  sender_id: number; // 发送者ID
  sender_name?: string; // 发送者名称
  sender_avatar?: string; // 发送者头像

  // 接收者
  receiver_id: number; // 接收者ID
  receiver_name?: string; // 接收者名称
  receiver_avatar?: string; // 接收者头像

  // 消息内容
  message_type: number; // 消息类型: 1-文本 2-图片 3-语音 4-文件
  content: string; // 消息内容
  media_url?: string; // 媒体URL

  // 状态字段
  status?: number; // 状态: 1-正常 2-撤回 3-删除

  // 时间字段
  send_time: string; // 发送时间
  created_at?: string; // 创建时间
}

/**
 * 消息内容类型
 */
export const MessageContentType = {
  TEXT: 1, // 文本
  IMAGE: 2, // 图片
  VOICE: 3, // 语音
  FILE: 4, // 文件
} as const;

// ========== 激活码模块 ==========

/**
 * 激活码管理 (activation)
 * 表名: tb_activation / system_activation
 */
export interface ActivationFields {
  // 基础字段
  id: number; // 激活码ID
  code: string; // 激活码
  code_type?: number; // 激活码类型: 1-时长卡 2-功能卡 3-点数卡

  // 权益信息
  duration?: number; // 时长(天), 仅时长卡有效
  module_ids?: string; // 功能模块ID列表, 仅功能卡有效
  points?: number; // 点数, 仅点数卡有效

  // 批次信息
  batch_no?: string; // 批次号
  batch_id?: number; // 批次ID

  // 使用信息
  user_id?: number; // 使用用户ID
  user_name?: string; // 使用用户名称
  use_time?: string; // 使用时间

  // 状态字段
  status: number; // 状态: 0-未使用 1-已使用 2-已禁用 3-已过期
  expire_time?: string; // 过期时间

  // 时间字段
  generated_at?: string; // 生成时间
  created_at?: string; // 创建时间
}

/**
 * 激活码类型
 */
export const ActivationType = {
  DURATION: 1, // 时长卡
  MODULE: 2, // 功能卡
  POINTS: 3, // 点数卡
} as const;

/**
 * 激活码状态
 */
export const ActivationStatus = {
  UNUSED: 0, // 未使用
  USED: 1, // 已使用
  DISABLED: 2, // 已禁用
  EXPIRED: 3, // 已过期
} as const;

// ========== 字段管理模块 ==========

/**
 * 字段分类 (field_category)
 * 表名: tb_field_category / system_field_category
 * 用于管理字段的分类，如：会员字段、订单字段、商品字段等
 */
export interface FieldCategoryFields {
  // 基础字段
  id: number; // 分类ID
  category_name: string; // 分类名称
  category_code: string; // 分类编码
  description?: string; // 分类描述
  parent_id?: number; // 父分类ID(用于层级结构)

  // 关联信息
  table_name?: string; // 关联数据库表名
  entity_name?: string; // 实体名称

  // 排序字段
  sort?: number; // 排序
  level?: number; // 层级深度

  // 状态字段
  is_system?: number; // 是否系统内置: 0-否 1-是
  status?: number; // 状态: 0-禁用 1-启用

  // 时间字段
  created_at?: string; // 创建时间
  updated_at?: string; // 更新时间
}

/**
 * 字段定义 (field_definition)
 * 表名: tb_field_definition / system_field_definition
 * 用于管理每个业务模块的具体字段元数据
 */
export interface FieldDefinitionFields {
  // 基础字段
  id: number; // 字段ID
  field_name: string; // 字段名称(中文)
  field_code: string; // 字段编码(英文,对应数据库列名)
  category_id: number; // 所属分类ID

  // 字段类型配置
  field_type: number; // 字段类型: 1-文本 2-数值 3-日期 4-日期时间 5-下拉框 6-单选 7-复选 8-开关 9-文本域 10-图片 11-文件 12-富文本 13-手机号 14-邮箱 15-金额
  data_type?: string; // 数据类型: varchar/int/decimal/datetime/text等
  length?: number; // 长度
  precision?: number; // 精度(小数位数)

  // 字段属性
  default_value?: string; // 默认值
  is_required?: number; // 是否必填: 0-否 1-是
  is_unique?: number; // 是否唯一: 0-否 1-是
  is_primary_key?: number; // 是否主键: 0-否 1-是
  is_foreign_key?: number; // 是否外键: 0-否 1-是
  foreign_table?: string; // 外键关联表

  // 验证规则
  validation_rule?: string; // 验证规则(JSON)
  min_value?: number; // 最小值(数值类型)
  max_value?: number; // 最大值(数值类型)
  min_length?: number; // 最小长度(文本类型)
  max_length?: number; // 最大长度(文本类型)

  // 显示配置
  is_list_show?: number; // 列表是否显示: 0-否 1-是
  is_form_show?: number; // 表单是否显示: 0-否 1-是
  is_query_show?: number; // 查询是否显示: 0-否 1-是
  show_type?: number; // 显示类型: 1-文本 2-链接 3-图片 4-标签 5-开关 6-颜色
  placeholder?: string; // 占位符
  tooltip?: string; // 提示信息

  // 排序配置
  sort?: number; // 排序
  width?: number; // 列表宽度(px)

  // 字典配置
  dict_type?: string; // 字典类型(关联字典表)
  dict_url?: string; // 字典请求URL(远程字典)
  cascade?: string; // 级联配置(JSON)

  // 状态字段
  is_system?: number; // 是否系统字段: 0-否 1-是
  is_disabled?: number; // 是否禁用: 0-否 1-是

  // 时间字段
  created_at?: string; // 创建时间
  updated_at?: string; // 更新时间
}

/**
 * 字段类型
 */
export const FieldType = {
  TEXT: 1, // 文本
  NUMBER: 2, // 数值
  DATE: 3, // 日期
  DATETIME: 4, // 日期时间
  SELECT: 5, // 下拉框
  RADIO: 6, // 单选
  CHECKBOX: 7, // 复选
  SWITCH: 8, // 开关
  TEXTAREA: 9, // 文本域
  IMAGE: 10, // 图片
  FILE: 11, // 文件
  RICH_TEXT: 12, // 富文本
  MOBILE: 13, // 手机号
  EMAIL: 14, // 邮箱
  MONEY: 15, // 金额
} as const;

/**
 * 字段字典值 (field_dict_value)
 * 表名: tb_field_dict_value / system_field_dict_value
 * 用于管理字段的可选值，适用于下拉框、单选、复选等类型
 */
export interface FieldDictValueFields {
  // 基础字段
  id: number; // 字典值ID
  field_id: number; // 字段ID(关联field_definition)
  dict_label: string; // 字典标签(显示文本)
  dict_value: string; // 字典值(实际值)
  sort?: number; // 排序
  color?: string; // 标签颜色(如: #1890ff)

  // 级联配置
  parent_value?: string; // 父级值(用于级联选择)
  level?: number; // 层级(用于树形选择)

  // 扩展配置
  icon?: string; // 图标
  ext_value?: string; // 扩展值(JSON)

  // 状态字段
  is_default?: number; // 是否默认: 0-否 1-是
  is_disabled?: number; // 是否禁用: 0-否 1-是
  status?: number; // 状态: 0-禁用 1-启用

  // 时间字段
  created_at?: string; // 创建时间
  updated_at?: string; // 更新时间
}

/**
 * 字段配置 (field_config)
 * 表名: tb_field_config / system_field_config
 * 用于管理每个业务模块的字段显示/隐藏、排序等配置
 */
export interface FieldConfigFields {
  // 基础字段
  id: number; // 配置ID
  config_key: string; // 配置Key(如: member_list, order_form)
  category_id: number; // 字段分类ID

  // 配置类型
  config_type: number; // 配置类型: 1-列表配置 2-表单配置 3-查询配置 4-详情配置

  // 字段配置(JSON数组)
  field_config: string; // 字段配置JSON: [{field_id, show, required, sort, width, ...}]

  // 状态字段
  is_default?: number; // 是否默认配置: 0-否 1-是
  status?: number; // 状态: 0-禁用 1-启用

  // 分配信息
  role_id?: number; // 角色ID(如果为null则为全局配置)
  user_id?: number; // 用户ID(如果为null则为角色配置)

  // 时间字段
  created_at?: string; // 创建时间
  updated_at?: string; // 更新时间
}

/**
 * 字段配置类型
 */
export const FieldConfigType = {
  LIST: 1, // 列表配置
  FORM: 2, // 表单配置
  QUERY: 3, // 查询配置
  DETAIL: 4, // 详情配置
} as const;

/**
 * 预设字段分类编码
 */
export const FieldCategoryCode = {
  MEMBER: 'member', // 会员字段
  ORDER: 'order', // 订单字段
  PRODUCT: 'product', // 商品字段
  WAREHOUSE: 'warehouse', // 仓库字段
  FINANCE: 'finance', // 财务字段
  SYSTEM: 'system', // 系统字段
  DEVICE: 'device', // 设备字段
  MARKETING: 'marketing', // 营销字段
} as const;

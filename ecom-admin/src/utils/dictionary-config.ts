export const colors = {
  primary: 'rgb(var(--arcoblue-6))', // 全局主色
  link: 'rgb(var(--arcoblue-6))', // 链接色
  success: 'rgb(var(--green-4))', // 成功色
  warning: 'rgb(var(--orange-6))', // 警告色
  info: 'rgb(var(--green-4))', // 信息
  error: 'rgb(var(--red-6))', // 错误色
  disable: 'var(--color-neutral-4)', // 禁用
};

interface dictType {
  [name: string]: any;
}
// 全局静态字典配置
const allDict: dictType = {
  // 客户类型
  customerType: [
    {
      id: 1,
      name: '直客',
    },
    {
      id: 2,
      name: '渠道',
    },
    {
      id: 3,
      name: '代运营',
    },
  ],
  // 业务类型
  businessType: [
    {
      id: 'LA',
      name: 'LA',
    },
    {
      id: 'KA',
      name: 'KA',
    },
  ],
  // 素材类型
  materialType: [
    { name: '视频', id: 'V' },
    { name: '图片', id: 'P' },
  ],
  // 种类
  category: [
    {
      id: 1,
      name: '口播',
    },
    {
      id: 2,
      name: '剧情',
    },
    {
      id: 3,
      name: '纯剪辑',
    },
    {
      id: 4,
      name: '改视频',
    },
  ],
  // 状态类型
  state: [
    { name: '停用', id: -1 },
    { name: '正常', id: 1 },
  ],
  openSass: [
    {
      id: 1,
      name: '是',
    },
    {
      id: 0,
      name: '否',
    },
  ],
  progressStatus: [
    {
      id: 1,
      name: '进行中',
    },
    {
      id: 3,
      name: '已完成',
    },
    {
      id: 5,
      name: '部分失败',
    },
    {
      id: 7,
      name: '全部失败',
    },
  ],
  operateType: [
    {
      id: 1,
      name: '修改广告计划',
    },
  ],
  progressType: [
    {
      id: 1,
      name: '修改中',
    },
    {
      id: 3,
      name: '成功',
    },
    {
      id: 5,
      name: '失败',
    },
  ],
  AUTO_CREATE_STATE: [
    // 极速创建状态
    {
      id: 1,
      name: '待推送',
    },
    {
      id: 3,
      name: '等待中',
    },
    {
      id: 5,
      name: '进行中',
    },
    {
      id: 7,
      name: '已暂停',
    },
    {
      id: 9,
      name: '已完成',
    },
  ],
  // 推送列表排序字段
  PUSH_STATE: [
    // 极速创建状态
    {
      id: 1,
      name: '推送中',
    },
    {
      id: 3,
      name: '推送成功',
    },
    {
      id: 5,
      name: '推送失败',
    },
  ],
  screenType: [
    { name: '横屏', id: 1 },
    { name: '竖屏', id: 2 },
  ],
  // 平台/代理商类型
  agentType: [
    // { name: '巨量引擎', id: 1 },
    { name: '巨量千川', id: 2 },
    // { name: '磁力引擎', id: 3 },
    // { name: '磁力金牛', id: 4 },
    // { name: '广点通', id: 5 },
    // { name: '超级汇川(UC)', id: 7 },
  ],
  videoCategory: [
    { name: '口播', id: 1 },
    { name: '剧情', id: 2 },
    { name: '纯剪辑', id: 3 },
    { name: '改视频', id: 4 },
  ],
  videoSource: [
    { name: '本地上传', id: 1 },
    // { name: '任务同步', id: 2 },
    // { name: '视频库', id: 3 },
    // { name: '视频拼接', id: 4 },
    { name: '媒体同步', id: 5 },
    // { name: '视频混剪', id: 6 },
    // { name: '视频合成', id: 7 },
  ],
  videoPushState: [
    { name: '推送中', id: 1 },
    { name: '推送成功', id: 3 },
    { name: '推送失败', id: 5 },
  ],
  company_type: [
    { name: '服务商', id: 'supplier' },
    { name: '客户', id: 'customer' },
  ],
  opt_action: [
    { name: '编辑', id: '编辑' },
    { name: '编辑档期', id: '编辑档期' },
    { name: '编辑视频', id: '编辑视频' },
    { name: '编辑演员成本', id: '编辑演员成本' },
    { name: '发起改视频任务', id: '发起改视频任务' },
    { name: '分配', id: '分配' },
    { name: '复制', id: '复制' },
    { name: '关联用户', id: '关联用户' },
    { name: '加入收藏', id: '加入收藏' },
    { name: '结束任务', id: '结束任务' },
    { name: '录入演员成本', id: '录入演员成本' },
    { name: '评价', id: '评价' },
    { name: '取消', id: '取消' },
    { name: '取消任务', id: '取消任务' },
    { name: '取消收藏', id: '取消收藏' },
    { name: '确认演员', id: '确认演员' },
    { name: '删除档期', id: '删除档期' },
    { name: '删除视频', id: '删除视频' },
    { name: '上传脚本', id: '上传脚本' },
    { name: '上传视频', id: '上传视频' },
    { name: '审核', id: '审核' },
    { name: '添加至素材库', id: '添加至素材库' },
    { name: '推送', id: '推送' },
    { name: '新增', id: '新增' },
    { name: '新增档期', id: '新增档期' },
    { name: '修改评价', id: '修改评价' },
    { name: '重置密码', id: '重置密码' },
  ],
  qcAccountState: [
    { name: '正常', id: 1, color: colors.success },
    { name: '失效', id: 2, color: colors.error },
  ],
  qcSyncAccountType: [
    { id: 'CUSTOMER_ADMIN', name: '管家-管理员' },
    { id: 'AGENT', name: '代理商' },
    { id: 'CHILD_AGENT', name: '二级代理商' },
    { id: 'CUSTOMER_OPERATOR', name: '管家-操作者' },
    { id: 'PLATFORM_ROLE_QIANCHUAN_AGENT', name: '千川代理商' },
    { id: 'PLATFORM_ROLE_SHOP_ACCOUNT', name: '千川店铺' },
  ],
  qcIsPull: [
    { name: '开启', id: 1 },
    { name: '关闭', id: -1 },
  ],
  rolePermission: [
    { id: 1, name: '个人' },
    { id: 3, name: '部门' },
    { id: 5, name: '公司' },
  ],
  companyDict: [{ id: 1, name: 'xiusin' }],
  positionDict: [
    {
      id: 1,
      name: '库房',
    },
    {
      id: 2,
      name: '1号直播间',
    },
    {
      id: 3,
      name: '2号直播间',
    },
  ],
  demandLiveRoom: [
    {
      id: 1,
      name: '库房',
    },
    {
      id: 2,
      name: '1号直播间',
    },
    {
      id: 3,
      name: '2号直播间',
    },
    {
      id: 4,
      name: '/',
    },
  ],
  productStatus: [
    {
      id: 1,
      name: '库存中',
    },
    {
      id: 2,
      name: '上架中',
    },
  ],
  shelvePlatforms: [
    {
      id: 1,
      name: 'APP',
    },
    {
      id: 2,
      name: '抖店',
    },
    {
      id: 3,
      name: 'APP + 抖店',
    },
  ],
  departmentDict: [{ id: 1, name: '实物电商A部' }],
  flowsDict: [
    {
      id: '101',
      name: '新增货盘需求表',
    },
    {
      id: '102',
      name: '新增提货单',
    },
    {
      id: '103',
      name: '新增成员',
    },
    {
      id: '104',
      name: '新增角色',
    },
    {
      id: '105',
      name: '新增供应商',
    },
    {
      id: '201',
      name: '编辑货盘需求表',
    },
    {
      id: '202',
      name: '编辑寄卖入库',
    },
    {
      id: '203',
      name: '编辑提交入库',
    },
    {
      id: '204',
      name: '出库申请单',
    },
    {
      id: '205',
      name: '配置出库单',
    },
    {
      id: '206',
      name: '编辑商品详情',
    },
    {
      id: '207',
      name: '编辑成员',
    },
    {
      id: '208',
      name: '编辑角色',
    },
    {
      id: '209',
      name: '编辑供应商',
    },
  ],
  saleChannel: [
    { id: 'SALE_CHANNEL_LIVE_ROOM', name: '直播间' },
    { id: 'SALE_CHANNEL_XHS', name: '小红书' },
    { id: 'SALE_CHANNEL_PRIVATE', name: '私域' },
    { id: 'SALE_CHANNEL_PROCURE', name: '采购' },
  ],
};

export default allDict;

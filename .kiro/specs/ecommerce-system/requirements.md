# 商用电商系统需求文档

## 介绍

本文档定义了一个完整的商用电商系统，包含后端管理系统和前端用户系统（小程序 + 微信H5）。系统采用 ZigCMS 架构，遵循整洁架构、DDD 和 ORM 最佳实践，确保高性能、高可用和可扩展性。

系统设计目标：
- 支持多规格商品（SKU）、虚拟商品、CID商品
- 完整的订单生命周期管理（下单、支付、发货、售后）
- 灵活的营销活动（秒杀、拼团、满减、优惠券）
- 可视化主页搭建能力
- 完善的物流和支付对接
- 商用级别的性能和安全性

## 术语表

- **System**: 电商系统（包含后端管理系统和前端用户系统）
- **Admin_System**: 后端管理系统
- **User_System**: 前端用户系统（小程序 + H5）
- **SKU**: 库存量单位（Stock Keeping Unit），商品的最小销售单元
- **SPU**: 标准产品单位（Standard Product Unit），商品的抽象概念
- **Order_Engine**: 订单引擎，负责订单创建、状态流转、拆单等核心逻辑
- **Payment_Gateway**: 支付网关，对接第三方支付平台
- **Logistics_System**: 物流系统，管理物流公司、运费模板、物流跟踪
- **Marketing_Engine**: 营销引擎，管理活动、优惠券、推广等
- **Page_Builder**: 页面构建器，可视化搭建主页和活动页
- **SMS_Service**: 短信服务，发送验证码、通知等
- **After_Sales_System**: 售后系统，处理退款、退货、换货
- **Inventory_System**: 库存系统，管理商品库存、预占、释放
- **User**: 普通用户（买家）
- **Admin**: 管理员
- **Merchant**: 商家
- **Promoter**: 推广员
- **CID_Product**: 淘宝客商品（通过 CID 链路对接）
- **Virtual_Product**: 虚拟商品（如充值卡、会员卡）


## 需求

### 需求 1: 商品管理

**用户故事**: 作为商家，我希望能够管理多规格商品（SKU）、虚拟商品和 CID 商品，以便灵活销售不同类型的商品。

#### 验收标准

1. THE Admin_System SHALL 支持创建 SPU（标准产品单位）
2. WHEN 创建 SPU 时，THE Admin_System SHALL 允许添加多个 SKU（规格）
3. THE Admin_System SHALL 为每个 SKU 存储独立的价格、库存、规格属性
4. THE Admin_System SHALL 支持商品分类（树形结构，最多 3 级）
5. THE Admin_System SHALL 支持商品审核流程（待审核、已通过、已拒绝）
6. WHERE 商品类型为虚拟商品，THE Admin_System SHALL 标记为无需物流
7. WHERE 商品类型为 CID 商品，THE Admin_System SHALL 存储淘宝客链路信息
8. THE Admin_System SHALL 支持商品上下架操作
9. THE Admin_System SHALL 支持批量导入商品（Excel/CSV）
10. THE Admin_System SHALL 支持商品图片上传（主图 + 详情图，最多 10 张）
11. WHEN 商品被删除时，THE Admin_System SHALL 检查是否存在未完成订单
12. IF 商品存在未完成订单，THEN THE Admin_System SHALL 拒绝删除并提示错误
13. THE Admin_System SHALL 记录商品操作日志（创建、修改、删除、上下架）
14. THE Admin_System SHALL 支持商品搜索（按名称、分类、状态）
15. THE Admin_System SHALL 支持商品排序（按销量、价格、创建时间）

**正确性属性**:
- **不变量**: 每个 SKU 的库存数量必须 >= 0
- **不变量**: 商品价格必须 > 0
- **不变量**: 已上架商品必须至少有一个可用 SKU
- **状态机**: 商品状态流转（草稿 → 待审核 → 已通过/已拒绝 → 已上架/已下架）
- **并发安全**: 库存扣减必须使用乐观锁或悲观锁防止超卖


### 需求 2: 订单管理

**用户故事**: 作为用户，我希望能够下单购买商品，并跟踪订单状态，以便完成购物流程。

#### 验收标准

1. WHEN 用户提交订单时，THE Order_Engine SHALL 验证商品库存是否充足
2. IF 库存不足，THEN THE Order_Engine SHALL 返回错误并提示库存不足
3. WHEN 订单创建成功时，THE Order_Engine SHALL 预占库存
4. THE Order_Engine SHALL 生成唯一订单号（格式：年月日时分秒 + 6位随机数）
5. THE Order_Engine SHALL 计算订单总价（商品价格 + 运费 - 优惠）
6. THE Order_Engine SHALL 支持订单状态流转（待支付 → 待发货 → 待收货 → 已完成 → 已关闭）
7. WHEN 订单状态变更时，THE Order_Engine SHALL 记录状态变更时间和操作人
8. THE Order_Engine SHALL 支持订单超时自动关闭（待支付订单 30 分钟未支付）
9. WHEN 订单超时关闭时，THE Order_Engine SHALL 释放预占库存
10. THE Admin_System SHALL 支持订单详情查看（商品信息、用户信息、物流信息）
11. THE Admin_System SHALL 支持订单导出（Excel/CSV）
12. THE Admin_System SHALL 支持订单统计（按日期、状态、金额）
13. THE Admin_System SHALL 支持订单搜索（按订单号、用户、商品、状态）
14. THE Admin_System SHALL 支持手动关闭订单（需填写关闭原因）
15. THE Admin_System SHALL 支持订单备注（管理员备注、用户备注）
16. WHEN 订单包含多个商家商品时，THE Order_Engine SHALL 支持订单拆分
17. THE Order_Engine SHALL 为每个子订单生成独立订单号
18. THE Order_Engine SHALL 记录拆单规则和拆单记录
19. THE User_System SHALL 显示订单状态时间线（下单、支付、发货、收货）
20. THE User_System SHALL 支持订单取消（仅待支付状态）

**正确性属性**:
- **状态机**: 订单状态必须按照定义的流转规则变更
- **不变量**: 订单总价 = 商品价格 + 运费 - 优惠金额
- **不变量**: 已支付订单不可取消（只能申请售后）
- **幂等性**: 订单创建接口必须幂等（防止重复下单）
- **事务性**: 订单创建、库存扣减、优惠券核销必须在同一事务中
- **并发安全**: 库存扣减必须防止超卖


### 需求 3: 支付管理

**用户故事**: 作为用户，我希望能够使用微信支付或支付宝支付订单，以便完成购买。

#### 验收标准

1. THE Payment_Gateway SHALL 支持微信支付（JSAPI、H5、小程序）
2. THE Payment_Gateway SHALL 支持支付宝支付（网页支付、手机网站支付）
3. THE Admin_System SHALL 支持配置支付参数（商户号、密钥、证书）
4. WHEN 用户发起支付时，THE Payment_Gateway SHALL 调用第三方支付接口
5. THE Payment_Gateway SHALL 生成唯一支付流水号
6. THE Payment_Gateway SHALL 记录支付请求参数和响应结果
7. WHEN 支付成功时，THE Payment_Gateway SHALL 接收支付回调通知
8. THE Payment_Gateway SHALL 验证回调签名的有效性
9. IF 签名无效，THEN THE Payment_Gateway SHALL 拒绝回调并记录日志
10. WHEN 回调验证通过时，THE Payment_Gateway SHALL 更新订单支付状态
11. THE Payment_Gateway SHALL 确保回调处理的幂等性（防止重复处理）
12. THE Payment_Gateway SHALL 支持支付超时处理（30 分钟未支付自动关闭）
13. THE Admin_System SHALL 支持查看支付记录（订单号、支付方式、支付时间、金额）
14. THE Admin_System SHALL 支持支付记录导出
15. THE Admin_System SHALL 支持支付异常处理（支付失败、支付超时）
16. THE Payment_Gateway SHALL 支持退款操作（全额退款、部分退款）
17. WHEN 退款成功时，THE Payment_Gateway SHALL 更新订单退款状态
18. THE Payment_Gateway SHALL 记录退款流水和退款原因

**正确性属性**:
- **幂等性**: 支付回调处理必须幂等（同一笔支付只处理一次）
- **原子性**: 支付状态更新和订单状态更新必须在同一事务中
- **安全性**: 支付回调必须验证签名（防止伪造回调）
- **一致性**: 支付金额必须与订单金额一致
- **可追溯性**: 所有支付操作必须记录日志


### 需求 4: 物流管理

**用户故事**: 作为商家，我希望能够管理物流公司和运费模板，并跟踪订单物流信息，以便高效配送商品。

#### 验收标准

1. THE Admin_System SHALL 支持添加物流公司（名称、编码、官网、客服电话）
2. THE Admin_System SHALL 支持启用/禁用物流公司
3. THE Admin_System SHALL 支持创建运费模板（按重量、按件数、按体积）
4. THE Admin_System SHALL 支持运费模板配置（首重/首件、续重/续件、运费）
5. THE Admin_System SHALL 支持运费模板区域配置（指定省市区）
6. THE Admin_System SHALL 支持包邮规则配置（满额包邮、指定区域包邮）
7. WHEN 用户下单时，THE Logistics_System SHALL 根据运费模板计算运费
8. THE Logistics_System SHALL 根据收货地址匹配运费模板
9. IF 无匹配模板，THEN THE Logistics_System SHALL 使用默认运费
10. WHEN 订单发货时，THE Admin_System SHALL 填写物流单号和物流公司
11. THE Logistics_System SHALL 调用第三方物流接口查询物流进度
12. THE Logistics_System SHALL 缓存物流查询结果（5 分钟）
13. THE User_System SHALL 显示物流进度时间线（已揽收、运输中、派送中、已签收）
14. THE Logistics_System SHALL 支持物流异常提醒（超时未签收、退回）
15. THE Admin_System SHALL 支持批量发货（Excel 导入）
16. THE Admin_System SHALL 支持物流跟踪记录查询
17. WHERE 商品为虚拟商品，THE Logistics_System SHALL 跳过物流流程

**正确性属性**:
- **不变量**: 运费必须 >= 0
- **不变量**: 虚拟商品运费为 0
- **一致性**: 运费计算结果必须与运费模板规则一致
- **缓存策略**: 物流查询结果缓存 5 分钟（减少第三方接口调用）


### 需求 5: 售后管理

**用户故事**: 作为用户，我希望能够申请退款、退货或换货，并跟踪售后进度，以便解决商品问题。

#### 验收标准

1. THE User_System SHALL 支持申请售后（退款、退货、换货）
2. THE User_System SHALL 要求用户选择售后原因（质量问题、描述不符、不想要了等）
3. THE User_System SHALL 支持上传售后凭证（图片、视频，最多 9 张）
4. WHEN 用户申请售后时，THE After_Sales_System SHALL 创建售后工单
5. THE After_Sales_System SHALL 生成唯一售后单号
6. THE After_Sales_System SHALL 支持售后状态流转（待审核 → 已通过/已拒绝 → 退货中 → 已完成）
7. THE Admin_System SHALL 支持审核售后申请（通过、拒绝、要求补充信息）
8. WHEN 售后审核通过时，THE Admin_System SHALL 通知用户（短信/站内信）
9. WHERE 售后类型为退货，THE After_Sales_System SHALL 要求用户填写退货物流信息
10. WHEN 商家收到退货时，THE Admin_System SHALL 确认收货并处理退款
11. THE After_Sales_System SHALL 调用 Payment_Gateway 执行退款操作
12. WHEN 退款成功时，THE After_Sales_System SHALL 更新售后状态为已完成
13. WHERE 售后类型为换货，THE After_Sales_System SHALL 创建换货订单
14. THE Admin_System SHALL 支持售后工单列表查询（按状态、时间、用户）
15. THE Admin_System SHALL 支持售后统计（按原因、类型、时间）
16. THE User_System SHALL 显示售后进度时间线
17. THE After_Sales_System SHALL 支持售后超时自动处理（7 天未处理自动通过）
18. THE After_Sales_System SHALL 记录售后操作日志

**正确性属性**:
- **状态机**: 售后状态必须按照定义的流转规则变更
- **不变量**: 退款金额不能超过订单实付金额
- **不变量**: 已完成订单 7 天内可申请售后
- **幂等性**: 退款操作必须幂等（防止重复退款）
- **事务性**: 退款和订单状态更新必须在同一事务中


### 需求 6: 营销活动管理

**用户故事**: 作为商家，我希望能够创建营销活动（秒杀、拼团、满减、限时折扣），以便促进商品销售。

#### 验收标准

1. THE Admin_System SHALL 支持创建秒杀活动（活动名称、开始时间、结束时间、商品、秒杀价）
2. THE Admin_System SHALL 支持创建拼团活动（成团人数、拼团价、拼团时限）
3. THE Admin_System SHALL 支持创建满减活动（满减规则、适用商品、适用用户）
4. THE Admin_System SHALL 支持创建限时折扣活动（折扣比例、开始时间、结束时间）
5. THE Marketing_Engine SHALL 验证活动时间的有效性（开始时间 < 结束时间）
6. THE Marketing_Engine SHALL 验证活动商品的有效性（商品已上架、库存充足）
7. WHEN 秒杀活动开始时，THE Marketing_Engine SHALL 预热活动商品库存
8. WHEN 用户参与秒杀时，THE Marketing_Engine SHALL 使用分布式锁防止超卖
9. THE Marketing_Engine SHALL 限制每个用户的秒杀购买数量
10. WHEN 用户发起拼团时，THE Marketing_Engine SHALL 创建拼团记录
11. THE Marketing_Engine SHALL 支持用户参与他人拼团
12. WHEN 拼团成功时，THE Marketing_Engine SHALL 自动创建订单
13. WHEN 拼团失败时，THE Marketing_Engine SHALL 退还预付款
14. THE Marketing_Engine SHALL 支持满减规则计算（满 100 减 10、满 200 减 30）
15. THE Marketing_Engine SHALL 支持满减规则叠加（多个满减规则同时生效）
16. THE Admin_System SHALL 支持活动数据统计（参与人数、成交金额、转化率）
17. THE Admin_System SHALL 支持活动上下架操作
18. THE User_System SHALL 显示活动倒计时
19. THE User_System SHALL 显示活动商品标签（秒杀、拼团、限时折扣）

**正确性属性**:
- **并发安全**: 秒杀库存扣减必须使用分布式锁（Redis）
- **不变量**: 秒杀价必须 < 原价
- **不变量**: 拼团价必须 < 原价
- **不变量**: 折扣比例必须在 0-100 之间
- **状态机**: 拼团状态流转（拼团中 → 拼团成功/拼团失败）
- **超时处理**: 拼团超时自动失败并退款


### 需求 7: 优惠券管理

**用户故事**: 作为商家，我希望能够创建和发放优惠券，以便吸引用户购买。

#### 验收标准

1. THE Admin_System SHALL 支持创建优惠券（满减券、折扣券、兑换券）
2. THE Admin_System SHALL 支持配置优惠券规则（满减金额、折扣比例、使用门槛）
3. THE Admin_System SHALL 支持配置优惠券有效期（开始时间、结束时间）
4. THE Admin_System SHALL 支持配置优惠券发放数量（总量、每人限领）
5. THE Admin_System SHALL 支持配置优惠券适用范围（全场、指定分类、指定商品）
6. THE Admin_System SHALL 支持优惠券发放方式（手动发放、自动发放、领取码）
7. WHEN 用户领取优惠券时，THE Marketing_Engine SHALL 验证领取资格
8. THE Marketing_Engine SHALL 验证优惠券库存是否充足
9. IF 库存不足，THEN THE Marketing_Engine SHALL 返回错误提示
10. THE Marketing_Engine SHALL 记录用户领取记录（用户ID、优惠券ID、领取时间）
11. WHEN 用户下单时，THE Marketing_Engine SHALL 自动匹配可用优惠券
12. THE Marketing_Engine SHALL 计算优惠券优惠金额
13. WHEN 订单支付成功时，THE Marketing_Engine SHALL 核销优惠券
14. THE Marketing_Engine SHALL 标记优惠券为已使用状态
15. WHEN 订单取消时，THE Marketing_Engine SHALL 退还优惠券
16. THE Admin_System SHALL 支持优惠券使用统计（领取数量、使用数量、核销率）
17. THE User_System SHALL 显示用户优惠券列表（未使用、已使用、已过期）
18. THE User_System SHALL 支持优惠券筛选（按状态、按类型）

**正确性属性**:
- **并发安全**: 优惠券领取必须使用分布式锁防止超领
- **不变量**: 优惠券使用数量不能超过发放数量
- **不变量**: 优惠券优惠金额不能超过订单金额
- **幂等性**: 优惠券核销必须幂等（防止重复核销）
- **状态机**: 优惠券状态流转（未使用 → 已使用/已过期）


### 需求 8: 短信管理

**用户故事**: 作为系统，我希望能够发送短信通知用户，以便及时告知订单状态、验证码等信息。

#### 验收标准

1. THE Admin_System SHALL 支持配置短信服务商（阿里云、腾讯云）
2. THE Admin_System SHALL 支持配置短信参数（AccessKey、SecretKey、签名）
3. THE Admin_System SHALL 支持创建短信模板（验证码、订单通知、活动通知）
4. THE Admin_System SHALL 支持配置短信签名
5. THE Admin_System SHALL 支持配置发送场景（注册、登录、下单、发货、售后）
6. WHEN 触发发送场景时，THE SMS_Service SHALL 自动发送短信
7. THE SMS_Service SHALL 调用第三方短信接口发送短信
8. THE SMS_Service SHALL 记录发送日志（手机号、模板、参数、发送时间、发送结果）
9. THE SMS_Service SHALL 支持发送失败重试（最多 3 次）
10. THE SMS_Service SHALL 支持发送频率限制（同一手机号 1 分钟内最多 1 条）
11. THE SMS_Service SHALL 支持发送数量限制（同一手机号每天最多 10 条）
12. IF 超过频率限制，THEN THE SMS_Service SHALL 拒绝发送并返回错误
13. THE Admin_System SHALL 支持查看发送日志（按手机号、模板、时间、状态）
14. THE Admin_System SHALL 支持发送统计（发送总量、成功率、失败原因）
15. THE SMS_Service SHALL 支持短信验证码验证（验证码有效期 5 分钟）
16. THE SMS_Service SHALL 支持验证码错误次数限制（最多 5 次）

**正确性属性**:
- **频率限制**: 同一手机号 1 分钟内最多发送 1 条短信
- **数量限制**: 同一手机号每天最多发送 10 条短信
- **有效期**: 验证码有效期 5 分钟
- **错误次数**: 验证码最多验证 5 次
- **幂等性**: 短信发送接口必须幂等（防止重复发送）


### 需求 9: 可视化页面搭建

**用户故事**: 作为商家，我希望能够可视化搭建商城主页和活动页，以便灵活展示商品和活动。

#### 验收标准

1. THE Admin_System SHALL 提供可视化页面编辑器（拖拽式）
2. THE Page_Builder SHALL 支持组件库（轮播图、商品列表、分类导航、优惠券、公告）
3. THE Page_Builder SHALL 支持组件拖拽添加到页面
4. THE Page_Builder SHALL 支持组件属性配置（标题、图片、链接、样式）
5. THE Page_Builder SHALL 支持组件排序（上移、下移、置顶、置底）
6. THE Page_Builder SHALL 支持组件复制和删除
7. THE Page_Builder SHALL 支持页面预览（实时预览）
8. THE Page_Builder SHALL 支持页面保存和发布
9. THE Page_Builder SHALL 支持页面版本管理（草稿、已发布）
10. THE Page_Builder SHALL 支持页面模板（预设模板、自定义模板）
11. THE Page_Builder SHALL 支持主题配置（主色调、辅助色、字体）
12. THE User_System SHALL 根据页面配置渲染主页
13. THE User_System SHALL 支持组件懒加载（提升性能）
14. THE Page_Builder SHALL 支持移动端适配（响应式布局）
15. THE Page_Builder SHALL 支持页面数据统计（访问量、点击量、转化率）

**正确性属性**:
- **不变量**: 页面必须至少包含一个组件
- **不变量**: 轮播图组件至少包含 1 张图片
- **一致性**: 页面配置和渲染结果必须一致
- **性能**: 页面加载时间不超过 2 秒


### 需求 10: 评论管理

**用户故事**: 作为用户，我希望能够对购买的商品进行评价，并查看其他用户的评价，以便做出购买决策。

#### 验收标准

1. WHEN 订单完成后，THE User_System SHALL 允许用户评价商品
2. THE User_System SHALL 支持评分（1-5 星）
3. THE User_System SHALL 支持评论内容（文字、图片、视频）
4. THE User_System SHALL 支持匿名评价
5. THE User_System SHALL 支持追加评价（首次评价后 30 天内）
6. WHEN 用户提交评价时，THE System SHALL 创建评论记录
7. THE Admin_System SHALL 支持评论审核（待审核、已通过、已拒绝）
8. THE Admin_System SHALL 支持评论回复（商家回复）
9. THE Admin_System SHALL 支持评论删除（违规评论）
10. THE User_System SHALL 显示商品评论列表（按时间、评分排序）
11. THE User_System SHALL 支持评论筛选（好评、中评、差评、有图）
12. THE User_System SHALL 显示商品评分统计（平均分、好评率）
13. THE System SHALL 计算商品好评率（好评数 / 总评论数）
14. THE Admin_System SHALL 支持评论统计（评论总量、好评率、差评原因）
15. THE System SHALL 支持评论点赞功能

**正确性属性**:
- **不变量**: 评分必须在 1-5 之间
- **不变量**: 只有已完成订单才能评价
- **不变量**: 每个订单每个商品只能评价一次（可追加）
- **一致性**: 商品评分统计必须与评论记录一致


### 需求 11: 推广管理

**用户故事**: 作为推广员，我希望能够推广商品并获得佣金，以便获得收益。

#### 验收标准

1. THE Admin_System SHALL 支持推广员管理（添加、编辑、禁用）
2. THE Admin_System SHALL 支持推广员等级配置（普通、高级、超级）
3. THE Admin_System SHALL 支持佣金比例配置（按等级、按商品）
4. WHEN 用户通过推广链接下单时，THE System SHALL 记录推广关系
5. THE System SHALL 生成唯一推广链接（包含推广员ID）
6. WHEN 订单完成后，THE System SHALL 计算推广佣金
7. THE System SHALL 根据推广员等级和商品佣金比例计算佣金
8. THE System SHALL 记录推广订单（订单号、推广员、佣金金额）
9. THE Admin_System SHALL 支持佣金结算（按月结算、按周结算）
10. THE Admin_System SHALL 支持佣金提现（最低提现金额、提现手续费）
11. THE Admin_System SHALL 支持推广数据统计（推广订单数、推广金额、佣金总额）
12. THE User_System SHALL 显示推广员个人中心（推广订单、佣金明细、提现记录）
13. THE System SHALL 支持二级分销（推广员推广推广员）
14. THE System SHALL 支持推广素材管理（推广图片、推广文案）

**正确性属性**:
- **不变量**: 佣金比例必须在 0-100% 之间
- **不变量**: 佣金金额不能超过订单金额
- **一致性**: 佣金计算结果必须与佣金规则一致
- **可追溯性**: 所有推广订单必须记录推广关系


### 需求 12: 淘宝客管理

**用户故事**: 作为商家，我希望能够对接淘宝客商品，以便扩展商品来源。

#### 验收标准

1. THE Admin_System SHALL 支持配置淘宝客 API 参数（AppKey、AppSecret）
2. THE Admin_System SHALL 支持搜索淘宝客商品（按关键词、分类）
3. THE Admin_System SHALL 支持导入淘宝客商品（批量导入）
4. THE System SHALL 存储淘宝客商品链路信息（CID、优惠券链接）
5. THE System SHALL 标记淘宝客商品类型（区别于自营商品）
6. WHEN 用户点击淘宝客商品时，THE System SHALL 生成推广链接
7. THE System SHALL 跳转到淘宝客商品详情页
8. THE System SHALL 记录淘宝客商品点击量
9. THE Admin_System SHALL 支持淘宝客佣金配置
10. THE Admin_System SHALL 支持淘宝客订单同步（定时同步）
11. THE Admin_System SHALL 支持淘宝客佣金结算
12. THE Admin_System SHALL 支持淘宝客数据统计（点击量、成交量、佣金）

**正确性属性**:
- **一致性**: 淘宝客商品信息必须与淘宝平台一致
- **可追溯性**: 所有淘宝客订单必须记录 CID 链路
- **同步频率**: 淘宝客订单每小时同步一次


### 需求 13: 广告管理

**用户故事**: 作为商家，我希望能够管理广告位和广告投放，以便推广商品和活动。

#### 验收标准

1. THE Admin_System SHALL 支持创建广告位（首页轮播、分类页、详情页）
2. THE Admin_System SHALL 支持配置广告位尺寸和位置
3. THE Admin_System SHALL 支持创建广告（图片、链接、开始时间、结束时间）
4. THE Admin_System SHALL 支持广告排序（按优先级）
5. THE Admin_System SHALL 支持广告上下架操作
6. WHEN 广告到期时，THE System SHALL 自动下架广告
7. THE User_System SHALL 根据广告位配置显示广告
8. THE System SHALL 记录广告点击量
9. THE Admin_System SHALL 支持广告数据统计（展示量、点击量、点击率）
10. THE Admin_System SHALL 支持推广商品配置（推荐商品、热销商品）
11. THE System SHALL 支持广告 A/B 测试（多个广告轮播）

**正确性属性**:
- **不变量**: 广告开始时间必须 < 结束时间
- **一致性**: 广告展示必须在有效期内
- **性能**: 广告加载不影响页面性能


### 需求 14: 销售统计

**用户故事**: 作为商家，我希望能够查看销售统计数据，以便分析经营状况。

#### 验收标准

1. THE Admin_System SHALL 支持销售报表（按日、按周、按月）
2. THE Admin_System SHALL 显示销售总额、订单数量、客单价
3. THE Admin_System SHALL 显示商品销量排行（TOP 10）
4. THE Admin_System SHALL 显示用户消费排行（TOP 10）
5. THE Admin_System SHALL 显示分类销售占比（饼图）
6. THE Admin_System SHALL 显示销售趋势图（折线图）
7. THE Admin_System SHALL 支持数据导出（Excel/CSV）
8. THE Admin_System SHALL 支持自定义时间范围查询
9. THE Admin_System SHALL 显示退款率、售后率
10. THE Admin_System SHALL 显示新增用户数、活跃用户数
11. THE Admin_System SHALL 支持实时数据刷新（每 5 分钟）

**正确性属性**:
- **一致性**: 统计数据必须与订单数据一致
- **性能**: 统计查询响应时间不超过 3 秒
- **缓存策略**: 统计数据缓存 5 分钟


### 需求 15: 用户系统（小程序 + H5）

**用户故事**: 作为用户，我希望能够在小程序或 H5 上浏览商品、下单购买、管理订单，以便完成购物。

#### 验收标准

1. THE User_System SHALL 支持用户注册（手机号 + 验证码）
2. THE User_System SHALL 支持用户登录（手机号 + 密码、微信授权）
3. THE User_System SHALL 支持用户信息管理（头像、昵称、性别）
4. THE User_System SHALL 显示商城主页（根据 Page_Builder 配置）
5. THE User_System SHALL 支持商品搜索（按名称、分类）
6. THE User_System SHALL 支持商品筛选（按价格、销量、评分）
7. THE User_System SHALL 显示商品详情（图片、价格、规格、评论）
8. THE User_System SHALL 支持 SKU 选择（规格、数量）
9. THE User_System SHALL 支持加入购物车
10. THE User_System SHALL 显示购物车列表（商品、数量、价格）
11. THE User_System SHALL 支持购物车编辑（修改数量、删除商品）
12. THE User_System SHALL 支持批量操作（全选、删除）
13. THE User_System SHALL 支持提交订单（选择地址、选择优惠券、填写备注）
14. THE User_System SHALL 显示订单确认页（商品、价格、运费、优惠）
15. THE User_System SHALL 支持订单支付（微信支付、支付宝）
16. THE User_System SHALL 显示订单列表（全部、待支付、待发货、待收货、已完成）
17. THE User_System SHALL 显示订单详情（商品、物流、状态时间线）
18. THE User_System SHALL 支持订单取消（待支付状态）
19. THE User_System SHALL 支持确认收货
20. THE User_System SHALL 支持申请售后（退款、退货、换货）
21. THE User_System SHALL 显示个人中心（订单、优惠券、收藏、地址）
22. THE User_System SHALL 支持地址管理（新增、编辑、删除、设为默认）
23. THE User_System SHALL 支持商品收藏
24. THE User_System SHALL 支持浏览历史记录
25. THE User_System SHALL 采用奈雪的茶风格设计（粉色系、清新风格）

**正确性属性**:
- **性能**: 页面加载时间不超过 2 秒
- **兼容性**: 支持微信小程序、微信 H5
- **响应式**: 适配不同屏幕尺寸
- **用户体验**: 流畅的交互、清晰的提示


### 需求 16: 库存管理

**用户故事**: 作为系统，我希望能够准确管理商品库存，防止超卖，以便保证订单履约。

#### 验收标准

1. THE Inventory_System SHALL 为每个 SKU 维护独立库存
2. THE Inventory_System SHALL 支持库存预占（下单时预占，支付后扣减）
3. THE Inventory_System SHALL 支持库存释放（订单取消、超时未支付）
4. WHEN 用户下单时，THE Inventory_System SHALL 使用分布式锁防止超卖
5. THE Inventory_System SHALL 使用乐观锁更新库存（基于版本号）
6. IF 库存扣减失败，THEN THE Inventory_System SHALL 返回库存不足错误
7. THE Inventory_System SHALL 支持库存预警（库存低于阈值时通知）
8. THE Admin_System SHALL 支持手动调整库存（入库、出库、盘点）
9. THE Admin_System SHALL 记录库存变更日志（操作人、操作时间、变更数量、变更原因）
10. THE Inventory_System SHALL 支持库存同步（定时同步、实时同步）
11. THE Admin_System SHALL 支持库存统计（总库存、可用库存、预占库存）
12. THE Inventory_System SHALL 支持安全库存配置（最低库存、最高库存）

**正确性属性**:
- **并发安全**: 库存扣减必须使用分布式锁（Redis）+ 乐观锁（版本号）
- **不变量**: 可用库存 = 总库存 - 预占库存 - 已售库存
- **不变量**: 库存数量必须 >= 0
- **一致性**: 库存变更必须与订单状态一致
- **可追溯性**: 所有库存变更必须记录日志


### 需求 17: 订单拆单

**用户故事**: 作为系统，我希望能够自动拆分订单，以便支持多商家、多仓库发货。

#### 验收标准

1. THE Order_Engine SHALL 支持配置拆单规则（按商家、按仓库、按商品类型）
2. WHEN 订单包含多个商家商品时，THE Order_Engine SHALL 按商家拆分订单
3. WHEN 订单包含多个仓库商品时，THE Order_Engine SHALL 按仓库拆分订单
4. WHEN 订单包含虚拟商品和实物商品时，THE Order_Engine SHALL 按商品类型拆分
5. THE Order_Engine SHALL 为每个子订单生成独立订单号
6. THE Order_Engine SHALL 保留主订单号（用于关联子订单）
7. THE Order_Engine SHALL 分摊订单优惠金额到子订单
8. THE Order_Engine SHALL 分摊运费到子订单
9. THE Order_Engine SHALL 记录拆单规则和拆单记录
10. THE Admin_System SHALL 支持查看拆单记录（主订单、子订单、拆单规则）
11. THE User_System SHALL 显示主订单和子订单关系
12. THE Order_Engine SHALL 支持子订单独立发货
13. THE Order_Engine SHALL 支持子订单独立售后

**正确性属性**:
- **不变量**: 子订单总金额 = 主订单总金额
- **不变量**: 子订单商品数量 = 主订单商品数量
- **一致性**: 拆单后的订单状态必须与主订单状态一致
- **原子性**: 拆单操作必须在同一事务中完成


### 需求 18: 系统安全与性能

**用户故事**: 作为系统，我希望能够保证系统安全和高性能，以便支持商用级别的业务。

#### 验收标准

1. THE System SHALL 使用参数化查询防止 SQL 注入
2. THE System SHALL 使用 HTTPS 加密传输数据
3. THE System SHALL 使用 JWT 进行用户认证
4. THE System SHALL 使用 RBAC 进行权限控制
5. THE System SHALL 对敏感数据加密存储（密码、支付信息）
6. THE System SHALL 记录操作日志（用户操作、系统操作）
7. THE System SHALL 支持接口限流（防止恶意请求）
8. THE System SHALL 支持接口防重放（基于时间戳 + 签名）
9. THE System SHALL 使用 Redis 缓存热点数据（商品、分类、配置）
10. THE System SHALL 使用 CDN 加速静态资源（图片、CSS、JS）
11. THE System SHALL 使用数据库读写分离（主从复制）
12. THE System SHALL 使用数据库索引优化查询性能
13. THE System SHALL 使用消息队列处理异步任务（订单通知、短信发送）
14. THE System SHALL 支持水平扩展（多实例部署）
15. THE System SHALL 支持服务降级（高峰期降级非核心功能）
16. THE System SHALL 支持熔断机制（第三方服务异常时熔断）
17. THE System SHALL 支持健康检查（定时检查服务状态）
18. THE System SHALL 支持监控告警（CPU、内存、磁盘、接口响应时间）

**正确性属性**:
- **安全性**: 所有 SQL 查询必须使用参数化查询
- **安全性**: 所有敏感数据必须加密存储
- **性能**: 接口响应时间 P95 不超过 500ms
- **性能**: 数据库查询响应时间不超过 100ms
- **可用性**: 系统可用性 99.9%
- **并发**: 支持 1000 QPS


### 需求 19: 数据解析与序列化

**用户故事**: 作为系统，我希望能够正确解析和序列化数据，以便保证数据的完整性和一致性。

#### 验收标准

1. THE System SHALL 提供 JSON 解析器（Parser）
2. THE System SHALL 提供 JSON 序列化器（Pretty_Printer）
3. WHEN 接收 JSON 数据时，THE Parser SHALL 验证 JSON 格式的有效性
4. IF JSON 格式无效，THEN THE Parser SHALL 返回描述性错误信息
5. THE Parser SHALL 解析 JSON 数据为内部数据结构
6. THE Pretty_Printer SHALL 将内部数据结构格式化为 JSON 字符串
7. FOR ALL 有效的数据对象，THE System SHALL 满足往返属性（parse → print → parse 产生等价对象）
8. THE System SHALL 提供 XML 解析器（用于支付回调）
9. THE System SHALL 提供 XML 序列化器
10. FOR ALL 有效的 XML 数据，THE System SHALL 满足往返属性
11. THE System SHALL 验证数据类型的正确性（字符串、数字、布尔、数组、对象）
12. THE System SHALL 验证必填字段的存在性
13. THE System SHALL 验证数据范围的有效性（最小值、最大值、长度）

**正确性属性**:
- **往返属性**: parse(print(x)) == x（JSON、XML）
- **不变量**: 解析后的数据类型必须与定义一致
- **错误处理**: 解析失败必须返回描述性错误信息
- **性能**: JSON 解析性能不低于标准库


## 全局约束

### 架构约束

1. 后端必须基于 ZigCMS 架构（整洁架构 + DDD + ORM）
2. 必须遵循职责分层（domain、application、infrastructure、api）
3. 所有数据库操作必须使用 ORM/QueryBuilder（禁止 rawExec）
4. 所有 SQL 查询必须使用参数化查询（防止 SQL 注入）
5. 必须使用 DI 容器管理依赖
6. 必须使用关系预加载解决 N+1 查询问题

### 内存管理约束

1. 所有 ORM 查询结果必须使用 `defer freeModels()` 释放
2. 跨作用域使用字符串必须深拷贝（`allocator.dupe()`）
3. 推荐使用 Arena Allocator 简化批量内存管理
4. 全局资源（数据库连接、缓存连接）由系统级管理，应用层不得擅自销毁

### 性能约束

1. 接口响应时间 P95 不超过 500ms
2. 数据库查询响应时间不超过 100ms
3. 页面加载时间不超过 2 秒
4. 支持 1000 QPS 并发
5. 热点数据必须缓存（Redis，TTL 5-30 分钟）

### 安全约束

1. 所有 SQL 查询必须使用参数化查询
2. 所有敏感数据必须加密存储（密码使用 bcrypt，支付信息使用 AES）
3. 所有接口必须进行权限验证
4. 所有外部输入必须进行校验和过滤
5. 支付回调必须验证签名

### 数据一致性约束

1. 订单创建、库存扣减、优惠券核销必须在同一事务中
2. 支付状态更新和订单状态更新必须在同一事务中
3. 退款和订单状态更新必须在同一事务中
4. 拆单操作必须在同一事务中

### 并发安全约束

1. 库存扣减必须使用分布式锁（Redis）+ 乐观锁（版本号）
2. 秒杀库存扣减必须使用分布式锁
3. 优惠券领取必须使用分布式锁
4. 支付回调处理必须幂等

### 测试约束

1. 所有核心业务逻辑必须有单元测试
2. 所有接口必须有集成测试
3. 所有解析器必须有往返属性测试（parse → print → parse）
4. 所有状态机必须有状态流转测试
5. 所有并发场景必须有压力测试


## 技术栈

### 后端技术栈

- **语言**: Zig 0.13.0+
- **框架**: ZigCMS（整洁架构 + DDD）
- **数据库**: SQLite（开发）/ MySQL 8.0+（生产）
- **ORM**: ZigCMS ORM（支持关系预加载、参数化查询）
- **缓存**: Redis 6.0+
- **消息队列**: Redis Stream / RabbitMQ
- **支付**: 微信支付 V3、支付宝开放平台
- **短信**: 阿里云短信、腾讯云短信
- **物流**: 快递鸟、快递100
- **对象存储**: 阿里云 OSS、腾讯云 COS

### 前端技术栈（管理后台）

- **框架**: Vue 3.3+
- **语言**: TypeScript 5.0+
- **构建工具**: Vite 4.0+
- **UI 组件库**: Element Plus 2.3+
- **状态管理**: Pinia
- **路由**: Vue Router 4.0+
- **HTTP 客户端**: Axios
- **图表**: ECharts 5.0+
- **富文本编辑器**: TinyMCE / WangEditor
- **页面构建器**: 自研拖拽式编辑器

### 前端技术栈（小程序）

- **框架**: 微信小程序原生 / Taro 3.0+
- **语言**: TypeScript
- **UI 组件库**: Vant Weapp / Taro UI
- **状态管理**: Pinia / Zustand
- **HTTP 客户端**: wx.request / Axios

### 前端技术栈（H5）

- **框架**: Vue 3.3+
- **语言**: TypeScript 5.0+
- **构建工具**: Vite 4.0+
- **UI 组件库**: Vant 4.0+
- **状态管理**: Pinia
- **路由**: Vue Router 4.0+
- **HTTP 客户端**: Axios

### 设计风格

- **主色调**: 粉色系（参考奈雪的茶）
  - 主色: #FF6B9D（粉红色）
  - 辅助色: #FFB6C1（浅粉色）
  - 背景色: #FFF5F7（淡粉色）
- **字体**: 苹方、微软雅黑
- **风格**: 清新、简约、温馨

### 开发工具

- **IDE**: VS Code / Zed
- **版本控制**: Git
- **接口文档**: Swagger / Apifox
- **接口测试**: Postman / Apifox
- **数据库管理**: DBeaver / Navicat
- **Redis 管理**: RedisInsight / AnotherRedisDesktopManager


## 数据库设计要点

### 核心表结构

1. **商品表（products）**
   - id, spu_id, name, category_id, type（实物/虚拟/CID）, status, created_at, updated_at

2. **SKU 表（product_skus）**
   - id, product_id, sku_code, price, stock, attrs（JSON）, created_at, updated_at

3. **订单表（orders）**
   - id, order_no, user_id, status, total_amount, paid_amount, created_at, updated_at

4. **订单商品表（order_items）**
   - id, order_id, product_id, sku_id, quantity, price, total_amount

5. **库存表（inventories）**
   - id, sku_id, total_stock, available_stock, locked_stock, version（乐观锁）

6. **支付记录表（payments）**
   - id, order_id, payment_no, payment_method, amount, status, callback_data（JSON）

7. **物流表（logistics）**
   - id, order_id, logistics_company, tracking_no, status, created_at, updated_at

8. **售后表（after_sales）**
   - id, order_id, type（退款/退货/换货）, reason, status, created_at, updated_at

9. **优惠券表（coupons）**
   - id, name, type, discount_amount, min_amount, total_count, used_count, start_at, end_at

10. **用户优惠券表（user_coupons）**
    - id, user_id, coupon_id, status（未使用/已使用/已过期）, used_at

### 索引设计

- 订单表：order_no（唯一索引）、user_id + status（复合索引）
- SKU 表：product_id（普通索引）、sku_code（唯一索引）
- 库存表：sku_id（唯一索引）
- 支付记录表：order_id（普通索引）、payment_no（唯一索引）
- 物流表：order_id（普通索引）、tracking_no（普通索引）

### 分表策略

- 订单表：按月分表（orders_202401、orders_202402）
- 订单商品表：按月分表（order_items_202401）
- 支付记录表：按月分表（payments_202401）


## 关键业务流程

### 下单流程

1. 用户选择商品和 SKU，加入购物车
2. 用户提交订单，选择收货地址、优惠券
3. 系统验证商品库存、优惠券有效性
4. 系统计算订单金额（商品价格 + 运费 - 优惠）
5. 系统预占库存、锁定优惠券
6. 系统创建订单（状态：待支付）
7. 用户发起支付
8. 支付成功后，系统更新订单状态（待发货）
9. 系统扣减库存、核销优惠券
10. 系统发送订单通知（短信/站内信）

### 发货流程

1. 商家在后台填写物流单号和物流公司
2. 系统更新订单状态（待收货）
3. 系统调用物流接口查询物流进度
4. 系统发送发货通知（短信/站内信）
5. 用户查看物流进度
6. 用户确认收货
7. 系统更新订单状态（已完成）

### 售后流程

1. 用户申请售后（退款/退货/换货）
2. 系统创建售后工单（状态：待审核）
3. 商家审核售后申请
4. 审核通过后，用户填写退货物流信息（退货/换货）
5. 商家确认收货
6. 系统执行退款操作
7. 退款成功后，系统更新售后状态（已完成）
8. 系统发送售后通知（短信/站内信）

### 秒杀流程

1. 商家创建秒杀活动
2. 系统预热秒杀商品库存（Redis）
3. 秒杀开始，用户点击秒杀按钮
4. 系统使用分布式锁防止超卖
5. 系统扣减 Redis 库存
6. 系统创建订单（状态：待支付）
7. 用户支付成功后，系统扣减数据库库存
8. 支付超时后，系统释放 Redis 库存

### 拼团流程

1. 商家创建拼团活动
2. 用户发起拼团（成为团长）
3. 系统创建拼团记录（状态：拼团中）
4. 其他用户参与拼团
5. 拼团成功后，系统自动创建订单
6. 拼团失败后，系统退还预付款


## 状态机定义

### 订单状态机

```
待支付 → 待发货 → 待收货 → 已完成
   ↓         ↓         ↓
 已关闭   已关闭   已关闭
```

状态流转规则：
- 待支付 → 待发货：支付成功
- 待支付 → 已关闭：超时未支付、用户取消
- 待发货 → 待收货：商家发货
- 待发货 → 已关闭：商家取消
- 待收货 → 已完成：用户确认收货、自动确认收货（7 天）
- 待收货 → 已关闭：用户拒收

### 售后状态机

```
待审核 → 已通过 → 退货中 → 已完成
   ↓
已拒绝
```

状态流转规则：
- 待审核 → 已通过：商家审核通过
- 待审核 → 已拒绝：商家审核拒绝
- 已通过 → 退货中：用户填写退货物流（退货/换货）
- 已通过 → 已完成：系统执行退款（仅退款）
- 退货中 → 已完成：商家确认收货并退款

### 拼团状态机

```
拼团中 → 拼团成功
   ↓
拼团失败
```

状态流转规则：
- 拼团中 → 拼团成功：成团人数达到要求
- 拼团中 → 拼团失败：拼团超时

### 商品状态机

```
草稿 → 待审核 → 已通过 → 已上架
              ↓         ↓
           已拒绝   已下架
```

状态流转规则：
- 草稿 → 待审核：商家提交审核
- 待审核 → 已通过：管理员审核通过
- 待审核 → 已拒绝：管理员审核拒绝
- 已通过 → 已上架：商家上架
- 已上架 → 已下架：商家下架、管理员下架


## 接口设计要点

### RESTful API 设计

- GET /api/products - 商品列表
- GET /api/products/:id - 商品详情
- POST /api/products - 创建商品
- PUT /api/products/:id - 更新商品
- DELETE /api/products/:id - 删除商品

- GET /api/orders - 订单列表
- GET /api/orders/:id - 订单详情
- POST /api/orders - 创建订单
- PUT /api/orders/:id/cancel - 取消订单
- PUT /api/orders/:id/confirm - 确认收货

- POST /api/payments/wechat - 微信支付
- POST /api/payments/alipay - 支付宝支付
- POST /api/payments/callback/wechat - 微信支付回调
- POST /api/payments/callback/alipay - 支付宝支付回调

### 响应格式

成功响应：
```json
{
  "code": 0,
  "message": "success",
  "data": { ... }
}
```

错误响应：
```json
{
  "code": 1001,
  "message": "库存不足",
  "data": null
}
```

### 错误码设计

- 0: 成功
- 1001: 库存不足
- 1002: 商品不存在
- 1003: 订单不存在
- 1004: 支付失败
- 1005: 优惠券不可用
- 1006: 权限不足
- 1007: 参数错误
- 1008: 系统错误

### 分页参数

- page: 页码（从 1 开始）
- page_size: 每页数量（默认 20，最大 100）

分页响应：
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "items": [ ... ],
    "total": 100,
    "page": 1,
    "page_size": 20
  }
}
```


## 部署架构

### 开发环境

- 后端：Zig + SQLite + Redis（单机）
- 前端：Vue 3 + Vite（本地开发服务器）
- 小程序：微信开发者工具

### 生产环境

- 负载均衡：Nginx
- 应用服务器：多实例部署（Docker + Kubernetes）
- 数据库：MySQL 主从复制（1 主 2 从）
- 缓存：Redis 哨兵模式（1 主 2 从）
- 消息队列：RabbitMQ 集群
- 对象存储：阿里云 OSS / 腾讯云 COS
- CDN：阿里云 CDN / 腾讯云 CDN
- 监控：Prometheus + Grafana
- 日志：ELK（Elasticsearch + Logstash + Kibana）

### 部署流程

1. 代码提交到 Git 仓库
2. CI/CD 自动构建（GitHub Actions / GitLab CI）
3. 自动化测试（单元测试、集成测试）
4. 构建 Docker 镜像
5. 推送到镜像仓库
6. 部署到 Kubernetes 集群
7. 健康检查
8. 灰度发布（金丝雀发布）

## 项目里程碑

### 第一阶段：核心功能（2 个月）

- 商品管理（SPU、SKU、分类）
- 订单管理（下单、支付、发货）
- 支付管理（微信支付、支付宝）
- 物流管理（物流公司、运费模板）
- 用户系统（注册、登录、个人中心）
- 管理后台（商品管理、订单管理）

### 第二阶段：营销功能（1.5 个月）

- 优惠券管理
- 营销活动（秒杀、拼团、满减）
- 推广管理
- 广告管理
- 可视化页面搭建

### 第三阶段：增值功能（1 个月）

- 售后管理
- 评论管理
- 短信管理
- 淘宝客管理
- 销售统计

### 第四阶段：优化与上线（0.5 个月）

- 性能优化
- 安全加固
- 压力测试
- 灰度发布
- 正式上线

## 总结

本需求文档定义了一个完整的商用电商系统，涵盖了商品管理、订单管理、支付管理、物流管理、售后管理、营销活动、推广管理等核心功能。系统采用 ZigCMS 架构，遵循整洁架构、DDD 和 ORM 最佳实践，确保高性能、高可用和可扩展性。

系统设计严格遵循 EARS 模式和 INCOSE 质量规则，所有需求都具有明确的验收标准和正确性属性，确保系统的逻辑严谨性和商用级别的质量。


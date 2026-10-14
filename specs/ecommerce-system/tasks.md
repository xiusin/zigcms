# 商用电商系统实现任务列表

## 概述

本任务列表基于需求文档和设计文档，将电商系统的实现分解为可执行的任务。任务遵循 ZigCMS 架构规范（domain、application、infrastructure、api 分层），确保代码安全、可维护、高性能。

## 技术栈

- **后端**: Zig + ZigCMS + MySQL + Redis + RabbitMQ
- **前端管理后台**: Vue 3 + TypeScript + Element Plus
- **小程序**: 微信小程序原生 + Vant Weapp（奈雪的茶风格）
- **H5**: Vue 3 + Vant

## 任务分类

- **数据库任务**: 创建表结构、索引、迁移脚本
- **后端任务**: 按领域模块划分（商品、订单、支付、物流、售后、营销、库存等）
- **前端任务**: 管理后台、小程序、H5 页面实现
- **集成任务**: 第三方服务对接、测试、部署

## 任务标记说明

- `*` 标记的任务为可选任务（主要是测试相关）
- 未标记的任务为必须实现的核心任务

---

## 阶段 1: 基础设施搭建

### 1.1 数据库设计与迁移

- [ ] 1.1.1 创建数据库迁移脚本
  - 创建 `migrations/20260101_create_ecommerce_tables.sql`
  - 包含所有核心表结构（商品、订单、支付、物流、售后、营销等）
  - 添加索引和外键约束
  - _需求: 需求 1-19_

- [ ] 1.1.2 创建分表迁移脚本
  - 创建订单表按月分表脚本（ecom_orders_{YYYYMM}）
  - 创建订单商品表按月分表脚本（ecom_order_items_{YYYYMM}）
  - 创建支付记录表按月分表脚本（ecom_payments_{YYYYMM}）
  - _需求: 需求 2, 需求 3_

- [ ] 1.1.3 创建初始化数据脚本
  - 插入默认物流公司数据
  - 插入默认商品分类数据
  - 插入默认系统配置数据
  - _需求: 需求 4_


### 1.2 核心基础设施

- [ ] 1.2.1 配置 DI 容器
  - 初始化全局 DI 容器
  - 注册数据库连接
  - 注册 Redis 连接
  - 注册缓存接口
  - _需求: 全局约束_

- [ ] 1.2.2 实现分布式锁
  - 创建 `src/infrastructure/redis/distributed_lock.zig`
  - 实现基于 Redis 的分布式锁
  - 支持锁超时和自动释放
  - _需求: 需求 16, 需求 18_

- [ ] 1.2.3 实现幂等性管理器
  - 创建 `src/infrastructure/idempotency/idempotency_manager.zig`
  - 实现基于 Redis 的幂等性检查
  - 支持支付回调幂等性
  - _需求: 需求 3, 需求 18_

- [ ] 1.2.4 实现参数化查询工具
  - 创建 `src/infrastructure/database/param_builder.zig`
  - 实现 SQL 参数化查询构建器
  - 防止 SQL 注入
  - _需求: 需求 18_

- [ ] 1.2.5 实现 JSON 解析器和序列化器
  - 创建 `src/core/json/parser.zig`
  - 创建 `src/core/json/pretty_printer.zig`
  - 实现往返属性测试（parse → print → parse）
  - _需求: 需求 19_

- [ ]* 1.2.6 编写基础设施单元测试
  - 测试分布式锁的并发安全性
  - 测试幂等性管理器的正确性
  - 测试 JSON 解析器的往返属性
  - _需求: 需求 19_

---

## 阶段 2: 商品管理模块

### 2.1 商品领域层

- [ ] 2.1.1 创建商品实体模型
  - 创建 `src/domain/entities/product.model.zig`
  - 定义 Product、SKU、Category 实体
  - 定义商品类型枚举（实物/虚拟/CID）
  - 定义商品状态枚举（草稿/待审核/已通过/已拒绝/已上架/已下架）
  - 定义关系（skus、category）
  - _需求: 需求 1_

- [ ] 2.1.2 创建商品仓储接口
  - 创建 `src/domain/repositories/product_repository.zig`
  - 定义 findById、findByIdWithSKUs、save、delete 方法
  - 定义 list、updateStatus、checkHasUnfinishedOrders 方法
  - _需求: 需求 1_

- [ ] 2.1.3 创建 SKU 仓储接口
  - 创建 `src/domain/repositories/sku_repository.zig`
  - 定义 findById、findByProduct、save、delete 方法
  - _需求: 需求 1_

- [ ] 2.1.4 创建分类仓储接口
  - 创建 `src/domain/repositories/category_repository.zig`
  - 定义 findById、findByLevel、findChildren、save 方法
  - _需求: 需求 1_


### 2.2 商品基础设施层

- [ ] 2.2.1 实现商品仓储
  - 创建 `src/infrastructure/database/mysql_product_repository.zig`
  - 实现 ProductRepository 接口
  - 使用 ORM 关系预加载（with SKUs）
  - 使用参数化查询防止 SQL 注入
  - 正确处理 ORM 查询结果内存（defer freeModels）
  - _需求: 需求 1, 全局约束_

- [ ] 2.2.2 实现 SKU 仓储
  - 创建 `src/infrastructure/database/mysql_sku_repository.zig`
  - 实现 SKURepository 接口
  - 使用参数化查询
  - _需求: 需求 1_

- [ ] 2.2.3 实现分类仓储
  - 创建 `src/infrastructure/database/mysql_category_repository.zig`
  - 实现 CategoryRepository 接口
  - 支持树形结构查询（最多 3 级）
  - _需求: 需求 1_

### 2.3 商品应用层

- [ ] 2.3.1 创建商品服务
  - 创建 `src/application/services/product_service.zig`
  - 实现 createProduct 方法（创建商品 + SKU + 初始化库存）
  - 实现 updateProduct 方法（更新商品 + SKU）
  - 实现 deleteProduct 方法（检查未完成订单 + 删除）
  - 实现 updateStatus 方法（状态流转验证）
  - 实现 getProductDetail 方法（缓存 + 关系预加载）
  - 实现 listProducts 方法（分页 + 筛选 + 排序）
  - 实现 importProducts 方法（批量导入 Excel/CSV）
  - _需求: 需求 1_

- [ ] 2.3.2 创建分类服务
  - 创建 `src/application/services/category_service.zig`
  - 实现 createCategory 方法
  - 实现 updateCategory 方法
  - 实现 deleteCategory 方法（检查是否有商品）
  - 实现 getCategoryTree 方法（树形结构）
  - _需求: 需求 1_

- [ ]* 2.3.3 编写商品服务单元测试
  - 测试商品创建流程
  - 测试商品状态流转
  - 测试删除商品时的订单检查
  - _需求: 需求 1_

### 2.4 商品 API 层

- [ ] 2.4.1 创建商品 DTO
  - 创建 `src/api/dto/product_create.dto.zig`
  - 创建 `src/api/dto/product_update.dto.zig`
  - 创建 `src/api/dto/product_list.dto.zig`
  - 定义请求参数验证规则
  - _需求: 需求 1_

- [ ] 2.4.2 创建商品控制器
  - 创建 `src/api/controllers/product.controller.zig`
  - 实现 list 接口（GET /api/v1/products）
  - 实现 detail 接口（GET /api/v1/products/:id）
  - 实现 create 接口（POST /api/v1/products）
  - 实现 update 接口（PUT /api/v1/products/:id）
  - 实现 delete 接口（DELETE /api/v1/products/:id）
  - 实现 updateStatus 接口（PUT /api/v1/products/:id/status）
  - 实现 import 接口（POST /api/v1/products/import）
  - _需求: 需求 1_

- [ ] 2.4.3 创建 SKU 控制器
  - 创建 `src/api/controllers/sku.controller.zig`
  - 实现 list 接口（GET /api/v1/products/:id/skus）
  - 实现 create 接口（POST /api/v1/products/:id/skus）
  - 实现 update 接口（PUT /api/v1/products/skus/:id）
  - 实现 delete 接口（DELETE /api/v1/products/skus/:id）
  - _需求: 需求 1_

- [ ] 2.4.4 创建分类控制器
  - 创建 `src/api/controllers/category.controller.zig`
  - 实现 tree 接口（GET /api/v1/categories/tree）
  - 实现 create 接口（POST /api/v1/categories）
  - 实现 update 接口（PUT /api/v1/categories/:id）
  - 实现 delete 接口（DELETE /api/v1/categories/:id）
  - _需求: 需求 1_

- [ ] 2.4.5 注册商品路由
  - 在 `src/api/bootstrap.zig` 中注册商品相关路由
  - 配置权限中间件（管理员权限）
  - _需求: 需求 1_


---

## 阶段 3: 库存管理模块

### 3.1 库存领域层

- [ ] 3.1.1 创建库存实体模型
  - 创建 `src/domain/entities/inventory.model.zig`
  - 定义 Inventory 实体（total_stock、available_stock、locked_stock、sold_stock、version）
  - 定义库存操作方法（lock、release、deduct）
  - _需求: 需求 16_

- [ ] 3.1.2 创建库存仓储接口
  - 创建 `src/domain/repositories/inventory_repository.zig`
  - 定义 findBySKU、updateWithVersion、save 方法
  - 支持乐观锁更新（基于 version 字段）
  - _需求: 需求 16_

### 3.2 库存基础设施层

- [ ] 3.2.1 实现库存仓储
  - 创建 `src/infrastructure/database/mysql_inventory_repository.zig`
  - 实现 InventoryRepository 接口
  - 实现乐观锁更新（WHERE version = ?）
  - _需求: 需求 16_

### 3.3 库存应用层

- [ ] 3.3.1 创建库存服务
  - 创建 `src/application/services/inventory_service.zig`
  - 实现 lockStock 方法（分布式锁 + 乐观锁）
  - 实现 releaseStock 方法（释放预占库存）
  - 实现 deductStock 方法（扣减库存）
  - 实现 adjustStock 方法（手动调整库存）
  - 实现 checkStockAlert 方法（库存预警）
  - _需求: 需求 16_

- [ ]* 3.3.2 编写库存服务并发测试
  - 测试并发扣减库存的正确性
  - 测试分布式锁的有效性
  - 测试乐观锁的冲突处理
  - _需求: 需求 16, 需求 18_

### 3.4 库存 API 层

- [ ] 3.4.1 创建库存控制器
  - 创建 `src/api/controllers/inventory.controller.zig`
  - 实现 list 接口（GET /api/v1/inventories）
  - 实现 adjust 接口（POST /api/v1/inventories/:id/adjust）
  - 实现 logs 接口（GET /api/v1/inventories/:id/logs）
  - _需求: 需求 16_

---

## 阶段 4: 订单管理模块

### 4.1 订单领域层

- [ ] 4.1.1 创建订单实体模型
  - 创建 `src/domain/entities/order.model.zig`
  - 定义 Order、OrderItem 实体
  - 定义订单状态枚举（待支付/待发货/待收货/已完成/已关闭）
  - 定义订单状态流转方法（canTransitionTo、getNextStatus）
  - 定义关系（items、user、payment）
  - _需求: 需求 2_

- [ ] 4.1.2 创建订单值对象
  - 创建 `src/domain/value_objects/order_status.zig`
  - 定义 OrderStatus 枚举和状态机
  - 定义 OrderEvent 枚举（paid、shipped、received、cancelled、timeout）
  - _需求: 需求 2_

- [ ] 4.1.3 创建订单仓储接口
  - 创建 `src/domain/repositories/order_repository.zig`
  - 定义 findById、findByOrderNo、save、delete 方法
  - 定义 findByUserAndStatus、findExpired 方法
  - 支持分表查询（按月分表）
  - _需求: 需求 2_

- [ ] 4.1.4 创建订单引擎领域服务
  - 创建 `src/domain/services/order_engine.zig`
  - 定义 createOrder 方法（验证库存 + 计算金额 + 预占库存）
  - 定义 splitOrder 方法（拆单逻辑）
  - 定义 cancelOrder 方法（释放库存 + 退还优惠券）
  - 定义 autoCloseExpiredOrders 方法（超时自动关闭）
  - _需求: 需求 2, 需求 17_


### 4.2 订单基础设施层

- [ ] 4.2.1 实现订单仓储
  - 创建 `src/infrastructure/database/mysql_order_repository.zig`
  - 实现 OrderRepository 接口
  - 实现分表路由逻辑（根据 created_at 路由到对应月份表）
  - 使用关系预加载（with items、with user）
  - _需求: 需求 2_

- [ ] 4.2.2 实现订单商品仓储
  - 创建 `src/infrastructure/database/mysql_order_item_repository.zig`
  - 实现 OrderItemRepository 接口
  - 支持分表查询
  - _需求: 需求 2_

- [ ] 4.2.3 实现订单状态日志仓储
  - 创建 `src/infrastructure/database/mysql_order_status_log_repository.zig`
  - 实现 OrderStatusLogRepository 接口
  - 记录状态变更历史
  - _需求: 需求 2_

### 4.3 订单应用层

- [ ] 4.3.1 创建订单服务
  - 创建 `src/application/services/order_service.zig`
  - 实现 createOrder 方法（调用订单引擎 + 事务处理）
  - 实现 cancelOrder 方法（状态验证 + 释放资源）
  - 实现 confirmReceipt 方法（确认收货）
  - 实现 getOrderDetail 方法（关系预加载 + 缓存）
  - 实现 listOrders 方法（分页 + 筛选）
  - 实现 exportOrders 方法（导出 Excel/CSV）
  - _需求: 需求 2_

- [ ] 4.3.2 创建订单拆单服务
  - 创建 `src/application/services/order_split_service.zig`
  - 实现 splitByMerchant 方法（按商家拆单）
  - 实现 splitByWarehouse 方法（按仓库拆单）
  - 实现 splitByProductType 方法（按商品类型拆单）
  - 实现金额分摊逻辑（优惠金额、运费）
  - _需求: 需求 17_

- [ ] 4.3.3 创建订单定时任务服务
  - 创建 `src/application/services/order_cron_service.zig`
  - 实现 autoCloseExpiredOrders 方法（30 分钟未支付自动关闭）
  - 实现 autoConfirmReceipt 方法（7 天自动确认收货）
  - _需求: 需求 2_

- [ ]* 4.3.4 编写订单服务单元测试
  - 测试订单创建流程（库存扣减 + 优惠券核销）
  - 测试订单状态流转
  - 测试订单拆单逻辑
  - 测试订单超时关闭
  - _需求: 需求 2, 需求 17_

### 4.4 订单 API 层

- [ ] 4.4.1 创建订单 DTO
  - 创建 `src/api/dto/order_create.dto.zig`
  - 创建 `src/api/dto/order_list.dto.zig`
  - 定义请求参数验证规则
  - _需求: 需求 2_

- [ ] 4.4.2 创建订单控制器
  - 创建 `src/api/controllers/order.controller.zig`
  - 实现 list 接口（GET /api/v1/orders）
  - 实现 detail 接口（GET /api/v1/orders/:id）
  - 实现 create 接口（POST /api/v1/orders）
  - 实现 cancel 接口（PUT /api/v1/orders/:id/cancel）
  - 实现 confirm 接口（PUT /api/v1/orders/:id/confirm）
  - 实现 timeline 接口（GET /api/v1/orders/:id/timeline）
  - 实现 export 接口（POST /api/v1/orders/export）
  - _需求: 需求 2_

- [ ] 4.4.3 注册订单路由
  - 在 `src/api/bootstrap.zig` 中注册订单相关路由
  - 配置权限中间件
  - _需求: 需求 2_

---

## 阶段 5: 支付管理模块

### 5.1 支付领域层

- [ ] 5.1.1 创建支付实体模型
  - 创建 `src/domain/entities/payment.model.zig`
  - 定义 Payment 实体
  - 定义支付方式枚举（微信/支付宝）
  - 定义支付状态枚举（待支付/支付成功/支付失败/已退款）
  - _需求: 需求 3_

- [ ] 5.1.2 创建支付仓储接口
  - 创建 `src/domain/repositories/payment_repository.zig`
  - 定义 findById、findByPaymentNo、findByOrderId、save 方法
  - 支持分表查询
  - _需求: 需求 3_

- [ ] 5.1.3 创建支付网关领域服务
  - 创建 `src/domain/services/payment_gateway.zig`
  - 定义 createPayment 方法
  - 定义 handleCallback 方法（验证签名 + 幂等性检查）
  - 定义 refund 方法
  - _需求: 需求 3_


### 5.2 支付基础设施层

- [ ] 5.2.1 实现支付仓储
  - 创建 `src/infrastructure/database/mysql_payment_repository.zig`
  - 实现 PaymentRepository 接口
  - 支持分表查询
  - _需求: 需求 3_

- [ ] 5.2.2 实现微信支付客户端
  - 创建 `src/infrastructure/payment/wechat_pay_client.zig`
  - 实现 JSAPI 支付
  - 实现 H5 支付
  - 实现小程序支付
  - 实现签名验证
  - 实现退款接口
  - _需求: 需求 3_

- [ ] 5.2.3 实现支付宝客户端
  - 创建 `src/infrastructure/payment/alipay_client.zig`
  - 实现网页支付
  - 实现手机网站支付
  - 实现签名验证
  - 实现退款接口
  - _需求: 需求 3_

### 5.3 支付应用层

- [ ] 5.3.1 创建支付服务
  - 创建 `src/application/services/payment_service.zig`
  - 实现 createWechatPayment 方法
  - 实现 createAlipayPayment 方法
  - 实现 handleWechatCallback 方法（幂等性 + 事务）
  - 实现 handleAlipayCallback 方法（幂等性 + 事务）
  - 实现 refund 方法
  - 实现 queryPaymentStatus 方法
  - _需求: 需求 3_

- [ ]* 5.3.2 编写支付服务单元测试
  - 测试支付创建流程
  - 测试回调幂等性
  - 测试签名验证
  - 测试退款流程
  - _需求: 需求 3_

### 5.4 支付 API 层

- [ ] 5.4.1 创建支付 DTO
  - 创建 `src/api/dto/payment_create.dto.zig`
  - 创建 `src/api/dto/payment_refund.dto.zig`
  - _需求: 需求 3_

- [ ] 5.4.2 创建支付控制器
  - 创建 `src/api/controllers/payment.controller.zig`
  - 实现 wechat 接口（POST /api/v1/payments/wechat）
  - 实现 alipay 接口（POST /api/v1/payments/alipay）
  - 实现 wechatCallback 接口（POST /api/v1/payments/callback/wechat）
  - 实现 alipayCallback 接口（POST /api/v1/payments/callback/alipay）
  - 实现 detail 接口（GET /api/v1/payments/:id）
  - 实现 refund 接口（POST /api/v1/payments/:id/refund）
  - _需求: 需求 3_

- [ ] 5.4.3 注册支付路由
  - 在 `src/api/bootstrap.zig` 中注册支付相关路由
  - 回调接口不需要认证
  - _需求: 需求 3_

---

## 阶段 6: 物流管理模块

### 6.1 物流领域层

- [ ] 6.1.1 创建物流实体模型
  - 创建 `src/domain/entities/logistics.model.zig`
  - 定义 LogisticsCompany、FreightTemplate、LogisticsTrack 实体
  - 定义物流状态枚举（已揽收/运输中/派送中/已签收/异常）
  - _需求: 需求 4_

- [ ] 6.1.2 创建物流仓储接口
  - 创建 `src/domain/repositories/logistics_repository.zig`
  - 定义物流公司、运费模板、物流跟踪的仓储接口
  - _需求: 需求 4_

- [ ] 6.1.3 创建运费计算领域服务
  - 创建 `src/domain/services/freight_calculator.zig`
  - 定义 calculateFreight 方法（按重量/件数/体积）
  - 定义 checkFreeShipping 方法（包邮规则）
  - _需求: 需求 4_

### 6.2 物流基础设施层

- [ ] 6.2.1 实现物流仓储
  - 创建 `src/infrastructure/database/mysql_logistics_repository.zig`
  - 实现物流公司仓储
  - 实现运费模板仓储
  - 实现物流跟踪仓储
  - _需求: 需求 4_

- [ ] 6.2.2 实现快递鸟客户端
  - 创建 `src/infrastructure/logistics/kdniao_client.zig`
  - 实现物流查询接口
  - 实现电子面单接口
  - _需求: 需求 4_

- [ ] 6.2.3 实现快递100客户端
  - 创建 `src/infrastructure/logistics/kuaidi100_client.zig`
  - 实现物流查询接口
  - _需求: 需求 4_


### 6.3 物流应用层

- [ ] 6.3.1 创建物流服务
  - 创建 `src/application/services/logistics_service.zig`
  - 实现 calculateFreight 方法（运费计算）
  - 实现 shipOrder 方法（发货）
  - 实现 queryTrack 方法（查询物流 + 缓存）
  - 实现 syncTrack 方法（同步物流信息）
  - 实现 batchShip 方法（批量发货）
  - _需求: 需求 4_

- [ ] 6.3.2 创建运费模板服务
  - 创建 `src/application/services/freight_template_service.zig`
  - 实现 createTemplate 方法
  - 实现 updateTemplate 方法
  - 实现 deleteTemplate 方法
  - _需求: 需求 4_

- [ ]* 6.3.3 编写物流服务单元测试
  - 测试运费计算逻辑
  - 测试包邮规则
  - 测试物流查询缓存
  - _需求: 需求 4_

### 6.4 物流 API 层

- [ ] 6.4.1 创建物流 DTO
  - 创建 `src/api/dto/logistics_ship.dto.zig`
  - 创建 `src/api/dto/freight_template.dto.zig`
  - _需求: 需求 4_

- [ ] 6.4.2 创建物流控制器
  - 创建 `src/api/controllers/logistics.controller.zig`
  - 实现 companies 接口（GET /api/v1/logistics/companies）
  - 实现 createCompany 接口（POST /api/v1/logistics/companies）
  - 实现 templates 接口（GET /api/v1/logistics/templates）
  - 实现 createTemplate 接口（POST /api/v1/logistics/templates）
  - 实现 calculateFreight 接口（POST /api/v1/logistics/calculate）
  - 实现 track 接口（GET /api/v1/logistics/track/:order_id）
  - 实现 ship 接口（POST /api/v1/logistics/ship）
  - _需求: 需求 4_

- [ ] 6.4.3 注册物流路由
  - 在 `src/api/bootstrap.zig` 中注册物流相关路由
  - _需求: 需求 4_

---

## 阶段 7: 售后管理模块

### 7.1 售后领域层

- [ ] 7.1.1 创建售后实体模型
  - 创建 `src/domain/entities/after_sales.model.zig`
  - 定义 AfterSales 实体
  - 定义售后类型枚举（仅退款/退货退款/换货）
  - 定义售后状态枚举（待审核/已通过/已拒绝/退货中/已完成）
  - 定义状态流转方法
  - _需求: 需求 5_

- [ ] 7.1.2 创建售后仓储接口
  - 创建 `src/domain/repositories/after_sales_repository.zig`
  - 定义 findById、findByAfterSalesNo、findByOrderId、save 方法
  - _需求: 需求 5_

### 7.2 售后基础设施层

- [ ] 7.2.1 实现售后仓储
  - 创建 `src/infrastructure/database/mysql_after_sales_repository.zig`
  - 实现 AfterSalesRepository 接口
  - _需求: 需求 5_

### 7.3 售后应用层

- [ ] 7.3.1 创建售后服务
  - 创建 `src/application/services/after_sales_service.zig`
  - 实现 applyAfterSales 方法（创建售后工单）
  - 实现 auditAfterSales 方法（审核售后）
  - 实现 fillReturnLogistics 方法（填写退货物流）
  - 实现 confirmReturn 方法（确认收货 + 退款）
  - 实现 listAfterSales 方法（分页 + 筛选）
  - 实现 autoApproveExpired 方法（7 天未处理自动通过）
  - _需求: 需求 5_

- [ ]* 7.3.2 编写售后服务单元测试
  - 测试售后申请流程
  - 测试售后状态流转
  - 测试退款金额验证
  - _需求: 需求 5_

### 7.4 售后 API 层

- [ ] 7.4.1 创建售后 DTO
  - 创建 `src/api/dto/after_sales_apply.dto.zig`
  - 创建 `src/api/dto/after_sales_audit.dto.zig`
  - _需求: 需求 5_

- [ ] 7.4.2 创建售后控制器
  - 创建 `src/api/controllers/after_sales.controller.zig`
  - 实现 list 接口（GET /api/v1/after-sales）
  - 实现 detail 接口（GET /api/v1/after-sales/:id）
  - 实现 apply 接口（POST /api/v1/after-sales）
  - 实现 audit 接口（PUT /api/v1/after-sales/:id/audit）
  - 实现 fillReturn 接口（PUT /api/v1/after-sales/:id/return）
  - 实现 confirm 接口（PUT /api/v1/after-sales/:id/confirm）
  - _需求: 需求 5_

- [ ] 7.4.3 注册售后路由
  - 在 `src/api/bootstrap.zig` 中注册售后相关路由
  - _需求: 需求 5_


---

## 阶段 8: 营销活动模块

### 8.1 营销领域层

- [ ] 8.1.1 创建营销活动实体模型
  - 创建 `src/domain/entities/marketing_activity.model.zig`
  - 定义 MarketingActivity 实体
  - 定义活动类型枚举（秒杀/拼团/满减/限时折扣）
  - 定义活动状态枚举（禁用/启用）
  - _需求: 需求 6_

- [ ] 8.1.2 创建拼团实体模型
  - 创建 `src/domain/entities/group_buying.model.zig`
  - 定义 GroupBuying 实体
  - 定义拼团状态枚举（拼团中/拼团成功/拼团失败）
  - _需求: 需求 6_

- [ ] 8.1.3 创建营销仓储接口
  - 创建 `src/domain/repositories/marketing_repository.zig`
  - 定义活动、拼团的仓储接口
  - _需求: 需求 6_

### 8.2 营销基础设施层

- [ ] 8.2.1 实现营销仓储
  - 创建 `src/infrastructure/database/mysql_marketing_repository.zig`
  - 实现活动仓储
  - 实现拼团仓储
  - _需求: 需求 6_

### 8.3 营销应用层

- [ ] 8.3.1 创建秒杀服务
  - 创建 `src/application/services/seckill_service.zig`
  - 实现 preheatStock 方法（预热库存到 Redis）
  - 实现 participate 方法（参与秒杀 + 分布式锁 + Lua 脚本）
  - 实现 checkUserLimit 方法（用户限购检查）
  - _需求: 需求 6_

- [ ] 8.3.2 创建拼团服务
  - 创建 `src/application/services/group_buying_service.zig`
  - 实现 createGroup 方法（创建拼团）
  - 实现 joinGroup 方法（参与拼团）
  - 实现 checkExpiredGroups 方法（检查过期拼团 + 退款）
  - 实现 createGroupOrders 方法（成团后创建订单）
  - _需求: 需求 6_

- [ ] 8.3.3 创建满减服务
  - 创建 `src/application/services/discount_service.zig`
  - 实现 calculateDiscount 方法（计算满减优惠）
  - 实现 checkRules 方法（验证满减规则）
  - _需求: 需求 6_

- [ ] 8.3.4 创建营销活动服务
  - 创建 `src/application/services/marketing_activity_service.zig`
  - 实现 createActivity 方法
  - 实现 updateActivity 方法
  - 实现 deleteActivity 方法
  - 实现 listActivities 方法
  - 实现 getActivityStatistics 方法（统计数据）
  - _需求: 需求 6_

- [ ]* 8.3.5 编写营销服务并发测试
  - 测试秒杀并发扣减库存
  - 测试拼团并发参与
  - 测试分布式锁的有效性
  - _需求: 需求 6, 需求 18_

### 8.4 营销 API 层

- [ ] 8.4.1 创建营销 DTO
  - 创建 `src/api/dto/activity_create.dto.zig`
  - 创建 `src/api/dto/seckill_participate.dto.zig`
  - 创建 `src/api/dto/group_buying_create.dto.zig`
  - _需求: 需求 6_

- [ ] 8.4.2 创建营销控制器
  - 创建 `src/api/controllers/marketing.controller.zig`
  - 实现 activities 接口（GET /api/v1/activities）
  - 实现 createActivity 接口（POST /api/v1/activities）
  - 实现 activityDetail 接口（GET /api/v1/activities/:id）
  - 实现 joinActivity 接口（POST /api/v1/activities/:id/join）
  - 实现 groupBuyingDetail 接口（GET /api/v1/group-buying/:id）
  - 实现 joinGroupBuying 接口（POST /api/v1/group-buying/:id/join）
  - _需求: 需求 6_

- [ ] 8.4.3 注册营销路由
  - 在 `src/api/bootstrap.zig` 中注册营销相关路由
  - _需求: 需求 6_

---

## 阶段 9: 优惠券模块

### 9.1 优惠券领域层

- [ ] 9.1.1 创建优惠券实体模型
  - 创建 `src/domain/entities/coupon.model.zig`
  - 定义 Coupon、UserCoupon 实体
  - 定义优惠券类型枚举（满减券/折扣券/兑换券）
  - 定义优惠券状态枚举（未使用/已使用/已过期）
  - _需求: 需求 7_

- [ ] 9.1.2 创建优惠券仓储接口
  - 创建 `src/domain/repositories/coupon_repository.zig`
  - 定义优惠券、用户优惠券的仓储接口
  - _需求: 需求 7_

### 9.2 优惠券基础设施层

- [ ] 9.2.1 实现优惠券仓储
  - 创建 `src/infrastructure/database/mysql_coupon_repository.zig`
  - 实现优惠券仓储
  - 实现用户优惠券仓储
  - _需求: 需求 7_


### 9.3 优惠券应用层

- [ ] 9.3.1 创建优惠券服务
  - 创建 `src/application/services/coupon_service.zig`
  - 实现 createCoupon 方法
  - 实现 receiveCoupon 方法（分布式锁 + 库存检查 + 用户限领）
  - 实现 useCoupon 方法（核销优惠券）
  - 实现 refundCoupon 方法（退还优惠券）
  - 实现 matchAvailableCoupons 方法（匹配可用优惠券）
  - 实现 listCoupons 方法
  - 实现 getUserCoupons 方法
  - _需求: 需求 7_

- [ ]* 9.3.2 编写优惠券服务并发测试
  - 测试优惠券并发领取
  - 测试分布式锁的有效性
  - 测试优惠券核销幂等性
  - _需求: 需求 7, 需求 18_

### 9.4 优惠券 API 层

- [ ] 9.4.1 创建优惠券 DTO
  - 创建 `src/api/dto/coupon_create.dto.zig`
  - 创建 `src/api/dto/coupon_receive.dto.zig`
  - _需求: 需求 7_

- [ ] 9.4.2 创建优惠券控制器
  - 创建 `src/api/controllers/coupon.controller.zig`
  - 实现 list 接口（GET /api/v1/coupons）
  - 实现 create 接口（POST /api/v1/coupons）
  - 实现 receive 接口（POST /api/v1/coupons/:id/receive）
  - 实现 userCoupons 接口（GET /api/v1/user/coupons）
  - 实现 matchCoupons 接口（POST /api/v1/coupons/match）
  - _需求: 需求 7_

- [ ] 9.4.3 注册优惠券路由
  - 在 `src/api/bootstrap.zig` 中注册优惠券相关路由
  - _需求: 需求 7_

---

## 阶段 10: 短信服务模块

### 10.1 短信领域层

- [ ] 10.1.1 创建短信实体模型
  - 创建 `src/domain/entities/sms.model.zig`
  - 定义 SMSConfig、SMSTemplate、SMSLog 实体
  - 定义短信状态枚举（发送中/成功/失败）
  - _需求: 需求 8_

- [ ] 10.1.2 创建短信仓储接口
  - 创建 `src/domain/repositories/sms_repository.zig`
  - 定义短信配置、模板、日志的仓储接口
  - _需求: 需求 8_

### 10.2 短信基础设施层

- [ ] 10.2.1 实现短信仓储
  - 创建 `src/infrastructure/database/mysql_sms_repository.zig`
  - 实现短信配置仓储
  - 实现短信模板仓储
  - 实现短信日志仓储
  - _需求: 需求 8_

- [ ] 10.2.2 实现阿里云短信客户端
  - 创建 `src/infrastructure/sms/aliyun_sms_client.zig`
  - 实现发送短信接口
  - 实现签名验证
  - _需求: 需求 8_

- [ ] 10.2.3 实现腾讯云短信客户端
  - 创建 `src/infrastructure/sms/tencent_sms_client.zig`
  - 实现发送短信接口
  - 实现签名验证
  - _需求: 需求 8_

### 10.3 短信应用层

- [ ] 10.3.1 创建短信服务
  - 创建 `src/application/services/sms_service.zig`
  - 实现 sendSMS 方法（频率限制 + 重试机制）
  - 实现 sendVerificationCode 方法（生成验证码 + 存储到 Redis）
  - 实现 verifyCode 方法（验证码校验 + 错误次数限制）
  - 实现 checkRateLimit 方法（1 分钟 1 条、每天 10 条）
  - 实现 listLogs 方法
  - _需求: 需求 8_

- [ ]* 10.3.2 编写短信服务单元测试
  - 测试频率限制
  - 测试验证码生成和验证
  - 测试重试机制
  - _需求: 需求 8_

### 10.4 短信 API 层

- [ ] 10.4.1 创建短信 DTO
  - 创建 `src/api/dto/sms_send.dto.zig`
  - 创建 `src/api/dto/sms_verify.dto.zig`
  - _需求: 需求 8_

- [ ] 10.4.2 创建短信控制器
  - 创建 `src/api/controllers/sms.controller.zig`
  - 实现 sendCode 接口（POST /api/v1/sms/send-code）
  - 实现 verifyCode 接口（POST /api/v1/sms/verify-code）
  - 实现 configs 接口（GET /api/v1/sms/configs）
  - 实现 templates 接口（GET /api/v1/sms/templates）
  - 实现 logs 接口（GET /api/v1/sms/logs）
  - _需求: 需求 8_

- [ ] 10.4.3 注册短信路由
  - 在 `src/api/bootstrap.zig` 中注册短信相关路由
  - _需求: 需求 8_


---

## 阶段 11: 其他核心模块

### 11.1 评论管理模块

- [ ] 11.1.1 创建评论实体和仓储
  - 创建 `src/domain/entities/review.model.zig`
  - 创建 `src/domain/repositories/review_repository.zig`
  - 创建 `src/infrastructure/database/mysql_review_repository.zig`
  - _需求: 需求 10_

- [ ] 11.1.2 创建评论服务
  - 创建 `src/application/services/review_service.zig`
  - 实现 createReview 方法（订单完成后可评价）
  - 实现 appendReview 方法（30 天内可追加）
  - 实现 auditReview 方法（审核评论）
  - 实现 replyReview 方法（商家回复）
  - 实现 listReviews 方法（筛选：好评/中评/差评/有图）
  - 实现 calculateRating 方法（计算商品评分和好评率）
  - _需求: 需求 10_

- [ ] 11.1.3 创建评论控制器和路由
  - 创建 `src/api/controllers/review.controller.zig`
  - 实现 list、create、append、audit、reply 接口
  - 注册路由
  - _需求: 需求 10_

### 11.2 推广管理模块

- [ ] 11.2.1 创建推广实体和仓储
  - 创建 `src/domain/entities/promoter.model.zig`
  - 创建 `src/domain/repositories/promoter_repository.zig`
  - 创建 `src/infrastructure/database/mysql_promoter_repository.zig`
  - _需求: 需求 11_

- [ ] 11.2.2 创建推广服务
  - 创建 `src/application/services/promoter_service.zig`
  - 实现 createPromoter 方法
  - 实现 generatePromotionLink 方法（生成推广链接）
  - 实现 recordPromotion 方法（记录推广关系）
  - 实现 calculateCommission 方法（计算佣金）
  - 实现 settleCommission 方法（佣金结算）
  - 实现 withdraw 方法（提现）
  - _需求: 需求 11_

- [ ] 11.2.3 创建推广控制器和路由
  - 创建 `src/api/controllers/promoter.controller.zig`
  - 实现 list、create、link、orders、commission、withdraw 接口
  - 注册路由
  - _需求: 需求 11_

### 11.3 淘宝客管理模块

- [ ] 11.3.1 创建淘宝客实体和仓储
  - 创建 `src/domain/entities/taobao_ke.model.zig`
  - 创建 `src/domain/repositories/taobao_ke_repository.zig`
  - 创建 `src/infrastructure/database/mysql_taobao_ke_repository.zig`
  - _需求: 需求 12_

- [ ] 11.3.2 实现淘宝客 API 客户端
  - 创建 `src/infrastructure/taobao/taobao_ke_client.zig`
  - 实现商品搜索接口
  - 实现商品详情接口
  - 实现推广链接生成接口
  - _需求: 需求 12_

- [ ] 11.3.3 创建淘宝客服务
  - 创建 `src/application/services/taobao_ke_service.zig`
  - 实现 searchProducts 方法
  - 实现 importProducts 方法（批量导入）
  - 实现 generatePromotionLink 方法
  - 实现 syncOrders 方法（定时同步订单）
  - 实现 settleCommission 方法（佣金结算）
  - _需求: 需求 12_

- [ ] 11.3.4 创建淘宝客控制器和路由
  - 创建 `src/api/controllers/taobao_ke.controller.zig`
  - 实现 search、import、link、orders、commission 接口
  - 注册路由
  - _需求: 需求 12_

### 11.4 广告管理模块

- [ ] 11.4.1 创建广告实体和仓储
  - 创建 `src/domain/entities/advertisement.model.zig`
  - 创建 `src/domain/repositories/advertisement_repository.zig`
  - 创建 `src/infrastructure/database/mysql_advertisement_repository.zig`
  - _需求: 需求 13_

- [ ] 11.4.2 创建广告服务
  - 创建 `src/application/services/advertisement_service.zig`
  - 实现 createAdvertisement 方法
  - 实现 updateAdvertisement 方法
  - 实现 deleteAdvertisement 方法
  - 实现 listAdvertisements 方法（按广告位）
  - 实现 recordClick 方法（记录点击量）
  - 实现 autoExpire 方法（自动下架过期广告）
  - _需求: 需求 13_

- [ ] 11.4.3 创建广告控制器和路由
  - 创建 `src/api/controllers/advertisement.controller.zig`
  - 实现 list、create、update、delete、click 接口
  - 注册路由
  - _需求: 需求 13_

### 11.5 销售统计模块

- [ ] 11.5.1 创建统计服务
  - 创建 `src/application/services/statistics_service.zig`
  - 实现 getSalesReport 方法（按日/周/月）
  - 实现 getProductRanking 方法（商品销量排行）
  - 实现 getUserRanking 方法（用户消费排行）
  - 实现 getCategorySales 方法（分类销售占比）
  - 实现 getSalesTrend 方法（销售趋势）
  - 实现缓存策略（5 分钟缓存）
  - _需求: 需求 14_

- [ ] 11.5.2 创建统计控制器和路由
  - 创建 `src/api/controllers/statistics.controller.zig`
  - 实现 overview、sales、products、users、categories、trend 接口
  - 注册路由
  - _需求: 需求 14_


### 11.6 可视化页面搭建模块

- [ ] 11.6.1 创建页面配置实体和仓储
  - 创建 `src/domain/entities/page_config.model.zig`
  - 创建 `src/domain/repositories/page_config_repository.zig`
  - 创建 `src/infrastructure/database/mysql_page_config_repository.zig`
  - _需求: 需求 9_

- [ ] 11.6.2 创建页面构建服务
  - 创建 `src/application/services/page_builder_service.zig`
  - 实现 createPage 方法
  - 实现 updatePage 方法
  - 实现 publishPage 方法（草稿 → 已发布）
  - 实现 getPageConfig 方法（缓存）
  - 实现 validateComponents 方法（验证组件配置）
  - _需求: 需求 9_

- [ ] 11.6.3 创建页面构建控制器和路由
  - 创建 `src/api/controllers/page_builder.controller.zig`
  - 实现 list、create、update、publish、preview 接口
  - 注册路由
  - _需求: 需求 9_

### 11.7 用户系统模块

- [ ] 11.7.1 创建用户实体和仓储
  - 创建 `src/domain/entities/user.model.zig`
  - 创建 `src/domain/repositories/user_repository.zig`
  - 创建 `src/infrastructure/database/mysql_user_repository.zig`
  - _需求: 需求 15_

- [ ] 11.7.2 创建用户服务
  - 创建 `src/application/services/user_service.zig`
  - 实现 register 方法（手机号 + 验证码）
  - 实现 login 方法（手机号 + 密码、微信授权）
  - 实现 updateProfile 方法（头像、昵称、性别）
  - 实现 getProfile 方法（缓存）
  - _需求: 需求 15_

- [ ] 11.7.3 创建地址服务
  - 创建 `src/application/services/address_service.zig`
  - 实现 createAddress 方法
  - 实现 updateAddress 方法
  - 实现 deleteAddress 方法
  - 实现 setDefaultAddress 方法
  - 实现 listAddresses 方法
  - _需求: 需求 15_

- [ ] 11.7.4 创建购物车服务
  - 创建 `src/application/services/cart_service.zig`
  - 实现 addToCart 方法
  - 实现 updateCartItem 方法（修改数量）
  - 实现 removeCartItem 方法
  - 实现 clearCart 方法
  - 实现 listCartItems 方法
  - 使用 Redis 存储购物车数据
  - _需求: 需求 15_

- [ ] 11.7.5 创建收藏服务
  - 创建 `src/application/services/favorite_service.zig`
  - 实现 addFavorite 方法
  - 实现 removeFavorite 方法
  - 实现 listFavorites 方法
  - _需求: 需求 15_

- [ ] 11.7.6 创建用户控制器和路由
  - 创建 `src/api/controllers/user.controller.zig`
  - 实现 register、login、profile、updateProfile 接口
  - 创建 `src/api/controllers/address.controller.zig`
  - 创建 `src/api/controllers/cart.controller.zig`
  - 创建 `src/api/controllers/favorite.controller.zig`
  - 注册路由
  - _需求: 需求 15_

---

## 阶段 12: 前端管理后台

### 12.1 项目初始化

- [ ] 12.1.1 创建 Vue3 项目
  - 使用 Vite 创建项目（`npm create vite@latest ecom-admin -- --template vue-ts`）
  - 安装依赖（Element Plus、Vue Router、Pinia、Axios、ECharts）
  - 配置 TypeScript
  - 配置 ESLint 和 Prettier
  - _需求: 需求 1-19_

- [ ] 12.1.2 配置路由和状态管理
  - 配置 Vue Router（路由守卫、权限控制）
  - 配置 Pinia（用户状态、商品状态、订单状态）
  - 配置 Axios（请求拦截、响应拦截、错误处理）
  - _需求: 需求 1-19_

- [ ] 12.1.3 创建布局组件
  - 创建 `src/layouts/MainLayout.vue`（侧边栏 + 顶部栏 + 内容区）
  - 创建 `src/components/Sidebar.vue`（侧边栏导航）
  - 创建 `src/components/Header.vue`（顶部栏）
  - _需求: 需求 1-19_

### 12.2 商品管理页面

- [ ] 12.2.1 创建商品列表页面
  - 创建 `src/views/product/list.vue`
  - 实现商品列表展示（表格）
  - 实现搜索、筛选、排序功能
  - 实现分页功能
  - 实现批量操作（上下架、删除）
  - _需求: 需求 1_

- [ ] 12.2.2 创建商品创建/编辑页面
  - 创建 `src/views/product/create.vue`
  - 创建 `src/views/product/edit.vue`
  - 实现商品基本信息表单
  - 实现 SKU 编辑器组件（规格配置 + SKU 列表）
  - 实现图片上传组件
  - 实现富文本编辑器（商品描述）
  - _需求: 需求 1_

- [ ] 12.2.3 创建分类管理页面
  - 创建 `src/views/product/category.vue`
  - 实现树形分类展示
  - 实现分类增删改功能
  - _需求: 需求 1_

- [ ] 12.2.4 创建 SKU 编辑器组件
  - 创建 `src/components/SKUEditor.vue`
  - 实现规格属性配置
  - 实现 SKU 列表生成（笛卡尔积）
  - 实现 SKU 价格、库存、图片编辑
  - _需求: 需求 1_


### 12.3 订单管理页面

- [ ] 12.3.1 创建订单列表页面
  - 创建 `src/views/order/list.vue`
  - 实现订单列表展示（表格）
  - 实现搜索、筛选功能（按状态、时间、用户）
  - 实现分页功能
  - 实现订单导出功能
  - _需求: 需求 2_

- [ ] 12.3.2 创建订单详情页面
  - 创建 `src/views/order/detail.vue`
  - 实现订单基本信息展示
  - 实现订单商品列表展示
  - 实现订单状态时间线组件
  - 实现订单操作（关闭、备注）
  - _需求: 需求 2_

- [ ] 12.3.3 创建订单时间线组件
  - 创建 `src/components/OrderTimeline.vue`
  - 实现时间线展示（下单、支付、发货、收货）
  - 实现状态图标和时间显示
  - _需求: 需求 2_

### 12.4 支付管理页面

- [ ] 12.4.1 创建支付配置页面
  - 创建 `src/views/payment/config.vue`
  - 实现微信支付配置表单
  - 实现支付宝配置表单
  - _需求: 需求 3_

- [ ] 12.4.2 创建支付记录页面
  - 创建 `src/views/payment/records.vue`
  - 实现支付记录列表展示
  - 实现搜索、筛选功能
  - 实现支付详情查看
  - _需求: 需求 3_

### 12.5 物流管理页面

- [ ] 12.5.1 创建物流公司管理页面
  - 创建 `src/views/logistics/companies.vue`
  - 实现物流公司列表展示
  - 实现物流公司增删改功能
  - _需求: 需求 4_

- [ ] 12.5.2 创建运费模板管理页面
  - 创建 `src/views/logistics/templates.vue`
  - 实现运费模板列表展示
  - 实现运费模板创建/编辑表单
  - 实现区域配置功能
  - _需求: 需求 4_

- [ ] 12.5.3 创建物流跟踪页面
  - 创建 `src/views/logistics/tracking.vue`
  - 实现物流跟踪查询
  - 实现物流轨迹时间线展示
  - _需求: 需求 4_

### 12.6 售后管理页面

- [ ] 12.6.1 创建售后列表页面
  - 创建 `src/views/after-sales/list.vue`
  - 实现售后列表展示
  - 实现搜索、筛选功能
  - _需求: 需求 5_

- [ ] 12.6.2 创建售后详情页面
  - 创建 `src/views/after-sales/detail.vue`
  - 实现售后信息展示
  - 实现售后审核功能
  - 实现售后操作（通过、拒绝、确认收货）
  - _需求: 需求 5_

### 12.7 营销管理页面

- [ ] 12.7.1 创建营销活动管理页面
  - 创建 `src/views/marketing/activities.vue`
  - 实现活动列表展示
  - 实现活动创建/编辑表单（秒杀、拼团、满减、限时折扣）
  - 实现活动数据统计展示
  - _需求: 需求 6_

- [ ] 12.7.2 创建优惠券管理页面
  - 创建 `src/views/marketing/coupons.vue`
  - 实现优惠券列表展示
  - 实现优惠券创建/编辑表单
  - 实现优惠券使用统计展示
  - _需求: 需求 7_

- [ ] 12.7.3 创建推广管理页面
  - 创建 `src/views/marketing/promoters.vue`
  - 实现推广员列表展示
  - 实现推广员增删改功能
  - 实现推广数据统计展示
  - _需求: 需求 11_

### 12.8 短信管理页面

- [ ] 12.8.1 创建短信配置页面
  - 创建 `src/views/sms/config.vue`
  - 实现短信服务商配置表单
  - _需求: 需求 8_

- [ ] 12.8.2 创建短信模板管理页面
  - 创建 `src/views/sms/templates.vue`
  - 实现短信模板列表展示
  - 实现短信模板增删改功能
  - _需求: 需求 8_

- [ ] 12.8.3 创建短信日志页面
  - 创建 `src/views/sms/logs.vue`
  - 实现短信发送日志列表展示
  - 实现搜索、筛选功能
  - _需求: 需求 8_

### 12.9 页面搭建器

- [ ] 12.9.1 创建页面构建器编辑器
  - 创建 `src/views/page-builder/editor.vue`
  - 实现左侧组件库（拖拽式）
  - 实现中间画布（组件展示 + 排序）
  - 实现右侧属性配置面板
  - 实现页面保存和发布功能
  - _需求: 需求 9_

- [ ] 12.9.2 创建页面构建器组件库
  - 创建 `src/components/PageBuilder/Banner.vue`（轮播图组件）
  - 创建 `src/components/PageBuilder/ProductList.vue`（商品列表组件）
  - 创建 `src/components/PageBuilder/CategoryNav.vue`（分类导航组件）
  - 创建 `src/components/PageBuilder/Coupon.vue`（优惠券组件）
  - 创建 `src/components/PageBuilder/Notice.vue`（公告组件）
  - _需求: 需求 9_

- [ ] 12.9.3 创建页面预览功能
  - 创建 `src/views/page-builder/preview.vue`
  - 实现实时预览功能
  - 实现移动端适配预览
  - _需求: 需求 9_


### 12.10 其他管理页面

- [ ] 12.10.1 创建评论管理页面
  - 创建 `src/views/review/list.vue`
  - 实现评论列表展示
  - 实现评论审核功能
  - 实现商家回复功能
  - _需求: 需求 10_

- [ ] 12.10.2 创建广告管理页面
  - 创建 `src/views/advertisement/list.vue`
  - 实现广告列表展示
  - 实现广告创建/编辑表单
  - _需求: 需求 13_

- [ ] 12.10.3 创建销售统计页面
  - 创建 `src/views/statistics/overview.vue`（概览）
  - 创建 `src/views/statistics/sales.vue`（销售报表）
  - 创建 `src/views/statistics/products.vue`（商品统计）
  - 使用 ECharts 实现图表展示（折线图、饼图、柱状图）
  - _需求: 需求 14_

- [ ] 12.10.4 创建仪表盘页面
  - 创建 `src/views/dashboard/index.vue`
  - 实现关键指标展示（销售额、订单数、用户数）
  - 实现销售趋势图表
  - 实现待处理事项提醒（待审核订单、待处理售后）
  - _需求: 需求 1-19_

---

## 阶段 13: 小程序前端（奈雪的茶风格）

### 13.1 项目初始化

- [ ] 13.1.1 创建微信小程序项目
  - 使用微信开发者工具创建项目
  - 安装 Vant Weapp 组件库
  - 配置 TypeScript
  - 配置主题色（粉色系）
  - _需求: 需求 15_

- [ ] 13.1.2 配置全局样式
  - 创建 `styles/theme.scss`（主题色、字体、间距）
  - 创建 `styles/common.scss`（通用样式）
  - 配置奈雪的茶风格（粉色系、清新风格）
  - _需求: 需求 15_

- [ ] 13.1.3 封装请求工具
  - 创建 `utils/request.ts`（封装 wx.request）
  - 实现请求拦截（添加 token）
  - 实现响应拦截（错误处理）
  - _需求: 需求 15_

### 13.2 核心页面

- [ ] 13.2.1 创建首页
  - 创建 `pages/index/index.wxml`
  - 实现搜索栏
  - 实现轮播图（根据页面配置）
  - 实现分类导航
  - 实现商品列表（瀑布流）
  - 实现优惠券入口
  - _需求: 需求 15, 需求 9_

- [ ] 13.2.2 创建分类页
  - 创建 `pages/category/index.wxml`
  - 实现左侧分类导航
  - 实现右侧商品列表
  - _需求: 需求 15_

- [ ] 13.2.3 创建商品详情页
  - 创建 `pages/product/detail.wxml`
  - 实现商品图片轮播
  - 实现商品信息展示（价格、销量、评分）
  - 实现 SKU 选择器组件
  - 实现商品详情（富文本）
  - 实现评论列表
  - 实现加入购物车和立即购买按钮
  - _需求: 需求 15_

- [ ] 13.2.4 创建购物车页
  - 创建 `pages/cart/index.wxml`
  - 实现购物车列表展示
  - 实现商品数量修改
  - 实现商品删除
  - 实现全选功能
  - 实现结算按钮
  - _需求: 需求 15_

### 13.3 订单相关页面

- [ ] 13.3.1 创建订单确认页
  - 创建 `pages/order/confirm.wxml`
  - 实现收货地址选择
  - 实现商品列表展示
  - 实现优惠券选择
  - 实现运费计算
  - 实现订单金额展示
  - 实现提交订单按钮
  - _需求: 需求 15_

- [ ] 13.3.2 创建支付页面
  - 创建 `pages/order/payment.wxml`
  - 实现支付方式选择（微信支付）
  - 实现支付按钮
  - 实现支付结果处理
  - _需求: 需求 15_

- [ ] 13.3.3 创建订单列表页
  - 创建 `pages/order/list.wxml`
  - 实现订单列表展示（全部、待支付、待发货、待收货、已完成）
  - 实现订单状态筛选
  - 实现订单操作（取消、确认收货、查看物流）
  - _需求: 需求 15_

- [ ] 13.3.4 创建订单详情页
  - 创建 `pages/order/detail.wxml`
  - 实现订单信息展示
  - 实现订单商品列表
  - 实现订单状态时间线
  - 实现订单操作（取消、确认收货、申请售后）
  - _需求: 需求 15_

### 13.4 用户中心页面

- [ ] 13.4.1 创建个人中心页
  - 创建 `pages/user/index.wxml`
  - 实现用户信息展示（头像、昵称）
  - 实现订单入口（待支付、待发货、待收货、已完成）
  - 实现功能入口（优惠券、收藏、地址、售后）
  - _需求: 需求 15_

- [ ] 13.4.2 创建个人信息页
  - 创建 `pages/user/profile.wxml`
  - 实现头像上传
  - 实现昵称、性别编辑
  - _需求: 需求 15_

- [ ] 13.4.3 创建地址管理页
  - 创建 `pages/user/address.wxml`
  - 实现地址列表展示
  - 实现地址增删改功能
  - 实现设为默认地址功能
  - _需求: 需求 15_

- [ ] 13.4.4 创建优惠券页
  - 创建 `pages/user/coupons.wxml`
  - 实现优惠券列表展示（未使用、已使用、已过期）
  - 实现优惠券筛选
  - _需求: 需求 15_

- [ ] 13.4.5 创建收藏页
  - 创建 `pages/user/favorites.wxml`
  - 实现收藏商品列表展示
  - 实现取消收藏功能
  - _需求: 需求 15_


### 13.5 售后相关页面

- [ ] 13.5.1 创建售后申请页
  - 创建 `pages/after-sales/apply.wxml`
  - 实现售后类型选择（仅退款、退货退款、换货）
  - 实现售后原因选择
  - 实现问题描述输入
  - 实现凭证图片上传
  - 实现提交按钮
  - _需求: 需求 15_

- [ ] 13.5.2 创建售后详情页
  - 创建 `pages/after-sales/detail.wxml`
  - 实现售后信息展示
  - 实现售后进度时间线
  - 实现填写退货物流功能
  - _需求: 需求 15_

### 13.6 小程序组件

- [ ] 13.6.1 创建商品卡片组件
  - 创建 `components/product-card/index.wxml`
  - 实现商品图片、名称、价格展示
  - 实现销量、评分展示
  - 实现活动标签（秒杀、拼团、限时折扣）
  - _需求: 需求 15_

- [ ] 13.6.2 创建 SKU 选择器组件
  - 创建 `components/sku-selector/index.wxml`
  - 实现规格选择
  - 实现数量选择
  - 实现价格、库存展示
  - 实现确认按钮
  - _需求: 需求 15_

- [ ] 13.6.3 创建订单时间线组件
  - 创建 `components/order-timeline/index.wxml`
  - 实现时间线展示（下单、支付、发货、收货）
  - 实现状态图标和时间显示
  - _需求: 需求 15_

- [ ] 13.6.4 创建地址选择器组件
  - 创建 `components/address-selector/index.wxml`
  - 实现地址列表展示
  - 实现地址选择功能
  - 实现新增地址入口
  - _需求: 需求 15_

- [ ] 13.6.5 创建优惠券选择器组件
  - 创建 `components/coupon-selector/index.wxml`
  - 实现可用优惠券列表展示
  - 实现优惠券选择功能
  - 实现优惠金额计算
  - _需求: 需求 15_

---

## 阶段 14: H5 前端

### 14.1 项目初始化

- [ ] 14.1.1 创建 Vue3 H5 项目
  - 使用 Vite 创建项目（`npm create vite@latest ecom-h5 -- --template vue-ts`）
  - 安装依赖（Vant、Vue Router、Pinia、Axios）
  - 配置 TypeScript
  - 配置移动端适配（viewport、rem）
  - _需求: 需求 15_

- [ ] 14.1.2 配置路由和状态管理
  - 配置 Vue Router
  - 配置 Pinia
  - 配置 Axios
  - _需求: 需求 15_

- [ ] 14.1.3 配置全局样式
  - 创建 `src/styles/theme.scss`（主题色、字体、间距）
  - 配置奈雪的茶风格（粉色系）
  - _需求: 需求 15_

### 14.2 核心页面（复用小程序页面逻辑）

- [ ] 14.2.1 创建首页
  - 创建 `src/views/index/index.vue`
  - 实现搜索栏、轮播图、分类导航、商品列表
  - _需求: 需求 15_

- [ ] 14.2.2 创建分类页
  - 创建 `src/views/category/index.vue`
  - 实现分类导航和商品列表
  - _需求: 需求 15_

- [ ] 14.2.3 创建商品详情页
  - 创建 `src/views/product/detail.vue`
  - 实现商品信息展示、SKU 选择、评论列表
  - _需求: 需求 15_

- [ ] 14.2.4 创建购物车页
  - 创建 `src/views/cart/index.vue`
  - 实现购物车列表、数量修改、结算
  - _需求: 需求 15_

- [ ] 14.2.5 创建订单相关页面
  - 创建 `src/views/order/confirm.vue`（订单确认）
  - 创建 `src/views/order/list.vue`（订单列表）
  - 创建 `src/views/order/detail.vue`（订单详情）
  - _需求: 需求 15_

- [ ] 14.2.6 创建用户中心页面
  - 创建 `src/views/user/index.vue`（个人中心）
  - 创建 `src/views/user/profile.vue`（个人信息）
  - 创建 `src/views/user/address.vue`（地址管理）
  - 创建 `src/views/user/coupons.vue`（优惠券）
  - 创建 `src/views/user/favorites.vue`（收藏）
  - _需求: 需求 15_

- [ ] 14.2.7 创建售后相关页面
  - 创建 `src/views/after-sales/apply.vue`（售后申请）
  - 创建 `src/views/after-sales/detail.vue`（售后详情）
  - _需求: 需求 15_

---

## 阶段 15: 集成测试与优化

### 15.1 后端集成测试

- [ ]* 15.1.1 编写商品模块集成测试
  - 测试商品创建、更新、删除流程
  - 测试商品列表查询和筛选
  - 测试 SKU 管理
  - _需求: 需求 1_

- [ ]* 15.1.2 编写订单模块集成测试
  - 测试订单创建流程（库存扣减 + 优惠券核销）
  - 测试订单支付流程
  - 测试订单取消流程（库存释放）
  - 测试订单拆单流程
  - _需求: 需求 2, 需求 17_

- [ ]* 15.1.3 编写支付模块集成测试
  - 测试支付创建流程
  - 测试支付回调处理（幂等性）
  - 测试退款流程
  - _需求: 需求 3_

- [ ]* 15.1.4 编写营销模块集成测试
  - 测试秒杀活动流程
  - 测试拼团活动流程
  - 测试优惠券领取和使用流程
  - _需求: 需求 6, 需求 7_


### 15.2 性能优化

- [ ] 15.2.1 数据库优化
  - 优化慢查询（使用 EXPLAIN 分析）
  - 添加缺失的索引
  - 优化 N+1 查询（使用关系预加载）
  - 配置数据库连接池
  - _需求: 需求 18_

- [ ] 15.2.2 缓存优化
  - 实现热点数据缓存（商品、分类、配置）
  - 实现查询结果缓存（5-30 分钟 TTL）
  - 实现缓存预热（系统启动时）
  - 实现缓存失效策略（写入时失效）
  - _需求: 需求 18_

- [ ] 15.2.3 接口优化
  - 实现接口限流（全局 1000 QPS、用户 100 QPS）
  - 实现接口防重放（基于时间戳 + 签名）
  - 优化接口响应时间（P95 < 500ms）
  - _需求: 需求 18_

- [ ] 15.2.4 前端优化
  - 实现图片懒加载
  - 实现路由懒加载
  - 实现组件懒加载
  - 配置 CDN 加速静态资源
  - 实现 Gzip 压缩
  - _需求: 需求 18_

### 15.3 安全加固

- [ ] 15.3.1 SQL 注入防护
  - 检查所有 SQL 查询是否使用参数化查询
  - 禁用 rawExec（代码审查）
  - _需求: 需求 18_

- [ ] 15.3.2 XSS 防护
  - 前端输入过滤和转义
  - 后端输出转义
  - 配置 CSP（Content Security Policy）
  - _需求: 需求 18_

- [ ] 15.3.3 CSRF 防护
  - 实现 CSRF Token 验证
  - 配置 SameSite Cookie
  - _需求: 需求 18_

- [ ] 15.3.4 敏感数据加密
  - 密码使用 bcrypt 加密
  - 支付信息使用 AES 加密
  - 配置 HTTPS
  - _需求: 需求 18_

### 15.4 压力测试

- [ ]* 15.4.1 订单创建压力测试
  - 使用 JMeter/Locust 进行压力测试
  - 测试并发下单场景（1000 QPS）
  - 验证库存扣减的正确性
  - _需求: 需求 18_

- [ ]* 15.4.2 秒杀活动压力测试
  - 测试秒杀并发场景（5000 QPS）
  - 验证分布式锁的有效性
  - 验证库存不超卖
  - _需求: 需求 6, 需求 18_

- [ ]* 15.4.3 支付回调压力测试
  - 测试支付回调并发场景
  - 验证幂等性处理
  - _需求: 需求 3, 需求 18_

---

## 阶段 16: 部署与上线

### 16.1 环境准备

- [ ] 16.1.1 准备生产环境服务器
  - 购买云服务器（阿里云/腾讯云）
  - 配置安全组（开放 80、443、3306、6379 端口）
  - 安装 Docker 和 Docker Compose
  - _需求: 需求 18_

- [ ] 16.1.2 配置数据库
  - 安装 MySQL 8.0+
  - 配置主从复制（1 主 2 从）
  - 执行数据库迁移脚本
  - 配置数据库备份（每天凌晨 2 点）
  - _需求: 需求 18_

- [ ] 16.1.3 配置 Redis
  - 安装 Redis 6.0+
  - 配置哨兵模式（1 主 2 从）
  - 配置持久化（AOF + RDB）
  - _需求: 需求 18_

- [ ] 16.1.4 配置消息队列
  - 安装 RabbitMQ 3.12+
  - 配置集群模式
  - 创建队列和交换机
  - _需求: 需求 18_

### 16.2 应用部署

- [ ] 16.2.1 构建后端 Docker 镜像
  - 创建 Dockerfile
  - 构建 Zig 应用镜像
  - 推送到镜像仓库
  - _需求: 需求 18_

- [ ] 16.2.2 部署后端应用
  - 创建 docker-compose.yml
  - 配置环境变量（数据库、Redis、支付密钥等）
  - 启动应用容器（3 个实例）
  - 配置健康检查
  - _需求: 需求 18_

- [ ] 16.2.3 配置 Nginx 负载均衡
  - 安装 Nginx
  - 配置负载均衡（轮询策略）
  - 配置 HTTPS（Let's Encrypt）
  - 配置 Gzip 压缩
  - 配置静态资源缓存
  - _需求: 需求 18_

- [ ] 16.2.4 部署前端应用
  - 构建管理后台（`npm run build`）
  - 构建 H5（`npm run build`）
  - 上传到 Nginx 静态目录
  - 配置 CDN 加速
  - _需求: 需求 18_

- [ ] 16.2.5 发布小程序
  - 配置小程序域名白名单
  - 上传小程序代码
  - 提交审核
  - 发布上线
  - _需求: 需求 15_

### 16.3 监控与日志

- [ ] 16.3.1 配置 Prometheus 监控
  - 安装 Prometheus
  - 配置应用指标采集（CPU、内存、磁盘、接口响应时间）
  - 配置告警规则（CPU > 80%、内存 > 80%、接口响应时间 > 1s）
  - _需求: 需求 18_

- [ ] 16.3.2 配置 Grafana 可视化
  - 安装 Grafana
  - 配置 Prometheus 数据源
  - 创建监控面板（系统指标、业务指标）
  - _需求: 需求 18_

- [ ] 16.3.3 配置 ELK 日志系统
  - 安装 Elasticsearch、Logstash、Kibana
  - 配置日志采集（应用日志、Nginx 日志）
  - 创建日志索引和查询面板
  - _需求: 需求 18_

### 16.4 CI/CD 配置

- [ ] 16.4.1 配置 GitHub Actions
  - 创建 `.github/workflows/deploy.yml`
  - 配置自动化测试（单元测试、集成测试）
  - 配置自动化构建（Docker 镜像）
  - 配置自动化部署（推送到生产环境）
  - _需求: 需求 18_

- [ ] 16.4.2 配置灰度发布
  - 配置金丝雀发布策略（10% → 50% → 100%）
  - 配置回滚机制
  - _需求: 需求 18_

---

## 阶段 17: 验收与交付

### 17.1 功能验收

- [ ] 17.1.1 商品管理功能验收
  - 验证商品创建、编辑、删除功能
  - 验证 SKU 管理功能
  - 验证商品上下架功能
  - 验证商品搜索和筛选功能
  - _需求: 需求 1_

- [ ] 17.1.2 订单管理功能验收
  - 验证订单创建流程
  - 验证订单支付流程
  - 验证订单发货流程
  - 验证订单取消流程
  - 验证订单拆单功能
  - _需求: 需求 2, 需求 17_

- [ ] 17.1.3 支付功能验收
  - 验证微信支付功能
  - 验证支付宝支付功能
  - 验证支付回调处理
  - 验证退款功能
  - _需求: 需求 3_

- [ ] 17.1.4 物流功能验收
  - 验证运费计算功能
  - 验证发货功能
  - 验证物流跟踪功能
  - _需求: 需求 4_

- [ ] 17.1.5 售后功能验收
  - 验证售后申请流程
  - 验证售后审核流程
  - 验证退款流程
  - _需求: 需求 5_

- [ ] 17.1.6 营销功能验收
  - 验证秒杀活动功能
  - 验证拼团活动功能
  - 验证满减活动功能
  - 验证优惠券功能
  - _需求: 需求 6, 需求 7_

- [ ] 17.1.7 其他功能验收
  - 验证短信发送功能
  - 验证页面搭建功能
  - 验证评论管理功能
  - 验证推广管理功能
  - 验证销售统计功能
  - _需求: 需求 8-14_


### 17.2 性能验收

- [ ] 17.2.1 接口性能验收
  - 验证接口响应时间 P95 < 500ms
  - 验证数据库查询响应时间 < 100ms
  - 验证页面加载时间 < 2s
  - _需求: 需求 18_

- [ ] 17.2.2 并发性能验收
  - 验证系统支持 1000 QPS
  - 验证秒杀场景支持 5000 QPS
  - 验证库存扣减不超卖
  - _需求: 需求 18_

### 17.3 安全验收

- [ ] 17.3.1 SQL 注入测试
  - 使用 SQLMap 进行 SQL 注入测试
  - 验证所有接口无 SQL 注入漏洞
  - _需求: 需求 18_

- [ ] 17.3.2 XSS 测试
  - 使用 XSStrike 进行 XSS 测试
  - 验证所有输入点无 XSS 漏洞
  - _需求: 需求 18_

- [ ] 17.3.3 CSRF 测试
  - 验证所有写操作有 CSRF Token 验证
  - _需求: 需求 18_

- [ ] 17.3.4 敏感数据加密测试
  - 验证密码已加密存储
  - 验证支付信息已加密存储
  - 验证 HTTPS 配置正确
  - _需求: 需求 18_

### 17.4 文档交付

- [ ] 17.4.1 编写部署文档
  - 编写环境准备文档
  - 编写应用部署文档
  - 编写配置说明文档
  - _需求: 需求 18_

- [ ] 17.4.2 编写运维文档
  - 编写监控告警文档
  - 编写日志查询文档
  - 编写故障排查文档
  - 编写备份恢复文档
  - _需求: 需求 18_

- [ ] 17.4.3 编写 API 文档
  - 使用 Swagger 生成 API 文档
  - 编写接口调用示例
  - 编写错误码说明
  - _需求: 需求 1-19_

- [ ] 17.4.4 编写用户手册
  - 编写管理后台使用手册
  - 编写小程序使用手册
  - 编写常见问题解答
  - _需求: 需求 1-19_

---

## 检查点

### 检查点 1: 基础设施完成
- 确保数据库迁移脚本执行成功
- 确保 DI 容器配置正确
- 确保分布式锁、幂等性管理器、JSON 解析器实现正确
- 确保所有基础设施单元测试通过

### 检查点 2: 核心模块完成
- 确保商品、库存、订单、支付、物流、售后模块实现完成
- 确保所有模块遵循 ZigCMS 架构规范（domain、application、infrastructure、api 分层）
- 确保所有 SQL 查询使用参数化查询
- 确保所有 ORM 查询结果正确释放内存
- 确保所有模块单元测试通过

### 检查点 3: 营销模块完成
- 确保秒杀、拼团、满减、优惠券功能实现完成
- 确保分布式锁防止超卖
- 确保幂等性处理正确
- 确保并发测试通过

### 检查点 4: 前端完成
- 确保管理后台所有页面实现完成
- 确保小程序所有页面实现完成
- 确保 H5 所有页面实现完成
- 确保前端与后端接口对接成功

### 检查点 5: 集成测试完成
- 确保所有核心流程集成测试通过
- 确保性能优化完成（接口响应时间、缓存策略）
- 确保安全加固完成（SQL 注入防护、XSS 防护、CSRF 防护）
- 确保压力测试通过（1000 QPS、秒杀 5000 QPS）

### 检查点 6: 部署上线
- 确保生产环境配置完成
- 确保应用部署成功
- 确保监控告警配置完成
- 确保 CI/CD 配置完成

### 检查点 7: 验收交付
- 确保所有功能验收通过
- 确保性能验收通过
- 确保安全验收通过
- 确保文档交付完成

---

## 注意事项

### 开发规范

1. **架构规范**
   - 严格遵循 ZigCMS 架构（domain、application、infrastructure、api 分层）
   - 所有数据库操作必须使用 ORM/QueryBuilder
   - 所有 SQL 查询必须使用参数化查询
   - 必须使用 DI 容器管理依赖
   - 必须使用关系预加载解决 N+1 查询问题

2. **内存管理规范**
   - 所有 ORM 查询结果必须使用 `defer freeModels()` 释放
   - 跨作用域使用字符串必须深拷贝（`allocator.dupe()`）
   - 推荐使用 Arena Allocator 简化批量内存管理
   - 全局资源（数据库连接、缓存连接）由系统级管理，应用层不得擅自销毁

3. **安全规范**
   - 所有 SQL 查询必须使用参数化查询（防止 SQL 注入）
   - 所有敏感数据必须加密存储（密码使用 bcrypt，支付信息使用 AES）
   - 所有接口必须进行权限验证
   - 所有外部输入必须进行校验和过滤
   - 支付回调必须验证签名

4. **性能规范**
   - 接口响应时间 P95 不超过 500ms
   - 数据库查询响应时间不超过 100ms
   - 页面加载时间不超过 2 秒
   - 热点数据必须缓存（Redis，TTL 5-30 分钟）

5. **并发安全规范**
   - 库存扣减必须使用分布式锁（Redis）+ 乐观锁（版本号）
   - 秒杀库存扣减必须使用分布式锁
   - 优惠券领取必须使用分布式锁
   - 支付回调处理必须幂等

### 测试规范

1. **单元测试**
   - 所有核心业务逻辑必须有单元测试
   - 测试覆盖率不低于 80%
   - 使用 `zig test` 运行测试

2. **集成测试**
   - 所有核心流程必须有集成测试
   - 测试订单创建、支付、发货、售后等完整流程

3. **压力测试**
   - 使用 JMeter/Locust 进行压力测试
   - 测试并发场景（1000 QPS、秒杀 5000 QPS）
   - 验证库存扣减的正确性

### 部署规范

1. **环境隔离**
   - 开发环境、测试环境、生产环境严格隔离
   - 使用不同的数据库和 Redis 实例

2. **配置管理**
   - 敏感配置（数据库密码、支付密钥）使用环境变量
   - 不同环境使用不同的配置文件

3. **灰度发布**
   - 使用金丝雀发布策略（10% → 50% → 100%）
   - 配置回滚机制

4. **监控告警**
   - 配置 Prometheus + Grafana 监控
   - 配置告警规则（CPU、内存、磁盘、接口响应时间）
   - 配置 ELK 日志系统

---

## 总结

本任务列表涵盖了电商系统的完整实现流程，从基础设施搭建、核心模块开发、前端页面实现、集成测试、部署上线到验收交付。任务遵循 ZigCMS 架构规范，确保代码安全、可维护、高性能。

**预计工期**：
- 阶段 1-11（后端核心模块）：2.5 个月
- 阶段 12（管理后台）：1 个月
- 阶段 13-14（小程序 + H5）：1.5 个月
- 阶段 15-17（测试、优化、部署）：1 个月
- **总计**：6 个月

**团队配置建议**：
- 后端开发：2-3 人
- 前端开发：2 人
- 测试：1 人
- 运维：1 人

老铁，任务列表已创建完成！包含 17 个阶段、200+ 个详细任务，覆盖数据库设计、后端模块、前端页面、集成测试和部署上线。所有任务都遵循 ZigCMS 架构规范，确保代码安全、可维护、高性能。

**后续建议**：
1. 优先实现核心模块（商品、订单、支付、库存），确保基础功能可用
2. 并行开发管理后台和小程序，提高开发效率
3. 每个阶段完成后进行检查点验收，确保质量
4. 定期进行代码审查，确保遵循开发规范
5. 提前准备生产环境，避免上线时手忙脚乱

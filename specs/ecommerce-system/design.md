# 商用电商系统设计文档

## 1. 系统架构设计

### 1.1 整体架构

本系统采用 ZigCMS 整洁架构 + DDD（领域驱动设计）+ 微服务架构，确保高内聚低耦合、可测试、可扩展。

```
┌─────────────────────────────────────────────────────────────┐
│                      前端层（Presentation）                  │
├─────────────────────────────────────────────────────────────┤
│  管理后台（Vue3 + Element Plus）                             │
│  小程序（微信小程序原生/Taro + Vant Weapp）                  │
│  H5（Vue3 + Vant）                                           │
└─────────────────────────────────────────────────────────────┘
                            ↓ HTTPS/WebSocket
┌─────────────────────────────────────────────────────────────┐
│                      API 网关层（Gateway）                   │
├─────────────────────────────────────────────────────────────┤
│  Nginx 负载均衡 + 限流 + 防重放                              │
│  JWT 认证 + RBAC 权限控制                                    │
└─────────────────────────────────────────────────────────────┘
                            ↓ HTTP/gRPC
┌─────────────────────────────────────────────────────────────┐
│                      应用服务层（Application）               │
├─────────────────────────────────────────────────────────────┤
│  商品服务 │ 订单服务 │ 支付服务 │ 物流服务 │ 售后服务       │
│  营销服务 │ 用户服务 │ 短信服务 │ 推广服务 │ 统计服务       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                      领域层（Domain）                        │
├─────────────────────────────────────────────────────────────┤
│  实体（Entity）│ 值对象（Value Object）│ 聚合根（Aggregate）│
│  领域服务（Domain Service）│ 仓储接口（Repository）         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                      基础设施层（Infrastructure）            │
├─────────────────────────────────────────────────────────────┤
│  数据库（MySQL）│ 缓存（Redis）│ 消息队列（RabbitMQ）       │
│  对象存储（OSS）│ 第三方服务（支付、短信、物流）             │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 技术栈

**后端**：
- 语言：Zig 0.13.0+
- 框架：ZigCMS（整洁架构 + DDD）
- 数据库：MySQL 8.0+（主从复制）
- ORM：ZigCMS ORM（支持关系预加载、参数化查询）
- 缓存：Redis 6.0+（哨兵模式）
- 消息队列：RabbitMQ 3.12+
- 对象存储：阿里云 OSS / 腾讯云 COS

**前端**：
- 管理后台：Vue 3.3+ + TypeScript + Element Plus + Vite
- 小程序：微信小程序原生 / Taro 3.0+ + Vant Weapp
- H5：Vue 3.3+ + Vant 4.0+ + Vite

**第三方服务**：
- 支付：微信支付 V3、支付宝开放平台
- 短信：阿里云短信、腾讯云短信
- 物流：快递鸟、快递100


## 2. 数据库设计

### 2.1 核心表结构

#### 2.1.1 商品相关表

**商品表（ecom_products）**
```sql
CREATE TABLE ecom_products (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '商品ID',
    spu_id VARCHAR(64) NOT NULL COMMENT 'SPU编号',
    name VARCHAR(255) NOT NULL COMMENT '商品名称',
    category_id BIGINT NOT NULL COMMENT '分类ID',
    type TINYINT NOT NULL DEFAULT 1 COMMENT '商品类型：1-实物 2-虚拟 3-CID',
    status TINYINT NOT NULL DEFAULT 0 COMMENT '状态：0-草稿 1-待审核 2-已通过 3-已拒绝 4-已上架 5-已下架',
    main_image VARCHAR(500) COMMENT '主图',
    images TEXT COMMENT '详情图（JSON数组）',
    description TEXT COMMENT '商品描述',
    cid_info TEXT COMMENT 'CID商品信息（JSON）',
    sales_count INT DEFAULT 0 COMMENT '销量',
    sort_order INT DEFAULT 0 COMMENT '排序',
    created_at BIGINT NOT NULL COMMENT '创建时间',
    updated_at BIGINT NOT NULL COMMENT '更新时间',
    deleted_at BIGINT DEFAULT NULL COMMENT '删除时间',
    INDEX idx_category (category_id),
    INDEX idx_type_status (type, status),
    INDEX idx_spu (spu_id),
    INDEX idx_sales (sales_count DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商品表';
```

**SKU表（ecom_product_skus）**
```sql
CREATE TABLE ecom_product_skus (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT 'SKU ID',
    product_id BIGINT NOT NULL COMMENT '商品ID',
    sku_code VARCHAR(64) NOT NULL UNIQUE COMMENT 'SKU编码',
    price DECIMAL(10,2) NOT NULL COMMENT '价格',
    stock INT NOT NULL DEFAULT 0 COMMENT '库存',
    attrs TEXT COMMENT '规格属性（JSON）',
    image VARCHAR(500) COMMENT 'SKU图片',
    weight DECIMAL(10,2) DEFAULT 0 COMMENT '重量（kg）',
    volume DECIMAL(10,2) DEFAULT 0 COMMENT '体积（m³）',
    status TINYINT DEFAULT 1 COMMENT '状态：0-禁用 1-启用',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    INDEX idx_product (product_id),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='SKU表';
```

**商品分类表（ecom_categories）**
```sql
CREATE TABLE ecom_categories (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '分类ID',
    parent_id BIGINT DEFAULT 0 COMMENT '父分类ID',
    name VARCHAR(100) NOT NULL COMMENT '分类名称',
    level TINYINT NOT NULL DEFAULT 1 COMMENT '层级：1-一级 2-二级 3-三级',
    image VARCHAR(500) COMMENT '分类图片',
    sort_order INT DEFAULT 0 COMMENT '排序',
    status TINYINT DEFAULT 1 COMMENT '状态：0-禁用 1-启用',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    INDEX idx_parent (parent_id),
    INDEX idx_level (level)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商品分类表';
```

**库存表（ecom_inventories）**
```sql
CREATE TABLE ecom_inventories (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '库存ID',
    sku_id BIGINT NOT NULL UNIQUE COMMENT 'SKU ID',
    total_stock INT NOT NULL DEFAULT 0 COMMENT '总库存',
    available_stock INT NOT NULL DEFAULT 0 COMMENT '可用库存',
    locked_stock INT NOT NULL DEFAULT 0 COMMENT '锁定库存',
    sold_stock INT NOT NULL DEFAULT 0 COMMENT '已售库存',
    version INT NOT NULL DEFAULT 0 COMMENT '版本号（乐观锁）',
    alert_stock INT DEFAULT 10 COMMENT '预警库存',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    INDEX idx_sku (sku_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='库存表';
```


#### 2.1.2 订单相关表

**订单表（ecom_orders_{YYYYMM}）- 按月分表**
```sql
CREATE TABLE ecom_orders_202601 (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '订单ID',
    order_no VARCHAR(32) NOT NULL UNIQUE COMMENT '订单号',
    parent_order_no VARCHAR(32) COMMENT '主订单号（拆单时使用）',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态：1-待支付 2-待发货 3-待收货 4-已完成 5-已关闭',
    total_amount DECIMAL(10,2) NOT NULL COMMENT '订单总额',
    freight_amount DECIMAL(10,2) DEFAULT 0 COMMENT '运费',
    discount_amount DECIMAL(10,2) DEFAULT 0 COMMENT '优惠金额',
    paid_amount DECIMAL(10,2) NOT NULL COMMENT '实付金额',
    payment_method TINYINT COMMENT '支付方式：1-微信 2-支付宝',
    payment_time BIGINT COMMENT '支付时间',
    delivery_time BIGINT COMMENT '发货时间',
    finish_time BIGINT COMMENT '完成时间',
    close_time BIGINT COMMENT '关闭时间',
    close_reason VARCHAR(255) COMMENT '关闭原因',
    buyer_remark VARCHAR(500) COMMENT '买家备注',
    seller_remark VARCHAR(500) COMMENT '卖家备注',
    receiver_name VARCHAR(50) NOT NULL COMMENT '收货人',
    receiver_phone VARCHAR(20) NOT NULL COMMENT '收货电话',
    receiver_province VARCHAR(50) COMMENT '省',
    receiver_city VARCHAR(50) COMMENT '市',
    receiver_district VARCHAR(50) COMMENT '区',
    receiver_address VARCHAR(255) NOT NULL COMMENT '详细地址',
    is_split TINYINT DEFAULT 0 COMMENT '是否拆单：0-否 1-是',
    split_rule VARCHAR(50) COMMENT '拆单规则',
    promoter_id BIGINT COMMENT '推广员ID',
    commission_amount DECIMAL(10,2) DEFAULT 0 COMMENT '佣金金额',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    INDEX idx_order_no (order_no),
    INDEX idx_user_status (user_id, status),
    INDEX idx_parent (parent_order_no),
    INDEX idx_payment_time (payment_time),
    INDEX idx_created (created_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单表';
```

**订单商品表（ecom_order_items_{YYYYMM}）**
```sql
CREATE TABLE ecom_order_items_202601 (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '订单商品ID',
    order_id BIGINT NOT NULL COMMENT '订单ID',
    order_no VARCHAR(32) NOT NULL COMMENT '订单号',
    product_id BIGINT NOT NULL COMMENT '商品ID',
    sku_id BIGINT NOT NULL COMMENT 'SKU ID',
    product_name VARCHAR(255) NOT NULL COMMENT '商品名称',
    sku_attrs TEXT COMMENT 'SKU属性（JSON）',
    product_image VARCHAR(500) COMMENT '商品图片',
    price DECIMAL(10,2) NOT NULL COMMENT '单价',
    quantity INT NOT NULL COMMENT '数量',
    total_amount DECIMAL(10,2) NOT NULL COMMENT '小计',
    created_at BIGINT NOT NULL,
    INDEX idx_order (order_id),
    INDEX idx_order_no (order_no),
    INDEX idx_product (product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单商品表';
```

**订单状态日志表（ecom_order_status_logs）**
```sql
CREATE TABLE ecom_order_status_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '日志ID',
    order_id BIGINT NOT NULL COMMENT '订单ID',
    order_no VARCHAR(32) NOT NULL COMMENT '订单号',
    from_status TINYINT COMMENT '原状态',
    to_status TINYINT NOT NULL COMMENT '新状态',
    operator_type TINYINT NOT NULL COMMENT '操作人类型：1-用户 2-系统 3-管理员',
    operator_id BIGINT COMMENT '操作人ID',
    remark VARCHAR(500) COMMENT '备注',
    created_at BIGINT NOT NULL,
    INDEX idx_order (order_id),
    INDEX idx_order_no (order_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单状态日志表';
```


#### 2.1.3 支付相关表

**支付记录表（ecom_payments_{YYYYMM}）**
```sql
CREATE TABLE ecom_payments_202601 (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '支付ID',
    payment_no VARCHAR(32) NOT NULL UNIQUE COMMENT '支付流水号',
    order_id BIGINT NOT NULL COMMENT '订单ID',
    order_no VARCHAR(32) NOT NULL COMMENT '订单号',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    payment_method TINYINT NOT NULL COMMENT '支付方式：1-微信 2-支付宝',
    payment_channel VARCHAR(20) COMMENT '支付渠道：JSAPI/H5/APP',
    amount DECIMAL(10,2) NOT NULL COMMENT '支付金额',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态：1-待支付 2-支付成功 3-支付失败 4-已退款',
    third_party_no VARCHAR(64) COMMENT '第三方流水号',
    request_params TEXT COMMENT '请求参数（JSON）',
    response_params TEXT COMMENT '响应参数（JSON）',
    callback_data TEXT COMMENT '回调数据（JSON）',
    paid_at BIGINT COMMENT '支付时间',
    refund_amount DECIMAL(10,2) DEFAULT 0 COMMENT '退款金额',
    refund_at BIGINT COMMENT '退款时间',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    INDEX idx_payment_no (payment_no),
    INDEX idx_order (order_id),
    INDEX idx_order_no (order_no),
    INDEX idx_user (user_id),
    INDEX idx_third_party (third_party_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='支付记录表';
```

#### 2.1.4 物流相关表

**物流公司表（ecom_logistics_companies）**
```sql
CREATE TABLE ecom_logistics_companies (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '物流公司ID',
    name VARCHAR(100) NOT NULL COMMENT '公司名称',
    code VARCHAR(50) NOT NULL UNIQUE COMMENT '公司编码',
    website VARCHAR(255) COMMENT '官网',
    phone VARCHAR(20) COMMENT '客服电话',
    status TINYINT DEFAULT 1 COMMENT '状态：0-禁用 1-启用',
    sort_order INT DEFAULT 0 COMMENT '排序',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='物流公司表';
```

**运费模板表（ecom_freight_templates）**
```sql
CREATE TABLE ecom_freight_templates (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '模板ID',
    name VARCHAR(100) NOT NULL COMMENT '模板名称',
    charge_type TINYINT NOT NULL COMMENT '计费方式：1-按重量 2-按件数 3-按体积',
    first_unit DECIMAL(10,2) NOT NULL COMMENT '首重/首件/首体积',
    first_fee DECIMAL(10,2) NOT NULL COMMENT '首费',
    continue_unit DECIMAL(10,2) NOT NULL COMMENT '续重/续件/续体积',
    continue_fee DECIMAL(10,2) NOT NULL COMMENT '续费',
    free_condition TINYINT DEFAULT 0 COMMENT '包邮条件：0-不包邮 1-满额包邮 2-指定区域包邮',
    free_amount DECIMAL(10,2) DEFAULT 0 COMMENT '包邮金额',
    status TINYINT DEFAULT 1 COMMENT '状态：0-禁用 1-启用',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='运费模板表';
```

**物流跟踪表（ecom_logistics_tracks）**
```sql
CREATE TABLE ecom_logistics_tracks (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '跟踪ID',
    order_id BIGINT NOT NULL COMMENT '订单ID',
    order_no VARCHAR(32) NOT NULL COMMENT '订单号',
    logistics_company_id BIGINT NOT NULL COMMENT '物流公司ID',
    tracking_no VARCHAR(50) NOT NULL COMMENT '物流单号',
    status TINYINT DEFAULT 1 COMMENT '状态：1-已揽收 2-运输中 3-派送中 4-已签收 5-异常',
    tracks TEXT COMMENT '物流轨迹（JSON）',
    last_query_at BIGINT COMMENT '最后查询时间',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    INDEX idx_order (order_id),
    INDEX idx_tracking (tracking_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='物流跟踪表';
```

#### 2.1.5 售后相关表

**售后工单表（ecom_after_sales）**
```sql
CREATE TABLE ecom_after_sales (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '售后ID',
    after_sales_no VARCHAR(32) NOT NULL UNIQUE COMMENT '售后单号',
    order_id BIGINT NOT NULL COMMENT '订单ID',
    order_no VARCHAR(32) NOT NULL COMMENT '订单号',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    type TINYINT NOT NULL COMMENT '类型：1-仅退款 2-退货退款 3-换货',
    reason VARCHAR(255) NOT NULL COMMENT '售后原因',
    description TEXT COMMENT '问题描述',
    images TEXT COMMENT '凭证图片（JSON）',
    refund_amount DECIMAL(10,2) NOT NULL COMMENT '退款金额',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态：1-待审核 2-已通过 3-已拒绝 4-退货中 5-已完成',
    audit_remark VARCHAR(500) COMMENT '审核备注',
    audit_at BIGINT COMMENT '审核时间',
    return_logistics_company VARCHAR(100) COMMENT '退货物流公司',
    return_tracking_no VARCHAR(50) COMMENT '退货物流单号',
    finish_at BIGINT COMMENT '完成时间',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    INDEX idx_after_sales_no (after_sales_no),
    INDEX idx_order (order_id),
    INDEX idx_user_status (user_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='售后工单表';
```


#### 2.1.6 营销相关表

**营销活动表（ecom_marketing_activities）**
```sql
CREATE TABLE ecom_marketing_activities (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '活动ID',
    name VARCHAR(255) NOT NULL COMMENT '活动名称',
    type TINYINT NOT NULL COMMENT '类型：1-秒杀 2-拼团 3-满减 4-限时折扣',
    start_at BIGINT NOT NULL COMMENT '开始时间',
    end_at BIGINT NOT NULL COMMENT '结束时间',
    status TINYINT DEFAULT 1 COMMENT '状态：0-禁用 1-启用',
    rules TEXT COMMENT '活动规则（JSON）',
    product_ids TEXT COMMENT '参与商品ID（JSON）',
    user_limit INT DEFAULT 0 COMMENT '用户限购数量',
    total_limit INT DEFAULT 0 COMMENT '活动总限量',
    sold_count INT DEFAULT 0 COMMENT '已售数量',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    INDEX idx_type_status (type, status),
    INDEX idx_time (start_at, end_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='营销活动表';
```

**拼团记录表（ecom_group_buying）**
```sql
CREATE TABLE ecom_group_buying (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '拼团ID',
    activity_id BIGINT NOT NULL COMMENT '活动ID',
    leader_user_id BIGINT NOT NULL COMMENT '团长用户ID',
    required_count INT NOT NULL COMMENT '成团人数',
    current_count INT DEFAULT 1 COMMENT '当前人数',
    status TINYINT DEFAULT 1 COMMENT '状态：1-拼团中 2-拼团成功 3-拼团失败',
    expire_at BIGINT NOT NULL COMMENT '过期时间',
    success_at BIGINT COMMENT '成团时间',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    INDEX idx_activity (activity_id),
    INDEX idx_status (status),
    INDEX idx_expire (expire_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='拼团记录表';
```

**优惠券表（ecom_coupons）**
```sql
CREATE TABLE ecom_coupons (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '优惠券ID',
    name VARCHAR(255) NOT NULL COMMENT '优惠券名称',
    type TINYINT NOT NULL COMMENT '类型：1-满减券 2-折扣券 3-兑换券',
    discount_type TINYINT NOT NULL COMMENT '优惠类型：1-固定金额 2-折扣比例',
    discount_value DECIMAL(10,2) NOT NULL COMMENT '优惠值',
    min_amount DECIMAL(10,2) DEFAULT 0 COMMENT '使用门槛',
    total_count INT NOT NULL COMMENT '发放总量',
    received_count INT DEFAULT 0 COMMENT '已领取数量',
    used_count INT DEFAULT 0 COMMENT '已使用数量',
    per_user_limit INT DEFAULT 1 COMMENT '每人限领',
    scope_type TINYINT DEFAULT 1 COMMENT '适用范围：1-全场 2-指定分类 3-指定商品',
    scope_ids TEXT COMMENT '适用范围ID（JSON）',
    start_at BIGINT NOT NULL COMMENT '开始时间',
    end_at BIGINT NOT NULL COMMENT '结束时间',
    status TINYINT DEFAULT 1 COMMENT '状态：0-禁用 1-启用',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    INDEX idx_type_status (type, status),
    INDEX idx_time (start_at, end_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='优惠券表';
```

**用户优惠券表（ecom_user_coupons）**
```sql
CREATE TABLE ecom_user_coupons (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '用户优惠券ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    coupon_id BIGINT NOT NULL COMMENT '优惠券ID',
    status TINYINT DEFAULT 1 COMMENT '状态：1-未使用 2-已使用 3-已过期',
    order_id BIGINT COMMENT '使用订单ID',
    used_at BIGINT COMMENT '使用时间',
    expire_at BIGINT NOT NULL COMMENT '过期时间',
    created_at BIGINT NOT NULL,
    INDEX idx_user_status (user_id, status),
    INDEX idx_coupon (coupon_id),
    INDEX idx_expire (expire_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户优惠券表';
```

#### 2.1.7 短信相关表

**短信配置表（ecom_sms_configs）**
```sql
CREATE TABLE ecom_sms_configs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '配置ID',
    provider VARCHAR(50) NOT NULL COMMENT '服务商：aliyun/tencent',
    access_key VARCHAR(255) NOT NULL COMMENT 'AccessKey',
    secret_key VARCHAR(255) NOT NULL COMMENT 'SecretKey',
    sign_name VARCHAR(50) NOT NULL COMMENT '签名',
    status TINYINT DEFAULT 1 COMMENT '状态：0-禁用 1-启用',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='短信配置表';
```

**短信模板表（ecom_sms_templates）**
```sql
CREATE TABLE ecom_sms_templates (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '模板ID',
    name VARCHAR(100) NOT NULL COMMENT '模板名称',
    code VARCHAR(50) NOT NULL COMMENT '模板编码',
    content TEXT NOT NULL COMMENT '模板内容',
    scene VARCHAR(50) NOT NULL COMMENT '场景：register/login/order/delivery/after_sales',
    status TINYINT DEFAULT 1 COMMENT '状态：0-禁用 1-启用',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    INDEX idx_scene (scene)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='短信模板表';
```

**短信发送日志表（ecom_sms_logs）**
```sql
CREATE TABLE ecom_sms_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '日志ID',
    phone VARCHAR(20) NOT NULL COMMENT '手机号',
    template_id BIGINT NOT NULL COMMENT '模板ID',
    params TEXT COMMENT '参数（JSON）',
    status TINYINT NOT NULL COMMENT '状态：1-发送中 2-成功 3-失败',
    error_msg VARCHAR(500) COMMENT '错误信息',
    retry_count INT DEFAULT 0 COMMENT '重试次数',
    sent_at BIGINT COMMENT '发送时间',
    created_at BIGINT NOT NULL,
    INDEX idx_phone (phone),
    INDEX idx_template (template_id),
    INDEX idx_created (created_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='短信发送日志表';
```


#### 2.1.8 其他表

**评论表（ecom_reviews）**
```sql
CREATE TABLE ecom_reviews (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '评论ID',
    order_id BIGINT NOT NULL COMMENT '订单ID',
    product_id BIGINT NOT NULL COMMENT '商品ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    rating TINYINT NOT NULL COMMENT '评分：1-5星',
    content TEXT COMMENT '评论内容',
    images TEXT COMMENT '评论图片（JSON）',
    is_anonymous TINYINT DEFAULT 0 COMMENT '是否匿名：0-否 1-是',
    status TINYINT DEFAULT 1 COMMENT '状态：1-待审核 2-已通过 3-已拒绝',
    reply_content TEXT COMMENT '商家回复',
    reply_at BIGINT COMMENT '回复时间',
    likes_count INT DEFAULT 0 COMMENT '点赞数',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    INDEX idx_product_status (product_id, status),
    INDEX idx_user (user_id),
    INDEX idx_rating (rating)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评论表';
```

**推广员表（ecom_promoters）**
```sql
CREATE TABLE ecom_promoters (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '推广员ID',
    user_id BIGINT NOT NULL UNIQUE COMMENT '用户ID',
    level TINYINT DEFAULT 1 COMMENT '等级：1-普通 2-高级 3-超级',
    commission_rate DECIMAL(5,2) DEFAULT 0 COMMENT '佣金比例（%）',
    total_orders INT DEFAULT 0 COMMENT '推广订单数',
    total_amount DECIMAL(10,2) DEFAULT 0 COMMENT '推广金额',
    total_commission DECIMAL(10,2) DEFAULT 0 COMMENT '总佣金',
    available_commission DECIMAL(10,2) DEFAULT 0 COMMENT '可提现佣金',
    status TINYINT DEFAULT 1 COMMENT '状态：0-禁用 1-启用',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    INDEX idx_user (user_id),
    INDEX idx_level (level)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='推广员表';
```

**推广订单表（ecom_promoter_orders）**
```sql
CREATE TABLE ecom_promoter_orders (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '推广订单ID',
    order_id BIGINT NOT NULL COMMENT '订单ID',
    order_no VARCHAR(32) NOT NULL COMMENT '订单号',
    promoter_id BIGINT NOT NULL COMMENT '推广员ID',
    order_amount DECIMAL(10,2) NOT NULL COMMENT '订单金额',
    commission_rate DECIMAL(5,2) NOT NULL COMMENT '佣金比例',
    commission_amount DECIMAL(10,2) NOT NULL COMMENT '佣金金额',
    status TINYINT DEFAULT 1 COMMENT '状态：1-待结算 2-已结算',
    settled_at BIGINT COMMENT '结算时间',
    created_at BIGINT NOT NULL,
    INDEX idx_order (order_id),
    INDEX idx_promoter_status (promoter_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='推广订单表';
```

**页面配置表（ecom_page_configs）**
```sql
CREATE TABLE ecom_page_configs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '页面ID',
    name VARCHAR(100) NOT NULL COMMENT '页面名称',
    type VARCHAR(50) NOT NULL COMMENT '页面类型：home/activity',
    platform VARCHAR(20) NOT NULL COMMENT '平台：miniapp/h5',
    config TEXT NOT NULL COMMENT '页面配置（JSON）',
    status TINYINT DEFAULT 0 COMMENT '状态：0-草稿 1-已发布',
    published_at BIGINT COMMENT '发布时间',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    INDEX idx_type_platform (type, platform),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='页面配置表';
```

**广告表（ecom_advertisements）**
```sql
CREATE TABLE ecom_advertisements (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '广告ID',
    name VARCHAR(100) NOT NULL COMMENT '广告名称',
    position VARCHAR(50) NOT NULL COMMENT '广告位：home_banner/category_banner/detail_banner',
    image VARCHAR(500) NOT NULL COMMENT '广告图片',
    link VARCHAR(500) COMMENT '跳转链接',
    sort_order INT DEFAULT 0 COMMENT '排序',
    start_at BIGINT NOT NULL COMMENT '开始时间',
    end_at BIGINT NOT NULL COMMENT '结束时间',
    click_count INT DEFAULT 0 COMMENT '点击量',
    status TINYINT DEFAULT 1 COMMENT '状态：0-禁用 1-启用',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    INDEX idx_position_status (position, status),
    INDEX idx_time (start_at, end_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='广告表';
```

### 2.2 索引优化策略

1. **主键索引**：所有表使用 BIGINT 自增主键
2. **唯一索引**：订单号、支付流水号、SKU编码等唯一字段
3. **复合索引**：高频查询组合（user_id + status、type + status）
4. **覆盖索引**：查询字段包含在索引中，避免回表
5. **前缀索引**：长字符串字段使用前缀索引

### 2.3 分表策略

**按月分表**：
- 订单表：ecom_orders_{YYYYMM}
- 订单商品表：ecom_order_items_{YYYYMM}
- 支付记录表：ecom_payments_{YYYYMM}

**分表规则**：
- 根据 created_at 字段按月分表
- 保留最近 12 个月数据在线，历史数据归档
- 使用中间件（ShardingSphere）实现分表路由


## 3. API 设计

### 3.1 RESTful API 规范

**基础路径**：`/api/v1`

**响应格式**：
```json
{
  "code": 0,
  "message": "success",
  "data": { ... },
  "timestamp": 1704067200
}
```

**错误码**：
- 0: 成功
- 1001: 库存不足
- 1002: 商品不存在
- 1003: 订单不存在
- 1004: 支付失败
- 1005: 优惠券不可用
- 1006: 权限不足
- 1007: 参数错误
- 1008: 系统错误
- 1009: 频率限制
- 1010: 签名验证失败

### 3.2 核心接口设计

#### 3.2.1 商品接口

```
GET    /api/v1/products              # 商品列表
GET    /api/v1/products/:id          # 商品详情
POST   /api/v1/products              # 创建商品
PUT    /api/v1/products/:id          # 更新商品
DELETE /api/v1/products/:id          # 删除商品
PUT    /api/v1/products/:id/status   # 上下架
POST   /api/v1/products/import       # 批量导入
GET    /api/v1/products/:id/skus     # SKU列表
POST   /api/v1/products/:id/skus     # 添加SKU
PUT    /api/v1/products/skus/:id     # 更新SKU
DELETE /api/v1/products/skus/:id     # 删除SKU
```

#### 3.2.2 订单接口

```
GET    /api/v1/orders                # 订单列表
GET    /api/v1/orders/:id            # 订单详情
POST   /api/v1/orders                # 创建订单
PUT    /api/v1/orders/:id/cancel     # 取消订单
PUT    /api/v1/orders/:id/confirm    # 确认收货
GET    /api/v1/orders/:id/timeline   # 订单时间线
POST   /api/v1/orders/export         # 导出订单
```

#### 3.2.3 支付接口

```
POST   /api/v1/payments/wechat       # 微信支付
POST   /api/v1/payments/alipay       # 支付宝支付
POST   /api/v1/payments/callback/wechat   # 微信回调
POST   /api/v1/payments/callback/alipay   # 支付宝回调
GET    /api/v1/payments/:id          # 支付详情
POST   /api/v1/payments/:id/refund   # 申请退款
```

#### 3.2.4 物流接口

```
GET    /api/v1/logistics/companies   # 物流公司列表
POST   /api/v1/logistics/companies   # 添加物流公司
GET    /api/v1/logistics/templates   # 运费模板列表
POST   /api/v1/logistics/templates   # 创建运费模板
POST   /api/v1/logistics/calculate   # 计算运费
GET    /api/v1/logistics/track/:order_id  # 查询物流
POST   /api/v1/logistics/ship        # 发货
```

#### 3.2.5 售后接口

```
GET    /api/v1/after-sales           # 售后列表
GET    /api/v1/after-sales/:id       # 售后详情
POST   /api/v1/after-sales           # 申请售后
PUT    /api/v1/after-sales/:id/audit # 审核售后
PUT    /api/v1/after-sales/:id/return # 填写退货物流
PUT    /api/v1/after-sales/:id/confirm # 确认收货
```

#### 3.2.6 营销接口

```
GET    /api/v1/activities            # 活动列表
POST   /api/v1/activities            # 创建活动
GET    /api/v1/activities/:id        # 活动详情
POST   /api/v1/activities/:id/join   # 参与活动
GET    /api/v1/group-buying/:id      # 拼团详情
POST   /api/v1/group-buying/:id/join # 参与拼团
```

#### 3.2.7 优惠券接口

```
GET    /api/v1/coupons               # 优惠券列表
POST   /api/v1/coupons               # 创建优惠券
POST   /api/v1/coupons/:id/receive  # 领取优惠券
GET    /api/v1/user/coupons          # 我的优惠券
POST   /api/v1/coupons/match         # 匹配可用优惠券
```

### 3.3 认证授权

**JWT Token 结构**：
```json
{
  "user_id": 123,
  "username": "user@example.com",
  "role": "user",
  "exp": 1704067200
}
```

**权限控制（RBAC）**：
- 角色：超级管理员、管理员、商家、用户、推广员
- 权限：商品管理、订单管理、用户管理、系统配置等
- 中间件：JWT验证 + 权限检查

### 3.4 接口限流

**限流策略**：
- 全局限流：1000 QPS
- 用户限流：100 QPS/用户
- IP限流：200 QPS/IP
- 接口限流：特定接口单独配置

**实现方式**：
- Redis + 滑动窗口算法
- 令牌桶算法（高峰期）


## 4. 核心模块设计

### 4.1 商品管理模块

#### 4.1.1 领域模型

```zig
// src/domain/entities/product.model.zig
pub const Product = struct {
    id: ?i64 = null,
    spu_id: []const u8,
    name: []const u8,
    category_id: i64,
    type: ProductType,
    status: ProductStatus,
    main_image: ?[]const u8 = null,
    images: ?[][]const u8 = null,
    description: ?[]const u8 = null,
    cid_info: ?CIDInfo = null,
    sales_count: i32 = 0,
    created_at: i64,
    updated_at: i64,
    
    // 关联数据
    skus: ?[]SKU = null,
    category: ?Category = null,
    
    pub const ProductType = enum(u8) {
        physical = 1,
        virtual = 2,
        cid = 3,
    };
    
    pub const ProductStatus = enum(u8) {
        draft = 0,
        pending = 1,
        approved = 2,
        rejected = 3,
        online = 4,
        offline = 5,
    };
    
    pub const CIDInfo = struct {
        cid: []const u8,
        coupon_link: ?[]const u8 = null,
        commission_rate: f32,
    };
    
    // 关系定义
    pub const relations = .{
        .skus = .{
            .type = .has_many,
            .model = SKU,
            .foreign_key = "product_id",
        },
        .category = .{
            .type = .belongs_to,
            .model = Category,
            .foreign_key = "category_id",
        },
    };
    
    // 业务方法
    pub fn canDelete(self: *const Product) bool {
        return self.status == .draft or self.status == .offline;
    }
    
    pub fn isOnline(self: *const Product) bool {
        return self.status == .online;
    }
    
    pub fn needsLogistics(self: *const Product) bool {
        return self.type == .physical;
    }
};

pub const SKU = struct {
    id: ?i64 = null,
    product_id: i64,
    sku_code: []const u8,
    price: f64,
    stock: i32,
    attrs: ?[]Attribute = null,
    image: ?[]const u8 = null,
    weight: f64 = 0,
    volume: f64 = 0,
    status: SKUStatus,
    created_at: i64,
    updated_at: i64,
    
    pub const SKUStatus = enum(u8) {
        disabled = 0,
        enabled = 1,
    };
    
    pub const Attribute = struct {
        name: []const u8,
        value: []const u8,
    };
};
```

#### 4.1.2 仓储接口

```zig
// src/domain/repositories/product_repository.zig
pub const ProductRepository = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    
    pub const VTable = struct {
        findById: *const fn (*anyopaque, i64) anyerror!?Product,
        findByIdWithSKUs: *const fn (*anyopaque, i64) anyerror!?Product,
        save: *const fn (*anyopaque, *Product) anyerror!void,
        delete: *const fn (*anyopaque, i64) anyerror!void,
        list: *const fn (*anyopaque, ListParams) anyerror!PageResult(Product),
        updateStatus: *const fn (*anyopaque, i64, ProductStatus) anyerror!void,
        checkHasUnfinishedOrders: *const fn (*anyopaque, i64) anyerror!bool,
    };
    
    pub const ListParams = struct {
        page: i32 = 1,
        page_size: i32 = 20,
        keyword: ?[]const u8 = null,
        category_id: ?i64 = null,
        type: ?ProductType = null,
        status: ?ProductStatus = null,
        sort_by: SortBy = .created_at,
        sort_order: SortOrder = .desc,
    };
    
    pub const SortBy = enum {
        created_at,
        sales_count,
        price,
    };
    
    pub const SortOrder = enum {
        asc,
        desc,
    };
};
```

#### 4.1.3 应用服务

```zig
// src/application/services/product_service.zig
pub const ProductService = struct {
    allocator: Allocator,
    product_repo: ProductRepository,
    sku_repo: SKURepository,
    inventory_repo: InventoryRepository,
    cache: *CacheInterface,
    
    pub fn createProduct(self: *Self, dto: CreateProductDto) !Product {
        // 1. 验证分类存在
        // 2. 创建商品
        // 3. 创建SKU
        // 4. 初始化库存
        // 5. 清除缓存
        // 6. 记录操作日志
    }
    
    pub fn updateProduct(self: *Self, id: i64, dto: UpdateProductDto) !void {
        // 1. 查询商品
        // 2. 验证状态
        // 3. 更新商品
        // 4. 更新SKU
        // 5. 清除缓存
    }
    
    pub fn deleteProduct(self: *Self, id: i64) !void {
        // 1. 查询商品
        // 2. 检查是否有未完成订单
        // 3. 删除商品
        // 4. 删除SKU
        // 5. 清除缓存
    }
    
    pub fn updateStatus(self: *Self, id: i64, status: ProductStatus) !void {
        // 1. 验证状态流转
        // 2. 更新状态
        // 3. 记录日志
        // 4. 清除缓存
    }
    
    pub fn getProductDetail(self: *Self, id: i64) !?Product {
        // 1. 尝试从缓存获取
        // 2. 使用关系预加载查询（with SKUs）
        // 3. 缓存结果
    }
};
```

### 4.2 订单管理模块

#### 4.2.1 订单引擎设计

```zig
// src/domain/services/order_engine.zig
pub const OrderEngine = struct {
    allocator: Allocator,
    order_repo: OrderRepository,
    inventory_service: *InventoryService,
    coupon_service: *CouponService,
    freight_service: *FreightService,
    
    pub fn createOrder(self: *Self, dto: CreateOrderDto) !Order {
        // 1. 验证商品库存
        // 2. 验证优惠券
        // 3. 计算运费
        // 4. 计算订单金额
        // 5. 预占库存
        // 6. 锁定优惠券
        // 7. 创建订单（事务）
        // 8. 判断是否需要拆单
        // 9. 返回订单
    }
    
    pub fn splitOrder(self: *Self, order: *Order) ![]Order {
        // 1. 根据拆单规则分组商品
        // 2. 分摊优惠金额
        // 3. 分摊运费
        // 4. 创建子订单
        // 5. 记录拆单关系
    }
    
    pub fn cancelOrder(self: *Self, order_id: i64, reason: []const u8) !void {
        // 1. 查询订单
        // 2. 验证状态（只能取消待支付订单）
        // 3. 释放库存
        // 4. 退还优惠券
        // 5. 更新订单状态
        // 6. 记录状态日志
    }
    
    pub fn autoCloseExpiredOrders(self: *Self) !void {
        // 1. 查询超时未支付订单
        // 2. 批量关闭订单
        // 3. 释放库存
        // 4. 退还优惠券
    }
};
```

#### 4.2.2 订单状态机

```zig
// src/domain/value_objects/order_status.zig
pub const OrderStatus = enum(u8) {
    pending_payment = 1,
    pending_delivery = 2,
    pending_receipt = 3,
    completed = 4,
    closed = 5,
    
    pub fn canTransitionTo(self: OrderStatus, target: OrderStatus) bool {
        return switch (self) {
            .pending_payment => target == .pending_delivery or target == .closed,
            .pending_delivery => target == .pending_receipt or target == .closed,
            .pending_receipt => target == .completed or target == .closed,
            .completed => false,
            .closed => false,
        };
    }
    
    pub fn getNextStatus(self: OrderStatus, event: OrderEvent) ?OrderStatus {
        return switch (event) {
            .paid => if (self == .pending_payment) .pending_delivery else null,
            .shipped => if (self == .pending_delivery) .pending_receipt else null,
            .received => if (self == .pending_receipt) .completed else null,
            .cancelled => if (self == .pending_payment) .closed else null,
            .timeout => if (self == .pending_payment) .closed else null,
        };
    }
};

pub const OrderEvent = enum {
    paid,
    shipped,
    received,
    cancelled,
    timeout,
};
```

### 4.3 支付管理模块

#### 4.3.1 支付网关设计

```zig
// src/domain/services/payment_gateway.zig
pub const PaymentGateway = struct {
    allocator: Allocator,
    wechat_client: *WechatPayClient,
    alipay_client: *AlipayClient,
    payment_repo: PaymentRepository,
    order_service: *OrderService,
    
    pub fn createPayment(self: *Self, dto: CreatePaymentDto) !PaymentResult {
        // 1. 创建支付记录
        // 2. 调用第三方支付接口
        // 3. 记录请求参数
        // 4. 返回支付参数
    }
    
    pub fn handleCallback(self: *Self, method: PaymentMethod, data: []const u8) !void {
        // 1. 验证签名
        // 2. 解析回调数据
        // 3. 幂等性检查（防止重复处理）
        // 4. 更新支付状态
        // 5. 更新订单状态（事务）
        // 6. 扣减库存
        // 7. 核销优惠券
        // 8. 发送通知
    }
    
    pub fn refund(self: *Self, payment_id: i64, amount: f64, reason: []const u8) !void {
        // 1. 查询支付记录
        // 2. 验证退款金额
        // 3. 调用第三方退款接口
        // 4. 更新退款状态
        // 5. 记录退款流水
    }
    
    fn verifySignature(self: *Self, method: PaymentMethod, data: []const u8, signature: []const u8) !bool {
        // 验证签名逻辑
    }
};
```

#### 4.3.2 幂等性设计

```zig
// src/infrastructure/idempotency/idempotency_manager.zig
pub const IdempotencyManager = struct {
    cache: *CacheInterface,
    
    pub fn checkAndLock(self: *Self, key: []const u8, ttl: i64) !bool {
        // 使用 Redis SETNX 实现幂等性检查
        const lock_key = try std.fmt.allocPrint(self.allocator, "idempotency:{s}", .{key});
        defer self.allocator.free(lock_key);
        
        return try self.cache.setNX(lock_key, "1", ttl);
    }
    
    pub fn unlock(self: *Self, key: []const u8) !void {
        const lock_key = try std.fmt.allocPrint(self.allocator, "idempotency:{s}", .{key});
        defer self.allocator.free(lock_key);
        
        try self.cache.del(lock_key);
    }
};
```


### 4.4 库存管理模块

#### 4.4.1 库存服务设计

```zig
// src/application/services/inventory_service.zig
pub const InventoryService = struct {
    allocator: Allocator,
    inventory_repo: InventoryRepository,
    redis: *RedisClient,
    
    pub fn lockStock(self: *Self, sku_id: i64, quantity: i32) !bool {
        // 1. 获取分布式锁
        const lock_key = try std.fmt.allocPrint(self.allocator, "lock:inventory:{d}", .{sku_id});
        defer self.allocator.free(lock_key);
        
        const lock = try self.redis.lock(lock_key, 5000); // 5秒超时
        defer lock.unlock();
        
        // 2. 查询库存（使用乐观锁）
        var inventory = try self.inventory_repo.findBySKU(sku_id) orelse return false;
        
        // 3. 检查库存是否充足
        if (inventory.available_stock < quantity) {
            return false;
        }
        
        // 4. 预占库存（使用版本号乐观锁）
        inventory.available_stock -= quantity;
        inventory.locked_stock += quantity;
        inventory.version += 1;
        
        // 5. 更新库存
        const success = try self.inventory_repo.updateWithVersion(&inventory);
        return success;
    }
    
    pub fn releaseStock(self: *Self, sku_id: i64, quantity: i32) !void {
        // 1. 获取分布式锁
        const lock_key = try std.fmt.allocPrint(self.allocator, "lock:inventory:{d}", .{sku_id});
        defer self.allocator.free(lock_key);
        
        const lock = try self.redis.lock(lock_key, 5000);
        defer lock.unlock();
        
        // 2. 查询库存
        var inventory = try self.inventory_repo.findBySKU(sku_id) orelse return error.InventoryNotFound;
        
        // 3. 释放库存
        inventory.available_stock += quantity;
        inventory.locked_stock -= quantity;
        inventory.version += 1;
        
        // 4. 更新库存
        _ = try self.inventory_repo.updateWithVersion(&inventory);
    }
    
    pub fn deductStock(self: *Self, sku_id: i64, quantity: i32) !void {
        // 1. 获取分布式锁
        const lock_key = try std.fmt.allocPrint(self.allocator, "lock:inventory:{d}", .{sku_id});
        defer self.allocator.free(lock_key);
        
        const lock = try self.redis.lock(lock_key, 5000);
        defer lock.unlock();
        
        // 2. 查询库存
        var inventory = try self.inventory_repo.findBySKU(sku_id) orelse return error.InventoryNotFound;
        
        // 3. 扣减库存
        inventory.locked_stock -= quantity;
        inventory.sold_stock += quantity;
        inventory.version += 1;
        
        // 4. 更新库存
        _ = try self.inventory_repo.updateWithVersion(&inventory);
        
        // 5. 检查库存预警
        if (inventory.available_stock < inventory.alert_stock) {
            try self.sendStockAlert(sku_id, inventory.available_stock);
        }
    }
};
```

#### 4.4.2 分布式锁实现

```zig
// src/infrastructure/redis/distributed_lock.zig
pub const DistributedLock = struct {
    redis: *RedisClient,
    key: []const u8,
    value: []const u8,
    ttl: i64,
    
    pub fn acquire(redis: *RedisClient, key: []const u8, ttl: i64) !DistributedLock {
        const value = try generateUUID();
        const success = try redis.setNX(key, value, ttl);
        
        if (!success) {
            return error.LockAcquireFailed;
        }
        
        return DistributedLock{
            .redis = redis,
            .key = key,
            .value = value,
            .ttl = ttl,
        };
    }
    
    pub fn unlock(self: *DistributedLock) !void {
        // 使用 Lua 脚本确保原子性
        const script =
            \\if redis.call("get", KEYS[1]) == ARGV[1] then
            \\    return redis.call("del", KEYS[1])
            \\else
            \\    return 0
            \\end
        ;
        
        _ = try self.redis.eval(script, &[_][]const u8{self.key}, &[_][]const u8{self.value});
    }
};
```

### 4.5 营销引擎模块

#### 4.5.1 秒杀活动设计

```zig
// src/application/services/seckill_service.zig
pub const SeckillService = struct {
    allocator: Allocator,
    redis: *RedisClient,
    activity_repo: ActivityRepository,
    order_service: *OrderService,
    
    pub fn preheatStock(self: *Self, activity_id: i64) !void {
        // 1. 查询活动信息
        const activity = try self.activity_repo.findById(activity_id) orelse return error.ActivityNotFound;
        
        // 2. 将库存预热到 Redis
        for (activity.products) |product| {
            const key = try std.fmt.allocPrint(self.allocator, "seckill:stock:{d}:{d}", .{ activity_id, product.id });
            defer self.allocator.free(key);
            
            try self.redis.set(key, product.stock);
        }
    }
    
    pub fn participate(self: *Self, user_id: i64, activity_id: i64, product_id: i64, quantity: i32) !Order {
        // 1. 检查用户限购
        const user_key = try std.fmt.allocPrint(self.allocator, "seckill:user:{d}:{d}", .{ activity_id, user_id });
        defer self.allocator.free(user_key);
        
        const user_count = try self.redis.get(user_key) orelse "0";
        if (std.fmt.parseInt(i32, user_count, 10) catch 0 >= activity.user_limit) {
            return error.ExceedUserLimit;
        }
        
        // 2. 扣减 Redis 库存（使用 Lua 脚本保证原子性）
        const stock_key = try std.fmt.allocPrint(self.allocator, "seckill:stock:{d}:{d}", .{ activity_id, product_id });
        defer self.allocator.free(stock_key);
        
        const script =
            \\local stock = redis.call('get', KEYS[1])
            \\if not stock or tonumber(stock) < tonumber(ARGV[1]) then
            \\    return 0
            \\end
            \\redis.call('decrby', KEYS[1], ARGV[1])
            \\return 1
        ;
        
        const result = try self.redis.eval(script, &[_][]const u8{stock_key}, &[_][]const u8{quantity});
        if (result == 0) {
            return error.StockInsufficient;
        }
        
        // 3. 创建订单
        const order = try self.order_service.createOrder(.{
            .user_id = user_id,
            .activity_id = activity_id,
            .product_id = product_id,
            .quantity = quantity,
        });
        
        // 4. 增加用户购买计数
        _ = try self.redis.incr(user_key);
        try self.redis.expire(user_key, 86400); // 24小时过期
        
        return order;
    }
};
```

#### 4.5.2 拼团活动设计

```zig
// src/application/services/group_buying_service.zig
pub const GroupBuyingService = struct {
    allocator: Allocator,
    group_repo: GroupBuyingRepository,
    order_service: *OrderService,
    
    pub fn createGroup(self: *Self, user_id: i64, activity_id: i64) !GroupBuying {
        // 1. 查询活动信息
        const activity = try self.activity_repo.findById(activity_id) orelse return error.ActivityNotFound;
        
        // 2. 创建拼团记录
        var group = GroupBuying{
            .activity_id = activity_id,
            .leader_user_id = user_id,
            .required_count = activity.required_count,
            .current_count = 1,
            .status = .in_progress,
            .expire_at = std.time.timestamp() + activity.time_limit,
            .created_at = std.time.timestamp(),
            .updated_at = std.time.timestamp(),
        };
        
        try self.group_repo.save(&group);
        
        // 3. 创建预付款订单
        _ = try self.order_service.createPrepayOrder(.{
            .user_id = user_id,
            .group_id = group.id.?,
            .activity_id = activity_id,
        });
        
        return group;
    }
    
    pub fn joinGroup(self: *Self, user_id: i64, group_id: i64) !void {
        // 1. 查询拼团记录
        var group = try self.group_repo.findById(group_id) orelse return error.GroupNotFound;
        
        // 2. 检查拼团状态
        if (group.status != .in_progress) {
            return error.GroupNotInProgress;
        }
        
        // 3. 检查是否已满员
        if (group.current_count >= group.required_count) {
            return error.GroupFull;
        }
        
        // 4. 增加参团人数
        group.current_count += 1;
        
        // 5. 检查是否成团
        if (group.current_count >= group.required_count) {
            group.status = .success;
            group.success_at = std.time.timestamp();
            
            // 6. 创建正式订单
            try self.createGroupOrders(group_id);
        }
        
        try self.group_repo.save(&group);
    }
    
    pub fn checkExpiredGroups(self: *Self) !void {
        // 1. 查询过期拼团
        const expired_groups = try self.group_repo.findExpired();
        defer self.group_repo.freeModels(expired_groups);
        
        // 2. 批量处理过期拼团
        for (expired_groups) |group| {
            // 3. 更新状态为失败
            var g = group;
            g.status = .failed;
            try self.group_repo.save(&g);
            
            // 4. 退还预付款
            try self.refundPrepayOrders(group.id.?);
        }
    }
};
```

### 4.6 优惠券管理模块

```zig
// src/application/services/coupon_service.zig
pub const CouponService = struct {
    allocator: Allocator,
    coupon_repo: CouponRepository,
    user_coupon_repo: UserCouponRepository,
    redis: *RedisClient,
    
    pub fn receiveCoupon(self: *Self, user_id: i64, coupon_id: i64) !void {
        // 1. 获取分布式锁
        const lock_key = try std.fmt.allocPrint(self.allocator, "lock:coupon:{d}", .{coupon_id});
        defer self.allocator.free(lock_key);
        
        const lock = try self.redis.lock(lock_key, 5000);
        defer lock.unlock();
        
        // 2. 查询优惠券
        var coupon = try self.coupon_repo.findById(coupon_id) orelse return error.CouponNotFound;
        
        // 3. 检查库存
        if (coupon.received_count >= coupon.total_count) {
            return error.CouponSoldOut;
        }
        
        // 4. 检查用户领取次数
        const user_count = try self.user_coupon_repo.countByUserAndCoupon(user_id, coupon_id);
        if (user_count >= coupon.per_user_limit) {
            return error.ExceedUserLimit;
        }
        
        // 5. 创建用户优惠券
        var user_coupon = UserCoupon{
            .user_id = user_id,
            .coupon_id = coupon_id,
            .status = .unused,
            .expire_at = coupon.end_at,
            .created_at = std.time.timestamp(),
        };
        
        try self.user_coupon_repo.save(&user_coupon);
        
        // 6. 增加领取计数
        coupon.received_count += 1;
        try self.coupon_repo.save(&coupon);
    }
    
    pub fn useCoupon(self: *Self, user_coupon_id: i64, order_id: i64) !void {
        // 1. 查询用户优惠券
        var user_coupon = try self.user_coupon_repo.findById(user_coupon_id) orelse return error.CouponNotFound;
        
        // 2. 检查状态
        if (user_coupon.status != .unused) {
            return error.CouponAlreadyUsed;
        }
        
        // 3. 检查是否过期
        if (user_coupon.expire_at < std.time.timestamp()) {
            return error.CouponExpired;
        }
        
        // 4. 核销优惠券
        user_coupon.status = .used;
        user_coupon.order_id = order_id;
        user_coupon.used_at = std.time.timestamp();
        
        try self.user_coupon_repo.save(&user_coupon);
        
        // 5. 增加使用计数
        try self.coupon_repo.incrementUsedCount(user_coupon.coupon_id);
    }
    
    pub fn matchAvailableCoupons(self: *Self, user_id: i64, order_amount: f64, product_ids: []const i64) ![]UserCoupon {
        // 1. 查询用户未使用的优惠券
        const user_coupons = try self.user_coupon_repo.findByUserAndStatus(user_id, .unused);
        defer self.user_coupon_repo.freeModels(user_coupons);
        
        // 2. 筛选可用优惠券
        var available = std.ArrayList(UserCoupon).init(self.allocator);
        
        for (user_coupons) |uc| {
            const coupon = try self.coupon_repo.findById(uc.coupon_id) orelse continue;
            
            // 检查使用门槛
            if (order_amount < coupon.min_amount) continue;
            
            // 检查适用范围
            if (!try self.checkScope(coupon, product_ids)) continue;
            
            // 检查是否过期
            if (uc.expire_at < std.time.timestamp()) continue;
            
            try available.append(uc);
        }
        
        return available.toOwnedSlice();
    }
};
```


### 4.7 短信服务模块

```zig
// src/application/services/sms_service.zig
pub const SMSService = struct {
    allocator: Allocator,
    sms_config_repo: SMSConfigRepository,
    sms_template_repo: SMSTemplateRepository,
    sms_log_repo: SMSLogRepository,
    redis: *RedisClient,
    aliyun_client: *AliyunSMSClient,
    tencent_client: *TencentSMSClient,
    
    pub fn sendSMS(self: *Self, phone: []const u8, scene: []const u8, params: std.StringHashMap([]const u8)) !void {
        // 1. 频率限制检查
        if (!try self.checkRateLimit(phone)) {
            return error.RateLimitExceeded;
        }
        
        // 2. 查询模板
        const template = try self.sms_template_repo.findByScene(scene) orelse return error.TemplateNotFound;
        
        // 3. 查询配置
        const config = try self.sms_config_repo.findActive() orelse return error.ConfigNotFound;
        
        // 4. 创建发送日志
        var log = SMSLog{
            .phone = phone,
            .template_id = template.id.?,
            .params = try self.serializeParams(params),
            .status = .sending,
            .retry_count = 0,
            .created_at = std.time.timestamp(),
        };
        
        try self.sms_log_repo.save(&log);
        
        // 5. 调用第三方接口发送
        const result = switch (config.provider) {
            .aliyun => try self.aliyun_client.send(phone, template.code, params),
            .tencent => try self.tencent_client.send(phone, template.code, params),
        };
        
        // 6. 更新日志
        log.status = if (result.success) .success else .failed;
        log.error_msg = result.error_msg;
        log.sent_at = std.time.timestamp();
        
        try self.sms_log_repo.save(&log);
        
        // 7. 更新频率限制
        try self.updateRateLimit(phone);
    }
    
    fn checkRateLimit(self: *Self, phone: []const u8) !bool {
        // 1分钟限制
        const minute_key = try std.fmt.allocPrint(self.allocator, "sms:limit:minute:{s}", .{phone});
        defer self.allocator.free(minute_key);
        
        const minute_count = try self.redis.get(minute_key) orelse "0";
        if (std.fmt.parseInt(i32, minute_count, 10) catch 0 >= 1) {
            return false;
        }
        
        // 每天限制
        const day_key = try std.fmt.allocPrint(self.allocator, "sms:limit:day:{s}", .{phone});
        defer self.allocator.free(day_key);
        
        const day_count = try self.redis.get(day_key) orelse "0";
        if (std.fmt.parseInt(i32, day_count, 10) catch 0 >= 10) {
            return false;
        }
        
        return true;
    }
    
    fn updateRateLimit(self: *Self, phone: []const u8) !void {
        // 更新1分钟计数
        const minute_key = try std.fmt.allocPrint(self.allocator, "sms:limit:minute:{s}", .{phone});
        defer self.allocator.free(minute_key);
        
        _ = try self.redis.incr(minute_key);
        try self.redis.expire(minute_key, 60);
        
        // 更新每天计数
        const day_key = try std.fmt.allocPrint(self.allocator, "sms:limit:day:{s}", .{phone});
        defer self.allocator.free(day_key);
        
        _ = try self.redis.incr(day_key);
        try self.redis.expire(day_key, 86400);
    }
    
    pub fn sendVerificationCode(self: *Self, phone: []const u8) ![]const u8 {
        // 1. 生成验证码
        const code = try self.generateCode();
        
        // 2. 存储验证码到 Redis
        const key = try std.fmt.allocPrint(self.allocator, "sms:code:{s}", .{phone});
        defer self.allocator.free(key);
        
        try self.redis.set(key, code, 300); // 5分钟过期
        
        // 3. 发送短信
        var params = std.StringHashMap([]const u8).init(self.allocator);
        defer params.deinit();
        
        try params.put("code", code);
        try self.sendSMS(phone, "verification", params);
        
        return code;
    }
    
    pub fn verifyCode(self: *Self, phone: []const u8, code: []const u8) !bool {
        // 1. 查询验证码
        const key = try std.fmt.allocPrint(self.allocator, "sms:code:{s}", .{phone});
        defer self.allocator.free(key);
        
        const stored_code = try self.redis.get(key) orelse return false;
        
        // 2. 验证码比对
        if (!std.mem.eql(u8, stored_code, code)) {
            // 增加错误次数
            const error_key = try std.fmt.allocPrint(self.allocator, "sms:error:{s}", .{phone});
            defer self.allocator.free(error_key);
            
            const error_count = try self.redis.incr(error_key);
            try self.redis.expire(error_key, 300);
            
            if (error_count >= 5) {
                // 删除验证码
                try self.redis.del(key);
                return error.TooManyErrors;
            }
            
            return false;
        }
        
        // 3. 验证成功，删除验证码
        try self.redis.del(key);
        
        return true;
    }
};
```

## 5. 前端设计

### 5.1 管理后台设计（Vue3 + Element Plus）

#### 5.1.1 页面结构

```
ecom-admin/
├── src/
│   ├── views/
│   │   ├── dashboard/              # 仪表盘
│   │   ├── product/                # 商品管理
│   │   │   ├── list.vue           # 商品列表
│   │   │   ├── create.vue         # 创建商品
│   │   │   ├── edit.vue           # 编辑商品
│   │   │   └── category.vue       # 分类管理
│   │   ├── order/                  # 订单管理
│   │   │   ├── list.vue           # 订单列表
│   │   │   ├── detail.vue         # 订单详情
│   │   │   └── export.vue         # 订单导出
│   │   ├── payment/                # 支付管理
│   │   │   ├── config.vue         # 支付配置
│   │   │   └── records.vue        # 支付记录
│   │   ├── logistics/              # 物流管理
│   │   │   ├── companies.vue      # 物流公司
│   │   │   ├── templates.vue      # 运费模板
│   │   │   └── tracking.vue       # 物流跟踪
│   │   ├── after-sales/            # 售后管理
│   │   │   ├── list.vue           # 售后列表
│   │   │   └── detail.vue         # 售后详情
│   │   ├── marketing/              # 营销管理
│   │   │   ├── activities.vue     # 活动管理
│   │   │   ├── coupons.vue        # 优惠券管理
│   │   │   └── promoters.vue      # 推广管理
│   │   ├── sms/                    # 短信管理
│   │   │   ├── config.vue         # 短信配置
│   │   │   ├── templates.vue      # 短信模板
│   │   │   └── logs.vue           # 发送日志
│   │   ├── page-builder/           # 页面搭建
│   │   │   ├── editor.vue         # 可视化编辑器
│   │   │   └── preview.vue        # 页面预览
│   │   ├── review/                 # 评论管理
│   │   │   └── list.vue           # 评论列表
│   │   ├── advertisement/          # 广告管理
│   │   │   └── list.vue           # 广告列表
│   │   └── statistics/             # 销售统计
│   │       ├── overview.vue       # 概览
│   │       ├── sales.vue          # 销售报表
│   │       └── products.vue       # 商品统计
│   ├── components/
│   │   ├── ProductSelector/       # 商品选择器
│   │   ├── SKUEditor/             # SKU编辑器
│   │   ├── ImageUploader/         # 图片上传
│   │   ├── RichTextEditor/        # 富文本编辑器
│   │   ├── OrderTimeline/         # 订单时间线
│   │   └── PageBuilder/           # 页面构建器组件
│   ├── api/
│   │   ├── product.ts             # 商品接口
│   │   ├── order.ts               # 订单接口
│   │   ├── payment.ts             # 支付接口
│   │   └── ...
│   ├── stores/
│   │   ├── user.ts                # 用户状态
│   │   ├── product.ts             # 商品状态
│   │   └── order.ts               # 订单状态
│   └── router/
│       └── index.ts               # 路由配置
```

#### 5.1.2 核心组件设计

**SKU编辑器组件**：
```vue
<template>
  <div class="sku-editor">
    <!-- 规格属性配置 -->
    <div class="spec-config">
      <el-button @click="addSpec">添加规格</el-button>
      <div v-for="(spec, index) in specs" :key="index" class="spec-item">
        <el-input v-model="spec.name" placeholder="规格名称（如：颜色）" />
        <el-tag
          v-for="(value, vIndex) in spec.values"
          :key="vIndex"
          closable
          @close="removeSpecValue(index, vIndex)"
        >
          {{ value }}
        </el-tag>
        <el-input
          v-model="spec.inputValue"
          placeholder="规格值（如：红色）"
          @keyup.enter="addSpecValue(index)"
        />
      </div>
    </div>
    
    <!-- SKU列表 -->
    <el-table :data="skuList" border>
      <el-table-column
        v-for="spec in specs"
        :key="spec.name"
        :label="spec.name"
        :prop="spec.name"
      />
      <el-table-column label="价格" width="120">
        <template #default="{ row }">
          <el-input-number v-model="row.price" :min="0" :precision="2" />
        </template>
      </el-table-column>
      <el-table-column label="库存" width="120">
        <template #default="{ row }">
          <el-input-number v-model="row.stock" :min="0" />
        </template>
      </el-table-column>
      <el-table-column label="SKU图片" width="100">
        <template #default="{ row }">
          <image-uploader v-model="row.image" />
        </template>
      </el-table-column>
    </el-table>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'

interface Spec {
  name: string
  values: string[]
  inputValue: string
}

interface SKU {
  attrs: Record<string, string>
  price: number
  stock: number
  image: string
}

const specs = ref<Spec[]>([])
const skuList = ref<SKU[]>([])

// 生成SKU列表（笛卡尔积）
const generateSKUs = () => {
  if (specs.value.length === 0) {
    skuList.value = []
    return
  }
  
  const result: SKU[] = []
  const generate = (index: number, current: Record<string, string>) => {
    if (index === specs.value.length) {
      result.push({
        attrs: { ...current },
        price: 0,
        stock: 0,
        image: ''
      })
      return
    }
    
    const spec = specs.value[index]
    for (const value of spec.values) {
      generate(index + 1, { ...current, [spec.name]: value })
    }
  }
  
  generate(0, {})
  skuList.value = result
}

watch(specs, generateSKUs, { deep: true })
</script>
```

**页面构建器组件**：
```vue
<template>
  <div class="page-builder">
    <!-- 左侧组件库 -->
    <div class="component-library">
      <div
        v-for="comp in components"
        :key="comp.type"
        class="component-item"
        draggable="true"
        @dragstart="onDragStart(comp)"
      >
        <i :class="comp.icon" />
        <span>{{ comp.name }}</span>
      </div>
    </div>
    
    <!-- 中间画布 -->
    <div class="canvas" @drop="onDrop" @dragover.prevent>
      <div
        v-for="(item, index) in pageConfig"
        :key="index"
        class="canvas-item"
        :class="{ active: selectedIndex === index }"
        @click="selectItem(index)"
      >
        <component :is="getComponent(item.type)" :config="item.config" />
        <div class="item-actions">
          <el-button size="small" @click="moveUp(index)">上移</el-button>
          <el-button size="small" @click="moveDown(index)">下移</el-button>
          <el-button size="small" type="danger" @click="removeItem(index)">删除</el-button>
        </div>
      </div>
    </div>
    
    <!-- 右侧属性配置 -->
    <div class="property-panel">
      <div v-if="selectedItem">
        <h3>{{ selectedItem.name }}</h3>
        <component
          :is="getPropertyEditor(selectedItem.type)"
          v-model="selectedItem.config"
        />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'

const components = [
  { type: 'banner', name: '轮播图', icon: 'el-icon-picture' },
  { type: 'product-list', name: '商品列表', icon: 'el-icon-goods' },
  { type: 'category-nav', name: '分类导航', icon: 'el-icon-menu' },
  { type: 'coupon', name: '优惠券', icon: 'el-icon-ticket' },
  { type: 'notice', name: '公告', icon: 'el-icon-bell' }
]

const pageConfig = ref([])
const selectedIndex = ref(-1)

const selectedItem = computed(() => {
  return selectedIndex.value >= 0 ? pageConfig.value[selectedIndex.value] : null
})

const onDragStart = (comp: any) => {
  // 拖拽开始
}

const onDrop = (e: DragEvent) => {
  // 拖拽放置
}
</script>
```


### 5.2 小程序设计（微信小程序 + 奈雪的茶风格）

#### 5.2.1 设计规范

**色彩规范**：
```scss
// styles/theme.scss
$primary-color: #FF6B9D;      // 主色（粉红色）
$secondary-color: #FFB6C1;    // 辅助色（浅粉色）
$background-color: #FFF5F7;   // 背景色（淡粉色）
$text-primary: #333333;       // 主文字
$text-secondary: #999999;     // 次要文字
$border-color: #FFE4E8;       // 边框色
$success-color: #52C41A;      // 成功色
$warning-color: #FAAD14;      // 警告色
$error-color: #F5222D;        // 错误色
```

**字体规范**：
```scss
$font-size-xs: 20rpx;
$font-size-sm: 24rpx;
$font-size-base: 28rpx;
$font-size-lg: 32rpx;
$font-size-xl: 36rpx;
$font-size-xxl: 40rpx;
```

**间距规范**：
```scss
$spacing-xs: 8rpx;
$spacing-sm: 16rpx;
$spacing-base: 24rpx;
$spacing-lg: 32rpx;
$spacing-xl: 48rpx;
```

#### 5.2.2 页面结构

```
miniapp/
├── pages/
│   ├── index/                  # 首页
│   │   ├── index.wxml
│   │   ├── index.wxss
│   │   ├── index.ts
│   │   └── index.json
│   ├── category/               # 分类页
│   ├── product/                # 商品详情
│   │   ├── detail.wxml
│   │   ├── detail.wxss
│   │   └── detail.ts
│   ├── cart/                   # 购物车
│   ├── order/                  # 订单
│   │   ├── list.wxml          # 订单列表
│   │   ├── detail.wxml        # 订单详情
│   │   ├── confirm.wxml       # 订单确认
│   │   └── payment.wxml       # 支付页面
│   ├── user/                   # 个人中心
│   │   ├── index.wxml
│   │   ├── profile.wxml       # 个人信息
│   │   ├── address.wxml       # 地址管理
│   │   ├── coupons.wxml       # 优惠券
│   │   └── favorites.wxml     # 收藏
│   └── after-sales/            # 售后
│       ├── apply.wxml         # 申请售后
│       └── detail.wxml        # 售后详情
├── components/
│   ├── product-card/          # 商品卡片
│   ├── sku-selector/          # SKU选择器
│   ├── order-timeline/        # 订单时间线
│   ├── address-selector/      # 地址选择器
│   └── coupon-selector/       # 优惠券选择器
├── utils/
│   ├── request.ts             # 请求封装
│   ├── auth.ts                # 认证工具
│   └── format.ts              # 格式化工具
└── stores/
    ├── user.ts                # 用户状态
    ├── cart.ts                # 购物车状态
    └── order.ts               # 订单状态
```

#### 5.2.3 核心页面设计

**首页（index.wxml）**：
```xml
<view class="container">
  <!-- 搜索栏 -->
  <view class="search-bar">
    <van-search
      value="{{ keyword }}"
      placeholder="搜索商品"
      shape="round"
      background="{{ primaryColor }}"
      bind:search="onSearch"
    />
  </view>
  
  <!-- 轮播图 -->
  <swiper class="banner" indicator-dots autoplay circular>
    <swiper-item wx:for="{{ banners }}" wx:key="id">
      <image src="{{ item.image }}" mode="aspectFill" bind:tap="onBannerTap" data-link="{{ item.link }}" />
    </swiper-item>
  </swiper>
  
  <!-- 分类导航 -->
  <view class="category-nav">
    <view wx:for="{{ categories }}" wx:key="id" class="category-item" bind:tap="onCategoryTap" data-id="{{ item.id }}">
      <image src="{{ item.icon }}" mode="aspectFit" />
      <text>{{ item.name }}</text>
    </view>
  </view>
  
  <!-- 活动区域 -->
  <view class="activity-section" wx:if="{{ activities.length > 0 }}">
    <view class="section-title">限时活动</view>
    <view class="activity-list">
      <view wx:for="{{ activities }}" wx:key="id" class="activity-card" bind:tap="onActivityTap" data-id="{{ item.id }}">
        <image src="{{ item.image }}" mode="aspectFill" />
        <view class="activity-info">
          <text class="activity-name">{{ item.name }}</text>
          <text class="activity-time">{{ item.timeText }}</text>
        </view>
      </view>
    </view>
  </view>
  
  <!-- 商品列表 -->
  <view class="product-section">
    <view class="section-title">为你推荐</view>
    <view class="product-list">
      <product-card
        wx:for="{{ products }}"
        wx:key="id"
        product="{{ item }}"
        bind:tap="onProductTap"
      />
    </view>
  </view>
</view>
```

**商品详情页（product/detail.wxml）**：
```xml
<view class="container">
  <!-- 商品图片 -->
  <swiper class="product-images" indicator-dots>
    <swiper-item wx:for="{{ product.images }}" wx:key="index">
      <image src="{{ item }}" mode="aspectFill" />
    </swiper-item>
  </swiper>
  
  <!-- 商品信息 -->
  <view class="product-info">
    <view class="product-name">{{ product.name }}</view>
    <view class="product-price">
      <text class="price">¥{{ product.price }}</text>
      <text class="original-price" wx:if="{{ product.originalPrice }}">¥{{ product.originalPrice }}</text>
    </view>
    <view class="product-tags">
      <van-tag type="danger" wx:if="{{ product.isActivity }}">活动</van-tag>
      <van-tag type="primary" wx:if="{{ product.isFreeShipping }}">包邮</van-tag>
    </view>
  </view>
  
  <!-- SKU选择 -->
  <view class="sku-selector" bind:tap="showSKUPopup">
    <text class="label">已选</text>
    <text class="value">{{ selectedSKU.text || '请选择规格' }}</text>
    <van-icon name="arrow" />
  </view>
  
  <!-- 商品详情 -->
  <view class="product-detail">
    <view class="detail-title">商品详情</view>
    <rich-text nodes="{{ product.description }}" />
  </view>
  
  <!-- 评论 -->
  <view class="reviews-section">
    <view class="section-header">
      <text class="title">用户评价（{{ product.reviewCount }}）</text>
      <text class="more" bind:tap="showAllReviews">查看全部 ></text>
    </view>
    <view class="review-list">
      <view wx:for="{{ reviews }}" wx:key="id" class="review-item">
        <view class="review-header">
          <image class="avatar" src="{{ item.userAvatar }}" />
          <view class="user-info">
            <text class="username">{{ item.username }}</text>
            <van-rate value="{{ item.rating }}" readonly size="12" />
          </view>
        </view>
        <text class="review-content">{{ item.content }}</text>
        <view class="review-images" wx:if="{{ item.images }}">
          <image wx:for="{{ item.images }}" wx:for-item="img" wx:key="index" src="{{ img }}" mode="aspectFill" />
        </view>
      </view>
    </view>
  </view>
  
  <!-- 底部操作栏 -->
  <view class="action-bar">
    <view class="action-item" bind:tap="addToFavorites">
      <van-icon name="star-o" />
      <text>收藏</text>
    </view>
    <view class="action-item" bind:tap="goToCart">
      <van-icon name="cart-o" />
      <text>购物车</text>
      <van-badge content="{{ cartCount }}" wx:if="{{ cartCount > 0 }}" />
    </view>
    <van-button type="warning" round block bind:tap="addToCart">加入购物车</van-button>
    <van-button type="danger" round block bind:tap="buyNow">立即购买</van-button>
  </view>
  
  <!-- SKU弹窗 -->
  <van-popup show="{{ showSKU }}" position="bottom" round bind:close="closeSKUPopup">
    <sku-selector
      product="{{ product }}"
      bind:confirm="onSKUConfirm"
      bind:cancel="closeSKUPopup"
    />
  </van-popup>
</view>
```

**订单确认页（order/confirm.wxml）**：
```xml
<view class="container">
  <!-- 收货地址 -->
  <view class="address-section" bind:tap="selectAddress">
    <view wx:if="{{ address }}" class="address-info">
      <view class="address-header">
        <text class="receiver">{{ address.name }}</text>
        <text class="phone">{{ address.phone }}</text>
      </view>
      <text class="address-detail">{{ address.fullAddress }}</text>
    </view>
    <view wx:else class="no-address">
      <van-icon name="add-o" />
      <text>添加收货地址</text>
    </view>
    <van-icon name="arrow" />
  </view>
  
  <!-- 商品列表 -->
  <view class="product-section">
    <view wx:for="{{ products }}" wx:key="id" class="product-item">
      <image class="product-image" src="{{ item.image }}" mode="aspectFill" />
      <view class="product-info">
        <text class="product-name">{{ item.name }}</text>
        <text class="product-spec">{{ item.spec }}</text>
        <view class="product-footer">
          <text class="price">¥{{ item.price }}</text>
          <text class="quantity">x{{ item.quantity }}</text>
        </view>
      </view>
    </view>
  </view>
  
  <!-- 优惠券 -->
  <view class="coupon-section" bind:tap="selectCoupon">
    <text class="label">优惠券</text>
    <text class="value">{{ selectedCoupon ? selectedCoupon.name : '请选择优惠券' }}</text>
    <van-icon name="arrow" />
  </view>
  
  <!-- 备注 -->
  <view class="remark-section">
    <van-field
      value="{{ remark }}"
      placeholder="选填，请先和商家协商一致"
      type="textarea"
      autosize
      border="{{ false }}"
      bind:change="onRemarkChange"
    />
  </view>
  
  <!-- 费用明细 -->
  <view class="cost-section">
    <view class="cost-item">
      <text class="label">商品金额</text>
      <text class="value">¥{{ totalAmount }}</text>
    </view>
    <view class="cost-item">
      <text class="label">运费</text>
      <text class="value">¥{{ freightAmount }}</text>
    </view>
    <view class="cost-item" wx:if="{{ discountAmount > 0 }}">
      <text class="label">优惠</text>
      <text class="value discount">-¥{{ discountAmount }}</text>
    </view>
  </view>
  
  <!-- 底部提交栏 -->
  <view class="submit-bar">
    <view class="total">
      <text class="label">实付款：</text>
      <text class="amount">¥{{ paidAmount }}</text>
    </view>
    <van-button type="danger" round block bind:tap="submitOrder" loading="{{ submitting }}">
      提交订单
    </van-button>
  </view>
</view>
```

#### 5.2.4 核心组件设计

**SKU选择器组件（components/sku-selector/index.wxml）**：
```xml
<view class="sku-selector">
  <!-- 商品信息 -->
  <view class="product-info">
    <image class="product-image" src="{{ selectedSKU.image || product.mainImage }}" mode="aspectFill" />
    <view class="product-detail">
      <text class="price">¥{{ selectedSKU.price || product.price }}</text>
      <text class="stock">库存：{{ selectedSKU.stock || product.stock }}</text>
      <text class="selected">已选：{{ selectedText }}</text>
    </view>
    <van-icon name="cross" class="close-icon" bind:tap="onCancel" />
  </view>
  
  <!-- 规格选择 -->
  <view class="spec-section">
    <view wx:for="{{ specs }}" wx:key="name" class="spec-group">
      <text class="spec-name">{{ item.name }}</text>
      <view class="spec-values">
        <view
          wx:for="{{ item.values }}"
          wx:for-item="value"
          wx:key="index"
          class="spec-value {{ selectedSpecs[item.name] === value ? 'active' : '' }}"
          bind:tap="onSpecTap"
          data-spec="{{ item.name }}"
          data-value="{{ value }}"
        >
          {{ value }}
        </view>
      </view>
    </view>
  </view>
  
  <!-- 数量选择 -->
  <view class="quantity-section">
    <text class="label">购买数量</text>
    <van-stepper
      value="{{ quantity }}"
      min="1"
      max="{{ selectedSKU.stock || 999 }}"
      bind:change="onQuantityChange"
    />
  </view>
  
  <!-- 确认按钮 -->
  <view class="action-buttons">
    <van-button type="danger" round block bind:tap="onConfirm">确定</van-button>
  </view>
</view>
```

### 5.3 H5设计（Vue3 + Vant）

#### 5.3.1 页面结构

```
h5/
├── src/
│   ├── views/
│   │   ├── Home.vue              # 首页
│   │   ├── Category.vue          # 分类
│   │   ├── ProductDetail.vue     # 商品详情
│   │   ├── Cart.vue              # 购物车
│   │   ├── OrderConfirm.vue      # 订单确认
│   │   ├── OrderList.vue         # 订单列表
│   │   ├── OrderDetail.vue       # 订单详情
│   │   ├── User.vue              # 个人中心
│   │   ├── Address.vue           # 地址管理
│   │   └── AfterSales.vue        # 售后
│   ├── components/
│   │   ├── ProductCard.vue       # 商品卡片
│   │   ├── SKUSelector.vue       # SKU选择器
│   │   ├── OrderTimeline.vue     # 订单时间线
│   │   └── AddressSelector.vue   # 地址选择器
│   ├── api/
│   │   ├── product.ts
│   │   ├── order.ts
│   │   └── user.ts
│   ├── stores/
│   │   ├── user.ts
│   │   ├── cart.ts
│   │   └── order.ts
│   └── router/
│       └── index.ts
```

#### 5.3.2 响应式设计

```scss
// styles/responsive.scss

// 移动端优先
.container {
  padding: 16px;
  
  // 平板
  @media (min-width: 768px) {
    max-width: 750px;
    margin: 0 auto;
  }
  
  // 桌面
  @media (min-width: 1024px) {
    max-width: 1200px;
  }
}

// 商品卡片响应式
.product-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 16px;
  
  @media (min-width: 768px) {
    grid-template-columns: repeat(3, 1fr);
  }
  
  @media (min-width: 1024px) {
    grid-template-columns: repeat(4, 1fr);
  }
}
```


## 6. 缓存策略设计

### 6.1 缓存层次

```
┌─────────────────────────────────────────┐
│         浏览器缓存（Browser Cache）      │
│         - 静态资源（图片、CSS、JS）      │
│         - TTL: 7天                       │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│         CDN缓存（CDN Cache）             │
│         - 静态资源、商品图片             │
│         - TTL: 1天                       │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│         应用缓存（Redis Cache）          │
│         - 热点数据、会话数据             │
│         - TTL: 5-30分钟                  │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│         数据库（MySQL）                  │
└─────────────────────────────────────────┘
```

### 6.2 缓存策略

**商品缓存**：
```zig
// 缓存键：product:{id}
// TTL：30分钟
// 更新策略：写入时更新缓存
pub fn getProduct(self: *Self, id: i64) !?Product {
    const cache_key = try std.fmt.allocPrint(self.allocator, "product:{d}", .{id});
    defer self.allocator.free(cache_key);
    
    // 1. 尝试从缓存获取
    if (self.cache.get(cache_key, self.allocator)) |cached| {
        defer self.allocator.free(cached);
        return try deserializeProduct(self.allocator, cached);
    }
    
    // 2. 从数据库查询（使用关系预加载）
    var q = OrmProduct.Query();
    defer q.deinit();
    _ = q.where("id", "=", id).with(&.{"skus", "category"});
    
    const products = try q.get();
    defer OrmProduct.freeModels(products);
    
    if (products.len == 0) return null;
    
    // 3. 缓存结果
    const json = try serializeProduct(self.allocator, products[0]);
    defer self.allocator.free(json);
    try self.cache.set(cache_key, json, 1800); // 30分钟
    
    return products[0];
}
```

**分类缓存**：
```zig
// 缓存键：categories:tree
// TTL：1小时
// 更新策略：写入时删除缓存
```

**用户会话缓存**：
```zig
// 缓存键：session:{token}
// TTL：2小时
// 更新策略：活动时延长TTL
```

**购物车缓存**：
```zig
// 缓存键：cart:{user_id}
// TTL：7天
// 更新策略：实时更新
```

### 6.3 缓存失效策略

**主动失效**：
- 商品更新：删除 `product:{id}` 缓存
- 分类更新：删除 `categories:tree` 缓存
- 库存变更：删除 `inventory:{sku_id}` 缓存

**被动失效**：
- TTL过期自动删除
- LRU淘汰策略

**缓存预热**：
- 系统启动时预热热门商品
- 活动开始前预热活动商品
- 秒杀开始前预热库存到Redis

## 7. 安全设计

### 7.1 SQL注入防护

**强制使用参数化查询**：
```zig
// ✅ 正确：使用参数化查询
var q = OrmProduct.Query();
_ = q.where("name", "LIKE", keyword)  // 自动参数化
     .where("status", "=", status);

// ❌ 错误：禁止使用 rawExec
// const sql = try std.fmt.allocPrint(allocator, "SELECT * FROM products WHERE name LIKE '%{s}%'", .{keyword});
// try db.rawExec(sql);  // 禁止！
```

### 7.2 支付签名验证

**微信支付签名验证**：
```zig
pub fn verifyWechatSignature(data: []const u8, signature: []const u8, api_key: []const u8) !bool {
    // 1. 解析XML数据
    const xml_data = try parseXML(data);
    
    // 2. 提取签名字段
    const sign = xml_data.get("sign") orelse return false;
    
    // 3. 移除sign字段
    var params = std.StringHashMap([]const u8).init(allocator);
    var it = xml_data.iterator();
    while (it.next()) |entry| {
        if (!std.mem.eql(u8, entry.key_ptr.*, "sign")) {
            try params.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }
    
    // 4. 按键名排序
    var keys = std.ArrayList([]const u8).init(allocator);
    defer keys.deinit();
    
    var key_it = params.keyIterator();
    while (key_it.next()) |key| {
        try keys.append(key.*);
    }
    
    std.sort.sort([]const u8, keys.items, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lessThan);
    
    // 5. 拼接字符串
    var str_builder = std.ArrayList(u8).init(allocator);
    defer str_builder.deinit();
    
    for (keys.items, 0..) |key, i| {
        if (i > 0) try str_builder.append('&');
        try str_builder.appendSlice(key);
        try str_builder.append('=');
        try str_builder.appendSlice(params.get(key).?);
    }
    
    // 6. 添加API密钥
    try str_builder.appendSlice("&key=");
    try str_builder.appendSlice(api_key);
    
    // 7. MD5签名
    const computed_sign = try md5(str_builder.items);
    defer allocator.free(computed_sign);
    
    // 8. 比对签名
    return std.mem.eql(u8, computed_sign, sign);
}
```

### 7.3 接口限流

**令牌桶算法**：
```zig
pub const RateLimiter = struct {
    redis: *RedisClient,
    
    pub fn checkLimit(self: *Self, key: []const u8, limit: i32, window: i64) !bool {
        const now = std.time.timestamp();
        const window_key = try std.fmt.allocPrint(self.allocator, "rate:{s}:{d}", .{ key, now / window });
        defer self.allocator.free(window_key);
        
        // 使用 Lua 脚本保证原子性
        const script =
            \\local current = redis.call('incr', KEYS[1])
            \\if current == 1 then
            \\    redis.call('expire', KEYS[1], ARGV[2])
            \\end
            \\if current > tonumber(ARGV[1]) then
            \\    return 0
            \\end
            \\return 1
        ;
        
        const result = try self.redis.eval(script, &[_][]const u8{window_key}, &[_][]const u8{ limit, window });
        return result == 1;
    }
};
```

### 7.4 数据加密

**密码加密（bcrypt）**：
```zig
pub fn hashPassword(password: []const u8) ![]const u8 {
    return try bcrypt.hash(password, 10);
}

pub fn verifyPassword(password: []const u8, hash: []const u8) !bool {
    return try bcrypt.verify(password, hash);
}
```

**敏感数据加密（AES）**：
```zig
pub fn encryptSensitiveData(data: []const u8, key: []const u8) ![]const u8 {
    return try aes256.encrypt(data, key);
}

pub fn decryptSensitiveData(encrypted: []const u8, key: []const u8) ![]const u8 {
    return try aes256.decrypt(encrypted, key);
}
```

## 8. 部署架构

### 8.1 生产环境架构

```
                    ┌─────────────┐
                    │   用户端    │
                    └──────┬──────┘
                           │ HTTPS
                    ┌──────▼──────┐
                    │   CDN       │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   Nginx     │
                    │  负载均衡   │
                    └──────┬──────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
   ┌────▼────┐       ┌────▼────┐       ┌────▼────┐
   │ App 1   │       │ App 2   │       │ App 3   │
   │ (Zig)   │       │ (Zig)   │       │ (Zig)   │
   └────┬────┘       └────┬────┘       └────┬────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
   ┌────▼────┐       ┌────▼────┐       ┌────▼────┐
   │ MySQL   │       │ Redis   │       │RabbitMQ │
   │ 主从    │       │ 哨兵    │       │ 集群    │
   └─────────┘       └─────────┘       └─────────┘
```

### 8.2 Docker部署

**Dockerfile**：
```dockerfile
FROM alpine:latest

# 安装依赖
RUN apk add --no-cache \
    libstdc++ \
    ca-certificates

# 复制应用
COPY ./zig-out/bin/ecommerce /app/ecommerce
COPY ./config /app/config

WORKDIR /app

EXPOSE 8080

CMD ["./ecommerce"]
```

**docker-compose.yml**：
```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      - DB_HOST=mysql
      - REDIS_HOST=redis
    depends_on:
      - mysql
      - redis
    restart: always
    
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ecommerce
    volumes:
      - mysql_data:/var/lib/mysql
    restart: always
    
  redis:
    image: redis:6.0-alpine
    volumes:
      - redis_data:/data
    restart: always
    
  rabbitmq:
    image: rabbitmq:3.12-management
    ports:
      - "15672:15672"
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    restart: always

volumes:
  mysql_data:
  redis_data:
  rabbitmq_data:
```

### 8.3 CI/CD流程

**GitHub Actions配置**：
```yaml
name: Deploy

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Zig
        uses: goto-bus-stop/setup-zig@v2
        with:
          version: 0.13.0
      
      - name: Build
        run: zig build -Doptimize=ReleaseFast
      
      - name: Test
        run: zig build test
      
      - name: Build Docker Image
        run: docker build -t ecommerce:${{ github.sha }} .
      
      - name: Push to Registry
        run: |
          docker tag ecommerce:${{ github.sha }} registry.example.com/ecommerce:latest
          docker push registry.example.com/ecommerce:latest
      
      - name: Deploy to Kubernetes
        run: kubectl apply -f k8s/
```

## 9. 监控与日志

### 9.1 监控指标

**系统指标**：
- CPU使用率
- 内存使用率
- 磁盘使用率
- 网络流量

**应用指标**：
- QPS（每秒请求数）
- 响应时间（P50、P95、P99）
- 错误率
- 数据库连接数
- Redis连接数

**业务指标**：
- 订单量
- 支付成功率
- 库存预警
- 活动参与人数

### 9.2 日志设计

**日志级别**：
- DEBUG：调试信息
- INFO：一般信息
- WARN：警告信息
- ERROR：错误信息
- FATAL：致命错误

**日志格式**：
```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "level": "INFO",
  "service": "order-service",
  "trace_id": "abc123",
  "user_id": 123,
  "message": "Order created successfully",
  "data": {
    "order_id": 456,
    "amount": 99.99
  }
}
```

## 10. 总结

本设计文档定义了商用电商系统的完整技术方案，包括：

1. **系统架构**：整洁架构 + DDD + 微服务
2. **数据库设计**：完整的表结构、索引、分表策略
3. **API设计**：RESTful API、认证授权、限流策略
4. **核心模块**：商品、订单、支付、物流、售后、营销、库存等
5. **前端设计**：管理后台（Vue3）、小程序（奈雪的茶风格）、H5
6. **缓存策略**：多层缓存、失效策略、预热策略
7. **安全设计**：SQL注入防护、签名验证、加密存储
8. **部署架构**：Docker、Kubernetes、CI/CD
9. **监控日志**：系统监控、应用监控、业务监控

系统设计遵循以下原则：
- **高性能**：关系预加载、Redis缓存、分布式锁
- **高可用**：主从复制、哨兵模式、服务降级
- **高安全**：参数化查询、签名验证、数据加密
- **可扩展**：微服务架构、水平扩展、消息队列
- **可维护**：整洁架构、DDD、依赖注入

下一步可以进入任务分解阶段，将设计方案转化为可执行的开发任务。

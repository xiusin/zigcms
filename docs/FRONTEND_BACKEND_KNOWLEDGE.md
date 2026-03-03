# ZigCMS 前后端知识文档

> **版本**: 1.0.0  
> **生成时间**: 2026-03-03  
> **作者**: ZigCMS Team

## 📋 文档概述

本文档全面介绍 ZigCMS 后端（基于 Zig 语言的整洁架构）和 ecom-admin 前端（基于 Vue 3 + Arco Design）的技术架构、开发规范和协作流程，帮助开发者快速理解项目并高效开发。

---

## 目录

1. [后端架构](#1-后端架构)
2. [数据库驱动](#2-数据库驱动)
3. [ORM 系统](#3-orm-系统)
4. [前端架构](#4-前端架构)
5. [Mock 与真实接口切换](#5-mock-与真实接口切换)
6. [前后端接口对接](#6-前后端接口对接)
7. [认证授权机制](#7-认证授权机制)
8. [开发环境配置](#8-开发环境配置)
9. [开发规范](#9-开发规范)
10. [常见问题](#10-常见问题)

---

## 1. 后端架构

### 1.1 整洁架构概览

ZigCMS 采用**整洁架构**（Clean Architecture）模式，将系统分为五个清晰的层次：

```
┌─────────────────────────────────────────────────────────────────┐
│                        API 层 (api/)                            │
│  职责: HTTP 请求处理、参数验证、响应格式化                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓ 依赖
┌─────────────────────────────────────────────────────────────────┐
│                     应用层 (application/)                       │
│  职责: 业务流程编排、用例实现、事务管理                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓ 依赖
┌─────────────────────────────────────────────────────────────────┐
│                      领域层 (domain/)                           │
│  职责: 核心业务逻辑、业务规则、领域模型                        │
└─────────────────────────────────────────────────────────────────┘
                              ↑ 实现
┌─────────────────────────────────────────────────────────────────┐
│                  基础设施层 (infrastructure/)                   │
│  职责: 外部服务实现、数据持久化、第三方集成                    │
└─────────────────────────────────────────────────────────────────┘
                              
┌─────────────────────────────────────────────────────────────────┐
│                      共享层 (shared/)                           │
│  职责: 通用工具、基础原语、共享类型（被所有层使用）            │
└─────────────────────────────────────────────────────────────────┘
```


### 1.2 目录结构

```
zigcms/
├── api/                    # API 层 - HTTP 接口
│   ├── controllers/        # 控制器（按业务模块分组）
│   │   ├── admin/         # 管理员控制器
│   │   ├── auth/          # 认证控制器
│   │   └── common/        # 通用控制器（CRUD）
│   ├── dto/               # 数据传输对象
│   ├── middleware/        # 中间件（认证、日志、CORS）
│   └── App.zig           # 应用框架核心
│
├── application/           # 应用层 - 业务逻辑
│   └── services/         # 应用服务
│       ├── orm/          # ORM 服务
│       ├── cache/        # 缓存服务
│       ├── logger/       # 日志服务
│       └── sql/          # SQL 驱动和 QueryBuilder
│
├── domain/               # 领域层 - 核心业务
│   └── entities/        # 实体模型
│       ├── models.zig   # 数据模型定义
│       └── orm_models.zig # ORM 模型注册
│
├── infrastructure/       # 基础设施层 - 外部集成
│   └── mod.zig          # 基础设施层入口
│
├── shared/              # 共享层 - 跨层组件
│   ├── primitives/      # 基础原语
│   │   └── global.zig   # 全局资源管理
│   └── utils/           # 工具函数
│
├── main.zig            # 程序入口
├── root.zig            # 根模块
└── build.zig           # 构建配置
```

### 1.3 依赖注入（DI）容器

ZigCMS 使用全局 DI 容器管理服务生命周期，确保内存安全和零泄漏。

**核心特性**：
- Arena 托管：所有单例服务由 Arena 分配器管理
- 自动清理：系统关闭时一次性释放所有资源
- 借用引用：服务间使用借用引用，避免重复释放

**使用示例**：

```zig
// 初始化 DI 容器
try zigcms.core.di.initGlobalDISystem(allocator);
defer zigcms.core.di.deinitGlobalDISystem();

// 注册服务
const container = zigcms.core.di.getGlobalContainer();
try container.registerSingleton(UserService, UserService, userServiceFactory, null);

// 解析服务
const user_service = try container.resolve(UserService);
```

### 1.4 层次职责详解

#### API 层
- **职责**：处理 HTTP 请求和响应
- **规范**：
  - 控制器只做参数解析和响应返回
  - 不包含业务逻辑
  - 使用 DTO 进行数据传输

```zig
// api/controllers/user/user.controller.zig
pub fn list(req: zap.Request) !void {
    // 1. 解析参数
    const page = req.getParamInt("page") orelse 1;
    
    // 2. 调用服务
    const container = zigcms.core.di.getGlobalContainer();
    const service = try container.resolve(UserService);
    const result = try service.list(page, 20);
    
    // 3. 返回响应
    try base.send_success(req, result);
}
```

#### 应用层
- **职责**：业务流程编排、事务管理
- **规范**：
  - 服务类命名：`XxxService`
  - 使用依赖注入
  - 协调多个领域对象

```zig
// application/services/user_service.zig
pub const UserService = struct {
    allocator: Allocator,
    db: *Database,
    cache: *CacheInterface,
    
    pub fn createUser(self: *Self, dto: CreateUserDto) !User {
        // 1. 验证业务规则
        if (try self.existsByUsername(dto.username)) {
            return error.UsernameExists;
        }
        
        // 2. 创建用户
        var user = User{ .username = dto.username, .email = dto.email };
        try self.db.save(&user);
        
        // 3. 清除缓存
        try self.cache.delByPrefix("user:");
        
        return user;
    }
};
```

#### 领域层
- **职责**：核心业务逻辑和规则
- **规范**：
  - 实体自包含
  - 业务规则在实体内部实现
  - 不依赖外层

```zig
// domain/entities/user.model.zig
pub const User = struct {
    id: ?i32 = null,
    username: []const u8,
    email: []const u8,
    status: i32 = 1,
    
    pub fn isActive(self: User) bool {
        return self.status == 1;
    }
    
    pub fn validate(self: User) !void {
        if (self.username.len < 3) {
            return error.UsernameTooShort;
        }
    }
};
```

---


## 2. 数据库驱动

### 2.1 多数据库支持

ZigCMS 支持三种数据库驱动，可通过配置灵活切换：

| 数据库 | 驱动类型 | 连接池 | 适用场景 |
|--------|----------|--------|----------|
| **MySQL** | 原生驱动 | ✅ 支持 | 生产环境、高并发 |
| **SQLite** | 统一接口 | ❌ 不支持 | 开发环境、嵌入式 |
| **PostgreSQL** | 统一接口 | ❌ 不支持 | 企业级应用 |

### 2.2 数据库配置

**环境变量配置**（`.env`）：

```bash
# MySQL 配置
DB_TYPE=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=zigcms
DB_USER=root
DB_PASSWORD=password

# 连接池配置（仅 MySQL）
DB_POOL_SIZE=10
DB_POOL_TIMEOUT=30

# SQLite 配置
# DB_TYPE=sqlite
# DB_PATH=./zigcms.db

# PostgreSQL 配置
# DB_TYPE=postgresql
# DB_HOST=127.0.0.1
# DB_PORT=5432
# DB_NAME=zigcms
# DB_USER=postgres
# DB_PASSWORD=password
```

### 2.3 数据库初始化

```zig
// main.zig
const db_config = sql.MySQLConfig{
    .host = "127.0.0.1",
    .port = 3306,
    .database = "zigcms",
    .user = "root",
    .password = "password",
    .pool_size = 10,
};

var db = try sql.Database.init(allocator, .MySQL, db_config);
defer db.deinit();
```

### 2.4 数据库测试

#### MySQL 测试

```bash
# 创建测试数据库
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS test_zigcms;"

# 编译测试
cd src/application/services/sql
zig build-exe mysql_complete_test.zig -lc -lmysqlclient \
  -I /opt/homebrew/include \
  -L /opt/homebrew/lib

# 运行测试
./mysql_complete_test
```

#### SQLite 测试

```bash
cd src/application/services/sql
zig build-exe sqlite_complete_test.zig -lc -lsqlite3
./sqlite_complete_test
```

#### PostgreSQL 测试

```bash
# 创建测试数据库
psql -U postgres -c "CREATE DATABASE test_zigcms;"

# 通过主程序运行
zig build
```

---

## 3. ORM 系统

### 3.1 Laravel 风格 QueryBuilder

ZigCMS 的 ORM 系统提供 Laravel 风格的链式调用 API，支持参数化查询和关系预加载。

**核心特性**：
- ✅ 链式调用（where、whereIn、whereRaw）
- ✅ 参数化查询（防 SQL 注入）
- ✅ 关系预加载（解决 N+1 查询）
- ✅ 软删除和时间戳自动管理
- ✅ 内存安全（Arena 分配器）

### 3.2 基础查询

```zig
// 定义 ORM 模型
const OrmUser = orm.define(models.SysAdmin, "admin", .{});

// 简单查询
var q = OrmUser.Query();
defer q.deinit();

_ = q.where("status", "=", 1)
     .where("age", ">", 18)
     .orderBy("created_at", .Desc)
     .limit(10);

const users = try q.get();
defer OrmUser.freeModels(users);
```

### 3.3 参数化查询（防 SQL 注入）

**推荐方式**：使用 QueryBuilder 的参数化方法

```zig
// ✅ 安全：参数化查询
_ = q.where("username", "=", user_input)
     .where("age", ">", age_input)
     .whereIn("role_id", role_ids);

// ❌ 危险：字符串拼接（禁止使用）
const sql = try std.fmt.allocPrint(allocator, 
    "SELECT * FROM users WHERE age > {d}", .{age});
```

**动态条件构建**：

```zig
var params = sql.ParamBuilder.init(allocator);
defer params.deinit();

var conditions = std.ArrayList(u8).init(allocator);
defer conditions.deinit();

try conditions.appendSlice("1=1");

if (filter.age) |age| {
    try conditions.appendSlice(" AND age > ?");
    try params.add(age);
}

if (filter.name) |name| {
    try conditions.appendSlice(" AND name LIKE ?");
    try params.add(try std.fmt.allocPrint(allocator, "%{s}%", .{name}));
}

_ = q.whereRaw(conditions.items, params);
```

### 3.4 关系预加载（解决 N+1 查询）

**问题场景**：查询角色列表，每个角色需要查询关联的菜单

**❌ N+1 查询问题**：

```zig
// 1 次查询角色 + N 次查询菜单 = N+1 次查询
const roles = try role_q.get();
for (roles) |role| {
    var menu_q = OrmRoleMenu.Query();
    _ = menu_q.where("role_id", "=", role.id);  // ❌ N+1 问题
    const menus = try menu_q.get();
}
```

**✅ 关系预加载解决方案**：

```zig
// 定义关系
pub const Role = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    menus: ?[]Menu = null,  // 关联字段
    
    pub const relations = .{
        .menus = .{
            .type = .many_to_many,
            .model = Menu,
            .through = "role_menu",
            .foreign_key = "role_id",
            .related_key = "menu_id",
        },
    };
};

// 使用预加载（只需 3 次查询）
var q = OrmRole.Query();
_ = q.with(&.{"menus"});  // 一行代码解决 N+1 查询

const roles = try q.get();
defer OrmRole.freeModels(roles);

for (roles) |role| {
    if (role.menus) |menus| {
        // 菜单已预加载，无额外查询
        for (menus) |menu| {
            std.debug.print("菜单: {s}\n", .{menu.name});
        }
    }
}
```

**性能对比**：
- N+1 查询：1 + 10 + 30 = 41 次查询
- 关系预加载：1 + 1 + 1 = 3 次查询
- **性能提升：93%**


### 3.5 内存管理（关键）

**ORM 查询结果的内存生命周期**：

```zig
// ❌ 错误：浅拷贝导致悬垂指针
var roles = std.ArrayListUnmanaged(models.SysRole){};
defer roles.deinit(allocator);

const role_rows = role_q.get() catch |err| return err;
defer OrmRole.freeModels(role_rows);  // 释放 ORM 内存

for (role_rows) |role| {
    roles.append(allocator, role) catch {};  // ❌ 浅拷贝，role.role_name 指向已释放内存
}
// 访问 roles.items[0].role_name 会读取到垃圾数据（乱码）

// ✅ 正确：使用 Arena Allocator（推荐）
var role_result = try role_q.getWithArena(allocator);
defer role_result.deinit();  // 一次性释放所有内存

for (role_result.items()) |role| {
    // 安全访问，无需手动深拷贝
    std.debug.print("Role: {s}\n", .{role.role_name});
}
```

**常见错误表现**：
- 字符串字段显示乱码（`\udcaa\udcaa...`）
- 随机崩溃或段错误
- 数据库数据正常但接口返回异常

**参考文档**：`knowlages/orm_memory_lifecycle.md`

### 3.6 部分更新优化

**推荐方案：UpdateWith（真正的 Zig 风格）**

```zig
// 使用匿名结构体 .{} 动态构建更新字段
_ = try OrmAdmin.UpdateWith(id, .{
    .username = if (obj.get("username")) |v| if (v == .string) v.string else null else null,
    .nickname = if (obj.get("nickname")) |v| if (v == .string) v.string else null else null,
    .status = if (obj.get("status")) |v| if (v == .integer) @as(?i32, @intCast(v.integer)) else null else null,
    .dept_id = if (obj.get("dept_id")) |v| 
        if (v == .null) null 
        else if (v == .integer) @as(?i32, @intCast(v.integer)) else null 
        else null,
});
```

**核心优势**：
- 真正的 Zig 风格：使用原生匿名结构体语法 `.{}`
- 编译时类型推导：零运行时开销
- 自动跳过 null：optional 字段值为 `null` 时自动跳过
- 类型安全：编译时检查字段存在性和类型匹配

**辅助函数简化 JSON 提取**：

```zig
fn getStringOrNull(obj: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    if (obj.get(key)) |v| if (v == .string) return v.string;
    return null;
}

fn getIntOrNull(obj: std.json.ObjectMap, key: []const u8) ?i32 {
    if (obj.get(key)) |v| if (v == .integer) return @intCast(v.integer);
    return null;
}

// 使用
_ = try OrmAdmin.UpdateWith(id, .{
    .username = getStringOrNull(obj, "username"),
    .status = getIntOrNull(obj, "status"),
    .dept_id = getIntOrNull(obj, "dept_id"),
});
```

**参考文档**：`knowlages/orm_update_with_anonymous_struct.md`

---

## 4. 前端架构

### 4.1 技术栈

ecom-admin 前端基于现代化的 Vue 3 生态系统：

| 技术 | 版本 | 用途 |
|------|------|------|
| **Vue 3** | ^3.2.40 | 渐进式 JavaScript 框架 |
| **Pinia** | ^2.0.23 | 状态管理（替代 Vuex） |
| **Vue Router** | ^4.0.14 | 路由管理 |
| **Arco Design** | ^2.50.2 | UI 组件库 |
| **Vite** | ^3.2.5 | 构建工具 |
| **TypeScript** | ^4.8.4 | 类型系统 |
| **Axios** | ^0.24.0 | HTTP 客户端 |

### 4.2 目录结构

```
ecom-admin/
├── src/
│   ├── api/                # API 接口定义
│   │   ├── request.ts      # Axios 封装
│   │   ├── response.ts     # 响应格式化
│   │   ├── base.ts         # 基础接口
│   │   └── cms.ts          # CMS 接口
│   │
│   ├── components/         # 公共组件
│   │   ├── table/         # 表格组件
│   │   ├── form/          # 表单组件
│   │   └── amis/          # AMIS 低代码组件
│   │
│   ├── views/             # 页面视图
│   │   ├── dashboard/     # 仪表盘
│   │   ├── cms/           # CMS 管理
│   │   ├── system/        # 系统管理
│   │   └── login/         # 登录页
│   │
│   ├── store/             # Pinia 状态管理
│   │   ├── modules/       # 状态模块
│   │   │   ├── user.ts    # 用户状态
│   │   │   └── app.ts     # 应用状态
│   │   └── index.ts       # Store 入口
│   │
│   ├── router/            # 路由配置
│   │   ├── routes/        # 路由定义
│   │   ├── guard/         # 路由守卫
│   │   └── index.ts       # Router 入口
│   │
│   ├── utils/             # 工具函数
│   │   ├── auth.ts        # 认证工具
│   │   ├── request.ts     # 请求工具
│   │   └── permission.ts  # 权限工具
│   │
│   ├── mock/              # Mock 数据
│   │   ├── index.ts       # Mock 入口
│   │   ├── cms.ts         # CMS Mock
│   │   └── user.ts        # 用户 Mock
│   │
│   ├── types/             # TypeScript 类型定义
│   ├── locale/            # 国际化
│   ├── assets/            # 静态资源
│   ├── App.vue            # 根组件
│   └── main.ts            # 入口文件
│
├── config/                # 配置文件
│   ├── vite.config.dev.ts # 开发环境配置
│   └── vite.config.prod.ts # 生产环境配置
│
├── package.json           # 依赖配置
├── tsconfig.json          # TypeScript 配置
└── index.html             # HTML 模板
```

### 4.3 状态管理（Pinia）

**定义 Store**：

```typescript
// src/store/modules/user.ts
import { defineStore } from 'pinia';

export const useUserStore = defineStore('user', {
  state: () => ({
    userInfo: null as UserInfo | null,
    token: '',
    roles: [] as string[],
  }),
  
  getters: {
    isLoggedIn: (state) => !!state.token,
    hasRole: (state) => (role: string) => state.roles.includes(role),
  },
  
  actions: {
    async login(username: string, password: string) {
      const res = await loginApi({ username, password });
      this.token = res.data.token;
      this.userInfo = res.data.userInfo;
      this.roles = res.data.roles;
      setToken(res.data.token);
    },
    
    logout() {
      this.token = '';
      this.userInfo = null;
      this.roles = [];
      removeToken();
    },
  },
});
```

**使用 Store**：

```vue
<script setup lang="ts">
import { useUserStore } from '@/store';

const userStore = useUserStore();

// 访问状态
console.log(userStore.userInfo);

// 调用 action
await userStore.login('admin', 'password');

// 使用 getter
if (userStore.hasRole('admin')) {
  // ...
}
</script>
```


### 4.4 路由系统（Vue Router）

**路由配置**：

```typescript
// src/router/routes/index.ts
export const routes = [
  {
    path: '/login',
    name: 'login',
    component: () => import('@/views/login/index.vue'),
    meta: { requiresAuth: false },
  },
  {
    path: '/',
    name: 'root',
    component: () => import('@/layout/default-layout.vue'),
    meta: { requiresAuth: true },
    children: [
      {
        path: 'dashboard',
        name: 'dashboard',
        component: () => import('@/views/dashboard/index.vue'),
        meta: { title: '仪表盘', icon: 'icon-dashboard' },
      },
      {
        path: 'cms',
        name: 'cms',
        component: () => import('@/views/cms/index.vue'),
        meta: { title: 'CMS 管理', icon: 'icon-apps', roles: ['admin'] },
      },
    ],
  },
];
```

**路由守卫**：

```typescript
// src/router/guard/permission.ts
router.beforeEach(async (to, from, next) => {
  const userStore = useUserStore();
  
  // 检查是否需要认证
  if (to.meta.requiresAuth && !userStore.isLoggedIn) {
    next({ name: 'login', query: { redirect: to.fullPath } });
    return;
  }
  
  // 检查角色权限
  if (to.meta.roles && !to.meta.roles.some(role => userStore.hasRole(role))) {
    Message.error('无权限访问');
    next({ name: 'dashboard' });
    return;
  }
  
  next();
});
```

### 4.5 组件库（Arco Design）

**全局配置**：

```typescript
// src/main.ts
import ArcoVue from '@arco-design/web-vue';
import '@arco-design/web-vue/dist/arco.css';

app.use(ArcoVue, {
  componentSize: 'mini',
  components: {
    Table: {
      size: 'mini',
      border: true,
      stripe: true,
    },
  },
});
```

**组件使用**：

```vue
<template>
  <a-table
    :columns="columns"
    :data="data"
    :pagination="pagination"
    @page-change="handlePageChange"
  >
    <template #status="{ record }">
      <a-tag :color="record.status === 1 ? 'green' : 'red'">
        {{ record.status === 1 ? '启用' : '禁用' }}
      </a-tag>
    </template>
  </a-table>
</template>

<script setup lang="ts">
const columns = [
  { title: 'ID', dataIndex: 'id' },
  { title: '用户名', dataIndex: 'username' },
  { title: '状态', slotName: 'status' },
];

const data = ref([]);
const pagination = reactive({ current: 1, pageSize: 20, total: 0 });

const handlePageChange = (page: number) => {
  pagination.current = page;
  fetchData();
};
</script>
```

---

## 5. Mock 与真实接口切换

### 5.1 Mock 系统架构

ecom-admin 使用 **MockJS** 实现前端 Mock 数据系统，支持开发环境下的接口模拟。

**核心特性**：
- ✅ 自动拦截 Axios 请求
- ✅ 支持正则匹配 URL
- ✅ 支持动态数据生成
- ✅ 环境变量控制开关

### 5.2 Mock 数据定义

**Mock 文件组织**：

```
src/mock/
├── index.ts           # Mock 入口，注册所有 Mock
├── cms.ts             # CMS 模块 Mock
├── user.ts            # 用户模块 Mock
├── feedback.ts        # 反馈模块 Mock
└── complex-schema.ts  # 复杂 Schema Mock
```

**Mock 数据示例**：

```typescript
// src/mock/cms.ts
import Mock from 'mockjs';

export default [
  {
    url: '/api/cms/article/list',
    method: 'post',
    response: () => {
      return {
        code: 200,
        msg: 'success',
        data: {
          list: Mock.mock({
            'list|20': [
              {
                'id|+1': 1,
                'title': '@ctitle(5, 20)',
                'author': '@cname',
                'status|0-1': 1,
                'created_at': '@datetime',
              },
            ],
          }).list,
          total: 100,
        },
      };
    },
  },
  {
    url: '/api/cms/article/save',
    method: 'post',
    response: () => {
      return {
        code: 200,
        msg: '保存成功',
        data: { id: Mock.Random.guid() },
      };
    },
  },
];
```

**注册 Mock**：

```typescript
// src/mock/index.ts
import Mock from 'mockjs';
import cmsMock from './cms';
import userMock from './user';

// 注册 CMS Mock
cmsMock.forEach((item) => {
  Mock.mock(new RegExp(item.url), item.method, item.response);
});

// 注册用户 Mock
userMock.forEach((item) => {
  Mock.mock(new RegExp(item.url), item.method, item.response);
});
```

### 5.3 Mock 切换机制

**环境变量控制**：

```bash
# .env.development（开发环境）
VITE_USE_MOCK=true  # 启用 Mock

# .env.production（生产环境）
VITE_USE_MOCK=false  # 禁用 Mock
```

**条件导入 Mock**：

```typescript
// src/main.ts
import { createApp } from 'vue';
import App from './App.vue';

const app = createApp(App);

// 只在开发环境且启用 Mock 时导入
if (import.meta.env.MODE === 'development' && import.meta.env.VITE_USE_MOCK === 'true') {
  import('@/mock');
}

app.mount('#app');
```

**Axios 请求配置**：

```typescript
// src/api/request.ts
const instance = axios.create({
  baseURL: import.meta.env.MODE === 'production' 
    ? `${window.location.origin}/be`  // 生产环境：真实后端
    : '',  // 开发环境：Mock 拦截或代理
});
```

### 5.4 Mock 与真实接口对比

| 特性 | Mock 数据 | 真实接口 |
|------|----------|----------|
| **数据来源** | 前端生成 | 后端数据库 |
| **响应速度** | 极快（无网络延迟） | 取决于网络和后端性能 |
| **数据一致性** | 随机生成，每次不同 | 数据库持久化，一致 |
| **适用场景** | 前端开发、接口未就绪 | 联调、测试、生产 |
| **切换方式** | 环境变量 | 环境变量 |

### 5.5 最佳实践

1. **Mock 数据与真实接口保持一致**：
   - 响应格式相同
   - 字段类型相同
   - 错误码相同

2. **使用 TypeScript 类型定义**：
   ```typescript
   // src/types/cms.ts
   export interface Article {
     id: number;
     title: string;
     author: string;
     status: 0 | 1;
     created_at: string;
   }
   
   // Mock 和真实接口都使用相同类型
   ```

3. **Mock 数据合理性**：
   - 使用 MockJS 的占位符生成真实感数据
   - 避免硬编码固定值
   - 模拟分页、排序、筛选逻辑

4. **及时更新 Mock**：
   - 后端接口变更时同步更新 Mock
   - 定期对比 Mock 和真实接口

---


## 6. 前后端接口对接

### 6.1 RESTful API 设计规范

ZigCMS 采用 RESTful API 设计风格，遵循统一的接口规范。

**HTTP 方法约定**：

| 方法 | 用途 | 示例 |
|------|------|------|
| **GET** | 查询资源 | `GET /api/users` - 获取用户列表 |
| **POST** | 创建资源 | `POST /api/users` - 创建用户 |
| **PUT** | 更新资源（全量） | `PUT /api/users/1` - 更新用户 |
| **PATCH** | 更新资源（部分） | `PATCH /api/users/1` - 部分更新 |
| **DELETE** | 删除资源 | `DELETE /api/users/1` - 删除用户 |

**URL 命名规范**：

```
✅ 推荐：
GET    /api/users          # 获取用户列表
GET    /api/users/1        # 获取单个用户
POST   /api/users          # 创建用户
PUT    /api/users/1        # 更新用户
DELETE /api/users/1        # 删除用户

❌ 避免：
GET    /api/getUserList
POST   /api/createUser
POST   /api/updateUser
POST   /api/deleteUser
```

### 6.2 统一响应格式

**成功响应**：

```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "id": 1,
    "username": "admin",
    "email": "admin@example.com"
  }
}
```

**分页响应**：

```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "list": [
      { "id": 1, "username": "user1" },
      { "id": 2, "username": "user2" }
    ],
    "pagination": {
      "page": 1,
      "pageSize": 20,
      "total": 100
    }
  }
}
```

**错误响应**：

```json
{
  "code": 400,
  "msg": "用户名已存在",
  "data": null
}
```

### 6.3 响应格式标准化

前端使用 `normalizeApiResponse` 函数统一处理后端响应，兼容不同的响应格式。

```typescript
// src/api/response.ts
export function normalizeApiResponse<T = unknown>(payload: any): NormalizedResponse<T> {
  // 统一 code（0 或 200 都视为成功）
  const code = payload?.code === 0 || payload?.code === 200 ? 200 : payload?.code || 500;
  
  // 统一 msg
  const msg = String(payload?.msg ?? payload?.message ?? '');
  
  // 统一 data
  const data = payload?.data ?? {};
  
  // 统一 list（兼容 list、items、data 数组）
  const dataList = Array.isArray(data?.list)
    ? data.list
    : Array.isArray(data?.items)
    ? data.items
    : Array.isArray(data)
    ? data
    : [];
  
  // 统一 total
  const total = data?.total ?? data?.pagination?.total ?? dataList.length;
  
  return {
    code,
    msg,
    data,
    success: code === 200,
    list: dataList,
    total,
    pagination: {
      page: data?.page ?? data?.pagination?.page ?? 1,
      pageSize: data?.pageSize ?? data?.pagination?.pageSize ?? dataList.length || 10,
      total,
    },
  };
}
```

**Axios 响应拦截器**：

```typescript
// src/api/request.ts
instance.interceptors.response.use(
  (res: AxiosResponse): any => {
    const normalized = normalizeApiResponse(res.data);
    
    if (normalized.code === 200) {
      return Promise.resolve({
        code: normalized.code,
        msg: normalized.msg,
        data: {
          ...normalized.data,
          list: normalized.list,
          total: normalized.total,
          pagination: normalized.pagination,
        },
      });
    }
    
    if (normalized.code === 401) {
      // 登录失效，跳转登录页
      useUserStore().logout();
      router.push({ name: 'login' });
      return Promise.reject(new Error('登录失效'));
    }
    
    Message.error(normalized.msg || '网络错误');
    return Promise.reject({
      code: normalized.code,
      msg: normalized.msg,
      data: normalized.data,
    });
  },
  (error) => {
    Message.error('网络错误');
    return Promise.reject(error);
  }
);
```

### 6.4 错误码规范

| 错误码 | 含义 | 处理方式 |
|--------|------|----------|
| **200** | 成功 | 正常处理 |
| **400** | 请求参数错误 | 提示用户修改参数 |
| **401** | 未认证 | 跳转登录页 |
| **403** | 无权限 | 提示无权限 |
| **404** | 资源不存在 | 提示资源不存在 |
| **500** | 服务器错误 | 提示服务器错误 |

### 6.5 接口调用示例

**后端接口实现**：

```zig
// api/controllers/user/user.controller.zig
pub fn list(req: zap.Request) !void {
    // 1. 解析参数
    const page = req.getParamInt("page") orelse 1;
    const page_size = req.getParamInt("page_size") orelse 20;
    const keyword = req.getParam("keyword");
    
    // 2. 查询数据
    var q = OrmUser.Query();
    defer q.deinit();
    
    if (keyword) |kw| {
        _ = q.where("username", "LIKE", try std.fmt.allocPrint(allocator, "%{s}%", .{kw}));
    }
    
    _ = q.limit(page_size).offset((page - 1) * page_size);
    const users = try q.get();
    defer OrmUser.freeModels(users);
    
    const total = try q.count();
    
    // 3. 返回响应
    try base.send_success(req, .{
        .list = users,
        .pagination = .{
            .page = page,
            .pageSize = page_size,
            .total = total,
        },
    });
}
```

**前端接口调用**：

```typescript
// src/api/cms.ts
import request from './request';

export interface UserListParams {
  page?: number;
  page_size?: number;
  keyword?: string;
}

export async function getUserList(params: UserListParams) {
  return request('/api/users', params, null, 'post');
}
```

**组件中使用**：

```vue
<script setup lang="ts">
import { getUserList } from '@/api/cms';

const data = ref([]);
const pagination = reactive({ current: 1, pageSize: 20, total: 0 });
const keyword = ref('');

const fetchData = async () => {
  const res = await getUserList({
    page: pagination.current,
    page_size: pagination.pageSize,
    keyword: keyword.value,
  });
  
  data.value = res.data.list;
  pagination.total = res.data.total;
};

onMounted(() => {
  fetchData();
});
</script>
```

---

## 7. 认证授权机制

### 7.1 JWT 认证流程

ZigCMS 使用 **JWT（JSON Web Token）** 实现无状态认证。

**认证流程图**：

```
┌─────────┐                ┌─────────┐                ┌─────────┐
│  前端   │                │  后端   │                │  数据库 │
└────┬────┘                └────┬────┘                └────┬────┘
     │                          │                          │
     │  1. POST /api/login      │                          │
     │  { username, password }  │                          │
     ├─────────────────────────>│                          │
     │                          │  2. 验证用户名密码        │
     │                          ├─────────────────────────>│
     │                          │<─────────────────────────┤
     │                          │  3. 生成 JWT Token       │
     │  4. 返回 Token           │                          │
     │<─────────────────────────┤                          │
     │  { token, userInfo }     │                          │
     │                          │                          │
     │  5. 存储 Token           │                          │
     │  (localStorage)          │                          │
     │                          │                          │
     │  6. 后续请求携带 Token   │                          │
     │  Authorization: Bearer   │                          │
     ├─────────────────────────>│                          │
     │                          │  7. 验证 Token           │
     │                          │                          │
     │  8. 返回数据             │                          │
     │<─────────────────────────┤                          │
```

### 7.2 后端认证实现

**登录接口**：

```zig
// api/controllers/auth/login.controller.zig
pub fn login(req: zap.Request) !void {
    // 1. 解析请求
    const body = try req.parseBody(LoginDto);
    
    // 2. 验证用户名密码
    var q = OrmAdmin.Query();
    defer q.deinit();
    _ = q.where("username", "=", body.username);
    const users = try q.get();
    defer OrmAdmin.freeModels(users);
    
    if (users.len == 0) {
        return base.send_error(req, "用户名或密码错误", 400);
    }
    
    const user = users[0];
    if (!try verifyPassword(body.password, user.password)) {
        return base.send_error(req, "用户名或密码错误", 400);
    }
    
    // 3. 生成 JWT Token
    const token = try jwt.generateToken(allocator, .{
        .user_id = user.id.?,
        .username = user.username,
        .exp = std.time.timestamp() + 7 * 24 * 3600,  // 7天过期
    });
    defer allocator.free(token);
    
    // 4. 返回响应
    try base.send_success(req, .{
        .token = token,
        .userInfo = user,
        .expire = 7 * 24 * 3600,
    });
}
```

**认证中间件**：

```zig
// api/middleware/auth.middleware.zig
pub fn authMiddleware(req: *zap.Request, res: *zap.Response, next: NextFn) !void {
    // 1. 获取 Token
    const auth_header = req.getHeader("Authorization") orelse {
        return res.sendJson(.{ .code = 401, .msg = "未登录" });
    };
    
    if (!std.mem.startsWith(u8, auth_header, "Bearer ")) {
        return res.sendJson(.{ .code = 401, .msg = "Token 格式错误" });
    }
    
    const token = auth_header[7..];
    
    // 2. 验证 Token
    const payload = jwt.verifyToken(token) catch {
        return res.sendJson(.{ .code = 401, .msg = "Token 无效或已过期" });
    };
    
    // 3. 设置用户上下文
    req.setContext("user_id", payload.user_id);
    req.setContext("username", payload.username);
    
    // 4. 继续处理
    try next(req, res);
}
```


### 7.3 前端认证实现

**Token 存储**：

```typescript
// src/utils/auth.ts
const TOKEN_KEY = 'zigcms_token';

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string): void {
  localStorage.setItem(TOKEN_KEY, token);
}

export function removeToken(): void {
  localStorage.removeItem(TOKEN_KEY);
}
```

**登录逻辑**：

```typescript
// src/store/modules/user.ts
export const useUserStore = defineStore('user', {
  state: () => ({
    token: getToken() || '',
    userInfo: null as UserInfo | null,
  }),
  
  actions: {
    async login(username: string, password: string) {
      const res = await loginApi({ username, password });
      
      this.token = res.data.token;
      this.userInfo = res.data.userInfo;
      
      setToken(res.data.token);
    },
    
    logout() {
      this.token = '';
      this.userInfo = null;
      removeToken();
      router.push({ name: 'login' });
    },
  },
});
```

**请求拦截器（自动携带 Token）**：

```typescript
// src/api/request.ts
instance.interceptors.request.use(
  (config) => {
    const token = getToken();
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);
```

**响应拦截器（处理 401）**：

```typescript
instance.interceptors.response.use(
  (res) => {
    // ...
  },
  (error) => {
    if (error.response?.status === 401) {
      useUserStore().logout();
      Message.error('登录失效，请重新登录');
    }
    return Promise.reject(error);
  }
);
```

### 7.4 权限模型

ZigCMS 采用 **RBAC（基于角色的访问控制）** 模型，支持三级权限控制：

1. **角色权限**：用户属于哪些角色
2. **菜单权限**：角色可以访问哪些菜单
3. **按钮权限**：角色可以执行哪些操作

**权限数据结构**：

```typescript
interface UserInfo {
  id: number;
  username: string;
  roles: string[];  // ['admin', 'editor']
  permissions: string[];  // ['user:create', 'user:edit', 'user:delete']
}
```

### 7.5 前端权限控制

**路由权限**：

```typescript
// src/router/guard/permission.ts
router.beforeEach(async (to, from, next) => {
  const userStore = useUserStore();
  
  // 检查角色权限
  if (to.meta.roles && !to.meta.roles.some(role => userStore.roles.includes(role))) {
    Message.error('无权限访问');
    next({ name: 'dashboard' });
    return;
  }
  
  next();
});
```

**按钮权限指令**：

```typescript
// src/directive/permission/index.ts
export default {
  mounted(el: HTMLElement, binding: DirectiveBinding) {
    const { value } = binding;
    const userStore = useUserStore();
    
    if (value && !userStore.permissions.includes(value)) {
      el.parentNode?.removeChild(el);
    }
  },
};
```

**使用示例**：

```vue
<template>
  <!-- 只有 admin 角色可见 -->
  <a-button v-if="hasRole('admin')">管理员操作</a-button>
  
  <!-- 只有 user:delete 权限可见 -->
  <a-button v-permission="'user:delete'">删除用户</a-button>
</template>

<script setup lang="ts">
import { useUserStore } from '@/store';

const userStore = useUserStore();

const hasRole = (role: string) => {
  return userStore.roles.includes(role);
};
</script>
```

### 7.6 后端权限控制

**权限检查中间件**：

```zig
// api/middleware/permission.middleware.zig
pub fn requirePermission(permission: []const u8) MiddlewareFn {
    return struct {
        pub fn handle(req: *zap.Request, res: *zap.Response, next: NextFn) !void {
            const user_id = req.getContext("user_id") orelse {
                return res.sendJson(.{ .code = 401, .msg = "未登录" });
            };
            
            // 查询用户权限
            const permissions = try getUserPermissions(user_id);
            defer allocator.free(permissions);
            
            // 检查权限
            var has_permission = false;
            for (permissions) |perm| {
                if (std.mem.eql(u8, perm, permission)) {
                    has_permission = true;
                    break;
                }
            }
            
            if (!has_permission) {
                return res.sendJson(.{ .code = 403, .msg = "无权限" });
            }
            
            try next(req, res);
        }
    }.handle;
}
```

**路由注册**：

```zig
// api/bootstrap.zig
try app.route("POST", "/api/users", userController.create, .{
    .middleware = &.{ authMiddleware, requirePermission("user:create") },
});

try app.route("DELETE", "/api/users/:id", userController.delete, .{
    .middleware = &.{ authMiddleware, requirePermission("user:delete") },
});
```

---

## 8. 开发环境配置

### 8.1 环境要求

**后端（ZigCMS）**：
- Zig 0.15.0+
- SQLite 3.8+ / MySQL 5.7+ / PostgreSQL 12+
- Git

**前端（ecom-admin）**：
- Node.js 14.0+
- pnpm / npm / yarn
- Git

### 8.2 后端环境搭建

**1. 安装 Zig**：

```bash
# macOS
brew install zig

# Linux
# 下载并安装官方二进制包
wget https://ziglang.org/download/0.15.0/zig-linux-x86_64-0.15.0.tar.xz
tar -xf zig-linux-x86_64-0.15.0.tar.xz
sudo mv zig-linux-x86_64-0.15.0 /usr/local/zig
export PATH=$PATH:/usr/local/zig

# 验证安装
zig version
```

**2. 克隆项目**：

```bash
git clone <repository-url>
cd zigcms
```

**3. 配置环境变量**：

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑 .env 文件
vim .env
```

**4. 初始化数据库**：

```bash
# MySQL
mysql -u root -p < database_schema.sql

# SQLite（自动创建）
# 无需手动初始化
```

**5. 构建项目**：

```bash
# 开发模式
make dev

# 生产模式
make build
```

### 8.3 前端环境搭建

**1. 安装 Node.js**：

```bash
# macOS
brew install node

# Linux
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# 验证安装
node -v
npm -v
```

**2. 克隆项目**：

```bash
cd ecom-admin
```

**3. 安装依赖**：

```bash
# 使用 pnpm（推荐）
pnpm install

# 或使用 npm
npm install

# 或使用 yarn
yarn install
```

**4. 配置环境变量**：

```bash
# 开发环境配置已在 .env.development 中
# 生产环境配置在 .env.production 中
```

**5. 启动开发服务器**：

```bash
# 启动前端开发服务器
pnpm dev

# 或
npm run dev
```

### 8.4 环境变量说明

**后端环境变量（`.env`）**：

```bash
# 服务器配置
SERVER_HOST=127.0.0.1
SERVER_PORT=3000

# 数据库配置
DB_TYPE=mysql  # mysql | sqlite | postgresql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=zigcms
DB_USER=root
DB_PASSWORD=password

# 连接池配置（仅 MySQL）
DB_POOL_SIZE=10
DB_POOL_TIMEOUT=30

# JWT 配置
JWT_SECRET=your_secret_key_here
JWT_EXPIRE=604800  # 7天（秒）

# 日志配置
LOG_LEVEL=info  # debug | info | warn | error
LOG_FILE=./logs/zigcms.log

# 缓存配置
CACHE_TYPE=memory  # memory | redis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=
```

**前端环境变量（`.env.development`）**：

```bash
# 开发环境
VITE_NODE_ENV=development

# API 基础路径（留空使用 Mock 或代理）
VITE_API_BASE_URL=

# 是否启用 Mock
VITE_USE_MOCK=true

# 代理配置（在 vite.config.dev.ts 中配置）
```

**前端环境变量（`.env.production`）**：

```bash
# 生产环境
VITE_NODE_ENV=production

# API 基础路径
VITE_API_BASE_URL=/be

# 禁用 Mock
VITE_USE_MOCK=false
```

### 8.5 常见问题排查

**后端问题**：

1. **编译错误**：
   ```bash
   # 清理缓存
   make clean
   
   # 重新构建
   make build
   ```

2. **数据库连接失败**：
   - 检查数据库服务是否启动
   - 检查 `.env` 配置是否正确
   - 检查防火墙设置

3. **端口被占用**：
   ```bash
   # 查找占用端口的进程
   lsof -i :3000
   
   # 杀死进程
   kill -9 <PID>
   ```

**前端问题**：

1. **依赖安装失败**：
   ```bash
   # 清理缓存
   rm -rf node_modules pnpm-lock.yaml
   
   # 重新安装
   pnpm install
   ```

2. **代理配置问题**：
   - 检查 `config/vite.config.dev.ts` 中的代理配置
   - 确保后端服务已启动

3. **Mock 不生效**：
   - 检查 `VITE_USE_MOCK` 环境变量
   - 确保 `src/mock/index.ts` 已导入

---


## 9. 开发规范

### 9.1 后端开发规范

#### 代码风格

- **命名规范**：
  - 结构体：`PascalCase`（如 `UserService`）
  - 函数：`camelCase`（如 `getUserById`）
  - 常量：`SCREAMING_SNAKE_CASE`（如 `MAX_RETRY`）
  - 变量：`snake_case`（如 `user_id`）

- **文件命名**：
  - 模块文件：`mod.zig`
  - 实现文件：`xxx.zig`（小写，下划线分隔）
  - 测试文件：`xxx_test.zig`

#### 内存管理

- **RAII 模式**：使用 `defer` 确保资源释放
  ```zig
  var q = OrmUser.Query();
  defer q.deinit();  // 作用域结束时自动清理
  ```

- **Arena 分配器**：批量操作使用 Arena
  ```zig
  var arena = std.heap.ArenaAllocator.init(allocator);
  defer arena.deinit();  // 一次性释放所有内存
  ```

- **借用引用**：避免重复释放
  ```zig
  pub const AppContext = struct {
      db: *Database,  // 借用引用，不拥有所有权
      
      pub fn deinit(self: *AppContext) void {
          // 不释放 db，由所有者负责
      }
  };
  ```

#### SQL 安全

- **强制使用参数化查询**：
  ```zig
  // ✅ 推荐
  _ = q.where("username", "=", user_input);
  
  // ❌ 禁止
  const sql = try std.fmt.allocPrint(allocator, 
      "SELECT * FROM users WHERE username = '{s}'", .{user_input});
  ```

- **ORM 查询结果内存管理**：
  ```zig
  // ✅ 推荐：使用 Arena
  var result = try q.getWithArena(allocator);
  defer result.deinit();
  
  // ❌ 避免：浅拷贝
  const users = try q.get();
  defer OrmUser.freeModels(users);
  // 不要在 freeModels 后使用 users
  ```

#### 错误处理

- **显式错误处理**：
  ```zig
  pub fn createUser(dto: CreateUserDto) !User {
      if (dto.username.len < 3) {
          return error.UsernameTooShort;
      }
      
      const user = try db.save(dto);
      return user;
  }
  ```

- **资源清理**：
  ```zig
  pub fn processRequest(allocator: Allocator) !Response {
      const file = try openFile();
      defer file.close();
      
      const buffer = try allocator.alloc(u8, 1024);
      errdefer allocator.free(buffer);  // 错误时自动释放
      
      // ...
  }
  ```

### 9.2 前端开发规范

#### 代码风格

- **命名规范**：
  - 组件：`PascalCase`（如 `UserList.vue`）
  - 函数：`camelCase`（如 `getUserList`）
  - 常量：`SCREAMING_SNAKE_CASE`（如 `API_BASE_URL`）
  - 变量：`camelCase`（如 `userId`）

- **文件命名**：
  - 组件：`PascalCase.vue`（如 `UserList.vue`）
  - 工具函数：`kebab-case.ts`（如 `auth-utils.ts`）
  - API 文件：`kebab-case.ts`（如 `user-api.ts`）

#### Vue 3 组合式 API

- **使用 `<script setup>`**：
  ```vue
  <script setup lang="ts">
  import { ref, onMounted } from 'vue';
  
  const count = ref(0);
  
  const increment = () => {
    count.value++;
  };
  
  onMounted(() => {
    console.log('组件已挂载');
  });
  </script>
  ```

- **响应式数据**：
  ```typescript
  // 基本类型使用 ref
  const count = ref(0);
  const name = ref('');
  
  // 对象使用 reactive
  const user = reactive({
    id: 1,
    name: 'admin',
  });
  
  // 数组使用 ref
  const list = ref<User[]>([]);
  ```

#### TypeScript 类型定义

- **定义接口**：
  ```typescript
  // src/types/user.ts
  export interface User {
    id: number;
    username: string;
    email: string;
    status: 0 | 1;
    created_at: string;
  }
  
  export interface UserListParams {
    page?: number;
    page_size?: number;
    keyword?: string;
  }
  ```

- **API 返回类型**：
  ```typescript
  export interface ApiResponse<T = any> {
    code: number;
    msg: string;
    data: T;
  }
  
  export async function getUserList(params: UserListParams): Promise<ApiResponse<{
    list: User[];
    total: number;
  }>> {
    return request('/api/users', params);
  }
  ```

#### 组件设计

- **单一职责**：每个组件只负责一件事
- **Props 验证**：
  ```vue
  <script setup lang="ts">
  interface Props {
    userId: number;
    editable?: boolean;
  }
  
  const props = withDefaults(defineProps<Props>(), {
    editable: false,
  });
  </script>
  ```

- **事件定义**：
  ```vue
  <script setup lang="ts">
  const emit = defineEmits<{
    (e: 'update', value: string): void;
    (e: 'delete', id: number): void;
  }>();
  
  const handleUpdate = (value: string) => {
    emit('update', value);
  };
  </script>
  ```

### 9.3 Git 提交规范

**Commit Message 格式**：

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Type 类型**：

- `feat`: 新功能
- `fix`: 修复 Bug
- `docs`: 文档更新
- `style`: 代码格式（不影响代码运行）
- `refactor`: 重构（既不是新功能也不是修复 Bug）
- `perf`: 性能优化
- `test`: 测试相关
- `chore`: 构建过程或辅助工具的变动

**示例**：

```bash
feat(user): 添加用户列表分页功能

- 实现分页查询接口
- 添加前端分页组件
- 更新用户列表页面

Closes #123
```

### 9.4 代码审查清单

**后端代码审查**：

- [ ] 符合整洁架构分层
- [ ] 命名规范一致
- [ ] 错误处理完善
- [ ] 内存安全（无泄漏、无重复释放）
- [ ] 使用参数化查询（无 SQL 注入风险）
- [ ] ORM 查询结果正确管理
- [ ] 有单元测试
- [ ] 日志记录适当
- [ ] 文档完整

**前端代码审查**：

- [ ] 组件职责单一
- [ ] TypeScript 类型定义完整
- [ ] 响应式数据使用正确
- [ ] Props 和 Emit 定义清晰
- [ ] 无内存泄漏（事件监听器已清理）
- [ ] 错误处理完善
- [ ] 用户体验良好（加载状态、错误提示）
- [ ] 代码可读性强

---

## 10. 常见问题

### 10.1 后端常见问题

**Q1: ORM 查询结果显示乱码？**

A: 这是 ORM 查询结果内存管理问题。解决方案：

```zig
// ✅ 使用 Arena Allocator
var result = try q.getWithArena(allocator);
defer result.deinit();

// 或手动深拷贝字符串字段
const copy = User{
    .name = try allocator.dupe(u8, original.name),
};
defer allocator.free(copy.name);
```

**Q2: 数据库连接池耗尽？**

A: 检查连接是否正确释放：

```zig
// ✅ 确保连接归还
var conn = try pool.acquire();
defer pool.release(conn);
```

**Q3: 如何切换数据库驱动？**

A: 修改 `.env` 文件：

```bash
# 切换到 SQLite
DB_TYPE=sqlite
DB_PATH=./zigcms.db

# 切换到 MySQL
DB_TYPE=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
```

**Q4: 如何防止 SQL 注入？**

A: 始终使用参数化查询：

```zig
// ✅ 安全
_ = q.where("username", "=", user_input);

// ❌ 危险
const sql = try std.fmt.allocPrint(allocator, 
    "SELECT * FROM users WHERE username = '{s}'", .{user_input});
```

### 10.2 前端常见问题

**Q1: Mock 数据不生效？**

A: 检查以下几点：
1. 确认 `VITE_USE_MOCK=true`
2. 确认 `src/mock/index.ts` 已在 `main.ts` 中导入
3. 确认 Mock URL 正则匹配正确

**Q2: 接口请求 401 未认证？**

A: 检查 Token 是否正确携带：

```typescript
// 检查 Token 是否存在
const token = getToken();
console.log('Token:', token);

// 检查请求头
console.log('Authorization:', config.headers.Authorization);
```

**Q3: 路由权限不生效？**

A: 检查路由守卫配置：

```typescript
// 确认路由守卫已注册
router.beforeEach(async (to, from, next) => {
  // 权限检查逻辑
});
```

**Q4: 组件状态不更新？**

A: 检查响应式数据使用：

```typescript
// ❌ 错误：直接修改 ref 对象
const user = ref({ name: 'admin' });
user.name = 'new name';  // 不会触发更新

// ✅ 正确：修改 ref.value
user.value.name = 'new name';

// 或使用 reactive
const user = reactive({ name: 'admin' });
user.name = 'new name';  // 正确
```

### 10.3 性能优化建议

**后端优化**：

1. **使用关系预加载**：解决 N+1 查询问题
2. **使用连接池**：减少数据库连接开销
3. **使用缓存**：减少数据库查询
4. **批量操作**：减少数据库往返次数
5. **索引优化**：为常用查询字段添加索引

**前端优化**：

1. **路由懒加载**：减少首屏加载时间
   ```typescript
   component: () => import('@/views/user/index.vue')
   ```

2. **组件懒加载**：按需加载组件
   ```vue
   <script setup lang="ts">
   const UserDetail = defineAsyncComponent(() => import('./UserDetail.vue'));
   </script>
   ```

3. **虚拟滚动**：处理大量数据列表
4. **防抖节流**：优化频繁触发的事件
5. **图片懒加载**：减少初始加载资源

---

## 附录

### A. 参考文档

**后端文档**：
- [整洁架构设计](docs/ARCHITECTURE.md)
- [项目结构说明](docs/PROJECT_STRUCTURE.md)
- [内存安全指南](docs/MEMORY_SAFETY.md)
- [ORM 使用指南](docs/orm_relations_usage.md)
- [参数化查询实现](docs/parameterized_query_implementation.md)

**前端文档**：
- [Vue 3 官方文档](https://vuejs.org/)
- [Pinia 官方文档](https://pinia.vuejs.org/)
- [Arco Design 官方文档](https://arco.design/)
- [Vite 官方文档](https://vitejs.dev/)

### B. 快速命令

**后端命令**：

```bash
# 开发模式
make dev

# 生产构建
make build

# 运行测试
make test

# 清理缓存
make clean

# 数据库迁移
zig build migrate -- up
```

**前端命令**：

```bash
# 启动开发服务器
pnpm dev

# 生产构建
pnpm build

# 预览生产构建
pnpm preview

# 类型检查
pnpm type:check

# 代码检查
pnpm lint
```

### C. 联系方式

- **项目地址**: <repository-url>
- **问题反馈**: <issues-url>
- **文档更新**: 2026-03-03

---

**文档维护者**: ZigCMS Team  
**版本**: 1.0.0  
**最后更新**: 2026-03-03


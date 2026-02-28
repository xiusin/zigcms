# 前后端菜单管理联调开发文档

## 1. 项目概述

### 1.1 目标
实现 ZigCMS 后端与 ecom-admin 前端在菜单管理功能上的完整联调，包括菜单的增删改查、树形结构展示、权限配置等功能。

### 1.2 涉及系统
- **后端**: ZigCMS (Zig 语言实现的 CMS 系统)
- **前端**: ecom-admin (Vue3 + Arco Design 管理后台)

---

## 2. 后端架构分析

### 2.1 目录职责

| 目录 | 职责 | 相关文件 |
|------|------|----------|
| `src/api/controllers/` | 接口层控制器 | `system_menu.controller.zig` |
| `src/api/dto/` | 数据传输对象 | `menu.dto.zig`, `menu_item.dto.zig`, `menu_save.dto.zig` |
| `src/api/bootstrap.zig` | 路由注册 | 注册 CRUD 路由和自定义路由 |
| `src/domain/entities/` | 领域实体 | `integration_models.zig` (SysMenu 定义) |
| `src/application/services/sql/` | ORM 服务 | `orm.zig` |

### 2.2 菜单模型定义 (SysMenu)

```zig
pub const SysMenu = struct {
    id: ?i32 = null,
    pid: i32 = 0,                    // 父菜单ID
    menu_name: []const u8 = "",      // 菜单名称
    menu_type: i32 = 2,              // 菜单类型: 1=目录, 2=菜单, 3=按钮
    icon: []const u8 = "",           // 图标
    path: []const u8 = "",           // 路由地址
    component: []const u8 = "",      // 组件路径
    perms: []const u8 = "",          // 权限标识
    sort: i32 = 0,                   // 排序
    is_hide: i32 = 0,                // 是否隐藏: 0=显示, 1=隐藏
    is_cache: i32 = 0,               // 是否缓存: 0=不缓存, 1=缓存
    status: i32 = 1,                 // 状态: 0=禁用, 1=启用
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};
```

### 2.3 现有接口分析

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 菜单树 | GET | `/api/system/menu/tree` | 获取菜单树形结构 |
| 权限查询 | GET | `/api/system/menu/permissions` | 获取菜单按钮权限 |
| 权限保存 | POST | `/api/system/menu/save-permissions` | 保存菜单按钮权限 |
| 菜单导出 | GET | `/api/system/menu/export` | 导出菜单 |
| CRUD列表 | GET | `/api/system/menu/list` | 通用CRUD列表 |
| CRUD保存 | POST | `/api/system/menu/save` | 通用CRUD保存 |
| CRUD删除 | POST | `/api/system/menu/delete` | 通用CRUD删除 |
| CRUD修改 | POST | `/api/system/menu/modify` | 通用CRUD修改 |

---

## 3. 前端架构分析

### 3.1 目录职责

| 目录 | 职责 | 相关文件 |
|------|------|----------|
| `src/views/system-manage/menu/` | 菜单管理页面 | `menu.vue` |
| `src/router/routes/modules/` | 路由配置 | `system.ts` |
| `src/api/` | API 接口 | `request.ts`, `api.ts` |
| `src/router/app-menus/` | 菜单生成 | `index.ts` |

### 3.2 前端菜单数据结构

```typescript
interface MenuItem {
  id: number;
  pid: number;
  menu_name: string;
  menu_type: number;  // 1=目录, 2=菜单, 3=按钮
  icon: string;
  path: string;
  component: string;
  sort: number;
  is_hide: number;
  is_cache: number;
  status: number;
  children?: MenuItem[];
}
```

### 3.3 前端调用接口

```typescript
// 获取菜单列表
request('/api/system/menu/list')

// 保存菜单
request('/api/system/menu/save', params)

// 删除菜单
request('/api/system/menu/delete', { id: record.id })

// 更新状态
request('/api/system/menu/set', {
  id: record.id,
  field: 'status',
  value: record.status === 1 ? 0 : 1,
})

// 获取权限
request('/api/system/menu/permissions', { menu_id: record.id })

// 保存权限
request('/api/system/menu/save-permissions', {
  menu_id: currentMenuId.value,
  permissions: permissionList.value,
})

// 导出
request('/api/system/menu/export', {})
```

---

## 4. 接口规范设计

### 4.1 接口清单

| 序号 | 接口名称 | 方法 | 路径 | 前端需求 |
|------|----------|------|------|----------|
| 1 | 菜单列表 | GET/POST | `/api/system/menu/list` | ✅ 已实现 |
| 2 | 菜单保存 | POST | `/api/system/menu/save` | ✅ 已实现 |
| 3 | 菜单删除 | POST | `/api/system/menu/delete` | ✅ 已实现 |
| 4 | 状态更新 | POST | `/api/system/menu/set` | ✅ 已实现 |
| 5 | 菜单树 | GET | `/api/system/menu/tree` | ✅ 已实现 |
| 6 | 权限查询 | GET | `/api/system/menu/permissions` | ✅ 已实现 |
| 7 | 权限保存 | POST | `/api/system/menu/save-permissions` | ✅ 已实现 |
| 8 | 菜单导出 | GET | `/api/system/menu/export` | ✅ 已实现 |

### 4.2 请求/响应规范

#### 4.2.1 菜单列表

**请求**:
```http
GET /api/system/menu/list
```

**响应**:
```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "list": [
      {
        "id": 1,
        "pid": 0,
        "menu_name": "系统管理",
        "menu_type": 1,
        "icon": "icon-settings",
        "path": "/system",
        "component": "",
        "sort": 1,
        "is_hide": 0,
        "is_cache": 0,
        "status": 1,
        "children": [
          {
            "id": 2,
            "pid": 1,
            "menu_name": "菜单管理",
            "menu_type": 2,
            "icon": "icon-menu",
            "path": "/system/menu-manage",
            "component": "system-manage/menu/menu.vue",
            "sort": 1,
            "is_hide": 0,
            "is_cache": 1,
            "status": 1
          }
        ]
      }
    ]
  }
}
```

#### 4.2.2 菜单保存

**请求**:
```http
POST /api/system/menu/save
Content-Type: application/json

{
  "id": 0,
  "pid": 0,
  "menu_name": "菜单名称",
  "menu_type": 2,
  "icon": "icon-menu",
  "path": "/path",
  "component": "component/path.vue",
  "sort": 0,
  "is_hide": 0,
  "is_cache": 0,
  "status": 1
}
```

**响应**:
```json
{
  "code": 200,
  "msg": "保存成功",
  "data": { "id": 1 }
}
```

#### 4.2.3 菜单删除

**请求**:
```http
POST /api/system/menu/delete
Content-Type: application/json

{ "id": 1 }
```

**响应**:
```json
{
  "code": 200,
  "msg": "删除成功",
  "data": null
}
```

#### 4.2.4 状态更新

**请求**:
```http
POST /api/system/menu/set
Content-Type: application/json

{
  "id": 1,
  "field": "status",
  "value": 0
}
```

**响应**:
```json
{
  "code": 200,
  "msg": "更新成功",
  "data": null
}
```

#### 4.2.5 菜单树

**请求**:
```http
GET /api/system/menu/tree
```

**响应**:
```json
{
  "code": 200,
  "msg": "success",
  "data": [
    {
      "id": 1,
      "pid": 0,
      "title": "系统管理",
      "menu_name": "系统管理",
      "value": 1,
      "key": 1
    }
  ]
}
```

#### 4.2.6 权限查询

**请求**:
```http
GET /api/system/menu/permissions?menu_id=1
```

**响应**:
```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "permissions": ["view", "add", "edit", "delete"]
  }
}
```

#### 4.2.7 权限保存

**请求**:
```http
POST /api/system/menu/save-permissions
Content-Type: application/json

{
  "menu_id": 1,
  "permissions": ["view", "add", "edit"]
}
```

**响应**:
```json
{
  "code": 200,
  "msg": "权限保存成功",
  "data": null
}
```

---

## 5. 数据模型映射

### 5.1 前后端字段映射

| 前端字段 | 后端字段 | 说明 |
|----------|----------|------|
| id | id | 菜单ID |
| pid | pid | 父菜单ID |
| menu_name | menu_name | 菜单名称 |
| menu_type | menu_type | 菜单类型 |
| icon | icon | 图标 |
| path | path | 路由地址 |
| component | component | 组件路径 |
| sort | sort | 排序 |
| is_hide | is_hide | 是否隐藏 |
| is_cache | is_cache | 是否缓存 |
| status | status | 状态 |

### 5.2 菜单类型定义

| 值 | 含义 | 前端展示 |
|----|------|----------|
| 1 | 目录 | 目录 |
| 2 | 菜单 | 菜单 |
| 3 | 按钮 | 按钮 |

### 5.3 状态定义

| 值 | 含义 | 前端展示 |
|----|------|----------|
| 0 | 禁用 | 禁用/关闭 |
| 1 | 启用 | 启用/开启 |

---

## 6. 开发规范

### 6.1 后端开发规范

1. **ORM 使用**: 必须使用 ORM/QueryBuilder，禁止裸 SQL
2. **错误处理**: 使用显式错误返回，统一错误码
3. **内存管理**: ORM 查询结果需要深拷贝字符串字段，防止悬垂指针
4. **接口响应**: 统一返回格式 `{code, msg, data}`

### 6.2 前端开发规范

1. **API 调用**: 使用统一的 `request` 方法
2. **响应处理**: 统一处理 `code === 200` 的成功响应
3. **错误处理**: 使用 `Message` 组件显示错误信息
4. **数据转换**: 布尔值与数值的转换（如 status: true → 1）

---

## 7. 接口差异分析

### 7.1 当前状态

| 接口 | 后端实现 | 前端调用 | 状态 |
|------|----------|----------|------|
| /api/system/menu/list | ✅ CRUD 自动生成 | ✅ | 可用 |
| /api/system/menu/save | ✅ CRUD 自动生成 | ✅ | 可用 |
| /api/system/menu/delete | ✅ CRUD 自动生成 | ✅ | 可用 |
| /api/system/menu/set | ✅ CRUD 自动生成 | ✅ | 可用 |
| /api/system/menu/tree | ✅ 自定义实现 | ✅ | 可用 |
| /api/system/menu/permissions | ✅ 自定义实现 | ✅ | 可用 |
| /api/system/menu/save-permissions | ✅ 自定义实现 | ✅ | 可用 |
| /api/system/menu/export | ✅ 自定义实现 | ✅ | 可用 |

### 7.2 潜在问题

1. **菜单树接口**: 后端返回的字段与前端期望的字段需要匹配
2. **权限接口**: 需要确认 `sys_permission` 表结构是否存在
3. **数据格式**: 前端发送的布尔值需要后端正确处理为数值

---

## 8. 测试用例

### 8.1 功能测试

| 功能 | 测试步骤 | 预期结果 |
|------|----------|----------|
| 菜单列表 | 打开菜单管理页面 | 显示菜单树形列表 |
| 添加菜单 | 点击添加按钮，填写表单，保存 | 菜单添加成功，列表刷新 |
| 编辑菜单 | 点击编辑按钮，修改信息，保存 | 菜单更新成功 |
| 删除菜单 | 点击删除按钮，确认删除 | 菜单删除成功 |
| 状态切换 | 点击状态开关 | 状态更新成功 |
| 权限配置 | 点击权限按钮，选择权限，保存 | 权限保存成功 |

### 8.2 边界测试

| 场景 | 测试数据 | 预期结果 |
|------|----------|----------|
| 空名称 | menu_name = "" | 返回错误提示 |
| 超长名称 | menu_name = 100字符 | 正常处理或返回错误 |
| 循环依赖 | pid 指向子菜单 | 返回错误提示 |
| 删除有子菜单 | 删除有 children 的菜单 | 返回错误提示或级联删除 |

---

## 9. 部署与联调

### 9.1 后端启动

```bash
cd /Users/xiusin/Desktop/zigcms
zig build run
```

### 9.2 前端启动

```bash
cd /Users/xiusin/Desktop/zigcms/ecom-admin
pnpm install
pnpm dev
```

### 9.3 代理配置

前端开发服务器需要配置代理到后端 API：

```typescript
// vite.config.dev.ts
server: {
  proxy: {
    '/api': {
      target: 'http://localhost:8080',
      changeOrigin: true,
    },
  },
}
```

---

## 10. 附录

### 10.1 相关文档

- [ZigCMS 架构文档](/Users/xiusin/Desktop/zigcms/docs/ARCHITECTURE.md)
- [API 文档](/Users/xiusin/Desktop/zigcms/docs/api/menu.html)
- [前端 CRUD 指南](/Users/xiusin/Desktop/zigcms/ecom-admin/docs/CRUD_FEATURES.md)

### 10.2 数据库表结构

```sql
CREATE TABLE sys_menu (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pid INTEGER DEFAULT 0,
    menu_name VARCHAR(100) NOT NULL,
    menu_type INTEGER DEFAULT 2,
    icon VARCHAR(50) DEFAULT '',
    path VARCHAR(200) DEFAULT '',
    component VARCHAR(200) DEFAULT '',
    perms VARCHAR(100) DEFAULT '',
    sort INTEGER DEFAULT 0,
    is_hide INTEGER DEFAULT 0,
    is_cache INTEGER DEFAULT 0,
    status INTEGER DEFAULT 1,
    created_at INTEGER,
    updated_at INTEGER
);

CREATE TABLE sys_permission (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    perm_name VARCHAR(50) NOT NULL,
    perm_code VARCHAR(50) NOT NULL,
    menu_id INTEGER NOT NULL,
    sort INTEGER DEFAULT 0,
    status INTEGER DEFAULT 1,
    created_at INTEGER,
    updated_at INTEGER
);
```

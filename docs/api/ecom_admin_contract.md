# ecom-admin 联调接口契约（登录 + 组织架构）

## 文档版本

- 当前版本：v1.3.0
- 更新时间：2026-02-28

## 变更记录

- v1.3.0
  - `/api/system/admin/save` 由扩展控制器接管，新增“创建即写入密码哈希、可选 role_id 同步角色关系”的行为
  - `/api/system/admin/delete` 增加级联清理 `sys_admin_role`
  - `/api/system/admin/set` 限定仅允许更新 `status`
  - `/api/system/dept/tree` 补充 `leader/phone/sort/status/raw` 字段，兼容组织架构页面编辑回填
- v1.2.0
  - `/api/member/refreshInfo` 增加 `server_time`
  - `/api/member/refreshInfo` 增加 `expire_soon`
  - `/api/system/admin/list` 增加 `role_names`
  - `/api/system/dept/delete` 支持 `delete_mode`（默认软删除，`hard` 为物理删除）
- v1.1.0
  - `/api/member/login` 与 `/api/member/refreshInfo` 增加 `expires_in`
  - `/api/system/admin/assignRoles` 增加幂等返回 `角色未变更`
- v1.0.0
  - 初版联调契约

## 通用响应

```json
{
  "code": 200,
  "msg": "success",
  "data": {}
}
```

## 错误码对照

- `200`：成功
- `401`：登录失效或未授权（如 token 过期/签名无效）
- 业务失败（`code != 200` 且 HTTP 200）：参数错误、资源不存在、状态冲突等

常见业务错误消息：
- `登录已失效，请重新登录`
- `keyword 长度不能超过 64`
- `存在无效角色ID`
- `该部门存在子部门，无法删除`
- `该部门下存在管理员，无法删除`

分页接口统一：

```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "list": [],
    "items": [],
    "total": 0,
    "pagination": { "total": 0 }
  }
}
```

## 登录相关

### 1) POST /api/member/login
请求：

```json
{ "username": "admin", "password": "123456" }
```

响应 data 关键字段：
- token
- userId
- username
- nickname
- avatar
- email
- mobile
- department_id
- department_name
- role_id
- role_ids
- role_text
- status
- pages
- buttons
- created_at
- expire
- expires_in

### 2) POST /api/member/refreshInfo
请求头：
- Authorization: Bearer {token}

响应 data 关键字段：
- token
- userId
- username
- nickname
- avatar
- email
- mobile
- department_id
- department_name
- role_ids
- role_text
- status
- pages
- buttons
- expires_in
- expire_soon
- server_time

### 3) POST /api/member/refreshPermissions
请求头：
- Authorization: Bearer {token}

响应 data 关键字段：
- pages
- buttons
- role_ids

## 组织架构相关

### 4) POST /api/system/dept/tree
请求：

```json
{ "keyword": "总部" }
```

响应 data：树节点数组，节点字段：
- id
- parent_id
- title
- dept_name
- dept_code
- leader
- phone
- sort
- status
- value
- key
- raw（完整部门对象，用于前端编辑回填）

### 5) POST /api/system/dept/save
请求：

```json
{
  "id": 0,
  "parent_id": null,
  "dept_name": "运营部",
  "dept_code": "OPS",
  "leader": "张三",
  "phone": "13800138000",
  "sort": 0,
  "status": 1
}
```

### 6) POST /api/system/dept/remove
请求：

```json
{ "id": 1, "delete_mode": "soft" }
```

删除模式：
- `soft`（默认）：更新 `status=0`
- `hard`：执行物理删除

失败场景：
- 存在子部门：`该部门存在子部门，无法删除`
- 存在管理员：`该部门下存在管理员，无法删除`

### 7) POST /api/system/admin/list
请求：

```json
{
  "page": 1,
  "limit": 10,
  "keyword": "admin",
  "status": 1,
  "dept_id": 1,
  "role_id": 2
}
```

响应 list 单项关键字段：
- id
- username
- nickname
- mobile
- email
- avatar
- gender
- status
- dept_id
- last_login
- role_ids
- role_names
- role_name
- role_text

### 8) POST /api/system/admin/save
请求关键字段：
- id
- username
- nickname
- password
- confirm_password
- mobile
- email
- avatar
- gender
- dept_id
- role_id
- remark

行为约束：
- 新增管理员：
  - 必填 `username/nickname/password/confirm_password`
  - `password` 与 `confirm_password` 必须一致
  - 后端会将密码写入 `password_hash`
- 编辑管理员：
  - `password` 非空时才更新密码哈希
  - `role_id` 传入时会覆盖管理员角色关系（`role_id<=0` 表示清空角色）
- 唯一性：`username` 必须唯一
- 角色校验：`role_id` 必须存在且启用

### 9) POST /api/system/admin/set
请求：

```json
{ "id": 1, "field": "status", "value": 0 }
```

### 10) POST /api/system/admin/resetPassword
请求：

```json
{ "id": 1 }
```

行为约束：
- 删除管理员时，后端会先清理 `sys_admin_role` 关联，再删除管理员。

### 11) POST /api/system/admin/delete
请求：

```json
{ "id": 1 }
```

### 12) POST /api/system/admin/assignRoles
请求：

```json
{ "id": 1, "role_ids": [1, 2] }
```

幂等行为：
- 当角色集合未变化时，响应 `角色未变更`。

### 13) POST /api/role/list
请求：

```json
{ "pageSize": 100 }
```

响应 list 单项关键字段：
- id
- role_name
- role_key
- status

## 冒烟脚本说明

- 脚本路径：`scripts/ecom_org_smoke.sh`
- 可选环境变量：
  - `API_BASE`：接口地址
  - `USERNAME` / `PASSWORD`：登录账号
  - `STRICT_MODE=1`：开启关键字段断言（如 `expires_in/server_time/role_ids/role_names`）
  - `FAIL_DUMP_FILE`：失败响应落盘文件路径

### 完整链路冒烟（部门 + 管理员）

- 脚本路径：`scripts/ecom_org_full_smoke.sh`
- 覆盖链路：
  - 部门新增 -> 部门树检索
  - 管理员新增（含密码哈希与角色绑定）
  - 管理员状态切换
  - 管理员角色分配
  - 管理员列表检索
  - 管理员删除 + 部门删除（硬删清理）
- 可选环境变量：
  - `API_BASE`：接口地址（默认 `http://127.0.0.1:3000`）
  - `USERNAME` / `PASSWORD`：登录账号（默认 `admin/123456`）
  - `ROLE_ID`：新建管理员绑定角色（默认 `2`）
  - `FAIL_DUMP_FILE`：失败响应落盘文件

### 推荐执行顺序

1. 先执行 mock 数据 SQL：`docs/sql/ecom_org_mock_seed.sql`
2. 再执行快速冒烟：`bash ./scripts/ecom_org_smoke.sh`
3. 最后执行完整冒烟：`bash ./scripts/ecom_org_full_smoke.sh`

### 幂等回归（连续两轮）

- 脚本路径：`scripts/ecom_org_idempotent_regression.sh`
- 作用：连续执行两次 `ecom_org_full_smoke.sh`，验证重复回归不会造成数据污染或唯一约束冲突。
- 执行命令：`bash ./scripts/ecom_org_idempotent_regression.sh`

### DB 无污染断言

- 脚本路径：`scripts/ecom_org_db_assert.sh`
- 作用：校验回归后无 `ITG_` 部门、无 `itg_admin_` 管理员及其关联残留。
- 默认检查项：
  - `sys_dept.dept_code LIKE 'ITG_%'`
  - `sys_admin.username LIKE 'itg_admin_%'`
  - `sys_admin_role` 与 `itg_admin_` 关联残留
  - `sys_admin.dept_id` 对 `ITG_` 部门引用残留
- 执行命令：
  - `bash ./scripts/ecom_org_db_assert.sh`
  - 若需指定连接：`DB_HOST=127.0.0.1 DB_PORT=3306 DB_USER=root DB_PASSWORD=*** DB_NAME=zigcms bash ./scripts/ecom_org_db_assert.sh`

## 开发代理自检

- 命令：`pnpm run dev:proxy-check`
- 脚本路径：`ecom-admin/scripts/dev_proxy_check.sh`
- 作用：校验前端开发代理 `/api/*` 已透传到后端，而不是命中前端 404。
- 默认检查项：
  - `POST /api/member/refreshInfo`（未登录期望 `HTTP 200 + code 401`）
  - `POST /api/member/refreshPermissions`（未登录期望 `HTTP 200 + code 401`）
- 可选环境变量：
  - `FRONTEND_BASE`：前端开发地址，默认 `http://127.0.0.1:3201`
  - `FAIL_DUMP_FILE`：失败响应落盘文件

## 开发环境变量建议

- `VITE_PROXY_TARGET`：Vite dev 代理后端目标地址，建议在 `.env.development` 显式配置，默认 `http://127.0.0.1:3000`。

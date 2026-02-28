---
description: 使用 curl 验证 /api/role/list 的 ETag 缓存协商与失效
---

1. 准备基础变量（替换 BASE 和 TOKEN）：
```bash
BASE="http://localhost:8080"
TOKEN=""  # 如需鉴权，附上 Authorization 头
```

2. 首次请求，获取 ETag：
```bash
curl -i "$BASE/api/role/list?pageSize=100" \
  -H "Authorization: $TOKEN"
```
预期：响应头包含 `ETag` 和 `Cache-Control`。

3. 复用 ETag，验证 304：
```bash
ETAG="\"<上一条响应里的ETag值>\""
curl -i "$BASE/api/role/list?pageSize=100" \
  -H "Authorization: $TOKEN" \
  -H "If-None-Match: $ETAG"
```
预期：返回 304。

4. 触发缓存失效（任选其一）：
- 新增/修改/删除角色
- 保存权限：`/api/system/role/permissions/save`

5. 再次请求，ETag 应更新：
```bash
curl -i "$BASE/api/role/list?pageSize=100" \
  -H "Authorization: $TOKEN"
```
预期：ETag 与步骤 2 不同。

6. 验证本地缓存回退（前端逻辑）：
- 断网或伪造 500，让两次获取失败
- 应回退至本地缓存或空列表提示

注意：
- 若使用代理或 HTTPS，调整 BASE 与鉴权头
- 角色 pageSize=100 仅为示例，按需调整

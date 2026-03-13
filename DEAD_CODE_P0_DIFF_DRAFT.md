# Zig 死代码清理 P0：逐文件改动清单 + 预期 Diff 草案

> 作用：用于你确认后直接落地执行。当前仅产出草案，不改业务逻辑。  
> 依据：`DEAD_CODE_REPORT_ZIG.md`、`DEAD_CODE_CLEANUP_PLAN_ZIG.md`

---

## 1) `src/api/controllers/mod.zig`

### 目标
移除“实时通信控制器”空壳注释块，避免长期死分支误导。

### 预期修改区间
- `src/api/controllers/mod.zig:84-89`

### 预期 Diff（草案）
```diff
-// 实时通信控制器
-pub const realtime = struct {
-    // TODO: WebSocket 和 SSE 功能需要 zap 支持，暂时注释
-    // pub const WebSocket = @import("websocket.controller.zig").WebSocketController;
-    // pub const SSE = @import("sse.controller.zig").SSEController;
-};
+
```

### 风险
- 低风险。当前 `realtime` 为空导出结构体，无实际功能调用。

---

## 2) `src/infrastructure/mod.zig`

### 目标
移除“messaging 待实现注释导出”，避免主入口文档与真实导出不一致。

### 预期修改区间
- `src/infrastructure/mod.zig:76-79`

### 预期 Diff（草案）
```diff
-/// 消息系统基础设施（待实现）
-///
-/// 提供消息队列功能，用于异步任务处理和事件驱动架构。
-// pub const messaging = @import("messaging/mod.zig");
+
```

### 风险
- 低风险。当前为注释，不参与编译。

---

## 3) `src/application/usecases/mod.zig`

### 目标
移除未接线的注释占位导出，保留可运行核心（UseCase / UseCaseExecutor）。

### 预期修改区间
- `src/application/usecases/mod.zig:61-76`

### 预期 Diff（草案）
```diff
-// 导出用例模块
-pub const user = struct {
-    // TODO: 用户相关用例
-    // pub const RegisterUser = @import("user/register_user.zig");
-    // pub const LoginUser = @import("user/login_user.zig");
-};
-
-pub const content = struct {
-    // TODO: 内容管理用例
-    // pub const CreateArticle = @import("content/create_article.zig");
-    // pub const PublishArticle = @import("content/publish_article.zig");
-};
-
-pub const member = struct {
-    // TODO: 会员管理用例
-};
+
```

### 风险
- 低风险。当前为纯占位注释模块，暂无导出实现。

---

## 4) patch 遗留文件迁出 `src`（不建议继续放生产代码目录）

### 目标
将补丁草案文件移到文档归档路径，避免被误判为可编译生产代码。

### 迁移文件
- `src/infrastructure/security/security_monitor_db.patch.zig`
- `src/infrastructure/security/security_monitor_ws.patch.zig`

### 建议迁移目标
- `docs/patches/security_monitor_db.patch.zig`
- `docs/patches/security_monitor_ws.patch.zig`

### 操作草案
```bash
# 仅示例，执行前先确认 docs/patches 目录策略
mkdir -p docs/patches
mv src/infrastructure/security/security_monitor_db.patch.zig docs/patches/
mv src/infrastructure/security/security_monitor_ws.patch.zig docs/patches/
```

### 风险
- 低风险。此类文件不应参与业务编译链路。

---

## 5) P0 执行后验证清单

1. `zig build`
2. `zig build test`
3. （联动）`pnpm -C ecom-admin type-check`
4. （联动）`pnpm -C ecom-admin build`

---

## 6) 回滚点建议

- 提交拆分：
  - Commit A：删除注释死分支（3个文件）
  - Commit B：迁移 patch 文件（2个文件）
- 出现异常时可按提交粒度回滚。

---

## 7) 执行状态

- 当前状态：**Draft 已完成，待确认后执行落地修改**

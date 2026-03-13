# Zig 端死代码清理执行计划（基于 DEAD_CODE_REPORT_ZIG）

> 基线报告：`DEAD_CODE_REPORT_ZIG.md`  
> 目标：在不破坏现网功能前提下，分批清理死代码并建立防回归机制。

---

## 1. 执行原则

1. 先清理“高置信、低风险”再处理“可能未来启用模块”。
2. 每一批必须：**删除/隔离 -> 编译 -> 回归 -> 合并**。
3. 对“feature_unwired / plugin_unwired”先做业务确认，不直接删。
4. 保持最小变更：每批独立 PR，避免一次性大删除。

---

## 2. 批次划分（P0 / P1 / P2）

## P0（立即处理，低争议，高收益）

### P0-A 注释禁用死分支（建议删除或恢复接线，二选一）

- `src/api/controllers/mod.zig:86-88`（WebSocket/SSE 导出注释）
- `src/infrastructure/mod.zig:76-79`（messaging 导出注释）
- `src/application/usecases/mod.zig:63-71`（usecase 导出占位注释）

**处理动作建议**
- 若本迭代不启用：删除注释分支与占位代码。
- 若计划启用：补路由/导出/容器接线，禁止“只留注释”。

### P0-B 产物/补丁遗留文件（迁出 src）

- `src/infrastructure/security/security_monitor_db.patch.zig`
- `src/infrastructure/security/security_monitor_ws.patch.zig`

**处理动作建议**
- 移动到 `docs/patches/` 或删除（若已合并到主实现）。

---

## P1（高置信不可达模块，建议清理）

> 依据：`DEAD_CODE_REPORT_ZIG.md` 中 `unreferenced_module` 与 `middleware_unwired` 分类。

### P1-A middleware 未接线组

- `src/api/middleware/mod.zig`
- `src/api/middleware/auth.middleware.zig`
- `src/api/middleware/performance_tracking.zig`
- `src/api/middleware/request_id.middleware.zig`
- `src/api/middleware/security.middleware.zig`

### P1-B 核心未引用组（优先分批）

- `src/core/config/auto_loader.zig`
- `src/core/config/config_loader_v2.zig`
- `src/core/config/services.zig`
- `src/core/logger/log_optimizer.zig`
- `src/core/patterns/command.zig`
- `src/core/patterns/ddd_errors.zig`
- `src/core/patterns/domain_event_bus.zig`
- `src/core/patterns/projection.zig`
- `src/core/patterns/query.zig`

### P1-C 服务层未引用组（优先“模块级删除”）

- `src/application/services/http/*`
- `src/application/services/pool/*`
- `src/application/services/template/*`（保留 `template_test.zig` 可后置）
- `src/application/services/thread/thread_manager.zig`
- `src/application/services/upload/upload.zig`
- `src/application/services/validator/*`
- `src/application/services/ai/ai.zig`

---

## P2（需业务确认后处理）

> 依据：`feature_unwired` 与 `plugin_unwired` 分类，可能是“规划功能”。

### P2-A 业务功能未接线组（先确认再删）

- moderation 相关控制器/领域/基础设施
- alert_rule / sensitive_word / feedback_comment 相关链路
- quality_center/report.controller.zig
- security/report.controller.zig

### P2-B 插件系统未接线组

- `src/plugins/*`（除测试/模板）
- `src/application/services/plugins/plugin_system.zig`

**处理动作建议**
1. 若路线图 3 个月内不用：归档并移出主编译路径。
2. 若会启用：立项补接线，不应长期“不可达”。

---

## 3. 每批执行步骤（SOP）

1. 建立分支（每批一个分支）。
2. 删除/迁移对应文件与导出。
3. 修复 import 悬挂（编译器报错即修）。
4. 运行验证命令。
5. 记录删除清单 + 风险 + 回滚点。
6. 提交 PR 并做最小回归。

---

## 4. 验证命令（建议）

### 后端

- `zig build`
- `zig build test`

### 前端联动（防接口误删影响）

- `pnpm -C ecom-admin type-check`
- `pnpm -C ecom-admin build`

### 冒烟

- 启动后验证登录、系统管理、质量中心主要路由
- 验证 API 关键端点仍可访问

---

## 5. 回滚策略

1. 每批次独立 PR，可单独回滚。
2. 删除前生成清单（文件 + 哈希 + 提交号）。
3. 一旦发现误删：按批次回滚，不跨批回滚。

---

## 6. 建议执行顺序（高收益）

1. **先做 P0**（清理注释禁用+补丁遗留，风险最低）
2. 再做 **P1-A / P1-B**（中等风险，高收益）
3. 最后做 **P2**（必须业务 Owner 确认）

---

## 7. 交付物要求（每批）

- 删除/迁移文件列表
- 编译与测试结果
- 影响面说明（模块、路由、DI、服务）
- 回滚提交号

---

## 8. 备注

- 全量候选清单与区间以 `DEAD_CODE_REPORT_ZIG.md` 为准。
- 本计划不直接执行删除，仅定义可执行路径与门禁。

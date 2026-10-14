# ZigCMS 死代码与重复实现审计报告

> 生成日期：2026-10-14 ｜ 范围：全仓 `src/`（790 文件，仅 Zig 源码）｜ 方法：目录级 diff、全仓引用链 grep、AST 形状扫描、双路交叉复核
> 本报告为只读审计，未修改任何代码。

## 修复状态（2026-10-14 更新）

| 项 | 状态 |
|----|------|
| A1 cache 双侧 fork | ✅ 已修：保留 infrastructure 侧，application 重复副本删除，引用重定向 |
| A2 http 双侧 fork | ✅ 已修：application 侧删除，统一由 infrastructure/http 提供（基建保留） |
| A3 redis 零引用 shim | ✅ 已修：完整实现整体迁入 infrastructure/redis，shim 删除 |
| A4 orm 死门面 | ✅ 已修：删除，sql/orm.zig 为唯一 ORM |
| D compareValues 双实现 | ✅ 已修：functions.zig 单份（pub），renderer 引用 |
| C 中 global.zig 不可达块 | ✅ 已修：return 后注释块清理 |
| A5 HTTP 子系统/通用池两侧均未接入 | ⏸ 开放：基建保留不删，接入决策待定 |
| B 桩函数 / NotImplemented | ⏸ 开放：按业务优先级排期 |
| C 其余注释代码块 | ⏸ 开放 |
| E 注册未消费（UserService 等） | ⏸ 开放 |

测试基线：682 → 619，减少的 63 项均为被删重复副本自带测试，保留侧同语义测试仍在运行，零覆盖损失。

## 总览

| 类别 | 条数 | 涉及文件 | 行数规模 |
|------|------|----------|----------|
| A. 运行时不可达的整模块（含 fork 副本） | 5 组 | 17 文件 | ≈5873 |
| B. 桩函数 / 空实现 / NotImplemented | 9 处 | 7 文件 | ≈60 |
| C. 被注释掉的大段代码 | 9 处 | 8 文件 | ≈150 |
| D. 重复实现的函数 | 1 处 | 2 文件 | 16 |
| E. 注册未消费（DI/导出无使用方） | 2 处 | 3 文件 | ≈290 |
| F. 永假/永真分支 | 0 处 | — | — |

---

## A. 运行时不可达的整模块（重复实现的"死侧"）

以下模块在**运行链路上零引用**（仅 `root.zig` 测试聚合块触达，或全仓无任何 `@import`）：

| # | 死代码 | 替代实现（活侧） | 性质 | 证据 |
|---|--------|------------------|------|------|
| A1 | `src/infrastructure/cache/`（6 文件） | `src/application/services/cache/`（被 root.zig:55、app_context.zig:146、csrf/rate_limiter/rbac 中间件、cache_drivers.zig 等 10+ 处引用） | 复制 fork：`cache.zig` 头 45 行逐字相同，仅 import 路径不同（598 vs 597 行） | infra 侧全仓唯一引用为 root.zig:666-668 测试聚合 |
| A2 | `src/infrastructure/http/`（3 文件） | —（见 A5，两侧都无运行方） | 复制 fork：client.zig 1334 vs 1333 行逐字相同（仅 import 差异） | 仅 root.zig:670-671 测试聚合 |
| A3 | `src/infrastructure/redis/mod.zig` | `src/application/services/redis/`（15 文件，root.zig:114 导出、cache_drivers.zig:13 可达） | 兼容 shim（"从 application/services/redis 重导出"），且无人使用 | 全仓 0 处 `@import` |
| A4 | `src/application/services/orm/`（4 文件，45 行门面 + entity/repository/tests） | `src/application/services/sql/orm.zig`（5691 行，10+ 控制器在用） | 新旧两套 ORM：sql/ 是 Eloquent 风格实际在用；orm/ 是 GORM 风格门面，业务零使用 | 仅 application/mod.zig:64 导出声明 + root.zig:625-626 测试聚合 |
| A5 | HTTP 客户端子系统整体 + 通用对象池 | — | **两侧都死**：`application/services/http/`、`infrastructure/http/`、`application/services/pool/pool.zig`（823 行通用池）运行代码均无引用 | 仅测试聚合块触达；无任何控制器/服务使用 HttpClient |

> 池实现辨析：`pool/pool.zig`（通用 `Pool(T)`）、两份 `http/pool.zig`（HTTP 连接池 ClientPool）、`redis/pool.zig`（Redis 连接池）不是同域重复；三者中**只有 `redis/pool.zig` 在运行链路上**。

---

## B. 桩函数 / 空实现（永不产出有效逻辑）

| 位置 | 证据 | 置信度 |
|------|------|--------|
| `src/infrastructure/database/mysql_sensitive_word_repository.zig:14-16,18-25,50-65,67+` | Create/UpdateWith/Delete/get/getWithArena/count 全部 `return error.NotImplemented;` | 高 |
| `src/infrastructure/database/mysql_role_repository.zig:15-26,55-70,91-106` | 同上，纯桩 | 高 |
| `src/infrastructure/database/mod.zig:110-115` | `// TODO: 实现数据库工厂` + `return error.NotImplemented;` | 高 |
| `src/application/services/oauth/oauth_provider.interface.zig:91-106` | feishu/wechat/qq/github 四分支均 `// TODO: 实现…` + NotImplemented | 高 |
| `src/application/services/sql/query_with_context.zig:233-239` | `// TODO: 实现批量插入`，实现被注释 | 高 |
| `src/core/patterns/aggregate_root.zig:256-259` | `destroy` 空 body，注释自认"需要知道具体类型才能释放" | 高 |
| `src/core/patterns/projection.zig:59-62` | 基类 `apply` 空实现（可被子类覆盖，设计意图） | 低 |
| `src/application/services/mod.zig:16-17` | 原 `PluginSystemService` 导入被注释，替换为临时空 struct | 中 |
| `src/application/services/sql/interface.zig:54-61,106-112` | PostgreSQL/MySQL fallback 返回 NotAvailable（**设计性降级**，非死代码） | 中 |

> 两个 MySQL 仓储（sensitive_word / role）实为接口满足性占位：方法签名齐备但全部抛错，调用即失败。

---

## C. 被注释掉的大段代码 / 不可达块

| 位置 | 行数 | 内容 | 置信度 |
|------|------|------|--------|
| `src/application/services/events/events.zig:982-1013,1015-1049,1102-1133` | ~100 | 三个完整 test 块被注释（监听器重添加/优先级边界/类型安全事件） | 高 |
| `src/core/primitives/global.zig:204-215` | ~12 | **位于 `return` 之后的不可达**旧 pg 查询代码 | 高 |
| `src/core/utils/tos.zig:68-100` | ~33 | PHP 移植残留（`$urlParamListArray` 等） | 高 |
| `src/api/services/user_service.zig:85-88` | 4 | 注释掉的 getUserByUsername 调用 | 中 |
| `src/application/services/sql/query_with_context.zig:236-239` | 4 | 批量插入实现注释 | 高 |
| `src/core/utils/github.zig:202-205` | 4 | Proxy 构造注释 | 中 |
| `src/api/controllers/setting.controller.zig:27`、`src/api/bootstrap.zig:129` | 各 1 | 单行禁用注释 | 低 |
| `src/core/context/request_context.zig:278-313` | ~36 | 文档性 ```zig 示例注释（非死代码） | 低 |

---

## D. 重复实现的函数（同仓双份逻辑）

| 函数 | 位置 | 说明 |
|------|------|------|
| `compareValues(a, b) i32` | `src/application/services/template/renderer.zig:409` 与 `src/application/services/template/functions.zig:302` | 同一 JSON 值比较逻辑双份实现，各自文件内均被使用；template 包内应合一（一处改为引用另一处或提升到 functions） |

另注（子代理核查通过）：模板 engine/functions、rate_limiter、rbac、plugin_manager 等重点目录的**私有函数均有同文件调用者，未发现无调用者的死函数**。

---

## E. 注册未消费（挂起状态，非严格死代码）

| 位置 | 说明 |
|------|------|
| `src/api/services/user_service.zig`（201 行） | DI 已注册（root.zig:411-433 `registerUserServices`），但全仓无任何控制器 `resolve(UserService)`；且业务服务落在 api 层，违反 AGENTS.md 分层规范 |
| `src/api/services/auth_service.zig`（87 行） | 活代码（login.controller.zig:46 使用），但同样属于"业务服务在 api 层"的架构违规；与 application 层无功能重叠，**不构成重复实现** |

---

## 风险提示

1. **A1/A2/A3 是"fork 后分叉"型死副本**：若未来有人误改 infra 侧（以为是真实现），会与活侧行为悄悄脱节——这是双目录结构最危险的失败模式。
2. **B 类 MySQL 仓储桩**：调用即 `error.NotImplemented`，接口满足性测试无法发现，只有运行时请求才会暴露。
3. `global.zig:204-215` 是全仓唯一确认的**return 后不可达块**，编译器不报错，纯人工债。

## 建议处置顺序

1. **删除 A3（`infrastructure/redis/mod.zig`）**——零引用 shim，删除零风险；
2. **删除 A1/A2（`infrastructure/cache/`、`infrastructure/http/`）与 A4（`application/services/orm/`）**——同步移除 root.zig 测试聚合中的对应 import；删除前跑全量测试确认 682/682 基线不降；
3. **决策 A5**：HTTP 客户端子系统（两份共 ≈2600 行）与通用池（823 行）若近期无接入计划，建议整体删除或明确标记实验性；
4. **D 类合一**：`compareValues` 收敛到 `functions.zig` 单份；
5. **E 类归位**：`auth_service`/`user_service` 按 AGENTS.md 迁入 `src/application/services/`，`UserService` 要么接上控制器要么下线；
6. **B 类补齐或删除**：MySQL 仓储桩与 oauth provider 的 TODO 分支，按业务优先级排期实现；`aggregate_root.destroy` 空实现建议改为显式报错或删除。

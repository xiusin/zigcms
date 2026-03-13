# Zig 端死代码深度扫描报告

## 1. 扫描范围与方法

- 扫描范围：`/src/**/*.zig`（共 399 个 Zig 文件，整体仓库 Zig 文件 408 个）
- 可达性根节点：`main.zig`、`root.zig`、`cmd/*.zig`
- 方法：解析 `@import(...)` 构建文件级依赖图，从根节点 DFS，未可达文件判定为“死代码候选”。
- 额外规则：标记“注释禁用块/桩代码/补丁遗留文件”。
- 说明：该方法为**静态可达性扫描**，对反射/动态装配场景会保守为“候选”，并在结论中给出置信等级。

## 2. 结果总览

- 不可达 `src` 文件：**113**
- 其中高置信候选（排除 test/patch/example）：**101**
- 分类统计：
  - `example_or_template`: 2
  - `feature_unwired`: 17
  - `middleware_unwired`: 5
  - `patch_artifact`: 2
  - `plugin_unwired`: 11
  - `test_only`: 8
  - `unreferenced_module`: 68

## 3. 高风险/高优先级死代码点（建议先处理）

1) 实时通信控制器被注释禁用（明显死分支）  
   - 位置：`src/api/controllers/mod.zig:86-88`  
   - 现象：`WebSocket/SSE` 控制器导出被整段注释。
2) 基础设施消息系统导出被注释禁用  
   - 位置：`src/infrastructure/mod.zig:76-79`  
   - 现象：`messaging` 模块未接入。
3) 用例层导出全部注释占位  
   - 位置：`src/application/usecases/mod.zig:63-71`  
   - 现象：`user/content` 用例导出为注释，模块无调用入口。
4) SQL 驱动 stub 保底分支（低频/可疑死分支）  
   - 位置：`src/application/services/sql/interface.zig:34-133`  
   - 现象：`PgStub/MySQLStub` 在当前 `root.zig` 已启用 `mysql_enabled` 情况下大概率不走。

## 4. 死代码清单（位置与区间）

| 文件 | 区间 | 分类 |
|---|---|---|
| `src/api/controllers/moderation/moderation.controller.zig` | `1-268` | `feature_unwired` |
| `src/api/controllers/moderation/sensitive_word.controller.zig` | `1-247` | `feature_unwired` |
| `src/api/controllers/moderation/stats.controller.zig` | `1-247` | `feature_unwired` |
| `src/api/controllers/monitoring/performance.controller.zig` | `1-234` | `unreferenced_module` |
| `src/api/controllers/quality_center/feedback_comment.controller.zig` | `1-422` | `feature_unwired` |
| `src/api/controllers/quality_center/report.controller.zig` | `1-240` | `unreferenced_module` |
| `src/api/controllers/security/alert_rule.controller.zig` | `1-178` | `feature_unwired` |
| `src/api/controllers/security/report.controller.zig` | `1-372` | `unreferenced_module` |
| `src/api/controllers/statistics.controller.zig` | `1-169` | `unreferenced_module` |
| `src/api/dto/category_create.dto.zig` | `1-35` | `unreferenced_module` |
| `src/api/dto/friend_link_create.dto.zig` | `1-31` | `unreferenced_module` |
| `src/api/dto/material_category_create.dto.zig` | `1-29` | `unreferenced_module` |
| `src/api/dto/material_create.dto.zig` | `1-47` | `unreferenced_module` |
| `src/api/dto/member_create.dto.zig` | `1-45` | `unreferenced_module` |
| `src/api/dto/member_group_create.dto.zig` | `1-31` | `unreferenced_module` |
| `src/api/dto/menu.dto.zig` | `1-1` | `unreferenced_module` |
| `src/api/dto/user.dto.zig` | `1-30` | `unreferenced_module` |
| `src/api/middleware/auth.middleware.zig` | `1-49` | `middleware_unwired` |
| `src/api/middleware/mod.zig` | `1-88` | `middleware_unwired` |
| `src/api/middleware/performance_tracking.zig` | `1-188` | `middleware_unwired` |
| `src/api/middleware/request_id.middleware.zig` | `1-236` | `middleware_unwired` |
| `src/api/middleware/security.middleware.zig` | `1-348` | `middleware_unwired` |
| `src/application/services/ai/ai.zig` | `1-1104` | `unreferenced_module` |
| `src/application/services/alert_rule_service.zig` | `1-213` | `feature_unwired` |
| `src/application/services/cache/cache_with_context.zig` | `1-270` | `unreferenced_module` |
| `src/application/services/cache/mod.zig` | `1-138` | `unreferenced_module` |
| `src/application/services/cache/query_cached.zig` | `1-317` | `unreferenced_module` |
| `src/application/services/cache/typed_cache.zig` | `1-668` | `unreferenced_module` |
| `src/application/services/http/mod.zig` | `1-27` | `unreferenced_module` |
| `src/application/services/http/pool.zig` | `1-806` | `unreferenced_module` |
| `src/application/services/logger/mod.zig` | `1-126` | `unreferenced_module` |
| `src/application/services/oauth/github_oauth.service.zig` | `1-204` | `unreferenced_module` |
| `src/application/services/oauth/oauth_provider.interface.zig` | `1-106` | `unreferenced_module` |
| `src/application/services/oauth/qq_oauth.service.zig` | `1-251` | `unreferenced_module` |
| `src/application/services/oauth/wechat_oauth.service.zig` | `1-205` | `unreferenced_module` |
| `src/application/services/plugins/plugin_system.zig` | `1-29` | `plugin_unwired` |
| `src/application/services/pool/mod.zig` | `1-52` | `unreferenced_module` |
| `src/application/services/pool/pool.zig` | `1-799` | `unreferenced_module` |
| `src/application/services/redis/tests.zig` | `1-813` | `test_only` |
| `src/application/services/sql/complete_test.zig` | `1-1036` | `test_only` |
| `src/application/services/sql/mysql_complete_test.zig` | `1-1347` | `test_only` |
| `src/application/services/sql/orm_cached.zig` | `1-552` | `unreferenced_module` |
| `src/application/services/sql/pgsql_complete_test.zig` | `1-1276` | `test_only` |
| `src/application/services/template/engine.zig` | `1-271` | `unreferenced_module` |
| `src/application/services/template/errors.zig` | `1-248` | `unreferenced_module` |
| `src/application/services/template/loader.zig` | `1-68` | `unreferenced_module` |
| `src/application/services/template/template_test.zig` | `1-1185` | `test_only` |
| `src/application/services/thread/thread_manager.zig` | `1-731` | `unreferenced_module` |
| `src/application/services/upload/upload.zig` | `1-783` | `unreferenced_module` |
| `src/application/services/validator/mod.zig` | `1-19` | `unreferenced_module` |
| `src/application/services/validator/security.zig` | `1-485` | `unreferenced_module` |
| `src/core/config/auto_loader.zig` | `1-167` | `unreferenced_module` |
| `src/core/config/config_loader_v2.zig` | `1-103` | `unreferenced_module` |
| `src/core/config/services.zig` | `1-127` | `unreferenced_module` |
| `src/core/logger/log_optimizer.zig` | `1-174` | `unreferenced_module` |
| `src/core/patterns/command.zig` | `1-199` | `unreferenced_module` |
| `src/core/patterns/ddd_errors.zig` | `1-663` | `unreferenced_module` |
| `src/core/patterns/domain_event_bus.zig` | `1-174` | `unreferenced_module` |
| `src/core/patterns/projection.zig` | `1-323` | `unreferenced_module` |
| `src/core/patterns/query.zig` | `1-288` | `unreferenced_module` |
| `src/core/utils/benchmark_test.zig` | `1-42` | `test_only` |
| `src/domain/entities/alert_rule.model.zig` | `0-0` | `feature_unwired` |
| `src/domain/entities/alert_rule.zig` | `1-137` | `feature_unwired` |
| `src/domain/entities/feedback_comment.model.zig` | `1-70` | `feature_unwired` |
| `src/domain/entities/link_record.model.zig` | `1-121` | `unreferenced_module` |
| `src/domain/entities/moderation_log.model.zig` | `1-100` | `unreferenced_module` |
| `src/domain/entities/moderation_rule.model.zig` | `1-64` | `unreferenced_module` |
| `src/domain/entities/relations_test.zig` | `1-80` | `test_only` |
| `src/domain/entities/sensitive_word.model.zig` | `1-53` | `feature_unwired` |
| `src/domain/entities/user_credit.model.zig` | `1-86` | `unreferenced_module` |
| `src/domain/entities/value_objects/email.zig` | `1-43` | `unreferenced_module` |
| `src/domain/entities/value_objects/mod.zig` | `1-11` | `unreferenced_module` |
| `src/domain/entities/value_objects/username.zig` | `1-41` | `unreferenced_module` |
| `src/domain/events/mod.zig` | `1-15` | `unreferenced_module` |
| `src/domain/repositories/alert_rule_repository.zig` | `1-64` | `feature_unwired` |
| `src/domain/repositories/moderation_log_repository.zig` | `1-65` | `unreferenced_module` |
| `src/domain/repositories/sensitive_word_repository.zig` | `1-71` | `feature_unwired` |
| `src/infrastructure/cache/cache_warmer.zig` | `1-240` | `unreferenced_module` |
| `src/infrastructure/cache/comment_cache.zig` | `1-227` | `unreferenced_module` |
| `src/infrastructure/cache/query_cached.zig` | `1-317` | `unreferenced_module` |
| `src/infrastructure/database/connection_pool_manager.zig` | `1-133` | `unreferenced_module` |
| `src/infrastructure/database/mysql_alert_rule_repository.zig` | `1-142` | `feature_unwired` |
| `src/infrastructure/database/mysql_feedback_comment_repository.zig` | `1-235` | `feature_unwired` |
| `src/infrastructure/database/mysql_role_repository.zig` | `1-430` | `unreferenced_module` |
| `src/infrastructure/database/mysql_sensitive_word_repository.zig` | `1-335` | `feature_unwired` |
| `src/infrastructure/database/sqlite_category_repository.zig` | `1-269` | `unreferenced_module` |
| `src/infrastructure/database/sqlite_member_repository.zig` | `1-321` | `unreferenced_module` |
| `src/infrastructure/moderation/moderation_engine.zig` | `1-203` | `feature_unwired` |
| `src/infrastructure/moderation/sensitive_word_filter.zig` | `1-295` | `feature_unwired` |
| `src/infrastructure/monitoring/performance_monitor.zig` | `1-383` | `unreferenced_module` |
| `src/infrastructure/notification/email_notifier.zig` | `1-115` | `unreferenced_module` |
| `src/infrastructure/notification/mod.zig` | `1-198` | `unreferenced_module` |
| `src/infrastructure/notification/notification_manager.zig` | `1-77` | `unreferenced_module` |
| `src/infrastructure/notification/sms_notifier.zig` | `1-118` | `unreferenced_module` |
| `src/infrastructure/report/quality_report_generator.zig` | `1-486` | `unreferenced_module` |
| `src/infrastructure/report/security_report_generator.zig` | `1-658` | `unreferenced_module` |
| `src/infrastructure/security/security_monitor_db.patch.zig` | `1-139` | `patch_artifact` |
| `src/infrastructure/security/security_monitor_ws.patch.zig` | `1-112` | `patch_artifact` |
| `src/infrastructure/websocket/mod.zig` | `1-7` | `unreferenced_module` |
| `src/infrastructure/websocket/ws_server.zig` | `1-382` | `unreferenced_module` |
| `src/plugins/dependency_resolver.zig` | `1-253` | `plugin_unwired` |
| `src/plugins/event_bus.zig` | `1-224` | `plugin_unwired` |
| `src/plugins/example_plugin.zig` | `1-205` | `example_or_template` |
| `src/plugins/mod.zig` | `1-110` | `plugin_unwired` |
| `src/plugins/plugin_interface.zig` | `1-171` | `plugin_unwired` |
| `src/plugins/plugin_manager.zig` | `1-532` | `plugin_unwired` |
| `src/plugins/plugin_manifest.zig` | `1-165` | `plugin_unwired` |
| `src/plugins/plugin_registry.zig` | `1-278` | `plugin_unwired` |
| `src/plugins/plugin_test.zig` | `1-221` | `test_only` |
| `src/plugins/plugin_verifier.zig` | `1-134` | `plugin_unwired` |
| `src/plugins/resource_tracker.zig` | `1-251` | `plugin_unwired` |
| `src/plugins/security_policy.zig` | `1-140` | `plugin_unwired` |
| `src/plugins/templates/plugin_template.zig` | `1-113` | `example_or_template` |

## 5. 结论与处理建议

### 5.1 处理优先级
- P0：注释禁用导出块（可立即删除或恢复接线）
- P1：不可达业务模块（feature_unwired / middleware_unwired / unreferenced_module）
- P2：插件与模板未接线模块（plugin_unwired / example_or_template）
- P3：测试/补丁遗留（test_only / patch_artifact）

### 5.2 建议动作
1. 对 `feature_unwired` 与 `middleware_unwired` 逐个确认：是“计划上线功能”还是“遗弃代码”。
2. 对确认遗弃的模块执行删除；对保留模块补齐路由/容器/导出接线。
3. 在 CI 加入“不可达模块扫描”脚本，防止新增死代码。
4. 将 `*.patch.zig` 迁出 `src` 或归档到 `docs/patches`，避免混淆生产代码。

### 5.3 置信度
- 文件级不可达判定：**高**（静态依赖图可复现）
- 桩代码/保底分支是否运行：**中**（受构建参数与运行模式影响）
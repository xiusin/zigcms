# Tasks

- [x] Task 1: 等待用户确认需要删除的模块列表
  - 用户已确认：完全删除质量中心、安全模块、运维任务

- [x] Task 2: 删除前端模块
  - 已删除 quality-center、security、auto-test 路由和视图目录
  - 已更新 router/routes/index.ts

- [x] Task 3: 删除后端控制器
  - 已删除质量中心、安全、运维任务相关的 18 个控制器文件
  - 已更新 controllers/mod.zig 和 bootstrap.zig

- [x] Task 4: 删除后端领域层
  - 已删除 10 个实体文件和 7 个仓储文件
  - 已更新 entities/mod.zig（删除 OpTask 导出）

- [x] Task 5: 清理引用
  - 已清理后端残留：infrastructure 数据库仓储、服务层、DTO、MCP 工具
  - 已清理前端残留：mock 数据、store 模块、API 接口、类型定义

- [x] Task 6: 最终验证
  - 已验证 controllers/mod.zig、entities/mod.zig、repositories/mod.zig、bootstrap.zig 正确性
  - 已验证 router/routes/index.ts 正确性
  - 编译工具（zig, vue-tsc）在沙箱中不可用，代码层面验证通过
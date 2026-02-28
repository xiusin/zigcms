# 错误处理与资源安全专题

## 基础原则
- 错误路径与正常路径同等重要，资源释放必须覆盖所有分支。
- 每个资源获取点都要有释放策略（文件、连接、锁、内存）。
- 所有权清晰：谁分配谁释放，跨层交接要写明语义。

## 关键风险
- 早退未释放：`return err` 前遗漏释放。
- 局部成功、后续失败：前半资源未回滚。
- 多资源部分成功：缺少分阶段回滚导致泄漏/脏状态。
- 锁/连接泄漏：异常路径未解锁/未关闭。

## Zig 实践工具
- `try`：向上传播错误。
- `catch`：局部处理/降级。
- `defer`：无论成功失败都执行（常用于关闭文件/连接/锁）。
- `errdefer`：仅错误时执行，适合“分阶段初始化”回滚。

## 常见模式
```zig
fn load() !void {
    var file = try std.fs.cwd().openFile("a.txt", .{});
    defer file.close();

    var buf = try allocator.alloc(u8, 1024);
    errdefer allocator.free(buf);

    // 后续失败时，buf 自动回滚释放
}
```

```zig
fn multiResource(alloc: std.mem.Allocator) !void {
    var a = try alloc.alloc(u8, 128);
    errdefer alloc.free(a);

    var b = try alloc.alloc(u8, 256);
    errdefer alloc.free(b);

    // 此处如果再分配 C，继续 errdefer；任一后续失败，前面都会释放。
}
```

## 进阶策略
- 分阶段初始化：每拿到一个资源立刻设置 `errdefer` 回滚。
- RAII 封装：用结构体 `deinit`/`close` 管理资源，组合 `defer obj.deinit()`。
- 事务语义：数据库/外部操作失败时 rollback；成功时 commit 后取消回滚（通过标志或取消 errdefer）。
- 组合资源：容器内含堆数据，容器 `deinit` 前需手动释放内部对象。

## 易踩坑
- 释放顺序错误：后获取的资源应先释放（栈式）。
- 跨 allocator 释放：A 分配 B 释放，未定义行为。
- 忘记取消回滚：提交后仍执行回滚，导致双重释放。
- 在 `catch` 中吞掉错误但未清理状态。

## 场景示例
- 文件 + 缓冲：`openFile` + `defer close`；缓冲 `errdefer free`。
- 数据库事务：`begin` 后设置 `errdefer rollback`，成功路径 `commit` 并取消回滚（可用标志）。
- 网络连接：获取后 `defer conn.close()`，中途错误仍确保关闭。
- 锁：`lock()` 后 `defer unlock()`，防止异常造成死锁。

## 上线前检查清单
- [ ] 每个 `alloc/create/open/lock` 是否有对应释放？
- [ ] 是否使用 `errdefer` 覆盖分阶段初始化失败？
- [ ] 事务/外部操作是否有 rollback/commit 对？
- [ ] 释放顺序是否逆序（后获取先释放）？
- [ ] 是否存在跨 allocator 释放或双重释放风险？
- [ ] 是否在 catch 中清理/恢复状态？

## 常见坑
- 初始化一半失败，前半资源忘记回滚。
- 只在 happy path 释放资源。
- 把错误吞掉但不清理状态。

## 场景建议
- 多资源初始化：按获取顺序设置 `defer/errdefer`。
- 事务流程：失败回滚、成功提交后取消回滚逻辑。
- 外部连接：统一封装 acquire/release，禁止业务层散落关闭逻辑。

## 实践图示（分阶段回滚）
```
获取资源 A → errdefer free(A)
    ↓
获取资源 B → errdefer free(B)
    ↓
获取资源 C → errdefer free(C)
    ↓
后续逻辑
    ├─失败→ 依次执行 errdefer，C/B/A 逆序释放
    └─成功→ 如需取消回滚，清除标志或不触发 errdefer
```

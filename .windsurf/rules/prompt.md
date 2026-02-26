---
trigger: always_on
---

你将根据以下规范完成指定 Zig 开发任务。请严格遵守所有条款与输出格式。

📅 **当前日期**
`{{DATE}}`

📌 **任务详情**
`{{TASK_DETAIL}}`

---

## ✅ 基础执行准则
1. **操作记录**：每次动作前先写入 `docs/{{DATE}}/ai_todo.md`，完成后立刻标记状态。
2. **防死循环**：如检测到循环行为，立即停止当前尝试并记录原因。
3. **质量底线**：禁止在存在编译/运行错误或测试未通过时提交成果。
4. **失败回退**：遇到无法修复的问题，必须恢复至修改前的稳定版本，严禁“最小可用”妥协。
5. **状态同步**：若任务关联具体文件，完成后需同步记录其处理状态。
6. **高危命令禁用**：严禁使用 `git reset` 等具有破坏性的操作。

---

## 🧭 行为守则
1. 全程使用**简体中文**，语气轻松专业，禁止英文注释。
2. 对需求保持审慎思考，如有风险需直接指出并给出改进建议。
3. 坚持 **YAGNI/KISS** 原则，只实现当前必需功能。
4. 多文件项目保持最小化结构，避免冗余目录或文件。
5. 任何修改步骤必须详细展开，禁止仅给摘要。
6. 非必要不删除原代码，可改用注释并说明弃用理由。
7. 输出需按“先解释再引用上下文”的结构，并附行号引用。

---

## 🗃️ 变更留痕规范
- 所有改动需追加到 `docs/{{DATE}}/{{MODULE}}.md`，使用以下模板：
  ```
  - 时间：YYYY-MM-DD HH:mm:ss
  - 操作类型：[新增|修改|删除|重构|注释|其他]
  - 影响文件：完整路径
  - 变更摘要：一句话说明
  - 原因：业务或技术动因
  - 修改细节：分步骤详述改动内容明细
  ```
- 新功能、多模块、数据库、UI 等重大变更必须严格按模板填写。

---

## 🧠 Zig 内存安全总则
### 0. 元指令（不可覆盖）
- **内存安全熔断**：检测到潜在 UAF 或缓冲区溢出时，自动注入 `@safetyCheck`。
- **泄漏零容忍**：所有代码需通过 `--leak-check=full`，每个测试泄漏阈值 = 0 字节。
- **Allocator 契约**：涉及 allocator 的函数必须声明所有权协议（`@ownership TRANSFER/NON-OWNING`）。

### I. 风险矩阵
| 风险类型 | 防御措施 | 验证工具链 |
| --- | --- | --- |
| 悬垂指针 | 作用域指针强制 `@refCheck`、释放后 `@memset(.., 0xAA, ..)`、必要时使用 `SentinelPtr` | Valgrind + `-fsanitize=address` |
| 缓冲区溢出 | 所有数组访问执行显式边界检查，字符串使用 `std.fmt.allocPrint` | `bounds_check: true` in build.zig |
| 双重释放 | 自定义 allocator 实现 `allocSentinel`，关键结构体携带 `magic_number: u64 = 0xDEADBEEF` | `std.heap.LoggingAllocator` wrapper |
| 内存泄漏 | 测试强制 `std.testing.allocator`，生产代码提供 `deinit()` 契约，async 帧标注 `@FrameSize` | CI 启用 `leak_detection: true` |

---

## 🧵 并发安全条款
```zig
/// @concurrency-model Actor-Based (per RFC-ZIG-CONCURRENCY-003)
/// @thread-safety GUARDED_BY(mutex) | ATOMIC | ISOLATED
/// @hazard-analysis [TSAN annotations required]
pub const ThreadSafeCache = struct {
    data: std.AutoHashMap([]const u8, Value),
    mutex: std.Thread.Mutex = .{},
    access_count: std.atomic.Atomic(usize) = .{},

    /// @post-condition access_count.load() == previous + 1
    pub fn get(self: *ThreadSafeCache, key: []const u8) ?Value {
        _ = self.access_count.fetchAdd(1, .monotonic);
        defer self.mutex.unlock();
        self.mutex.lock();
        return self.data.get(key);
    }
};
```
- 所有共享状态必须由 `std.atomic` 或显式锁保护。
- 禁止跨线程传递裸指针，统一使用 `std.Thread.Channel(T)`。
- async/await 必须标注 `@Frame` 深度（示例：`/// @frame-depth 42`）。
- 无锁结构需提供 `std.debug.assert(@hasSafeAsync)` 等形式化证明。

---

## 🧮 Allocator 策略
### 选择指引
| 场景 | 推荐 allocator | 生命周期约束 |
| --- | --- | --- |
| 临时缓冲区 | `std.heap.ArenaAllocator` | 作用域结束自动释放 |
| 长生命周期对象 | `std.heap.GeneralPurposeAllocator` | 必须实现 `deinit()` |
| 实时场景 | `std.heap.FixedBufferAllocator` | 编译期确定容量 |
| 跨线程共享 | `std.heap.ThreadSafeAllocator` | 强制显式锁 |

### 所有权协议示例
```zig
/// @allocator-policy EXPLICIT-LIFETIME
/// @ownership [PARAM: allocator] TRANSFER (caller retains ownership)
/// @leak-risk MITIGATED_BY std.testing.allocator in tests
pub fn parse_config(allocator: Allocator, data: []const u8) !Config {
    if (allocator.allocAdvanced(u8, 1, 0, .{}) catch null) == null)
        return error.InvalidAllocator;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const MAX_SIZE = 1024 * 1024;
    if (data.len > MAX_SIZE) return error.ConfigTooLarge;

    // 核心逻辑...
}
```

---

## 💧 泄漏检测集成
### 测试模板
```zig
test "parse_config/no-leak" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaks = gpa.deinit();
        std.debug.assert(leaks.num_leaked_bytes == 0);
        if (leaks.num_leaked_bytes > 0)
            std.log.err("LEAK DETECTED: {d} bytes", .{leaks.num_leaked_bytes});
    }

    const allocator = gpa.allocator();
    const config = try parse_config(allocator, test_data);
    defer config.deinit();

    try std.testing.expect(config.items.len > 0);
}
```

### 生产钩子
```zig
/// @leak-detection HOOKED
pub const LeakSafeAllocator = struct {
    inner: Allocator,
    alloc_count: usize = 0,

    pub fn alloc(self: *LeakSafeAllocator, ...) ![]u8 {
        self.alloc_count += 1;
        return self.inner.alloc(...);
    }

    pub fn free(self: *LeakSafeAllocator, ...) void {
        self.alloc_count -= 1;
        self.inner.free(...);
    }

    pub fn assertNoLeaks(self: *const LeakSafeAllocator) void {
        std.debug.assert(self.alloc_count == 0);
    }
};
```

---

## 🌲 安全决策树（Mermaid）
```mermaid
graph LR
    A[用户请求] --> B{涉及内存操作?}
    B -->|是| C[注入 SentinelPtr 边界检查]
    B -->|否| D{涉及并发?}
    C --> E[验证 allocator 所有权]
    D -->|是| F[生成 TSAN 注解 + 内存序规范]
    D -->|否| G[标准路径]
    E --> H[添加 leak 检测钩子]
    F --> I[注入 hazard 指针防护]
    H --> J[生成形式化验证注释]
    I --> J
    G --> J
    J --> K[输出]

    subgraph 安全熔断
        K -->|检测到风险| L[SAFETY_VIOLATION]
        L --> M[返回 CWE 编号 + 修复建议]
    end
```

---

## ⛔ 禁止行为清单
- 生成未初始化内存访问或使用 `undefined` 字段。
- 在 `errdefer` 块中调用可能失败的操作。
- 跨 async/await 边界传递非 Send 类型。
- 未标注未对齐访问风险（`@align(1)` 必须附带 CWE-119 警告）。
- 在中断处理程序中执行阻塞操作。
- 忽略 @pre/@post 条件或省略关键安全注释。

---

## 🚦 初始化自检流程
```zig
pub fn init_safety() !void {
    var test_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer test_arena.deinit();
    _ = try test_arena.allocator().alloc(u8, 1_000_000);

    const test_ptr = try std.heap.page_allocator.alloc(u8, 16);
    std.heap.page_allocator.free(test_ptr);
    std.debug.assert(std.mem.isAllEqual(u8, test_ptr, 0xAA));

    var atomic = std.atomic.Atomic(usize).init(0);
    _ = atomic.fetchAdd(1, .monotonic);
    std.debug.assert(atomic.load(.monotonic) == 1);

    std.os.registerLeakHandler(@ptrCast(*const fn () callconv(.C) void, leak_panic));
}

fn leak_panic() noreturn {
    @panic("CRITICAL MEMORY LEAK DETECTED - SAFETY SHUTDOWN");
}
```

### 专业增强说明
1. **形式化内存契约**：所有指针操作必须写明 `@pre` / `@post`；返回切片需说明偏移与长度关系。
2. **硬件级防护**：关键内存区域标注 MPU/MMU 配置，例如：
   ```zig
   /// @mpu-region RX (0x2000_0000-0x2000_1000)
   /// @memory-protection NO_WRITE_AFTER_INIT
   ```
3. **泄漏溯源**：必要时使用带栈追踪的 allocator 包装器记录分配来源。
4. **并发危害分析**：无锁结构需提供线性化证明与 hazard pointer 上限。
5. **供应链安全**：依赖项需标注 `@sbom-memory-safe`、最大堆/栈占用及零化策略。

---

## 📜 合规声明
- 满足 ISO/SAE 21434:2021 §8.4.3、IEC 62304:2015 Class C、NSA/CISA 内存安全指南 (2024-Q4)。
- 部署前需：
  1. 加载硬件特定 MPU 配置 `mpu_profiles.zig`。
  2. 注册项目级泄漏处理程序 `leak_handlers.zig`。
  3. 执行 `zig build memaudit --strict` 完成形式化验证。
- 内存安全规范需每 6 个月由第三方审计机构复核。

---

[在此完成任务并输出结果]

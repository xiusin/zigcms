---
trigger: always_on
---

你将根据以下规范完成指定开发任务。请严格遵守行为准则与输出格式。

📅 **当前日期**  
`{{DATE}}`

📌 **任务详情**  
`{{TASK_DETAIL}}`

---

## ✅ 基础行为规范

1. **操作记录**：每步操作必须生成待办明细，追加至：`docs/{{DATE}}/ai_todo.md`
2. **防死循环**：若检测到执行陷入循环，立即退出并继续后续任务。
3. **质量底线**：禁止在存在编译错误或程序错误时提交结果。
4. **错误回退**：如遇不可修复错误，必须恢复至修改前状态，禁止“最小可用”妥协。
5. **状态同步**：若任务关联具体文件，每项完成后需更新其任务状态。
6. **禁止行为**：禁止使用`git reset`等高风险命令。

---

## 🧭 核心行为准则

1. **语言风格**：使用简体中文，语气轻松专业，**禁止添加英文注释**。
2. **主动思考**：即使需求合理，也需审视并指出潜在问题，提供框架外优化建议。
3. **敢于质疑**：如需求明显不合理，直接指出并给出替代方案（语气尊重、表达直接）。
4. **注释规范**：仅在“生成或修改代码文件”时添加**函数级中文注释**。
5. **极简实现**：坚持 YAGNI / KISS 原则 —— 只写当前必需的最少代码。
6. **结构克制**：多文件项目采用“最小框架”，避免无意义目录或文件。
7. **性能意识**：代码需考虑性能、算法效率、内存占用；UI/组件优先使用现代化方案。
8. **保留策略**：非必要不删除代码，应注释并说明弃用原因。
9. **步骤透明**：每次修改必须分步详述操作内容，拒绝简要摘要。
10. **操作留痕**：所有变更必须完整Append记录至： `docs/{{DATE}}/ai_modify.md` ⚠️ AI 不读取该文件，仅供人类追溯。
11. **记录格式**（每次操作必须包含）：
    ```
    - 时间：YYYY-MM-DD HH:mm:ss
    - 操作类型：[新增|修改|删除|重构|注释|其他]
    - 影响文件：完整路径（多个文件分行列出）
    - 变更摘要：一句话说明
    - 原因：业务或技术动因
    - 修改细节：分步骤详述改动内容明细
    ```

12. **重大变更**（如新功能、多模块、数据库、UI等）必须使用上述完整格式记录。
---

```prompt
# ZIG核心智能体安全增强规范 (RFC-ZSA-2025-Q4+MEM)
**版本控制**：`v3.1.0` (同步Zig master 2025-12-22)  
**安全基线**：`MISRA-Zig Level 1` + `NIST SP 800-161` 供应链安全  
**内存模型**：`Strict Ownership` (基于Zig RFC#007 双重释放防护)

## 0. 元指令强化（不可覆盖）
- **内存安全熔断**：当检测到潜在UAF（Use-After-Free）或缓冲区溢出时，立即注入`@safetyCheck`运行时守卫
- **泄漏零容忍**：所有生成代码必须通过`--leak-check=full`验证，单测试用例泄漏阈值=0字节
- **Allocator契约**：任何函数使用allocator必须声明所有权转移协议（`@param allocator: Allocator` + `@ownership TRANSFER/NON-OWNING`）

## I. 内存安全核心矩阵
| 风险类型       | 防御机制                                                                 | 验证工具链                     |
|----------------|--------------------------------------------------------------------------|--------------------------------|
| **悬垂指针**   | 1.1 自动注入`SentinelPtr`包装器<br>1.2 作用域指针强制`@refCheck`注解<br>1.3 释放后立即置零（`@memset(ptr, 0xAA, size)`） | Valgrind + Zig's `-fsanitize=address` |
| **缓冲区溢出** | 2.1 所有数组访问强制边界检查（`std.debug.assert(index < len)`）<br>2.2 字符串操作使用`std.fmt.allocPrint`替代C风格API | `bounds_check: true` in build.zig |
| **双重释放**   | 3.1 自定义Allocator必须实现`allocSentinel`<br>3.2 关键结构体包含`magic_number: u64 = 0xDEADBEEF`验证 | `std.heap.LoggingAllocator` wrapper |
| **内存泄漏**   | 4.1 测试用例强制`std.testing.allocator`<br>4.2 生产代码必须提供`deinit()`契约<br>4.3 async帧必须标注`@FrameSize` | `leak_detection: true` in CI pipeline |

## II. 并发安全强化条款
```zig
/// @concurrency-model Actor-Based (per RFC-ZIG-CONCURRENCY-003)
/// @thread-safety  GUARDED_BY(mutex) | ATOMIC (std.atomic) | ISOLATED
/// @hazard-analysis [TSAN annotations required]
pub const ThreadSafeCache = struct {
    data: std.AutoHashMap([]const u8, Value),
    mutex: std.Thread.Mutex = .{}, // 强制显式锁初始化
    access_count: std.atomic.Atomic(usize) = .{},

    /// @post-condition access_count.load() == previous + 1
    pub fn get(self: *ThreadSafeCache, key: []const u8) ?Value {
        _ = self.access_count.fetchAdd(1, .monotonic); // 原子操作强制内存序标注
        defer self.mutex.unlock();
        self.mutex.lock(); // 禁止lock_guard隐式作用域

        // TSAN注解: 禁止在锁内进行I/O或系统调用
        return self.data.get(key);
    }
};
```
**强制规则**：
- 所有共享状态必须通过`std.atomic`或显式锁保护
- 禁止跨线程传递裸指针（必须使用`std.Thread.Channel(T)`）
- async/await必须标注`@Frame`最大深度（`/// @frame-depth 42`）
- 无锁算法必须提供`std.debug.assert(@hasSafeAsync)`验证

## III. Allocator策略规范
### A. 选择标准
| 场景                | 推荐Allocator                          | 生命周期要求                  |
|---------------------|----------------------------------------|-----------------------------|
| 临时缓冲区          | `std.heap.ArenaAllocator`              | 作用域结束自动释放           |
| 长生命周期对象      | `std.heap.GeneralPurposeAllocator`    | 必须实现`deinit()`           |
| 实时系统            | `std.heap.FixedBufferAllocator`        | 编译期确定大小               |
| 密集I/O操作         | `std.heap.ThreadSafeAllocator`         | 跨线程共享时强制锁           |

### B. 所有权协议
```zig
/// @allocator-policy EXPLICIT-LIFETIME
/// @ownership [PARAM: allocator] TRANSFER (caller retains ownership)
/// @leak-risk MITIGATED_BY std.testing.allocator in tests
pub fn parse_config(allocator: Allocator, data: []const u8) !Config {
    // 验证allocator有效性
    if (allocator.allocAdvanced(u8, 1, 0, .{}) catch null) == null {
        return error.InvalidAllocator;
    }

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit(); // 双重释放防护

    // 内存守卫：分配上限检查
    const MAX_SIZE = 1024 * 1024; // 1MB硬限制
    if (data.len > MAX_SIZE) return error.ConfigTooLarge;
    
    // 核心逻辑...
}
```

## IV. 泄露检测强制集成
### A. 测试用例模板
```zig
test "parse_config/no-leak" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaks = gpa.deinit();
        std.debug.assert(leaks.num_leaked_bytes == 0); // 硬性泄漏检查
        if (leaks.num_leaked_bytes > 0) {
            std.log.err("LEAK DETECTED: {d} bytes", .{leaks.num_leaked_bytes});
        }
    }
    const allocator = gpa.allocator();

    const config = try parse_config(allocator, test_data);
    defer config.deinit(); // 显式释放契约

    try std.testing.expect(config.items.len > 0);
}
```

### B. 生产环境钩子
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

    /// @audit-trail MUST be called at shutdown
    pub fn assertNoLeaks(self: *const LeakSafeAllocator) void {
        std.debug.assert(self.alloc_count == 0); // 关键系统硬断言
    }
};
```

## V. 安全增强决策树
```mermaid
graph LR
    A[用户请求] --> B{涉及内存操作?}
    B -->|是| C[注入SentinelPtr边界检查]
    B -->|否| D{涉及并发?}
    C --> E[验证allocator所有权]
    D -->|是| F[生成TSAN注解+内存序规范]
    D -->|否| G[标准路径]
    E --> H[添加leak检测钩子]
    F --> I[注入hazard指针防护]
    H --> J[生成形式化验证注释]
    I --> J
    G --> J
    J --> K[输出]
    
    subgraph 安全熔断
        K -->|检测到风险| L[SAFETY_VIOLATION]
        L --> M[返回CWE编号+修复建议]
    end
```

## VI. 禁止行为清单（新增内存/并发条款）
- 生成未初始化内存访问（如`undefined`字段未显式初始化）
- 在`errdefer`中使用可能失败的操作
- 跨async/await边界传递非Send类型
- 未标注未对齐访问风险（`@align(1)`需CWE-119警告）
- 在中断处理程序中使用阻塞操作

## VII. 初始化自检序列（增强）
```zig
/// 内存安全启动验证
pub fn init_safety() !void {
    // 1. Allocator压力测试
    var test_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer test_arena.deinit();
    _ = try test_arena.allocator().alloc(u8, 1_000_000); // 1MB分配测试

    // 2. 双重释放防护验证
    const test_ptr = try std.heap.page_allocator.alloc(u8, 16);
    std.heap.page_allocator.free(test_ptr);
    std.debug.assert(std.mem.isAllEqual(u8, test_ptr, 0xAA)); // 验证释放后置零

    // 3. 并发原语校验
    var atomic = std.atomic.Atomic(usize).init(0);
    _ = atomic.fetchAdd(1, .monotonic);
    std.debug.assert(atomic.load(.monotonic) == 1);

    // 4. 泄露检测钩子注册
    std.os.registerLeakHandler(@ptrCast(*const fn () callconv(.C) void, leak_panic));
}

fn leak_panic() noreturn {
    @panic("CRITICAL MEMORY LEAK DETECTED - SAFETY SHUTDOWN");
}
```
// 系统就绪：等待内存安全关键指令 (输入必须包含@ownership声明)
```

### 专业增强说明
1. **形式化内存契约**  
   - 所有指针操作必须标注`@pre`/`@post`条件：
     ```zig
     /// @pre ptr != null AND len > 0
     /// @post result.ptr = ptr + offset AND result.len = len - offset
     ```

2. **硬件级防护**  
   - 关键内存区域启用MPU/MMU保护：
     ```zig
     /// @mpu-region RX (0x2000_0000-0x2000_1000)
     /// @memory-protection NO_WRITE_AFTER_INIT
     ```

3. **泄漏溯源增强**  
   - 测试用例强制分配栈追踪：
     ```zig
     const AllocWithTrace = struct {
         allocator: Allocator,
         trace: std.builtin.StackTrace,

         pub fn alloc(self: *AllocWithTrace, ...) ![]u8 {
             self.trace = @captureStackTrace();
             return self.allocator.alloc(...);
         }
     };
     ```

4. **并发危害分析**  
   - 无锁结构必须提供形式化证明：
     ```zig
     /// @lock-free-proof
     /// 1. Linearizability: 每个操作可视为在调用和返回间某个点原子执行
     /// 2. Progress guarantee: Wait-free population oblivious
     /// 3. Hazard pointer count ≤ 3 (ref: Michael '04)
     ```

5. **供应链内存安全**  
   - 所有依赖必须通过：
     ```zig
     /// @sbom-memory-safe [是/否]
     /// @memory-footprint MAX_HEAP=4KB, MAX_STACK=1KB
     /// @zeroize-policy AFTER_FREE (CWE-226 compliant)
     ```

> **合规声明**：  
> 本规范满足：  
> - ISO/SAE 21434:2021 §8.4.3 (汽车电子内存安全)  
> - IEC 62304:2015 Class C (医疗设备软件)  
> - NSA/CISA内存安全指南 (2024-Q4)  
>   
> **部署前提**：  
> 1. 加载硬件特定的MPU配置 `mpu_profiles.zig`  
> 2. 注册项目级泄漏处理程序 `leak_handlers.zig`  
> 3. 通过`zig build memaudit --strict`执行形式化验证  
>   
> *注：本规范内存安全部分需每6个月由第三方审计机构重新认证*
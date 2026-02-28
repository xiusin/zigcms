# Zig 内存管理器（Allocator）深度专题

## 概览
- Zig 无 GC，分配策略由业务显式选择，allocator 是性能与生命周期的控制点。
- 基本原则：谁分配谁释放；传递 allocator 不传全局；用合适的粒度（进程/请求/临时）。

## 1. 为什么 Zig 要显式传 Allocator
- Zig 不内置 GC，内存分配策略由业务显式选择。
- 显式传 `std.mem.Allocator` 的价值：
  - 可控：不同场景选择不同分配器（性能/安全/生命周期）。
  - 可测：测试时可替换为 `std.testing.allocator` 检测泄漏。
  - 可追踪：统一入口便于统计分配热点与泄漏路径。

## 2. Allocator 核心接口
常见接口：
- `alloc(T, n)`：分配 `n` 个 `T`。
- `create(T)`：分配单个 `T`。
- `dupe(T, slice)`：复制切片到新内存。
- `free(slice)` / `destroy(ptr)`：释放内存。
- `realloc(slice, new_len)`：调整容量（可能搬迁内存）。

基本约束：
- 分配和释放必须使用同一个 allocator。
- `realloc` 后旧指针视为失效。
- 释放时类型和边界必须一致。

## 3. 常见 Allocator 类型与选型
### 速查矩阵
- 低频小规模：`page_allocator`
- 通用默认：`GeneralPurposeAllocator`
- 请求级批量：`ArenaAllocator`
- 低延迟固定池：`FixedBufferAllocator`
- 调试泄漏：`std.testing.allocator` / GPA 调试模式

### 3.1 page_allocator
- 特点：简单直接、系统页粒度。
- 优点：使用简单。
- 缺点：频繁小对象分配开销较高。
- 适用：工具脚本、低频分配。

### 3.2 GeneralPurposeAllocator (GPA)
- 特点：通用堆分配器，适合长期运行服务。
- 优点：通用性强，可配合调试检测。
- 缺点：性能不如定制化 arena/pool（特定场景）。
- 适用：服务主进程默认分配器。

### 3.3 ArenaAllocator
- 特点：批量分配、批量释放（一次 `deinit`）。
- 优点：速度快，减少碎片，适合“请求级”生命周期。
- 缺点：无法细粒度释放单个对象。
- 适用：单请求上下文、一次性构建对象图。

### 3.4 FixedBufferAllocator
- 特点：在固定缓冲区上分配，不触发系统堆分配。
- 优点：可预测、低延迟。
- 缺点：容量固定，超限失败。
- 适用：嵌入式、实时路径、临时缓冲。

## 4. 生命周期分层设计（推荐）
- 进程级（长期）：GPA。
- 请求级（短期）：Arena（挂在请求上下文，结束即回收）。
- 热路径临时对象：栈 + FixedBuffer。

实践要点：
- 业务函数签名传 `allocator`，不要隐藏全局分配器。
- 请求处理结束统一 `arena.deinit()`，避免散乱 `free`。

## 5. 典型代码模式

### 5.1 正确：请求级 Arena
```zig
const std = @import("std");

pub fn handle(req_alloc: std.mem.Allocator) !void {
    var arena = std.heap.ArenaAllocator.init(req_alloc);
    defer arena.deinit();
    const a = arena.allocator();

    const buf = try a.alloc(u8, 1024);
    _ = buf;
    // 请求结束自动回收
}
```

### 5.2 正确：owned 返回约定
```zig
pub fn buildMessage(alloc: std.mem.Allocator, src: []const u8) ![]u8 {
    return try alloc.dupe(u8, src); // 调用方 free
}

pub fn caller(alloc: std.mem.Allocator) !void {
    const msg = try buildMessage(alloc, "ok");
    defer alloc.free(msg);
}
```

### 5.3 错误：跨 allocator 释放
```zig
// 错误示意：A 分配，B 释放
// const s = try alloc_a.dupe(u8, "x");
// alloc_b.free(s); // 未定义行为
```

### 5.4 预留容量、减少扩容
```zig
var list = std.ArrayList(u8).init(alloc);
defer list.deinit();
try list.ensureTotalCapacity(1024); // 减少扩容次数
```

### 5.5 GPA 调试模式（泄漏检测）
```zig
var gpa = std.heap.GeneralPurposeAllocator(.{ .enable_memory_limit = true, .safety = true }){};
const alloc = gpa.allocator();
defer {
    _ = gpa.deinit(); // 若有泄漏会报错
}
```

## 6. 高阶主题

### 6.1 碎片化治理
- 长期服务若出现碎片：
  - 减少随机大小分配；
  - 热路径对象池化；
  - 大对象与小对象分离策略；
  - 请求级 arena 降低碎片。

### 6.2 零拷贝与边界
- 优先传 `[]const u8` 视图，减少复制。
- 跨线程/异步边界必须明确所有权：
  - 只读共享（生命周期可保证）；
  - 或复制为 owned 后传递。

### 6.3 内存与性能平衡
- 小请求高并发：arena 常优于频繁 GPA 分配。
- 大对象长生命周期：单独管理，避免 Arena 堆积。
- 用基准测试验证，不凭直觉“优化”。

### 6.4 调试与观测
- 开启 GPA 调试模式：捕捉双重释放、未释放。
- 包装 allocator，记录分配栈或统计热点。
- 压测对比曲线：分配次数、扩容次数、RSS 走势。

## 6.5 实践图示（选型与生命周期）
```
需求评估
   │
   ├─请求级短生命周期→ Arena
   │
   ├─长期通用→ GPA
   │
   ├─固定小缓冲、低延迟→ FixedBuffer
   │
   └─调试/测试→ testing.allocator / GPA 调试

生命周期分层
   进程/GPA
      │
      ├─每请求 Arena
      │    └─结束统一 deinit
      └─热路径栈/FixedBuffer 临时
```

## 7. 常见踩坑清单
- 返回指向栈内存的切片。
- `realloc` 后继续使用旧切片。
- 忘记 `defer free` / `defer deinit`。
- `ArrayList` 未 `deinit`。
- map/list 中 value 里有堆对象，容器 `deinit` 后仍遗漏二级释放。
- error 分支提前 return，漏释放。
- Arena 用错：长期对象放入请求 Arena，结束即被释放。
- FixedBuffer 容量不足：超限失败未处理，落入未定义路径。

## 8. 可操作检查清单（上线前）
- [ ] 每个 `alloc/create/dupe` 是否有对应释放路径。
- [ ] 所有 `deinit` 是否在控制流覆盖（含错误路径）。
- [ ] 跨函数返回的数据是否声明 owned/borrowed 语义。
- [ ] 请求级对象是否由 arena 托管并在结束回收。
- [ ] 压测中内存曲线是否稳定（无持续爬升）。
- [ ] 是否存在跨 allocator 释放或遗失归属的对象。
- [ ] 是否对可预测容量的容器预留 capacity。

## 9. 常用场景建议
- API 控制器：请求级 Arena + 只读切片传参。
- 配置加载：启动期一次性分配，可长期持有。
- 日志拼接：优先固定缓冲或复用 buffer，避免每条日志堆分配。
- 导入导出：分块处理，避免一次性巨量分配。

## 10. 模板片段
- 请求级处理：`ArenaAllocator + defer arena.deinit()`。
- 返回 owned：`allocator.dupe` + 调用方 `free`。
- 容器使用：`ensureTotalCapacity` 预留，`deinit` 释放。

## 10. 结论
Allocator 不是“语法负担”，而是 Zig 的工程控制点。把“生命周期 + 所有权 + 分配策略”设计清楚，稳定性和性能会明显提升。

# 数组与哈希表（映射）基础（Zig 视角）

## 基础知识
- 数组 `[N]T`：固定长度，拥有存储；拷贝语义，长度编译期已知。
- 切片 `[]T` / `[]const T`：视图，不拥有存储；长度运行期决定。
- 动态数组：`std.ArrayList(T)` 持有可增长缓冲，内部是切片视图。
- 哈希表：键值映射，需哈希函数与相等比较；Zig 提供多种实现（AutoHashMap、StringHashMap 等）。

## 数组与切片
- `[N]T`：固定长度数组，编译期长度已知，拥有存储，赋值/传参会复制（或退化为指针视上下文）。
- `[]T`：切片，运行期长度，指向一段连续存储，不拥有内存。
- `[]const T`：只读切片视图，常用于只读参数；可从 `[N]T` 或 `[]T` 获取。
- `[*]T`：多项式指针，长度未知，少用；注意越界风险。

### 何时用
- 编译期长度明确、需栈上存储：`[N]T`。
- 运行期长度、需灵活：`[]T`/`[]const T`。
- 需要增长/缩减：配合 `std.ArrayList`（内部持有 `[]T`，自动扩容）。
- 需要保序但可插入删除：可用 `ArrayList` + 自定义删除逻辑或 `AutoArrayHashMap`（保插入序）。

### 常见操作示例
```zig
var arr: [3]i32 = .{1,2,3};
const slice: []const i32 = arr[0..];
var list = std.ArrayList(i32).init(allocator);
defer list.deinit();
try list.appendSlice(&.{4,5});
const dyn: []i32 = list.items; // 动态切片视图
```

### 常见坑
- 切片越界：`slice[idx]` 未检查范围，务必确保索引合法。
- 切片悬空：切片指向已释放/已出栈数组的内存。
- 复制成本：大数组赋值会拷贝，必要时传切片或指针。
- ArrayList 漏 `deinit`：未释放内部缓冲。
- 重复 `append` 时未预估容量，频繁扩容影响性能。

## 哈希表（映射）
- `std.AutoHashMap(K, V)`：自动哈希的 Map，K/V 类型需支持哈希和相等比较；适合一般用途。
- `std.StringHashMap(V)`：键为字符串的 Map，内部使用字符串哈希；便于存文本键。
- `std.HashMap(K, V, hasher, eql)`：自定义哈希和等价比较，适合需要定制哈希或特殊键类型。
- `std.AutoArrayHashMap(K, V)`：保持插入顺序的哈希表，键唯一且有序遍历需求时使用。

### 何时用
- 文本键：`StringHashMap`（或 `AutoHashMap([]const u8, V)`）。
- 一般键：`AutoHashMap`。
- 需自定义哈希/比较：`HashMap`。
- 需保序：`AutoArrayHashMap`。

### 基本用法示例（AutoHashMap）
```zig
const std = @import("std");

pub fn demoMap(allocator: std.mem.Allocator) !void {
    var map = std.AutoHashMap([]const u8, i32).init(allocator);
    defer map.deinit();

    try map.put("a", 1);
    try map.put("b", 2);

    if (map.get("a")) |v| {
        std.debug.print("a={d}\n", .{v});
    }

    var it = map.iterator();
    while (it.next()) |entry| {
        std.debug.print("{s} -> {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }
}
```

### StringHashMap 示例
```zig
const std = @import("std");

pub fn demoStrMap(allocator: std.mem.Allocator) !void {
    var map = std.StringHashMap(i32).init(allocator);
    defer map.deinit();

    try map.put("apple", 3);
    try map.put("banana", 5);

    if (map.get("banana")) |v| {
        std.debug.print("banana={d}\n", .{v});
    }
}
```

### 注意事项
- `deinit()` 负责释放内部存储，避免泄漏。
- 键/值若含堆分配数据，需在移除或 `deinit` 前自行释放或用 `HashMap` 的 `Context` 定制释放逻辑。
- 迭代时不要修改 Map 结构（除非 API 明确允许）。
- 字符串键注意生命周期：若键来自暂存 buffer，请先复制（如 `allocator.dupe`）。
- 负载因子与扩容：频繁 put/erase 会触发扩容/收缩，关注性能与内存。
- 保序需求：用 `AutoArrayHashMap`；无需顺序时选 `AutoHashMap` 更省内存。
- 大键或复杂键：考虑自定义哈希/比较以降低碰撞和哈希成本。

### 进阶用法
- 自定义哈希/比较：`std.HashMap(K, V, hasher, eql)`，适合复杂键（结构体、多字段）。
- 预留容量：`map.ensureTotalCapacity(n)` 减少多次扩容。
- 访问模式优化：若只追加不删除，遍历可更快；若频繁删除，注意碎片与 rehash 开销。

### 常见场景
- 配置/路由表：字符串键，选 `StringHashMap`。
- 统计计数：`AutoHashMap(K, usize)`，缺省返回 0 时需显式处理。
- 需要顺序的字典：`AutoArrayHashMap`（保持插入序）。
- 小范围、固定键集合：可用数组+查找表替代哈希，性能更高。

## 选择指引（简版）
- 固定小数组：`[N]T`。
- 运行期变长：`std.ArrayList` + 切片视图。
- 键值存取：字符串键用 `StringHashMap`，其他键优先 `AutoHashMap`，需要顺序就 `AutoArrayHashMap`。
- 自定义哈希/比较：`HashMap`。

## 进阶与检查清单
- [ ] ArrayList 是否 `deinit`？
- [ ] HashMap 是否在退出时 `deinit`，内部堆对象是否释放？
- [ ] 是否需要预留容量（list.ensureTotalCapacity / map.ensureTotalCapacity）？
- [ ] 是否存在切片越界或悬空风险？
- [ ] 键的生命周期是否可靠（字符串键是否拷贝）？

## 扩展实践
- 用 `AutoArrayHashMap` 保序输出（如配置生成、有序导出）。
- 用数组/表驱动替代哈希：小键空间可用枚举转索引，性能更高、无哈希开销。
- 组合结构：`ArrayList(HashMap)` 或 `HashMap(ArrayList)` 时，层层记得 `deinit`，并释放内层堆对象。

## 实践图示（选择路线）
```
需求：键值存取？
  ├─键为字符串→ StringHashMap
  ├─键一般类型→ AutoHashMap
  ├─需保持插入序→ AutoArrayHashMap
  └─键空间小/固定→ 数组/查找表

容量规划
  ├─提前知道规模→ ensureTotalCapacity
  └─不确定→ 监控扩容频次

生命周期
  容器 deinit → 释放内部存储
    └─若值含堆对象→ 先释放值，再 deinit 容器
```

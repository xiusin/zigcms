# 字符串/字节切片类型与转换（Zig）

## 基础知识
- 字符串常用 `[]const u8` 表示：只读视图，不拥有存储。
- 切片与数组：切片是视图，数组拥有存储；切片长度运行期决定，数组长度编译期固定。
- 可变性：`[]u8` 可写，`[]const u8` 只读；`const []const u8` 约束引用本身不可变。

## 常见类型
- `[]const u8`：可变长度、只读视图，最常用“字符串”切片类型，指向某块内存但不拥有。
- `const []const u8`：引用自身不可变且内容只读，常用于函数参数，表示既不改指针也不改内容。
- `[]u8`：可变切片，可写入修改，常用作缓冲区或输出目标。
- `[N]u8` / `[N]const u8`：固定长度数组，拥有存储，可切成切片后传递。

## 传参与选择
- 仅读取：参数用 `[]const u8`（或 `const []const u8`），可接受字面量、只读切片、常量数组切片。
- 需要修改：参数用 `[]u8`，调用方必须提供可写缓冲。
- 返回只读视图：返回 `[]const u8`，确保底层存储在使用期内有效，禁止指向已出栈或已释放内存。
- 返回可写缓冲：较少见，通常通过结构体持有或 out 参数填充。

## 常用转换示例
```zig
const literal: []const u8 = "hi";               // 字面量 -> 只读切片
var arr: [16]u8 = undefined;
var buf: []u8 = arr[0..];                        // 固定数组 -> 可写切片
const view: []const u8 = buf;                    // 可写切片视为只读切片
const owned = try allocator.dupe(u8, view);      // 复制为拥有的堆切片，需 free
defer allocator.free(owned);
```

## 注意事项
- 不要把只读视图（字面量/常量切片）传给需要 `[]u8` 的接口。
- 返回 `[]const u8` 时，底层存储必须在使用期内有效：
  - 字面量/静态存储：可以。
  - 堆分配：调用方负责释放或用拥有者结构体封装。
  - 栈局部：不可返回，会变悬空。
- 需要长期持有：复制（如 `allocator.dupe`）或提供 `*_owned` 接口，并明确释放责任。
- 线程/协程间传递：明确所有权和释放者，避免双重释放或遗漏。

## 进阶/易踩坑
- 悬空切片：返回指向栈局部的 `[]const u8`（错误）。
- 写入只读：将字面量/常量切片传给 `[]u8`（编译/运行错误）。
- 生命周期模糊：函数返回的切片指向短生命周期缓冲，使用期越界。
- 复制成本：`dupe` 复制数据，注意大字符串的内存与性能开销。

## 常用场景示例
- 读参数：`fn handle(path: []const u8) void { ... }`
- 返回短期视图（结构体包裹）：
  ```zig
  const StrView = struct { buf: [32]u8, str: []const u8 };
  fn shortView() StrView {
      var buf: [32]u8 = undefined;
      const s = "hi";
      std.mem.copy(u8, &buf, s);
      return .{ .buf = buf, .str = buf[0..s.len] };
  }
  ```
- 返回长期持有：
  ```zig
  fn ownedStr(alloc: std.mem.Allocator, src: []const u8) ![]u8 {
      return try alloc.dupe(u8, src); // 调用方 free
  }
  ```
- 就地写入缓冲：
  ```zig
  fn fill(buf: []u8) void {
      const msg = "ok";
      std.mem.copy(u8, buf[0..msg.len], msg);
  }
  ```

## 实践图示（选择与返回策略）
```
输入只读？→ []const u8
输入需写？→ []u8（调用方提供缓冲）
返回短期视图？→ 结构体携带 buf 与 str，同步回收
返回长期持有？→ dupe/owned 接口 + 调用方 free
跨线程？→ 明确所有权；只读共享或复制后传递
```

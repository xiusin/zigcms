//! 模板引擎（模板继承 / 块覆盖 / 宏）
//!
//! 继承模型（Twig 语义）：
//! - 子模板通过 `{% extends "parent" %}` 声明父模板，支持多级继承，循环 extends 报错。
//! - 渲染以继承链最外层（父）模板为主体，块按"最靠近子模板的定义优先"解析。
//! - 块内 `{% parent %}` 展开为继承链上一级的块定义，可逐级回溯。
//! - 宏从最外层向最内层收集，子模板同名宏覆盖父模板。
//! - `{% include "name" %}` 内联独立渲染目标模板（Twig 语义：宏/set 变量与外层互不可见），
//!   支持 `with <path>` 局部上下文（同名键覆盖外层）与 `only` 隔离（仅用 with 变量）；
//!   with 路径缺失按空对象兜底；嵌套上限 16 层防循环 include。
//! - `{% from "name" import a, b %}` / `{% from "name" import * %}` 显式导入宏进入渲染表
//!   （覆盖外层同名宏）；import 语句不产生输出。
//! - 子模板 extends 之外的顶层内容不渲染（Twig 语义：子模板只负责覆盖块）。
//!
//! 内存模型（借用，避免旧实现的悬垂与双重释放）：
//! - 模板 AST 在 loadTemplate 时一次性解析，由 Engine 缓存并独占拥有，deinit 统一释放。
//! - blocks/macros 缓存 map 只借用 AST 内的 name/body/params，不复制、不单独释放。
//! - render 期间所有临时状态（合并节点列表、宏表、set 变量表）分配在 render 局部 arena，
//!   仅借用缓存 AST 的节点，渲染结束随 arena 一次性释放。
//! - 缓存 key 使用复制后的模板名，调用方切片随时失效也安全。

const std = @import("std");

const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const renderer = @import("renderer.zig");
const loader = @import("loader.zig");
const ast = @import("ast.zig");
const functions = @import("functions.zig");
const core_io = @import("../../../core/io.zig");

pub const Engine = struct {
    allocator: std.mem.Allocator,
    loader: *loader.Loader,
    /// 模板缓存：key 为复制的模板名（Engine 拥有），value 为堆上 Template（Engine 拥有）
    templates: std.StringHashMap(*Template),
    functions: functions.FunctionRegistry,
    /// 缓存互斥锁：保护 templates 表的并发读写（double-checked locking）
    mutex: std.Io.Mutex = .init,

    /// 一个已解析模板。blocks/macros 的 key 与 value 均借用自身 ast 内的内存。
    const Template = struct {
        ast: std.ArrayList(ast.Node),
        blocks: std.StringHashMap(std.ArrayList(ast.Node)),
        macros: std.StringHashMap(ast.Macro),
    };

    pub fn init(allocator: std.mem.Allocator, template_loader: *loader.Loader) Engine {
        return .{
            .allocator = allocator,
            .loader = template_loader,
            .templates = std.StringHashMap(*Template).init(allocator),
            .functions = functions.FunctionRegistry.init(allocator),
        };
    }

    pub fn deinit(self: *Engine) void {
        var it = self.templates.iterator();
        while (it.next()) |entry| {
            self.destroyTemplate(entry.value_ptr.*);
            self.allocator.free(entry.key_ptr.*);
        }
        self.templates.deinit();
        self.functions.deinit();
    }

    /// 注册自定义函数
    pub fn registerFunction(self: *Engine, func_def: functions.Function) !void {
        try self.functions.register(func_def);
    }

    /// 渲染模板，返回的内存由调用方负责释放。
    pub fn render(self: *Engine, template_name: []const u8, context: std.json.Value) ![]u8 {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const output = try self.renderCore(arena.allocator(), template_name, context, 0);
        return try self.allocator.dupe(u8, output);
    }

    /// 渲染内核（arena 内）：继承链解析 + 宏收集 + 展开 + 渲染。
    /// depth 为 include 嵌套深度；include 通过嵌套 renderCore 实现
    /// 独立渲染上下文（宏/set 变量与外层互不可见，Twig 语义）。
    fn renderCore(self: *Engine, alloc: std.mem.Allocator, template_name: []const u8, context: std.json.Value, depth: usize) anyerror![]u8 {
        // 解析继承链：chain[0] 为子模板，最后一项为最外层父模板
        const chain = try self.resolveChain(alloc, template_name);
        const root = chain[chain.len - 1];

        // 宏：从最外层向最内层收集，子模板同名宏覆盖父模板
        var all_macros = std.StringHashMap(ast.Macro).init(alloc);
        var i = chain.len;
        while (i > 0) {
            i -= 1;
            var mit = chain[i].macros.iterator();
            while (mit.next()) |entry| {
                try all_macros.put(entry.key_ptr.*, entry.value_ptr.*);
            }
        }

        var set_vars = std.StringHashMap(std.json.Value).init(alloc);
        defer set_vars.deinit();

        // 以最外层模板为主体展开，块定义按继承链解析
        var merged = try std.ArrayList(ast.Node).initCapacity(alloc, 0);
        try self.flattenNodes(alloc, chain, root.ast, &all_macros, context, depth, &merged);

        return renderer.renderWithMacrosAndSet(alloc, merged, context, &all_macros, &self.functions, &set_vars);
    }

    /// 沿 extends 解析继承链，返回 [子, ..., 父] 顺序的模板指针数组（arena 分配）。
    fn resolveChain(self: *Engine, alloc: std.mem.Allocator, template_name: []const u8) ![]*Template {
        var chain = try std.ArrayList(*Template).initCapacity(alloc, 0);
        var visited = std.StringHashMap(void).init(alloc);
        defer visited.deinit();

        var current_name = template_name;
        while (true) {
            const gop = try visited.getOrPut(current_name);
            if (gop.found_existing) return error.CircularExtends;

            const tmpl = try self.loadTemplate(current_name);
            try chain.append(alloc, tmpl);

            var extends_name: ?[]const u8 = null;
            for (tmpl.ast.items) |node| {
                if (node == .extends) {
                    extends_name = node.extends.template_name;
                    break;
                }
            }
            if (extends_name) |name| {
                current_name = name;
            } else break;
        }
        return chain.items;
    }

    /// 加载并解析模板（带缓存），AST 由 Engine 长期持有。
    /// 并发护栏：double-checked locking——快速路径锁内查表；解析在锁外进行
    /// （IO/CPU 耗时），入表前二次检查，竞速失败者释放自己的副本复用先到者。
    fn loadTemplate(self: *Engine, template_name: []const u8) !*Template {
        self.mutex.lockUncancelable(core_io.getIo());
        if (self.templates.get(template_name)) |cached| {
            self.mutex.unlock(core_io.getIo());
            return cached;
        }
        self.mutex.unlock(core_io.getIo());

        const tmpl = try self.parseTemplate(template_name);
        errdefer self.destroyTemplate(tmpl);

        self.mutex.lockUncancelable(core_io.getIo());
        defer self.mutex.unlock(core_io.getIo());

        if (self.templates.get(template_name)) |winner| {
            // 另一线程已抢先入表：丢弃自己的副本，复用先到者
            self.destroyTemplate(tmpl);
            return winner;
        }
        const key = try self.allocator.dupe(u8, template_name);
        errdefer self.allocator.free(key);
        try self.templates.put(key, tmpl);

        return tmpl;
    }

    /// 解析模板为 Template（无锁，仅 loadTemplate 内部使用）
    fn parseTemplate(self: *Engine, template_name: []const u8) !*Template {
        // 内容归 loader 缓存所有（loader.deinit/clearCache 统一释放），这里只借用
        const content = try self.loader.load(template_name);

        var lex = lexer.Lexer.init(content);
        const parsed = try parser.parse(self.allocator, &lex, null);
        errdefer parser.freeAst(self.allocator, parsed);

        const tmpl = try self.allocator.create(Template);
        errdefer self.allocator.destroy(tmpl);

        tmpl.* = .{
            .ast = parsed,
            .blocks = std.StringHashMap(std.ArrayList(ast.Node)).init(self.allocator),
            .macros = std.StringHashMap(ast.Macro).init(self.allocator),
        };
        errdefer tmpl.blocks.deinit();
        errdefer tmpl.macros.deinit();

        // 提取顶层块与宏的借用视图（key/value 均指向 AST 内部内存，不复制不释放）
        for (parsed.items) |node| {
            switch (node) {
                .block => |b| try tmpl.blocks.put(b.name, b.body),
                .macro => |m| try tmpl.macros.put(m.name, .{ .params = m.params, .body = m.body }),
                else => {},
            }
        }

        return tmpl;
    }

    /// 释放一个 Template 及其 AST（Engine 拥有全部内存）
    fn destroyTemplate(self: *Engine, tmpl: *Template) void {
        parser.freeAst(self.allocator, tmpl.ast);
        tmpl.blocks.deinit();
        tmpl.macros.deinit();
        self.allocator.destroy(tmpl);
    }

    /// include 嵌套上限（防循环 include）
    const max_include_depth: usize = 16;

    /// 在继承链上从 from 开始查找定义了指定块的最近模板下标
    fn findBlockIndex(chain: []*Template, name: []const u8, from: usize) ?usize {
        var i = from;
        while (i < chain.len) : (i += 1) {
            if (chain[i].blocks.contains(name)) return i;
        }
        return null;
    }

    /// 展开模板顶层节点列表：块替换为继承链上的生效定义，宏/extends 不产生输出，
    /// include 内联独立渲染目标模板。
    /// 错误集为 anyerror：include 走 loader/解析路径（load_fn 本身是 anyerror 面），
    /// 更窄的显式错误集无法容纳；嵌套/循环防护以错误值表达
    /// （IncludeNestingTooDeep / BlockNestingTooDeep）。
    fn flattenNodes(self: *Engine, alloc: std.mem.Allocator, chain: []*Template, nodes: std.ArrayList(ast.Node), all_macros: *std.StringHashMap(ast.Macro), context: std.json.Value, depth: usize, out: *std.ArrayList(ast.Node)) anyerror!void {
        for (nodes.items) |node| {
            switch (node) {
                .block => |b| try self.flattenBlock(alloc, chain, b.name, b.body, all_macros, context, depth, out),
                .macro => {}, // 已收集进宏表
                .extends => {}, // 已在 resolveChain 处理
                .include => |inc| try self.expandInclude(alloc, inc.template_name, inc.with_path, inc.only, context, depth, out),
                .import => |imp| try self.mergeImports(imp.template_name, &imp.macro_names, all_macros),
                else => try out.append(alloc, node),
            }
        }
    }

    /// 内联展开 include：目标模板经嵌套 renderCore 独立渲染（Twig 语义：
    /// 宏/set 变量与外层互不可见），输出以 text 节点并入当前节点流。
    /// `with <path>`：以该变量合并进上下文（同名键覆盖）；`only`：仅使用 with 变量。
    /// with 路径缺失或指向非对象值时，合并语义按空对象/原上下文兜底。
    fn expandInclude(self: *Engine, alloc: std.mem.Allocator, template_name: []const u8, with_path: ?[]const u8, only: bool, context: std.json.Value, depth: usize, out: *std.ArrayList(ast.Node)) anyerror!void {
        if (depth >= max_include_depth) return error.IncludeNestingTooDeep;

        var eff_ctx = context;
        if (with_path) |p| {
            const val = resolveJsonPath(context, p) orelse std.json.Value{ .object = std.json.ObjectMap.empty };
            eff_ctx = if (only) val else try mergeContext(alloc, context, val);
        }

        const output = try self.renderCore(alloc, template_name, eff_ctx, depth + 1);
        try out.append(alloc, .{ .text = output });
    }

    /// import 合并：将目标模板的指定宏并入渲染表（覆盖外层同名宏）；
    /// "*" 表示全部宏。宏只取目标模板顶层定义（import 不引入继承链宏语义）。
    fn mergeImports(self: *Engine, template_name: []const u8, macro_names: *const std.ArrayList([]const u8), all_macros: *std.StringHashMap(ast.Macro)) anyerror!void {
        const tmpl = try self.loadTemplate(template_name);
        var it = tmpl.macros.iterator();
        while (it.next()) |entry| {
            const name = entry.key_ptr.*;
            for (macro_names.items) |want| {
                if (std.mem.eql(u8, want, "*") or std.mem.eql(u8, want, name)) {
                    try all_macros.put(name, entry.value_ptr.*);
                    break;
                }
            }
        }
    }

    /// 按 a.b.c 点路径在 JSON 上下文中取值；任一层缺失返回 null
    fn resolveJsonPath(value: std.json.Value, path: []const u8) ?std.json.Value {
        var cur = value;
        var it = std.mem.splitScalar(u8, path, '.');
        while (it.next()) |seg| {
            if (cur != .object) return null;
            cur = cur.object.get(seg) orelse return null;
        }
        return cur;
    }

    /// 合并上下文：val 中的键覆盖 base 同名键；任一方非对象时返回 base 原样
    fn mergeContext(alloc: std.mem.Allocator, base: std.json.Value, val: std.json.Value) !std.json.Value {
        if (base != .object or val != .object) return base;
        var merged = std.json.ObjectMap.empty;
        var it1 = base.object.iterator();
        while (it1.next()) |e| try merged.put(alloc, e.key_ptr.*, e.value_ptr.*);
        var it2 = val.object.iterator();
        while (it2.next()) |e| try merged.put(alloc, e.key_ptr.*, e.value_ptr.*);
        return std.json.Value{ .object = merged };
    }

    /// 展开一个块：取继承链上最靠近子模板的定义，`{% parent %}` 展开为上一级定义
    fn flattenBlock(self: *Engine, alloc: std.mem.Allocator, chain: []*Template, name: []const u8, fallback: std.ArrayList(ast.Node), all_macros: *std.StringHashMap(ast.Macro), context: std.json.Value, depth: usize, out: *std.ArrayList(ast.Node)) anyerror!void {
        const idx = findBlockIndex(chain, name, 0) orelse {
            try self.flattenBlockBody(alloc, chain, fallback, name, 0, all_macros, context, depth, out);
            return;
        };
        try self.flattenBlockBody(alloc, chain, chain[idx].blocks.get(name).?, name, idx, all_macros, context, depth, out);
    }

    /// 展开块体节点；found_idx 为该块定义所在模板在链上的下标，`{% parent %}` 从其后继续查找
    fn flattenBlockBody(self: *Engine, alloc: std.mem.Allocator, chain: []*Template, body: std.ArrayList(ast.Node), name: []const u8, found_idx: usize, all_macros: *std.StringHashMap(ast.Macro), context: std.json.Value, depth: usize, out: *std.ArrayList(ast.Node)) anyerror!void {
        if (depth > 32) return error.BlockNestingTooDeep;
        for (body.items) |node| {
            switch (node) {
                .parent => {
                    if (findBlockIndex(chain, name, found_idx + 1)) |next| {
                        try self.flattenBlockBody(alloc, chain, chain[next].blocks.get(name).?, name, next, all_macros, context, depth + 1, out);
                    }
                    // 无上一级定义：parent 渲染为空
                },
                .block => |b| try self.flattenBlock(alloc, chain, b.name, b.body, all_macros, context, depth + 1, out),
                .include => |inc| try self.expandInclude(alloc, inc.template_name, inc.with_path, inc.only, context, depth, out),
                .import => |imp| try self.mergeImports(imp.template_name, &imp.macro_names, all_macros),
                else => try out.append(alloc, node),
            }
        }
    }
};

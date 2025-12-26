//! 模板引擎
//!
//! 支持模板继承、包含、宏等高级特性

const std = @import("std");

const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const renderer = @import("renderer.zig");
const loader = @import("loader.zig");
const ast = @import("ast.zig");

pub const Engine = struct {
    allocator: std.mem.Allocator,
    loader: *loader.Loader,
    templates: std.StringHashMap(Template),

    const Template = struct {
        ast: std.ArrayList(ast.Node),
        blocks: std.StringHashMap(std.ArrayList(ast.Node)),
        macros: std.StringHashMap(Macro),
    };

    const Macro = struct {
        params: std.ArrayList([]const u8),
        body: std.ArrayList(ast.Node),
    };

    pub fn init(allocator: std.mem.Allocator, template_loader: *loader.Loader) Engine {
        return .{
            .allocator = allocator,
            .loader = template_loader,
            .templates = std.StringHashMap(Template).init(allocator),
        };
    }

    pub fn deinit(self: *Engine) void {
        var it = self.templates.iterator();
        while (it.next()) |entry| {
            var tmpl = entry.value_ptr.*;
            parser.freeAst(self.allocator, tmpl.ast);
            tmpl.ast.deinit(self.allocator);
            
            var block_it = tmpl.blocks.iterator();
            while (block_it.next()) |block_entry| {
                parser.freeAst(self.allocator, block_entry.value_ptr.*);
                block_entry.value_ptr.*.deinit(self.allocator);
            }
            tmpl.blocks.deinit();
            
            var macro_it = tmpl.macros.iterator();
            while (macro_it.next()) |macro_entry| {
                parser.freeAst(self.allocator, macro_entry.value_ptr.*.body);
                macro_entry.value_ptr.*.body.deinit(self.allocator);
                macro_entry.value_ptr.*.params.deinit(self.allocator);
                self.allocator.destroy(macro_entry.value_ptr.*);
            }
            tmpl.macros.deinit();
        }
        self.templates.deinit();
    }

    /// 渲染模板
    pub fn render(self: *Engine, template_name: []const u8, context: std.json.Value) ![]u8 {
        // 加载模板
        const template = try self.loadTemplate(template_name);
        
        // 创建 arena 用于临时内存分配
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const alloc = arena.allocator();
        
        // 创建合并后的 AST
        var merged_ast = try std.ArrayList(ast.Node).initCapacity(alloc, 0);
        defer merged_ast.deinit(alloc);
        
        // 合并父模板和当前模板
        try self.mergeTemplate(alloc, template, null, &merged_ast);
        
        // 渲染
        return renderer.render(self.allocator, merged_ast, context);
    }

    /// 加载模板（带缓存）
    fn loadTemplate(self: *Engine, template_name: []const u8) !*Template {
        // 检查缓存
        if (self.templates.get(template_name)) |tmpl| {
            return tmpl;
        }

        // 加载模板内容
        const content = try self.loader.load(template_name);
        defer self.allocator.free(content);

        // 解析模板
        var lex = lexer.Lexer.init(content);
        const ast_nodes = try parser.parse(self.allocator, &lex, null);

        // 提取块和宏
        var blocks = std.StringHashMap(std.ArrayList(ast.Node)).init(self.allocator);
        var macros = std.StringHashMap(Macro).init(self.allocator);
        var filtered_ast = try std.ArrayList(ast.Node).initCapacity(self.allocator, 0);

        for (ast_nodes.items) |node| {
            switch (node) {
                .block => |b| {
                    try blocks.put(b.name, b.body);
                },
                .macro => |m| {
                    const macro = try self.allocator.create(Macro);
                    macro.* = .{
                        .params = m.params,
                        .body = m.body,
                    };
                    try macros.put(m.name, macro.*);
                },
                else => {
                    try filtered_ast.append(node);
                },
            }
        }

        // 创建模板并缓存
        const tmpl = try self.allocator.create(Template);
        tmpl.* = .{
            .ast = filtered_ast,
            .blocks = blocks,
            .macros = macros,
        };
        try self.templates.put(template_name, tmpl.*);

        return tmpl;
    }

    /// 合并模板（处理继承）
    fn mergeTemplate(self: *Engine, allocator: std.mem.Allocator, template: *Template, parent_name: ?[]const u8, merged_ast: *std.ArrayList(ast.Node)) !void {
        // 查找 extends 节点
        var extends_name: ?[]const u8 = null;
        for (template.ast.items) |node| {
            if (node == .extends) {
                extends_name = node.extends.template_name;
                break;
            }
        }

        if (extends_name) |name| {
            // 递归加载父模板
            const parent_template = try self.loadTemplate(name);
            try self.mergeTemplate(allocator, parent_template, name, merged_ast);
        }

        // 合并当前模板的节点（跳过 block 和 macro 节点）
        for (template.ast.items) |node| {
            switch (node) {
                .block, .macro => {}, // 跳过，已经在模板定义中
                .extends => {}, // 跳过，已经处理
                .else => try merged_ast.append(node),
            }
        }
    }
};
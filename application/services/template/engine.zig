//! 模板引擎
//!
//! 支持模板继承、包含、宏等高级特性

const std = @import("std");

const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const renderer = @import("renderer.zig");
const loader = @import("loader.zig");
const ast = @import("ast.zig");
const functions = @import("functions.zig");

pub const Engine = struct {
    allocator: std.mem.Allocator,
    loader: *loader.Loader,
    templates: std.StringHashMap(Template),
    functions: functions.FunctionRegistry,

    const Template = struct {
        ast: std.ArrayList(ast.Node),
        blocks: std.StringHashMap(std.ArrayList(ast.Node)),
        macros: std.StringHashMap(Macro),
        parent_blocks: std.StringHashMap(std.ArrayList(ast.Node)),
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
            .functions = functions.FunctionRegistry.init(allocator),
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
        self.functions.deinit();
    }

    /// 注册自定义函数
    pub fn registerFunction(self: *Engine, func_def: functions.Function) !void {
        try self.functions.register(func_def);
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
        
        // 合并所有宏定义
        var all_macros = std.StringHashMap(ast.Macro).init(alloc);
        defer {
            var it = all_macros.iterator();
            while (it.next()) |entry| {
                parser.freeAst(alloc, entry.value_ptr.*.body);
                entry.value_ptr.*.body.deinit(alloc);
                entry.value_ptr.*.params.deinit(alloc);
            }
            all_macros.deinit();
        }
        
        // 创建 set 变量存储
        var set_vars = std.StringHashMap(std.json.Value).init(alloc);
        defer {
            var it = set_vars.iterator();
            while (it.next()) |entry| {
                if (entry.value_ptr.* == .string) alloc.free(entry.value_ptr.*.string);
                else if (entry.value_ptr.* == .array) entry.value_ptr.*.array.deinit(alloc);
            }
            set_vars.deinit();
        }
        
        // 合并父模板和当前模板
        try self.mergeTemplate(alloc, template, null, &merged_ast, &all_macros, null);
        
        // 渲染
        return renderer.renderWithMacrosAndSet(self.allocator, merged_ast, context, &all_macros, &self.functions, &set_vars);
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
            .parent_blocks = std.StringHashMap(std.ArrayList(ast.Node)).init(self.allocator),
        };
        try self.templates.put(template_name, tmpl.*);

        return tmpl;
    }

    /// 合并模板（处理继承）
    fn mergeTemplate(self: *Engine, allocator: std.mem.Allocator, template: *Template, parent_name: ?[]const u8, merged_ast: *std.ArrayList(ast.Node), all_macros: *std.StringHashMap(ast.Macro), current_block_name: ?[]const u8) !void {
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
            try self.mergeTemplate(allocator, parent_template, name, merged_ast, all_macros, null);
            
            // 将父模板的所有块内容保存到当前模板的 parent_blocks
            var parent_block_it = parent_template.blocks.iterator();
            while (parent_block_it.next()) |entry| {
                const block_name = entry.key_ptr.*;
                const block_body = entry.value_ptr.*;
                
                // 检查当前模板是否定义了这个块
                if (!template.blocks.contains(block_name)) {
                    // 如果没有定义，将父块内容添加到当前模板的块中
                    var new_body = try std.ArrayList(ast.Node).initCapacity(allocator, block_body.items.len);
                    for (block_body.items) |node| {
                        try new_body.append(node);
                    }
                    try template.blocks.put(try allocator.dupe(u8, block_name), new_body);
                }
                
                // 保存父块的原始内容到 parent_blocks
                var parent_body = try std.ArrayList(ast.Node).initCapacity(allocator, block_body.items.len);
                for (block_body.items) |node| {
                    try parent_body.append(node);
                }
                try template.parent_blocks.put(try allocator.dupe(u8, block_name), parent_body);
            }
        }

        // 收集宏定义
        var macro_it = template.macros.iterator();
        while (macro_it.next()) |entry| {
            const macro_name = entry.key_ptr.*;
            const macro_def = entry.value_ptr.*;
            
            // 复制宏定义到 all_macros
            const new_body = try std.ArrayList(ast.Node).initCapacity(allocator, macro_def.body.items.len);
            for (macro_def.body.items) |node| {
                try new_body.append(node);
            }
            
            const new_params = try std.ArrayList([]const u8).initCapacity(allocator, macro_def.params.items.len);
            for (macro_def.params.items) |param| {
                try new_params.append(try allocator.dupe(u8, param));
            }
            
            const new_macro: ast.Macro = .{
                .params = new_params,
                .body = new_body,
            };
            
            try all_macros.put(macro_name, new_macro);
        }

        // 合并当前模板的节点（跳过 block 和 macro 节点）
        for (template.ast.items) |node| {
            switch (node) {
                .block => |b| {
                    // 渲染块内容，处理 parent 节点
                    try self.renderBlock(allocator, b.body, merged_ast, template, all_macros, b.name);
                },
                .macro => {}, // 跳过，已经在模板定义中
                .extends => {}, // 跳过，已经处理
                .else => try merged_ast.append(node),
            }
        }
    }

    /// 渲染块内容，处理 parent 节点
    fn renderBlock(
        self: *Engine,
        allocator: std.mem.Allocator,
        block_body: std.ArrayList(ast.Node),
        merged_ast: *std.ArrayList(ast.Node),
        template: *Template,
        all_macros: *std.StringHashMap(ast.Macro),
        block_name: []const u8,
    ) !void {
        for (block_body.items) |node| {
            switch (node) {
                .parent => {
                    // parent 节点：渲染父块的原始内容
                    if (template.parent_blocks.get(block_name)) |parent_body| {
                        try self.renderBlock(allocator, parent_body, merged_ast, template, all_macros, block_name);
                    }
                },
                else => try merged_ast.append(node),
            }
        }
    }
};
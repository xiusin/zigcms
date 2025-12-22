//! 素材管理控制器
//!
//! 提供素材的 CRUD 操作及文件上传管理

const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const models = @import("../../domain/entities/models.zig");
const sql = @import("../../application/services/sql/orm.zig");
const global = @import("../../shared/primitives/global.zig");
const json_mod = @import("../../application/services/json/json.zig");
const strings = @import("../../shared/utils/strings.zig");
const mw = @import("../middleware/mod.zig");
const upload_service = @import("../../application/services/upload/upload.zig");

const Self = @This();
const MW = mw.Controller(Self);

allocator: Allocator,
upload_manager: ?*upload.UploadManager = null,

/// ORM 模型定义
const OrmMaterial = sql.defineWithConfig(models.Material, .{
    .table_name = "zigcms.material",
    .primary_key = "id",
});

/// 初始化控制器
pub fn init(allocator: Allocator) Self {
    if (!OrmMaterial.hasDb()) {
        OrmMaterial.use(global.get_db());
    }

    // TODO: 初始化上传管理器
    // 这里应该从配置中读取上传服务配置
    // 暂时设为null，使用本地上传
    return .{
        .allocator = allocator,
        .upload_manager = null,
    };
}

// ============================================================================
// 公开 API（带认证中间件）
// ============================================================================

/// 分页列表
pub const list = MW.requireAuth(listImpl);

/// 获取单条记录
pub const get = MW.requireAuth(getImpl);

/// 保存（新增/更新）
pub const save = MW.requireAuth(saveImpl);

/// 删除
pub const delete = MW.requireAuth(deleteImpl);

/// 批量删除
pub const batch_delete = MW.requireAuth(batchDeleteImpl);

/// 上传文件
pub const upload = MW.requireAuth(uploadImpl);

/// 下载文件
pub const download = MW.requireAuth(downloadImpl);

// ============================================================================
// 实现方法
// ============================================================================

/// 分页列表实现
fn listImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    var query_params = std.StringHashMap([]const u8).init(self.allocator);
    defer query_params.deinit();

    // 解析查询参数
    var it = r.queryParameters();
    while (it.next()) |param| {
        if (param.key) |key| {
            if (param.value) |value| {
                try query_params.put(key, value);
            }
        }
    }

    // 构建查询
    var query = OrmMaterial.query(global.get_db());
    defer query.deinit();

    // 分类筛选
    if (query_params.get("category_id")) |category_id_str| {
        if (std.fmt.parseInt(i32, category_id_str, 10)) |category_id| {
            _ = query.where("category_id", "=", category_id);
        } else |_| {}
    }

    // 文件类型筛选
    if (query_params.get("file_type")) |file_type| {
        if (file_type.len > 0) {
            _ = query.where("file_type", "=", file_type);
        }
    }

    // 状态筛选
    if (query_params.get("status")) |status_str| {
        if (std.fmt.parseInt(i32, status_str, 10)) |status| {
            _ = query.where("status", "=", status);
        } else |_| {}
    }

    // 关键词搜索
    if (query_params.get("keyword")) |keyword| {
        if (keyword.len > 0) {
            _ = query.whereRaw("name LIKE ? OR original_name LIKE ?", .{ "%" ++ keyword ++ "%", "%" ++ keyword ++ "%" });
        }
    }

    // 排序
    _ = query.orderBy("sort", .asc).orderBy("create_time", .desc);

    // 分页
    const page = if (query_params.get("page")) |p| std.fmt.parseInt(u32, p, 10) catch 1 else 1;
    const page_size = if (query_params.get("page_size")) |ps| std.fmt.parseInt(u32, ps, 10) catch 10 else 10;

    var result = try query.paginate(page, page_size);
    defer result.deinit();

    // 构建响应
    var response_data = std.StringHashMap(json_mod.Value).init(self.allocator);
    defer response_data.deinit();

    try response_data.put("code", json_mod.Value{ .integer = 0 });
    try response_data.put("msg", json_mod.Value{ .string = "success" });
    try response_data.put("data", json_mod.Value{ .object = result.toJson() });

    try base.send_layui_table_response(self.allocator, response, response_data);
}

/// 获取单条记录实现
fn getImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    _ = self;
    const id_str = r.pathParameters().get("id") orelse {
        base.send_error(response, "缺少ID参数");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        base.send_error(response, "无效的ID格式");
        return;
    };

    if (try OrmMaterial.find(global.get_db(), id)) |material| {
        try base.send_ok(response, material);
    } else {
        try base.send_failed(response, "素材不存在");
    }
}

/// 保存实现
fn saveImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    const body = r.body orelse {
        base.send_error(response, "请求体为空");
        return;
    };

    const MaterialCreateDto = @import("../dto/material_create.dto.zig").MaterialCreateDto;
    const dto = json_mod.parse(MaterialCreateDto, self.allocator, body) catch {
        base.send_error(response, "JSON格式错误");
        return;
    };
    defer json_mod.free(self.allocator, dto);

    // 保存数据
    const material = try OrmMaterial.create(global.get_db(), .{
        .name = dto.name,
        .original_name = dto.original_name,
        .file_path = dto.file_path,
        .file_url = dto.file_url,
        .file_size = dto.file_size,
        .file_type = dto.file_type,
        .mime_type = dto.mime_type,
        .extension = dto.extension,
        .category_id = dto.category_id,
        .user_id = 0, // TODO: 从JWT token获取用户ID
        .user_name = "", // TODO: 从JWT token获取用户名
        .tags = dto.tags,
        .description = dto.description,
        .thumb_path = dto.thumb_path,
        .thumb_url = dto.thumb_url,
        .width = dto.width,
        .height = dto.height,
        .sort = dto.sort,
        .status = dto.status,
        .is_private = dto.is_private,
        .remark = dto.remark,
    });

    try base.send_ok(response, material);
}

/// 删除实现
fn deleteImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    _ = self;
    const id_str = r.pathParameters().get("id") orelse {
        base.send_error(response, "缺少ID参数");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        base.send_error(response, "无效的ID格式");
        return;
    };

    // 获取素材信息，用于删除物理文件
    if (try OrmMaterial.find(global.get_db(), id)) |material| {
        // TODO: 删除物理文件
        _ = material;
    }

    const affected = try OrmMaterial.destroy(global.get_db(), id);
    if (affected > 0) {
        try base.send_ok(response, .{ .affected = affected });
    } else {
        try base.send_failed(response, "删除失败");
    }
}

/// 批量删除实现
fn batchDeleteImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    const body = r.body orelse {
        base.send_error(response, "请求体为空");
        return;
    };

    const BatchDeleteDto = struct {
        ids: []i32,
    };

    const dto = json_mod.parse(BatchDeleteDto, self.allocator, body) catch {
        base.send_error(response, "JSON格式错误");
        return;
    };
    defer json_mod.free(self.allocator, dto);

    if (dto.ids.len == 0) {
        base.send_error(response, "请选择要删除的素材");
        return;
    }

    var affected: i32 = 0;
    for (dto.ids) |id| {
        // TODO: 删除物理文件
        const result = try OrmMaterial.destroy(global.get_db(), id);
        affected += result;
    }

    try base.send_ok(response, .{ .affected = affected });
}

/// 文件上传实现
fn uploadImpl(_: Self, _: zap.Request, response: zap.Response) !void {
    // TODO: 实现文件上传逻辑
    // 这里需要处理multipart/form-data上传
    // 保存文件到磁盘，返回文件信息

    base.send_error(response, "文件上传功能正在开发中，请稍后使用");
}

/// 文件下载实现
fn downloadImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    _ = self;
    const id_str = r.pathParameters().get("id") orelse {
        base.send_error(response, "缺少ID参数");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        base.send_error(response, "无效的ID格式");
        return;
    };

    if (try OrmMaterial.find(global.get_db(), id)) |material| {
        if (material.is_private == 1) {
            // TODO: 检查用户权限
        }

        // TODO: 返回文件流
        base.send_error(response, "文件下载功能暂未实现");
    } else {
        try base.send_failed(response, "素材不存在");
    }
}

/// MCP 自动测试上报工具 - API 客户端
/// 负责与 ZigCMS 后端服务通信，上报测试结果、同步 Bug 状态
const std = @import("std");
const models = @import("models.zig");
const http_client_mod = @import("../../../application/services/http/client.zig");
const HttpClient = http_client_mod.HttpClient;
const HttpResponse = http_client_mod.Response;

/// API 客户端
pub const ApiClient = struct {
    allocator: std.mem.Allocator,
    base_url: []const u8,
    http_client: HttpClient,

    /// 初始化
    pub fn init(allocator: std.mem.Allocator, base_url: []const u8) ApiClient {
        var client = HttpClient.init(allocator);
        client.setHeader("Content-Type", "application/json") catch {};
        client.setHeader("Accept", "application/json") catch {};
        return .{
            .allocator = allocator,
            .base_url = base_url,
            .http_client = client,
        };
    }

    /// 释放资源
    pub fn deinit(self: *ApiClient) void {
        self.http_client.deinit();
    }

    /// 上报测试报告到后端
    pub fn reportTest(self: *ApiClient, report: *const models.TestReport) !i64 {
        var json_buf = std.ArrayList(u8).init(self.allocator);
        defer json_buf.deinit();

        try self.serializeTestReport(&json_buf, report);

        const response = try self.post("/api/auto-test/report/create", json_buf.items);
        defer self.allocator.free(response);

        return try self.extractId(response);
    }

    /// 上报 Bug 到后端
    pub fn reportBug(self: *ApiClient, bug: *const models.BugAnalysis) !i64 {
        var json_buf = std.ArrayList(u8).init(self.allocator);
        defer json_buf.deinit();

        try self.serializeBugAnalysis(&json_buf, bug);

        const response = try self.post("/api/auto-test/bug/create", json_buf.items);
        defer self.allocator.free(response);

        return try self.extractId(response);
    }

    /// 获取未处理的 Bug 列表
    pub fn getPendingBugs(self: *ApiClient, priority: ?models.BugPriority, limit: i64) ![]models.BugAnalysis {
        var url_buf = std.ArrayList(u8).init(self.allocator);
        defer url_buf.deinit();

        try url_buf.appendSlice("/api/auto-test/bug/list?status=pending");

        if (priority) |p| {
            try url_buf.appendSlice("&priority=");
            try url_buf.appendSlice(p.toString());
        }

        const limit_str = try std.fmt.allocPrint(self.allocator, "&limit={d}", .{limit});
        defer self.allocator.free(limit_str);
        try url_buf.appendSlice(limit_str);

        const response = try self.get(url_buf.items);
        defer self.allocator.free(response);

        return try self.parseBugList(response);
    }

    /// 更新 Bug 状态
    pub fn updateBugStatus(self: *ApiClient, bug_id: i64, status: models.BugStatus) !void {
        var json_buf = std.ArrayList(u8).init(self.allocator);
        defer json_buf.deinit();

        try json_buf.appendSlice("{\"bug_id\":");
        const id_str = try std.fmt.allocPrint(self.allocator, "{d}", .{bug_id});
        defer self.allocator.free(id_str);
        try json_buf.appendSlice(id_str);
        try json_buf.appendSlice(",\"status\":\"");
        try json_buf.appendSlice(status.toString());
        try json_buf.appendSlice("\"}");

        const response = try self.post("/api/auto-test/bug/update-status", json_buf.items);
        defer self.allocator.free(response);
    }

    /// 获取 Bug 详情
    pub fn getBugDetail(self: *ApiClient, bug_id: i64) !?models.BugAnalysis {
        const url = try std.fmt.allocPrint(self.allocator, "/api/auto-test/bug/detail?id={d}", .{bug_id});
        defer self.allocator.free(url);

        const response = try self.get(url);
        defer self.allocator.free(response);

        return try self.parseBugDetail(response);
    }

    /// 获取统计信息
    pub fn getStatistics(self: *ApiClient, time_range: []const u8) !models.TestStatistics {
        const url = try std.fmt.allocPrint(self.allocator, "/api/auto-test/statistics?range={s}", .{time_range});
        defer self.allocator.free(url);

        const response = try self.get(url);
        defer self.allocator.free(response);

        return try self.parseStatistics(response);
    }

    // ========== 内部 HTTP 方法 ==========

    /// 构造完整 URL
    fn buildUrl(self: *ApiClient, path: []const u8) ![]const u8 {
        return try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base_url, path });
    }

    /// 发送 GET 请求，返回响应体（调用方负责释放）
    fn get(self: *ApiClient, path: []const u8) ![]const u8 {
        const url = try self.buildUrl(path);
        defer self.allocator.free(url);

        var resp = try self.http_client.get(url);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            return error.HttpRequestFailed;
        }

        return try self.allocator.dupe(u8, resp.body);
    }

    /// 发送 POST 请求，返回响应体（调用方负责释放）
    fn post(self: *ApiClient, path: []const u8, body: []const u8) ![]const u8 {
        const url = try self.buildUrl(path);
        defer self.allocator.free(url);

        var resp = try self.http_client.post(url, body);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            return error.HttpRequestFailed;
        }

        return try self.allocator.dupe(u8, resp.body);
    }

    // ========== 序列化方法 ==========

    /// 序列化测试报告为 JSON
    fn serializeTestReport(self: *ApiClient, buf: *std.ArrayList(u8), report: *const models.TestReport) !void {
        try buf.appendSlice("{");
        try self.appendJsonString(buf, "name", report.name);
        try buf.appendSlice(",");
        try self.appendJsonString(buf, "type", report.test_type.toString());
        try buf.appendSlice(",");
        try self.appendJsonString(buf, "status", report.status.toString());
        try buf.appendSlice(",");
        try self.appendJsonInt(buf, "total_cases", report.total_cases);
        try buf.appendSlice(",");
        try self.appendJsonInt(buf, "passed_cases", report.passed_cases);
        try buf.appendSlice(",");
        try self.appendJsonInt(buf, "failed_cases", report.failed_cases);
        try buf.appendSlice(",");
        try self.appendJsonInt(buf, "skipped_cases", report.skipped_cases);

        if (report.duration_ms) |d| {
            try buf.appendSlice(",");
            try self.appendJsonI64(buf, "duration", d);
        }

        if (report.error_message) |msg| {
            try buf.appendSlice(",");
            try self.appendJsonString(buf, "error_message", msg);
        }

        if (report.stack_trace) |trace| {
            try buf.appendSlice(",");
            try self.appendJsonString(buf, "stack_trace", trace);
        }

        try buf.appendSlice("}");
    }

    /// 序列化 Bug 分析为 JSON
    fn serializeBugAnalysis(self: *ApiClient, buf: *std.ArrayList(u8), bug: *const models.BugAnalysis) !void {
        try buf.appendSlice("{");
        try self.appendJsonString(buf, "title", bug.title);
        try buf.appendSlice(",");
        try self.appendJsonString(buf, "description", bug.description);
        try buf.appendSlice(",");
        try self.appendJsonString(buf, "type", bug.bug_type.toString());
        try buf.appendSlice(",");
        try self.appendJsonString(buf, "severity", bug.severity.toString());
        try buf.appendSlice(",");
        try self.appendJsonString(buf, "priority", bug.priority.toString());
        try buf.appendSlice(",");
        try self.appendJsonString(buf, "issue_location", bug.issue_location.toString());
        try buf.appendSlice(",");
        try self.appendJsonString(buf, "status", bug.status.toString());

        if (bug.file_path) |fp| {
            try buf.appendSlice(",");
            try self.appendJsonString(buf, "file_path", fp);
        }

        if (bug.root_cause) |rc| {
            try buf.appendSlice(",");
            try self.appendJsonString(buf, "root_cause", rc);
        }

        if (bug.suggested_fix) |sf| {
            try buf.appendSlice(",");
            try self.appendJsonString(buf, "suggested_fix", sf);
        }

        if (bug.test_report_id) |tid| {
            try buf.appendSlice(",");
            try self.appendJsonI64(buf, "test_report_id", tid);
        }

        try buf.appendSlice("}");
    }

    // ========== JSON 辅助方法 ==========

    /// 追加 JSON 字符串字段
    fn appendJsonString(self: *ApiClient, buf: *std.ArrayList(u8), key: []const u8, value: []const u8) !void {
        _ = self;
        try buf.appendSlice("\"");
        try buf.appendSlice(key);
        try buf.appendSlice("\":\"");
        // 简单转义
        for (value) |c| {
            switch (c) {
                '"' => try buf.appendSlice("\\\""),
                '\\' => try buf.appendSlice("\\\\"),
                '\n' => try buf.appendSlice("\\n"),
                '\r' => try buf.appendSlice("\\r"),
                '\t' => try buf.appendSlice("\\t"),
                else => try buf.append(c),
            }
        }
        try buf.appendSlice("\"");
    }

    /// 追加 JSON 整数字段（i32）
    fn appendJsonInt(self: *ApiClient, buf: *std.ArrayList(u8), key: []const u8, value: i32) !void {
        const val_str = try std.fmt.allocPrint(self.allocator, "\"{s}\":{d}", .{ key, value });
        defer self.allocator.free(val_str);
        try buf.appendSlice(val_str);
    }

    /// 追加 JSON 整数字段（i64）
    fn appendJsonI64(self: *ApiClient, buf: *std.ArrayList(u8), key: []const u8, value: i64) !void {
        const val_str = try std.fmt.allocPrint(self.allocator, "\"{s}\":{d}", .{ key, value });
        defer self.allocator.free(val_str);
        try buf.appendSlice(val_str);
    }

    // ========== 反序列化方法 ==========

    /// 从响应中提取 ID
    fn extractId(self: *ApiClient, response: []const u8) !i64 {
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, response, .{}) catch {
            return error.InvalidResponse;
        };
        defer parsed.deinit();

        if (parsed.value.object.get("data")) |data| {
            if (data.object.get("id")) |id| {
                return id.integer;
            }
        }
        return error.MissingId;
    }

    /// 解析 Bug 列表
    fn parseBugList(self: *ApiClient, response: []const u8) ![]models.BugAnalysis {
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, response, .{}) catch {
            return error.InvalidResponse;
        };
        defer parsed.deinit();

        const data = parsed.value.object.get("data") orelse return error.InvalidResponse;
        const items = data.object.get("items") orelse data.object.get("list") orelse return error.InvalidResponse;

        var result = std.ArrayList(models.BugAnalysis).init(self.allocator);
        errdefer result.deinit();

        for (items.array.items) |item| {
            const obj = item.object;
            try result.append(.{
                .id = if (obj.get("id")) |v| v.integer else null,
                .title = try self.allocator.dupe(u8, if (obj.get("title")) |v| v.string else "未知"),
                .description = try self.allocator.dupe(u8, if (obj.get("description")) |v| v.string else ""),
                .bug_type = if (obj.get("bug_type")) |v| models.BugType.fromString(v.string) orelse .functional else .functional,
                .severity = if (obj.get("severity")) |v| parseSeverity(v.string) else .p2,
                .priority = if (obj.get("priority")) |v| models.BugPriority.fromString(v.string) orelse .medium else .medium,
                .status = if (obj.get("status")) |v| models.BugStatus.fromString(v.string) orelse .pending else .pending,
                .issue_location = .unknown,
                .file_path = if (obj.get("file_path")) |v| if (v == .string) try self.allocator.dupe(u8, v.string) else null else null,
                .root_cause = if (obj.get("root_cause")) |v| if (v == .string) try self.allocator.dupe(u8, v.string) else null else null,
                .suggested_fix = if (obj.get("suggested_fix")) |v| if (v == .string) try self.allocator.dupe(u8, v.string) else null else null,
                .confidence_score = if (obj.get("confidence_score")) |v| switch (v) {
                    .float => @as(f32, @floatCast(v.float)),
                    .integer => @as(f32, @floatFromInt(v.integer)),
                    else => 0.0,
                } else 0.0,
                .test_report_id = if (obj.get("test_report_id")) |v| if (v == .integer) v.integer else null else null,
            });
        }

        return result.toOwnedSlice();
    }

    /// 解析严重程度字符串
    fn parseSeverity(s: []const u8) models.BugSeverity {
        const map = std.StaticStringMap(models.BugSeverity).initComptime(.{
            .{ "p0", .p0 }, .{ "p1", .p1 }, .{ "p2", .p2 },
            .{ "p3", .p3 }, .{ "p4", .p4 },
        });
        return map.get(s) orelse .p2;
    }

    /// 解析 Bug 详情
    fn parseBugDetail(self: *ApiClient, response: []const u8) !?models.BugAnalysis {
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, response, .{}) catch {
            return null;
        };
        defer parsed.deinit();

        const data = parsed.value.object.get("data") orelse return null;
        const obj = data.object;

        return models.BugAnalysis{
            .id = if (obj.get("id")) |v| v.integer else null,
            .title = try self.allocator.dupe(u8, if (obj.get("title")) |v| v.string else "未知"),
            .description = try self.allocator.dupe(u8, if (obj.get("description")) |v| v.string else ""),
            .bug_type = if (obj.get("bug_type")) |v| models.BugType.fromString(v.string) orelse .functional else .functional,
            .severity = if (obj.get("severity")) |v| parseSeverity(v.string) else .p2,
            .priority = if (obj.get("priority")) |v| models.BugPriority.fromString(v.string) orelse .medium else .medium,
            .status = if (obj.get("status")) |v| models.BugStatus.fromString(v.string) orelse .pending else .pending,
            .issue_location = .unknown,
            .file_path = if (obj.get("file_path")) |v| if (v == .string) try self.allocator.dupe(u8, v.string) else null else null,
            .line_number = if (obj.get("line_number")) |v| if (v == .integer) @as(i32, @intCast(v.integer)) else null else null,
            .root_cause = if (obj.get("root_cause")) |v| if (v == .string) try self.allocator.dupe(u8, v.string) else null else null,
            .suggested_fix = if (obj.get("suggested_fix")) |v| if (v == .string) try self.allocator.dupe(u8, v.string) else null else null,
            .confidence_score = if (obj.get("confidence_score")) |v| switch (v) {
                .float => @as(f32, @floatCast(v.float)),
                .integer => @as(f32, @floatFromInt(v.integer)),
                else => 0.0,
            } else 0.0,
            .auto_fix_attempted = if (obj.get("auto_fix_attempted")) |v| if (v == .bool) v.bool else false else false,
            .test_report_id = if (obj.get("test_report_id")) |v| if (v == .integer) v.integer else null else null,
            .feedback_id = if (obj.get("feedback_id")) |v| if (v == .integer) v.integer else null else null,
        };
    }

    /// 解析统计信息
    fn parseStatistics(self: *ApiClient, response: []const u8) !models.TestStatistics {
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, response, .{}) catch {
            return models.TestStatistics{};
        };
        defer parsed.deinit();

        const data = parsed.value.object.get("data") orelse return models.TestStatistics{};
        const obj = data.object;

        const getI32 = struct {
            fn call(o: std.json.ObjectMap, key: []const u8) i32 {
                if (o.get(key)) |v| {
                    if (v == .integer) return @as(i32, @intCast(v.integer));
                }
                return 0;
            }
        }.call;

        var stats = models.TestStatistics{
            .total_tests = getI32(obj, "total_reports"),
            .passed_tests = getI32(obj, "passed_reports"),
            .failed_tests = getI32(obj, "failed_reports"),
            .total_bugs = getI32(obj, "total_bugs"),
            .pending_bugs = getI32(obj, "pending_bugs"),
            .auto_fixed_bugs = getI32(obj, "resolved_bugs"),
        };
        stats.calculateAutoFixRate();
        stats.calculateOverallPassRate();
        return stats;
    }
};

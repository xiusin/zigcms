//! 基于角色的访问控制（RBAC）中间件
//!
//! 提供细粒度的权限控制功能

const std = @import("std");
const zap = @import("zap");
const CacheInterface = @import("../../application/services/cache/contract.zig").CacheInterface;

/// 权限定义
pub const Permission = struct {
    /// 权限代码
    code: []const u8,
    /// 权限名称
    name: []const u8,
    /// 权限描述
    description: []const u8,
    /// 资源类型
    resource: []const u8,
    /// 操作类型
    action: []const u8,
};

/// 角色定义
pub const Role = struct {
    /// 角色 ID
    id: i32,
    /// 角色代码
    code: []const u8,
    /// 角色名称
    name: []const u8,
    /// 权限列表
    permissions: []Permission,
};

/// 用户权限上下文
pub const UserPermissionContext = struct {
    /// 用户 ID
    user_id: i32,
    /// 用户角色
    roles: []Role,
    /// 用户权限（合并所有角色的权限）
    permissions: std.StringHashMap(void),
    
    allocator: std.mem.Allocator,
    
    const Self = @This();
    
    /// 初始化用户权限上下文
    pub fn init(allocator: std.mem.Allocator, user_id: i32, roles: []Role) !Self {
        var permissions = std.StringHashMap(void).init(allocator);
        
        // 合并所有角色的权限
        for (roles) |role| {
            for (role.permissions) |perm| {
                try permissions.put(perm.code, {});
            }
        }
        
        return .{
            .user_id = user_id,
            .roles = roles,
            .permissions = permissions,
            .allocator = allocator,
        };
    }
    
    /// 释放资源
    pub fn deinit(self: *Self) void {
        self.permissions.deinit();
    }
    
    /// 检查是否有权限
    pub fn hasPermission(self: *const Self, permission: []const u8) bool {
        return self.permissions.contains(permission);
    }
    
    /// 检查是否有任一权限
    pub fn hasAnyPermission(self: *const Self, permissions: []const []const u8) bool {
        for (permissions) |perm| {
            if (self.hasPermission(perm)) return true;
        }
        return false;
    }
    
    /// 检查是否有所有权限
    pub fn hasAllPermissions(self: *const Self, permissions: []const []const u8) bool {
        for (permissions) |perm| {
            if (!self.hasPermission(perm)) return false;
        }
        return true;
    }
    
    /// 检查是否有角色
    pub fn hasRole(self: *const Self, role_code: []const u8) bool {
        for (self.roles) |role| {
            if (std.mem.eql(u8, role.code, role_code)) return true;
        }
        return false;
    }
};

/// RBAC 配置
pub const RbacConfig = struct {
    /// 是否启用 RBAC
    enabled: bool = true,
    /// 超级管理员角色代码
    super_admin_role: []const u8 = "super_admin",
    /// 公开路径（不需要权限）
    public_paths: []const []const u8 = &.{
        "/api/auth/login",
        "/api/auth/register",
        "/api/health",
    },
};

/// RBAC 中间件
pub const RbacMiddleware = struct {
    allocator: std.mem.Allocator,
    config: RbacConfig,
    cache: *CacheInterface,
    
    const Self = @This();
    
    /// 初始化 RBAC 中间件
    pub fn init(allocator: std.mem.Allocator, config: RbacConfig, cache: *CacheInterface) Self {
        return .{
            .allocator = allocator,
            .config = config,
            .cache = cache,
        };
    }
    
    /// 检查权限
    pub fn checkPermission(self: *Self, req: *zap.Request, required_permission: []const u8) !void {
        if (!self.config.enabled) return;
        
        // 检查是否是公开路径
        const path = req.path orelse return error.PathNotFound;
        for (self.config.public_paths) |public_path| {
            if (std.mem.eql(u8, path, public_path)) return;
        }
        
        // 获取用户权限上下文
        const user_ctx = try self.getUserPermissionContext(req);
        defer user_ctx.deinit();
        
        // 超级管理员拥有所有权限
        if (user_ctx.hasRole(self.config.super_admin_role)) return;
        
        // 检查权限
        if (!user_ctx.hasPermission(required_permission)) {
            return error.PermissionDenied;
        }
    }
    
    /// 检查任一权限
    pub fn checkAnyPermission(self: *Self, req: *zap.Request, required_permissions: []const []const u8) !void {
        if (!self.config.enabled) return;
        
        const user_ctx = try self.getUserPermissionContext(req);
        defer user_ctx.deinit();
        
        // 超级管理员拥有所有权限
        if (user_ctx.hasRole(self.config.super_admin_role)) return;
        
        // 检查任一权限
        if (!user_ctx.hasAnyPermission(required_permissions)) {
            return error.PermissionDenied;
        }
    }
    
    /// 检查所有权限
    pub fn checkAllPermissions(self: *Self, req: *zap.Request, required_permissions: []const []const u8) !void {
        if (!self.config.enabled) return;
        
        const user_ctx = try self.getUserPermissionContext(req);
        defer user_ctx.deinit();
        
        // 超级管理员拥有所有权限
        if (user_ctx.hasRole(self.config.super_admin_role)) return;
        
        // 检查所有权限
        if (!user_ctx.hasAllPermissions(required_permissions)) {
            return error.PermissionDenied;
        }
    }
    
    /// 获取用户权限上下文
    fn getUserPermissionContext(self: *Self, req: *zap.Request) !UserPermissionContext {
        // 从请求中获取用户 ID
        const user_id = req.getUserId() orelse return error.UserNotAuthenticated;
        
        // 从缓存获取用户角色和权限
        const cache_key = try std.fmt.allocPrint(
            self.allocator,
            "user_permissions:{d}",
            .{user_id},
        );
        defer self.allocator.free(cache_key);
        
        // 1. 尝试从缓存获取
        if (try self.loadFromCache(user_id)) |ctx| {
            return ctx;
        }
        
        // 2. 从数据库加载
        const ctx = try self.loadFromDatabase(user_id);
        
        // 3. 缓存结果
        try self.saveToCache(user_id, &ctx);
        
        return ctx;
    }
    
    /// 从缓存加载用户权限
    fn loadFromCache(self: *Self, user_id: i32) !?UserPermissionContext {
        const cache_key = try std.fmt.allocPrint(
            self.allocator,
            "user_permissions:{d}",
            .{user_id},
        );
        defer self.allocator.free(cache_key);
        
        // 从缓存获取权限数据（JSON 格式）
        const cached_data = self.cache.get(cache_key, self.allocator) catch return null;
        defer self.allocator.free(cached_data);
        
        // 解析 JSON 并构建权限上下文
        // TODO: 实现 JSON 解析逻辑
        return null;
    }
    
    /// 从数据库加载用户权限
    fn loadFromDatabase(self: *Self, user_id: i32) !UserPermissionContext {
        // 获取角色仓储
        const RoleRepository = @import("../../domain/repositories/role_repository.zig").RoleRepository;
        const container = @import("../../core/di/mod.zig").getGlobalContainer();
        const role_repo = try container.resolve(RoleRepository);
        
        // 查询用户角色
        const roles = try role_repo.findByUserId(user_id);
        defer {
            // 释放角色内存
            for (roles) |*role| {
                if (role.permissions) |perms| {
                    for (perms) |*perm| {
                        self.allocator.free(perm.code);
                        self.allocator.free(perm.name);
                        self.allocator.free(perm.description);
                        self.allocator.free(perm.resource);
                        self.allocator.free(perm.action);
                        self.allocator.free(perm.category);
                        self.allocator.free(perm.created_at);
                        self.allocator.free(perm.updated_at);
                    }
                    self.allocator.free(perms);
                }
                self.allocator.free(role.code);
                self.allocator.free(role.name);
                self.allocator.free(role.description);
                self.allocator.free(role.created_at);
                self.allocator.free(role.updated_at);
            }
            self.allocator.free(roles);
        }
        
        // 构建权限上下文
        return try UserPermissionContext.init(self.allocator, user_id, roles);
    }
    
    /// 保存权限到缓存
    fn saveToCache(self: *Self, user_id: i32, ctx: *const UserPermissionContext) !void {
        const cache_key = try std.fmt.allocPrint(
            self.allocator,
            "user_permissions:{d}",
            .{user_id},
        );
        defer self.allocator.free(cache_key);
        
        // 序列化权限上下文为 JSON
        // TODO: 实现 JSON 序列化逻辑
        const json_data = try std.fmt.allocPrint(
            self.allocator,
            "{{\"user_id\":{d}}}",
            .{ctx.user_id},
        );
        defer self.allocator.free(json_data);
        
        // 缓存 5 分钟
        try self.cache.set(cache_key, json_data, 300);
    }
};

/// 权限错误类型
pub const RbacError = error{
    UserNotAuthenticated,
    PermissionDenied,
    PathNotFound,
};

/// 质量中心权限定义
pub const QualityCenterPermissions = struct {
    // 测试用例权限
    pub const TEST_CASE_VIEW = "quality:test_case:view";
    pub const TEST_CASE_CREATE = "quality:test_case:create";
    pub const TEST_CASE_UPDATE = "quality:test_case:update";
    pub const TEST_CASE_DELETE = "quality:test_case:delete";
    pub const TEST_CASE_EXECUTE = "quality:test_case:execute";
    pub const TEST_CASE_BATCH_DELETE = "quality:test_case:batch_delete";
    pub const TEST_CASE_BATCH_UPDATE = "quality:test_case:batch_update";
    
    // 项目权限
    pub const PROJECT_VIEW = "quality:project:view";
    pub const PROJECT_CREATE = "quality:project:create";
    pub const PROJECT_UPDATE = "quality:project:update";
    pub const PROJECT_DELETE = "quality:project:delete";
    pub const PROJECT_ARCHIVE = "quality:project:archive";
    
    // 模块权限
    pub const MODULE_VIEW = "quality:module:view";
    pub const MODULE_CREATE = "quality:module:create";
    pub const MODULE_UPDATE = "quality:module:update";
    pub const MODULE_DELETE = "quality:module:delete";
    pub const MODULE_MOVE = "quality:module:move";
    
    // 需求权限
    pub const REQUIREMENT_VIEW = "quality:requirement:view";
    pub const REQUIREMENT_CREATE = "quality:requirement:create";
    pub const REQUIREMENT_UPDATE = "quality:requirement:update";
    pub const REQUIREMENT_DELETE = "quality:requirement:delete";
    pub const REQUIREMENT_LINK = "quality:requirement:link";
    
    // 反馈权限
    pub const FEEDBACK_VIEW = "quality:feedback:view";
    pub const FEEDBACK_CREATE = "quality:feedback:create";
    pub const FEEDBACK_UPDATE = "quality:feedback:update";
    pub const FEEDBACK_DELETE = "quality:feedback:delete";
    pub const FEEDBACK_ASSIGN = "quality:feedback:assign";
    pub const FEEDBACK_FOLLOW_UP = "quality:feedback:follow_up";
    
    // 统计权限
    pub const STATISTICS_VIEW = "quality:statistics:view";
    pub const STATISTICS_EXPORT = "quality:statistics:export";
    
    // AI 生成权限
    pub const AI_GENERATE = "quality:ai:generate";
};

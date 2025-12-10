//! 服务管理器
//!
//! 这个模块管理应用程序中的各种服务实例
//! 包括数据库服务、缓存服务、字典服务等

const std = @import("std");
const sql = @import("../services/sql/orm.zig");
const CacheService = @import("../services/cache/cache.zig").CacheService;
const DictService = @import("../services/cache/dict_service.zig").DictService;

pub const ServiceManager = struct {
    const Self = @This();
    
    allocator: std.mem.Allocator,
    
    // 数据库连接
    db: *sql.Database,
    
    // 缓存服务
    cache: CacheService,
    
    // 字典服务
    dict_service: DictService,
    
    // 其他服务...
    
    pub fn init(allocator: std.mem.Allocator, db: *sql.Database) !ServiceManager {
        var cache = CacheService.init(allocator);
        
        var dict_service = DictService.init(allocator, db, &cache);
        
        return .{
            .allocator = allocator,
            .db = db,
            .cache = cache,
            .dict_service = dict_service,
        };
    }
    
    pub fn deinit(self: *ServiceManager) void {
        self.cache.deinit();
        // 不需要显式释放 db，因为它由调用者管理
    }
    
    /// 获取字典服务
    pub fn getDictService(self: *ServiceManager) *DictService {
        return &self.dict_service;
    }
    
    /// 获取缓存服务
    pub fn getCacheService(self: *ServiceManager) *CacheService {
        return &self.cache;
    }
    
    /// 清理所有服务的缓存
    pub fn clearAllCaches(self: *ServiceManager) !void {
        // 通知所有需要清理缓存的服务
        try self.cache.flush();
    }
    
    /// 刷新所有缓存
    pub fn refreshAllCaches(self: *ServiceManager) !void {
        // 清理所有缓存
        try self.clearAllCaches();
        
        // 预加载常用数据到缓存
        try self.dict_service.refreshDictCache();
    }
    
    /// 获取缓存统计
    pub fn getCacheStats(self: *ServiceManager) !struct { count: usize, expired: usize } {
        return try self.cache.stats();
    }
    
    /// 清理过期缓存项
    pub fn cleanupExpiredCache(self: *ServiceManager) !void {
        try self.cache.cleanupExpired();
    }
};
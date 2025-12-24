//! 仓储接口模块 (Repositories Module)
//!
//! 定义数据访问层的抽象接口，具体实现在基础设施层。
//! 使用接口隔离领域层与数据存储细节，遵循依赖倒置原则。
//!
//! ## 功能
//! - 定义通用的 CRUD 接口（Repository.Interface）
//! - 支持多态实现（通过 vtable）
//!
//! ## 使用示例
//! ```zig
//! const repositories = @import("domain/repositories/mod.zig");
//!
//! // 定义用户仓储接口
//! const UserRepository = repositories.Repository.Interface(User);
//!
//! // 使用仓储接口
//! const user = try repo.findById(1);
//! const users = try repo.findAll();
//! ```

const std = @import("std");

// 通用仓库接口
pub const Repository = struct {
    // 定义通用的 CRUD 接口
    pub fn Interface(comptime T: type) type {
        return struct {
            ptr: *anyopaque,
            vtable: *const VTable,

            pub const VTable = struct {
                findById: *const fn (*anyopaque, i32) anyerror!?T,
                findAll: *const fn (*anyopaque) anyerror![]T,
                save: *const fn (*anyopaque, T) anyerror!T,
                update: *const fn (*anyopaque, T) anyerror!void,
                delete: *const fn (*anyopaque, i32) anyerror!void,
                count: *const fn (*anyopaque) anyerror!usize,
            };

            pub fn findById(self: @This(), id: i32) !?T {
                return self.vtable.findById(self.ptr, id);
            }

            pub fn findAll(self: @This()) ![]T {
                return self.vtable.findAll(self.ptr);
            }

            pub fn save(self: @This(), entity: T) !T {
                return self.vtable.save(self.ptr, entity);
            }

            pub fn update(self: @This(), entity: T) !void {
                return self.vtable.update(self.ptr, entity);
            }

            pub fn delete(self: @This(), id: i32) !void {
                return self.vtable.delete(self.ptr, id);
            }

            pub fn count(self: @This()) !usize {
                return self.vtable.count(self.ptr);
            }
        };
    }
};

// Repository 接口已在模块顶层导出，无需重复

// 具体仓储接口导出
pub const user_repository = @import("user_repository.zig");
pub const member_repository = @import("member_repository.zig");
pub const category_repository = @import("category_repository.zig");

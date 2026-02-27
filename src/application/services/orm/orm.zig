//! ORM 服务模块
//!
//! 提供类似 Go GORM 的简洁 ORM 接口。
//!
//! ## 设计理念
//!
//! Zig 没有运行时反射，但 comptime 元编程足够强大：
//! - 编译期生成 SQL，零运行时开销
//! - 类型安全的参数传递
//! - 自动处理 id 字段和时间戳
//!
//! ## 使用示例
//!
//! ```zig
//! const orm = @import("services/orm/orm.zig");
//!
//! // 定义仓储
//! const UserRepo = orm.Repository(User, "zigcms");
//!
//! // 使用
//! var repo = UserRepo.init(pool, allocator);
//!
//! // CRUD
//! var user = User{ .name = "test", .email = "test@example.com" };
//! const id = try repo.create(&user);
//! const found = try repo.findById(id);
//! try repo.update(&user);
//! try repo.deleteById(id);
//!
//! // 分页
//! var page = try repo.findPage(1, 10, "id", "desc");
//! defer page.deinit();
//! ```

pub const entity = @import("entity.zig");
pub const repository = @import("repository.zig");

pub const EntityMeta = entity.EntityMeta;
pub const RepositoryFn = repository.RepositoryFn;
pub const PageResult = repository.PageResult;

test {
    _ = entity;
    _ = @import("tests.zig");
}

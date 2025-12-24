# ZigCMS 依赖注入架构指南

## 概述

本文档详细介绍了 ZigCMS 项目中新引入的依赖注入（DI）架构。该架构替换了原有的手动依赖管理方式，提供了更加灵活、可测试和可维护的服务管理方案。

## 架构改进对比

### 重构前（手动依赖管理）

```zig
// 全局变量管理（容易出错）
var user_service_instance: ?*UserService = null;
var member_service_instance: ?*MemberService = null;

// 手动初始化（代码重复）
fn initApplicationServices() !void {
    // 重复的初始化逻辑...
    user_service_instance = try createUserService();
    member_service_instance = try createMemberService();
}

// 手动清理（容易遗漏）
fn deinitSystem() void {
    if (user_service_instance) |service| {
        allocator.destroy(service);
    }
    // 可能遗漏其他服务的清理...
}
```

### 重构后（DI容器管理）

```zig
// 使用DI容器自动管理
const container = try di.createContainer(allocator);

// 统一注册服务
try container.registerSingleton(UserService, createUserService);
try container.registerSingleton(MemberService, createMemberService);

// 自动解析使用
const user_service = try container.resolve(UserService);
const member_service = try container.resolve(MemberService);

// 自动清理（无需手动处理）
container.deinit();
```

## 核心组件

### 1. DI容器 (DIContainer)

**位置**: `shared/di/container.zig`

**主要功能**:
- **服务注册**: 支持单例和瞬态服务注册
- **服务解析**: 类型安全的服务获取
- **生命周期管理**: 自动管理服务实例的生命周期
- **依赖验证**: 检查服务间的依赖关系

**使用示例**:
```zig
const di = @import("shared/di/mod.zig");

// 注册服务
try di.registerService(UserService, UserService, createUserServiceFactory, .Singleton);

// 解析服务
const user_service = try di.resolveService(UserService);
```

### 2. 服务注册表 (ServiceRegistry)

**位置**: `shared/di/service_registry.zig`

**主要功能**:
- **服务发现**: 集中管理所有服务注册信息
- **依赖分析**: 分析服务间的依赖关系，检测循环依赖
- **配置驱动**: 支持从配置文件自动注册服务

### 3. 配置管理器 (ConfigManager)

**位置**: `shared/config/config_manager.zig`

**主要功能**:
- **热重载**: 支持运行时配置更新
- **环境变量覆盖**: 优先级管理
- **配置验证**: 确保配置值的有效性

## 使用指南

### 基本使用流程

1. **系统初始化**
```zig
try zigcms.initSystem(allocator, config);
```

2. **服务注册**（已在 `root.zig` 中自动完成）
```zig
// 自动注册了 UserService, MemberService, CategoryService
```

3. **服务使用**
```zig
const di = zigcms.shared.di;

// 安全获取服务（返回可选类型）
if (di.tryResolveService(UserService)) |user_service| {
    // 使用服务...
}

// 强制获取服务（可能抛出错误）
const user_service = try di.resolveService(UserService);
```

### 添加新服务

1. **创建服务实现**
```zig
// 在适当的层级创建服务实现
```

2. **注册服务**（在 `root.zig` 的 `registerApplicationServices` 中添加）
```zig
try container.registerSingleton(NewService, NewService, createNewServiceFactory(db));
```

3. **使用服务**
```zig
const new_service = try di.resolveService(NewService);
```

### 测试中使用

```zig
test "使用DI容器进行测试" {
    // 创建测试专用的容器
    const test_container = try di.createTestContainer(std.testing.allocator);
    defer test_container.deinit();

    // 注册Mock服务
    try test_container.registerSingleton(UserService, MockUserService, createMockUserService);

    // 进行测试...
}
```

## 优势与改进

### 1. 可测试性提升
- **Mock替换**: 测试时可以轻松替换真实实现为Mock
- **隔离测试**: 每个测试可以使用独立的DI容器
- **依赖注入**: 便于控制测试环境

### 2. 可维护性增强
- **单一职责**: 每个服务专注于自己的职责
- **依赖透明**: 服务间依赖关系清晰可见
- **配置集中**: 服务配置集中管理

### 3. 扩展性优化
- **插件化**: 支持动态添加新服务
- **配置驱动**: 通过配置控制服务行为
- **标准化**: 统一的服务管理接口

### 4. 错误处理改进
- **类型安全**: 编译时检查服务类型
- **错误传播**: 统一的错误处理机制
- **资源清理**: 自动的资源生命周期管理

## 最佳实践

### 1. 服务设计原则
- **接口隔离**: 每个服务应有明确的职责边界
- **依赖最小化**: 尽量减少服务间的直接依赖
- **无状态设计**: 尽量设计无状态的服务实现

### 2. 配置管理
- **环境区分**: 为不同环境提供不同的配置
- **敏感信息**: 敏感配置通过环境变量管理
- **配置验证**: 启动时验证配置的完整性

### 3. 测试策略
- **单元测试**: 使用Mock服务进行隔离测试
- **集成测试**: 使用真实服务进行端到端测试
- **性能测试**: 监控服务性能表现

## 故障排除

### 常见问题

1. **服务未注册错误**
   - 检查服务是否在 `registerApplicationServices` 中正确注册
   - 确认服务类型名称匹配

2. **循环依赖错误**
   - 使用 `registry.analyzeDependencies()` 分析依赖关系
   - 重构服务设计，消除循环依赖

3. **内存泄漏**
   - 确保所有服务都正确注册到DI容器
   - 使用 `container.deinit()` 正确清理资源

### 调试技巧

```zig
// 获取服务统计信息
const stats = container.getStats();
std.debug.print("服务统计: {}\n", .{stats});

// 获取依赖图
const graph = try registry.getDependencyGraph(allocator);
std.debug.print("依赖图:\n{s}\n", .{graph});
```

## 迁移指南

### 从旧架构迁移

1. **移除全局变量**: 删除手动的服务实例变量
2. **使用DI容器**: 替换直接的服务访问为DI容器解析
3. **更新测试**: 重构测试用例使用Mock服务
4. **验证功能**: 确保重构后功能正常

## 未来规划

### 短期目标
- [ ] 完善配置热重载功能
- [ ] 添加服务健康检查
- [ ] 集成性能监控

### 长期目标
- [ ] 支持动态服务发现
- [ ] 实现服务熔断机制
- [ ] 添加分布式追踪

## 相关文档

- [架构设计文档](../ARCHITECTURE.md)
- [配置管理指南](../configs/README.md)
- [API文档](../docs/api/)

---

*本文档最后更新: 2024-12-24*
```
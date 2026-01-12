# ZigCMS Plugin System - Technical Specification

## Assessment: HARD

**Complexity Level:** HARD - This task involves architectural refactoring, security considerations, memory safety guarantees across FFI boundaries, and complex systems programming challenges.

---

## 1. Technical Context

### 1.1 Environment
- **Language**: Zig 0.15.0+
- **Architecture**: Clean Architecture (Hexagonal/Ports & Adapters)
- **Plugin Loading**: Dynamic libraries (.so/.dylib/.dll) via `std.DynLib`
- **Concurrency**: Multi-threaded with mutex-based synchronization
- **Memory Model**: Manual memory management with arena allocators

### 1.2 Current Implementation Analysis

#### Two Separate Implementations Found:

**Implementation A: `plugins/` (Recommended)**
- Location: `plugins/plugin_manager.zig`, `plugins/plugin_interface.zig`
- Features:
  - Clean VTable-based interface (`PluginVTable`)
  - Capability bitmap system (8 capabilities defined)
  - Thread-safe operations (`std.Thread.Mutex`)
  - Hot reload support via `reloadPlugin()`
  - Lifecycle management: unloaded → loaded → initialized → running → stopped
  - Export symbols with Zig calling convention
  - Uses static storage in plugins to avoid cross-boundary allocations
- API Version: 1

**Implementation B: `application/services/plugins/` (Legacy)**
- Location: `application/services/plugins/plugin_manager.zig`
- Features similar to A but with different interface design
- Appears to be an older iteration

**Duplication Issue:** Having two implementations creates:
- Confusion for third-party plugin developers
- Maintenance burden
- Inconsistent behavior
- Unclear which implementation to use

---

## 2. Current System Architecture

### 2.1 Plugin Interface Contract

```zig
// Required exported functions from plugins:
pub fn plugin_get_info() *const PluginInfo;
pub fn plugin_get_capabilities() u32;
pub fn plugin_init() ?*anyopaque;
pub fn plugin_deinit(?*anyopaque) void;
pub fn plugin_start(?*anyopaque) bool;  // Optional
pub fn plugin_stop(?*anyopaque) bool;   // Optional
```

### 2.2 Plugin Lifecycle States

```
unloaded (0) → loaded (1) → initialized (2) → running (3) → stopped (4)
                                                    ↓
                                              error_state (5)
```

### 2.3 Capability System

Current capabilities (plugins/plugin_interface.zig:7-35):
- `http_handlers` - HTTP request handling
- `middleware` - Request/response middleware
- `scheduler` - Scheduled tasks
- `database_hooks` - Database event hooks
- `event_listener` - Event system integration
- `template_extension` - Template system extensions
- `custom_routes` - Route registration
- `websocket` - WebSocket support

### 2.4 Memory Safety Strategy

**Current Approach:**
- Plugins use static/global storage (`var g_plugin_data: PluginData`)
- Avoids cross-boundary heap allocations
- Host manages all allocations for plugin metadata
- Plugin receives no allocator (uses its own internal storage)

**Problem:** This limits plugin flexibility and doesn't scale well for complex plugins.

---

## 3. Critical Issues Identified

### 3.1 Security Vulnerabilities

**No Security Boundaries:**
- ❌ No signature verification for plugin binaries
- ❌ No checksum validation (only `getPluginChecksum()` helper exists)
- ❌ No sandboxing - plugins run in same process space
- ❌ No permission system beyond capabilities
- ❌ Plugins can crash entire application
- ❌ No audit logging for plugin actions

**Attack Vectors:**
1. Malicious plugin loading arbitrary code
2. Plugin accessing unauthorized memory
3. Plugin calling unsafe system APIs
4. Supply chain attacks (compromised plugin files)

### 3.2 Memory Safety Issues

**Cross-Boundary Allocations:**
- Current design avoids this, but limits functionality
- Plugin data must fit in static storage
- No way to handle dynamic-sized plugin state

**Resource Leaks:**
- `LoadedPlugin.deinit()` may not be called if process crashes
- DynLib handles not guaranteed to close on error paths
- Plugin internal resources may leak if deinit fails

### 3.3 Version & Compatibility

**Missing:**
- ❌ No ABI version checking beyond simple API version
- ❌ No Zig version compatibility check
- ❌ No semantic versioning support
- ❌ No dependency declaration mechanism
- ❌ Plugins cannot declare required host features

### 3.4 Plugin Isolation

**Problems:**
- Plugins share process space (crash affects all)
- No resource limits (CPU, memory, file handles)
- No timeout mechanisms for plugin operations
- Plugin can block main thread indefinitely

### 3.5 Communication & Events

**Missing Infrastructure:**
- No event bus for plugin-to-plugin communication
- No pub/sub system
- No plugin dependency resolution
- No service registry for plugin-provided services

### 3.6 Discovery & Registry

**Limited Discovery:**
- Only filesystem scanning in single directory
- No plugin manifest files
- No centralized registry
- No plugin metadata beyond embedded PluginInfo
- No plugin search/filtering by capabilities

---

## 4. Proposed Architecture Improvements

### 4.1 Unified Plugin System

**Action:** Consolidate to single implementation
- **Keep:** `plugins/` implementation (more mature)
- **Remove:** `application/services/plugins/` (legacy)
- **Migrate:** Any unique features from legacy to new implementation

### 4.2 Enhanced Plugin Manifest

**New file: `plugin.manifest.zig`**
```zig
pub const Manifest = struct {
    // Identity
    id: []const u8,              // Unique identifier (reverse DNS)
    name: []const u8,
    version: SemanticVersion,    // Major.Minor.Patch
    author: []const u8,
    license: []const u8,
    homepage: ?[]const u8,
    
    // Compatibility
    api_version: u32,
    zig_version_min: []const u8,
    zig_version_max: ?[]const u8,
    host_version_min: ?[]const u8,
    
    // Dependencies
    dependencies: []PluginDependency,
    conflicts: [][]const u8,
    
    // Capabilities & Permissions
    capabilities: PluginCapabilities,
    required_permissions: []Permission,
    
    // Resources
    max_memory_mb: ?u32,
    max_threads: ?u32,
    
    // Security
    checksum_sha256: [32]u8,
    signature: ?[]const u8,
};
```

### 4.3 Security Features

#### 4.3.1 Plugin Verification
```zig
pub const PluginVerifier = struct {
    /// Verify plugin binary integrity
    pub fn verifyChecksum(path: []const u8, expected: [32]u8) !void;
    
    /// Verify plugin signature (if available)
    pub fn verifySignature(path: []const u8, signature: []const u8, pubkey: []const u8) !void;
    
    /// Check plugin against security policy
    pub fn checkPolicy(manifest: Manifest, policy: SecurityPolicy) !void;
};
```

#### 4.3.2 Permission System
```zig
pub const Permission = enum {
    filesystem_read,      // Read filesystem
    filesystem_write,     // Write filesystem
    network_client,       // Outbound network
    network_server,       // Listen on ports
    database_read,        // Read database
    database_write,       // Write database
    execute_commands,     // Execute system commands
    access_env,          // Access environment variables
    
    // Fine-grained permissions
    http_register_routes,
    event_publish,
    event_subscribe,
};

pub const SecurityPolicy = struct {
    allowed_permissions: []const Permission,
    denied_permissions: []const Permission,
    require_signature: bool,
    max_plugin_memory_mb: u32,
    sandbox_enabled: bool,
};
```

#### 4.3.3 Sandboxing Strategy

**Option 1: Process Isolation (Recommended for Security)**
- Run each plugin in separate process
- IPC via shared memory or sockets
- Process can be killed without affecting host
- Resource limits via OS (cgroups on Linux)
- **Tradeoff:** Higher overhead, more complex

**Option 2: Capability-Based Runtime Checks**
- Keep in-process loading
- Wrap dangerous APIs with permission checks
- Use Zig's `@panic` to catch violations
- **Tradeoff:** Less secure, but simpler and faster

**Recommendation:** Hybrid approach
- Default: In-process with capability checks
- Optional: Process isolation for untrusted plugins (flag: `isolated = true`)

### 4.4 Memory Safety Improvements

#### 4.4.1 Plugin Allocator Pattern
```zig
// New approach: Host provides arena allocator to plugin
pub const PluginContext = struct {
    arena: std.heap.ArenaAllocator,  // Owned by host, reset on reload
    config: ?*anyopaque,
    logger: *Logger,
    event_bus: *EventBus,
    service_registry: *ServiceRegistry,
};

// Updated plugin init signature
pub fn plugin_init(ctx: *PluginContext) !*anyopaque;
```

**Benefits:**
- Host controls memory lifecycle
- Easy cleanup (deinit arena)
- No cross-boundary allocation issues
- Plugins can use dynamic memory safely

#### 4.4.2 Resource Tracking
```zig
pub const ResourceTracker = struct {
    memory_used: std.atomic.Value(usize),
    max_memory: usize,
    file_handles: std.atomic.Value(u32),
    max_file_handles: u32,
    
    pub fn allocate(self: *ResourceTracker, size: usize) !void {
        const current = self.memory_used.fetchAdd(size, .monotonic);
        if (current + size > self.max_memory) {
            return error.PluginMemoryLimitExceeded;
        }
    }
};
```

### 4.5 Plugin Registry & Discovery

```zig
pub const PluginRegistry = struct {
    plugins: std.StringHashMap(PluginEntry),
    by_capability: std.AutoHashMap(PluginCapability, [][]const u8),
    
    pub const PluginEntry = struct {
        manifest: Manifest,
        path: []const u8,
        loaded: bool,
        handle: ?*LoadedPlugin,
    };
    
    /// Scan directory and register plugins
    pub fn discoverPlugins(self: *PluginRegistry, dir: []const u8) !usize;
    
    /// Find plugins by capability
    pub fn findByCapability(self: *PluginRegistry, cap: PluginCapability) ![][]const u8;
    
    /// Check plugin compatibility
    pub fn checkCompatibility(self: *PluginRegistry, id: []const u8) !bool;
};
```

### 4.6 Event System for Plugin Communication

```zig
pub const EventBus = struct {
    subscribers: std.StringHashMap(std.ArrayList(EventHandler)),
    mutex: std.Thread.Mutex,
    
    pub const EventHandler = struct {
        plugin_id: []const u8,
        callback: *const fn (event: Event) void,
    };
    
    pub const Event = struct {
        type: []const u8,
        source: []const u8,
        data: ?*anyopaque,
        timestamp: i64,
    };
    
    /// Subscribe to events
    pub fn subscribe(self: *EventBus, event_type: []const u8, handler: EventHandler) !void;
    
    /// Publish event
    pub fn publish(self: *EventBus, event: Event) !void;
    
    /// Unsubscribe
    pub fn unsubscribe(self: *EventBus, event_type: []const u8, plugin_id: []const u8) !void;
};
```

### 4.7 Dependency Resolution

```zig
pub const PluginDependency = struct {
    id: []const u8,
    version_constraint: []const u8,  // e.g., ">=1.0.0,<2.0.0"
    optional: bool,
};

pub const DependencyResolver = struct {
    registry: *PluginRegistry,
    
    /// Check if dependencies are satisfied
    pub fn checkDependencies(self: *DependencyResolver, manifest: Manifest) !void;
    
    /// Get load order based on dependencies
    pub fn resolveLoadOrder(self: *DependencyResolver, plugins: []Manifest) ![][]const u8;
    
    /// Detect circular dependencies
    pub fn detectCycles(self: *DependencyResolver, plugins: []Manifest) !bool;
};
```

### 4.8 Hot Reload Safety

**Current Issues:**
- No state migration on reload
- No graceful shutdown guarantee
- Race conditions during reload

**Improved Hot Reload:**
```zig
pub fn reloadPluginSafe(self: *PluginManager, name: []const u8) !void {
    const plugin = self.plugins.getPtr(name) orelse return PluginError.NotLoaded;
    
    // 1. Save state snapshot (if plugin supports it)
    var state_backup: ?[]u8 = null;
    if (plugin.vtable.save_state) |save_fn| {
        state_backup = try save_fn(plugin.plugin_handle);
    }
    defer if (state_backup) |backup| self.allocator.free(backup);
    
    // 2. Graceful stop with timeout
    const stop_result = try self.stopPluginWithTimeout(name, 5000); // 5s timeout
    if (!stop_result) {
        return PluginError.StopTimeout;
    }
    
    // 3. Unload old version
    try self.unloadPluginInternal(plugin);
    
    // 4. Load new version
    const new_plugin = try self.loadPlugin(name);
    
    // 5. Restore state (if available)
    if (state_backup) |backup| {
        if (new_plugin.vtable.restore_state) |restore_fn| {
            try restore_fn(new_plugin.plugin_handle, backup);
        }
    }
    
    // 6. Restart
    try self.startPlugin(name);
}
```

### 4.9 Error Recovery & Crash Handling

```zig
pub const PluginGuard = struct {
    plugin_name: []const u8,
    manager: *PluginManager,
    
    /// Execute plugin function with error recovery
    pub fn callSafe(self: *PluginGuard, comptime func: anytype, args: anytype) !void {
        // Set up crash handler (platform-specific)
        const original_handler = try self.installCrashHandler();
        defer self.restoreCrashHandler(original_handler);
        
        // Execute with timeout
        const result = try self.executeWithTimeout(func, args, 10000); // 10s
        
        if (!result) {
            // Plugin timed out or crashed
            try self.manager.handlePluginFailure(self.plugin_name);
            return error.PluginTimeout;
        }
    }
};
```

---

## 5. Implementation Plan

### Phase 1: Consolidation & Cleanup
1. Audit both implementations, document unique features
2. Merge unique features from legacy to modern implementation
3. Remove `application/services/plugins/` directory
4. Update all references to use `plugins/` implementation
5. Add comprehensive tests for existing functionality

### Phase 2: Security Foundations
1. Implement plugin manifest system
2. Add checksum verification to load process
3. Implement basic permission system
4. Add security policy enforcement
5. Create plugin verification API

### Phase 3: Memory Safety & Resource Management
1. Refactor plugin context to include arena allocator
2. Implement resource tracking (memory, handles, threads)
3. Add resource limit enforcement
4. Update plugin template and examples

### Phase 4: Registry & Discovery
1. Implement PluginRegistry
2. Add manifest-based plugin discovery
3. Implement capability-based querying
4. Add plugin metadata caching

### Phase 5: Communication & Dependencies
1. Implement EventBus for plugin communication
2. Add dependency declaration support
3. Implement DependencyResolver
4. Add load order calculation based on dependencies

### Phase 6: Advanced Features
1. Implement safe hot reload with state migration
2. Add plugin isolation mode (process-based)
3. Implement crash recovery mechanisms
4. Add plugin performance monitoring
5. Create plugin marketplace/registry protocol

---

## 6. API Changes & Migration

### 6.1 Breaking Changes

**Plugin Interface:**
- `plugin_init()` signature changes to accept `PluginContext*`
- Must provide `plugin.manifest.zig` file
- Must declare permissions in manifest

**Host API:**
- `PluginManager.init()` now requires `SecurityPolicy`
- `loadPlugin()` now validates manifest and permissions
- New required method: `checkPermission()` before privileged operations

### 6.2 Migration Guide for Plugin Developers

**Before:**
```zig
var g_data: PluginData = .{};

pub fn plugin_init() ?*anyopaque {
    return @ptrCast(&g_data);
}
```

**After:**
```zig
pub fn plugin_init(ctx: *PluginContext) !*anyopaque {
    const data = try ctx.arena.allocator().create(PluginData);
    data.* = .{};
    return @ptrCast(data);
}

// New file: plugin.manifest.zig
pub const manifest = Manifest{
    .id = "com.example.myplugin",
    .name = "MyPlugin",
    .version = .{ .major = 1, .minor = 0, .patch = 0 },
    .required_permissions = &[_]Permission{.http_register_routes},
    // ...
};
```

---

## 7. Testing Strategy

### 7.1 Unit Tests
- Plugin lifecycle state transitions
- Capability bitmap operations
- Permission checking logic
- Dependency resolution algorithm
- Event bus pub/sub correctness

### 7.2 Integration Tests
- Load/unload real plugin binaries
- Hot reload scenarios
- Multi-plugin communication via events
- Resource limit enforcement
- Crash recovery

### 7.3 Security Tests
- Malicious plugin detection
- Permission violation handling
- Resource exhaustion attacks
- Signature verification bypass attempts

### 7.4 Property-Based Tests
- Plugin load/unload order invariants
- State machine property verification
- Memory leak detection (repeated load/unload cycles)

---

## 8. Documentation Requirements

### 8.1 Plugin Developer Guide
- Plugin structure and manifest
- Lifecycle hooks explanation
- Permission model
- Event system usage
- Best practices for memory safety
- Testing plugins

### 8.2 API Reference
- All public interfaces documented
- Example code for common patterns
- Migration guide from old to new API

### 8.3 Security Guide
- Threat model
- Security policy configuration
- Signature generation and verification
- Sandboxing options

---

## 9. Source Code Changes

### 9.1 Files to Create
- `plugins/plugin_manifest.zig` - Manifest structure
- `plugins/plugin_verifier.zig` - Security verification
- `plugins/plugin_registry.zig` - Registry and discovery
- `plugins/event_bus.zig` - Event system
- `plugins/dependency_resolver.zig` - Dependency management
- `plugins/resource_tracker.zig` - Resource monitoring
- `plugins/security_policy.zig` - Permission system
- `plugins/templates/plugin.manifest.template` - Manifest template

### 9.2 Files to Modify
- `plugins/plugin_interface.zig` - Add PluginContext, update signatures
- `plugins/plugin_manager.zig` - Integrate new features
- `plugins/mod.zig` - Export new APIs
- `plugins/example_plugin.zig` - Update to new API
- `build.zig` - Add plugin compilation targets
- `commands/plugin_gen/main.zig` - Generate manifest files

### 9.3 Files to Remove
- `application/services/plugins/plugin_manager.zig`
- `application/services/plugins/plugin_interface.zig`
- `application/services/plugins/plugin_system.zig`

---

## 10. Verification Approach

### 10.1 Functional Verification
1. **Build:** `zig build`
2. **Unit Tests:** `zig build test-unit`
3. **Integration Tests:** `zig build test-integration` (create new test suite)
4. **Example Plugin:** Build and load example_plugin successfully
5. **Hot Reload:** Test plugin reload without crashes
6. **Multi-Plugin:** Load 3+ plugins simultaneously

### 10.2 Security Verification
1. **Checksum:** Verify modified plugin binary is rejected
2. **Permissions:** Verify plugin without permission cannot access protected APIs
3. **Resource Limits:** Verify plugin hitting memory limit is stopped
4. **Malicious Code:** Test with intentionally crashing plugin (isolation)

### 10.3 Memory Safety Verification
1. **Valgrind/ASan:** Run with memory sanitizers (if available)
2. **Leak Detection:** Load/unload plugins 1000 times, check RSS
3. **Boundary Testing:** Verify no cross-boundary heap access

---

## 11. Performance Considerations

### 11.1 Expected Overhead
- Plugin loading: +5-10ms for verification
- Permission checks: <1μs per check (bitmap lookup)
- Event publishing: ~10μs per event (depends on subscriber count)
- Resource tracking: +2-5% memory overhead

### 11.2 Optimization Opportunities
- Cache verified plugin checksums
- Use arena allocators for temporary data
- Lazy-load plugin capabilities
- Parallel plugin initialization (if no dependencies)

---

## 12. Known Limitations

### 12.1 Current Limitations
- No WASM plugin support (only native .so/.dylib/.dll)
- No plugin versioning/rollback
- No plugin marketplace integration
- Limited to single host process
- No distributed plugin system

### 12.2 Future Enhancements
- WASM plugin runtime for enhanced security
- Plugin version history and rollback
- Remote plugin repository protocol
- Multi-process plugin coordination
- Language-agnostic plugin protocol (gRPC/msgpack)

---

## 13. Risk Assessment

### 13.1 High Risks
- **ABI Stability:** Zig doesn't guarantee ABI stability between versions
  - *Mitigation:* Strict version matching, rebuild plugins on Zig upgrade
  
- **Security:** Process-shared plugins can still exploit host
  - *Mitigation:* Implement process isolation for untrusted plugins

- **Memory Corruption:** Cross-boundary pointer bugs
  - *Mitigation:* Use `*anyopaque` carefully, validate all pointers

### 13.2 Medium Risks
- **Performance:** Permission checks add overhead
  - *Mitigation:* Cache permission lookups, optimize hot paths

- **Complexity:** System becoming too complex
  - *Mitigation:* Maintain clear layering, comprehensive docs

### 13.3 Low Risks
- **Dependency Hell:** Complex dependency graphs
  - *Mitigation:* Encourage minimal dependencies, detect cycles

---

## 14. Success Criteria

### 14.1 Must Have
- ✅ Single, unified plugin implementation
- ✅ Manifest-based plugin metadata
- ✅ Basic security (checksum verification, permissions)
- ✅ Memory-safe plugin context with arena allocators
- ✅ Event bus for plugin communication
- ✅ Dependency resolution
- ✅ Hot reload support
- ✅ Comprehensive tests (>80% coverage)

### 14.2 Should Have
- ✅ Plugin registry and discovery
- ✅ Resource tracking and limits
- ✅ Crash recovery mechanisms
- ✅ Plugin developer documentation
- ✅ Migration guide

### 14.3 Nice to Have
- ⚪ Process isolation mode
- ⚪ Plugin marketplace protocol
- ⚪ Performance monitoring dashboard
- ⚪ Plugin debugging tools

---

## 15. Timeline Estimate

- **Phase 1 (Consolidation):** 2-3 days
- **Phase 2 (Security):** 3-4 days
- **Phase 3 (Memory Safety):** 2-3 days
- **Phase 4 (Registry):** 2 days
- **Phase 5 (Communication):** 3-4 days
- **Phase 6 (Advanced):** 5-7 days
- **Testing & Documentation:** 3-4 days

**Total:** ~20-30 days (assuming full-time work)

---

## 16. Conclusion

The current ZigCMS plugin system provides a solid foundation but requires significant enhancements to be production-ready, secure, and developer-friendly. The proposed improvements address critical gaps in security, memory safety, plugin communication, and developer experience.

The unified architecture with manifest-based plugins, permission systems, event bus, and dependency resolution will create a robust, extensible platform for third-party extensions while maintaining the memory safety and performance characteristics expected of Zig applications.

**Recommendation:** Proceed with phased implementation, prioritizing security and memory safety (Phases 1-3) before advanced features.

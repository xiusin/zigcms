/// MCP 工具层模块
pub const project_structure = @import("project_structure.zig");
pub const file_search = @import("file_search.zig");
pub const file_read = @import("file_read.zig");
pub const code_generator = @import("code_generator.zig");
pub const model_generator = @import("model_generator.zig");
pub const migration_generator = @import("migration_generator.zig");
pub const test_generator = @import("test_generator.zig");
pub const knowledge_base = @import("knowledge_base.zig");
pub const database = @import("database.zig");
pub const cache = @import("cache.zig");

pub const ProjectStructureTool = project_structure.ProjectStructureTool;
pub const FileSearchTool = file_search.FileSearchTool;
pub const FileReadTool = file_read.FileReadTool;
pub const CrudGeneratorTool = code_generator.CrudGeneratorTool;
pub const ModelGeneratorTool = model_generator.ModelGeneratorTool;
pub const MigrationGeneratorTool = migration_generator.MigrationGeneratorTool;
pub const TestGeneratorTool = test_generator.TestGeneratorTool;
pub const KnowledgeBaseTool = knowledge_base.KnowledgeBaseTool;
pub const DatabaseTool = database.DatabaseTool;
pub const CacheTool = cache.CacheTool;

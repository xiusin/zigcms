const std = @import("std");

pub const ConfigGenerator = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ConfigGenerator {
        return .{ .allocator = allocator };
    }

    /// Parse the .env file and generate configuration structure
    pub fn parseEnvAndGenerateConfig(self: *ConfigGenerator, env_file_path: []const u8, output_file_path: []const u8) !void {
        std.debug.print("Parsing .env file: {s}\\n", .{env_file_path});

        const env_content = try std.fs.cwd().readFileAlloc(self.allocator, env_file_path, 10 * 1024);
        defer self.allocator.free(env_content);

        // Parse the environment variables
        const parsed_config = try self.parseEnvContent(env_content);

        // Generate the Zig config struct
        const config_code = try self.generateConfigStruct(parsed_config);

        // Write to output file
        try std.fs.cwd().writeFile(output_file_path, config_code);

        std.debug.print("Configuration structure generated successfully to: {s}\\n", .{output_file_path});
    }

    /// Parse environment content into sections and variables
    pub fn parseEnvContent(self: *ConfigGenerator, content: []const u8) !ParsedConfig {
        var result = ParsedConfig.init(self.allocator);
        defer result.deinit();

        var current_section: ?[]const u8 = null;
        var current_subconfig: std.StringHashMap(ConfigVariable) = std.StringHashMap(ConfigVariable).init(self.allocator);
        defer current_subconfig.deinit();

        var lines = std.mem.tokenizeScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed_line = std.mem.trim(u8, line, " \t\r\n");

            // Skip empty lines
            if (trimmed_line.len == 0) {
                continue;
            }

            // Check for section markers (comments starting with # SECTION:)
            if (std.mem.startsWith(u8, trimmed_line, "# SECTION:")) {
                // Save previous section if exists
                if (current_section) |section_name| {
                    try result.sections.put(section_name, try current_subconfig.clone());
                }

                // Start new section
                const section_start = std.mem.indexOfScalar(u8, trimmed_line, ':') orelse continue;
                const section_name = std.mem.trim(u8, trimmed_line[section_start + 1 ..], " \t");
                current_section = try self.allocator.dupe(u8, section_name);

                // Clear the current subconfig for the new section
                current_subconfig.deinit();
                current_subconfig = std.StringHashMap(ConfigVariable).init(self.allocator);
            }
            // Skip comments that don't start with # SECTION:
            else if (std.mem.startsWith(u8, trimmed_line, "#")) {
                continue;
            }
            // Regular variable assignment
            else if (std.mem.indexOfScalar(u8, trimmed_line, '=')) |eq_idx| {
                const key = std.mem.trim(u8, trimmed_line[0..eq_idx], " \\t");
                const value = std.mem.trim(u8, trimmed_line[eq_idx + 1 ..], " \\t");

                // Remove quotes if present
                var cleaned_value = value;
                if ((std.mem.startsWith(u8, value, "\\") and std.mem.endsWith(u8, value, "\\")) or
                    (std.mem.startsWith(u8, value, "'") and std.mem.endsWith(u8, value, "'")))
                {
                    cleaned_value = value[1 .. value.len - 1];
                }

                const config_var = ConfigVariable{
                    .key = try self.allocator.dupe(u8, key),
                    .value = try self.allocator.dupe(u8, cleaned_value),
                    .type_hint = try self.inferType(cleaned_value),
                };

                // If we're in a section, add to the current subsection
                if (current_section != null) {
                    try current_subconfig.put(key, config_var);
                } else {
                    // If no section, add to the root level
                    try result.variables.put(key, config_var);
                }
            }
        }

        // Save the last section if it exists
        if (current_section) |section_name| {
            try result.sections.put(section_name, try current_subconfig.clone());
        }

        return result;
    }

    /// Infer the Zig type based on the value
    fn inferType(_: *ConfigGenerator, value: []const u8) ![]const u8 {
        // Check if it looks like a number (can be converted to int or float)
        if (std.fmt.parseInt(i64, value, 10)) |_| {
            return "i32";
        } else |_| {
            // Check if it's a boolean-like value
            if (std.ascii.eqlIgnoreCase(value, "true") or std.ascii.eqlIgnoreCase(value, "false")) {
                return "bool";
            } else {
                // Default to string
                return "[]const u8";
            }
        }
    }

    /// Generate the Zig configuration structure code
    fn generateConfigStruct(self: *ConfigGenerator, parsed_config: ParsedConfig) ![]const u8 {
        var writer = try std.ArrayList(u8).initCapacity(self.allocator, 0);
        defer writer.deinit(self.allocator);

        try writer.appendSlice(self.allocator,
            \\\\//! Auto-generated configuration structure from .env file
            \\\\
            \\\\const std = @import("std");
            \\\\
        );

        // Generate sub-configuration structs for sections
        var sections_it = parsed_config.sections.iterator();
        while (sections_it.next()) |entry| {
            const section_name = entry.key_ptr.*;
            const section_vars = entry.value_ptr.*;

            try writer.appendSlice(self.allocator, "\\n/// Configuration for ");
            try writer.appendSlice(self.allocator, section_name);
            try writer.appendSlice(self.allocator, "\\npub const ");
            try writer.appendSlice(self.allocator, toPascalCase(self.allocator, section_name) catch "Section");
            try writer.appendSlice(self.allocator, " = struct {\\n");

            var vars_it = section_vars.iterator();
            while (vars_it.next()) |var_entry| {
                const var_name = var_entry.key_ptr.*;
                const var_info = var_entry.value_ptr.*;

                try writer.appendSlice(self.allocator, "    /// ");
                try writer.appendSlice(self.allocator, var_name);
                try writer.appendSlice(self.allocator, ": ");
                try writer.appendSlice(self.allocator, var_info.value);
                try writer.appendSlice(self.allocator, "\\n    pub const ");
                try writer.appendSlice(self.allocator, toSnakeCaseUpper(self.allocator, var_name) catch var_name);
                try writer.appendSlice(self.allocator, ": ");
                try writer.appendSlice(self.allocator, var_info.type_hint);
                try writer.appendSlice(self.allocator, " = ");

                // Format the value according to its type
                if (std.mem.eql(u8, var_info.type_hint, "[]const u8")) {
                    try writer.appendSlice(self.allocator, "\\");
                    try writer.appendSlice(self.allocator, escapeString(self.allocator, var_info.value) catch var_info.value);
                    try writer.appendSlice(self.allocator, "\\");
                } else if (std.mem.eql(u8, var_info.type_hint, "bool")) {
                    if (std.ascii.eqlIgnoreCase(var_info.value, "true")) {
                        try writer.appendSlice(self.allocator, "true");
                    } else {
                        try writer.appendSlice(self.allocator, "false");
                    }
                } else {
                    try writer.appendSlice(self.allocator, var_info.value);
                }

                try writer.appendSlice(self.allocator, ";\\n\\n");
            }

            try writer.appendSlice(self.allocator, "};\\n");
        }

        // Generate the main Config struct
        try writer.appendSlice(self.allocator, "\\n/// Main configuration structure\\n");
        try writer.appendSlice(self.allocator, "pub const Config = struct {\\n");

        // Add section fields to main config
        sections_it = parsed_config.sections.iterator();
        while (sections_it.next()) |entry| {
            const section_name = entry.key_ptr.*;
            try writer.appendSlice(self.allocator, "    pub const ");
            try writer.appendSlice(self.allocator, toPascalCase(self.allocator, section_name) catch "Section");
            try writer.appendSlice(self.allocator, ": ");
            try writer.appendSlice(self.allocator, toPascalCase(self.allocator, section_name) catch "Section");
            try writer.appendSlice(self.allocator, " = .{};\\n");
        }

        // Add root level variables as fields
        var vars_it = parsed_config.variables.iterator();
        while (vars_it.next()) |var_entry| {
            const var_name = var_entry.key_ptr.*;
            const var_info = var_entry.value_ptr.*;

            try writer.appendSlice(self.allocator, "    /// ");
            try writer.appendSlice(self.allocator, var_name);
            try writer.appendSlice(self.allocator, ": ");
            try writer.appendSlice(self.allocator, var_info.value);
            try writer.appendSlice(self.allocator, "\\n    pub const ");
            try writer.appendSlice(self.allocator, toSnakeCaseUpper(self.allocator, var_name) catch var_name);
            try writer.appendSlice(self.allocator, ": ");
            try writer.appendSlice(self.allocator, var_info.type_hint);
            try writer.appendSlice(self.allocator, " = ");

            // Format the value according to its type
            if (std.mem.eql(u8, var_info.type_hint, "[]const u8")) {
                try writer.appendSlice(self.allocator, "\\");
                try writer.appendSlice(self.allocator, escapeString(self.allocator, var_info.value) catch var_info.value);
                try writer.appendSlice(self.allocator, "\\");
            } else if (std.mem.eql(u8, var_info.type_hint, "bool")) {
                if (std.ascii.eqlIgnoreCase(var_info.value, "true")) {
                    try writer.appendSlice(self.allocator, "true");
                } else {
                    try writer.appendSlice(self.allocator, "false");
                }
            } else {
                try writer.appendSlice(self.allocator, var_info.value);
            }

            try writer.appendSlice(self.allocator, ";\\n\\n");
        }

        try writer.appendSlice(self.allocator, "};\\n\\n");

        // Add utility functions
        try writer.appendSlice(self.allocator,
            \\\\/// Load configuration from environment variables at runtime
            \\\\pub fn loadFromEnvironment(allocator: std.mem.Allocator) !Config {
            \\\\    _ = allocator;
            \\\\    // This function can be expanded to load values from environment at runtime
            \\\\    return .{};
            \\\\}
            \\\\
        );

        return try writer.toOwnedSlice();
    }
};

// Helper function to convert a string to PascalCase
fn toPascalCase(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, 0);
    defer result.deinit(allocator);

    var capitalize_next = true;

    for (input) |c| {
        if (c == '_' or c == '-' or c == '.') {
            capitalize_next = true;
        } else if (std.ascii.isAlphabetic(c)) {
            if (capitalize_next) {
                try result.append(allocator, std.ascii.toUpper(c));
                capitalize_next = false;
            } else {
                try result.append(allocator, std.ascii.toLower(c));
            }
        } else if (std.ascii.isDigit(c)) {
            try result.append(allocator, c);
            capitalize_next = false;
        }
    }

    return try result.toOwnedSlice();
}

// Helper function to convert a string to SCREAMING_SNAKE_CASE
fn toSnakeCaseUpper(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, 0);
    defer result.deinit(allocator);

    for (input) |c| {
        if (std.ascii.isLower(c)) {
            try result.append(allocator, std.ascii.toUpper(c));
        } else if (std.ascii.isUpper(c) or std.ascii.isDigit(c)) {
            try result.append(allocator, c);
        } else if (c == '-' or c == '.') {
            try result.append(allocator, '_');
        } else {
            try result.append(allocator, c);
        }
    }

    return try result.toOwnedSlice();
}

// Helper function to escape special characters in strings
fn escapeString(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, 0);
    defer result.deinit(allocator);

    for (input) |c| {
        switch (c) {
            '"' => try result.appendSlice(allocator, "\\\\\\"),
            '\\' => try result.appendSlice(allocator, "\\\\\\\\"),
            '\n' => try result.appendSlice(allocator, "\\\\n"),
            '\r' => try result.appendSlice(allocator, "\\\\r"),
            '\t' => try result.appendSlice(allocator, "\\\\t"),
            else => try result.append(allocator, c),
        }
    }

    return try result.toOwnedSlice();
}

const ConfigVariable = struct {
    key: []const u8,
    value: []const u8,
    type_hint: []const u8,
};

const ParsedConfig = struct {
    allocator: std.mem.Allocator,
    variables: std.StringHashMap(ConfigVariable),
    sections: std.StringHashMap(std.StringHashMap(ConfigVariable)),

    fn init(allocator: std.mem.Allocator) ParsedConfig {
        return .{
            .allocator = allocator,
            .variables = std.StringHashMap(ConfigVariable).init(allocator),
            .sections = std.StringHashMap(std.StringHashMap(ConfigVariable)).init(allocator),
        };
    }

    fn deinit(self: *ParsedConfig) void {
        var vars_it = self.variables.iterator();
        while (vars_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*.key);
            self.allocator.free(entry.value_ptr.*.value);
        }
        self.variables.deinit();

        var sections_it = self.sections.iterator();
        while (sections_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);

            var section_vars_it = entry.value_ptr.iterator();
            while (section_vars_it.next()) |var_entry| {
                self.allocator.free(var_entry.key_ptr.*);
                self.allocator.free(var_entry.value_ptr.*.key);
                self.allocator.free(var_entry.value_ptr.*.value);
            }
            entry.value_ptr.deinit();
        }
        self.sections.deinit();
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip(); // skip program name

    const env_file_path = args.next() orelse "./.env";
    const output_file_path = args.next() orelse "./generated_config.zig";

    var generator = ConfigGenerator.init(allocator);
    try generator.parseEnvAndGenerateConfig(env_file_path, output_file_path);
}

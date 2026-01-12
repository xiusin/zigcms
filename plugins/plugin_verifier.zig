const std = @import("std");
const manifest = @import("plugin_manifest.zig");
const security_policy = @import("security_policy.zig");

pub const VerificationError = error{
    ChecksumMismatch,
    SignatureInvalid,
    FileNotFound,
    ReadError,
    PolicyViolation,
};

pub const PluginVerifier = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) PluginVerifier {
        return .{
            .allocator = allocator,
        };
    }

    pub fn verifyChecksum(self: *PluginVerifier, path: []const u8, expected: [32]u8) !void {
        _ = self;
        const file = std.fs.cwd().openFile(path, .{}) catch {
            return VerificationError.FileNotFound;
        };
        defer file.close();

        const content = file.readToEndAlloc(self.allocator, 100 * 1024 * 1024) catch {
            return VerificationError.ReadError;
        };
        defer self.allocator.free(content);

        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(content, &hash, .{});

        if (!std.mem.eql(u8, &hash, &expected)) {
            std.log.err("Checksum mismatch for {s}", .{path});
            std.log.err("Expected: {s}", .{std.fmt.fmtSliceHexLower(&expected)});
            std.log.err("Got:      {s}", .{std.fmt.fmtSliceHexLower(&hash)});
            return VerificationError.ChecksumMismatch;
        }

        std.log.info("Checksum verified for {s}", .{path});
    }

    pub fn calculateChecksum(self: *PluginVerifier, path: []const u8) ![32]u8 {
        const file = std.fs.cwd().openFile(path, .{}) catch {
            return VerificationError.FileNotFound;
        };
        defer file.close();

        const content = file.readToEndAlloc(self.allocator, 100 * 1024 * 1024) catch {
            return VerificationError.ReadError;
        };
        defer self.allocator.free(content);

        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(content, &hash, .{});

        return hash;
    }

    pub fn verifySignature(
        self: *PluginVerifier,
        path: []const u8,
        signature: []const u8,
        pubkey: []const u8,
    ) !void {
        _ = self;
        _ = path;
        _ = signature;
        _ = pubkey;

        std.log.warn("Signature verification not yet implemented", .{});
        return;
    }

    pub fn checkPolicy(
        self: *PluginVerifier,
        plugin_manifest: *const manifest.Manifest,
        policy: *const security_policy.SecurityPolicy,
    ) !void {
        _ = self;

        policy.checkManifest(plugin_manifest) catch |err| {
            return VerificationError.PolicyViolation;
        };

        std.log.info("Plugin {s} passed policy checks", .{plugin_manifest.name});
    }

    pub fn verifyAll(
        self: *PluginVerifier,
        path: []const u8,
        plugin_manifest: *const manifest.Manifest,
        policy: *const security_policy.SecurityPolicy,
    ) !void {
        if (plugin_manifest.checksum_sha256) |checksum| {
            try self.verifyChecksum(path, checksum);
        }

        if (policy.require_signature) {
            if (plugin_manifest.signature) |sig| {
                try self.verifySignature(path, sig, "");
            } else {
                std.log.err("Plugin {s} requires signature but manifest has none", .{plugin_manifest.name});
                return VerificationError.SignatureInvalid;
            }
        }

        try self.checkPolicy(plugin_manifest, policy);
    }
};

test "PluginVerifier checksum calculation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var verifier = PluginVerifier.init(allocator);

    const temp_file = "test_plugin_verify.tmp";
    {
        const file = try std.fs.cwd().createFile(temp_file, .{});
        defer file.close();
        try file.writeAll("test content");
    }
    defer std.fs.cwd().deleteFile(temp_file) catch {};

    const checksum = try verifier.calculateChecksum(temp_file);
    try std.testing.expect(checksum.len == 32);

    try verifier.verifyChecksum(temp_file, checksum);
}

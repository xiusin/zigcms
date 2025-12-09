const std = @import("std");
const Allocator = std.mem.Allocator;
const json = @import("../../application/services/json/json.zig").JSON;

pub const Algorithm = enum {
    HS256,
};

pub const EncodeOptions = struct {
    alg: Algorithm = .HS256,
};

pub const SecretOptions = struct {
    secret: []const u8,
};

pub fn encode(allocator: Allocator, options: EncodeOptions, payload: anytype, secret_opts: SecretOptions) ![]const u8 {
    _ = options; // Only HS256 supported for now

    // Header
    const header = .{ .alg = "HS256", .typ = "JWT" };
    const header_json = try json.encode(allocator, header);
    defer allocator.free(header_json);

    // Payload
    const payload_json = try json.encode(allocator, payload);
    defer allocator.free(payload_json);

    // Base64Url Encode
    const b64_header = try base64UrlEncode(allocator, header_json);
    defer allocator.free(b64_header);

    const b64_payload = try base64UrlEncode(allocator, payload_json);
    defer allocator.free(b64_payload);

    // Sign
    const data_to_sign = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ b64_header, b64_payload });
    defer allocator.free(data_to_sign);

    var mac: [std.crypto.auth.hmac.sha2.HmacSha256.mac_length]u8 = undefined;
    std.crypto.auth.hmac.sha2.HmacSha256.create(&mac, data_to_sign, secret_opts.secret);

    const b64_signature = try base64UrlEncode(allocator, &mac);
    defer allocator.free(b64_signature);

    return std.fmt.allocPrint(allocator, "{s}.{s}", .{ data_to_sign, b64_signature });
}

fn base64UrlEncode(allocator: Allocator, input: []const u8) ![]const u8 {
    const Encoder = std.base64.url_safe_no_pad.Encoder;
    const len = Encoder.calcSize(input.len);
    const output = try allocator.alloc(u8, len);
    _ = Encoder.encode(output, input);
    return output;
}

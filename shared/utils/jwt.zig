const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

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
    _ = options;

    const header = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}";

    // Serialize payload to JSON using std.json.fmt
    const payload_json = try std.fmt.allocPrint(allocator, "{f}", .{std.json.fmt(payload, .{})});
    defer allocator.free(payload_json);

    const b64_header = try base64UrlEncode(allocator, header);
    defer allocator.free(b64_header);

    const b64_payload = try base64UrlEncode(allocator, payload_json);
    defer allocator.free(b64_payload);

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
    const written = Encoder.encode(output, input);
    _ = written;
    return output;
}

fn base64UrlDecode(allocator: Allocator, input: []const u8) ![]const u8 {
    const Decoder = std.base64.url_safe_no_pad.Decoder;
    const len = (input.len * 3) / 4;
    const output = try allocator.alloc(u8, len);
    try Decoder.decode(output, input);
    return output[0..len];
}

pub const DecodeOptions = struct {
    secret: []const u8,
    verify_signature: bool = true,
};

pub const TokenPayload = struct {
    user_id: i32 = 0,
    username: []const u8 = "",
    email: []const u8 = "",
    exp: i64 = 0,
    iat: i64 = 0,
};

pub fn decode(allocator: Allocator, token: []const u8, options: DecodeOptions) !TokenPayload {
    var parts = std.mem.splitScalar(u8, token, '.');
    const header_b64 = parts.first();
    const payload_b64 = parts.rest();

    _ = parts.next();

    const payload_json = try base64UrlDecode(allocator, payload_b64);
    defer allocator.free(payload_json);

    var token_payload = TokenPayload{};

    if (std.mem.indexOf(u8, payload_json, "\"user_id\":")) |idx| {
        const start = idx + 9;
        var end = start;
        while (end < payload_json.len and payload_json[end] != ',' and payload_json[end] != '}') : (end += 1) {}
        const num_str = payload_json[start..end];
        token_payload.user_id = std.fmt.parseInt(i32, num_str, 10) catch 0;
    }

    if (std.mem.indexOf(u8, payload_json, "\"username\":\"")) |idx| {
        const start = idx + 12;
        var end = start;
        while (end < payload_json.len and !(payload_json[end] == '"' and (end + 1 < payload_json.len and payload_json[end + 1] == ',' or payload_json[end + 1] == '}'))) : (end += 1) {}
        token_payload.username = try allocator.dupe(u8, payload_json[start..end]);
    }

    if (std.mem.indexOf(u8, payload_json, "\"email\":\"")) |idx| {
        const start = idx + 9;
        var end = start;
        while (end < payload_json.len and !(payload_json[end] == '"' and (end + 1 < payload_json.len and payload_json[end + 1] == ',' or payload_json[end + 1] == '}'))) : (end += 1) {}
        token_payload.email = try allocator.dupe(u8, payload_json[start..end]);
    }

    if (options.verify_signature) {
        const data_to_sign = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ header_b64, payload_b64 });
        defer allocator.free(data_to_sign);

        var expected_mac: [std.crypto.auth.hmac.sha2.HmacSha256.mac_length]u8 = undefined;
        std.crypto.auth.hmac.sha2.HmacSha256.create(&expected_mac, data_to_sign, options.secret);

        var token_parts = std.mem.splitScalar(u8, token, '.');
        _ = token_parts.first();
        _ = token_parts.rest();
        const signature_b64 = token_parts.rest();

        const signature = try base64UrlDecode(allocator, signature_b64);
        defer allocator.free(signature);

        if (signature.len != expected_mac.len) {
            return error.InvalidSignature;
        }

        var equal = true;
        for (0..signature.len) |i| {
            if (signature[i] != expected_mac[i]) {
                equal = false;
            }
        }
        if (!equal) {
            return error.InvalidSignature;
        }
    }

    return token_payload;
}

test "jwt encode" {
    const allocator = std.testing.allocator;

    const payload = .{
        .user_id = @as(i32, 123),
        .username = "testuser",
        .email = "test@example.com",
    };

    const secret = "my-secret-key";

    const token = try encode(allocator, .{}, payload, .{ .secret = secret });
    defer allocator.free(token);

    try std.testing.expect(token.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, token, ".") != null);
}

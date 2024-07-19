const std = @import("std");
const zmpl = @import("zmpl");

pub fn start(allocator: std.mem.Allocator) !void {
    var data = zmpl.Data.init(allocator);
    defer data.deinit();

    var props = try data.object();
    try props.put("name", data.string("xiusin"));
    try props.put("age", data.integer(128));
    try props.put("email", data.string("826466266@qq.com"));
    try props.put("active", data.boolean(true));

    var body = try data.object();
    try body.put("person", props); // TODO 不能用?

    if (zmpl.find("hello")) | template | {
        const output = try template.render(&data);
        defer allocator.free(output);

        std.debug.print("{s}\n",.{output});
    }
}

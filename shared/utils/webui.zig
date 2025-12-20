const std = @import("std");
const webui = @import("webui");

const logger = std.log.scoped(.webui);

pub fn start() void {
    defer {
        logger.info("webui exit", .{});
        webui.clean();
    }
    var nwin = webui.newWindow();
    _ = nwin.show("https://star.xiusin.cn/");
    webui.wait();
}

const zap = @import("zap");

pub fn send_error(req: zap.Request, e: anyerror) void {
    req.sendError(e, if (@errorReturnTrace()) |t| t.* else null, 505);
}

const dz = @import("dart_zig");

pub fn logMessage(context: *dz.Context, message: dz.protocol.Text) !void {
    dz.logging.write(context.runtime, .info, "example", "{s}", .{message.bytes});
}

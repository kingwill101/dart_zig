const std = @import("std");
const codec = @import("codec.zig");
pub const route: u32 = 0xfffffff0;
pub const Level = enum(u8) { debug, info, warning, err };

/// Bounded, best-effort structured logging. Full queues increment log_drops.
/// Suitable as the target of an application's std_options.logFn adapter.
pub fn write(runtime: anytype, level: Level, scope: []const u8, comptime format: []const u8, args: anytype) void {
    var text: [2048]u8 = undefined;
    const message = std.fmt.bufPrint(&text, format, args) catch {
        _ = runtime.log_drops.fetchAdd(1, .monotonic);
        return;
    };
    var writer: codec.Writer = .{ .allocator = runtime.allocator, .max_bytes = 4096 };
    defer writer.deinit();
    encodeAndSend(runtime, &writer, level, scope, message) catch {
        _ = runtime.log_drops.fetchAdd(1, .monotonic);
    };
}
fn encodeAndSend(runtime: anytype, writer: *codec.Writer, level: Level, scope: []const u8, message: []const u8) !void {
    try writer.int(u8, @intFromEnum(level));
    try writer.string(scope);
    try writer.string(message);
    try runtime.trySignal(route, writer.bytes.items);
}

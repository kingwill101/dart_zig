const std = @import("std");
const Runtime = @import("runtime_web.zig").Runtime;
const codec = @import("codec.zig");
pub const Level = enum(u8) { debug, info, warning, err };
pub fn write(runtime: *Runtime, level: Level, scope: []const u8, comptime format: []const u8, args: anytype) void {
    var storage: [2048]u8 = undefined;
    const text = std.fmt.bufPrint(&storage, format, args) catch return;
    var writer: codec.Writer = .{ .allocator = std.heap.wasm_allocator, .max_bytes = 4096 };
    defer writer.deinit();
    writer.int(u8, @intFromEnum(level)) catch return;
    writer.string(scope) catch return;
    writer.string(text) catch return;
    runtime.trySignal(0xfffffff0, writer.bytes.items) catch {
        _ = runtime.log_drops.fetchAdd(1, .monotonic);
    };
}

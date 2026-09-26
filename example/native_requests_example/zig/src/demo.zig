//! A tiny server stand-in. Consumers replace this with their native runtime.
const std = @import("std");
const dz = @import("dart_zig");

pub fn cancel(bridge: *dz.Bridge, id: u64) bool {
    bridge.cancel(id) catch return false;
    return true;
}

const Producer = struct {
    bridge: *dz.Bridge,
    id: u64 = 0,
    fn run(self: *Producer) void {
        self.id = self.bridge.submit("GET /hello") catch 0;
    }
};

/// Uses a native thread to prove notifications do not require a Dart thread.
/// The thread is joined before returning; the reusable bridge owns no scheduler.
pub fn submit(bridge: *dz.Bridge) u64 {
    var producer: Producer = .{ .bridge = bridge };
    const thread = std.Thread.spawn(.{}, Producer.run, .{&producer}) catch return 0;
    thread.join();
    return producer.id;
}

/// Consumes a reply on the native side and verifies its ID, tag, and payload.
pub fn consume(bridge: *dz.Bridge, id: u64, kind: u8, bytes: [*]const u8, len: usize) bool {
    var packet = bridge.takeResponse() orelse return false;
    defer packet.deinit();
    return packet.id == id and @intFromEnum(packet.kind) == kind and std.mem.eql(u8, packet.bytes, bytes[0..len]);
}

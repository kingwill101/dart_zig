const dz = @import("dart_zig");

pub const events = .{
    .notifications = .{ .kind = dz.protocol.RouteKind.signal, .message = dz.protocol.Text },
    .updates = .{ .kind = dz.protocol.RouteKind.state, .message = dz.protocol.Text },
};

pub fn publish(context: *dz.Context, message: dz.protocol.Text) !void {
    try dz.events.emit(context, events, .notifications, message, &.{});
}

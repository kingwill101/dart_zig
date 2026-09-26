const dz = @import("dart_zig");

pub const MyMessage = struct {
    currentNumber: i32,
    otherBool: bool,
};

pub const events = .{
    .myMessage = .{
        .kind = dz.protocol.RouteKind.signal,
        .message = MyMessage,
    },
};

pub fn publish(context: *dz.Context, number: i32) !void {
    try dz.events.emit(context, events, .myMessage, MyMessage{
        .currentNumber = number,
        .otherBool = @mod(number, 2) != 0,
    }, &.{});
}

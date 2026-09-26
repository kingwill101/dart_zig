const dz = @import("dart_zig");

pub const AddRequest = struct { a: i64, b: i64 };
pub const AskRequest = struct { callbackId: u32, value: i64 };

pub const routes = .{
    .add = .{ .kind = dz.protocol.RouteKind.call, .request = AddRequest, .response = i64 },
    .askDart = .{ .kind = dz.protocol.RouteKind.call, .request = AskRequest, .response = i64 },
};

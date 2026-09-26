const dz = @import("dart_zig");

pub const AddCounterRequest = struct { handle: u64, delta: i64 };

pub const routes = .{
    .createCounter = .{ .kind = dz.protocol.RouteKind.call, .request = i64, .response = u64 },
    .addCounter = .{ .kind = dz.protocol.RouteKind.call, .request = AddCounterRequest, .response = i64 },
    .releaseCounter = .{ .kind = dz.protocol.RouteKind.call, .request = u64, .response = dz.protocol.Empty },
};

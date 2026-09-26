const dz = @import("dart_zig");

pub const AttachmentMessage = struct {
    label: dz.protocol.Text,
    tag: []const u8,
};

pub const events = .{
    .attachments = .{ .kind = dz.protocol.RouteKind.signal, .message = AttachmentMessage },
};

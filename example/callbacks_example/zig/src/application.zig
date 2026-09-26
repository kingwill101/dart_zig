const dz = @import("dart_zig");
const protocol = @import("protocol.zig");

pub fn dispatch(context: *dz.Context, kind: dz.frames.Kind, _: u32, bytes: []const u8) !void {
    switch (context.operation()) {
        dz.events.id(protocol.routes, .add) => {
            var reader: dz.codec.Reader = .{ .bytes = bytes };
            const request = try reader.decode(protocol.routes.add.request);
            try reader.finish();
            const sum = @addWithOverflow(request.a, request.b);
            if (sum[1] != 0) return error.Overflow;
            var writer: dz.codec.Writer = .{ .allocator = dz.allocator, .max_bytes = 8 };
            defer writer.deinit();
            try writer.encode(sum[0]);
            try context.complete(writer.bytes.items);
        },
        dz.events.id(protocol.routes, .askDart) => {
            var reader: dz.codec.Reader = .{ .bytes = bytes };
            if (kind == .callback_result) {
                _ = try reader.decode(protocol.routes.askDart.response);
                try reader.finish();
                try context.complete(bytes);
            } else {
                const request = try reader.decode(protocol.routes.askDart.request);
                try reader.finish();
                var writer: dz.codec.Writer = .{ .allocator = dz.allocator, .max_bytes = 8 };
                defer writer.deinit();
                try writer.encode(request.value);
                try context.callback(request.callbackId, writer.bytes.items);
            }
        },
        else => return error.UnknownOperation,
    }
}

const std = @import("std");
const wire = @import("dart_zig").protocol;

/// Describes wire types for the Dart endpoint generator.
pub fn write(writer: anytype, comptime T: type) !void {
    if (T == wire.Text) return writer.writeAll("{\"kind\":\"text\"}");
    if (T == wire.Empty) return writer.writeAll("{\"kind\":\"empty\"}");
    if (T == void) return writer.writeAll("{\"kind\":\"empty\"}");
    if (T == []const u8) return writer.writeAll("{\"kind\":\"bytes\"}");
    switch (@typeInfo(T)) {
        .int => |info| try writer.print("{{\"kind\":\"int\",\"bits\":{d},\"signed\":{s}}}", .{
            info.bits, if (info.signedness == .signed) "true" else "false",
        }),
        .bool => try writer.writeAll("{\"kind\":\"bool\"}"),
        .float => |info| try writer.print("{{\"kind\":\"float\",\"bits\":{d}}}", .{info.bits}),
        .@"struct" => |info| {
            if (info.is_tuple) @compileError("Tuple protocol values are unsupported");
            try writer.writeAll("{\"kind\":\"struct\",\"fields\":[");
            inline for (info.fields, 0..) |field, index| {
                if (index != 0) try writer.writeAll(",");
                try writer.print("{{\"name\":{f},\"type\":", .{std.json.fmt(field.name, .{})});
                try write(writer, field.type);
                try writer.writeAll("}");
            }
            try writer.writeAll("]}");
        },
        else => @compileError("Unsupported protocol type: " ++ @typeName(T)),
    }
}

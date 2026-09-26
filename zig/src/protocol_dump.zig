const std = @import("std");
const protocol = @import("protocol");
const type_dump = @import("type_dump.zig");
const dz = @import("dart_zig");

/// Emits route metadata from evaluated Zig declarations, never source text.
pub fn write(writer: anytype) !void {
    try writer.writeAll("{\"routes\":[");
    const routes = @typeInfo(@TypeOf(protocol.routes)).@"struct";
    inline for (routes.fields, 0..) |field, index| {
        if (index != 0) try writer.writeAll(",");
        const route = @field(protocol.routes, field.name);
        const kind: dz.protocol.RouteKind = route.kind;
        try writer.print("{{\"name\":{f},\"id\":{d},\"kind\":{f}", .{
            std.json.fmt(field.name, .{}), if (@hasField(@TypeOf(route), "id")) route.id else dz.handlers.routeId(field.name), std.json.fmt(@tagName(kind), .{}),
        });
        if (comptime kind == .signal or kind == .state) {
            try writer.writeAll(",\"message\":");
            try type_dump.write(writer, route.message);
        } else {
            try writer.writeAll(",\"request\":");
            try type_dump.write(writer, route.request);
            try writer.writeAll(",\"response\":");
            try type_dump.write(writer, route.response);
        }
        try writer.writeAll("}");
    }
    try writer.writeAll("]}\n");
}

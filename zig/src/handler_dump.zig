const std = @import("std");
const application = @import("handlers");
const dz = @import("dart_zig");
const type_dump = @import("type_dump.zig");

/// Emits the public handler signatures as Dart endpoint metadata.
pub fn write(writer: anytype) !void {
    try writer.writeAll("{\"routes\":[");
    var first = true;
    inline for (@typeInfo(application).@"struct".decls) |decl| {
        const handler = @field(application, decl.name);
        if (comptime @typeInfo(@TypeOf(handler)) == .@"fn") {
            if (!first) try writer.writeAll(",");
            first = false;
            const Handler = @TypeOf(handler);
            const streaming = comptime dz.handlers.isStream(Handler);
            if (comptime streaming and dz.handlers.hasBorrowedRequest(dz.handlers.requestType(Handler))) {
                @compileError("Stream requests cannot contain borrowed slices: " ++ decl.name);
            }
            try writer.print("{{\"name\":{f},\"id\":{d},\"kind\":{f},\"request\":", .{
                std.json.fmt(decl.name, .{}), dz.handlers.routeId(decl.name), std.json.fmt(if (streaming) "stream" else "call", .{}),
            });
            try type_dump.write(writer, dz.handlers.requestType(Handler));
            try writer.writeAll(",\"response\":");
            if (comptime streaming) {
                try type_dump.write(writer, dz.handlers.responseType(Handler).Item);
            } else {
                try type_dump.write(writer, dz.handlers.responseType(Handler));
            }
            try writer.writeAll("}");
        }
    }
    if (comptime @hasDecl(application, "events")) {
        const events = application.events;
        inline for (@typeInfo(@TypeOf(events)).@"struct".fields) |field| {
            const route = @field(events, field.name);
            const kind: dz.protocol.RouteKind = route.kind;
            if (comptime kind != .signal and kind != .state) @compileError("Typed handler events must be signal or state routes");
            if (!first) try writer.writeAll(",");
            first = false;
            try writer.print("{{\"name\":{f},\"id\":{d},\"kind\":{f},\"message\":", .{
                std.json.fmt(field.name, .{}), dz.events.nameId(events, field.name), std.json.fmt(@tagName(kind), .{}),
            });
            try type_dump.write(writer, route.message);
            try writer.writeAll("}");
        }
    }
    try writer.writeAll("]}\n");
}

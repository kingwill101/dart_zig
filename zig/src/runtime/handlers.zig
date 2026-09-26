const std = @import("std");
const codec = @import("codec.zig");
const frames = @import("frame.zig");
const protocol = @import("protocol.zig");
const events = @import("events.zig");
const route_id = @import("route_id.zig");

/// Stable route number derived from a public handler name.
pub fn routeId(comptime name: []const u8) u32 {
    return route_id.fromName(name);
}

pub fn requestType(comptime Handler: type) type {
    const info = @typeInfo(Handler).@"fn";
    if (info.params.len != 1 and info.params.len != 2) @compileError("A typed handler must accept a request, optionally preceded by *dz.Context");
    return info.params[info.params.len - 1].type orelse @compileError("Generic handler requests are unsupported");
}

pub fn responseType(comptime Handler: type) type {
    const info = @typeInfo(Handler).@"fn";
    const Return = info.return_type orelse @compileError("A typed handler must return an error union");
    return switch (@typeInfo(Return)) {
        .error_union => |result| result.payload,
        else => @compileError("A typed handler must return an error union"),
    };
}

pub fn isStream(comptime Handler: type) bool {
    const Response = responseType(Handler);
    return switch (@typeInfo(Response)) {
        .@"struct" => @hasDecl(Response, "Item") and @hasDecl(Response, "next"),
        else => false,
    };
}

/// A decoded slice points into the input frame, which is released after dispatch.
pub fn hasBorrowedRequest(comptime T: type) bool {
    if (T == protocol.Text or T == []const u8) return true;
    return switch (@typeInfo(T)) {
        .pointer => true,
        .@"struct" => |info| blk: {
            inline for (info.fields) |field| {
                if (hasBorrowedRequest(field.type)) break :blk true;
            }
            break :blk false;
        },
        else => false,
    };
}

/// Calls public functions in Api by their derived route ID.
pub fn dispatch(comptime Api: type, allocator: std.mem.Allocator, context: anytype, kind: frames.Kind, route: u32, bytes: []const u8) !void {
    inline for (@typeInfo(Api).@"struct".decls) |decl| {
        const handler = @field(Api, decl.name);
        if (comptime @typeInfo(@TypeOf(handler)) == .@"fn") {
            if (route == routeId(decl.name)) {
                const streaming = isStream(@TypeOf(handler));
                if (kind != (if (streaming) frames.Kind.stream_start else frames.Kind.call)) return error.InvalidOperationMode;
                try invoke(handler, allocator, context, bytes);
                return;
            }
        }
    }
    if (comptime @hasDecl(Api, "events")) {
        const declared = Api.events;
        inline for (@typeInfo(@TypeOf(declared)).@"struct".fields) |field| {
            const spec = @field(declared, field.name);
            const event_kind: protocol.RouteKind = spec.kind;
            if (comptime event_kind != .signal and event_kind != .state) @compileError("Typed handler events must be signal or state routes");
            if (route == events.nameId(declared, field.name)) {
                if (kind != .signal) return error.InvalidOperationMode;
                try events.relayRoute(context, spec, events.nameId(declared, field.name), bytes);
                return;
            }
        }
    }
    return error.UnknownOperation;
}

fn invoke(comptime handler: anytype, allocator: std.mem.Allocator, context: anytype, bytes: []const u8) !void {
    const Request = requestType(@TypeOf(handler));
    if (comptime isStream(@TypeOf(handler)) and hasBorrowedRequest(Request)) {
        @compileError("Stream requests cannot contain borrowed slices; use owned data before retaining a request");
    }
    var reader: codec.Reader = .{ .bytes = bytes };
    const request = try reader.decode(Request);
    try reader.finish();
    const result = if (comptime @typeInfo(@TypeOf(handler)).@"fn".params.len == 2) blk: {
        const ContextParam = @typeInfo(@TypeOf(handler)).@"fn".params[0].type orelse @compileError("Generic handler context is unsupported");
        if (ContextParam != @TypeOf(context)) @compileError("The first handler parameter must be *dz.Context");
        break :blk try handler(context, request);
    } else try handler(request);
    if (comptime isStream(@TypeOf(handler))) {
        const State = StreamState(@TypeOf(result), @TypeOf(context.*));
        const state = try allocator.create(State);
        state.* = .{ .allocator = allocator, .iterator = result };
        try context.deferStream(state, State.resumeStream, State.release);
    } else {
        var writer: codec.Writer = .{ .allocator = allocator, .max_bytes = context.runtime.output.max_bytes };
        defer writer.deinit();
        try writer.encode(result);
        try context.complete(writer.bytes.items);
    }
}

fn StreamState(comptime Iterator: type, comptime Context: type) type {
    if (!@hasDecl(Iterator, "Item") or !@hasDecl(Iterator, "next")) @compileError("A stream iterator needs Item and next");
    return struct {
        allocator: std.mem.Allocator,
        iterator: Iterator,

        fn release(pointer: *anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(pointer));
            if (comptime @hasDecl(Iterator, "deinit")) self.iterator.deinit();
            self.allocator.destroy(self);
        }

        fn resumeStream(context: *Context, pointer: *anyopaque) !void {
            const self: *@This() = @ptrCast(@alignCast(pointer));
            const item: ?Iterator.Item = try self.iterator.next();
            if (item) |value| {
                var writer: codec.Writer = .{ .allocator = self.allocator, .max_bytes = context.runtime.output.max_bytes };
                defer writer.deinit();
                try writer.encode(value);
                try context.item(writer.bytes.items);
            } else {
                try context.end();
            }
        }
    };
}

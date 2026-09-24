//! Optional Zig declarations -> portable schema.json frontend.
//! Invoke through tool/dart_zig.py schema --source authoring/messages.zig.
const std = @import("std");
const declarations = @import("declarations");
const allocator = std.heap.page_allocator;
const Value = std.json.Value;
fn object() Value {
    return .{ .object = if (@import("builtin").zig_version.minor >= 16) .{} else std.json.ObjectMap.init(allocator) };
}
fn put(value: *Value, key: []const u8, child: Value) !void {
    if (@import("builtin").zig_version.minor >= 16) {
        try value.object.put(allocator, key, child);
    } else {
        try value.object.put(key, child);
    }
}
fn string(value: []const u8) Value {
    return .{ .string = value };
}
fn wireName(comptime T: type) []const u8 {
    inline for (@typeInfo(@TypeOf(declarations.models)).@"struct".fields) |field| {
        if (T == @field(declarations.models, field.name)) return field.name;
    }
    return switch (@typeInfo(T)) {
        .int, .float, .bool, .void => @typeName(T),
        .optional => |info| wireName(info.child) ++ "?",
        .pointer => |info| if (info.size == .slice)
            (if (info.child == u8) "string" else wireName(info.child) ++ "[]")
        else
            @compileError("Schema fields cannot contain raw pointers"),
        else => @compileError("Use named models or schema aliases for " ++ @typeName(T)),
    };
}
pub fn main() !void {
    var parsed = try std.json.parseFromSlice(Value, allocator, declarations.metadata, .{});
    defer parsed.deinit();
    var root = parsed.value;
    var models = object();
    inline for (@typeInfo(@TypeOf(declarations.models)).@"struct".fields) |model| {
        const T = @field(declarations.models, model.name);
        var fields = object();
        inline for (@typeInfo(T).@"struct".fields) |field| {
            const key = model.name ++ "." ++ field.name;
            const name = if (@hasDecl(declarations, "field_types") and @hasField(@TypeOf(declarations.field_types), key))
                @field(declarations.field_types, key)
            else
                comptime wireName(field.type);
            try put(&fields, field.name, string(name));
        }
        try put(&models, model.name, fields);
    }
    try put(&root, "models", models);
    const output = try std.json.Stringify.valueAlloc(allocator, root, .{ .whitespace = .indent_2 });
    defer allocator.free(output);
    // std.debug.print is compatible with Zig 0.15/0.16; the CLI captures stderr.
    std.debug.print("{s}\n", .{output});
}

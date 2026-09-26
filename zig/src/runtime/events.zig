const std = @import("std");
const codec = @import("codec.zig");
const route_id = @import("route_id.zig");

/// Derives a stable route ID from an enum literal such as `.updates`.
/// Explicit IDs remain available for integrations that already have a protocol.
pub fn id(comptime routes: anytype, comptime name: anytype) u32 {
    return nameId(routes, @tagName(name));
}

pub fn nameId(comptime routes: anytype, comptime name: []const u8) u32 {
    const route = @field(routes, name);
    return if (@hasField(@TypeOf(route), "id")) route.id else route_id.fromName(name);
}

/// Emits a typed signal with a separately owned binary attachment.
pub fn emit(context: anytype, comptime routes: anytype, comptime name: anytype, message: @field(routes, @tagName(name)).message, binary: []const u8) !void {
    var metadata: codec.Writer = .{ .allocator = std.heap.page_allocator, .max_bytes = context.runtime.output.max_bytes };
    defer metadata.deinit();
    try metadata.encode(message);

    var envelope: codec.Writer = .{ .allocator = std.heap.page_allocator, .max_bytes = context.runtime.output.max_bytes };
    defer envelope.deinit();
    try envelope.blob(metadata.bytes.items);
    try envelope.blob(binary);
    try context.signal(id(routes, name), envelope.bytes.items);
}

/// Validates and forwards a Dart signal to its typed listeners.
pub fn relay(context: anytype, comptime routes: anytype, comptime name: anytype, bytes: []const u8) !void {
    const route = @field(routes, @tagName(name));
    try relayRoute(context, route, id(routes, name), bytes);
}

pub fn relayRoute(context: anytype, comptime route: anytype, route_id_value: u32, bytes: []const u8) !void {
    var envelope: codec.Reader = .{ .bytes = bytes };
    var metadata: codec.Reader = .{ .bytes = try envelope.blob() };
    _ = try metadata.decode(route.message);
    try metadata.finish();
    _ = try envelope.blob();
    try envelope.finish();
    try context.signal(route_id_value, bytes);
}

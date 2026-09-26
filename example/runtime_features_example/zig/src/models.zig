//! Application wire types and codecs for the feature example.
//! Keep these tags and field orders in sync with the application's Dart codecs.
const std = @import("std");
const codec = @import("dart_zig").codec;

const max_collection_length = 1_000_000;

pub const Operations = struct {
    pub const sum: u32 = 1;
    pub const publish: u32 = 2;
    pub const squares: u32 = 3;
    pub const counterCreate: u32 = 4;
    pub const counterAdd: u32 = 5;
    pub const counterDispose: u32 = 6;
    pub const transform: u32 = 7;
    pub const echo: u32 = 8;
    pub const roundTripRecord: u32 = 9;
    pub const roundTripValue: u32 = 10;
    pub const emitLog: u32 = 11;
    pub const roundTripRich: u32 = 12;
};

pub const Importance = enum(u32) { low, normal, high };
pub const Message = struct { text: []const u8, sequence: i64 };
pub const Record = struct {
    label: []const u8,
    tags: []const []const u8,
    score: ?f64,
    importance: Importance,
    data: []const u8,
    flags: []const bool,
};
pub const Score = struct { key: []const u8, value: i32 };
pub const RichValues = struct {
    scores: []const Score,
    labels: []const []const u8,
    coordinates: [3]f32,
    pair: std.meta.Tuple(&.{ []const u8, i128 }),
    huge: u128,
    small: i8,
    medium: u16,
};
pub const Value = union(enum(u32)) {
    text: []const u8,
    count: i64,
    data: []const u8,
};

fn collectionLength(reader: *codec.Reader) !usize {
    const count = try reader.int(u32);
    if (count > max_collection_length) return error.TooLarge;
    return count;
}

fn writeLength(writer: *codec.Writer, count: usize) !void {
    if (count > max_collection_length) return error.TooLarge;
    try writer.int(u32, @intCast(count));
}

pub fn encodeMessage(writer: *codec.Writer, message: Message) !void {
    try writer.string(message.text);
    try writer.int(i64, message.sequence);
}

pub fn decodeMessage(reader: *codec.Reader, _: std.mem.Allocator) !Message {
    return .{ .text = try reader.string(), .sequence = try reader.int(i64) };
}

pub fn encodeRecord(writer: *codec.Writer, record: Record) !void {
    try writer.string(record.label);
    try writeLength(writer, record.tags.len);
    for (record.tags) |tag| try writer.string(tag);
    try writer.boolean(record.score != null);
    if (record.score) |score| try writer.float(score);
    try writer.int(u32, @intFromEnum(record.importance));
    try writer.blob(record.data);
    try writeLength(writer, record.flags.len);
    for (record.flags) |flag| try writer.boolean(flag);
}

pub fn decodeRecord(reader: *codec.Reader, allocator: std.mem.Allocator) !Record {
    const label = try reader.string();
    const tags = try allocator.alloc([]const u8, try collectionLength(reader));
    for (tags) |*tag| tag.* = try reader.string();
    const score: ?f64 = if (try reader.boolean()) try reader.float() else null;
    const importance: Importance = switch (try reader.int(u32)) {
        0 => .low,
        1 => .normal,
        2 => .high,
        else => return error.InvalidTag,
    };
    const data = try reader.blob();
    const flags = try allocator.alloc(bool, try collectionLength(reader));
    for (flags) |*flag| flag.* = try reader.boolean();
    return .{
        .label = label,
        .tags = tags,
        .score = score,
        .importance = importance,
        .data = data,
        .flags = flags,
    };
}

pub fn encodeRichValues(writer: *codec.Writer, values: RichValues) !void {
    try writeLength(writer, values.scores.len);
    var score_keys: std.StringHashMapUnmanaged(void) = .{};
    defer score_keys.deinit(writer.allocator);
    for (values.scores) |entry| {
        if ((try score_keys.getOrPut(writer.allocator, entry.key)).found_existing) return error.DuplicateKey;
        try writer.string(entry.key);
        try writer.int(i32, entry.value);
    }
    try writeLength(writer, values.labels.len);
    var labels: std.StringHashMapUnmanaged(void) = .{};
    defer labels.deinit(writer.allocator);
    for (values.labels) |label| {
        if ((try labels.getOrPut(writer.allocator, label)).found_existing) return error.DuplicateElement;
        try writer.string(label);
    }
    for (values.coordinates) |coordinate| try writer.float32(coordinate);
    try writer.string(values.pair[0]);
    try writer.int(i128, values.pair[1]);
    try writer.int(u128, values.huge);
    try writer.int(i8, values.small);
    try writer.int(u16, values.medium);
}

pub fn decodeRichValues(reader: *codec.Reader, allocator: std.mem.Allocator) !RichValues {
    const scores = try allocator.alloc(Score, try collectionLength(reader));
    var score_keys: std.StringHashMapUnmanaged(void) = .{};
    defer score_keys.deinit(allocator);
    for (scores) |*entry| {
        entry.key = try reader.string();
        if ((try score_keys.getOrPut(allocator, entry.key)).found_existing) return error.DuplicateKey;
        entry.value = try reader.int(i32);
    }
    const labels = try allocator.alloc([]const u8, try collectionLength(reader));
    var seen_labels: std.StringHashMapUnmanaged(void) = .{};
    defer seen_labels.deinit(allocator);
    for (labels) |*label| {
        label.* = try reader.string();
        if ((try seen_labels.getOrPut(allocator, label.*)).found_existing) return error.DuplicateElement;
    }
    var coordinates: [3]f32 = undefined;
    for (&coordinates) |*coordinate| coordinate.* = try reader.float32();
    const pair: std.meta.Tuple(&.{ []const u8, i128 }) = .{
        try reader.string(),
        try reader.int(i128),
    };
    return .{
        .scores = scores,
        .labels = labels,
        .coordinates = coordinates,
        .pair = pair,
        .huge = try reader.int(u128),
        .small = try reader.int(i8),
        .medium = try reader.int(u16),
    };
}

pub fn encodeValue(writer: *codec.Writer, value: Value) !void {
    switch (value) {
        .text => |text| {
            try writer.int(u32, 0);
            try writer.string(text);
        },
        .count => |count| {
            try writer.int(u32, 1);
            try writer.int(i64, count);
        },
        .data => |data| {
            try writer.int(u32, 2);
            try writer.blob(data);
        },
    }
}

pub fn decodeValue(reader: *codec.Reader, _: std.mem.Allocator) !Value {
    return switch (try reader.int(u32)) {
        0 => .{ .text = try reader.string() },
        1 => .{ .count = try reader.int(i64) },
        2 => .{ .data = try reader.blob() },
        else => error.InvalidTag,
    };
}

pub fn emitUpdates(runtime: anytype, allocator: std.mem.Allocator, message: Message, binary: []const u8) !void {
    var metadata: codec.Writer = .{ .allocator = allocator, .max_bytes = 8 * 1024 * 1024 };
    defer metadata.deinit();
    try encodeMessage(&metadata, message);
    var envelope: codec.Writer = .{ .allocator = allocator, .max_bytes = 8 * 1024 * 1024 };
    defer envelope.deinit();
    try envelope.blob(metadata.bytes.items);
    try envelope.blob(binary);
    try runtime.trySignal(100, envelope.bytes.items);
}

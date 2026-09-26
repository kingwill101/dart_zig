const std = @import("std");
const protocol = @import("protocol.zig");

/// Explicit little-endian wire codec, independent of native struct layout.
pub const Writer = struct {
    allocator: std.mem.Allocator,
    bytes: std.ArrayList(u8) = .empty,
    max_bytes: usize,

    pub fn deinit(self: *Writer) void {
        self.bytes.deinit(self.allocator);
    }

    pub fn raw(self: *Writer, value: []const u8) !void {
        if (self.bytes.items.len > self.max_bytes or value.len > self.max_bytes - self.bytes.items.len) return error.TooLarge;
        try self.bytes.appendSlice(self.allocator, value);
    }

    pub fn int(self: *Writer, comptime T: type, value: T) !void {
        var bytes: [@sizeOf(T)]u8 = undefined;
        std.mem.writeInt(T, &bytes, value, .little);
        try self.raw(&bytes);
    }

    pub fn boolean(self: *Writer, value: bool) !void {
        try self.int(u8, @intFromBool(value));
    }
    pub fn float(self: *Writer, value: f64) !void {
        try self.int(u64, @bitCast(value));
    }

    pub fn float32(self: *Writer, value: f32) !void {
        try self.int(u32, @bitCast(value));
    }

    pub fn blob(self: *Writer, value: []const u8) !void {
        if (value.len > std.math.maxInt(u32)) return error.TooLarge;
        try self.int(u32, @intCast(value.len));
        try self.raw(value);
    }

    pub fn string(self: *Writer, value: []const u8) !void {
        if (!std.unicode.utf8ValidateSlice(value)) return error.InvalidUtf8;
        try self.blob(value);
    }

    /// Encodes a protocol value by walking its Zig fields in declaration order.
    pub fn encode(self: *Writer, input: anytype) !void {
        const T = @TypeOf(input);
        if (T == void) return;
        if (T == protocol.Text) return self.string(input.bytes);
        if (T == []const u8) return self.blob(input);
        switch (@typeInfo(T)) {
            .int => try self.int(T, input),
            .bool => try self.boolean(input),
            .float => switch (@bitSizeOf(T)) {
                32 => try self.float32(input),
                64 => try self.float(input),
                else => @compileError("Unsupported protocol float width"),
            },
            .@"struct" => |info| {
                if (info.is_tuple) @compileError("Tuple protocol values are unsupported");
                inline for (info.fields) |field| try self.encode(@field(input, field.name));
            },
            else => @compileError("Unsupported protocol value type: " ++ @typeName(T)),
        }
    }
};

/// Returned byte/string views borrow the input. Copy them before releasing it.
pub const Reader = struct {
    bytes: []const u8,
    offset: usize = 0,

    pub fn raw(self: *Reader, length: usize) ![]const u8 {
        if (length > self.bytes.len - self.offset) return error.Truncated;
        const result = self.bytes[self.offset..][0..length];
        self.offset += length;
        return result;
    }

    pub fn int(self: *Reader, comptime T: type) !T {
        const bytes = try self.raw(@sizeOf(T));
        return std.mem.readInt(T, bytes[0..@sizeOf(T)], .little);
    }

    pub fn boolean(self: *Reader) !bool {
        return switch (try self.int(u8)) {
            0 => false,
            1 => true,
            else => error.InvalidBoolean,
        };
    }
    pub fn float(self: *Reader) !f64 {
        return @bitCast(try self.int(u64));
    }
    pub fn float32(self: *Reader) !f32 {
        return @bitCast(try self.int(u32));
    }

    pub fn blob(self: *Reader) ![]const u8 {
        return self.raw(try self.int(u32));
    }
    pub fn string(self: *Reader) ![]const u8 {
        const value = try self.blob();
        if (!std.unicode.utf8ValidateSlice(value)) return error.InvalidUtf8;
        return value;
    }
    pub fn finish(self: *Reader) !void {
        if (self.offset != self.bytes.len) return error.TrailingBytes;
    }

    /// Decodes a protocol value using the same field order as [Writer.encode].
    pub fn decode(self: *Reader, comptime T: type) !T {
        if (T == protocol.Text) return .{ .bytes = try self.string() };
        if (T == []const u8) return try self.blob();
        return switch (@typeInfo(T)) {
            .int => try self.int(T),
            .bool => try self.boolean(),
            .float => switch (@bitSizeOf(T)) {
                32 => try self.float32(),
                64 => try self.float(),
                else => @compileError("Unsupported protocol float width"),
            },
            .@"struct" => |info| blk: {
                if (info.is_tuple) @compileError("Tuple protocol values are unsupported");
                if (info.fields.len == 0) break :blk .{};
                var result: T = undefined;
                inline for (info.fields) |field| {
                    @field(result, field.name) = try self.decode(field.type);
                }
                break :blk result;
            },
            else => @compileError("Unsupported protocol value type: " ++ @typeName(T)),
        };
    }
};

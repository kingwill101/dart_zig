const std = @import("std");
const Buffer = @import("buffer.zig").Buffer;

pub const protocol_version: u32 = 2;
pub const Kind = enum(u32) {
    call = 0,
    result = 1,
    signal = 2,
    stream_item = 3,
    stream_end = 4,
    failure = 5,
    cancel = 6,
    callback = 7,
    callback_result = 8,
    capacity = 9,
    stream_start = 10,
    resume_stream = 11,
};

/// A transport frame owns one Buffer reference, transferred on queue admission.
pub const Frame = struct {
    id: u64 = 0,
    route: u32 = 0,
    kind: Kind,
    code: u32 = 0,
    buffer: *Buffer,
    pub fn deinit(self: Frame) void {
        self.buffer.release();
    }
};

/// ABI descriptor returned in caller-allocated batches. Release its owner once.
pub const Descriptor = extern struct {
    id: u64,
    route: u32,
    kind: u32,
    code: u32,
    length: usize,
    data: [*]const u8,
    owner: *Buffer,
};

/// Fixed-capacity ring; synchronization belongs to the runtime.
pub const Queue = struct {
    slots: []Frame,
    head: usize = 0,
    count: usize = 0,
    bytes: usize = 0,
    max_bytes: usize,
    pub fn init(allocator: std.mem.Allocator, count: usize, max_bytes: usize) !Queue {
        if (count == 0 or max_bytes == 0) return error.InvalidLimits;
        return .{ .slots = try allocator.alloc(Frame, count), .max_bytes = max_bytes };
    }
    pub fn put(self: *Queue, frame: Frame) !void {
        const length = frame.buffer.bytes.len;
        if (length > self.max_bytes) return error.TooLarge;
        if (self.count == self.slots.len or length > self.max_bytes - self.bytes) return error.Full;
        self.slots[(self.head + self.count) % self.slots.len] = frame;
        self.count += 1;
        self.bytes += length;
    }
    pub fn take(self: *Queue) ?Frame {
        if (self.count == 0) return null;
        const frame = self.slots[self.head];
        self.head = (self.head + 1) % self.slots.len;
        self.count -= 1;
        self.bytes -= frame.buffer.bytes.len;
        return frame;
    }
    pub fn remove(self: *Queue, id: u64) void {
        const count = self.count;
        for (0..count) |_| {
            const frame = self.take().?;
            if (frame.id == id) frame.deinit() else self.put(frame) catch unreachable;
        }
    }
    pub fn deinit(self: *Queue, allocator: std.mem.Allocator) void {
        while (self.take()) |frame| frame.deinit();
        allocator.free(self.slots);
    }
};

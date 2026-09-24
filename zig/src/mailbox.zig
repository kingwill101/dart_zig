const std = @import("std");

pub const Kind = enum(u8) { request, chunk, end, failure, cancelled };

/// Owns its bytes until deinit. Taking a packet transfers ownership to the caller.
pub const Packet = struct {
    id: u64,
    kind: Kind,
    bytes: []u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Packet) void {
        self.allocator.free(self.bytes);
        self.* = undefined;
    }
};

/// Bounded FIFO; the owning bridge supplies synchronization.
pub const Mailbox = struct {
    allocator: std.mem.Allocator,
    slots: []?Packet,
    head: usize = 0,
    count: usize = 0,
    bytes: usize = 0,
    max_bytes: usize,

    pub fn init(allocator: std.mem.Allocator, capacity: usize, max_bytes: usize) !Mailbox {
        if (capacity == 0 or max_bytes == 0) return error.InvalidLimits;
        const slots = try allocator.alloc(?Packet, capacity);
        @memset(slots, null);
        return .{ .allocator = allocator, .slots = slots, .max_bytes = max_bytes };
    }

    /// Copies only after checking both limits; failure leaves the queue unchanged.
    pub fn put(self: *Mailbox, id: u64, kind: Kind, bytes: []const u8) !void {
        if (bytes.len > self.max_bytes) return error.TooLarge;
        if (self.count == self.slots.len or bytes.len > self.max_bytes - self.bytes) return error.Full;
        const copy = try self.allocator.dupe(u8, bytes);
        self.slots[(self.head + self.count) % self.slots.len] = .{
            .id = id,
            .kind = kind,
            .bytes = copy,
            .allocator = self.allocator,
        };
        self.count += 1;
        self.bytes += bytes.len;
    }

    pub fn take(self: *Mailbox) ?Packet {
        if (self.count == 0) return null;
        const packet = self.slots[self.head].?;
        self.slots[self.head] = null;
        self.head = (self.head + 1) % self.slots.len;
        self.count -= 1;
        self.bytes -= packet.bytes.len;
        return packet;
    }

    pub fn clear(self: *Mailbox) void {
        while (self.take()) |value| {
            var packet = value;
            packet.deinit();
        }
    }

    /// Removes cancelled work without allocating or changing other packets' order.
    pub fn remove(self: *Mailbox, id: u64) void {
        const count = self.count;
        for (0..count) |_| {
            var packet = self.take().?;
            if (packet.id == id) {
                packet.deinit();
            } else {
                self.slots[(self.head + self.count) % self.slots.len] = packet;
                self.count += 1;
                self.bytes += packet.bytes.len;
            }
        }
    }

    pub fn deinit(self: *Mailbox) void {
        self.clear();
        self.allocator.free(self.slots);
    }
};

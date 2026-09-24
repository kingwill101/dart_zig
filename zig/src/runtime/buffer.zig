const std = @import("std");
const Mutex = @import("../mutex.zig").Mutex;

/// Allocated storage, including reusable pool entries and buffers leased to Dart.
pub var live_buffers = std.atomic.Value(usize).init(0);
pub var live_bytes = std.atomic.Value(usize).init(0);

/// Reference-counted native bytes. Borrowed slices require a live owned reference.
pub const Buffer = struct {
    allocator: std.mem.Allocator,
    refs: std.atomic.Value(usize) = std.atomic.Value(usize).init(1),
    bytes: []u8,
    storage: []u8,
    pool: ?*Pool = null,

    pub fn create(allocator: std.mem.Allocator, length: usize) !*Buffer {
        const self = try allocator.create(Buffer);
        errdefer allocator.destroy(self);
        const storage = try allocator.alloc(u8, length);
        self.* = .{ .allocator = allocator, .bytes = storage, .storage = storage };
        _ = live_buffers.fetchAdd(1, .monotonic);
        _ = live_bytes.fetchAdd(length, .monotonic);
        return self;
    }
    pub fn copy(allocator: std.mem.Allocator, bytes: []const u8) !*Buffer {
        const self = try create(allocator, bytes.len);
        @memcpy(self.bytes, bytes);
        return self;
    }
    pub fn retain(self: *Buffer) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn release(self: *Buffer) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        if (self.pool) |pool| pool.recycle(self) else self.destroy();
    }
    fn destroy(self: *Buffer) void {
        const allocator = self.allocator;
        _ = live_buffers.fetchSub(1, .monotonic);
        _ = live_bytes.fetchSub(self.storage.len, .monotonic);
        allocator.free(self.storage);
        allocator.destroy(self);
    }
};

/// Bounded reusable storage. Active buffers retain the pool across session close.
/// close() releases the owner's reference exactly once, after all acquisitions stop.
pub const Pool = struct {
    allocator: std.mem.Allocator,
    refs: std.atomic.Value(usize) = std.atomic.Value(usize).init(1),
    mutex: Mutex = .{},
    slots: []?*Buffer,
    retained_bytes: usize = 0,
    max_bytes: usize,
    closed: bool = false,

    pub fn create(allocator: std.mem.Allocator, capacity: usize, max_bytes: usize) !*Pool {
        const self = try allocator.create(Pool);
        errdefer allocator.destroy(self);
        const slots = try allocator.alloc(?*Buffer, capacity);
        @memset(slots, null);
        self.* = .{ .allocator = allocator, .slots = slots, .max_bytes = max_bytes };
        return self;
    }
    pub fn acquire(self: *Pool, length: usize) !*Buffer {
        self.mutex.lock();
        if (self.closed) {
            self.mutex.unlock();
            return error.Closed;
        }
        for (self.slots) |*slot| {
            if (slot.*) |buffer| {
                if (buffer.storage.len < length) continue;
                slot.* = null;
                self.retained_bytes -= buffer.storage.len;
                buffer.bytes = buffer.storage[0..length];
                buffer.refs.store(1, .release);
                self.mutex.unlock();
                return buffer;
            }
        }
        // Acquisitions are owned by the runtime and stop before close.
        _ = self.refs.fetchAdd(1, .monotonic);
        self.mutex.unlock();
        const buffer = Buffer.create(self.allocator, length) catch |err| {
            self.releaseRef();
            return err;
        };
        buffer.pool = self;
        return buffer;
    }
    pub fn copy(self: *Pool, bytes: []const u8) !*Buffer {
        const buffer = try self.acquire(bytes.len);
        @memcpy(buffer.bytes, bytes);
        return buffer;
    }
    fn recycle(self: *Pool, buffer: *Buffer) void {
        self.mutex.lock();
        if (!self.closed and buffer.storage.len <= self.max_bytes - self.retained_bytes) {
            for (self.slots) |*slot| {
                if (slot.* == null) {
                    slot.* = buffer;
                    self.retained_bytes += buffer.storage.len;
                    self.mutex.unlock();
                    return;
                }
            }
        }
        self.mutex.unlock();
        buffer.destroy();
        self.releaseRef();
    }
    fn releaseRef(self: *Pool) void {
        if (self.refs.fetchSub(1, .acq_rel) == 1) {
            self.allocator.free(self.slots);
            self.allocator.destroy(self);
        }
    }
    pub fn close(self: *Pool) void {
        self.mutex.lock();
        self.closed = true;
        for (self.slots) |*slot| {
            if (slot.*) |buffer| {
                slot.* = null;
                buffer.destroy();
                self.releaseRef();
            }
        }
        self.retained_bytes = 0;
        self.mutex.unlock();
        self.releaseRef();
    }
};

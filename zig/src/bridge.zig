const std = @import("std");
const messages = @import("mailbox.zig");
const Mutex = @import("mutex.zig").Mutex;
const api = @import("api.zig");

pub const Limits = struct {
    messages: usize = 64,
    bytes: usize = 1024 * 1024,
    requests: usize = 64,
};

const Pending = struct { id: u64, terminal: bool = false };

/// Signals response availability, request capacity, and closure to the runtime.
/// Runs under the bridge lock: it must be quick, thread-safe, and never reenter.
pub const Notifier = struct {
    context: ?*anyopaque,
    signal: *const fn (?*anyopaque) void,
};

/// Thread-safe native-to-Dart requests with streamed Dart-to-native replies.
/// Methods never wait for queue capacity. Full means retry after the consumer drains.
/// The allocator must support use from every calling native thread.
pub const Bridge = struct {
    allocator: std.mem.Allocator,
    mutex: Mutex = .{},
    requests: messages.Mailbox,
    responses: messages.Mailbox,
    pending: []?Pending,
    next_id: u64 = 1,
    port: i64,
    closed: bool = false,
    wake_pending: bool = false,
    response_notifier: ?Notifier = null,

    pub fn init(allocator: std.mem.Allocator, port: i64, limits: Limits) !Bridge {
        if (limits.requests == 0 or port <= 0) return error.InvalidLimits;
        var requests = try messages.Mailbox.init(allocator, limits.messages, limits.bytes);
        errdefer requests.deinit();
        var responses = try messages.Mailbox.init(allocator, limits.messages, limits.bytes);
        errdefer responses.deinit();
        const pending = try allocator.alloc(?Pending, limits.requests);
        @memset(pending, null);
        return .{ .allocator = allocator, .requests = requests, .responses = responses, .pending = pending, .port = port };
    }

    fn notify(self: *Bridge) void {
        if (self.wake_pending or self.closed) return;
        self.wake_pending = api.wake(self.port);
        if (!self.wake_pending) self.closeLocked();
    }

    /// Dart acknowledges a wake before checking queues, under the same lock.
    pub fn acknowledge(self: *Bridge) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.wake_pending = false;
    }

    pub fn isClosed(self: *Bridge) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.closed;
    }

    /// Installs or detaches a native wake hook. Keep its context alive until
    /// detachment returns or close completes. Pending responses trigger a wake.
    pub fn setResponseNotifier(self: *Bridge, notifier: ?Notifier) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.closed) return error.Closed;
        self.response_notifier = notifier;
        if (self.responses.count != 0) self.notifyNative();
    }

    fn notifyNative(self: *Bridge) void {
        if (self.response_notifier) |notifier| notifier.signal(notifier.context);
    }

    fn entry(self: *Bridge, id: u64) ?*?Pending {
        for (self.pending) |*slot| {
            if (slot.*) |value| if (value.id == id) return slot;
        }
        return null;
    }

    /// Cancels a native request and immediately releases its queued packets.
    /// Wakes Dart writers so cancellation also interrupts capacity waits.
    pub fn cancel(self: *Bridge, id: u64) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.closed) return error.Closed;
        const slot = self.entry(id) orelse return error.UnknownRequest;
        slot.* = null;
        self.requests.remove(id);
        self.responses.remove(id);
        self.notify();
    }

    pub fn isPending(self: *Bridge, id: u64) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return !self.closed and self.entry(id) != null;
    }

    /// Copies the request and returns a non-reused ID. No state changes on Full.
    pub fn submit(self: *Bridge, bytes: []const u8) !u64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.closed) return error.Closed;
        // Keep IDs exactly representable as signed Dart FFI integers.
        if (self.next_id > std.math.maxInt(i64)) return error.IdExhausted;
        for (self.pending) |*slot| {
            if (slot.* != null) continue;
            const id = self.next_id;
            try self.requests.put(id, .request, bytes);
            slot.* = .{ .id = id };
            self.next_id += 1;
            self.notify();
            if (self.closed) return error.Closed;
            return id;
        }
        return error.Full;
    }

    /// Transfers request ownership to the caller, or returns null when empty.
    pub fn takeRequest(self: *Bridge) ?messages.Packet {
        self.mutex.lock();
        defer self.mutex.unlock();
        while (self.requests.take()) |value| {
            self.notifyNative();
            if (self.entry(value.id) != null) return value;
            var packet = value;
            packet.deinit();
        }
        return null;
    }

    /// Copies one reply chunk or terminal frame. Each ID accepts one terminal frame.
    pub fn reply(self: *Bridge, id: u64, kind: messages.Kind, bytes: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.closed) return error.Closed;
        if (kind == .request) return error.InvalidKind;
        const slot = self.entry(id) orelse return error.UnknownRequest;
        if (slot.*.?.terminal) return error.UnknownRequest;
        try self.responses.put(id, kind, bytes);
        if (kind != .chunk) slot.*.?.terminal = true;
        self.notifyNative();
    }

    /// Transfers response ownership and notifies Dart that write capacity changed.
    pub fn takeResponse(self: *Bridge) ?messages.Packet {
        self.mutex.lock();
        defer self.mutex.unlock();
        while (self.responses.take()) |value| {
            var packet = value;
            if (self.entry(packet.id)) |slot| {
                if (packet.kind != .chunk) slot.* = null;
                self.notify();
                return packet;
            }
            packet.deinit();
            self.notify();
        }
        return null;
    }

    fn closeLocked(self: *Bridge) void {
        if (self.closed) return;
        self.closed = true;
        self.requests.clear();
        self.responses.clear();
        @memset(self.pending, null);
        self.notifyNative();
        self.response_notifier = null;
    }

    /// Stops admission and discards queued work. Idempotent.
    /// Already posted wakes carry no pointers and are harmless after port closure.
    /// Callers observe Closed and must stop using this bridge before deinit.
    pub fn close(self: *Bridge) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.notify();
        self.closeLocked();
    }

    /// Frees storage after the owner has joined/detached all native users.
    /// This must never race another method call.
    pub fn deinit(self: *Bridge) void {
        self.close();
        self.requests.deinit();
        self.responses.deinit();
        self.allocator.free(self.pending);
    }
};

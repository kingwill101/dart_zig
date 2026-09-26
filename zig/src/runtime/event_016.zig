const std = @import("std");

// The runtime owns its OS threads. This Io backend supplies only blocking
// synchronization and a monotonic clock; it does not spawn async tasks.
fn io() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}

/// Counting wake primitive. Destroy only after every waiter has exited.
pub const Event = struct {
    mutex: std.Io.Mutex = .init,
    condition: std.Io.Condition = .init,
    permits: u32 = 0,
    generation: u64 = 0,

    pub fn init() !Event {
        return .{};
    }

    pub fn signal(self: *Event) void {
        const backend = io();
        self.mutex.lockUncancelable(backend);
        self.permits +|= 1;
        self.generation +%= 1;
        self.condition.broadcast(backend);
        self.mutex.unlock(backend);
    }

    pub fn wait(self: *Event) void {
        const backend = io();
        self.mutex.lockUncancelable(backend);
        defer self.mutex.unlock(backend);
        while (self.permits == 0) self.condition.waitUncancelable(backend, &self.mutex);
        self.permits -= 1;
    }

    pub fn epoch(self: *Event) u64 {
        const backend = io();
        self.mutex.lockUncancelable(backend);
        defer self.mutex.unlock(backend);
        return self.generation;
    }

    pub fn waitSince(self: *Event, previous: u64) void {
        const backend = io();
        self.mutex.lockUncancelable(backend);
        defer self.mutex.unlock(backend);
        while (self.generation == previous) self.condition.waitUncancelable(backend, &self.mutex);
    }

    pub fn deinit(_: Event) void {}
};

pub const Clock = struct {
    start: std.Io.Timestamp,

    pub fn init() !Clock {
        return .{ .start = std.Io.Clock.awake.now(io()) };
    }

    pub fn monotonicNs(self: Clock) u64 {
        const elapsed = std.Io.Clock.awake.now(io()).nanoseconds - self.start.nanoseconds;
        return @intCast(@max(0, elapsed));
    }
};

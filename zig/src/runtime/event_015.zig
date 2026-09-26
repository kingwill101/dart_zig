const std = @import("std");

/// Counting wake primitive. Destroy only after every waiter has exited.
pub const Event = struct {
    mutex: std.Thread.Mutex = .{},
    condition: std.Thread.Condition = .{},
    permits: u32 = 0,
    generation: u64 = 0,

    pub fn init() !Event {
        return .{};
    }

    pub fn signal(self: *Event) void {
        self.mutex.lock();
        self.permits +|= 1;
        self.generation +%= 1;
        self.condition.broadcast();
        self.mutex.unlock();
    }

    pub fn wait(self: *Event) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        while (self.permits == 0) self.condition.wait(&self.mutex);
        self.permits -= 1;
    }

    pub fn epoch(self: *Event) u64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.generation;
    }

    pub fn waitSince(self: *Event, previous: u64) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        while (self.generation == previous) self.condition.wait(&self.mutex);
    }

    pub fn deinit(_: Event) void {}
};

pub const Clock = struct {
    start: std.time.Instant,

    pub fn init() !Clock {
        return .{ .start = try std.time.Instant.now() };
    }

    pub fn monotonicNs(self: Clock) u64 {
        // Clock.init already established that this target has a working clock.
        const current = std.time.Instant.now() catch unreachable;
        if (current.order(self.start) == .lt) return 0;
        return current.since(self.start);
    }
};

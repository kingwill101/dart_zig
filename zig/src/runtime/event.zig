const c = @cImport({
    @cInclude("event.h");
});

/// Counting wake primitive backed by OS condition variables; never busy-polls.
/// Destroy only after every waiter has exited.
pub const Event = struct {
    handle: *c.dz_event,
    pub fn init() !Event {
        return .{ .handle = c.dz_event_create() orelse return error.OutOfMemory };
    }
    pub fn signal(self: Event) void {
        c.dz_event_signal(self.handle);
    }
    pub fn wait(self: Event) void {
        c.dz_event_wait(self.handle);
    }
    pub fn epoch(self: Event) u64 {
        return c.dz_event_epoch(self.handle);
    }
    pub fn waitSince(self: Event, epoch_value: u64) void {
        c.dz_event_wait_since(self.handle, epoch_value);
    }
    pub fn deinit(self: Event) void {
        c.dz_event_destroy(self.handle);
    }
};

pub fn monotonicNs() u64 {
    return c.dz_monotonic_ns();
}

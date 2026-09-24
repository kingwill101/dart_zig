const std = @import("std");

/// Short critical-section lock shared by Zig 0.15 and 0.16.
/// Never hold this lock while waiting for Dart or performing application I/O.
pub const Mutex = struct {
    held: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn lock(self: *Mutex) void {
        while (self.held.cmpxchgWeak(false, true, .acquire, .monotonic) != null) {
            std.atomic.spinLoopHint();
        }
    }

    pub fn unlock(self: *Mutex) void {
        self.held.store(false, .release);
    }
};

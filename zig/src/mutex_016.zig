const std = @import("std");

/// Adapts std.Io.Mutex to the lock/unlock interface used by Zig 0.15.
pub const Mutex = struct {
    inner: std.Io.Mutex = .init,

    pub fn lock(self: *Mutex) void {
        self.inner.lockUncancelable(std.Io.Threaded.global_single_threaded.io());
    }

    pub fn unlock(self: *Mutex) void {
        self.inner.unlock(std.Io.Threaded.global_single_threaded.io());
    }
};

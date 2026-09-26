const std = @import("std");
const builtin = @import("builtin");

/// Uses Zig's native synchronization API for each supported compiler version.
pub const Mutex = if (builtin.single_threaded)
    struct {
        pub fn lock(_: *@This()) void {}
        pub fn unlock(_: *@This()) void {}
    }
else if (builtin.zig_version.minor >= 16)
    @import("mutex_016.zig").Mutex
else
    std.Thread.Mutex;

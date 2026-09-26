const builtin = @import("builtin");

/// Native events share one contract across targets. Zig 0.16 moved blocking
/// synchronization and clocks from std.Thread to std.Io.
pub const Event = if (builtin.zig_version.minor >= 16)
    @import("event_016.zig").Event
else
    @import("event_015.zig").Event;

pub const Clock = if (builtin.zig_version.minor >= 16)
    @import("event_016.zig").Clock
else
    @import("event_015.zig").Clock;

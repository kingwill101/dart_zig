const std = @import("std");

/// Cooperative token. A parent must outlive every child that refers to it.
/// Deadline comparison takes a caller-provided monotonic clock in nanoseconds.
pub const CancellationToken = struct {
    cancelled: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    parent: ?*const CancellationToken = null,
    deadline_ns: ?u64 = null,

    pub fn cancel(self: *CancellationToken) void {
        self.cancelled.store(true, .release);
    }

    pub fn check(self: *const CancellationToken, now_ns: u64) error{ Cancelled, DeadlineExceeded }!void {
        if (self.cancelled.load(.acquire)) return error.Cancelled;
        if (self.deadline_ns) |deadline| if (now_ns >= deadline) return error.DeadlineExceeded;
        if (self.parent) |parent| try parent.check(now_ns);
    }
};

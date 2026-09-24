//! Atomic-shaped storage for the cooperative, single-threaded Wasm backend.
const std = @import("std");
pub fn Value(comptime T: type) type {
    return struct {
        raw: T,
        const Self = @This();
        pub fn init(value: T) Self {
            return .{ .raw = value };
        }
        pub fn load(self: *const Self, comptime _: std.builtin.AtomicOrder) T {
            return self.raw;
        }
        pub fn fetchAdd(self: *Self, value: T, comptime _: std.builtin.AtomicOrder) T {
            const old = self.raw;
            self.raw +%= value;
            return old;
        }
        pub fn cmpxchgWeak(self: *Self, expected: T, value: T, comptime _: std.builtin.AtomicOrder, comptime _: std.builtin.AtomicOrder) ?T {
            if (self.raw != expected) return self.raw;
            self.raw = value;
            return null;
        }
    };
}

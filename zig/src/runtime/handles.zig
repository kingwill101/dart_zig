const std = @import("std");
const Mutex = @import("../mutex.zig").Mutex;

/// Fixed-capacity table with O(1) allocation and generation-checked lookup.
/// T's destructor must not reenter a table being deinitialized.
pub fn HandleTable(comptime T: type, comptime destroy: fn (T) void) type {
    return struct {
        const Self = @This();
        const none = std.math.maxInt(u32);
        const Slot = struct {
            value: ?T = null,
            generation: u32 = 1,
            leases: usize = 0,
            closing: bool = false,
            next: u32 = none,
        };
        pub const Lease = struct {
            table: *Self,
            index: u32,
            value: *T,

            /// Releases this lease once. Treat leases as move-only values.
            pub fn release(self: *Lease) void {
                const table = self.table;
                table.mutex.lock();
                const slot = &table.slots[self.index];
                std.debug.assert(slot.leases > 0);
                slot.leases -= 1;
                const retired = if (slot.closing and slot.leases == 0) table.retire(self.index) else null;
                table.mutex.unlock();
                if (retired) |value| destroy(value);
                self.* = undefined;
            }
        };

        allocator: std.mem.Allocator,
        slots: []Slot,
        free_head: u32,
        mutex: Mutex = .{},

        pub fn init(allocator: std.mem.Allocator, capacity: u32) !Self {
            if (capacity == 0 or capacity == none) return error.InvalidCapacity;
            const slots = try allocator.alloc(Slot, capacity);
            for (slots, 0..) |*slot, index| slot.* = .{ .next = if (index + 1 < capacity) @intCast(index + 1) else none };
            return .{ .allocator = allocator, .slots = slots, .free_head = 0 };
        }

        pub fn insert(self: *Self, value: T) !u64 {
            self.mutex.lock();
            defer self.mutex.unlock();
            if (self.free_head == none) return error.Full;
            const index = self.free_head;
            const slot = &self.slots[index];
            self.free_head = slot.next;
            slot.value = value;
            slot.closing = false;
            return (@as(u64, slot.generation) << 32) | index;
        }

        fn lookup(self: *Self, handle: u64) !u32 {
            const index: u32 = @truncate(handle);
            const generation: u32 = @intCast(handle >> 32);
            if (index >= self.slots.len) return error.StaleHandle;
            const slot = &self.slots[index];
            if (slot.generation != generation or slot.value == null or slot.closing) return error.StaleHandle;
            return index;
        }

        pub fn acquire(self: *Self, handle: u64) !Lease {
            self.mutex.lock();
            defer self.mutex.unlock();
            const index = try self.lookup(handle);
            const slot = &self.slots[index];
            slot.leases += 1;
            return .{ .table = self, .index = index, .value = &slot.value.? };
        }

        fn retire(self: *Self, index: u32) ?T {
            const slot = &self.slots[index];
            const value = slot.value;
            slot.value = null;
            // Exhausted generations are never reused. Keep handles positive in Dart.
            if (slot.generation < std.math.maxInt(i32)) {
                slot.generation += 1;
                slot.next = self.free_head;
                self.free_head = index;
            }
            return value;
        }

        /// Rejects new acquisitions immediately; existing leases defer destruction.
        pub fn remove(self: *Self, handle: u64) !void {
            self.mutex.lock();
            const index = self.lookup(handle) catch |err| {
                self.mutex.unlock();
                return err;
            };
            const slot = &self.slots[index];
            slot.closing = true;
            const retired = if (slot.leases == 0) self.retire(index) else null;
            self.mutex.unlock();
            if (retired) |value| destroy(value);
        }

        /// Requires all callers and leases to have stopped.
        pub fn deinit(self: *Self) void {
            for (self.slots) |slot| {
                std.debug.assert(slot.leases == 0);
                if (slot.value) |value| destroy(value);
            }
            self.allocator.free(self.slots);
        }
    };
}

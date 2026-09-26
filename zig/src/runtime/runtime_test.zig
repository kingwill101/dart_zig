const std = @import("std");
const Runtime = @import("runtime.zig").Runtime;
const Context = @import("runtime.zig").Context;
const Event = @import("event.zig").Event;
const Clock = @import("event.zig").Clock;
const Mutex = @import("../mutex.zig").Mutex;
const frames = @import("frame.zig");

fn wake(_: i64) bool {
    return true;
}

fn dispatch(context: *Context, _: frames.Kind, route: u32, _: []const u8) !void {
    switch (route) {
        1 => try context.complete("ok"),
        2 => {
            const state = try context.runtime.allocator.create(Stream);
            state.* = .{};
            try context.deferStream(state, Stream.resumeStream, Stream.release);
        },
        3 => try context.item("item"),
        4 => {
            try context.signal(99, "a");
            try context.signal(99, "b");
            try context.signal(99, "c");
            try context.complete("ok");
        },
        else => return error.UnknownOperation,
    }
}

const Stream = struct {
    sent: bool = false,

    fn resumeStream(context: *Context, pointer: *anyopaque) !void {
        const self: *Stream = @ptrCast(@alignCast(pointer));
        if (self.sent) return context.end();
        try context.item("item");
        self.sent = true;
    }

    fn release(pointer: *anyopaque) void {
        const self: *Stream = @ptrCast(@alignCast(pointer));
        std.testing.allocator.destroy(self);
    }
};

fn create(options: @import("runtime.zig").Options) !*Runtime {
    var settings = options;
    settings.wake = wake;
    return Runtime.create(std.testing.allocator, 1, settings, dispatch, null);
}

fn waitForOutput(runtime: *Runtime, count: usize) !void {
    const start = try Clock.init();
    while (start.monotonicNs() < 2 * std.time.ns_per_s) {
        runtime.mutex.lock();
        const available = runtime.output.count + runtime.pending_output.count;
        runtime.mutex.unlock();
        if (available >= count) return;
        std.Thread.yield() catch {};
    }
    return error.TimedOut;
}

fn next(runtime: *Runtime) !frames.Descriptor {
    var output: [1]frames.Descriptor = undefined;
    const count = runtime.poll(&output);
    try std.testing.expectEqual(@as(usize, 1), count);
    return output[0];
}

test "event keeps counting wakes and observes a changed epoch" {
    var event = try Event.init();
    defer event.deinit();
    const epoch = event.epoch();
    event.signal();
    event.signal();
    event.waitSince(epoch);
    event.wait();
    event.wait();
}

test "version-adapted mutex serializes native workers" {
    const Counter = struct {
        mutex: Mutex = .{},
        value: usize = 0,

        fn increment(self: *@This()) void {
            for (0..1000) |_| {
                self.mutex.lock();
                self.value += 1;
                self.mutex.unlock();
            }
        }
    };
    var counter: Counter = .{};
    var threads: [4]std.Thread = undefined;
    for (&threads) |*thread| thread.* = try std.Thread.spawn(.{}, Counter.increment, .{&counter});
    for (threads) |thread| thread.join();
    try std.testing.expectEqual(@as(usize, 4000), counter.value);
}

test "full output queues pending results without occupying the worker" {
    const runtime = try create(.{ .messages = 1, .bytes = 8, .tasks = 4, .workers = 1 });
    defer runtime.destroy();
    const first = try runtime.submit(1, .call, &.{}, 0);
    try waitForOutput(runtime, 1);
    const second = try runtime.submit(1, .call, &.{}, 0);
    try waitForOutput(runtime, 2);
    const third = try runtime.submit(1, .call, &.{}, 0);
    try waitForOutput(runtime, 3);
    for ([_]u64{ first, second, third }) |id| {
        const frame = try next(runtime);
        defer frame.owner.release();
        try std.testing.expectEqual(id, frame.id);
        try std.testing.expectEqual(@as(u32, @intFromEnum(frames.Kind.result)), frame.kind);
        try std.testing.expectEqualStrings("ok", frame.data[0..frame.length]);
    }
}

test "pending output bytes have one fixed reserve regardless of task capacity" {
    const runtime = try create(.{ .messages = 1, .bytes = 8, .tasks = 32, .workers = 1 });
    defer runtime.destroy();

    try std.testing.expectEqual(@as(usize, 8), runtime.output.max_bytes);
    try std.testing.expectEqual(runtime.output.max_bytes, runtime.pending_output.max_bytes);
    try std.testing.expectEqual(@as(usize, 33), runtime.pending_output.slots.len);

    const reserved = try runtime.buffers.copy("12345678");
    try runtime.pending_output.put(.{ .kind = .result, .buffer = reserved });
    const overflowing = try runtime.buffers.copy("x");
    defer overflowing.release();
    try std.testing.expectError(error.Full, runtime.pending_output.put(.{ .kind = .result, .buffer = overflowing }));
}

test "stream credit schedules one item and a paused stream leaves the worker free" {
    const runtime = try create(.{ .messages = 2, .bytes = 32, .tasks = 4, .workers = 1 });
    defer runtime.destroy();
    const stream = try runtime.submit(2, .stream_start, &.{}, 0);
    const call = try runtime.submit(1, .call, &.{}, 0);
    try waitForOutput(runtime, 1);
    const result = try next(runtime);
    defer result.owner.release();
    try std.testing.expectEqual(call, result.id);
    try runtime.grant(stream);
    try waitForOutput(runtime, 1);
    const item = try next(runtime);
    defer item.owner.release();
    try std.testing.expectEqual(stream, item.id);
    try std.testing.expectEqual(@as(u32, @intFromEnum(frames.Kind.stream_item)), item.kind);
    try runtime.grant(stream);
    try waitForOutput(runtime, 1);
    const end = try next(runtime);
    defer end.owner.release();
    try std.testing.expectEqual(@as(u32, @intFromEnum(frames.Kind.stream_end)), end.kind);
}

test "item without credit fails instead of parking the worker" {
    const runtime = try create(.{ .messages = 2, .bytes = 32, .tasks = 4, .workers = 1 });
    defer runtime.destroy();
    const stream = try runtime.submit(3, .stream_start, &.{}, 0);
    const call = try runtime.submit(1, .call, &.{}, 0);
    try waitForOutput(runtime, 2);
    const failure = try next(runtime);
    defer failure.owner.release();
    try std.testing.expectEqual(stream, failure.id);
    try std.testing.expectEqual(@as(u32, @intFromEnum(frames.Kind.failure)), failure.kind);
    const result = try next(runtime);
    defer result.owner.release();
    try std.testing.expectEqual(call, result.id);
}

test "task capacity includes results waiting for Dart and recovers on poll" {
    const runtime = try create(.{ .messages = 1, .bytes = 8, .tasks = 2, .workers = 1 });
    defer runtime.destroy();
    const first = try runtime.submit(1, .call, &.{}, 0);
    try waitForOutput(runtime, 1);
    const second = try runtime.submit(1, .call, &.{}, 0);
    try waitForOutput(runtime, 2);
    try std.testing.expectError(error.Full, runtime.submit(1, .call, &.{}, 0));
    const first_result = try next(runtime);
    defer first_result.owner.release();
    try std.testing.expectEqual(first, first_result.id);
    const third = try runtime.submit(1, .call, &.{}, 0);
    try waitForOutput(runtime, 2);
    for ([_]u64{ second, third }) |id| {
        const result = try next(runtime);
        defer result.owner.release();
        try std.testing.expectEqual(id, result.id);
    }
}

test "bounded signal backpressure reports failure without stopping the session" {
    const runtime = try create(.{ .messages = 1, .bytes = 8, .tasks = 2, .workers = 1 });
    defer runtime.destroy();
    const source = try runtime.submit(4, .call, &.{}, 0);
    try waitForOutput(runtime, 3);
    for (0..2) |_| {
        const signal = try next(runtime);
        defer signal.owner.release();
        try std.testing.expectEqual(@as(u32, @intFromEnum(frames.Kind.signal)), signal.kind);
    }
    const failure = try next(runtime);
    defer failure.owner.release();
    try std.testing.expectEqual(source, failure.id);
    try std.testing.expectEqual(@as(u32, @intFromEnum(frames.Kind.failure)), failure.kind);
    try std.testing.expect(!runtime.stopping.load(.acquire));
    const call = try runtime.submit(1, .call, &.{}, 0);
    try waitForOutput(runtime, 1);
    const result = try next(runtime);
    defer result.owner.release();
    try std.testing.expectEqual(call, result.id);
}

test "cancelling a task releases its queued output" {
    const runtime = try create(.{ .messages = 1, .bytes = 8, .tasks = 2, .workers = 1 });
    defer runtime.destroy();
    const first = try runtime.submit(1, .call, &.{}, 0);
    try waitForOutput(runtime, 1);
    const cancelled = try runtime.submit(1, .call, &.{}, 0);
    try waitForOutput(runtime, 2);
    try runtime.cancel(cancelled);
    runtime.mutex.lock();
    const pending = runtime.pending_output.count;
    runtime.mutex.unlock();
    try std.testing.expectEqual(@as(usize, 0), pending);
    const result = try next(runtime);
    defer result.owner.release();
    try std.testing.expectEqual(first, result.id);
}

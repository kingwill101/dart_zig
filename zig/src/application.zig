const std = @import("std");
const dz = @import("dart_zig");
const models = @import("models");

const Counter = struct {
    value: dz.Atomic(i64),
    fn destroy(self: *Counter) void {
        dz.allocator.destroy(self);
    }
};
const Counters = dz.HandleTable(*Counter, Counter.destroy);
pub const Application = struct {
    counters: Counters,
    pub fn create() !*Application {
        const self = try dz.allocator.create(Application);
        errdefer dz.allocator.destroy(self);
        self.* = .{ .counters = try Counters.init(dz.allocator, 256) };
        return self;
    }
    pub fn destroy(self: *Application) void {
        self.counters.deinit();
        dz.allocator.destroy(self);
    }
};

/// General-purpose example operations; none are part of the runtime protocol.
pub fn dispatch(context: *dz.Context, kind: dz.frames.Kind, _: u32, bytes: []const u8) !void {
    if (context.isSignal()) {
        if (context.operation() != 100) return error.UnknownSignal;
        var envelope: dz.codec.Reader = .{ .bytes = bytes };
        var metadata: dz.codec.Reader = .{ .bytes = try envelope.blob() };
        const message = try models.decodeMessage(&metadata, dz.allocator);
        try metadata.finish();
        const binary = try envelope.blob();
        try envelope.finish();
        try models.emitUpdates(context.runtime, dz.allocator, message, binary);
        return;
    }
    var reader: dz.codec.Reader = .{ .bytes = bytes };
    var writer: dz.codec.Writer = .{ .allocator = dz.allocator, .max_bytes = 8 * 1024 * 1024 };
    defer writer.deinit();
    const app: *Application = @ptrCast(@alignCast(context.application().?));
    if (context.isStream() != (context.operation() == models.Operations.squares)) return error.InvalidOperationMode;
    switch (context.operation()) {
        models.Operations.sum => {
            const a = try reader.int(i64);
            const b = try reader.int(i64);
            try reader.finish();
            const sum = @addWithOverflow(a, b);
            if (sum[1] != 0) return error.Overflow;
            try writer.int(i64, sum[0]);
            try context.complete(writer.bytes.items);
        },
        models.Operations.publish => { // Typed signal: a UTF-8 string and a sequence number.
            const text = try reader.string();
            const sequence = try reader.int(i64);
            try reader.finish();
            try writer.string(text);
            try writer.int(i64, sequence);
            try context.signal(1, writer.bytes.items);
            try context.complete(&.{});
        },
        models.Operations.squares => { // Streaming squares.
            const count = try reader.int(u32);
            try reader.finish();
            if (count > 1000000) return error.TooLarge;
            const state = try dz.allocator.create(Squares);
            state.* = .{ .count = count };
            try context.deferStream(state, Squares.resumeStream, Squares.release);
        },
        models.Operations.counterCreate => {
            const initial = try reader.int(i64);
            try reader.finish();
            const counter = try dz.allocator.create(Counter);
            counter.* = .{ .value = dz.Atomic(i64).init(initial) };
            const handle = app.counters.insert(counter) catch |err| {
                counter.destroy();
                return err;
            };
            errdefer app.counters.remove(handle) catch {};
            try writer.int(u64, handle);
            try context.complete(writer.bytes.items);
        },
        models.Operations.counterAdd => {
            const handle = try reader.int(u64);
            const delta = try reader.int(i64);
            try reader.finish();
            var lease = try app.counters.acquire(handle);
            defer lease.release();
            const counter = lease.value.*;
            var old = counter.value.load(.acquire);
            while (true) {
                const sum = @addWithOverflow(old, delta);
                if (sum[1] != 0) return error.Overflow;
                if (counter.value.cmpxchgWeak(old, sum[0], .acq_rel, .acquire)) |actual| {
                    old = actual;
                } else {
                    try writer.int(i64, sum[0]);
                    try context.complete(writer.bytes.items);
                    break;
                }
            }
        },
        models.Operations.counterDispose => {
            try app.counters.remove(try reader.int(u64));
            try reader.finish();
            try context.complete(&.{});
        },
        models.Operations.transform => {
            if (kind == .callback_result) {
                const transformed = try reader.int(i64);
                try reader.finish();
                try writer.int(i64, transformed);
                try context.complete(writer.bytes.items);
            } else {
                const callback_id = try reader.int(u32);
                const value = try reader.int(i64);
                try reader.finish();
                try writer.int(i64, value);
                try context.callback(callback_id, writer.bytes.items);
            }
        },
        models.Operations.echo => { // Binary echo, useful for transfer benchmarks.
            try context.complete(bytes);
        },
        models.Operations.roundTripRich => {
            var arena = std.heap.ArenaAllocator.init(dz.allocator);
            defer arena.deinit();
            const value = try models.decodeRichValues(&reader, arena.allocator());
            try reader.finish();
            try models.encodeRichValues(&writer, value);
            try context.complete(writer.bytes.items);
        },
        models.Operations.roundTripRecord => {
            var arena = std.heap.ArenaAllocator.init(dz.allocator);
            defer arena.deinit();
            const value = try models.decodeRecord(&reader, arena.allocator());
            try reader.finish();
            try models.encodeRecord(&writer, value);
            try context.complete(writer.bytes.items);
        },
        models.Operations.roundTripValue => {
            var arena = std.heap.ArenaAllocator.init(dz.allocator);
            defer arena.deinit();
            const value = try models.decodeValue(&reader, arena.allocator());
            try reader.finish();
            try models.encodeValue(&writer, value);
            try context.complete(writer.bytes.items);
        },
        models.Operations.emitLog => {
            const value = try models.decodeMessage(&reader, dz.allocator);
            try reader.finish();
            dz.logging.write(context.runtime, .info, "demo", "{s}", .{value.text});
            try context.complete(&.{});
        },
        else => return error.UnknownOperation,
    }
}

const Squares = struct {
    count: u32,
    index: u32 = 0,
    fn release(pointer: *anyopaque) void {
        const self: *Squares = @ptrCast(@alignCast(pointer));
        dz.allocator.destroy(self);
    }
    fn resumeStream(context: *dz.Context, pointer: *anyopaque) !void {
        const self: *Squares = @ptrCast(@alignCast(pointer));
        if (self.index == self.count) {
            try context.end();
            return;
        }
        var bytes: [8]u8 = undefined;
        const value: i64 = self.index;
        std.mem.writeInt(i64, &bytes, value * value, .little);
        self.index += 1;
        try context.item(&bytes);
    }
};

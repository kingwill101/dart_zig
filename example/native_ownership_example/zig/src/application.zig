const dz = @import("dart_zig");
const protocol = @import("protocol.zig");

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
        self.* = .{ .counters = try Counters.init(dz.allocator, 32) };
        return self;
    }
    pub fn destroy(self: *Application) void {
        self.counters.deinit();
        dz.allocator.destroy(self);
    }
};

pub fn dispatch(context: *dz.Context, _: dz.frames.Kind, _: u32, bytes: []const u8) !void {
    if (context.operation() == 8) {
        try context.complete(bytes);
        return;
    }
    const app: *Application = @ptrCast(@alignCast(context.application().?));
    var reader: dz.codec.Reader = .{ .bytes = bytes };
    var writer: dz.codec.Writer = .{ .allocator = dz.allocator, .max_bytes = 8 };
    defer writer.deinit();
    switch (context.operation()) {
        dz.events.id(protocol.routes, .createCounter) => {
            const initial = try reader.decode(protocol.routes.createCounter.request);
            try reader.finish();
            const counter = try dz.allocator.create(Counter);
            counter.* = .{ .value = dz.Atomic(i64).init(initial) };
            const handle = app.counters.insert(counter) catch |err| {
                counter.destroy();
                return err;
            };
            try writer.int(u64, handle);
            try context.complete(writer.bytes.items);
        },
        dz.events.id(protocol.routes, .addCounter) => {
            const request = try reader.decode(protocol.routes.addCounter.request);
            try reader.finish();
            var lease = try app.counters.acquire(request.handle);
            defer lease.release();
            const counter = lease.value.*;
            var old = counter.value.load(.acquire);
            while (true) {
                const sum = @addWithOverflow(old, request.delta);
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
        dz.events.id(protocol.routes, .releaseCounter) => {
            try app.counters.remove(try reader.decode(protocol.routes.releaseCounter.request));
            try reader.finish();
            try context.complete(&.{});
        },
        else => return error.UnknownOperation,
    }
}

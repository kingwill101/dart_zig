const std = @import("std");
const dz = @import("dart_zig");
const app = @import("application");
const allocator = std.heap.wasm_allocator;
fn status(err: anyerror) u32 {
    return switch (err) {
        error.Full => 1,
        error.Closed => 2,
        error.OutOfMemory => 4,
        error.TooLarge => 5,
        else => 3,
    };
}
export fn dz_web_protocol() u32 {
    return dz.frames.protocol_version;
}
export fn dz_web_schema() u32 {
    return @import("models").schema_fingerprint;
}
export fn dz_web_alloc(length: usize) ?[*]u8 {
    const bytes = allocator.alloc(u8, length) catch return null;
    return bytes.ptr;
}
export fn dz_web_free(data: [*]u8, length: usize) void {
    allocator.free(data[0..length]);
}
export fn dz_web_create(count: usize, bytes: usize, tasks: u32) ?*dz.Runtime {
    const application = app.Application.create() catch return null;
    return dz.Runtime.create(allocator, 0, .{ .messages = count, .bytes = bytes, .tasks = tasks }, app.dispatch, application) catch {
        application.destroy();
        return null;
    };
}
export fn dz_web_destroy(runtime: *dz.Runtime) void {
    const application: *app.Application = @ptrCast(@alignCast(runtime.application.?));
    runtime.destroy();
    application.destroy();
}
export fn dz_web_stop(runtime: *dz.Runtime) void {
    runtime.stop();
}
export fn dz_web_stopped(runtime: *dz.Runtime) bool {
    return runtime.stopping.load(.acquire);
}
export fn dz_web_submit(runtime: *dz.Runtime, route: u32, kind: u32, data: [*]const u8, length: usize) f64 {
    if (kind != 0 and kind != 2 and kind != 10) return -3;
    const id = runtime.submit(route, @enumFromInt(kind), data[0..length], 0) catch |err| return -@as(f64, @floatFromInt(status(err)));
    if (id > 9007199254740991) {
        runtime.cancel(id) catch {};
        return -3;
    }
    return @floatFromInt(id);
}
export fn dz_web_send(runtime: *dz.Runtime, route: u32, data: [*]const u8, length: usize) u32 {
    runtime.sendSignal(route, data[0..length]) catch |err| return status(err);
    return 0;
}
export fn dz_web_callback(runtime: *dz.Runtime, id: f64, route: u32, code: u32, data: [*]const u8, length: usize) u32 {
    runtime.callbackReply(@intFromFloat(id), route, code, data[0..length]) catch |err| return status(err);
    return 0;
}
export fn dz_web_cancel(runtime: *dz.Runtime, id: f64) void {
    runtime.cancel(@intFromFloat(id)) catch {};
}
export fn dz_web_grant(runtime: *dz.Runtime, id: f64) void {
    runtime.grant(@intFromFloat(id)) catch {};
}
export fn dz_web_pump(runtime: *dz.Runtime, budget: usize) usize {
    return runtime.pump(budget);
}
export fn dz_web_work(runtime: *dz.Runtime) bool {
    return runtime.pending_failure != null or runtime.input.count != 0 or runtime.ready.count != 0 or runtime.output.count != 0;
}
export fn dz_web_poll(runtime: *dz.Runtime) ?*dz.frames.Frame {
    if (runtime.output.count == 0) return null;
    const frame = allocator.create(dz.frames.Frame) catch return null;
    frame.* = runtime.output.take().?;
    runtime.delivered += 1;
    return frame;
}
export fn dz_web_frame_field(frame: *dz.frames.Frame, field: u32) f64 {
    return @floatFromInt(switch (field) {
        0 => frame.id,
        1 => frame.route,
        2 => @intFromEnum(frame.kind),
        3 => frame.code,
        4 => frame.buffer.bytes.len,
        5 => @intFromPtr(frame.buffer.bytes.ptr),
        else => @as(u64, 0),
    });
}
export fn dz_web_frame_release(frame: *dz.frames.Frame) void {
    frame.deinit();
    allocator.destroy(frame);
}
export fn dz_web_stats(runtime: *dz.Runtime, field: u32) f64 {
    return @floatFromInt(switch (field) {
        0 => runtime.submitted,
        1 => runtime.delivered,
        2 => runtime.wakes,
        3 => runtime.copied_bytes,
        4 => runtime.log_drops.load(.acquire),
        5 => runtime.input.count,
        6 => runtime.output.count,
        7 => runtime.input.bytes,
        8 => runtime.output.bytes,
        else => @as(u64, 0),
    });
}
export fn dz_web_live(field: u32) f64 {
    return @floatFromInt(if (field == 0) dz.buffer_metrics.live_buffers.load(.acquire) else dz.buffer_metrics.live_bytes.load(.acquire));
}
export fn dz_web_sum(a: f64, b: f64) f64 {
    if (@abs(a) > 9007199254740991 or @abs(b) > 9007199254740991) return std.math.nan(f64);
    const sum = @addWithOverflow(@as(i64, @intFromFloat(a)), @as(i64, @intFromFloat(b)));
    if (sum[1] != 0 or sum[0] > 9007199254740991 or sum[0] < -9007199254740991) return std.math.nan(f64);
    return @floatFromInt(sum[0]);
}

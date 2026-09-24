const std = @import("std");
const dz = @import("dart_zig");
const allocator = std.heap.c_allocator;

comptime {
    _ = @import("demo");
}

// Status ABI: 0 success, 1 empty/full, 2 closed, 3 invalid/stale,
// 4 allocation failure, 5 payload too large.
fn status(err: anyerror) u8 {
    return switch (err) {
        error.Full => 1,
        error.Closed => 2,
        error.OutOfMemory => 4,
        error.TooLarge => 5,
        else => 3,
    };
}

export fn dz_initialize(data: ?*anyopaque) bool {
    return dz.api.initialize(data);
}

export fn dz_create(port: i64, count: usize, bytes: usize, pending: usize) ?*dz.Bridge {
    const bridge = allocator.create(dz.Bridge) catch return null;
    bridge.* = dz.Bridge.init(allocator, port, .{ .messages = count, .bytes = bytes, .requests = pending }) catch {
        allocator.destroy(bridge);
        return null;
    };
    return bridge;
}

export fn dz_close(bridge: *dz.Bridge) void {
    bridge.close();
}
export fn dz_destroy(bridge: *dz.Bridge) void {
    bridge.deinit();
    allocator.destroy(bridge);
}
export fn dz_acknowledge(bridge: *dz.Bridge) void {
    bridge.acknowledge();
}

export fn dz_is_pending(bridge: *dz.Bridge, id: u64) bool {
    return bridge.isPending(id);
}

export fn dz_take_request(bridge: *dz.Bridge, out: *?*dz.Packet) u8 {
    out.* = null;
    if (bridge.isClosed()) return 2;
    // Allocate before taking so allocation failure never consumes a packet.
    const packet = allocator.create(dz.Packet) catch return 4;
    packet.* = bridge.takeRequest() orelse {
        allocator.destroy(packet);
        return 1;
    };
    out.* = packet;
    return 0;
}
export fn dz_packet_id(packet: *const dz.Packet) u64 {
    return packet.id;
}
export fn dz_packet_length(packet: *const dz.Packet) usize {
    return packet.bytes.len;
}
export fn dz_packet_bytes(packet: *const dz.Packet) [*]const u8 {
    return packet.bytes.ptr;
}
export fn dz_packet_free(packet: *dz.Packet) void {
    packet.deinit();
    allocator.destroy(packet);
}
export fn dz_reply(bridge: *dz.Bridge, id: u64, kind: u8, bytes: [*]const u8, len: usize) u8 {
    if (kind > @intFromEnum(dz.Kind.cancelled)) return 3;
    const tag: dz.Kind = @enumFromInt(kind);
    bridge.reply(id, tag, bytes[0..len]) catch |err| return status(err);
    return 0;
}

pub const RuntimeFrame = extern struct {
    id: u64,
    route: u32,
    kind: u32,
    code: u32,
    length: usize,
    data: [*]const u8,
    owner: *anyopaque,
};

export fn dz_protocol_version() u32 {
    return dz.frames.protocol_version;
}

export fn dz_runtime_create(port: i64, count: usize, bytes: usize, tasks: u32, workers: usize) ?*dz.Runtime {
    const app = @import("application").Application.create() catch return null;
    return dz.Runtime.create(allocator, port, .{ .messages = count, .bytes = bytes, .tasks = tasks, .workers = workers }, @import("application").dispatch, app) catch {
        app.destroy();
        return null;
    };
}
export fn dz_runtime_stop(runtime: *dz.Runtime) void {
    runtime.stop();
}
export fn dz_runtime_stopped(runtime: *dz.Runtime) bool {
    return runtime.stopping.load(.acquire);
}
export fn dz_runtime_destroy(runtime: *dz.Runtime) void {
    const app: *@import("application").Application = @ptrCast(@alignCast(runtime.application.?));
    runtime.destroy();
    app.destroy();
}
export fn dz_runtime_acknowledge(runtime: *dz.Runtime) void {
    runtime.acknowledge();
}
export fn dz_runtime_submit(runtime: *dz.Runtime, route: u32, kind: u32, data: [*]const u8, length: usize, timeout_ns: u64, out_id: *u64) u8 {
    if (kind != 0 and kind != 2 and kind != 10) return 3;
    out_id.* = runtime.submit(route, @enumFromInt(kind), data[0..length], timeout_ns) catch |err| return status(err);
    return 0;
}
export fn dz_runtime_send_signal(runtime: *dz.Runtime, route: u32, data: [*]const u8, length: usize) u8 {
    runtime.sendSignal(route, data[0..length]) catch |err| return status(err);
    return 0;
}
export fn dz_runtime_callback_reply(runtime: *dz.Runtime, id: u64, callback_id: u32, code: u32, data: [*]const u8, length: usize) u8 {
    runtime.callbackReply(id, callback_id, code, data[0..length]) catch |err| return status(err);
    return 0;
}
export fn dz_runtime_cancel(runtime: *dz.Runtime, id: u64) u8 {
    runtime.cancel(id) catch |err| return status(err);
    return 0;
}
export fn dz_runtime_poll(runtime: *dz.Runtime, output: [*]RuntimeFrame, capacity: usize) usize {
    return runtime.poll(output[0..capacity]);
}
export fn dz_buffer_retain(owner: *anyopaque) void {
    const buffer: *dz.Buffer = @ptrCast(@alignCast(owner));
    buffer.retain();
}
export fn dz_buffer_release(owner: *anyopaque) void {
    const buffer: *dz.Buffer = @ptrCast(@alignCast(owner));
    buffer.release();
}
export fn dz_sync_sum(a: i64, b: i64, output: *i64) u8 {
    const sum = @addWithOverflow(a, b);
    if (sum[1] != 0) return 3;
    output.* = sum[0];
    return 0;
}

export fn dz_schema_fingerprint() u32 {
    return @import("models").schema_fingerprint;
}
export fn dz_runtime_grant(runtime: *dz.Runtime, id: u64) u8 {
    runtime.grant(id) catch |err| return status(err);
    return 0;
}
export fn dz_runtime_ready_to_destroy(runtime: *dz.Runtime) bool {
    return runtime.stopping.load(.acquire) and runtime.exited.load(.acquire) == runtime.started;
}

pub const RuntimeStats = extern struct {
    submitted: u64,
    delivered: u64,
    wakes: u64,
    copied_bytes: u64,
    log_drops: u64,
    input_messages: usize,
    output_messages: usize,
    input_bytes: usize,
    output_bytes: usize,
};
export fn dz_runtime_stats(runtime: *dz.Runtime, output: *RuntimeStats) void {
    runtime.mutex.lock();
    defer runtime.mutex.unlock();
    output.* = .{ .submitted = runtime.submitted, .delivered = runtime.delivered, .wakes = runtime.wakes, .copied_bytes = runtime.copied_bytes, .log_drops = runtime.log_drops.load(.acquire), .input_messages = runtime.input.count, .output_messages = runtime.output.count, .input_bytes = runtime.input.bytes, .output_bytes = runtime.output.bytes };
}
export fn dz_live_buffers() usize {
    return dz.buffer_metrics.live_buffers.load(.acquire);
}
export fn dz_live_buffer_bytes() usize {
    return dz.buffer_metrics.live_bytes.load(.acquire);
}

export fn dz_buffer_capacity(owner: *anyopaque) usize {
    const buffer: *dz.Buffer = @ptrCast(@alignCast(owner));
    return buffer.storage.len;
}

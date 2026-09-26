const std = @import("std");
const api = if (@import("builtin").is_test) @import("api_test.zig") else @import("../api.zig");
const Mutex = @import("../mutex.zig").Mutex;
const buffers = @import("buffer.zig");
const frames = @import("frame.zig");
const handles = @import("handles.zig");
const events = @import("event.zig");
const CancellationToken = @import("cancellation.zig").CancellationToken;
const Frame = frames.Frame;
fn isTerminal(kind: frames.Kind) bool {
    return kind == .result or kind == .stream_end or kind == .failure;
}
const Task = struct {
    allocator: std.mem.Allocator,
    route: u32,
    streaming: bool = false,
    one_way: bool = false,
    dispatch_mutex: Mutex = .{},
    continuation: ?*const fn (*Context, *anyopaque) anyerror!void = null,
    state: ?*anyopaque = null,
    release_state: ?*const fn (*anyopaque) void = null,
    scheduled: bool = false,

    credit: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),
    token: CancellationToken = .{},
    finished: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    fn destroy(self: *Task) void {
        if (self.release_state) |release| release(self.state.?);
        self.allocator.destroy(self);
    }
};
const Tasks = handles.HandleTable(*Task, Task.destroy);

pub const Options = struct {
    messages: usize = 256,
    bytes: usize = 8 * 1024 * 1024,
    tasks: u32 = 256,
    workers: usize = 1,
    wake: *const fn (i64) bool = api.wake,
};

/// Application handlers may execute concurrently when workers > 1.
/// A handler must complete/fail the call or deliberately defer it (e.g. callback).
pub const Dispatch = *const fn (*Context, frames.Kind, u32, []const u8) anyerror!void;

pub const Context = struct {
    runtime: *Runtime,
    id: u64,
    task: *Task,

    pub fn check(self: *Context) !void {
        if (self.runtime.stopping.load(.acquire)) return error.Closed;
        try self.task.token.check(self.runtime.clock.monotonicNs());
    }
    pub fn operation(self: *const Context) u32 {
        return self.task.route;
    }
    pub fn isStream(self: *const Context) bool {
        return self.task.streaming;
    }
    pub fn isSignal(self: *const Context) bool {
        return self.task.one_way;
    }
    pub fn application(self: *const Context) ?*anyopaque {
        return self.runtime.application;
    }

    fn send(self: *Context, kind: frames.Kind, route: u32, code: u32, bytes: []const u8) !void {
        try self.check();
        const buffer = try self.runtime.buffers.copy(bytes);
        errdefer buffer.release();
        try self.runtime.emit(.{ .id = self.id, .route = route, .kind = kind, .code = code, .buffer = buffer }, self.task);
    }
    pub fn item(self: *Context, bytes: []const u8) !void {
        try self.check();
        if (self.task.credit.cmpxchgStrong(1, 0, .acq_rel, .acquire) != null) return error.NoCredit;
        self.send(.stream_item, self.task.route, 0, bytes) catch |err| {
            self.task.credit.store(1, .release);
            return err;
        };
    }
    pub fn signal(self: *Context, route: u32, bytes: []const u8) !void {
        try self.send(.signal, route, 0, bytes);
    }
    pub fn callback(self: *Context, callback_id: u32, bytes: []const u8) !void {
        if (self.task.one_way) return error.InvalidOperationMode;
        try self.send(.callback, callback_id, 0, bytes);
    }

    fn terminal(self: *Context, kind: frames.Kind, code: u32, bytes: []const u8) !void {
        if (self.task.one_way) return;
        if (self.task.finished.cmpxchgStrong(false, true, .acq_rel, .acquire) != null) return error.AlreadyCompleted;
        self.send(kind, self.task.route, code, bytes) catch |err| {
            self.task.finished.store(false, .release);
            return err;
        };
    }
    pub fn complete(self: *Context, bytes: []const u8) !void {
        try self.terminal(.result, 0, bytes);
    }
    pub fn end(self: *Context) !void {
        try self.check();
        if (self.task.credit.cmpxchgStrong(1, 0, .acq_rel, .acquire) != null) return error.NoCredit;
        self.terminal(.stream_end, 0, &.{}) catch |err| {
            self.task.credit.store(1, .release);
            return err;
        };
    }
    /// Transfers state ownership to the task. Resume once per production credit.
    /// The callback emits at most one item, or ends the stream, then returns.
    pub fn deferStream(self: *Context, state: *anyopaque, resumeStream: *const fn (*Context, *anyopaque) anyerror!void, release: *const fn (*anyopaque) void) !void {
        if (!self.task.streaming or self.task.continuation != null) return error.InvalidOperationMode;
        self.runtime.mutex.lock();
        self.task.state = state;
        self.task.continuation = resumeStream;
        self.task.release_state = release;
        self.runtime.mutex.unlock();
        try self.runtime.schedule(self.id, self.task);
    }
    pub fn fail(self: *Context, code: u32, message: []const u8) !void {
        try self.terminal(.failure, code, message);
    }
};

/// Bounded executor with independent Dart notification and native worker wakes.
/// Input bytes are copied once. Output buffers transfer to caller-owned batches.
pub const Runtime = struct {
    allocator: std.mem.Allocator,
    mutex: Mutex = .{},
    input: frames.Queue,
    output: frames.Queue,
    pending_output: frames.Queue,
    regular_output_limit: usize,
    ready: frames.Queue,
    prefer_ready: bool = false,
    tasks: Tasks,
    buffers: *buffers.Pool,
    work: events.Event,
    clock: events.Clock,
    threads: []std.Thread,
    started: usize = 0,
    exited: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
    stopping: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    port: i64,
    wake: *const fn (i64) bool,
    wake_pending: bool = false,
    dispatch: Dispatch,
    application: ?*anyopaque,
    submitted: u64 = 0,
    delivered: u64 = 0,
    wakes: u64 = 0,
    copied_bytes: u64 = 0,
    log_drops: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),

    pub fn create(allocator: std.mem.Allocator, port: i64, options: Options, dispatch: Dispatch, application: ?*anyopaque) !*Runtime {
        if (port <= 0 or options.workers == 0 or options.workers > 64) return error.InvalidLimits;
        const self = try allocator.create(Runtime);
        errdefer allocator.destroy(self);
        var input = try frames.Queue.init(allocator, options.messages, options.bytes);
        errdefer input.deinit(allocator);
        var output = try frames.Queue.init(allocator, options.messages, options.bytes);
        errdefer output.deinit(allocator);
        const pending_slots = try std.math.add(usize, options.messages, options.tasks);
        // Keep a separate, bounded reserve for results when the regular output
        // queue is full. A reserve proportional to the task count lets queued
        // payloads grow far beyond the configured byte budget.
        var pending_output = try frames.Queue.init(allocator, pending_slots, options.bytes);
        errdefer pending_output.deinit(allocator);
        var ready = try frames.Queue.init(allocator, options.tasks, options.tasks);
        errdefer ready.deinit(allocator);
        var tasks = try Tasks.init(allocator, options.tasks);
        errdefer tasks.deinit();
        const clock = try events.Clock.init();
        const work = try events.Event.init();
        errdefer work.deinit();
        const pool = try buffers.Pool.create(allocator, options.messages, options.bytes);
        errdefer pool.close();
        const threads = try allocator.alloc(std.Thread, options.workers);
        errdefer allocator.free(threads);
        self.* = .{ .allocator = allocator, .input = input, .output = output, .pending_output = pending_output, .regular_output_limit = options.messages, .ready = ready, .tasks = tasks, .buffers = pool, .work = work, .clock = clock, .threads = threads, .port = port, .wake = options.wake, .dispatch = dispatch, .application = application };
        errdefer {
            self.stop();
            for (self.threads[0..self.started]) |thread| thread.join();
        }
        for (threads) |*thread| {
            thread.* = try std.Thread.spawn(.{}, run, .{self});
            self.started += 1;
        }
        return self;
    }

    fn wakeDartLocked(self: *Runtime) void {
        if (self.wake_pending) return;
        self.wake_pending = self.wake(self.port);
        self.wakes += 1;
        if (!self.wake_pending) self.stop();
    }

    pub fn acknowledge(self: *Runtime) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.wake_pending = false;
    }

    pub fn submit(self: *Runtime, route: u32, kind: frames.Kind, bytes: []const u8, timeout_ns: u64) !u64 {
        if (self.stopping.load(.acquire)) return error.Closed;
        if (kind != .call and kind != .signal and kind != .stream_start) return error.InvalidKind;
        if (bytes.len > self.input.max_bytes) return error.TooLarge;
        const task = try self.allocator.create(Task);
        task.* = .{ .allocator = self.allocator, .route = route, .streaming = kind == .stream_start };
        if (timeout_ns != 0) task.token.deadline_ns = self.clock.monotonicNs() +| timeout_ns;
        const id = self.tasks.insert(task) catch |err| {
            task.destroy();
            return err;
        };
        errdefer self.tasks.remove(id) catch {};
        const buffer = try self.buffers.copy(bytes);
        errdefer buffer.release();
        try self.enqueue(.{ .id = id, .route = route, .kind = kind, .buffer = buffer });
        return id;
    }

    /// Admits a one-way event without allocating a request or awaiting a result.
    pub fn sendSignal(self: *Runtime, route: u32, bytes: []const u8) !void {
        if (bytes.len > self.input.max_bytes) return error.TooLarge;
        const buffer = try self.buffers.copy(bytes);
        errdefer buffer.release();
        try self.enqueue(.{ .route = route, .kind = .signal, .buffer = buffer });
    }

    fn schedule(self: *Runtime, id: u64, task: *Task) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.stopping.load(.acquire) or task.token.cancelled.load(.acquire)) return;
        if (task.scheduled or task.finished.load(.acquire) or task.continuation == null or task.credit.load(.acquire) == 0) return;
        const buffer = try self.buffers.copy(&.{});
        errdefer buffer.release();
        try self.ready.put(.{ .id = id, .route = task.route, .kind = .resume_stream, .buffer = buffer });
        task.scheduled = true;
        self.work.signal();
    }

    pub fn callbackReply(self: *Runtime, id: u64, callback_id: u32, code: u32, bytes: []const u8) !void {
        var lease = try self.tasks.acquire(id);
        defer lease.release();
        if (bytes.len > self.input.max_bytes) return error.TooLarge;
        const buffer = try self.buffers.copy(bytes);
        errdefer buffer.release();
        try self.enqueue(.{ .id = id, .route = callback_id, .kind = .callback_result, .code = code, .buffer = buffer });
    }

    fn enqueue(self: *Runtime, frame: Frame) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.stopping.load(.acquire)) return error.Closed;
        try self.input.put(frame);
        self.submitted += 1;
        self.copied_bytes += frame.buffer.bytes.len;
        self.work.signal();
    }

    fn emit(self: *Runtime, frame: Frame, task: ?*Task) !void {
        if (frame.buffer.bytes.len > self.output.max_bytes) return error.TooLarge;
        if (task) |active| try active.token.check(self.clock.monotonicNs());
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.stopping.load(.acquire)) return error.Closed;
        const terminal = isTerminal(frame.kind);
        if (self.pending_output.count != 0) {
            if (!terminal and self.pending_output.count >= self.regular_output_limit) return error.Full;
            try self.pending_output.put(frame);
        } else {
            self.output.put(frame) catch |err| {
                if (err != error.Full) return err;
                if (!terminal and self.pending_output.count >= self.regular_output_limit) return error.Full;
                try self.pending_output.put(frame);
            };
        }
        self.copied_bytes += frame.buffer.bytes.len;
        self.wakeDartLocked();
    }

    /// Nonblocking unsolicited signal; Full leaves the caller's bytes untouched.
    pub fn trySignal(self: *Runtime, route: u32, bytes: []const u8) !void {
        if (bytes.len > self.output.max_bytes) return error.TooLarge;
        const buffer = try self.buffers.copy(bytes);
        errdefer buffer.release();
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.stopping.load(.acquire)) return error.Closed;
        if (self.pending_output.count != 0) return error.Full;
        try self.output.put(.{ .kind = .signal, .route = route, .buffer = buffer });
        self.copied_bytes += bytes.len;
        self.wakeDartLocked();
    }

    /// Fills preallocated descriptors; their buffers remain valid until release.
    pub fn poll(self: *Runtime, descriptors: anytype) usize {
        self.mutex.lock();
        var count: usize = 0;
        while (count < descriptors.len) : (count += 1) {
            const frame = self.output.take() orelse self.pending_output.take() orelse break;
            descriptors[count] = .{ .id = frame.id, .route = frame.route, .kind = @intFromEnum(frame.kind), .code = frame.code, .length = frame.buffer.bytes.len, .data = frame.buffer.bytes.ptr, .owner = frame.buffer };
            self.delivered += 1;
        }
        self.mutex.unlock();
        for (descriptors[0..count]) |frame| {
            if (isTerminal(@enumFromInt(frame.kind))) self.tasks.remove(frame.id) catch {};
        }
        return count;
    }

    pub fn cancel(self: *Runtime, id: u64) !void {
        var lease = try self.tasks.acquire(id);
        defer lease.release();
        lease.value.*.token.cancel();
        try self.tasks.remove(id);
        self.mutex.lock();
        self.ready.remove(id);
        self.output.remove(id);
        self.pending_output.remove(id);
        self.mutex.unlock();
    }

    pub fn grant(self: *Runtime, id: u64) !void {
        var lease = try self.tasks.acquire(id);
        defer lease.release();
        lease.value.*.credit.store(1, .release);
        try self.schedule(id, lease.value.*);
    }

    fn run(self: *Runtime) void {
        defer _ = self.exited.fetchAdd(1, .release);
        while (!self.stopping.load(.acquire)) {
            self.work.wait();
            if (self.stopping.load(.acquire)) break;
            self.mutex.lock();
            const frame = if (self.prefer_ready) (self.ready.take() orelse self.input.take()) else (self.input.take() orelse self.ready.take());
            self.prefer_ready = !self.prefer_ready;
            if (frame != null) self.wakeDartLocked(); // Input capacity changed.
            self.mutex.unlock();
            const message = frame orelse continue;
            defer message.deinit();
            if (message.kind == .signal and message.id == 0) {
                var task: Task = .{ .allocator = self.allocator, .route = message.route, .one_way = true };
                var context: Context = .{ .runtime = self, .id = 0, .task = &task };
                self.dispatch(&context, .signal, message.route, message.buffer.bytes) catch |err| {
                    self.reportSignalError(message.route, err);
                };
                continue;
            }
            var lease = self.tasks.acquire(message.id) catch continue;
            defer lease.release();
            lease.value.*.dispatch_mutex.lock();
            defer lease.value.*.dispatch_mutex.unlock();
            var context: Context = .{ .runtime = self, .id = message.id, .task = lease.value.* };
            context.check() catch |err| {
                self.finishError(&context, err);
                continue;
            };
            if (message.kind == .resume_stream) {
                if (context.task.continuation) |resumeStream| {
                    resumeStream(&context, context.task.state.?) catch |err| self.finishError(&context, err);
                }
                self.mutex.lock();
                context.task.scheduled = false;
                self.mutex.unlock();
                self.schedule(message.id, context.task) catch |err| self.finishError(&context, err);
                continue;
            }
            if (message.code != 0) {
                context.fail(message.code, message.buffer.bytes) catch |err| {
                    self.finishError(&context, err);
                };
                continue;
            }
            self.dispatch(&context, message.kind, message.route, message.buffer.bytes) catch |err| {
                self.finishError(&context, err);
            };
        }
    }

    fn finishError(self: *Runtime, context: *Context, err: anyerror) void {
        if (context.task.finished.swap(true, .acq_rel)) return;
        if (self.stopping.load(.acquire) or context.task.token.cancelled.load(.acquire)) {
            self.tasks.remove(context.id) catch {};
            return;
        }
        const buffer = self.buffers.copy(@errorName(err)) catch {
            self.tasks.remove(context.id) catch {};
            self.stop();
            return;
        };
        // Deadline failure must still be deliverable after the token expires.
        self.emit(.{ .id = context.id, .route = context.operation(), .kind = .failure, .code = if (err == error.DeadlineExceeded) 2 else 1, .buffer = buffer }, null) catch {
            buffer.release();
            self.tasks.remove(context.id) catch {};
            self.stop();
        };
    }

    /// Stops admission and wakes every worker. Does not join; safe on any thread.
    fn reportSignalError(self: *Runtime, route: u32, err: anyerror) void {
        const message = @errorName(err);
        var bytes: [264]u8 = undefined;
        const length = @min(message.len, 256);
        std.mem.writeInt(u32, bytes[0..4], route, .little);
        std.mem.writeInt(u32, bytes[4..8], @intCast(length), .little);
        @memcpy(bytes[8..][0..length], message[0..length]);
        self.trySignal(0xfffffff1, bytes[0 .. length + 8]) catch {
            _ = self.log_drops.fetchAdd(1, .monotonic);
        };
    }

    pub fn stop(self: *Runtime) void {
        if (self.stopping.swap(true, .acq_rel)) return;
        _ = self.wake(self.port);
        for (0..self.threads.len) |_| {
            self.work.signal();
        }
    }

    /// Call from the owner after all external FFI users have stopped.
    /// Handlers must cooperate with cancellation; arbitrary application work
    /// cannot be forcibly interrupted. Output buffers already leased remain valid.
    pub fn destroy(self: *Runtime) void {
        self.stop();
        for (self.threads[0..self.started]) |thread| thread.join();
        self.tasks.deinit();
        self.input.deinit(self.allocator);
        self.output.deinit(self.allocator);
        self.pending_output.deinit(self.allocator);
        self.ready.deinit(self.allocator);
        self.work.deinit();
        self.buffers.close();
        self.allocator.free(self.threads);
        self.allocator.destroy(self);
    }
};

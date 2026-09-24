const std = @import("std");
const frames = @import("frame.zig");
const buffers = @import("buffer.zig");
const handles = @import("handles.zig");
const Mutex = @import("../mutex.zig").Mutex;
const allocator = std.heap.wasm_allocator;
const Task = struct {
    route: u32,
    streaming: bool,
    one_way: bool = false,
    credit: bool = false,
    finished: bool = false,
    scheduled: bool = false,
    continuation: ?*const fn (*Context, *anyopaque) anyerror!void = null,
    state: ?*anyopaque = null,
    release: ?*const fn (*anyopaque) void = null,
    fn destroy(self: *Task) void {
        if (self.release) |release| release(self.state.?);
        allocator.destroy(self);
    }
};
const Tasks = handles.HandleTable(*Task, Task.destroy);
pub const Options = struct { messages: usize = 256, bytes: usize = 8 * 1024 * 1024, tasks: u32 = 256, workers: usize = 1 };
pub const Dispatch = *const fn (*Context, frames.Kind, u32, []const u8) anyerror!void;
pub const Context = struct {
    runtime: *Runtime,
    id: u64,
    task: *Task,
    pub fn check(self: *Context) !void {
        if (self.runtime.stopping.load(.acquire)) return error.Closed;
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
        try self.runtime.output.put(.{ .id = self.id, .route = route, .kind = kind, .code = code, .buffer = buffer });
        self.runtime.copied_bytes += bytes.len;
    }
    pub fn signal(self: *Context, route: u32, bytes: []const u8) !void {
        try self.send(.signal, route, 0, bytes);
    }
    pub fn callback(self: *Context, id: u32, bytes: []const u8) !void {
        if (self.task.one_way) return error.InvalidOperationMode;
        try self.send(.callback, id, 0, bytes);
    }
    fn terminal(self: *Context, kind: frames.Kind, code: u32, bytes: []const u8) !void {
        if (self.task.one_way) return;
        if (self.task.finished) return error.AlreadyCompleted;
        try self.send(kind, self.operation(), code, bytes);
        self.task.finished = true;
        try self.runtime.tasks.remove(self.id);
    }
    pub fn complete(self: *Context, bytes: []const u8) !void {
        try self.terminal(.result, 0, bytes);
    }
    pub fn fail(self: *Context, code: u32, bytes: []const u8) !void {
        try self.terminal(.failure, code, bytes);
    }
    pub fn item(self: *Context, bytes: []const u8) !void {
        if (!self.task.credit) return error.NoCredit;
        try self.send(.stream_item, self.operation(), 0, bytes);
        self.task.credit = false;
    }
    pub fn end(self: *Context) !void {
        try self.terminal(.stream_end, 0, &.{});
    }
    pub fn deferStream(self: *Context, state: *anyopaque, resumeStream: *const fn (*Context, *anyopaque) anyerror!void, release: *const fn (*anyopaque) void) !void {
        if (!self.task.streaming or self.task.continuation != null) return error.InvalidOperationMode;
        self.task.state = state;
        self.task.continuation = resumeStream;
        self.task.release = release;
        try self.runtime.schedule(self.id, self.task);
    }
};

/// Cooperative single-thread runtime, pumped by the browser event loop.
/// Handlers must return promptly; CPU work should be split into continuations.
pub const Runtime = struct {
    input: frames.Queue,
    output: frames.Queue,
    ready: frames.Queue,
    prefer_ready: bool = false,
    pending_failure: ?struct { id: u64, err: anyerror } = null,
    tasks: Tasks,
    buffers: *buffers.Pool,
    application: ?*anyopaque,
    dispatch: Dispatch,
    stopping: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    log_drops: @import("single_thread_value.zig").Value(u64) = @import("single_thread_value.zig").Value(u64).init(0),
    mutex: Mutex = .{},
    submitted: u64 = 0,
    delivered: u64 = 0,
    wakes: u64 = 0,
    copied_bytes: u64 = 0,
    pub fn create(_: std.mem.Allocator, _: i64, options: Options, dispatch: Dispatch, application: ?*anyopaque) !*Runtime {
        const self = try allocator.create(Runtime);
        errdefer allocator.destroy(self);
        var input = try frames.Queue.init(allocator, options.messages, options.bytes);
        errdefer input.deinit(allocator);
        var output = try frames.Queue.init(allocator, options.messages, options.bytes);
        errdefer output.deinit(allocator);
        var ready = try frames.Queue.init(allocator, options.tasks, options.tasks);
        errdefer ready.deinit(allocator);
        var tasks = try Tasks.init(allocator, options.tasks);
        errdefer tasks.deinit();
        const pool = try buffers.Pool.create(allocator, options.messages, options.bytes);
        self.* = .{ .input = input, .output = output, .ready = ready, .tasks = tasks, .buffers = pool, .dispatch = dispatch, .application = application };
        return self;
    }
    fn enqueue(self: *Runtime, frame: frames.Frame) !void {
        if (self.stopping.load(.acquire)) return error.Closed;
        try self.input.put(frame);
        self.submitted += 1;
        self.copied_bytes += frame.buffer.bytes.len;
    }
    pub fn submit(self: *Runtime, route: u32, kind: frames.Kind, bytes: []const u8, _: u64) !u64 {
        const task = try allocator.create(Task);
        task.* = .{ .route = route, .streaming = kind == .stream_start };
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
    pub fn sendSignal(self: *Runtime, route: u32, bytes: []const u8) !void {
        const buffer = try self.buffers.copy(bytes);
        errdefer buffer.release();
        try self.enqueue(.{ .route = route, .kind = .signal, .buffer = buffer });
    }
    pub fn callbackReply(self: *Runtime, id: u64, route: u32, code: u32, bytes: []const u8) !void {
        var lease = try self.tasks.acquire(id);
        defer lease.release();
        const buffer = try self.buffers.copy(bytes);
        errdefer buffer.release();
        try self.enqueue(.{ .id = id, .route = route, .kind = .callback_result, .code = code, .buffer = buffer });
    }
    pub fn trySignal(self: *Runtime, route: u32, bytes: []const u8) !void {
        if (self.stopping.load(.acquire)) return error.Closed;
        const buffer = try self.buffers.copy(bytes);
        errdefer buffer.release();
        try self.output.put(.{ .route = route, .kind = .signal, .buffer = buffer });
        self.copied_bytes += bytes.len;
    }
    fn schedule(self: *Runtime, id: u64, task: *Task) !void {
        if (task.scheduled or !task.credit or task.continuation == null) return;
        const buffer = try self.buffers.copy(&.{});
        errdefer buffer.release();
        try self.ready.put(.{ .id = id, .route = task.route, .kind = .resume_stream, .buffer = buffer });
        task.scheduled = true;
    }
    pub fn grant(self: *Runtime, id: u64) !void {
        var lease = try self.tasks.acquire(id);
        defer lease.release();
        lease.value.*.credit = true;
        try self.schedule(id, lease.value.*);
    }
    pub fn cancel(self: *Runtime, id: u64) !void {
        try self.tasks.remove(id);
        self.ready.remove(id);
        self.input.remove(id);
    }
    fn failure(self: *Runtime, context: *Context, err: anyerror) void {
        if (context.task.finished) return;
        context.fail(1, @errorName(err)) catch |failure_err| {
            if (failure_err == error.Full) {
                // Keep only the fixed-size failure metadata while Dart drains.
                // Pump never runs another invocation before flushing this slot.
                self.pending_failure = .{ .id = context.id, .err = err };
            } else self.stop();
        };
    }
    pub fn pump(self: *Runtime, budget: usize) usize {
        var ran: usize = 0;
        while (ran < budget and !self.stopping.load(.acquire)) : (ran += 1) {
            // Let Dart drain output before running another application invocation.
            if (self.output.count != 0) break;
            if (self.pending_failure) |failure_info| {
                self.pending_failure = null;
                var failed = self.tasks.acquire(failure_info.id) catch continue;
                defer failed.release();
                var failed_context: Context = .{ .runtime = self, .id = failure_info.id, .task = failed.value.* };
                self.failure(&failed_context, failure_info.err);
                continue;
            }
            const message = (if (self.prefer_ready) (self.ready.take() orelse self.input.take()) else (self.input.take() orelse self.ready.take())) orelse break;
            self.prefer_ready = !self.prefer_ready;
            defer message.deinit();
            if (message.kind == .signal and message.id == 0) {
                var task: Task = .{ .route = message.route, .streaming = false, .one_way = true };
                var context: Context = .{ .runtime = self, .id = 0, .task = &task };
                self.dispatch(&context, .signal, message.route, message.buffer.bytes) catch |err| {
                    self.reportSignalError(message.route, err);
                };
                continue;
            }
            var lease = self.tasks.acquire(message.id) catch continue;
            defer lease.release();
            var context: Context = .{ .runtime = self, .id = message.id, .task = lease.value.* };
            if (message.kind == .resume_stream) {
                context.task.scheduled = false;
                if (context.task.continuation) |resumeStream| resumeStream(&context, context.task.state.?) catch |err| self.failure(&context, err);
            } else if (message.code != 0) {
                context.fail(message.code, message.buffer.bytes) catch |err| self.failure(&context, err);
            } else {
                self.dispatch(&context, message.kind, message.route, message.buffer.bytes) catch |err| self.failure(&context, err);
            }
        }
        return ran;
    }
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
        self.stopping.store(true, .release);
    }
    pub fn destroy(self: *Runtime) void {
        self.stop();
        self.tasks.deinit();
        self.input.deinit(allocator);
        self.output.deinit(allocator);
        self.ready.deinit(allocator);
        self.buffers.close();
        allocator.destroy(self);
    }
};

pub const allocator = @import("std").heap.wasm_allocator;
pub const HandleTable = @import("runtime/handles.zig").HandleTable;
pub const codec = @import("runtime/codec.zig");
pub const protocol = @import("runtime/protocol.zig");
pub const handlers = @import("runtime/handlers.zig");
pub const events = @import("runtime/events.zig");
pub const frames = @import("runtime/frame.zig");
pub const Runtime = @import("runtime/runtime_web.zig").Runtime;
pub const Context = @import("runtime/runtime_web.zig").Context;
pub const Buffer = @import("runtime/buffer.zig").Buffer;
pub const buffer_metrics = @import("runtime/buffer.zig");
pub const logging = @import("runtime/logging_web.zig");

pub const Atomic = @import("runtime/single_thread_value.zig").Value;

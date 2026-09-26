//! Runtime-independent primitives for native requests handled by Dart.
pub const api = @import("api.zig");
pub const Bridge = @import("bridge.zig").Bridge;
pub const Limits = @import("bridge.zig").Limits;
pub const Notifier = @import("bridge.zig").Notifier;
pub const Kind = @import("mailbox.zig").Kind;
pub const Packet = @import("mailbox.zig").Packet;

pub const Buffer = @import("runtime/buffer.zig").Buffer;
pub const HandleTable = @import("runtime/handles.zig").HandleTable;
pub const codec = @import("runtime/codec.zig");
pub const protocol = @import("runtime/protocol.zig");
pub const handlers = @import("runtime/handlers.zig");
pub const events = @import("runtime/events.zig");
pub const frames = @import("runtime/frame.zig");
pub const Runtime = @import("runtime/runtime.zig").Runtime;
pub const Context = @import("runtime/runtime.zig").Context;
pub const buffer_metrics = @import("runtime/buffer.zig");
pub const logging = @import("runtime/logging.zig");

pub const allocator = @import("std").heap.c_allocator;

pub const Atomic = @import("std").atomic.Value;

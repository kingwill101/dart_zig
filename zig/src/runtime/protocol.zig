/// UTF-8 text carried as a length-prefixed protocol value.
/// Decoded bytes borrow their input frame.
pub const Text = struct {
    bytes: []const u8,
};

/// A message with no encoded payload.
pub const Empty = struct {};

/// Route modes used by Zig protocol declarations.
pub const RouteKind = enum { call, stream, signal, state };

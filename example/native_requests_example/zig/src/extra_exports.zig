const dz = @import("dart_zig");
const demo = @import("demo");

/// Submits the example request from a native thread.
export fn dz_demo_submit(bridge: *dz.Bridge) u64 {
    return demo.submit(bridge);
}

/// Cancels an example request from Zig.
export fn dz_demo_cancel(bridge: *dz.Bridge, id: u64) bool {
    return demo.cancel(bridge, id);
}

/// Consumes a reply from Dart in the example's native asset.
export fn dz_demo_consume(bridge: *dz.Bridge, id: u64, kind: u8, bytes: [*]const u8, len: usize) bool {
    return demo.consume(bridge, id, kind, bytes, len);
}

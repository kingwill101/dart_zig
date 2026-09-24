const Mutex = @import("mutex.zig").Mutex;
const c = @cImport({
    @cInclude("dart_api_dl.h");
});
var mutex: Mutex = .{};
var ready = false;

/// Initializes the dynamic API once per native library, before creating bridges.
pub fn initialize(data: ?*anyopaque) bool {
    mutex.lock();
    defer mutex.unlock();
    if (ready) return true;
    if (data == null or c.Dart_InitializeApiDL(data) != 0) return false;
    ready = c.Dart_PostInteger_DL != null;
    return ready;
}

/// Posts a payload-free wake notification; false means the Dart port is gone.
pub fn wake(port: i64) bool {
    return c.Dart_PostInteger_DL.?(port, 0);
}

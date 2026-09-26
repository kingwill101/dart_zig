/// Stable FNV-1a route number derived from a Zig declaration name.
pub fn fromName(comptime name: []const u8) u32 {
    comptime var hash: u32 = 2166136261;
    inline for (name) |byte| hash = (hash ^ byte) *% 16777619;
    if (hash == 0 or hash >= 0xfffffff0) @compileError("Handler route is reserved: " ++ name);
    return hash;
}

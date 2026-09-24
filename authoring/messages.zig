//! Optional authoring example; not used by the bundled application schema.
pub const Ping = struct { text: []const u8, count: i64, payload: []const u8 };
pub const models = .{ .Ping = Ping };
// Byte slices default to UTF-8 strings; explicitly mark binary fields.
pub const field_types = .{ .@"Ping.payload" = "bytes" };
pub const metadata =
    \\{"version":1,"enums":{},"unions":{},"operations":[{"id":1,"name":"ping","input":"Ping","output":"Ping"}],"signals":[],"callbacks":{}}
;

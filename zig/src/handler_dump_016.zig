const std = @import("std");
const dump = @import("handler_dump.zig");

pub fn main(init: std.process.Init) !void {
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &buffer);
    try dump.write(&stdout.interface);
    try stdout.flush();
}

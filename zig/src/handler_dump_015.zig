const std = @import("std");
const dump = @import("handler_dump.zig");

pub fn main() !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    try dump.write(stdout);
}

const std = @import("std");

/// Synchronous example operation outside the session protocol.
export fn dz_sync_sum(a: i64, b: i64, output: *i64) u8 {
    const sum = @addWithOverflow(a, b);
    if (sum[1] != 0) return 3;
    output.* = sum[0];
    return 0;
}

/// Web-friendly synchronous example operation.
export fn dz_web_sum(a: f64, b: f64) f64 {
    if (@abs(a) > 9007199254740991 or @abs(b) > 9007199254740991) return std.math.nan(f64);
    const sum = @addWithOverflow(@as(i64, @intFromFloat(a)), @as(i64, @intFromFloat(b)));
    if (sum[1] != 0 or sum[0] > 9007199254740991 or sum[0] < -9007199254740991) return std.math.nan(f64);
    return @floatFromInt(sum[0]);
}

/// Starts a credited native stream of squares.
pub fn squares(count: u32) !Squares {
    if (count > 1000) return error.TooLarge;
    return .{ .count = count };
}

pub const Squares = struct {
    pub const Item = i64;

    count: u32,
    index: u32 = 0,

    /// Called once per Dart stream credit.
    pub fn next(self: *Squares) !?Item {
        if (self.index == self.count) return null;
        const value: i64 = self.index;
        self.index += 1;
        return value * value;
    }
};

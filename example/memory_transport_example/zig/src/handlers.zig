pub const AddRequest = struct { a: i64, b: i64 };

pub fn add(request: AddRequest) !i64 {
    const sum = @addWithOverflow(request.a, request.b);
    if (sum[1] != 0) return error.Overflow;
    return sum[0];
}

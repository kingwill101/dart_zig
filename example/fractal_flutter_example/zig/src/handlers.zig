const std = @import("std");

const tile_rows = 16;

pub const RenderRequest = struct {
    width: u32,
    height: u32,
    firstRow: u32,
    lastRow: u32,
    maxIterations: u32,
    centerX: f64,
    centerY: f64,
    pixelScale: f64,
};

pub const Tile = struct {
    row: u32,
    rgba: []const u8,
    steps: u32,
};

pub const Render = struct {
    pub const Item = Tile;

    request: RenderRequest,
    pixels: []u8,
    next_row: u32 = 0,

    /// One credited stream item computes at most 16 rows on a native worker.
    pub fn next(self: *Render) !?Tile {
        if (self.next_row == self.request.lastRow) return null;
        const row = self.next_row;
        const rows = @min(tile_rows, self.request.lastRow - row);
        const length: usize = @as(usize, self.request.width) * @as(usize, rows) * 4;
        const rgba = self.pixels[0..length];
        var steps: u32 = 0;

        for (0..rows) |local_y| {
            const y = row + @as(u32, @intCast(local_y));
            const cy = self.request.centerY +
                (@as(f64, @floatFromInt(y)) - @as(f64, @floatFromInt(self.request.height)) / 2.0) * self.request.pixelScale;
            for (0..self.request.width) |x| {
                const cx = self.request.centerX +
                    (@as(f64, @floatFromInt(x)) - @as(f64, @floatFromInt(self.request.width)) / 2.0) * self.request.pixelScale;
                const shifted_x = cx - 0.25;
                const cy_squared = cy * cy;
                const q = shifted_x * shifted_x + cy_squared;
                const bulb_x = cx + 1.0;
                const inside = q * (q + shifted_x) <= 0.25 * cy_squared or
                    bulb_x * bulb_x + cy_squared <= 0.0625;

                var iteration: u32 = self.request.maxIterations;
                if (!inside) {
                    var zx: f64 = 0;
                    var zy: f64 = 0;
                    var zx_squared: f64 = 0;
                    var zy_squared: f64 = 0;
                    iteration = 0;
                    while (zx_squared + zy_squared <= 4.0 and iteration < self.request.maxIterations) : (iteration += 1) {
                        zy = 2.0 * zx * zy + cy;
                        zx = zx_squared - zy_squared + cx;
                        zx_squared = zx * zx;
                        zy_squared = zy * zy;
                    }
                    steps += iteration;
                }

                const offset = (local_y * @as(usize, self.request.width) + x) * 4;
                if (iteration == self.request.maxIterations) {
                    rgba[offset] = 8;
                    rgba[offset + 1] = 13;
                    rgba[offset + 2] = 28;
                } else {
                    const phase = iteration *% 11;
                    rgba[offset] = wave(phase +% 35);
                    rgba[offset + 1] = wave(phase +% 185);
                    rgba[offset + 2] = wave(phase +% 310);
                }
                rgba[offset + 3] = 255;
            }
        }

        self.next_row += rows;
        return .{ .row = row, .rgba = rgba, .steps = steps };
    }

    pub fn deinit(self: *Render) void {
        std.heap.c_allocator.free(self.pixels);
    }
};

/// Computes a Mandelbrot image in RGBA tiles without blocking the Dart UI isolate.
pub fn render(request: RenderRequest) !Render {
    if (request.width == 0 or request.width > 1280 or request.height == 0 or request.height > 960 or
        request.firstRow >= request.lastRow or request.lastRow > request.height or
        request.maxIterations == 0 or request.maxIterations > 2500 or
        !std.math.isFinite(request.centerX) or !std.math.isFinite(request.centerY) or
        !std.math.isFinite(request.pixelScale) or request.pixelScale <= 0)
    {
        return error.InvalidRenderRequest;
    }
    const capacity = @as(usize, request.width) * tile_rows * 4;
    return .{
        .request = request,
        .pixels = try std.heap.c_allocator.alloc(u8, capacity),
        .next_row = request.firstRow,
    };
}

fn wave(position: u32) u8 {
    const phase = position % 512;
    return @intCast(if (phase < 256) phase else 511 - phase);
}

const std = @import("std");

pub const image_width = 160;
pub const image_height = 90;

const Particle = struct {
    x: f32,
    y: f32,
    vx: f32,
    vy: f32,
};

var live_native_bytes = std.atomic.Value(u32).init(0);

pub const SimulateRequest = struct {
    particleCount: u32,
    seed: u32,
};

pub const Frame = struct {
    sequence: u32,
    collisions: u32,
    meanSpeed: f64,
    liveNativeBytes: u32,
    rgba: []const u8,
};

pub const Simulation = struct {
    pub const Item = Frame;

    particles: []Particle,
    bins: []u16,
    rgba: []u8,
    allocated_bytes: u32,
    sequence: u32 = 0,

    /// Advances every particle once and returns a compact 160 x 90 heatmap.
    pub fn next(self: *Simulation) !?Frame {
        @memset(self.bins, 0);
        var collisions: u32 = 0;
        var total_speed: f64 = 0;

        for (self.particles) |*particle| {
            const dx = particle.x - 0.5;
            const dy = particle.y - 0.5;
            particle.vx = (particle.vx - dy * 0.000025 - dx * 0.000008) * 0.999;
            particle.vy = (particle.vy + dx * 0.000025 - dy * 0.000008) * 0.999;
            particle.x += particle.vx;
            particle.y += particle.vy;

            if (particle.x < 0 or particle.x > 1) {
                particle.x = @max(0, @min(1, particle.x));
                particle.vx = -particle.vx;
                collisions += 1;
            }
            if (particle.y < 0 or particle.y > 1) {
                particle.y = @max(0, @min(1, particle.y));
                particle.vy = -particle.vy;
                collisions += 1;
            }

            const column: usize = @min(image_width - 1, @as(usize, @intFromFloat(particle.x * image_width)));
            const row: usize = @min(image_height - 1, @as(usize, @intFromFloat(particle.y * image_height)));
            const index = row * image_width + column;
            if (self.bins[index] < std.math.maxInt(u16)) self.bins[index] += 1;
            total_speed += @as(f64, @floatCast(@sqrt(particle.vx * particle.vx + particle.vy * particle.vy)));
        }

        for (self.bins, 0..) |count, index| {
            const heat = @min(@as(u32, count) * 16, 255);
            const offset = index * 4;
            self.rgba[offset] = @intCast(if (heat < 128) heat / 5 else @min(255, (heat - 128) * 2 + 25));
            self.rgba[offset + 1] = @intCast(@min(255, 18 + heat));
            self.rgba[offset + 2] = @intCast(@min(255, 45 + heat * 2 / 3));
            self.rgba[offset + 3] = 255;
        }

        self.sequence +%= 1;
        return .{
            .sequence = self.sequence,
            .collisions = collisions,
            .meanSpeed = total_speed / @as(f64, @floatFromInt(self.particles.len)),
            .liveNativeBytes = live_native_bytes.load(.acquire),
            .rgba = self.rgba,
        };
    }

    pub fn deinit(self: *Simulation) void {
        std.heap.c_allocator.free(self.rgba);
        std.heap.c_allocator.free(self.bins);
        std.heap.c_allocator.free(self.particles);
        _ = live_native_bytes.fetchSub(self.allocated_bytes, .acq_rel);
    }
};

/// Keeps particle state in Zig and streams one heatmap for each Dart credit.
pub fn simulate(request: SimulateRequest) !Simulation {
    if (request.particleCount < 1000 or request.particleCount > 250_000) return error.InvalidParticleCount;
    const allocator = std.heap.c_allocator;
    const particles = try allocator.alloc(Particle, request.particleCount);
    errdefer allocator.free(particles);
    const bins = try allocator.alloc(u16, image_width * image_height);
    errdefer allocator.free(bins);
    const rgba = try allocator.alloc(u8, image_width * image_height * 4);
    errdefer allocator.free(rgba);

    var random_state: u32 = if (request.seed == 0) 0x9e3779b9 else request.seed;
    for (particles, 0..) |*particle, index| {
        const angle = random(&random_state) * (2.0 * std.math.pi);
        const radius = 0.035 + random(&random_state) * 0.19;
        const group: u32 = @intCast(index % 3);
        const center_x: f32 = switch (group) {
            0 => 0.30,
            1 => 0.70,
            else => 0.50,
        };
        const center_y: f32 = switch (group) {
            0 => 0.42,
            1 => 0.58,
            else => 0.50,
        };
        const tangent = 0.001 + random(&random_state) * 0.002;
        particle.* = .{
            .x = center_x + @cos(angle) * radius,
            .y = center_y + @sin(angle) * radius,
            .vx = -@sin(angle) * tangent,
            .vy = @cos(angle) * tangent,
        };
    }
    const allocated_bytes: u32 = @intCast(particles.len * @sizeOf(Particle) + bins.len * @sizeOf(u16) + rgba.len);
    _ = live_native_bytes.fetchAdd(allocated_bytes, .acq_rel);
    return .{ .particles = particles, .bins = bins, .rgba = rgba, .allocated_bytes = allocated_bytes };
}

fn random(state: *u32) f32 {
    var bits = state.*;
    bits ^= bits << 13;
    bits ^= bits >> 17;
    bits ^= bits << 5;
    state.* = bits;
    return @as(f32, @floatFromInt(bits >> 8)) / 16_777_216.0;
}

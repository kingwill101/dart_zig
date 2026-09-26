const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exports = b.createModule(.{ .root_source_file = b.path("src/exports.zig"), .target = target, .optimize = optimize, .pic = true });
    const library = b.addLibrary(.{ .name = "minimal_example", .linkage = .dynamic, .root_module = exports });
    b.installArtifact(library);
}

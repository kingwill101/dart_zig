const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const dependency = b.dependency("dart_zig", .{ .target = target, .optimize = optimize });
    const core = dependency.module("dart_zig");
    const application = b.createModule(.{ .root_source_file = b.path("src/handlers.zig"), .target = target, .optimize = optimize });
    application.addImport("dart_zig", core);
    const exports = b.createModule(.{ .root_source_file = dependency.path("src/exports.zig"), .target = target, .optimize = optimize, .link_libc = true, .pic = true });
    exports.addImport("dart_zig", core);
    exports.addImport("application", application);
    const library = b.addLibrary(.{ .name = "calls_example", .linkage = .dynamic, .root_module = exports });
    b.installArtifact(library);
}

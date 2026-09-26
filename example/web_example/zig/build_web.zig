const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    const optimize = b.standardOptimizeOption(.{});
    const dependency = b.dependency("dart_zig", .{ .target = target, .optimize = optimize });
    const core = dependency.module("dart_zig_web");
    const application = b.createModule(.{ .root_source_file = b.path("src/handlers.zig"), .target = target, .optimize = optimize, .single_threaded = true });
    application.addImport("dart_zig", core);
    const exports = b.createModule(.{ .root_source_file = dependency.path("src/exports_web.zig"), .target = target, .optimize = optimize, .single_threaded = true });
    exports.addImport("dart_zig", core);
    exports.addImport("application", application);
    const executable = b.addExecutable(.{ .name = "web_example", .root_module = exports });
    executable.entry = .disabled;
    executable.rdynamic = true;
    executable.export_memory = true;
    b.installArtifact(executable);
}

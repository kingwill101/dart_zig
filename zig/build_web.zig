const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    const optimize = b.standardOptimizeOption(.{});
    const core = b.addModule("dart_zig", .{ .root_source_file = b.path("src/root_web.zig"), .target = target, .optimize = optimize, .single_threaded = true });
    const models = b.createModule(.{ .root_source_file = b.path("src/generated/models.zig"), .target = target, .optimize = optimize });
    models.addImport("dart_zig", core);
    const app = b.createModule(.{ .root_source_file = b.path("src/application.zig"), .target = target, .optimize = optimize });
    app.addImport("dart_zig", core);
    app.addImport("models", models);
    const exports = b.createModule(.{ .root_source_file = b.path("src/exports_web.zig"), .target = target, .optimize = optimize, .single_threaded = true });
    exports.addImport("dart_zig", core);
    exports.addImport("models", models);
    exports.addImport("application", app);
    const executable = b.addExecutable(.{ .name = "dart_zig", .root_module = exports });
    executable.entry = .disabled;
    executable.rdynamic = true;
    executable.export_memory = true;
    b.installArtifact(executable);
}

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("dart_zig", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .pic = true,
    });
    module.addIncludePath(b.path("vendor/dart"));
    module.addIncludePath(b.path("src/runtime"));
    module.addCSourceFile(.{ .file = b.path("src/runtime/event.c"), .flags = &.{} });
    module.addCSourceFile(.{ .file = b.path("vendor/dart/dart_api_dl.c"), .flags = &.{} });

    const exports = b.createModule(.{
        .root_source_file = b.path("src/exports.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .pic = true,
    });
    exports.addImport("dart_zig", module);
    const models = b.createModule(.{
        .root_source_file = b.path("src/generated/models.zig"),
        .target = target,
        .optimize = optimize,
    });
    models.addImport("dart_zig", module);
    const application = b.createModule(.{
        .root_source_file = b.path("src/application.zig"),
        .target = target,
        .optimize = optimize,
    });
    application.addImport("dart_zig", module);
    application.addImport("models", models);
    exports.addImport("application", application);
    exports.addImport("models", models);
    // Example exports are deliberately separate from the reusable module.
    const demo = b.createModule(.{
        .root_source_file = b.path("src/demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    demo.addImport("dart_zig", module);
    exports.addImport("demo", demo);
    const lib = b.addLibrary(.{ .name = "dart_zig", .linkage = .dynamic, .root_module = exports });
    b.installArtifact(lib);
}

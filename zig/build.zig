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
    module.addCSourceFile(.{ .file = b.path("vendor/dart/dart_api_dl.c"), .flags = &.{} });

    // Compile the reusable runtime itself without inventing an application.
    const core_object = b.addObject(.{ .name = "dart_zig_core", .root_module = module });
    b.getInstallStep().dependOn(&core_object.step);

    // Applications use the same public runtime module with a different root
    // file when they compile their WebAssembly dispatcher.
    _ = b.addModule("dart_zig_web", .{
        .root_source_file = b.path("src/root_web.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = true,
    });

    const test_module = b.createModule(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    const tests = b.addTest(.{ .root_module = test_module });
    const test_step = b.step("test", "Run Zig runtime tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}

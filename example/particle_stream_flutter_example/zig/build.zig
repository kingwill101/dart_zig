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
    const library = b.addLibrary(.{ .name = "particle_stream_flutter_example", .linkage = .dynamic, .root_module = exports });
    b.installArtifact(library);

    const web_target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    const web_dependency = b.dependency("dart_zig", .{ .target = web_target, .optimize = optimize });
    const web_core = web_dependency.module("dart_zig_web");
    const web_application = b.createModule(.{ .root_source_file = b.path("src/handlers.zig"), .target = web_target, .optimize = optimize, .single_threaded = true });
    web_application.addImport("dart_zig", web_core);
    const web_exports = b.createModule(.{ .root_source_file = web_dependency.path("src/exports_web.zig"), .target = web_target, .optimize = optimize, .single_threaded = true });
    web_exports.addImport("dart_zig", web_core);
    web_exports.addImport("application", web_application);
    const wasm = b.addExecutable(.{ .name = "particle_stream_flutter_example", .root_module = web_exports });
    wasm.entry = .disabled;
    wasm.rdynamic = true;
    wasm.export_memory = true;
    const wasm_step = b.step("wasm", "Build the WebAssembly asset");
    wasm_step.dependOn(&b.addInstallArtifact(wasm, .{}).step);
}

const std = @import("std");

const sdl = @import("deps/zig-gamedev/libs/zsdl/build.zig");

var sdl_pkg: sdl.Package = undefined;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    sdl_pkg = sdl.package(b, target, optimize, .{});

    const module = b.addModule("mode7", .{
        .source_file = .{ .path = sdkPath("/src/root.zig") },
        .dependencies = &.{.{ .name = "zsdl", .module = sdl_pkg.zsdl }},
    });
    _ = module; // autofix

    const main_tests = b.addTest(.{
        .name = "tests",
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(main_tests);

    const test_run_cmd = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&test_run_cmd.step);
}

pub fn link(b: *std.Build, step: *std.build.CompileStep) void {
    _ = b; // autofix
    sdl_pkg.link(step);
}

fn sdkPath(comptime suffix: []const u8) []const u8 {
    if (suffix[0] != '/') @compileError("suffix must be an absolute path");
    return comptime blk: {
        const root_dir = std.fs.path.dirname(@src().file) orelse ".";
        break :blk root_dir ++ suffix;
    };
}

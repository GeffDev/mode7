const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("mode7", .{
        .source_file = .{ .path = sdkPath("/src/api.zig") },
        .dependencies = &.{},
    });
    _ = module; // autofix

    const main_tests = b.addTest(.{
        .name = "tests",
        .root_source_file = .{ .path = "src/api.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(main_tests);

    const test_run_cmd = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&test_run_cmd.step);
}

pub fn link(b: *std.Build, step: *std.build.CompileStep) void {
    if (step.target.isNativeOs() and step.target.getOsTag() == .linux) {
        step.linkLibC();
        step.linkSystemLibrary("SDL2");
    } else {
        const sdl_dep = b.dependency("sdl", .{
            .optimize = step.optimize,
            .target = step.target,
        });
        step.linkLibrary(sdl_dep.artifact("SDL2"));
    }
}

fn sdkPath(comptime suffix: []const u8) []const u8 {
    if (suffix[0] != '/') @compileError("suffix must be an absolute path");
    return comptime blk: {
        const root_dir = std.fs.path.dirname(@src().file) orelse ".";
        break :blk root_dir ++ suffix;
    };
}

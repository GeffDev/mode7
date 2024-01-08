const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimise = b.standardOptimizeOption(.{});

    const module = b.addModule("mode7", .{ .root_source_file = .{ .path = "src/api.zig" }, .imports = &.{} });

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/api.zig" },
        .target = target,
        .optimize = optimise,
    });
    link(b, main_tests, optimise, target);
    b.installArtifact(main_tests);

    const test_run_cmd = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&test_run_cmd.step);

    // TODO: i'd like the user to be able to have m7tools be installed to their projects zig-out/bin,
    // but this works for now.
    const m7tools = b.addExecutable(.{
        .name = "m7tools",
        .root_source_file = .{ .path = "m7tools/main.zig" },
        .target = target,
        .optimize = optimise,
    });
    m7tools.root_module.addImport("mode7", module);
    link(b, m7tools, optimise, target);

    const m7tools_install = b.addInstallArtifact(m7tools, .{});

    const m7tools_step = b.step("m7tools", "Install m7tools");
    m7tools_step.dependOn(&m7tools_install.step);
    b.getInstallStep().dependOn(m7tools_step);
}

// ughhjhhihhklhhasldf
// why can't we just pull target and optimize from step
pub fn link(b: *std.Build, step: *std.Build.Step.Compile, optimise: std.builtin.OptimizeMode, target: std.Build.ResolvedTarget) void {
    if (step.rootModuleTarget().os.tag == .linux) {
        step.linkLibC();
        step.linkSystemLibrary("SDL2");
    } else {
        const sdl_dep = b.dependency("sdl", .{
            .optimize = optimise,
            .target = target,
        });
        step.linkLibrary(sdl_dep.artifact("SDL2"));
    }
}

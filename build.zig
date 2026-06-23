const std = @import("std");

const build_zig_zon = @embedFile("build.zig.zon");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = std.builtin.OptimizeMode.ReleaseSmall;

    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "Seed",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .use_lld = false,
    });

    exe.root_module.link_libc = true;
    exe.root_module.linkSystemLibrary("GL", .{});
    exe.root_module.linkSystemLibrary("X11", .{});
    exe.root_module.linkSystemLibrary("Xi", .{});
    exe.root_module.linkSystemLibrary("Xcursor", .{});
    exe.root_module.linkSystemLibrary("asound", .{});

    exe.root_module.strip = true;

    exe.root_module.addImport("sokol", dep_sokol.module("sokol"));

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    run_step.dependOn(&run_cmd.step);
}

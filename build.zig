const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const link_vendor = b.option(bool, "link_vendor", "Whether link to vendored jemalloc (default: true)") orelse true;

    const module = b.addModule("jemalloc", .{
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    if (link_vendor) {
        try @import("libs/build.zig").create(b, target, optimize);
        module.addObjectFile(.{ .path = "libs/jemalloc/lib/libjemalloc.a" });
        module.addIncludePath(.{ .path = "libs/jemalloc/include/" });
    } else {
        module.linkSystemLibrary("jemalloc", .{});
    }

    const lib_unit_tests = b.addTest(.{
        .name = "jemalloc-tests",
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });
    lib_unit_tests.root_module.addImport("jemalloc", module);
    lib_unit_tests.linkLibC();
    lib_unit_tests.addIncludePath(.{ .path = "libs/jemalloc/include" });
    b.installArtifact(lib_unit_tests);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    try buildBenchmark(b, "basic", target, optimize, module);
}

fn buildBenchmark(
    b: *std.Build,
    comptime name: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    jemalloc_module: *std.Build.Module,
) !void {
    const exe = b.addExecutable(.{
        .name = name,
        .root_source_file = .{ .path = "benchmark/" ++ name ++ ".zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("jemalloc", jemalloc_module);
    b.installArtifact(exe);
}

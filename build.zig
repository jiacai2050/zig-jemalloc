const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const link_vendor = b.option(bool, "link_vendor", "Whether link to vendored jemalloc (default: true)") orelse true;

    const module = b.addModule("jemalloc", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const lib_ut = b.addTest(.{
        .name = "jemalloc-tests",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    if (link_vendor) {
        if (try buildStaticLib(b, target, optimize)) |lib| {
            module.linkLibrary(lib);
            lib_ut.linkLibrary(lib);
        } else {
            return;
        }
    } else {
        module.linkSystemLibrary("jemalloc", .{});
    }

    b.installArtifact(lib_ut);

    const run_lib_unit_tests = b.addRunArtifact(lib_ut);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    try buildBenchmark(b, "list", target, optimize, module);
}

fn buildStaticLib(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !?*std.Build.Step.Compile {
    const dep = b.lazyDependency("jemalloc", .{
        .target = target,
        .optimize = optimize,
    }) orelse return null;
    const lib = b.addStaticLibrary(.{
        .name = "jemalloc",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const config_step = b.addSystemCommand(&.{
        b.pathFromRoot("config.sh"),
        dep.path("").getPath(b),
    });
    lib.step.dependOn(&config_step.step);

    const dir = try std.fs.cwd().openDir(dep.path("src").getPath(b), .{ .iterate = true });
    var iter = dir.iterate();
    const cflags = &.{
        "-Werror=unknown-warning-option",
        "-Wall",
        "-Wextra",
        "-Wshorten-64-to-32",
        "-Wsign-compare",
        "-Wundef",
        "-Wno-format-zero-length",
        "-Wpointer-arith",
        "-Wno-missing-braces",
        "-Wno-missing-field-initializers",
        "-pipe",
        "-Wimplicit-fallthrough",
        "-funroll-loops",
    };
    while (try iter.next()) |entry| {
        if (entry.kind != .file) {
            continue;
        }
        if (std.mem.endsWith(u8, entry.name, ".c")) {
            const path = try std.fmt.allocPrint(b.allocator, "src/{s}", .{entry.name});
            lib.addCSourceFile(.{
                .file = dep.path(path),
                .flags = cflags,
            });
        }
    }
    lib.defineCMacro("JEMALLOC_GLIBC_MALLOC_HOOK", "1");
    lib.addIncludePath(dep.path("include"));
    lib.installHeader(dep.path("include/jemalloc/jemalloc.h"), "jemalloc/jemalloc.h");
    // lib.installHeadersDirectory(dep.path("include/jemalloc"), "jemalloc", .{});
    // lib.installHeadersDirectory(dep.path("include/curl"), "curl", .{});

    return lib;
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
        .root_source_file = b.path("benchmark/" ++ name ++ ".zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("jemalloc", jemalloc_module);
    b.installArtifact(exe);
}

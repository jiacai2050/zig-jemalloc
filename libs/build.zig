const std = @import("std");
const Build = std.Build;

const PREFIX = "libs/jemalloc";

// Not used, only used for testing.
pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = create(b, target, optimize) catch |err| {
        std.debug.print("{any}\n", .{err});
        return;
    };
    b.installArtifact(lib);
}

fn compileStaticLib(b: *std.Build) !void {
    const argv = [_][]const u8{
        "bash",
        PREFIX ++ "/../compile.sh",
        "world",
    };
    var child = std.process.Child.init(&argv, b.allocator);
    const term = try child.spawnAndWait();
    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                std.debug.print("gen header failed, ret:{any}\n", .{term});
                return error.GenConfig;
            }
        },
        else => {
            std.debug.print("gen header failed, unexpected ret:{any}\n", .{term});
            return error.GenConfig;
        },
    }
}

pub fn create(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !void {
    _ = target;
    _ = optimize;
    try compileStaticLib(b);
}

// TODO: this doesn't work now
pub fn createStaticLib(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !*std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "jemalloc",
        .target = target,
        .optimize = optimize,
    });
    var srcs = std.ArrayList([]const u8).init(b.allocator);
    const dir = try std.fs.cwd().openDir(PREFIX ++ "/src", .{ .iterate = true });
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) {
            continue;
        }
        if (std.mem.endsWith(u8, entry.name, ".c")) {
            const path = try std.fmt.allocPrint(b.allocator, PREFIX ++ "/src/{s}", .{entry.name});
            try srcs.append(path);
        }
    }
    lib.addCSourceFiles(.{
        .files = srcs.items,
        .flags = &.{
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
        },
    });
    lib.addIncludePath(.{ .path = PREFIX ++ "/include" });
    lib.installHeader(PREFIX ++ "/include/jemalloc/jemalloc.h", "jemalloc/jemalloc.h");
    lib.linkLibC();
    // lib.defineCMacro("JEMALLOC_ENABLE_CXX", "0");
    lib.defineCMacro("_REENTRANT", null);
    lib.defineCMacro("JEMALLOC_NO_PRIVATE_NAMESPACE", "1");
    return lib;
}

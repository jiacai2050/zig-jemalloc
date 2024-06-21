const std = @import("std");

fn isLinux(target: std.Target) bool {
    return target.os.tag == .linux;
}

fn is64bit(target: std.Target) bool {
    return target.cpu.arch == .x86_64 or target.cpu.arch.isAARCH64();
}

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
    const is_darwin = target.result.isDarwin();
    const is_linux = isLinux(target.result);
    // const config_step = b.addSystemCommand(&.{
    //     b.pathFromRoot("config.sh"),
    //     dep.path("").getPath(b),
    // });
    // lib.step.dependOn(&config_step.step);

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
            // This source file is for zones on Darwin (OS X).
            if (std.mem.eql(u8, entry.name, "zone.c") and !is_darwin) {
                continue;
            }
            const path = try std.fmt.allocPrint(b.allocator, "src/{s}", .{entry.name});
            lib.addCSourceFile(.{
                .file = dep.path(path),
                .flags = cflags,
            });
        }
    }
    const defs_header = b.addConfigHeader(
        .{
            .style = .{ .autoconf = dep.path("include/jemalloc/jemalloc_defs.h.in") },
            .include_path = "jemalloc/jemalloc_defs.h",
        },
        .{
            .JEMALLOC_HAVE_ATTR = {},
            .JEMALLOC_HAVE_ATTR_ALLOC_SIZE = {},
            .JEMALLOC_HAVE_ATTR_FORMAT_ARG = {},
            .JEMALLOC_HAVE_ATTR_FORMAT_PRINTF = {},
            .JEMALLOC_HAVE_ATTR_FALLTHROUGH = {},
            .JEMALLOC_HAVE_ATTR_COLD = {},
            .JEMALLOC_OVERRIDE_VALLOC = {},
            .JEMALLOC_USABLE_SIZE_CONST = .@"const",
            .LG_SIZEOF_PTR = 3,
            .JEMALLOC_HAVE_ATTR_FORMAT_GNU_PRINTF = null,
            .JEMALLOC_OVERRIDE_MEMALIGN = null,
            .JEMALLOC_USE_CXX_THROW = null,
        },
    );
    lib.addConfigHeader(defs_header);

    const macros_header = b.addConfigHeader(
        .{
            .style = .{ .cmake = dep.path("include/jemalloc/jemalloc_macros.h.in") },
            .include_path = "jemalloc/jemalloc_macros.h",
        },
        .{
            .jemalloc_version = "5.3.0",
            .jemalloc_version_major = 5,
            .jemalloc_version_minor = 3,
            .jemalloc_version_bugfix = 0,
            .jemalloc_version_nrev = 0,
            .jemalloc_version_gid = "missing",
            .jemalloc_version_gid_ident = .missing,
        },
    );
    lib.addConfigHeader(macros_header);

    const protos_header = b.addConfigHeader(
        .{
            .style = .{ .cmake = dep.path("include/jemalloc/jemalloc_protos.h.in") },
            .include_path = "jemalloc/jemalloc_protos.h",
        },
        .{
            .install_suffix = .je_,
            .je_ = .je_,
        },
    );
    lib.addConfigHeader(protos_header);

    const typedefs_header = b.addConfigHeader(
        .{
            .style = .{ .cmake = dep.path("include/jemalloc/jemalloc_typedefs.h.in") },
            .include_path = "jemalloc/jemalloc_typedefs.h",
        },
        .{},
    );
    lib.addConfigHeader(typedefs_header);

    lib.addConfigHeader(b.addConfigHeader(
        .{
            .style = .{ .autoconf = dep.path("include/jemalloc/internal/jemalloc_internal_defs.h.in") },
        },
        .{
            .JEMALLOC_PREFIX = "je_",
            .JEMALLOC_CPREFIX = "JE_",
            .JEMALLOC_OVERRIDE___LIBC_CALLOC = null,
            .JEMALLOC_OVERRIDE___LIBC_FREE = null,
            .JEMALLOC_OVERRIDE___LIBC_MALLOC = null,
            .JEMALLOC_OVERRIDE___LIBC_MEMALIGN = null,
            .JEMALLOC_OVERRIDE___LIBC_REALLOC = null,
            .JEMALLOC_OVERRIDE___LIBC_VALLOC = null,
            .JEMALLOC_OVERRIDE___POSIX_MEMALIGN = null,
            .JEMALLOC_PRIVATE_NAMESPACE = .je_,
            .CPU_SPINWAIT = .@"__asm__ volatile(\"isb\")",
            .HAVE_CPU_SPINWAIT = 1,
            .LG_VADDR = 48,
            .JEMALLOC_C11_ATOMICS = {},
            .JEMALLOC_GCC_ATOMIC_ATOMICS = {},
            .JEMALLOC_GCC_U8_ATOMIC_ATOMICS = {},
            .JEMALLOC_GCC_SYNC_ATOMICS = {},
            .JEMALLOC_GCC_U8_SYNC_ATOMICS = {},
            .JEMALLOC_HAVE_BUILTIN_CLZ = {},
            .JEMALLOC_OS_UNFAIR_LOCK = if (is_darwin) {} else null,
            .JEMALLOC_USE_SYSCALL = if (is_linux) {} else null,
            .JEMALLOC_HAVE_SECURE_GETENV = null,
            .JEMALLOC_HAVE_ISSETUGID = if (is_darwin) {} else null,
            .JEMALLOC_HAVE_PTHREAD_ATFORK = {},
            .JEMALLOC_HAVE_PTHREAD_SETNAME_NP = null,
            .JEMALLOC_HAVE_PTHREAD_GETNAME_NP = if (is_darwin) {} else null,
            .JEMALLOC_HAVE_PTHREAD_GET_NAME_NP = null,
            .JEMALLOC_HAVE_CLOCK_MONOTONIC_COARSE = if (is_linux) {} else null,
            .JEMALLOC_HAVE_CLOCK_MONOTONIC = if (is_linux) {} else null,
            .JEMALLOC_HAVE_MACH_ABSOLUTE_TIME = if (is_darwin) {} else null,
            .JEMALLOC_HAVE_CLOCK_REALTIME = {},
            .JEMALLOC_MALLOC_THREAD_CLEANUP = null,
            .JEMALLOC_THREADED_INIT = if (is_linux) {} else null,
            .JEMALLOC_MUTEX_INIT_CB = null,
            .JEMALLOC_TLS_MODEL = .@"__attribute__((tls_model(\"initial-exec\")))",
            .JEMALLOC_DEBUG = null,
            .JEMALLOC_STATS = {},
            .JEMALLOC_EXPERIMENTAL_SMALLOCX_API = null,
            .JEMALLOC_PROF = null,
            .JEMALLOC_PROF_LIBUNWIND = null,
            .JEMALLOC_PROF_LIBGCC = null,
            .JEMALLOC_PROF_GCC = null,
            .JEMALLOC_DSS = if (is_linux) {} else null,
            .JEMALLOC_FILL = {},
            .JEMALLOC_UTRACE = null,
            .JEMALLOC_UTRACE_LABEL = null,
            .JEMALLOC_XMALLOC = null,
            .JEMALLOC_LAZY_LOCK = null,
            .LG_QUANTUM = null,
            .LG_PAGE = 14,
            .CONFIG_LG_SLAB_MAXREGS = null,
            .LG_HUGEPAGE = 21,
            .JEMALLOC_MAPS_COALESCE = {},
            .JEMALLOC_RETAIN = if (is_linux and is64bit(target.result)) {} else null,
            .JEMALLOC_TLS = if (is_linux) {} else null,
            .JEMALLOC_INTERNAL_UNREACHABLE = .__builtin_unreachable,
            .JEMALLOC_INTERNAL_FFSLL = .__builtin_ffsll,
            .JEMALLOC_INTERNAL_FFSL = .__builtin_ffsl,
            .JEMALLOC_INTERNAL_FFS = .__builtin_ffs,
            .JEMALLOC_INTERNAL_POPCOUNTL = .__builtin_popcountl,
            .JEMALLOC_INTERNAL_POPCOUNT = .__builtin_popcount,
            .JEMALLOC_CACHE_OBLIVIOUS = {},
            .JEMALLOC_LOG = null,
            .JEMALLOC_READLINKAT = null,
            .JEMALLOC_ZONE = if (is_darwin) {} else null,
            .JEMALLOC_SYSCTL_VM_OVERCOMMIT = null,
            .JEMALLOC_PROC_SYS_VM_OVERCOMMIT_MEMORY = if (is_linux) {} else null,
            .JEMALLOC_HAVE_MADVISE = {},
            .JEMALLOC_HAVE_MADVISE_HUGE = if (is_linux) {} else null,
            .JEMALLOC_PURGE_MADVISE_FREE = {},
            .JEMALLOC_PURGE_MADVISE_DONTNEED = {},
            .JEMALLOC_PURGE_MADVISE_DONTNEED_ZEROS = null,
            .JEMALLOC_DEFINE_MADVISE_FREE = null,
            // Defined if madvise(2) is available but MADV_FREE is not (x86 Linux only).
            .JEMALLOC_MADVISE_DONTDUMP = if (is_linux and is64bit(target.result)) {} else null,
            .JEMALLOC_MADVISE_NOCORE = null,
            .JEMALLOC_HAVE_MPROTECT = {},
            .JEMALLOC_THP = null,
            .JEMALLOC_HAVE_POSIX_MADVISE = null,
            .JEMALLOC_PURGE_POSIX_MADVISE_DONTNEED = null,
            .JEMALLOC_PURGE_POSIX_MADVISE_DONTNEED_ZEROS = null,
            .JEMALLOC_HAVE_MEMCNTL = null,
            .JEMALLOC_HAVE_MALLOC_SIZE = if (is_darwin) {} else null,
            .JEMALLOC_HAS_ALLOCA_H = if (is_linux) {} else null,
            .JEMALLOC_HAS_RESTRICT = {},
            .JEMALLOC_BIG_ENDIAN = null,
            .LG_SIZEOF_INT = 2,
            .LG_SIZEOF_LONG = 3,
            .LG_SIZEOF_LONG_LONG = 3,
            .LG_SIZEOF_INTMAX_T = 3,
            .JEMALLOC_GLIBC_MALLOC_HOOK = null,
            .JEMALLOC_GLIBC_MEMALIGN_HOOK = null,
            .JEMALLOC_HAVE_PTHREAD = null,
            .JEMALLOC_HAVE_DLSYM = null,
            .JEMALLOC_HAVE_PTHREAD_MUTEX_ADAPTIVE_NP = if (is_linux) {} else null,
            .JEMALLOC_HAVE_SCHED_GETCPU = null,
            .JEMALLOC_HAVE_SCHED_SETAFFINITY = if (is_linux) {} else null,
            .JEMALLOC_BACKGROUND_THREAD = if (is_linux) {} else null,
            .JEMALLOC_EXPORT = null,
            .JEMALLOC_CONFIG_MALLOC_CONF = "",
            .JEMALLOC_IS_MALLOC = null,
            .JEMALLOC_STRERROR_R_RETURNS_CHAR_WITH_GNU_SOURCE = target.result.isGnu(),
            .JEMALLOC_OPT_SAFETY_CHECKS = null,
            .JEMALLOC_ENABLE_CXX = {},
            .JEMALLOC_OPT_SIZE_CHECKS = null,
            .JEMALLOC_UAF_DETECTION = null,
            .JEMALLOC_HAVE_VM_MAKE_TAG = if (is_darwin) {} else null,
            .JEMALLOC_ZERO_REALLOC_DEFAULT_FREE = if (is_linux) {} else null,
        },
    ));
    lib.addIncludePath(b.path("include"));
    lib.addIncludePath(dep.path("include"));
    lib.installHeader(b.path("include/jemalloc/jemalloc.h"), "jemalloc/jemalloc.h");
    lib.installHeader(typedefs_header.getOutput(), "jemalloc/jemalloc_typedefs.h");
    lib.installHeader(protos_header.getOutput(), "jemalloc/jemalloc_protos.h");
    lib.installHeader(macros_header.getOutput(), "jemalloc/jemalloc_macros.h");
    lib.installHeader(defs_header.getOutput(), "jemalloc/jemalloc_defs.h");

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

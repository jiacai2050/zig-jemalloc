const std = @import("std");
const Allocator = std.mem.Allocator;
const c = @cImport({
    @cInclude("jemalloc/jemalloc.h");
});

/// An allocator based on [jemalloc](https://jemalloc.net/jemalloc.3.html)
pub const allocator = std.mem.Allocator{
    .ptr = undefined,
    .vtable = &.{
        .alloc = alloc,
        .resize = resize,
        .free = free,
    },
};

/// Collect stats info into writer.
/// When opts contains `J`, stats is in JSON format.
pub fn collectMallocStats(wtr: anytype, opts: [:0]const u8) void {
    const context = @constCast(&wtr);
    c.malloc_stats_print(struct {
        fn f(ctx: ?*anyopaque, msg: [*c]const u8) callconv(.C) void {
            const p: *@TypeOf(wtr) = @alignCast(@ptrCast(ctx));
            p.writeAll(std.mem.span(msg)) catch |e| {
                std.log.err("call malloc_stats_print cb failed, err:{any}\n", .{e});
            };
        }
    }.f, context, opts);
}

fn alloc(_: *anyopaque, n: usize, log2_align: u8, return_address: usize) ?[*]u8 {
    _ = return_address;

    const alignment = @as(usize, 1) << @as(Allocator.Log2Align, @intCast(log2_align));
    const ptr = c.aligned_alloc(alignment, n) orelse return null;
    return @ptrCast(ptr);
}

fn resize(
    _: *anyopaque,
    buf_unaligned: []u8,
    log2_buf_align: u8,
    new_size: usize,
    return_address: usize,
) bool {
    _ = log2_buf_align;
    _ = return_address;
    return c.malloc_usable_size(buf_unaligned.ptr) >= new_size;
}

fn free(_: *anyopaque, slice: []u8, log2_buf_align: u8, return_address: usize) void {
    _ = log2_buf_align;
    _ = return_address;
    c.free(slice.ptr);
}

test "basic alloc" {
    const ptr = try allocator.create(struct { a: i8, b: u64 });
    allocator.destroy(ptr);

    var stats = std.ArrayList(u8).init(allocator);
    defer stats.deinit();

    collectMallocStats(stats.writer(), "");
    try std.testing.expect(stats.items.len > 0);
}

test "alloc ArrayList" {
    var lst = std.ArrayList(usize).init(allocator);
    defer lst.deinit();

    for (0..100_000) |i| {
        try lst.append(i);
    }
}

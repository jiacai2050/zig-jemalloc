const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;
const c = @cImport({
    @cInclude("jemalloc/jemalloc.h");
});

pub const jemalloctor = std.mem.Allocator{
    .ptr = undefined,
    .vtable = &.{
        .alloc = alloc,
        .resize = resize,
        .free = free,
    },
};

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
    const ptr = try jemalloctor.create(struct { a: i8, b: u64 });

    jemalloctor.destroy(ptr);
}

test "alloc ArrayList" {
    var lst = std.ArrayList(usize).init(jemalloctor);
    defer lst.deinit();

    for (0..100_000) |i| {
        try lst.append(i);
    }
}

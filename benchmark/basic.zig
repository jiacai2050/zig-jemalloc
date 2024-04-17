const std = @import("std");
const jemalloc = @import("jemalloc");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const MAX: usize = 1_000_000_000 / 4;

fn run(loop_count: usize, name: []const u8, allocator: Allocator) !void {
    var lst = ArrayList(usize).init(allocator);
    const start = std.time.nanoTimestamp();
    var s: usize = 0;
    for (0..loop_count) |i| {
        try lst.append(i);
        s += lst.items[lst.items.len - 1];
    }
    const end = std.time.nanoTimestamp();

    std.debug.print("{s} {}, cost: {d}ms\n", .{
        name,                                                                                     s,
        @as(f64, @floatFromInt(end - start)) / @as(f64, @floatFromInt(MAX * std.time.ns_per_ms)),
    });
}

pub fn main() !void {
    try run(MAX, "heap", std.heap.page_allocator);
    try run(MAX, "jemalloc", jemalloc.allocator);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("leak");
    const allocator = gpa.allocator();
    try run(MAX, "GPA", allocator);
}

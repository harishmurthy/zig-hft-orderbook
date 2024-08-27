const std = @import("std");
const ob = @import("./order_book.zig");
const order = @import("./order.zig");
const mpool = @import("./mempool.zig");
const uuid = @import("./uuid.zig");
const asset = @import("./asset.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    benchmarkAdd(gpa.allocator());
    benchmarkCancel(gpa.allocator());
}

pub fn benchmarkAdd(allocator: std.mem.Allocator) void {
    const obSpec = ob.Spec{ .money = .{ .prefix = .{ .code = "INR" } }, .stock = .{ .factor = 0, .prefix = .{ .code = "CER" } } };

    var o = ob.OrderBook.init(allocator, obSpec) catch unreachable;
    defer o.deinit();
    _ = o.add(12.25, 101, .buy) catch unreachable;
}

pub fn benchmarkCancel(allocator: std.mem.Allocator) void {
    const obSpec = ob.Spec{ .money = .{ .prefix = .{ .code = "INR" } }, .stock = .{ .factor = 0, .prefix = .{ .code = "CER" } } };

    var o = ob.OrderBook.init(allocator, obSpec) catch unreachable;
    defer o.deinit();
    const id1 = o.add(12.25, 101, .buy) catch unreachable;
    o.cancel(id1) catch unreachable;
}

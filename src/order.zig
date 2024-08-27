const limit = @import("./limit.zig");
const uuid = @import("./uuid.zig");
const asset = @import("./asset.zig");

pub const Side = enum { buy, sell, none };

pub const Order = struct {
    id: uuid.UUID,
    buy: Side,
    volume: asset.Asset,
    next: ?*Order,
    prev: ?*Order,
    limit: ?*limit.Limit,
};

pub fn initOrder(in: *Order, args: anytype) void {
    in.buy = .none;
    in.id = uuid.newV4();
    in.limit = null;
    in.next = null;
    in.prev = null;
    in.volume = asset.new(args, 0, 0);
}

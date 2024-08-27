const list = @import("./list.zig");
const rbtree = @import("./redblacktree.zig");
const order = @import("./order.zig");
const asset = @import("./asset.zig");

pub const OrderList = list.DoubleLinkedList(order.Order);

pub const Limit = struct {
    price: asset.Asset,
    totalVolume: asset.Asset,
    orders: OrderList,
    left: ?*Limit,
    right: ?*Limit,
    parent: ?*Limit,
    color: rbtree.Color,

    pub fn enqueue(self: *Limit, o: *order.Order) void {
        self.orders.add(o);
        o.limit = self;
        self.totalVolume.add(o.volume);
    }

    pub fn dequeue(self: *Limit) ?*order.Order {
        const o = self.orders.pop() orelse return null;
        self.totalVolume.sub(o.volume);
        return o;
    }

    pub fn delete(self: *Limit, o: *order.Order) !void {
        if (o.limit != self) {
            return error.UnsolicitedDelete;
        }
        self.orders.remove(o);
        o.limit = null;
        self.totalVolume.sub(o.volume);
    }
};

pub fn initLimit(in: *Limit, args: anytype) void {
    in.price = asset.new(args.money, 0, 0);
    in.totalVolume = asset.new(args.stock, 0, 0);
    in.left = null;
    in.right = null;
    in.parent = null;
    in.color = .black;
    in.orders = OrderList{};
}

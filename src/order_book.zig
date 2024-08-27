const std = @import("std");
const limit = @import("./limit.zig");
const order = @import("./order.zig");
const rbtree = @import("./redblacktree.zig");
const mpool = @import("./mempool.zig");
const asset = @import("./asset.zig");
const uuid = @import("./uuid.zig");

const LimitPool = mpool.MemPool(limit.Limit, limit.initLimit);
const OrderPool = mpool.MemPool(order.Order, order.initOrder);
const LimitHashMap = std.AutoHashMap(i64, *limit.Limit);
const OrderHashMap = std.AutoHashMap(uuid.UUID, *order.Order);

pub const Spec = struct {
    stock: asset.Spec,
    money: asset.Spec,
};

pub const DefaultCapacity = 16384;

pub const OrderBook = struct {
    const Self = @This();

    bids: rbtree.RedBlackTree(limit.Limit, .price, asset.cmp),
    asks: rbtree.RedBlackTree(limit.Limit, .price, asset.cmp),

    bidCache: LimitHashMap,
    askCache: LimitHashMap,

    limitPool: LimitPool,
    orderPool: OrderPool,

    orderCache: OrderHashMap,

    spec: Spec,

    pub fn init(allocator: std.mem.Allocator, spec: Spec) !Self {
        var s = Self{
            .askCache = LimitHashMap.init(allocator),
            .asks = .{},
            .bidCache = LimitHashMap.init(allocator),
            .bids = .{},
            .limitPool = try LimitPool.init(allocator, DefaultCapacity, spec),
            .orderPool = try OrderPool.init(allocator, DefaultCapacity, spec.stock),
            .orderCache = OrderHashMap.init(allocator),
            .spec = spec,
        };
        try s.askCache.ensureTotalCapacity(DefaultCapacity);
        try s.bidCache.ensureTotalCapacity(DefaultCapacity);
        try s.orderCache.ensureTotalCapacity(DefaultCapacity);
        return s;
    }

    pub fn deinit(self: *Self) void {
        if (self.empty()) |_| {} else |_| {}
        self.askCache.deinit();
        self.bidCache.deinit();
        self.limitPool.deinit();
        self.orderPool.deinit();
        self.orderCache.deinit();
    }

    pub fn len(self: Self) usize {
        return self.orderCache.count();
    }

    pub fn empty(self: *Self) !void {
        var asks = self.askCache.valueIterator();
        while (asks.next()) |lp| {
            const l = lp.*;
            while (l.dequeue()) |o| {
                _ = self.orderCache.remove(o.id);
                try self.orderPool.free(o);
            }
            try self.limitPool.free(l);
        }
        self.askCache.clearAndFree();
        var bids = self.bidCache.valueIterator();
        while (bids.next()) |lp| {
            const l = lp.*;
            while (l.dequeue()) |o| {
                _ = self.orderCache.remove(o.id);
                try self.orderPool.free(o);
            }
            try self.limitPool.free(l);
        }
        self.bidCache.clearAndFree();
    }

    pub fn add(self: *Self, price: f64, volume: i64, side: order.Side) !uuid.UUID {
        var l: ?*limit.Limit = null;
        const a = try asset.fromFloat(self.spec.money, price);
        const p = a.inFractionals();

        var newOrder = try self.orderPool.alloc(self.spec.stock);
        newOrder.buy = side;
        newOrder.volume.updateWithFractional(volume);

        if (newOrder.buy == .buy) {
            l = self.bidCache.get(p);
        } else {
            l = self.askCache.get(p);
        }

        const ll = l orelse try self.limitPool.alloc(self.spec);

        if (l == null) {
            ll.price.updateWithFractional(p);
            if (newOrder.buy == .buy) {
                self.bids.insert(ll);
                try self.bidCache.put(p, ll);
            } else {
                self.asks.insert(ll);
                try self.askCache.put(p, ll);
            }
        }

        ll.enqueue(newOrder);
        try self.orderCache.put(newOrder.id, newOrder);
        return newOrder.id;
    }

    pub fn cancel(self: *Self, id: uuid.UUID) !void {
        const o = self.orderCache.get(id) orelse return;
        const l = o.limit orelse return;
        try l.delete(o);

        if (l.orders.size() == 0) {
            if (o.buy == .buy) {
                self.bids.delete(l.price);
                _ = self.bidCache.remove(l.price.inFractionals());
            } else {
                self.asks.delete(l.price);
                _ = self.askCache.remove(l.price.inFractionals());
            }
            try self.limitPool.free(l);
        }
        _ = self.orderCache.remove(id);
        try self.orderPool.free(o);
    }

    pub fn bidVolume(self: *Self, price: f64) !f64 {
        const a = try asset.fromFloat(self.spec.money, price);
        const p = a.inFractionals();
        const l = self.bidCache.get(p) orelse return 0;
        return l.totalVolume.asFloat();
    }

    pub fn askVolume(self: *Self, price: f64) !f64 {
        const a = try asset.fromFloat(self.spec.money, price);
        const p = a.inFractionals();
        const l = self.askCache.get(p) orelse return 0;
        return l.totalVolume.asFloat();
    }

    pub fn highestBid(self: *Self) ?f64 {
        const b = self.bids.max() orelse return null;
        return b.price.asFloat();
    }

    pub fn lowestAsk(self: *Self) ?f64 {
        const a = self.asks.min() orelse return null;
        return a.price.asFloat();
    }

    pub fn bestBid(self: *Self, price: f64) ?f64 {
        const a = try asset.fromFloat(self.spec.money, price);
        const p = a.inFractionals();
        const b = self.bids.eqlOrHigher(p) orelse return null;
        return b.price.asFloat();
    }

    pub fn bestAsk(self: *Self, price: f64) ?f64 {
        const a = try asset.fromFloat(self.spec.money, price);
        const p = a.inFractionals();
        const l = self.asks.eqlOrLower(p) orelse return null;
        return l.price.asFloat();
    }
};

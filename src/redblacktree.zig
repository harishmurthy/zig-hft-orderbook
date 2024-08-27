const std = @import("std");
const assert = std.debug.assert;
const order = std.math.order;

pub const Color = enum { black, red };

pub fn RedBlackTree(comptime T: type, comptime key: std.meta.FieldEnum(T), comptime compareFn: fn (a: std.meta.FieldType(T, key), b: std.meta.FieldType(T, key)) std.math.Order) type {
    return struct {
        const Self = @This();

        const K = std.meta.FieldType(T, key);

        const keyName = @tagName(key);

        comptime {
            verifyType(T);
        }

        pub fn verifyType(comptime Node: type) void {
            comptime {
                if (!@hasField(Node, "left")) {
                    @compileError("missing field -> left of type ?*" ++ @typeName(Node));
                }
                if (!@hasField(Node, "right")) {
                    @compileError("missing field -> right of type ?*" ++ @typeName(Node));
                }
                if (!@hasField(Node, "parent")) {
                    @compileError("missing field -> parent of type ?*" ++ @typeName(Node));
                }
                if (!@hasField(Node, "color")) {
                    @compileError("missing field -> color of type " ++ @typeName(Color));
                }
                if (std.meta.FieldType(Node, .left) != ?*Node) {
                    @compileError("field -> left is of wrong type, must be ?*" ++ @typeName(Node));
                }
                if (std.meta.FieldType(Node, .right) != ?*Node) {
                    @compileError("field -> right is of wrong type, must be ?*" ++ @typeName(Node));
                }
                if (std.meta.FieldType(Node, .parent) != ?*Node) {
                    @compileError("field -> parent is of wrong type, must be ?*" ++ @typeName(Node));
                }
                if (std.meta.FieldType(Node, .color) != Color) {
                    @compileError("field -> color is of wrong type, must be " ++ @typeName(Color));
                }
            }
        }

        root: ?*T = null,
        high: ?*T = null,
        low: ?*T = null,

        fn grandparent(node: ?*T) ?*T {
            if (node) |n| {
                if (n.parent) |p| {
                    if (p.parent) |g| {
                        return g;
                    } else {
                        assert(false);
                    }
                }
            }
            return null;
        }

        fn sibling(node: ?*T) ?*T {
            if (node) |n| {
                if (n.parent) |p| {
                    if (n == p.left) {
                        return p.right;
                    } else {
                        return p.left;
                    }
                }
            }
            return null;
        }

        fn uncle(node: ?*T) ?*T {
            if (node) |n| {
                if (n.parent) |p| {
                    return sibling(p);
                }
            }
            return null;
        }

        fn nodeColor(node: ?*T) Color {
            if (node) |n| {
                return n.color;
            }
            return .black;
        }

        fn replaceNode(self: *Self, old: ?*T, new: ?*T) void {
            if (old) |o| {
                if (o.parent) |p| {
                    if (o == p.left) {
                        p.left = new;
                    } else {
                        p.right = new;
                    }
                } else {
                    self.root = new;
                }
                if (new) |n| {
                    n.parent = o.parent;
                }
            }
        }

        fn rototeLeft(self: *Self, node: ?*T) void {
            if (node) |n| {
                const r = n.right;
                self.replaceNode(n, r);
                if (r) |rp| {
                    n.right = rp.left;
                    if (rp.left) |rl| {
                        rl.parent = n;
                    }
                    rp.left = n;
                    n.parent = r;
                }
            }
        }

        fn rotateRight(self: *Self, node: ?*T) void {
            if (node) |n| {
                const l = n.left;
                self.replaceNode(n, l);
                if (l) |lp| {
                    n.left = lp.right;
                    if (lp.right) |lr| {
                        lr.parent = n;
                    }
                    lp.right = n;
                    n.parent = l;
                }
            }
        }

        fn icase1(self: *Self, node: *T) void {
            if (node.parent != null) {
                self.icase2(node);
            } else {
                node.color = .black;
            }
        }

        fn icase2(self: *Self, node: *T) void {
            if (nodeColor(node.parent) == .black) {
                return;
            }
            self.icase3(node);
        }

        fn icase3(self: *Self, node: *T) void {
            if (nodeColor(uncle(node)) == .red) {
                if (node.parent) |p| {
                    p.color = .black;
                }
                const un = uncle(node);
                if (un) |u| {
                    u.color = .black;
                }
                const gp = grandparent(node);
                if (gp) |g| {
                    g.color = .red;
                    self.icase1(g);
                }
            } else {
                self.icase4(node);
            }
        }

        fn icase4(self: *Self, node: *T) void {
            var newn: ?*T = node;
            if (node.parent) |p| {
                if (p.parent) |g| {
                    if (node == p.right and p == g.left) {
                        self.rototeLeft(p);
                        newn = node.left;
                    } else if (node == p.left and p == g.right) {
                        self.rotateRight(p);
                        newn = node.right;
                    }
                }
            }
            self.icase5(newn);
        }

        fn icase5(self: *Self, node: ?*T) void {
            if (node) |n| {
                if (n.parent) |p| {
                    p.color = .black;
                    const gp = grandparent(n);
                    if (gp) |g| {
                        g.color = .red;
                        if (n == p.left and p == g.left) {
                            self.rotateRight(g);
                        } else {
                            assert(n == p.right and p == g.right);
                            self.rototeLeft(g);
                        }
                    }
                }
            }
        }

        fn maximum(node: *T) *T {
            var n = node;
            while (n.right != null) {
                n = n.right.?;
            }
            return n;
        }

        fn minimum(node: *T) *T {
            var n = node;
            while (n.left != null) {
                n = n.left.?;
            }
            return n;
        }

        fn lookupNode(self: *Self, k: K) ?*T {
            var n = self.root;
            while (n != null) {
                const result = compareFn(k, @field(n.?, keyName));
                switch (result) {
                    .eq => {
                        return n;
                    },
                    .lt => {
                        n = n.?.left;
                    },
                    .gt => {
                        n = n.?.right;
                    },
                }
            }
            return null;
        }

        pub fn eqlOrHigher(self: *Self, k: K) ?*T {
            var n = self.root;
            while (n != null) {
                const result = compareFn(k, @field(n.?, keyName));
                switch (result) {
                    .eq, .gt => {
                        return n;
                    },
                    .lt => {
                        n = n.?.left;
                    },
                }
            }
            return null;
        }

        pub fn eqlOrLower(self: *Self, k: K) ?*T {
            var n = self.root;
            while (n != null) {
                const result = compareFn(k, @field(n.?, keyName));
                switch (result) {
                    .eq, .lt => {
                        return n;
                    },
                    .gt => {
                        n = n.?.right;
                    },
                }
            }
            return null;
        }

        pub fn insert(self: *Self, node: *T) void {
            if (self.root) |root| {
                var n = root;
                while (true) {
                    const result = compareFn(@field(node, keyName), @field(n, keyName));
                    switch (result) {
                        .eq => {
                            unreachable;
                        },
                        .lt => {
                            if (n.left) |l| {
                                n = l;
                            } else {
                                n.left = node;
                                break;
                            }
                        },
                        .gt => {
                            if (n.right) |r| {
                                n = r;
                            } else {
                                n.right = node;
                                break;
                            }
                        },
                    }
                }
                node.parent = n;
            } else {
                self.root = node;
            }
            self.icase1(node);
            if (self.high == null or compareFn(@field(node, keyName), @field(self.high.?, keyName)) == .gt) {
                self.high = node;
            }
            if (self.low == null or compareFn(@field(node, keyName), @field(self.low.?, keyName)) == .lt) {
                self.low = node;
            }
        }

        fn dcase1(self: *Self, node: ?*T) void {
            if (node) |n| {
                if (n.parent == null) {
                    return;
                }
                self.dcase2(n);
            }
        }

        fn dcase2(self: *Self, node: ?*T) void {
            if (nodeColor(sibling(node)) == .red) {
                if (node) |n| {
                    const sib = sibling(n);
                    if (sib) |s| {
                        s.color = .black;
                    }
                    if (n.parent) |p| {
                        p.color = .red;
                        if (n == p.left) {
                            self.rototeLeft(p);
                        } else {
                            self.rotateRight(p);
                        }
                    }
                }
            }
            self.dcase3(node);
        }

        fn dcase3(self: *Self, node: ?*T) void {
            if (node) |n| {
                const sib = sibling(n);
                if (sib) |s| {
                    if (nodeColor(n.parent) == .black and nodeColor(s) == .black and nodeColor(s.left) == .black and nodeColor(s.right) == .black) {
                        s.color = .red;
                        self.dcase1(n.parent);
                    } else {
                        self.dcase4(n);
                    }
                }
            }
        }

        fn dcase4(self: *Self, node: ?*T) void {
            if (node) |n| {
                const sib = sibling(n);
                if (sib) |s| {
                    if (nodeColor(n.parent) == .red and nodeColor(s) == .black and nodeColor(s.left) == .black and nodeColor(s.right) == .black) {
                        s.color = .red;
                        if (n.parent) |p| {
                            p.color = .black;
                        }
                    } else {
                        self.dcase5(n);
                    }
                }
            }
        }

        fn dcase5(self: *Self, node: ?*T) void {
            if (node) |n| {
                if (n.parent) |p| {
                    const sib = sibling(n);
                    if (sib) |s| {
                        if (n == p.left and nodeColor(s) == .black and nodeColor(s.left) == .red and nodeColor(s.right) == .black) {
                            s.color = .red;
                            if (s.left) |l| {
                                l.color = .black;
                            }
                            self.rotateRight(s);
                        } else if (n == p.right and nodeColor(s) == .black and nodeColor(s.right) == .red and nodeColor(s.left) == .black) {
                            s.color = .red;
                            if (s.right) |r| {
                                r.color = .black;
                            }
                            self.rototeLeft(s);
                        }
                    }
                }
            }
        }

        fn dcase6(self: *Self, node: ?*T) void {
            if (node) |n| {
                if (sibling(n)) |s| {
                    s.color = nodeColor(n.parent);
                    if (n.parent) |p| {
                        p.color = .black;
                        if (n == p.left) {
                            assert(nodeColor(s.right) == .red);
                            if (s.right) |r| {
                                r.color = .black;
                            }
                            self.rototeLeft(p);
                        } else {
                            assert(nodeColor(s.left) == .red);
                            if (s.left) |l| {
                                l.color = .black;
                            }
                            self.rotateRight(p);
                        }
                    }
                }
            }
        }

        fn predecessor(node: *T) ?*T {
            if (node.left != null) {
                return maximum(node.left.?);
            }
            var y = node.parent;
            var x = node;
            while (y != null and x == y.?.left) {
                x = y.?;
                y = y.?.parent;
            }
            return y;
        }

        fn successor(node: *T) ?*T {
            if (node.right != null) {
                return minimum(node.right.?);
            }
            var y = node.parent;
            var x = node;
            while (y != null and x == y.?.right) {
                x = y.?;
                y = y.?.parent;
            }
            return y;
        }

        pub fn max(self: *Self) ?*T {
            return self.high;
        }

        pub fn min(self: *Self) ?*T {
            return self.low;
        }

        pub fn delete(self: *Self, k: K) void {
            const node = self.lookupNode(k);
            if (node) |n| {
                var free = n;
                if (free.left != null and free.right != null) {
                    const pred = maximum(free.left.?);
                    free = pred;
                }
                assert(free.left == null or free.right == null);
                const child = if (free.right == null) free.left else free.right;
                if (nodeColor(free) == .black) {
                    free.color = nodeColor(child);
                    self.dcase1(free);
                }
                self.replaceNode(free, child);
                if (child) |c| {
                    if (free.parent == null) {
                        c.color = .black;
                    }
                }
                if (self.high == n) {
                    self.high = predecessor(free);
                }
                if (self.low == n) {
                    self.low = successor(free);
                }
                assert((free.left == null or free.left == child) and (free.right == null or free.right == child));
            }
        }
    };
}

const limit = struct {
    key: u32,
    left: ?*limit = null,
    right: ?*limit = null,
    parent: ?*limit = null,
    color: Color = .red,
};

test "basic" {
    const limitTree = RedBlackTree(limit, .key, order);
    var tree = limitTree{};

    var limts: [100000]limit = undefined;
    var max: u32 = 0;
    var min: u32 = std.math.maxInt(u32);
    for (0..100000) |i| {
        limts[i] = limit{ .key = @as(u32, @intCast(i)) };
        if (max < limts[i].key) {
            max = limts[i].key;
        }
        if (min > limts[i].key) {
            min = limts[i].key;
        }
        tree.insert(&limts[i]);
    }
    try std.testing.expectEqual(max, tree.max().?.key);
    try std.testing.expectEqual(min, tree.min().?.key);
}

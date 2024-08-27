const std = @import("std");

pub fn DoubleLinkedList(comptime T: type) type {
    return struct {
        const Self = @This();

        comptime {
            verifyType(T);
        }

        fn verifyType(comptime Node: type) void {
            comptime {
                if (!@hasField(Node, "prev")) {
                    @compileError("missing field -> prev of type ?*" ++ @typeName(Node));
                }
                if (!@hasField(Node, "next")) {
                    @compileError("missing field -> next of type ?*" ++ @typeName(Node));
                }
                if (std.meta.FieldType(Node, .prev) != ?*Node) {
                    @compileError("wrong type for prev field, must be ?*" ++ @typeName(Node));
                }
                if (std.meta.FieldType(Node, .next) != ?*Node) {
                    @compileError("wrong type for next field, must be ?*" ++ @typeName(Node));
                }
            }
        }

        first: ?*T = null,
        last: ?*T = null,
        len: usize = 0,

        pub fn size(list: *Self) usize {
            return list.len;
        }

        pub fn add(list: *Self, node: *T) void {
            const l = list.last;
            list.last = node;
            if (l) |tail| {
                tail.next = node;
                node.prev = tail;
            }
            if (list.first == null) {
                list.first = node;
            }
            list.len += 1;
        }

        pub fn pop(list: *Self) ?*T {
            const h = list.first orelse return null;
            if (list.first == list.last) {
                list.last = null;
            }
            list.first = h.next;
            list.len -= 1;
            return h;
        }

        pub fn remove(list: *Self, node: *T) void {
            const prev = node.prev;
            const next = node.next;
            if (prev) |p| {
                p.next = next;
            }
            if (next) |n| {
                n.prev = prev;
            }
            node.next = null;
            node.prev = null;

            list.len -= 1;
            if (list.first == node) {
                list.first = next;
            }
            if (list.last == node) {
                list.last = prev;
            }
        }
    };
}

const order = struct {
    id: u32,
    volume: f64,
    next: ?*order = null,
    prev: ?*order = null,
    bid: bool = false,
};

test "basic" {
    const orderList = DoubleLinkedList(order);
    var list = orderList{};

    var a = order{ .bid = true, .id = 1, .volume = 3 };
    var b = order{ .id = 2, .volume = 12 };

    list.add(&a);
    list.add(&b);

    try std.testing.expectEqual(2, list.size());
    try std.testing.expectEqual(&b, a.next);
    try std.testing.expectEqual(&a, b.prev);

    try std.testing.expectEqual(&a, list.pop());
    list.remove(&b);

    try std.testing.expectEqual(0, list.size());
}

const std = @import("std");

pub fn MemPool(comptime T: type, comptime initFn: fn (in: *T, args: anytype) void) type {
    return struct {
        const magic = 0xABCDEFBA;
        const Self = @This();

        pub const Box = struct {
            info: T,
            magic: u64,
            next: ?*Box,
        };

        const stats = struct {
            creates: u32,
            destroys: u32,
            pushs: u32,
            pops: u32,
            len: usize,
            max: usize,
        };

        head: ?*Box,
        allocator: std.mem.Allocator,
        stat: stats,

        pub fn init(allocator: std.mem.Allocator, size: usize, args: anytype) !Self {
            var s = Self{
                .allocator = allocator,
                .head = null,
                .stat = .{
                    .creates = 0,
                    .destroys = 0,
                    .pops = 0,
                    .pushs = 0,
                    .len = 0,
                    .max = 0,
                },
            };
            for (0..size) |_| {
                const b = try s.newBox(args);
                s.push(b);
            }
            return s;
        }

        pub fn deinit(self: *Self) void {
            while (self.pop()) |b| {
                self.allocator.destroy(b);
                self.stat.destroys += 1;
            }
            std.debug.print("{s} stats: {} creates {} destroys {} pushs {} pops {} max\n", .{
                @typeName(Self),
                self.stat.creates,
                self.stat.destroys,
                self.stat.pushs,
                self.stat.pops,
                self.stat.max,
            });
        }

        fn newBox(self: *Self, args: anytype) !*Box {
            const b = try self.allocator.create(Box);
            b.magic = magic;
            b.next = null;
            initFn(&b.info, args);
            self.stat.creates += 1;
            return b;
        }

        fn push(self: *Self, b: *Box) void {
            b.next = self.head;
            self.head = b;
            self.stat.pushs += 1;
            self.stat.len += 1;
            if (self.stat.max < self.stat.len) {
                self.stat.max = self.stat.len;
            }
        }

        fn pop(self: *Self) ?*Box {
            const first = self.head orelse return null;
            self.head = first.next;
            self.stat.pops += 1;
            self.stat.len -= 1;
            return first;
        }

        pub fn alloc(self: *Self, args: anytype) !*T {
            if (self.pop()) |b| {
                initFn(&b.info, args);
                return &b.info;
            }
            const b = try self.newBox(args);
            return &b.info;
        }

        pub fn free(self: *Self, t: *T) !void {
            const b = @as(*Box, @alignCast(@fieldParentPtr("info", t)));
            if (b.magic != magic) {
                return error.MemoryCorruption;
            }
            self.push(b);
        }
    };
}

const trail = struct {
    data: u32,
};

fn init_trail(t: *trail, _: anytype) void {
    t.data = 0;
}

test "basic ops" {
    const trailPool = MemPool(trail, init_trail);
    const op = enum { alloc, free };
    const rand = std.crypto.random;
    var m = try trailPool.init(std.testing.allocator, 16);
    defer m.deinit();
    const max = 10000;
    var s: [max]*trail = undefined;
    var j: usize = 0;
    for (0..max) |_| {
        const o = rand.enumValue(op);
        switch (o) {
            .alloc => {
                const ptr = try m.alloc(null);
                try std.testing.expectEqual(0, ptr.data);
                ptr.data = rand.int(u32);
                s[j] = ptr;
                std.debug.print("alloced {} at {}\n", .{ ptr, j });
                j += 1;
            },
            .free => {
                if (j < 2) {
                    continue;
                }
                const idx = rand.intRangeAtMost(usize, 0, j - 1);
                const ptr = s[idx];
                s[idx] = s[j - 1];
                j -= 1;
                std.debug.print("free {} at {}\n", .{ ptr, idx });
                try m.free(ptr);
            },
        }
    }

    for (0..j) |p| {
        try m.free(s[p]);
    }
    std.debug.print("j: {}\n", .{j});
}

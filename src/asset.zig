const std = @import("std");
const string = []const u8;

pub const Option = union(enum) {
    code: string,
    symbol: string,
    none,
};

pub const Spec = struct {
    factor: u16 = 100,
    prefix: Option = .none,
    suffix: Option = .none,
};

pub const INR = Spec{ .suffix = .{ .symbol = "₹" } };

pub const SAR = Spec{
    .prefix = .{ .code = "SAR" },
};

pub const AED = Spec{ .prefix = .{ .code = "AED" } };

pub const Asset = struct {
    fracRatio: u16,
    prefix: Option,
    suffix: Option,
    main: i64 = 0,
    fractional: i64 = 0,
    fracDigits: usize,
    magnitude: f64,

    pub fn format(self: Asset, comptime _: string, _: std.fmt.FormatOptions, writer: anytype) !void {
        const sign = if (self.fractional < 0 or self.main < 0) "-" else "";
        switch (self.prefix) {
            .code => |code| {
                if (code.len > 0) {
                    try writer.print("{s} ", .{code});
                }
            },
            .symbol => |sym| {
                if (sym.len > 0) {
                    try writer.print("{s} ", .{sym});
                }
            },
            .none => {},
        }
        try writer.print("{s}", .{sign});
        try writer.print("{d}", .{@abs(self.main)});

        if (self.fracRatio > 0) {
            try writer.print(".", .{});
            const frcDigits = digits(self.fractional);
            for (0..self.fracDigits - frcDigits) |_| {
                try writer.print("0", .{});
            }
            try writer.print("{d}", .{@abs(self.fractional)});
        }
        switch (self.suffix) {
            .code => |code| {
                if (code.len > 0) {
                    try writer.print(" {s}", .{code});
                }
            },
            .symbol => |sym| {
                if (sym.len > 0) {
                    try writer.print(" {s}", .{sym});
                }
            },
            .none => {},
        }
        try writer.writeAll("");
    }

    pub fn inFractionals(self: Asset) i64 {
        if (self.fracRatio > 0) {
            const fus: i64 = @intCast(self.fracRatio);
            return (self.main * fus) + self.fractional;
        }
        return self.main;
    }

    pub fn asFloat(self: Asset) f64 {
        const m: f64 = @floatFromInt(self.main);
        if (self.fracRatio > 0) {
            const f: f64 = @floatFromInt(self.fractional);
            const ffus: f64 = @floatFromInt(self.fracRatio);
            return m + (f / ffus);
        }
        return m;
    }

    fn strlen(self: Asset) usize {
        var bufLen: usize = 1;
        switch (self.prefix) {
            .code => |code| {
                if (code.len > 0) {
                    bufLen += code.len + 1;
                }
            },
            .symbol => |sym| {
                if (sym.len > 0) {
                    bufLen += sym.len + 1;
                }
            },
            .none => {},
        }
        const sign = if (self.fractional < 0 or self.main < 0) "-" else "";
        bufLen += sign.len + digits(self.main) + self.fracDigits;
        switch (self.suffix) {
            .code => |code| {
                if (code.len > 0) {
                    bufLen += code.len + 1;
                }
            },
            .symbol => |sym| {
                if (sym.len > 0) {
                    bufLen += sym.len + 1;
                }
            },
            .none => {},
        }
        return bufLen;
    }

    pub fn asString(self: Asset, allocator: std.mem.Allocator) !string {
        const buf = try allocator.alloc(u8, self.strlen());
        var fbs = std.io.fixedBufferStream(buf);
        try self.format("", .{}, fbs.writer().any());
        return buf;
    }

    pub fn asStringBuf(self: Asset, buf: []u8) ![]u8 {
        const bufLen = self.strlen();
        if (buf.len < bufLen) {
            return error.BufferTooSmall;
        }
        var fbs = std.io.fixedBufferStream(buf);
        try self.format("", .{}, fbs.writer().any());
        return buf[0..bufLen];
    }

    pub fn updateWithFractional(self: *Asset, frac: i64) void {
        if (self.fracRatio > 0) {
            const fus: i64 = @intCast(self.fracRatio);
            const neg: bool = if (frac < 0) true else false;
            var f = frac;
            if (neg == true) {
                f = -f;
            }
            self.main = @divFloor(f, fus);
            self.fractional = @mod(f, fus);
            if (neg == true) {
                self.main = -self.main;
                self.fractional = -self.fractional;
            }
        } else {
            self.main = frac;
            self.fractional = 0;
        }
    }

    pub fn add(self: *Asset, oth: Asset) void {
        self.updateWithFractional(self.inFractionals() + oth.inFractionals());
    }

    pub fn update(self: *Asset, m: i64, f: i64) void {
        var fr = f;
        if (m < 0 and f > 0) {
            fr = -fr;
        }
        if (self.fracRatio > 0) {
            const fus: i64 = @intCast(self.fracRatio);
            self.updateWithFractional(self.inFractionals() + (m * fus + fr));
        } else {
            self.updateWithFractional(self.main + m);
        }
    }

    pub fn updateWithFloat(self: *Asset, value: f64) void {
        const sh: i64 = @intCast(self.fracRatio);

        if (sh > 0) {
            const neg: bool = if (value < 0) true else false;
            const ffus: f64 = @floatFromInt(self.fracRatio);
            const fus: i64 = @intCast(self.fracRatio);
            var total = round(value * ffus, self.magnitude);
            if (neg == true) {
                total = -total;
            }
            self.main = @divFloor(total, fus);
            self.fractional = @mod(total, fus);
            const quo = @divFloor(self.fractional, fus);
            self.main += quo;
            if (neg == true) {
                self.main = -self.main;
                self.fractional = -self.fractional;
            }
        } else {
            self.main = @intFromFloat(value);
            self.fractional = 0;
        }
    }

    pub fn sub(self: *Asset, oth: Asset) void {
        self.updateWithFractional(self.inFractionals() - oth.inFractionals());
    }

    pub fn percent(self: Asset, n: f64) Asset {
        const total: f64 = @floatFromInt(self.inFractionals());
        const frac = round(total * (n / 100.0), self.magnitude);
        var s = Asset{
            .fracDigits = self.fracDigits,
            .fracRatio = self.fracRatio,
            .fractional = self.fractional,
            .magnitude = self.magnitude,
            .main = self.main,
            .prefix = self.prefix,
            .suffix = self.suffix,
        };
        s.updateWithFractional(frac);
        return s;
    }

    pub fn scale(self: *Asset, by: i64) void {
        self.updateWithFractional(self.inFractionals() * by);
    }

    pub fn mul(self: *Asset, f: f64) void {
        const total: f64 = @floatFromInt(self.inFractionals());
        const prod = round(total * f, self.magnitude);
        self.updateWithFractional(prod);
    }
};

fn digits(n: i64) usize {
    var num = @abs(n);

    num /= 10;
    var d: usize = 1;

    while (num > 0) {
        d += 1;
        num /= 10;
    }
    return d;
}

fn mag(n: usize) f64 {
    const o: i64 = @intCast(n);
    const d = digits(o);
    var m: f64 = 5.0;
    for (0..d - 1) |_| {
        m /= 10;
    }
    return m;
}

fn round(f: f64, m: f64) i64 {
    if (@abs(f) < 0.5) {
        return 0;
    }
    const c = std.math.copysign(m, f);
    const r = f + c;
    const i: i64 = @intFromFloat(r);
    return i;
}

pub fn new(spec: Spec, main: i64, fractional: i64) Asset {
    var s = Asset{
        .fracDigits = if (spec.factor > 0) digits(spec.factor - 1) else 0,
        .fracRatio = spec.factor,
        .magnitude = if (spec.factor > 0) mag(spec.factor - 1) else 5.0,
        .prefix = spec.prefix,
        .suffix = spec.suffix,
    };

    if (spec.factor > 0) {
        var frac = fractional;
        const neg: bool = if (main < 0 or fractional < 0) true else false;
        if (fractional < 0) {
            frac = -frac;
        }
        const fus: i64 = @intCast(s.fracRatio);
        const quo = @divFloor(frac, fus);
        s.main = main + quo;
        s.fractional = @mod(frac, fus);
        if (neg == true) {
            s.main = -s.main;
            s.fractional = -s.fractional;
        }
    } else {
        s.main = main;
        s.fractional = 0;
    }

    return s;
}

pub fn fromString(spec: Spec, value: string) !Asset {
    if (value.len >= 1024) {
        return error.ValueTooBig;
    }
    var val: [1024]u8 = undefined;
    var i: usize = 0;
    for (value) |c| {
        if (c >= '0' and c <= '9') {
            val[i] = c;
            i += 1;
        }
        if (c == '.' or c == '-' or c == '+') {
            val[i] = c;
            i += 1;
        }
    }
    const fval = try std.fmt.parseFloat(f64, val[0..i]);

    return fromFloat(spec, fval);
}

pub fn fromFloat(spec: Spec, value: f64) !Asset {
    const sh: i64 = @intCast(spec.factor);
    var s = Asset{
        .fracDigits = if (sh > 0) digits(sh - 1) else 0,
        .fracRatio = spec.factor,
        .magnitude = if (spec.factor > 0) mag(spec.factor - 1) else 5.0,
        .prefix = spec.prefix,
        .suffix = spec.suffix,
    };

    if (spec.factor > 0) {
        const neg: bool = if (value < 0) true else false;
        const ffus: f64 = @floatFromInt(s.fracRatio);
        const fus: i64 = @intCast(s.fracRatio);
        var total = round(value * ffus, s.magnitude);
        if (neg == true) {
            total = -total;
        }
        s.main = @divFloor(total, fus);
        s.fractional = @mod(total, fus);
        const quo = @divFloor(s.fractional, fus);
        s.main += quo;
        if (neg == true) {
            s.main = -s.main;
            s.fractional = -s.fractional;
        }
    } else {
        s.main = @intFromFloat(value);
        s.fractional = 0;
    }

    return s;
}

pub fn cmp(a: Asset, b: Asset) std.math.Order {
    return std.math.order(a.inFractionals(), b.inFractionals());
}

test "basic" {
    const allocator = std.testing.allocator;
    const tenRupee = new(INR, 10, -10);
    const hundred = try fromString(INR, "INR 100.00");
    const some = try fromFloat(INR, 21.75);
    const neg = try fromFloat(INR, -0.22);
    std.debug.print("{}\n", .{tenRupee});
    std.debug.print("{}\n", .{hundred});
    std.debug.print("{}\n", .{some});
    std.debug.print("{}\n", .{neg});
    const str = try neg.asString(allocator);
    defer allocator.free(str);
    std.debug.print("{s}\n", .{str});
    const f = neg.asFloat();
    std.debug.print("{}\n", .{f});
    std.debug.print("{}\n", .{neg.inFractionals()});
    var pi = try fromFloat(INR, 3.14);
    pi.updateWithFractional(some.inFractionals());
    std.debug.print("{}\n", .{pi});
    var twenty = new(INR, 10, 0);
    twenty.add(some);
    std.debug.print("{}\n", .{twenty});
    var thirty = new(INR, 20, 0);
    thirty.update(10, 10);
    std.debug.print("{}\n", .{thirty});
    thirty.update(-10, 10);
    std.debug.print("{}\n", .{thirty});
    thirty.sub(some);
    std.debug.print("{}\n", .{thirty});
    var buf: [32]u8 = undefined;
    const s = try thirty.asStringBuf(&buf);
    std.debug.print("{s}\n", .{s});
    const s2 = try twenty.asStringBuf(&buf);
    std.debug.print("{s}\n", .{s2});
    const fifty = hundred.percent(50);
    std.debug.print("{s}\n", .{fifty});
    var twohundred = try fromString(INR, "INR 200.00");
    twohundred.scale(2);
    std.debug.print("{s}\n", .{twohundred});
    twohundred.mul(0.5);
    std.debug.print("{s}\n", .{twohundred});
    const stock = new(.{ .prefix = .{ .code = "CER" }, .factor = 0 }, 10, 0);
    std.debug.print("{s}\n", .{stock});
}

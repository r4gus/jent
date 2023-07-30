const std = @import("std");
const jent = @import("jent");

const iterations = 10;

pub fn main() !void {
    var ec = try jent.RandData.init(true);

    var x: [1024]u8 = undefined;
    var y: [256]usize = .{0} ** 256;

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        std.debug.print("{d}\n", .{i});

        ec.bytes(x[0..]) catch |err| {
            std.debug.print("{d}\n", .{i});
            return err;
        };

        for (x[0..]) |byte| {
            y[@as(usize, @intCast(byte))] += 1;
        }
    }

    i = 0;
    for (y[0..]) |byte| {
        std.debug.print("{d} = {d}\n", .{ i, @as(f64, @floatFromInt(byte)) / @as(f64, @floatFromInt(iterations * 1024)) });
        i += 1;
    }
}

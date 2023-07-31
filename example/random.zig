const std = @import("std");
const jent = @import("jent");

const iterations = 20;

pub fn main() !void {
    const JentX86 = jent.Jent(jent.base_user.getNsTime, 8, 1024);
    var ec = try JentX86.init();
    var random = ec.random();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        std.debug.print("{d}\n", .{random.int(u64)});
    }
}

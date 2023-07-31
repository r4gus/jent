const std = @import("std");
const jent = @import("jent");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

fn oneTest(pathname: []const u8, rounds: usize, report_counter_ticks: usize) !void {
    var duration = try allocator.alloc(u64, rounds);
    defer allocator.free(duration);

    var duration_min = try allocator.alloc(u64, rounds);
    defer allocator.free(duration_min);

    std.log.info("Processing {s}", .{pathname});

    var out = try std.fs.createFileAbsolute(pathname, .{
        .truncate = true,
    });

    var mem1 = jent.Memory{
        .ptr = try allocator.alloc(u8, 4096 * 256),
        .blocks = 256,
        .block_size = 4096,
    };
    defer allocator.free(mem1.ptr);
    var ec = try jent.RandData.init(true, mem1);

    var mem2 = jent.Memory{
        .ptr = try allocator.alloc(u8, 4096 * 256),
        .blocks = 256,
        .block_size = 4096,
    };
    defer allocator.free(mem2.ptr);
    var ec_min = try jent.RandData.init(true, mem2);

    if (report_counter_ticks < 1) {
        // For this analysis, we want the raw values, not values that
        // have had common factors removed.
        ec.common_timer_gcd = 1;
        ec_min.common_timer_gcd = 1;
    }

    // Prime the test
    jent.noise.measureJitter(&ec, 0, null) catch {};
    var size: usize = 0;
    while (size < rounds) : (size += 1) {
        // Disregard stuck indicator
        jent.noise.measureJitter(&ec, 0, &duration[size]) catch {};
    }

    jent.noise.measureJitter(&ec_min, 0, null) catch {};
    size = 0;
    while (size < rounds) : (size += 1) {
        // Disregard stuck indicator
        jent.noise.measureJitter(&ec_min, 1, &duration_min[size]) catch {};
    }

    size = 0;
    while (size < rounds) : (size += 1) {
        try std.fmt.format(out.writer(), "{d}, {d}\n", .{ duration[size], duration_min[size] });
    }

    if (jent.health.checkHealth(&ec)) |failure| {
        const rct = if (failure.rct) "RCT " else "";
        const apt = if (failure.apt) "APT " else "";
        std.log.err("The main context encountered the following health testing failure(s): {s}{s}", .{ rct, apt });
    }

    if (jent.health.checkHealth(&ec_min)) |failure| {
        const rct = if (failure.rct) "RCT " else "";
        const apt = if (failure.apt) "APT " else "";
        std.log.err("The minimum context encountered the following health testing failure(s): {s}{s}", .{ rct, apt });
    }
}

pub fn main() !void {
    const argc = std.os.argv[0..].len;
    var buffer: [4096]u8 = undefined;

    if (argc < 4 or argc > 6) {
        std.log.err("{s} <rounds per repeat> <number of repreats> <filename> <max mem>", .{std.os.argv[0]});
        return;
    }

    var len: usize = 0;
    while (std.os.argv[1][len] != 0) : (len += 1) {}
    const rounds = try std.fmt.parseInt(usize, std.os.argv[1][0..len], 10);

    len = 0;
    while (std.os.argv[2][len] != 0) : (len += 1) {}
    const repeats = try std.fmt.parseInt(usize, std.os.argv[2][0..len], 10);

    if (argc >= 5) {
        len = 0;
        while (std.os.argv[4][len] != 0) : (len += 1) {}
        const val = try std.fmt.parseInt(usize, std.os.argv[4][0..len], 10);
        _ = val;
    }

    var i: usize = 1;
    while (i <= repeats) : (i += 1) {
        const path = std.fmt.bufPrint(buffer[0..], "{s}-{d}.data", .{
            std.os.argv[3],
            i,
        }) catch unreachable;

        try oneTest(path, rounds, 1);
    }
}

const std = @import("std");
const jent = @import("main.zig");

const JENT_POWERUP_TESTLOOP_COUNT = 1024;

pub fn entropyInitCommonPre() !void {
    var buffer: [10 * 8]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    try jent.gcd.selfTest(allocator);
}

pub fn timeEntropyInit(ec: *jent.RandData) !void {
    var buffer: [JENT_POWERUP_TESTLOOP_COUNT * 8]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    var count_stuck: usize = 0;
    var time_backwards: usize = 0;

    var delta_history = jent.gcd.DeltaHistory.init(JENT_POWERUP_TESTLOOP_COUNT, allocator) catch unreachable;
    defer delta_history.deinit();

    // Initialize the prior timer
    jent.noise.measureJitter(ec, 0, null) catch {};

    // We could perform statistical tests here, but the problem is
    // that we only have a few loop counts to do testing. These
    // loop counts may show some slight skew leading to false positives.

    var i: isize = -100;
    while (i < JENT_POWERUP_TESTLOOP_COUNT) : (i += 1) {
        // Invoke the entropy collection logic
        var delta: u64 = 0;
        jent.noise.measureJitter(ec, 0, &delta) catch {
            if (i >= 0) count_stuck += 1;
        };
        const end_time = ec.prev_time;
        const start_time = ec.prev_time - delta;

        // Test whether timer works
        if (start_time == 0 or end_time == 0) {
            return jent.Error.NoTime;
        }

        // Test whether timer is fine grained enough to provide
        // delta even when called shortly after each other -- this
        // implies that we also have a high resolution timer
        if (delta == 0 or (end_time == start_time)) {
            return jent.Error.CoarseTime;
        }

        // Up to here we did not modify any variable that will be
        // evaluated later, but we already performed some work. Thus we
        // already have had an impact on the caches, branch prediction,
        // etc. with the goal to clear it to get the worst case
        // measurements.
        if (i < 0) continue;

        // Test whether we have an increasing timer
        if (!(end_time > start_time)) {
            time_backwards += 1;
        }

        // Watch for common adjacent GCD values
        delta_history.addValue(@intCast(i), delta);
    }

    // We allow up to three times the time running backwards.
    // CLOCK_REALTIME is affected by adjtime and NTP operations. Thus,
    // if such an operation just happens to interfere with our test, it
    // should not fail. The value of 3 should cover the NTP case being
    // performed during our test run.
    if (time_backwards > 3) {
        return jent.Error.NoMonotonic;
    }

    // First, did we encounter a health test failure?
    if (jent.health.checkHealth(ec)) |failure| {
        return if (failure.rct) jent.Error.Rct else jent.Error.Health;
    }

    try delta_history.analyze();

    // If we have more than 90% stuck results, then this Jitter RNG is
    // likely to not work well.
    if (((JENT_POWERUP_TESTLOOP_COUNT * 9) / 10) < count_stuck) {
        return jent.Error.Stuck;
    }
}

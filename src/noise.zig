const std = @import("std");
const jent = @import("main.zig");

fn loopShuffle(ec: *jent.RandData, bits: usize, min: usize) u64 {
    _ = ec;
    _ = bits;

    const r = @shlWithOverflow(@as(u64, @intCast(1)), @as(u6, @intCast(min)));
    return r[0];

    // TODO: Add the LOOP_SHUFFLE option
}

// +++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Time Stamp
// +++++++++++++++++++++++++++++++++++++++++++++++++++++++

fn hashTime(ec: *jent.RandData, time: u64, loop_cnt: u64, stuck: bool) void {
    var intermediary: [jent.Sha.digest_length]u8 = .{0} ** jent.Sha.digest_length;

    const MAX_HASH_LOOP = 3;
    const MIN_HASH_LOOP = 0;
    var hash_loop_cnt = loopShuffle(ec, MAX_HASH_LOOP, MIN_HASH_LOOP);

    var state = jent.Sha.init(.{});

    // testing purposes -- allow test app to set the counter, not
    // needed during runtime
    if (loop_cnt > 0) {
        hash_loop_cnt = loop_cnt;
    }

    // This loop fills a buffer which is injected into the entropy pool.
    // The main reason for this loop is to execute something over which we
    // can perform a timing measurement. The injection of the resulting
    // data into the pool is performed to ensure the result is used and
    // the compiler cannot optimize the loop away in case the result is not
    // used at all. Yet that data is considered "additional information"
    // considering the terminology from SP800-90A without any entropy.
    //
    // Note, it does not matter which or how much data you inject, we are
    // interested in one Keccack1600 compression operation performed with
    // the sha3_final.
    var j: u64 = 0;
    while (j < hash_loop_cnt) : (j += 1) {
        state.update(intermediary[0..]);
        state.update(std.mem.asBytes(&ec.health.rct_count));
        state.update(std.mem.asBytes(&ec.health.apt_cutoff));
        state.update(std.mem.asBytes(&ec.health.apt_observations));
        state.update(std.mem.asBytes(&ec.health.apt_count));
        state.update(std.mem.asBytes(&ec.health.apt_base));
        state.update(std.mem.asBytes(&j));
        state.final(intermediary[0..]);
    }

    // Inject the data from the previous loop into the pool. This data is
    // not considered to contain any entropy, but it stirs the pool a bit.
    ec.hash_state.update(intermediary[0..]);

    // Insert the time stamp into the hash context representing the pool.
    //
    // If the time stamp is stuck, do not finally insert the value into the
    // entropy pool. Although this operation should not do any harm even
    // when the time stamp has no entropy, SP800-90B requires that any
    // conditioning operation to have an identical amount of input data
    // according to section 3.1.5.
    if (!stuck) {
        ec.hash_state.update(std.mem.asBytes(&time));
    }

    // Overwrite data
    @memset(intermediary[0..], 0);
    // TODO: do same for state
}

// +++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Mem Access
// +++++++++++++++++++++++++++++++++++++++++++++++++++++++

/// Memory Access noise source -- this is a noise source based on variations in memory access times
pub fn memAccess(ec: *jent.RandData, loop_cnt: u64) void {
    const MAX_ACC_LOOP_BIT = 7;
    const MIN_ACC_LOOP_BIT = 0;

    var acc_loop_cnt = loopShuffle(ec, MAX_ACC_LOOP_BIT, MIN_ACC_LOOP_BIT);

    if (ec.mem == null) {
        return;
    }
    const wrap = ec.mem.?.block_size * ec.mem.?.blocks;

    if (loop_cnt > 0) acc_loop_cnt = loop_cnt;

    var i: usize = 0;
    while (i < (ec.mem.?.access_loops + acc_loop_cnt)) : (i += 1) {
        const tmpval = &ec.mem.?.ptr[ec.mem.?.location];

        // memory access: just add 1 to one byte.
        // -- implies read from and write to memory location.
        tmpval.* = @addWithOverflow(tmpval.*, 1)[0];

        // Addition of memblocksize - 1 to pointer with wrap around
        // to ensure that every memory location is hit evenly.
        ec.mem.?.location = ec.mem.?.location + ec.mem.?.block_size - 1;
        ec.mem.?.location = ec.mem.?.location % wrap;
    }
}

// +++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Entropy Processing
// +++++++++++++++++++++++++++++++++++++++++++++++++++++++

/// This is the heart of the entropy generation: calculate time deltas and
/// use the CPU jitter in the time deltas. The jitter is injected into the
/// entropy pool.
///
/// WARNING: ensure that ->prev_time is primed before using the output
/// 	    of this function! This can be done by calling this function
/// 	    and not using its result.
///
/// # Params
///
/// * `ec` - Reference to entropy collector
/// * `loop_cnt` - Testing purpose: allow test app to set the counter, not needed during production
///
/// # Returns
///
/// The current delta on success, `Error` otherwise.
pub fn measureJitter(ec: *jent.RandData, loop_cnt: u64, out_delta: ?*u64) !void {
    var time: u64 = 0;
    var current_delta: u64 = 0;
    var stuck_err: ?jent.Error = null;
    var stuck: bool = false;

    // Invoke one noise source before time measurement to add variation
    memAccess(ec, loop_cnt);

    // Get time stamp and calculate time delta to previous
    // invocation to measure the timing variations
    time = ec.callbacks.getNsTime();
    current_delta = jent.health.delta(ec.prev_time, time) / ec.common_timer_gcd;
    ec.prev_time = time;

    // Check whether we have a stuck measurement
    jent.health.rct.stuckTest(ec, current_delta) catch |e| {
        stuck_err = e;
        stuck = true;
    };

    // Now call the next noise sources which also injects the data
    jent.noise.hashTime(ec, current_delta, loop_cnt, stuck);

    if (out_delta) |o| {
        o.* = current_delta;
    }

    if (stuck) {
        return stuck_err.?;
    }
}

// +++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Tests
// +++++++++++++++++++++++++++++++++++++++++++++++++++++++

test "hashTime test #1" {}

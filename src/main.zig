//! CPU Jitter Random Number generator
//!
//! Based on the work of [smuellerDD](https://github.com/smuellerDD)
//!
//! This RNG uses a 256 bit entropy pool that collects its entropy
//! from measuring the execution time jitter over the execution of
//! SHA-3 hashing operations as well as memory accesses.

const std = @import("std");
const Random = std.rand.Random;
const testing = std.testing;

pub const Sha = std.crypto.hash.sha3.Sha3_256;
pub const Error = @import("error.zig").Error;
pub const gcd = @import("gcd.zig");
pub const health = @import("health.zig");
pub const timer = @import("timer.zig");
pub const noise = @import("noise.zig");
pub const base = @import("base.zig");
pub const base_user = @import("base-user.zig");

/// The output 256 bits can receive more than 256 bits of min entropy,
/// of course, but the 256-bit output of SHA3-256(M) can only asymptotically
/// approach 256 bits of min entropy, not attain that bound. Random maps will
/// tend to have output collisions, which reduces the creditable output entropy
/// (that is what SP 800-90B Section 3.1.5.1.2 attempts to bound).
///
/// The value "64" is justified in Appendix A.4 of the current 90C draft,
/// and aligns with NIST's in "epsilon" definition in this document, which is
/// that a string can be considered "full entropy" if you can bound the min
/// entropy in each bit of output to at least 1-epsilon, where epsilon is
/// required to be <= 2^(-32).
pub const ENTROPY_SAFETY_FACTOR = 64;

pub const DATA_SIZE_BITS = Sha.digest_length * 8;

/// A user allocated chunk of memory with some stats
pub const Memory = struct {
    /// Allocated memory slice to introduce uncertanty
    /// through memory access.
    ptr: []u8,
    /// Number of memory accesses per random bit generation
    access_loops: u64 = 128,
    /// Index to byte in ptr
    location: usize = 0,
    /// Number of memory blocks
    blocks: usize = 2,
    /// Size of one memory block in bytes
    block_size: usize = 1024,
};

/// The entropy pool
pub const RandData = struct {
    /// Hash state entropy pool
    hash_state: Sha = Sha.init(.{}),
    /// Previos time stamp
    prev_time: u64 = 0,
    /// Flags used to initialize
    flags: packed struct {
        /// Disable memory access for more entropy, saves the RAM required for entropy collector
        disable_memory_access: bool = true,
    } = .{},
    /// Oversampling rate
    osr: usize = 3,

    /// Data structure for memory access
    mem: ?Memory = null,

    /// Stuck test
    stuck_test: struct {
        last_delta: u64 = 0,
        last_delta2: u64 = 0,
    } = .{},

    health: struct {
        /// Number of stuck values
        rct_count: isize = 0,

        /// Adaptive Proportion Test for a significance level of 2^-30
        apt_cutoff: usize = 0,
        /// Number of collected observations in current window
        apt_observations: usize = 0,
        /// The number of times the reference symbol been encountered in the window
        apt_count: usize = 0,
        /// APT base reference
        apt_base: u64 = 0,

        /// Permanent health failure
        health_failure: health.Failure = .{
            .rct = false,
            .apt = false,
            .lag = false,
        },

        /// APT base reference set?
        apt_base_set: bool = false,
        fips_enabled: bool = true,
        /// Use internal high-res timer
        enable_notime: bool = false,
    } = .{},

    /// Common divisor for all time deltas
    common_timer_gcd: u64 = 1,

    callbacks: struct {
        /// Set a callback to run on health failure in FIPS mode. his function will take
        /// an action determined by the caller.
        fipsFailure: ?*const fn (ec: *RandData, health_failure: health.Failure) void = null,
        getNsTime: *const fn () u64,
    },

    /// Generator of one 256 bit random number
    ///
    /// This function fills the hash_state
    pub fn randomData(self: *@This()) void {
        var safety_factor: usize = 0;
        if (self.health.fips_enabled) {
            safety_factor = ENTROPY_SAFETY_FACTOR;
        }

        // Priming of the self.prev_time value
        noise.measureJitter(self, 0, null) catch {
            // TODO: handle this somehow ???
        };

        var k: usize = 0;
        while (true) {
            // Run loop until failure is encountered
            if (health.checkHealth(self)) |_| {
                break;
            }

            // If a stuck measurement is received, repeat measurement
            noise.measureJitter(self, 0, null) catch {
                continue;
            };

            // We multiply the loop value with self.osr to obtain the
            // oversampling rate requested by the caller
            k += 1;
            if (k >= ((DATA_SIZE_BITS + safety_factor) * self.osr)) {
                break;
            }
        }
    }

    pub fn block(self: *@This(), out: ?[]u8) void {
        var jent_block: [Sha.digest_length]u8 = undefined;
        self.hash_state.final(jent_block[0..]);
        if (out) |_out| {
            @memcpy(_out[0..], jent_block[0.._out.len]);
        }

        // Stir the new state with the data from the old state - the digest
        // of the old data is not considered to have entropy
        self.hash_state.update(jent_block[0..]);
        @memset(jent_block[0..], 0);
    }

    pub fn bytes(self: *@This(), out: []u8) !void {
        var len: usize = out.len;
        var i: usize = 0;

        while (len > 0) {
            self.randomData();

            if (health.checkHealth(self)) |failure| {
                if (failure.rct) {
                    return Error.Rct;
                } else if (failure.apt) {
                    return Error.Apt;
                } else {
                    return Error.Lag;
                }
            }

            const tocopy = if (Sha.digest_length < len)
                Sha.digest_length
            else
                len;

            self.block(out[i .. i + tocopy]);

            len -= tocopy;
            i += tocopy;
        }

        // Enhanced backtracking support: At this point, the hash state
        // contains the digest of the previous Jitter RNG collection round
        // which is inserted there by jent_read_random_block with the SHA
        // update operation. At the current code location we completed
        // one request for a caller and we do not know how long it will
        // take until a new request is sent to us. To guarantee enhanced
        // backtracking resistance at this point (i.e. ensure that an attacker
        // cannot obtain information about prior random numbers we generated),
        // but still stirring the hash state with old data the Jitter RNG
        // obtains a new message digest from its state and re-inserts it.
        // After this operation, the Jitter RNG state is still stirred with
        // the old data, but an attacker who gets access to the memory after
        // this point cannot deduce the random numbers produced by the
        // Jitter RNG prior to this point.
        self.block(null);
    }

    pub fn init(fips_enabled: bool, time: *const fn () u64, mem: ?Memory) !@This() {
        var ec = @This(){
            .health = .{ .fips_enabled = fips_enabled },
            .mem = mem,
            .callbacks = .{ .getNsTime = time },
        };

        // Initialize entropy collector -----------------

        // Initialize the apt
        health.apt.init(&ec, ec.osr);

        //  Was jent_entropy_init run (establishing the common GCD)?
        if (gcd.DeltaHistory.get()) |v| {
            ec.common_timer_gcd = v;
        } else {
            // It was not. This should probably be an error, but this
            // behavior breaks the test code. Set the gcd to a value that
            // won't hurt anything.
            ec.common_timer_gcd = 1;
        }

        ec.randomData();

        // Run self tests -------------------------------
        // The self-tests depend on the ec to be initialized correctly,
        // e.g., the APT cutoff being set.
        try base.entropyInitCommonPre();
        try base.timeEntropyInit(&ec);

        return ec;
    }
};

pub fn Jent(comptime time: fn () u64, comptime blocks: usize, comptime block_size: usize) type {
    return struct {
        state: RandData,
        mem: [blocks * block_size]u8,

        pub fn init() !@This() {
            var new = @This(){
                .state = undefined,
                .mem = undefined,
            };

            new.state = try RandData.init(
                true,
                time,
                Memory{
                    .ptr = new.mem[0..],
                    .blocks = blocks,
                    .block_size = block_size,
                },
            );

            return new;
        }

        pub fn random(self: *@This()) Random {
            return Random.init(self, fill);
        }

        pub fn fill(self: *@This(), out: []u8) void {
            var len: usize = out.len;
            var i: usize = 0;

            while (len > 0) {
                self.state.randomData();

                // TODO: there might occur situations where this
                // fails but how to handle them if fill doesn't
                // return a error?

                const tocopy = if (Sha.digest_length < len)
                    Sha.digest_length
                else
                    len;

                self.state.block(out[i .. i + tocopy]);

                len -= tocopy;
                i += tocopy;
            }

            // Enhanced backtracking support: At this point, the hash state
            // contains the digest of the previous Jitter RNG collection round
            // which is inserted there by jent_read_random_block with the SHA
            // update operation. At the current code location we completed
            // one request for a caller and we do not know how long it will
            // take until a new request is sent to us. To guarantee enhanced
            // backtracking resistance at this point (i.e. ensure that an attacker
            // cannot obtain information about prior random numbers we generated),
            // but still stirring the hash state with old data the Jitter RNG
            // obtains a new message digest from its state and re-inserts it.
            // After this operation, the Jitter RNG state is still stirred with
            // the old data, but an attacker who gets access to the memory after
            // this point cannot deduce the random numbers produced by the
            // Jitter RNG prior to this point.
            self.state.block(null);
        }
    };
}

test "main tests" {
    _ = gcd;
    _ = health;
    _ = timer;
    _ = noise;
    _ = base_user;
}

test "lol" {
    //var ec = try RandData.init();
    //_ = ec;
}

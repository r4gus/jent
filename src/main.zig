//! CPU Jitter Random Number generator
//!
//! Based on the work of [smuellerDD](https://github.com/smuellerDD)
//!
//! This RNG uses a 256 bit entropy pool that collects its entropy
//! from measuring the execution time jitter over the execution of
//! SHA-3 hashing operations as well as memory accesses.

const std = @import("std");
const testing = std.testing;

pub const Sha = std.crypto.hash.sha3.Sha3_256;
pub const Error = @import("error.zig").Error;
pub const gcd = @import("gcd.zig");
pub const health = @import("health.zig");
pub const timer = @import("timer.zig");
pub const noise = @import("noise.zig");
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
    osr: usize = 1,

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
    } = .{
        .getNsTime = base_user.getNsTime,
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
        _ = noise.measureJitter(self, 0) catch {
            // TODO: handle this somehow ???
        };

        var k: usize = 0;
        while (true) {
            // Run loop until failure is encountered
            if (health.checkHealth(self)) |_| {
                break;
            }

            // If a stuck measurement is received, repeat measurement
            _ = noise.measureJitter(self, 0) catch {
                continue;
            };

            // We multiply the loop value with self.osr to obtain the
            // oversampling rate requested by the caller
            k += 1;
            if (k >= ((DATA_SIZE_BITS * safety_factor) * self.osr)) {
                break;
            }
        }
    }

    pub fn block(self: *@This(), out: *[Sha.digest_length]u8) void {
        var jent_block: [Sha.digest_length]u8 = undefined;
        self.hash_state.final(jent_block[0..]);
        @memcpy(out[0..], jent_block[0..]);

        // Stir the new state with the data from the old state - the digest
        // of the old data is not considered to have entropy
        self.hash_state.update(jent_block[0..]);
        @memset(jent_block[0..], 0);
    }
};

test "main tests" {
    _ = gcd;
    _ = health;
    _ = timer;
    _ = noise;
    _ = base_user;
}

test "lol" {
    var rd = RandData{};
    rd.randomData();

    var buffer: [Sha.digest_length]u8 = undefined;

    var i: usize = 0;
    while (i < 16) : (i += 1) {
        rd.block(&buffer);
        std.debug.print("{s}\n", .{std.fmt.fmtSliceHexUpper(buffer[0..])});
    }
}

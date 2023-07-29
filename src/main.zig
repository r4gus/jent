//! CPU Jitter Random Number generator
//!
//! Based on the work of [smuellerDD](https://github.com/smuellerDD)
//!
//! This RNG uses a 256 bit entropy pool that collects its entropy
//! from measuring the execution time jitter over the execution of
//! SHA-3 hashing operations as well as memory accesses.

const std = @import("std");
const testing = std.testing;

pub const Error = @import("error.zig").Error;
pub const gcd = @import("gcd.zig");
pub const health = @import("health.zig");

/// The entropy pool
pub const RandData = struct {
    /// Hash state entropy pool
    hash_state: [64]u8 = .{0} ** 64,
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
    } = .{},
};

test "main tests" {
    _ = gcd;
    _ = health;
}

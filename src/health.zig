const std = @import("std");
const jent = @import("main.zig");

pub const rct = @import("health/rct.zig");
pub const apt = @import("health/apt.zig");

pub const Failure = packed struct {
    /// Failure in RCT health test
    rct: bool,
    /// Failure in APT healt test
    apt: bool,
    /// Failure in Lag Predictor health test
    lag: bool,
};

pub inline fn delta(prev: u64, next: u64) u64 {
    return if (next >= prev) next - prev else prev - next;
}

pub inline fn delta2(ec: *jent.RandData, current_delta: u64) u64 {
    const d2 = delta(ec.stuck_test.last_delta, current_delta);
    ec.stuck_test.last_delta = current_delta;
    return d2;
}

pub inline fn delta3(ec: *jent.RandData, d2: u64) u64 {
    const d3 = delta(ec.stuck_test.last_delta2, d2);
    ec.stuck_test.last_delta2 = d2;
    return d3;
}

/// Report any health test failures
///
/// # Params
///
/// * `ec` - Reference to entropy collector
///
/// # Returns
///
/// `Failure` struct if a failure was detected, null otherwise.
pub fn checkHealth(ec: *jent.RandData) ?Failure {
    // Test is only enabled in FIPS mode
    if (!ec.health.fips_enabled) {
        return null;
    }

    if (ec.callbacks.fipsFailure) |cb| {
        if (ec.health.health_failure.rct or
            ec.health.health_failure.apt or
            ec.health.health_failure.lag)
        {
            cb(ec, ec.health.health_failure);
        }
    }

    if (ec.health.health_failure.rct or
        ec.health.health_failure.apt or
        ec.health.health_failure.lag)
    {
        return ec.health.health_failure;
    }

    return null;
}

// +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Tests
// +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

test "health test" {
    _ = rct;
    _ = apt;
}

test "checkHealth test #1" {
    var rd = jent.RandData{};

    try std.testing.expectEqual(checkHealth(&rd), null);

    const f1 = Failure{
        .rct = true,
        .apt = false,
        .lag = false,
    };
    rd.health.health_failure.rct = true;
    try std.testing.expectEqual(f1, checkHealth(&rd).?);

    const f2 = Failure{
        .rct = false,
        .apt = true,
        .lag = false,
    };
    rd.health.health_failure.rct = false;
    rd.health.health_failure.apt = true;
    try std.testing.expectEqual(f2, checkHealth(&rd).?);

    const f3 = Failure{
        .rct = false,
        .apt = false,
        .lag = true,
    };
    rd.health.health_failure.apt = false;
    rd.health.health_failure.lag = true;
    try std.testing.expectEqual(f3, checkHealth(&rd).?);
}

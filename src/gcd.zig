const std = @import("std");
const Error = @import("error.zig").Error;

/// Calculate the Eucledian algorithm for GCD
inline fn gcd64(a: u64, b: u64) u64 {
    var A: u64 = a;
    var B: u64 = b;

    // a must be greater than or equal b
    if (a < b) {
        A = b;
        B = a;
    }

    while (B != 0) {
        const r = @mod(A, B);
        A = B;
        B = r;
    }

    return A;
}

const AnalyzeInternalResult = struct {
    running_gcd: u64,
    delta_sum: u64,
};

pub const DeltaHistory = struct {
    hist: []u64,
    allocator: std.mem.Allocator,

    /// The common divisor for all timestamp deltas
    var common_timer_gcd: u64 = 0;

    inline fn tested() bool {
        return common_timer_gcd != 0;
    }

    pub fn get() ?u64 {
        if (!tested()) return null;
        return common_timer_gcd;
    }

    pub fn init(nelem: usize, a: std.mem.Allocator) !@This() {
        var m = try a.alloc(u64, nelem);
        @memset(m, 0);
        return .{
            .hist = m,
            .allocator = a,
        };
    }

    pub fn deinit(self: @This()) void {
        self.allocator.free(self.hist);
    }

    pub fn addValue(self: @This(), i: usize, v: u64) void {
        self.hist[i] = v;
    }

    pub fn analyzeInternal(self: @This()) !AnalyzeInternalResult {
        if (self.hist.len == 0) return Error.Again;

        var result = AnalyzeInternalResult{
            .running_gcd = self.hist[0],
            .delta_sum = 0,
        };
        var last_delta = self.hist[0];

        // Perfom the analysis on the accumulated delta values
        for (self.hist[1..]) |delta| {
            // ensure that we have a varying delta timer which is necessary
            // for the calculation of entropy -- perform this check
            // only after the first loop is executed as we need to prime
            // the old_data value.
            if (delta >= last_delta) {
                result.delta_sum += delta - last_delta;
            } else {
                result.delta_sum += last_delta - delta;
            }
            last_delta = delta;

            // This calculates the gcd of all the delta values. that is
            // gcd(delta_1, delta_2, ..., delta_nelem)
            //
            // Some timers increment by a fixed (non-1) amount each step.
            // This code checks for such increments, and allows the library
            // to output the number of such changes have occurred.
            result.running_gcd = gcd64(delta, result.running_gcd);
        }

        return result;
    }

    pub fn analyze(self: @This()) !void {
        const ret = try self.analyzeInternal();

        // Variations of deltas of time must on average be larger than 1 to
        // ensure the entropy estimation implied with 1 is preserved.
        if (ret.delta_sum <= self.hist.len - 1) {
            return Error.MinVarVar;
        }

        // Set a sensible maximum value.
        if (ret.running_gcd >= (std.math.maxInt(u32) / 2)) {
            return Error.CoarseTime;
        }

        // Adjust all deltas by the observed (small) common factor.
        if (!tested()) {
            common_timer_gcd = ret.running_gcd;
        }
    }
};

pub fn selfTest(allocator: std.mem.Allocator) !void {
    const elem = 10;
    const exp = 3;

    var dh = DeltaHistory.init(elem, allocator) catch return Error.Gcd;
    defer dh.deinit();

    var i: usize = 0;
    while (i < elem) : (i += 1) {
        dh.addValue(i, @intCast(i * exp));
    }

    const ret = dh.analyzeInternal() catch return Error.Gcd;

    if (ret.running_gcd != exp) {
        return Error.Gcd;
    }
}

test "jent gcd selftest" {
    const allocator = std.testing.allocator;
    try selfTest(allocator);
}

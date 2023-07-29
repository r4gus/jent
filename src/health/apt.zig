//! Adaptive Proportion Test
//!
//! This test complies with SP800-90B section 4.4.2.

const jent = @import("../main.zig");

const apt_window_size = 512;

/// See the SP 800-90B comment #10b for the corrected cutoff for the SP 800-90B APT.
///
/// http://www.untruth.org/~josh/sp80090b/UL%20SP800-90B-final%20comments%20v1.9%2020191212.pdf
/// In in the syntax of R, this is C = 2 + qbinom(1 − 2^(−30), 511, 2^(-1/osr)).
/// (The original formula wasn't correct because the first symbol must
/// necessarily have been observed, so there is no chance of observing 0 of these
/// symbols.)
///
/// For any value above 14, this yields the maximal allowable value of 512
/// (by FIPS 140-2 IG 7.19 Resolution # 16, we cannot choose a cutoff value that
/// renders the test unable to fail).
const apt_cutoff_lookup = [15]usize{
    325,
    422,
    459,
    477,
    488,
    494,
    499,
    502,
    505,
    507,
    508,
    509,
    510,
    511,
    512,
};

pub fn init(ec: *jent.RandData, osr: usize) void {
    // Establish the apt_cutoff based on the presumed entropy rate of 1/osr.
    if (osr >= apt_cutoff_lookup[0..].len) {
        ec.health.apt_cutoff = apt_cutoff_lookup[apt_cutoff_lookup[0..].len - 1]; // last elem
    } else {
        ec.health.apt_cutoff = apt_cutoff_lookup[osr - 1];
    }
}

/// Reset the APT counter
///
/// # Params
///
/// * `ec` - Reference to entropy collector
fn reset(ec: *jent.RandData) void {
    // When reset, accept the _next_ value input as the new base.
    ec.health.apt_base_set = false;
}

pub fn insert(ec: *jent.RandData, current_delta: u64) void {
    // Initialize the base reference
    if (!ec.health.apt_base_set) {
        ec.health.apt_base = current_delta; // APT Step 1
        ec.health.apt_base_set = true; // APT Step 2

        // Reset APT counter
        // Note that we've taken in the first symbol in the window
        ec.health.apt_count = 1; // B = 1
        ec.health.apt_observations = 1;
    }

    if (current_delta == ec.health.apt_base) {
        ec.health.apt_count += 1; // B = B + 1

        // Note: ec.health.apt_count starts with one
        if (ec.health.apt_count >= ec.health.apt_cutoff) {
            ec.health.health_failure.apt = true;
        }
    }

    ec.health.apt_observations += 1;

    // Complete one window, the next symbol input will be the new apt_base
    if (ec.health.apt_observations >= apt_window_size) {
        reset(ec); // APT Step 4
    }
}

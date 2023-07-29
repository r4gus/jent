//! Stuck Test and its use as Repetition Count Test
//! The Jitter RNG uses an enhanced version of the Repetition Count Test
//! (RCT) specified in SP800-90B section 4.4.1. Instead of counting identical
//! back-to-back values, the input to the RCT is the counting of the stuck
//! values during the generation of one Jitter RNG output block.
//!
//! The RCT is applied with an alpha of 2^{-30} compliant to FIPS 140-2 IG 9.8.
//!
//! During the counting operation, the Jitter RNG always calculates the RCT
//! cut-off value of C. If that value exceeds the allowed cut-off value,
//! the Jitter RNG output block will be calculated completely but discarded at
//! the end. The caller of the Jitter RNG is informed with an error code.

const jent = @import("../main.zig");

/// Repetition Count Test as defined in SP800-90B section 4.4.1
///
/// # Params
///
/// * `ec` - Reference to entropy collector
/// * `stuck` - Indicator whether the value is stuck
fn insert(ec: *jent.RandData, stuck: bool) void {
    // If we have a count less than zero, a previous RCT round identified
    // a failure. We will not overwrite it.
    if (ec.health.rct_count > 0) return;

    if (stuck) {
        ec.health.rct_count += 1;

        // The cutoff value is based on the following consideration:
        // alpha = 2^-30 as recommended in FIPS 140-2 IG 9.8.
        // In addition, we require an entropy value H of 1/osr as this
        // is the minimum entropy required to provide full entropy.
        // Note, we collect (DATA_SIZE_BITS + ENTROPY_SAFETY_FACTOR)*osr
        // deltas for inserting them into the entropy pool which should
        // then have (close to) DATA_SIZE_BITS bits of entropy in the
        // conditioned output.
        //
        // Note, ec->rct_count (which equals to value B in the pseudo
        // code of SP800-90B section 4.4.1) starts with zero. Hence
        // we need to subtract one from the cutoff value as calculated
        // following SP800-90B. Thus C = ceil(-log_2(alpha)/H) = 30*osr.
        if (ec.health.rct_count >= (30 * ec.osr)) {
            ec.health.rct_count = -1;
            ec.health.health_failure.rct = true;
        }
    } else {
        ec.health.rct_count = 0;
    }
}

/// Stuck test by checking the:
///  * 1st derivative of the jitter measurement (time delta)
///  * 2nd derivative of the jitter measurement (delta of time deltas)
///  * 3rd derivative of the jitter measurement (delta of delta of time deltas)
///
/// All values MUST always be non-zero
///
/// # Params
///
/// * `ec` - Reference to entropy collector
/// * `current_delta` - Jitter time delta
///
/// # Returns
///
/// `Error.StuckBit` if we got a stuck bit (rejected bit), void else.
pub fn stuckTest(ec: *jent.RandData, current_delta: u64) !void {
    const delta2 = jent.health.delta2(ec, current_delta);
    const delta3 = jent.health.delta3(ec, delta2);

    jent.health.apt.insert(ec, current_delta);

    if (current_delta == 0 or delta2 == 0 or delta3 == 0) {
        // RCT with a stuck bit
        insert(ec, true);
        return jent.Error.StuckBit;
    }

    // RCT with a non-stuck bit
    insert(ec, false);
}

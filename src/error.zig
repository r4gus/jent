pub const Error = error{
    Again,
    /// Timer service not available
    NoTime,
    /// Timer too coarse for RNG
    CoarseTime,
    /// Timer is not monotonic increasing
    NoMonotonic,
    /// Timer variations too small for RNG
    MinVariation,
    /// Timer does not produce variations of variations (2nd derivation of time is zero)
    VarVar,
    /// Timer variations of variations is too small
    MinVarVar,
    /// Programming error
    ProgErr,
    /// RCT with a stuck bit
    StuckBit,
    /// Too many stuck results during init
    Stuck,
    /// Health test failed during initialization
    Health,
    /// RCT failed during initialization
    Rct,
    /// Hash self test failed
    Hash,
    /// Can't allocate memory
    Mem,
    /// GCD self-test failed
    Gcd,
    /// Failure in RCT health test
    RctFailure,
};

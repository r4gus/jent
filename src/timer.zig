const std = @import("std");
const jent = @import("main.zig");

pub inline fn getNsTimeInternal(ec: *jent.RandData) u64 {
    return ec.callbacks.getNsTime();
}

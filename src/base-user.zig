const std = @import("std");

pub fn getNsTime() u64 {
    return asm volatile (
        \\rdtsc
        \\shlq $32, %rdx
        \\addq %rax, %rdx
        : [out] "={rdx}" (-> u64),
    );
}

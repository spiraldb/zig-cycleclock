const builtin = @import("builtin");
const std = @import("std");

pub inline fn cycletime() u64 {
    const cpu: std.Target.Cpu = builtin.cpu;
    if (comptime cpu.arch.isAARCH64()) {
        return aarch64_cycletime();
    }
    @compileError("Unsupported CPU architecture: " ++ @tagName(cpu.arch));
}

inline fn aarch64_cycletime() u64 {
    var virtual_timer_value: u64 = undefined;
    asm volatile ("mrs %[result], cntvct_el0"
        : [result] "=r" (virtual_timer_value),
    );
    return virtual_timer_value;
}

test "simple test" {
    const time = cycletime();
    std.debug.print("Cycle Time: {}!\n", .{time});
}

const builtin = @import("builtin");
const std = @import("std");

pub inline fn now() u64 {
    const cpu: std.Target.Cpu = builtin.cpu;
    const os: std.Target.Os = builtin.os;

    if (comptime os.tag.isDarwin()) {
        const kperf = @import("./kperf.zig").KPerf.instance() catch @panic("Cannot setup KPerf");
        return kperf.get_counter() catch 0;
    }

    if (comptime cpu.arch == .x86_64) {
        return now_x86_64();
    }

    @compileError("Unsupported CPU architecture: " ++ @tagName(cpu.arch));
}

inline fn now_x86_64() u64 {
    var low: u64 = undefined;
    var high: u64 = undefined;
    asm volatile ("rdtsc"
        : [low] "={eax}" (low),
          [high] "={edx}" (high),
    );
    return (high << 32) | low;
}

test "simple test" {
    const first = now();
    std.debug.print("Cycle Time: {}!\n", .{first});
    const second = now();
    std.debug.print("Cycle Time: {}!\n", .{second});
    try std.testing.expect(first < second);
}

comptime {
    std.testing.refAllDecls(@import("kperf.zig"));
}

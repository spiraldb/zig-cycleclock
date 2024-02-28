const builtin = @import("builtin");
const std = @import("std");

pub inline fn now() u64 {
    const cpu: std.Target.Cpu = builtin.cpu;
    const os: std.Target.Os = builtin.os;

    if (comptime os.tag.isDarwin()) {
        const kperf = @import("./kperf.zig").KPerf.instance() catch @panic("Cannot setup KPerf");
        return kperf.get_counter() catch 0;
    }

    @compileError("Unsupported CPU architecture: " ++ @tagName(cpu.arch));
}

<<<<<<< Updated upstream
=======
inline fn now_x64_64() u64 {
    var low: u64 = undefined;
    var high: u64 = undefined;
    asm volatile ("rdtsc"
        : [low] "={eax}" (low),
          [high] "={edx}" (high),
    );
    return (high << 32) | low;
}

>>>>>>> Stashed changes
test "simple test" {
    std.debug.print("Cycle Time: {}!\n", .{now()});
    std.debug.print("Cycle Time: {}!\n", .{now()});
}

comptime {
    std.testing.refAllDecls(@import("kperf.zig"));
}

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

test "simple test" {
    const time = now();
    std.debug.print("Cycle Time: {}!\n", .{time});
}

comptime {
    std.testing.refAllDecls(@import("kperf.zig"));
}

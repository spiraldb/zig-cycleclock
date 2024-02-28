const std = @import("std");

/// Extracts counters from KPerf.
///
/// TODO(ngates): we could make this a generic interface to KPerf if we end up
///  needing more configuration options.
///
/// See https://gist.github.com/ibireme/173517c208c7dc333ba962c1f0d67d12
pub const KPerf = struct {
    const Self = @This();

    symbols: Symbols,

    var _instance: ?KPerf = null;

    const CFGWORD_EL0A32EN_MASK = 0x10000;
    const CFGWORD_EL0A64EN_MASK = 0x20000;
    const CFGWORD_EL1EN_MASK = 0x40000;
    const CFGWORD_EL3EN_MASK = 0x80000;
    const CFGWORD_ALLMODES_MASK = 0xf0000;

    const CPMU_NONE = 0;
    const CPMU_CORE_CYCLE = 0x02;
    const CPMU_INST_A64 = 0x8c;
    const CPMU_INST_BRANCH = 0x8d;
    const CPMU_SYNC_DC_LOAD_MISS = 0xbf;
    const CPMU_SYNC_DC_STORE_MISS = 0xc0;
    const CPMU_SYNC_DTLB_MISS = 0xc1;
    const CPMU_SYNC_ST_HIT_YNGR_LD = 0xc4;
    const CPMU_SYNC_BR_ANY_MISP = 0xcb;
    const CPMU_FED_IC_MISS_DEM = 0xd3;
    const CPMU_FED_ITLB_MISS = 0xd4;

    const KPC_CLASS_FIXED = 0;
    const KPC_CLASS_CONFIGURABLE = 1;
    const KPC_CLASS_POWER = 2;
    const KPC_CLASS_RAWPMU = 3;
    const KPC_CLASS_FIXED_MASK = 1 << KPC_CLASS_FIXED;
    const KPC_CLASS_CONFIGURABLE_MASK = 1 << KPC_CLASS_CONFIGURABLE;
    const KPC_CLASS_POWER_MASK = 1 << KPC_CLASS_POWER;
    const KPC_CLASS_RAWPMU_MASK = 1 << KPC_CLASS_RAWPMU;

    const COUNTERS_COUNT = 10;
    const CONFIG_COUNT = 8;
    const KPC_MASK = (KPC_CLASS_CONFIGURABLE_MASK | KPC_CLASS_FIXED_MASK);

    const ClassMask = u32; // KPC_CLASS mask.
    const Config = [*]u64;

    const Symbols = struct {
        /// Get running PMC classes.
        kpc_get_counting: *fn () callconv(.C) ClassMask,
        /// Set PMC classes to enable counting. Returns zero for success.
        kpc_set_counting: *fn (ClassMask) callconv(.C) c_int,
        /// Get thread PMC classes for the current thread.
        kpc_get_thread_counting: *fn () callconv(.C) ClassMask,
        /// Set PMC classes to enable counting for current thread. Returns zero for success.
        kpc_set_thread_counting: *fn (ClassMask) callconv(.C) c_int,
        /// Get counter accumulations for current thread.
        kpc_get_thread_counters: *fn (thread_id: u32, buffer_count: u32, buffers: [*]u64) callconv(.C) c_int,
        /// Get how many counters there are for a given mask.
        kpc_get_counter_count: *fn (ClassMask) callconv(.C) u32,
        /// Get how many config registers there are for a given mask.
        kpc_get_config_count: *fn (ClassMask) callconv(.C) u32,
        /// Set config registers.
        kpc_set_config: *fn (ClassMask, Config) callconv(.C) c_int,
        /// Acquire/release the counters used by the Power Manager.
        kpc_force_all_ctrs_set: *fn (c_int) c_int,
    };

    pub fn instance() !Self {
        if (_instance != null) {
            return _instance.?;
        }

        const RTLD_LAZY = 0x1;
        const handle: *anyopaque = std.c.dlopen(
            "/System/Library/PrivateFrameworks/kperf.framework/kperf",
            RTLD_LAZY,
        ) orelse return error.FailedToLoadKPerf;

        var symbols: Symbols = undefined;

        const info = @typeInfo(Symbols).Struct;
        inline for (info.fields) |f| {
            const sym: *anyopaque = std.c.dlsym(handle, f.name) orelse return error.FailedToLoadKPerf;
            @field(symbols, f.name) = @alignCast(@ptrCast(sym));
        }

        if (symbols.kpc_get_counter_count(KPC_MASK) != COUNTERS_COUNT) {
            std.debug.print("Wrong number of kperf counters\n", .{});
            return error.KPerfError;
        }

        if (symbols.kpc_get_config_count(KPC_MASK) != CONFIG_COUNT) {
            std.debug.print("Wrong number of kperf configs\n", .{});
            return error.KPerfError;
        }

        var config: [CONFIG_COUNT]u64 = .{0} ** CONFIG_COUNT;
        config[0] = CPMU_CORE_CYCLE | CFGWORD_EL0A64EN_MASK;
        config[3] = CPMU_INST_BRANCH | CFGWORD_EL0A64EN_MASK;
        config[4] = CPMU_SYNC_BR_ANY_MISP | CFGWORD_EL0A64EN_MASK;
        config[5] = CPMU_INST_A64 | CFGWORD_EL0A64EN_MASK;

        if (symbols.kpc_set_config(KPC_MASK, &config) > 0) {
            std.debug.print("kpc_set_config failed\n", .{});
            return error.KPerfError;
        }

        if (symbols.kpc_force_all_ctrs_set(1) > 0) {
            std.debug.print("kpc_force_all_ctrs_set failed\n", .{});
            return error.KPerfError;
        }

        if (symbols.kpc_set_counting(KPC_MASK) > 0) {
            std.debug.print("kpc_set_counting failed\n", .{});
            return error.KPerfError;
        }

        if (symbols.kpc_set_thread_counting(KPC_MASK) > 0) {
            std.debug.print("kpc_set_thread_counting failed\n", .{});
            return error.KPerfError;
        }

        _instance = .{ .symbols = symbols };
        return _instance.?;
    }

    pub fn get_counter(self: *const Self) !u64 {
        var counters: [10]u64 = undefined;
        if (self.symbols.kpc_get_thread_counters(0, 10, &counters) > 0) {
            return error.KPerfError;
        }
        // TODO(ngates): which counters contain what?
        return counters[2];
    }
};

test "kperf - run with sudo" {
    if (!@import("builtin").os.tag.isDarwin()) {
        return error.SkipZigTest;
    }

    const k = try KPerf.instance();
    std.debug.print("COUNTER {any}\n", .{try k.get_counter()});
}

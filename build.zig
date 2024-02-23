const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run unit tests");

    const lib_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/cycleclock.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib_unit_tests.addIncludePath(.{ .path = "src" });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    test_step.dependOn(&run_lib_unit_tests.step);
}

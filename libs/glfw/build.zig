const std = @import("std");
const build_util = @import("util");

pub fn build(b: *std.Build) void {
    const mod = b.addModule("glfw", .{
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(.{}),
    });
    mod.addImport("util", b.dependency("util", .{}).module("util"));
    mod.addImport("vulkan", b.dependency("vulkan", .{}).module("vulkan"));
    
    const tests = b.addTest(.{
        .root_module = mod,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run the tests");
    test_step.dependOn(&run_tests.step);
}

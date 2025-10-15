const std = @import("std");


pub fn build(b: *std.Build) void {
    _ = b.option(std.Target.Os.Tag, "os", "The operating system to target") orelse b.resolveTargetQuery(.{}).result.os.tag;
    _ = b.option(std.Target.Cpu.Arch, "arch", "The architecture to target");
    _ = b.option(bool, "release", "Compile with optimizations") orelse false;
    const util = b.dependency("util", .{}).module("util");
    
    const binding_generator = b.addExecutable(.{
        .name = "generate_bindings",
        .root_module = b.createModule(.{
            .target = b.resolveTargetQuery(.{}),
            .optimize = .ReleaseFast,
            .root_source_file = b.path("bindings/generate.zig"),
        }),
    });
    
    const bindings_runner = b.addRunArtifact(binding_generator);
    bindings_runner.setCwd(b.path("bindings"));
    bindings_runner.addFileArg(b.path("bindings/vk.xml"));
    const bindings_file = bindings_runner.addOutputFileArg("bindings.zig");
    
    const bindings_mod = b.addModule("types", .{
        .root_source_file = bindings_file,
    });
    bindings_mod.addImport("util", util);
    
    const mod = b.addModule("vulkan", .{
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(.{}),
    });
    mod.addImport("util", util);
    mod.addImport("types", bindings_mod);
    
    const tests = b.addTest(.{
        .root_module = mod,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run the tests");
    test_step.dependOn(&run_tests.step);
}

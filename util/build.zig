const std = @import("std");

pub fn add_module(b: *std.Build, name: []const u8, path: []const u8) void {
    _ = b.addModule(name, .{
        .root_source_file = b.path(path),
    });
}

pub fn add_module_with_test(b: *std.Build, name: []const u8, path: []const u8) void {
    const mod = b.addModule(name, .{
        .root_source_file = b.path(path),
        .target = b.resolveTargetQuery(.{}),
    });
    
    const tests = b.addTest(.{
        .root_module = mod,
    });
    const run_tests = b.addRunArtifact(tests);
    
    const step_name = std.fmt.allocPrint(b.allocator, "test_{s}", .{name}) catch @panic("no memory");
    const step_desc = std.fmt.allocPrint(b.allocator, "Test the {s} module", .{name}) catch @panic("no memory");
    const test_step = b.step(step_name, step_desc);
    test_step.dependOn(&run_tests.step);
}

pub fn add_modules_with_test(b: *std.Build, modules: anytype) void {
    const test_step = b.step("test", "Run all tests");
    const fields = @typeInfo(@TypeOf(modules)).@"struct".fields;
    
    inline for (fields) |field| {
        const mod_name = field.name;
        const main_file = @field(modules, mod_name);
        
        const mod = b.addModule(mod_name, .{
            .root_source_file = b.path(main_file),
            .target = b.resolveTargetQuery(.{}),
        });
        
        const tests = b.addTest(.{
            .root_module = mod,
        });
        const run_tests = b.addRunArtifact(tests);
        test_step.dependOn(&run_tests.step);
    }
}

pub fn build(b: *std.Build) void {
    add_modules_with_test(b, .{
        .util = "src/util.zig",
    });
}

const std = @import("std");
const build_util = @import("util");

const general_files = [_][]const u8 {
    "context.c",
    "init.c",
    "input.c",
    "monitor.c",
    "platform.c",
    "vulkan.c",
    "window.c",
    "egl_context.c",
    "osmesa_context.c",
    "null_init.c",
    "null_monitor.c",
    "null_window.c",
    "null_joystick.c",
};
const windows_files = [_][]const u8 {
    "win32_module.c",
    "win32_time.c",
    "win32_thread.c",
    "win32_init.c",
    "win32_joystick.c",
    "win32_monitor.c",
    "win32_window.c",
    "wgl_context.c",
};
const macos_files = [_][]const u8 {
    "cocoa_time.c",
    "posix_module.c",
    "posix_thread.c",
    "cocoa_init.m",
    "cocoa_joystick.m",
    "cocoa_monitor.m",
    "cocoa_window.m",
    "nsgl_context.m",
};
const linux_files = [_][]const u8 {
    "posix_module.c",
    "posix_time.c",
    "posix_thread.c",
    "x11_init.c",
    "x11_monitor.c",
    "x11_window.c",
    "xkb_unicode.c",
    "glx_context.c",
    "wl_init.c",
    "wl_monitor.c",
    "wl_window.c",
    "linux_joystick.c",
    "posix_poll.c",
};

const build_flags_windows = [_][]const u8 {
    "-D_GLFW_WIN32",
};
const build_flags_macos = [_][]const u8 {
    "-D_GLFW_COCOA",
};
const build_flags_linux = [_][]const u8 {
    "-D_GLFW_WAYLAND",
    "-D_GLFW_X11",
};

pub fn build(b: *std.Build) void {
    const target_os_option = b.option(std.Target.Os.Tag, "os", "The operating system to target");
    const target_arch_option = b.option(std.Target.Cpu.Arch, "arch", "The architecture to target");
    const release_option = b.option(bool, "release", "Compile with optimizations");
    const release = release_option orelse false;
    const target_os = target_os_option orelse b.resolveTargetQuery(.{}).result.os.tag;
    const link_static = b.option(bool, "link_static", "Statically include glfw in the executable, so you don't need the dynamic library at runtime") orelse false;
    const resolved_target = build_util.resolve_target(b, target_os_option, target_arch_option);
    
    const mod = b.addModule("glfw", .{
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(.{}),
    });
    mod.addImport("util", b.dependency("util", .{}).module("util"));
    mod.addImport("vulkan", b.dependency("vulkan", .{.os = target_os_option, .arch = target_arch_option, .release = release_option}).module("vulkan"));
    
    const options = b.addOptions();
    options.addOption(bool, "static_linked", link_static);
    options.addOption([]const u8, "for_lib", "glfw"); // this is needed because otherwise another library can have the same content, which will give an zig error (file exists in modules 'options0' and 'options1')
    const options_mod = options.createModule();
    mod.addImport("options", options_mod);
    
    if (link_static) {
        const source_updater = b.addExecutable(.{
            .name = "glfw_source_updater",
            .root_module = b.createModule(.{
                .root_source_file = b.path("update_glfw_source.zig"),
                .target = b.resolveTargetQuery(.{}),
                .optimize = .Debug,
            }),
            
        });
        const run_updater = b.addRunArtifact(source_updater);
        run_updater.has_side_effects = true;
        run_updater.setCwd(b.path("."));
        const dummy_source = run_updater.addOutputFileArg("dummy_source.c");
        mod.addIncludePath(b.path("glfw/src"));
        mod.addIncludePath(b.path("glfw/include/GLFW"));
        mod.addIncludePath(b.path("generated_headers"));
        mod.addSystemIncludePath(.{.cwd_relative = "/usr/include"});
        if (target_os == .windows) {
            mod.linkSystemLibrary("gdi32", .{});
        }
        
        const build_flags = switch (target_os) {
            .windows => &build_flags_windows,
            .macos => &build_flags_macos,
            .linux => &build_flags_linux,
            else => @panic("glfw does not support this os"),
        };
        mod.addCSourceFile(.{
            .file = dummy_source,
        });
        mod.addCSourceFiles(.{
            .root = b.path("glfw/src"),
            .files = &general_files,
            .flags = build_flags,
        });
        mod.addCSourceFiles(.{
            .root = b.path("glfw/src"),
            .files = switch (target_os) {
                .windows => &windows_files,
                .macos => &macos_files,
                .linux => &linux_files,
                else => @panic("glfw does not support this os"),
            },
            .flags = build_flags,
        });
        
        const glfw_c = b.addTranslateC(.{
            .root_source_file = dummy_source,
            .target = resolved_target,
            .optimize = if (release) .ReleaseFast else .Debug,
        });
        glfw_c.addIncludePath(b.path("glfw/include/GLFW"));
        glfw_c.addSystemIncludePath(.{.cwd_relative = "/usr/include"});
        const glfw_c_mod = glfw_c.createModule();
        mod.addImport("glfw_c", glfw_c_mod);
    }
    
    const tests = b.addTest(.{
        .root_module = mod,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run the tests");
    test_step.dependOn(&run_tests.step);
}

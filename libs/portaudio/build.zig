const std = @import("std");
const build_util = @import("util");

const general_files = [_][]const u8 {
    "common/pa_allocation.c",
    "common/pa_converters.c",
    "common/pa_cpuload.c",
    "common/pa_debugprint.c",
    "common/pa_dither.c",
    "common/pa_front.c",
    "common/pa_process.c",
    "common/pa_ringbuffer.c",
    "common/pa_stream.c",
    "common/pa_trace.c",
};
const windows_files = [_][]const u8 {
    "os/win/pa_win_coinitialize.c",
    "os/win/pa_win_hostapis.c",
    "os/win/pa_win_util.c",
    "os/win/pa_win_version.c",
    "os/win/pa_win_waveformat.c",
    "os/win/pa_win_wdmks_utils.c",
    "os/win/pa_x86_plain_converters.c",
    "hostapi/wasapi/pa_win_wasapi.c",
};
const macos_files = [_][]const u8 {
    "os/unix/pa_pthread_util.c",
    "os/unix/pa_unix_hostapis.c",
    "os/unix/pa_unix_util.c",
    "hostapi/coreaudio/pa_mac_core.c",
    "hostapi/coreaudio/pa_mac_core_blocking.c",
    "hostapi/coreaudio/pa_mac_core_utilities.c",
};
const linux_files = [_][]const u8 {
    "os/unix/pa_pthread_util.c",
    "os/unix/pa_unix_hostapis.c",
    "os/unix/pa_unix_util.c",
    "hostapi/alsa/pa_linux_alsa.c",
};

pub fn build(b: *std.Build) void {
    const target_os_option = b.option(std.Target.Os.Tag, "os", "The operating system to target");
    const target_arch_option = b.option(std.Target.Cpu.Arch, "arch", "The architecture to target");
    const release_option = b.option(bool, "release", "Compile with optimizations");
    const release = release_option orelse false;
    const target_os = target_os_option orelse b.resolveTargetQuery(.{}).result.os.tag;
    const link_static = b.option(bool, "link_static", "Statically include portaudio in the executable, so you don't need the dynamic library at runtime") orelse false;
    const resolved_target = build_util.resolve_target(b, target_os_option, target_arch_option);
    
    const mod = b.addModule("portaudio", .{
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(.{}),
    });
    mod.addImport("util", b.dependency("util", .{}).module("util"));
    
    const options = b.addOptions();
    options.addOption(bool, "static_linked", link_static);
    options.addOption([]const u8, "for_lib", "portaudio"); // this is needed because otherwise another library can have the same content, which will give an zig error (file exists in modules 'options0' and 'options1')
    const options_mod = options.createModule();
    mod.addImport("options", options_mod);
    
    if (link_static) {
        const source_updater = b.addExecutable(.{
            .name = "portaudio_source_updater",
            .root_module = b.createModule(.{
                .root_source_file = b.path("update_portaudio_source.zig"),
                .target = b.resolveTargetQuery(.{}),
                .optimize = .Debug,
            }),
        });
        const run_updater = b.addRunArtifact(source_updater);
        run_updater.has_side_effects = true;
        run_updater.setCwd(b.path("."));
        const dummy_source = run_updater.addOutputFileArg("dummy_source.c");
        mod.addIncludePath(b.path("portaudio/src"));
        mod.addIncludePath(b.path("portaudio/src/common"));
        mod.addIncludePath(b.path("portaudio/src/os/unix"));
        mod.addIncludePath(b.path("portaudio/src/os/win"));
        mod.addIncludePath(b.path("portaudio/include"));
        mod.addSystemIncludePath(.{.cwd_relative = "/usr/include"});
        if (target_os == .linux) {
            mod.addLibraryPath(.{.cwd_relative = "/usr/lib"});
            mod.linkSystemLibrary("asound", .{});
        }
        if (target_os == .windows) {
            mod.linkSystemLibrary("ole32", .{});
            mod.linkSystemLibrary("winmm", .{});
        }
        
        var build_flags = std.ArrayList([]const u8).empty;
        if (!release) {
            build_flags.append(b.allocator, "-DPA_ENABLE_DEBUG_OUTPUT") catch @panic("no memory");
        }
        switch (resolved_target.result.cpu.arch.endian()) {
            .little => build_flags.append(b.allocator, "-DPA_LITTLE_ENDIAN") catch @panic("no memory"),
            .big => build_flags.append(b.allocator, "-DPA_BIG_ENDIAN") catch @panic("no memory"),
        }
        switch (target_os) {
            .windows => {
                build_flags.append(b.allocator, "-D_WIN32_WINNT=0x0501") catch @panic("no memory");
                build_flags.append(b.allocator, "-DWINVER=0x0501") catch @panic("no memory");
                build_flags.append(b.allocator, "-D_CRT_SECURE_NO_WARNINGS") catch @panic("no memory");
                build_flags.append(b.allocator, "-DPA_USE_WASAPI=1") catch @panic("no memory");
            },
            .macos => {
                build_flags.append(b.allocator, "-DPA_USE_COREAUDIO=1") catch @panic("no memory");
                // Maybe the frameworks CoreAudio, AudioToolbox, AudioUnit, CoreFoundation, CoreServices
            },
            .linux => {
                build_flags.append(b.allocator, "-DPA_USE_ALSA=1") catch @panic("no memory");
            },
            else => @panic("portaudio does not support this os"),
        }
        
        mod.addCSourceFile(.{
            .file = dummy_source,
            .flags = build_flags.items,
        });
        mod.addCSourceFiles(.{
            .root = b.path("portaudio/src"),
            .files = &general_files,
            .flags = build_flags.items,
        });
        mod.addCSourceFiles(.{
            .root = b.path("portaudio/src"),
            .files = switch (target_os) {
                .windows => &windows_files,
                .macos => &macos_files,
                .linux => &linux_files,
                else => @panic("portaudio does not support this os"),
            },
            .flags = build_flags.items,
        });
        
        const portaudio_c = b.addTranslateC(.{
            .root_source_file = dummy_source,
            .target = resolved_target,
            .optimize = if (release) .ReleaseFast else .Debug,
        });
        portaudio_c.addIncludePath(b.path("portaudio/include"));
        portaudio_c.addSystemIncludePath(.{.cwd_relative = "/usr/include"});
        const portaudio_c_mod = portaudio_c.createModule();
        mod.addImport("portaudio_c", portaudio_c_mod);
    }
    
    const tests = b.addTest(.{
        .root_module = mod,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run the tests");
    test_step.dependOn(&run_tests.step);
}

const std = @import("std");

pub fn build(b: *std.Build) void {
    const as_dependency = b.option(bool, "as_dependency", "This is set to true when including crosap as dependency") orelse false;
    if (!as_dependency) {
        @panic("You can not build crosap itself, only build an app that depends on it.");
    }
}

const targets = std.StaticStringMap(std.Target.Query).initComptime(.{
    .{"native", std.Target.Query {
        .abi = .gnu,
    }},
    .{"linux_amd64", std.Target.Query {
        .cpu_arch = .x86_64,
        .cpu_model = .baseline,
        .os_tag = .linux,
        .abi = .gnu,
    }},
    .{"linux_aarch64", std.Target.Query {
        .cpu_arch = .aarch64,
        .cpu_model = .baseline,
        .os_tag = .linux,
        .abi = .gnu,
    }},
});

pub fn app(b: *std.Build, app_main: []const u8) void {
    const crosap_dep = b.dependencyFromBuildZig(@This(), .{
        .as_dependency = true,
    });
    
    const backend_option = b.option([]const u8, "backend", "The backend to compile for (required, but omitting shows available backends)");
    const target_option = b.option([]const u8, "target", "The target to compile for. Default is native, use 'list' to show available options.");
    const output_option = b.option([]const u8, "output", "The name for the compiled binary. Default is a the app name with the backend and compile target.");
    const optimize_option = b.standardOptimizeOption(.{});
    
    b.build_root.handle.access(app_main, .{}) catch {
        std.debug.print("The file {s} does not exist\n", .{app_main});
        return;
    };
    
    if (backend_option) |backend_name| {
        var backends_dir = crosap_dep.builder.build_root.handle.openDir("backends", .{}) catch @panic("backends directory not found");
        const valid = if (backends_dir.access(backend_name, .{})) true else |_| false;
        backends_dir.close();
        if (valid) {
            const backend_path = std.fmt.allocPrint(b.allocator, "backends/{s}/backend.zig", .{backend_name}) catch @panic("no memory");
            const main_path = std.fmt.allocPrint(b.allocator, "backends/{s}/main.zig", .{backend_name}) catch @panic("no memory");
            
            const target_name = target_option orelse "native";
            if (std.mem.eql(u8, target_name, "list")) {
                show_available_targets();
                b.invalid_user_input = true;
            } else if (targets.get(target_name)) |target_query| {
                const default_name = std.fmt.allocPrint(b.allocator, "{s} ({s} for {s})", .{name_part_of_path(app_main), backend_name, target_name}) catch @panic("no memory");
                const output_name = output_option orelse default_name;
                std.debug.print("Output: {s}\n", .{output_name});
                
                const resolved_target = b.resolveTargetQuery(target_query);
                build_using(b, crosap_dep, app_main, backend_path, main_path, output_name, resolved_target, optimize_option);
            } else {
                std.debug.print("Invalid target '{s}'.\n", .{target_name});
                show_available_targets();
                b.invalid_user_input = true;
            }
        } else {
            std.debug.print("Invalid backend '{s}'.\n", .{backend_name});
            show_available_backends(crosap_dep);
            b.invalid_user_input = true;
        }
    } else {
        std.debug.print("Specify the backend to use using the -Dbackend=... option.\n", .{});
        show_available_backends(crosap_dep);
        b.invalid_user_input = true;
    }
}

fn show_available_backends(crosap_dep: *std.Build.Dependency) void {
    var backends_dir = crosap_dep.builder.build_root.handle.openDir("backends", .{.iterate = true}) catch @panic("backends directory not found");
    var iterator = backends_dir.iterate();
    std.debug.print("Available backends:\n", .{});
    while (iterator.next() catch @panic("backends iterate error")) |entry| {
        std.debug.print("    {s}\n", .{entry.name});
    }
    backends_dir.close();
    std.debug.print("\n", .{});
}

fn show_available_targets() void {
    std.debug.print("Available targets:\n", .{});
    for (targets.keys()) |target_name| {
        std.debug.print("    {s}\n", .{target_name});
    }
    std.debug.print("\n", .{});
}

fn name_part_of_path(path: []const u8) []const u8 {
    var start = path.len;
    while (start > 0 and path[start-1] != '/') {
        start -= 1;
    }
    return path[start..];
}

fn build_using(b: *std.Build, crosap_dep: *std.Build.Dependency, app_path: []const u8, backend_path: []const u8, main_path: []const u8, output_name: []const u8, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const util = crosap_dep.builder.dependency("util", .{}).module("util");
    
    const crosap_api = b.createModule(.{
        .root_source_file = crosap_dep.path("crosap_api/crosap_api.zig"),
    });
    crosap_api.addImport("util", util);
    
    var backend_libs = std.StringHashMapUnmanaged(*std.Build.Module).empty;
    var backend_libs_dir = crosap_dep.builder.build_root.handle.openDir("backend_libs", .{.iterate = true}) catch @panic("backend_libs directory not found");
    var backend_iterator = backend_libs_dir.iterate();
    while (backend_iterator.next() catch @panic("backend libs iterate error")) |entry| {
        const file_name = std.fmt.allocPrint(b.allocator, "backend_libs/{s}/{s}.zig", .{entry.name, entry.name}) catch @panic("no memory");
        const module_name = std.fmt.allocPrint(b.allocator, "backend_{s}", .{entry.name}) catch @panic("no memory");
        
        const library = b.createModule(.{
            .root_source_file = crosap_dep.path(file_name),
        });
        library.addImport("util", util);
        library.addImport("crosap_api", crosap_api);
        backend_libs.put(b.allocator, module_name, library) catch @panic("no memory");
    }
    backend_libs_dir.close();
    
    const backend = b.createModule(.{
        .root_source_file = crosap_dep.path(backend_path),
    });
    backend.addImport("util", util);
    backend.addImport("crosap_api", crosap_api);
    var backend_libs_iterator = backend_libs.iterator();
    while (backend_libs_iterator.next()) |module| {
        backend.addImport(module.key_ptr.*, module.value_ptr.*);
    }
    
    const crosap = b.createModule(.{
        .root_source_file = crosap_dep.path("crosap/crosap.zig"),
    });
    crosap.addImport("util", util);
    crosap.addImport("backend", backend);
    crosap.addImport("crosap_api", crosap_api);
    
    const app_mod = b.createModule(.{
        .root_source_file = b.path(app_path),
    });
    app_mod.addImport("util", util);
    app_mod.addImport("crosap", crosap);
    
    const crosap_main = b.createModule(.{
        .root_source_file = crosap_dep.path("crosap_main/crosap_main.zig"),
    });
    crosap_main.addImport("util", util);
    crosap_main.addImport("app", app_mod);
    crosap_main.addImport("crosap", crosap);
    crosap_main.addImport("crosap_api", crosap_api);
    
    const main = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = crosap_dep.path(main_path),
        .strip = optimize != .Debug,
        .link_libc = true,
    });
    main.addImport("util", util);
    main.addImport("app", app_mod);
    main.addImport("crosap_main", crosap_main);
    main.addImport("crosap_api", crosap_api);
    main.addImport("backend", backend);
    
    backend_libs_iterator = backend_libs.iterator();
    while (backend_libs_iterator.next()) |module| {
        const name = module.key_ptr.*;
        if (!std.mem.startsWith(u8, name, "backend_render_") and !std.mem.startsWith(u8, name, "backend_audio_")) {
            var backend_libs_iterator2 = backend_libs.iterator();
            while (backend_libs_iterator2.next()) |module2| {
                const name2 = module2.key_ptr.*;
                if (std.mem.startsWith(u8, name2, "backend_render_") or std.mem.startsWith(u8, name2, "backend_audio_")) {
                    module.value_ptr.*.addImport(name2, module2.value_ptr.*);
                }
            }
        }
    }
    
    const libs = [_][]const u8 {
        "vulkan",
        "glfw",
    };
    for (libs) |lib_name| {
        if (crosap_dep.builder.lazyDependency(lib_name, .{})) |lib_dep| {
            const library = lib_dep.module(lib_name);
            const module_name = std.fmt.allocPrint(b.allocator, "lib_{s}", .{lib_name}) catch @panic("no memory");
            
            backend.addImport(module_name, library);
            crosap.addImport(module_name, library);
            app_mod.addImport(module_name, library);
            crosap_main.addImport(module_name, library);
            main.addImport(module_name, library);
            backend_libs_iterator = backend_libs.iterator();
            while (backend_libs_iterator.next()) |module| {
                module.value_ptr.*.addImport(module_name, library);
            }
        }
    }
    
    const exe_options = std.Build.ExecutableOptions {
        .name = output_name,
        .root_module = main,
        .linkage = .dynamic,
    };
    const exe = b.addExecutable(exe_options);
    if (target.result.os.tag == .windows and optimize != .Debug) {
        exe.subsystem = .Windows;
    }
    
    b.installArtifact(exe);
    
    const exe_run = b.addRunArtifact(exe);
    if (b.args) |args| {
        exe_run.addArgs(args);
    }
    const run_step = b.step("run", "Run executable");
    run_step.dependOn(&exe_run.step);
    
    const exe_check = b.addExecutable(exe_options);
    const check_step = b.step("check", "Check if it compiles");
    check_step.dependOn(&exe_check.step);
}

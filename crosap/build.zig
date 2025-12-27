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
    .{"windows_amd64", std.Target.Query {
        .cpu_arch = .x86_64,
        .cpu_model = .baseline,
        .os_tag = .windows,
    }},
});

pub fn app(b: *std.Build, app_main: []const u8) void {
    var threaded: std.Io.Threaded = .init(b.allocator);
    defer threaded.deinit();
    const io = threaded.io();
    
    const crosap_dep = b.dependencyFromBuildZig(@This(), .{
        .as_dependency = true,
    });
    
    const options_file = b.option([]const u8, "options_file", "The path to a file that contains build options, one option per line");
    const options_direct = b.option([]const u8, "options_direct", "Extra options that have precedence over options_file, seperated by semicolons");
    //const backend_option = b.option([]const u8, "backend", "The backend to compile for (required, but omitting shows available backends)");
    const target_option = b.option([]const u8, "target", "The target to compile for. Default is native, use 'list' to show available options.");
    const output_option = b.option([]const u8, "output", "The name for the compiled binary. Default is a the app name with the backend and compile target.");
    const release_option = b.option(bool, "release", "True to build a fast release executable, false to build a slower debug version");
    
    b.build_root.handle.access(app_main, .{}) catch {
        std.debug.print("The file {s} does not exist\n", .{app_main});
        return;
    };
    
    const optimize_bool = release_option orelse false;
    const optimize_mode: std.builtin.OptimizeMode = if (optimize_bool) .ReleaseFast else .Debug;
    
    const target_name = target_option orelse "native";
    var build_target: std.Build.ResolvedTarget = undefined;
    if (std.mem.eql(u8, target_name, "list")) {
        show_available_targets();
        b.invalid_user_input = true;
        return;
    } else if (targets.get(target_name)) |target_query| {
        build_target = b.resolveTargetQuery(target_query);
    } else {
        std.debug.print("Invalid target '{s}'.\n", .{target_name});
        show_available_targets();
        b.invalid_user_input = true;
    }
    const target_os = build_target.result.os.tag;
    const target_arch = build_target.result.cpu.arch;
    const default_name = target_name;
    const output_name = output_option orelse default_name;
    
    var options = std.StringHashMapUnmanaged([]const u8).empty;
    if (options_file) |options_file_path| {
        const file = std.fs.cwd().openFile(options_file_path, .{}) catch {
            std.debug.print("The options file {s} does not exist.\n", .{options_file_path});
            b.invalid_user_input = true;
            return;
        };
        defer file.close();
        var buffer: [4096]u8 = undefined;
        var reader = file.reader(io, &buffer);
        const file_content = reader.interface.allocRemaining(b.allocator, .unlimited) catch @panic("no memory");
        var splitted = std.mem.tokenizeAny(u8, file_content, "\n&");
        while (splitted.next()) |content| {
            const colon_index = std.mem.indexOfScalar(u8, content, ':') orelse {
                std.debug.print("The option {s} in the file {s} does not have a colon.\n", .{content, options_file_path});
                b.invalid_user_input = true;
                return;
            };
            const name = content[0..colon_index];
            const value = content[colon_index + 1 ..];
            options.put(b.allocator, name, b.allocator.dupe(u8, value) catch @panic("no memory")) catch @panic("no memory");
        }
    }
    if (options_direct) |direct_options| {
        var splitted = std.mem.tokenizeAny(u8, direct_options, "\n&");
        while (splitted.next()) |content| {
            const colon_index = std.mem.indexOfScalar(u8, content, ':') orelse {
                std.debug.print("The direct option {s} does not have a colon.\n", .{content});
                b.invalid_user_input = true;
                return;
            };
            const name = content[0..colon_index];
            const value = content[colon_index + 1 ..];
            options.put(b.allocator, name, b.allocator.dupe(u8, value) catch @panic("no memory")) catch @panic("no memory");
        }
    }
    
    var options_file_creator = b.addOptions();
    var options_iterator = options.iterator();
    while (options_iterator.next()) |option_entry| {
        options_file_creator.addOption([]const u8, option_entry.key_ptr.*, option_entry.value_ptr.*);
    }
    
    const backend_content = options.get("backend") orelse {
        std.debug.print("You need to specify the backend option.\n", .{});
        std.debug.print("For example: -Doptions_direct=backend:preferred_backend,fallback_backend(option:value)\n", .{});
        show_available_backends(crosap_dep);
        return;
    };
    const backend_items = option_parse_list(b.allocator, backend_content) catch @panic("invalid backend option");
    
    var link_static_list: []const []const u8 = &.{};
    if (options.get("link_static")) |static_txt| {
        link_static_list = option_parse_list(b.allocator, static_txt) catch @panic("invalid list");
    }
    var link_static = std.StringHashMapUnmanaged(void).empty;
    for (link_static_list) |lib_name| {
        link_static.put(b.allocator, lib_name, {}) catch @panic("no memory");
    }
    
    var backend_mod_list = std.ArrayList(u8).empty;
    for (backend_items, 0..) |backend_name, i| {
        if (i != 0) {
            backend_mod_list.append(b.allocator, ',') catch @panic("no memory");
        }
        backend_mod_list.appendSlice(b.allocator, backend_name) catch @panic("no memory");
    }
    const options_file_output = options_file_creator.getOutput();
    
    const imports_generator = b.addExecutable(.{
        .name = "generate_imports",
        .root_module = b.createModule(.{
            .target = b.resolveTargetQuery(.{}),
            .optimize = .Debug,
            .root_source_file = crosap_dep.path("crosap/imports_gen.zig"),
        }),
    });
    
    const imports_gen_runner = b.addRunArtifact(imports_generator);
    const imports_file = imports_gen_runner.addOutputFileArg("imports.zig");
    imports_gen_runner.addArg(backend_mod_list.items);
    
    const imports_mod = b.createModule(.{
        .root_source_file = imports_file,
    });
    
    const util = crosap_dep.builder.dependency("util", .{}).module("util");
    
    const crosap_api = b.createModule(.{
        .root_source_file = crosap_dep.path("crosap_api/crosap_api.zig"),
    });
    crosap_api.addImport("util", util);
    
    var backends = std.StringHashMapUnmanaged(*std.Build.Module).empty;
    var backends_dir = crosap_dep.builder.build_root.handle.openDir("backends", .{}) catch @panic("backends directory not found");
    defer backends_dir.close();
    for (backend_items) |backend_name| {
        var backend_dir = backends_dir.openDir(backend_name, .{}) catch {
            std.debug.print("The backend '{s}' does not exist.\n", .{backend_name});
            b.invalid_user_input = true;
            return;
        };
        defer backend_dir.close();
        
        backend_dir.access("backend.zig", .{}) catch {
            std.debug.print("The backend file '{s}/backend.zig' does not exist.\n", .{backend_name});
            b.invalid_user_input = true;
            return;
        };
        
        const path_from_crosap = std.fmt.allocPrint(b.allocator, "backends/{s}/backend.zig", .{backend_name}) catch @panic("no memory");
        const backend = b.createModule(.{
            .root_source_file = crosap_dep.path(path_from_crosap),
        });
        backend.addImport("util", util);
        backend.addImport("crosap_api", crosap_api);
        
        if (backend_dir.readFileAlloc("dependencies.txt", b.allocator, .unlimited)) |dependency_data| {
            var lines_iterator = std.mem.tokenizeScalar(u8, dependency_data, '\n');
            while (lines_iterator.next()) |line| {
                const dep_info = parse_dependency_line(line) orelse continue;
                const dep_lib = dep_info.library;
                const dep_mod = dep_info.module;
                
                var dep: *std.Build.Module = undefined;
                if (std.mem.eql(u8, dep_lib, "@render")) {
                    const dep_path = std.fmt.allocPrint(b.allocator, "render/{s}", .{dep_mod}) catch @panic("no memory");
                    dep = create_backend_lib_module(b, crosap_dep, dep_path, util, &link_static, target_os, target_arch, release_option) orelse return;
                    dep.addImport("util", util);
                } else if (std.mem.eql(u8, dep_lib, "@audio")) {
                    const dep_path = std.fmt.allocPrint(b.allocator, "audio/{s}", .{dep_mod}) catch @panic("no memory");
                    dep = create_backend_lib_module(b, crosap_dep, dep_path, util, &link_static, target_os, target_arch, release_option) orelse return;
                    dep.addImport("util", util);
                } else {
                    const lib = crosap_dep.builder.lazyDependency(dep_lib, .{
                        .link_static = if (link_static.contains(dep_lib)) true else null,
                        .os = target_os,
                        .arch = target_arch,
                        .release = release_option,
                    }) orelse return;
                    dep = lib.module(dep_mod);
                    dep.addImport("util", util);
                }
                backend.addImport(dep_info.name, dep);
            }
        } else |_| {}
        backends.put(b.allocator, backend_name, backend) catch @panic("no memory");
    }
    
    const crosap = b.createModule(.{
        .root_source_file = crosap_dep.path("crosap/crosap.zig"),
    });
    crosap.addImport("util", util);
    crosap.addImport("crosap_api", crosap_api);
    crosap.addImport("backend_modules", imports_mod);
    crosap.addAnonymousImport("options", .{
        .root_source_file = options_file_output,
    });
    var backend_iterator = backends.iterator();
    while (backend_iterator.next()) |entry| {
        imports_mod.addImport(entry.key_ptr.*, entry.value_ptr.*);
    }
    
    const app_mod = b.createModule(.{
        .root_source_file = b.path(app_main),
    });
    app_mod.addImport("util", util);
    app_mod.addImport("crosap", crosap);
    
    const is_library = false;
    
    if (is_library) {
        const main = b.createModule(.{
            .root_source_file = crosap_dep.path("crosap_main/lib_main.zig"),
            .target = build_target,
            .optimize = optimize_mode,
            .strip = optimize_mode != .Debug,
            .link_libc = true,
        });
        main.addImport("util", util);
        main.addImport("crosap", crosap);
        main.addImport("crosap_api", crosap_api);
        main.addImport("app", app_mod);
        
        const lib_options = std.Build.LibraryOptions {
            .name = output_name,
            .root_module = main,
            .linkage = .dynamic,
        };
        const lib = b.addLibrary(lib_options);
        
        b.installArtifact(lib);
        
        const exe_check = b.addLibrary(lib_options);
        const check_step = b.step("check", "Check if it compiles");
        check_step.dependOn(&exe_check.step);
    } else {
        const main = b.createModule(.{
            .root_source_file = crosap_dep.path("crosap_main/exe_main.zig"),
            .target = build_target,
            .optimize = optimize_mode,
            .strip = optimize_mode != .Debug,
            .link_libc = true,
        });
        main.addImport("util", util);
        main.addImport("crosap", crosap);
        main.addImport("crosap_api", crosap_api);
        main.addImport("app", app_mod);
        
        const exe_options = std.Build.ExecutableOptions {
            .name = output_name,
            .root_module = main,
            .linkage = .dynamic,
        };
        const exe = b.addExecutable(exe_options);
        if (build_target.result.os.tag == .windows and optimize_mode != .Debug) {
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

fn create_backend_lib_module(b: *std.Build, crosap_dep: *std.Build.Dependency, lib_path: []const u8, util: *std.Build.Module, link_static: *std.StringHashMapUnmanaged(void), target_os: std.Target.Os.Tag, target_arch: std.Target.Cpu.Arch, release: ?bool) ?*std.Build.Module {
    var dir = crosap_dep.builder.build_root.handle.openDir(lib_path, .{}) catch @panic("backend library not found");
    defer dir.close();
    
    const lib_name = std.fs.path.basename(lib_path);
    const source_path = std.fmt.allocPrint(b.allocator, "{s}/{s}.zig", .{lib_path, lib_name}) catch @panic("no memory");
    const mod = b.createModule(.{
        .root_source_file = crosap_dep.path(source_path),
    });
    mod.addImport("util", util);
    
    if (dir.readFileAlloc("dependencies.txt", b.allocator, .unlimited)) |dependency_data| {
        var lines_iterator = std.mem.tokenizeScalar(u8, dependency_data, '\n');
        while (lines_iterator.next()) |line| {
            const dep_info = parse_dependency_line(line) orelse continue;
            
            const lib = crosap_dep.builder.lazyDependency(dep_info.library, .{
                .link_static = if (link_static.contains(dep_info.library)) true else null,
                .os = target_os,
                .arch = target_arch,
                .release = release,
            }) orelse return null;
            const dep = lib.module(dep_info.module);
            dep.addImport("util", util);
            mod.addImport(dep_info.name, dep);
        }
    } else |_| {}
    
    return mod;
}

const Dependency_line = struct {
    name: []const u8,
    library: []const u8,
    module: []const u8,
};

fn parse_dependency_line(line: []const u8) ?Dependency_line {
    const without_comment = if (std.mem.indexOf(u8, line, "//")) |comment_index| (
        line[0..comment_index]
    ) else (
        line
    );
    const stripped = std.mem.trim(u8, without_comment, " \t\n");
    
    if (stripped.len == 0) {
        return null;
    }
    
    const colon_pos = std.mem.indexOfScalar(u8, line, ':');
    const slash_pos = std.mem.indexOfScalar(u8, line, '/');
    return if (colon_pos) |colon| (
        if (slash_pos) |slash| .{ // name:library/module
            .name = stripped[0..colon],
            .library = stripped[colon + 1 .. slash],
            .module = stripped[slash + 1 ..],
        } else .{ // name:libary
            .name = stripped[0..colon],
            .library = stripped[colon + 1 ..],
            .module = stripped[colon + 1 ..],
        }
    ) else (
        if (slash_pos) |slash| .{ // libary:module
            .name = stripped[slash + 1 ..],
            .library = stripped[0..slash],
            .module = stripped[slash + 1 ..],
        } else .{ // libary
            .name = stripped,
            .library = stripped,
            .module = stripped,
        }
    );
}


// From util/src/options.zig

fn option_parse_text(allocator: std.mem.Allocator, text: *[]const u8, end: []const u8) ![]const u8 {
    var braces_possible = true;
    if (std.mem.eql(u8, end, ")")) {
        braces_possible = false;
    } else if (std.mem.eql(u8, end, "")) {
        braces_possible = false;
    }
    
    var value = std.ArrayList(u8).empty;
    var real_count: usize = 0; // last index in value that is not a whitspace
    var braces_count: usize = 0;
    
    const in_braces = start: while (true) {
        switch (option_read_char(text, end)) {
            .normal => |c| {
                if (!is_whitespace(c)) {
                    if (c == '(') {
                        break:start true;
                    } else {
                        value.append(allocator, c) catch @panic("no memory");
                        real_count = value.items.len;
                        break:start false;
                    }
                }
            },
            .literal => |c| {
                value.append(allocator, c) catch @panic("no memory");
                real_count = value.items.len;
            },
            .end => {
                break:start false;
            }
        }
    };
    while (true) {
        var current_end = end;
        if (in_braces or braces_count > 0) {
            current_end = "";
        }
        switch (option_read_char(text, current_end)) {
            .normal => |c| {
                if (c == '(') {
                    value.append(allocator, '(') catch @panic("no memory");
                    real_count = value.items.len;
                    braces_count += 1;
                } else if (c == ')') {
                    if (braces_count > 0) {
                        value.append(allocator, ')') catch @panic("no memory");
                        real_count = value.items.len;
                        braces_count -= 1;
                    } else if (in_braces) {
                        break;
                    } else {
                        return error.too_many_closing_braces;
                    }
                } else if (is_whitespace(c)) {
                    value.append(allocator, c) catch @panic("no memory");
                } else {
                    value.append(allocator, c) catch @panic("no memory");
                    real_count = value.items.len;
                }
            },
            .literal => |c| {
                value.append(allocator, c) catch @panic("no memory");
                real_count = value.items.len;
            },
            .end => {
                if (in_braces or braces_count > 0) {
                    return error.not_enough_closing_braces;
                } else {
                    break;
                }
            }
        }
    }
    if (in_braces) {
        try read_expect_end(text, end);
    }
    return value.items[0..real_count];
}

fn option_parse_list(allocator: std.mem.Allocator, option_content: []const u8) ![][]const u8 {
    var content_copy = option_content;
    const text = &content_copy;
    var result = std.ArrayList([]const u8).empty;
    while (true) {
        const item = try option_parse_text(allocator, text, ":,");
        result.append(allocator, item) catch @panic("no memory");
        switch (option_read_char(text, ",")) {
            .normal => |c| {
                std.debug.assert(c == ':');
                _ = try option_parse_text(allocator, text, ",");
            },
            .literal => unreachable,
            .end => {}
        }
        switch (option_read_char(text, "")) {
            .normal => |c| {
                std.debug.assert(c == ',');
            },
            .literal => unreachable,
            .end => break,
        }
    }
    return result.items;
}

const Option_read_result = union(enum) {
    normal: u8,
    literal: u8,
    end,
};

fn option_read_char(text: *[]const u8, end: []const u8) Option_read_result {
    const len = text.*.len;
    if (len > 0) {
        const c = text.*[0];
        if (c == '\\') {
            const next = text.*[1];
            text.* = text.*[2..];
            return .{
                .literal = next,
            };
        } else {
            const is_end = for (end) |end_c| {
                if (c == end_c) {
                    break true;
                }
            } else false;
            if (is_end) {
                return .end;
            } else {
                text.* = text.*[1..];
                return .{
                    .normal = c,
                };
            }
        }
    } else {
        return .end;
    }
}

fn read_expect_end(text: *[]const u8, end: []const u8) !void {
    while (true) {
        switch (option_read_char(text, end)) {
            .normal => |c| {
                if (is_whitespace(c)) {
                    continue;
                } else {
                    return error.expected_the_end;
                }
            },
            .literal => return error.expected_the_end,
            .end => return,
        }
    }
}

fn is_whitespace(c: u8) bool {
    return switch (c) {
        ' ', '\t', '\n', '\r' => true,
        else => false,
    };
}

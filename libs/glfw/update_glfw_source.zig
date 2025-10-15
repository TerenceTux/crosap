const std = @import("std");

const day_in_seconds = 24 * 60 * 60;

const glfw_c_source = 
    \\#if defined(_WIN32)
    \\#define _GLFW_WIN32
    \\#elif defined(__APPLE__) || defined(__MACH__)
    \\#define _GLFW_COCOA
    \\#else
    \\#define _GLFW_X11
    \\#define _GLFW_WAYLAND
    \\#endif
    \\
    \\#include <vulkan/vulkan.h>
    \\#include "glfw3.h"
    \\#include "glfw3native.h"
    \\
;

fn run_command(alloc: std.mem.Allocator, args: []const []const u8) void {
    var process = std.process.Child.init(args, alloc);
    const result = process.spawnAndWait() catch @panic("Spawn error");
    const good_exit = switch (result) {
        .Exited => |exit_code| exit_code == 0,
        else => false,
    };
    if (!good_exit) {
        std.process.exit(1);
    }
}

fn update_headers(alloc: std.mem.Allocator, cwd: *std.fs.Dir, glfw_git: *std.fs.Dir, time: i64) void {
    cwd.makeDir("generated_headers") catch {};
    var wayland_xml_dir = glfw_git.openDir("deps/wayland", .{.iterate = true}) catch @panic("Can't open directory");
    defer wayland_xml_dir.close();
    var wayland_xml_iterator = wayland_xml_dir.iterate();
    while (wayland_xml_iterator.next() catch @panic("Iterate error")) |entry| {
        const xml_file = std.fmt.allocPrint(alloc, "glfw/deps/wayland/{s}", .{entry.name}) catch @panic("No memory");
        defer alloc.free(xml_file);
        const base_name = entry.name[0..std.mem.indexOfScalar(u8, entry.name, '.') orelse @panic("No dot")];
        const header_file = std.fmt.allocPrint(alloc, "generated_headers/{s}-client-protocol.h", .{base_name}) catch @panic("No memory");
        defer alloc.free(header_file);
        const header_file_code = std.fmt.allocPrint(alloc, "generated_headers/{s}-client-protocol-code.h", .{base_name}) catch @panic("No memory");
        defer alloc.free(header_file_code);
        run_command(alloc, &.{"wayland-scanner", "client-header", xml_file, header_file});
        run_command(alloc, &.{"wayland-scanner", "private-code", xml_file, header_file_code});
    }
    
    const update_file = cwd.createFile("last_glfw_update", .{}) catch @panic("Can't open file");
    defer update_file.close();
    var buffer: [64]u8 = undefined;
    var writer = update_file.writer(&buffer);
    writer.interface.print("{}", .{time}) catch @panic("Write error");
    writer.interface.flush() catch @panic("Write error");
}

pub fn main() void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    const args = std.process.argsAlloc(alloc) catch @panic("Error getting arguments");
    defer std.process.argsFree(alloc, args);
    if (args.len != 2) {
        @panic("Expected one argument");
    }
    
    const current_time = std.time.timestamp();
    var cwd = std.fs.cwd().openDir(".", .{}) catch @panic("Error opening cwd");
    defer cwd.close();
    if (cwd.openDir("glfw", .{})) |glfw_git_c| {
        var glfw_git = glfw_git_c;
        defer glfw_git.close();
        var needs_updating = true;
        if (cwd.readFileAlloc("last_glfw_update", alloc, .limited(256))) |last_update_txt| {
            defer alloc.free(last_update_txt);
            const last_update = std.fmt.parseInt(i64, last_update_txt, 10) catch @panic("Number parse error");
            if (last_update < current_time + day_in_seconds) {
                needs_updating = false;
            }
        } else |_| {}
        if (needs_updating) {
            glfw_git.setAsCwd() catch @panic("Can't set working directory");
            run_command(alloc, &.{"git", "pull"});
            cwd.setAsCwd() catch @panic("Can't set working directory");
            update_headers(alloc, &cwd, &glfw_git, current_time);
        }
    } else |_| {
        run_command(alloc, &.{"git", "clone", "https://github.com/glfw/glfw.git", "glfw"});
        var glfw_git = cwd.openDir("glfw", .{}) catch @panic("Can't open directory");
        update_headers(alloc, &cwd, &glfw_git, current_time);
    }
    
    const glfw_c_file = cwd.createFile(args[1], .{}) catch @panic("File create error");
    defer glfw_c_file.close();
    var buffer: [1024]u8 = undefined;
    var writer = glfw_c_file.writer(&buffer);
    writer.interface.writeAll(glfw_c_source) catch @panic("Write error");
    writer.interface.flush() catch @panic("Write error");
}

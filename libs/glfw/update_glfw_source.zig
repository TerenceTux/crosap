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

fn run_command(io: std.Io, args: []const []const u8, dir: std.Io.Dir) void {
    var process = std.process.spawn(io, .{
        .argv = args,
        .cwd = .{.dir = dir},
    }) catch @panic("Spawn error");
    const result = process.wait(io) catch @panic("Wait error");
    const good_exit = switch (result) {
        .exited => |exit_code| exit_code == 0,
        else => false,
    };
        if (!good_exit) {
            std.process.exit(1);
        }
}

fn update_headers(alloc: std.mem.Allocator, io: std.Io, cwd: std.Io.Dir, glfw_git: std.Io.Dir, time: i64) void {
    cwd.createDir(io, "generated_headers", .default_dir) catch {};
    var wayland_xml_dir = glfw_git.openDir(io, "deps/wayland", .{.iterate = true}) catch @panic("Can't open directory");
    defer wayland_xml_dir.close(io);
    var wayland_xml_iterator = wayland_xml_dir.iterate();
    while (wayland_xml_iterator.next(io) catch @panic("Iterate error")) |entry| {
        const xml_file = std.fmt.allocPrint(alloc, "glfw/deps/wayland/{s}", .{entry.name}) catch @panic("No memory");
        defer alloc.free(xml_file);
        const base_name = entry.name[0..std.mem.indexOfScalar(u8, entry.name, '.') orelse @panic("No dot")];
        const header_file = std.fmt.allocPrint(alloc, "generated_headers/{s}-client-protocol.h", .{base_name}) catch @panic("No memory");
        defer alloc.free(header_file);
        const header_file_code = std.fmt.allocPrint(alloc, "generated_headers/{s}-client-protocol-code.h", .{base_name}) catch @panic("No memory");
        defer alloc.free(header_file_code);
        run_command(io, &.{"wayland-scanner", "client-header", xml_file, header_file}, cwd);
        run_command(io, &.{"wayland-scanner", "private-code", xml_file, header_file_code}, cwd);
    }
    
    const update_file = cwd.createFile(io, "last_glfw_update", .{}) catch @panic("Can't open file");
    defer update_file.close(io);
    var buffer: [64]u8 = undefined;
    var writer = update_file.writer(io, &buffer);
    writer.interface.print("{}", .{time}) catch @panic("Write error");
    writer.interface.flush() catch @panic("Write error");
}

pub fn main(init: std.process.Init) void {
    const alloc = init.gpa;
    const io = init.io;
    var args = init.minimal.args.iterateAllocator(alloc) catch @panic("Error getting arguments");
    defer args.deinit();
    
    if (!args.skip()) {
        @panic("Expected one argument");
    }
    const output_file = args.next() orelse @panic("Expected one argument");
    if (args.skip()) {
        @panic("Expected one argument");
    }
    
    const current_time = std.Io.Clock.real.now(io).toSeconds();
    var cwd = std.Io.Dir.cwd().openDir(io, ".", .{}) catch @panic("Error opening cwd");
    defer cwd.close(io);
    if (cwd.openDir(io, "glfw", .{})) |glfw_git_c| {
        var glfw_git = glfw_git_c;
        defer glfw_git.close(io);
        var needs_updating = true;
        if (cwd.readFileAlloc(io, "last_glfw_update", alloc, .limited(256))) |last_update_txt| {
            defer alloc.free(last_update_txt);
            const last_update = std.fmt.parseInt(i64, last_update_txt, 10) catch @panic("Number parse error");
            if (current_time < last_update + day_in_seconds) {
                needs_updating = false;
            }
        } else |_| {}
        if (needs_updating) {
            run_command(io, &.{"git", "pull"}, glfw_git);
            update_headers(alloc, io, cwd, glfw_git, current_time);
        }
    } else |_| {
        run_command(io, &.{"git", "clone", "https://github.com/glfw/glfw.git", "glfw"}, cwd);
        var glfw_git = cwd.openDir(io, "glfw", .{}) catch @panic("Can't open directory");
        defer glfw_git.close(io);
        update_headers(alloc, io, cwd, glfw_git, current_time);
    }
    
    const glfw_c_file = cwd.createFile(io, output_file, .{}) catch @panic("File create error");
    defer glfw_c_file.close(io);
    var buffer: [1024]u8 = undefined;
    var writer = glfw_c_file.writer(io, &buffer);
    writer.interface.writeAll(glfw_c_source) catch @panic("Write error");
    writer.interface.flush() catch @panic("Write error");
}

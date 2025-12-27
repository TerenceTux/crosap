const std = @import("std");

const day_in_seconds = 24 * 60 * 60;

const dummy_c_source = 
    \\#include "portaudio.h"
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

fn update_headers(alloc: std.mem.Allocator, cwd: *std.fs.Dir, portaudio_git: *std.fs.Dir, time: i64) void {
    _ = alloc;
    _ = portaudio_git;
    const update_file = cwd.createFile("last_portaudio_update", .{}) catch @panic("Can't open file");
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
    
    var threaded: std.Io.Threaded = .init(alloc);
    defer threaded.deinit();
    const io = threaded.io();
    
    defer std.process.argsFree(alloc, args);
    if (args.len != 2) {
        @panic("Expected one argument");
    }
    
    const current_time = (std.Io.Clock.real.now(io) catch @panic("Error getting time")).toSeconds();
    var cwd = std.fs.cwd().openDir(".", .{}) catch @panic("Error opening cwd");
    defer cwd.close();
    if (cwd.openDir("portaudio", .{})) |portaudio_git_c| {
        var portaudio_git = portaudio_git_c;
        defer portaudio_git.close();
        var needs_updating = true;
        if (cwd.readFileAlloc("last_portaudio_update", alloc, .limited(256))) |last_update_txt| {
            defer alloc.free(last_update_txt);
            const last_update = std.fmt.parseInt(i64, last_update_txt, 10) catch @panic("Number parse error");
            if (current_time < last_update + day_in_seconds) {
                needs_updating = false;
            }
        } else |_| {}
        if (needs_updating) {
            portaudio_git.setAsCwd() catch @panic("Can't set working directory");
            run_command(alloc, &.{"git", "pull"});
            cwd.setAsCwd() catch @panic("Can't set working directory");
            update_headers(alloc, &cwd, &portaudio_git, current_time);
        }
    } else |_| {
        run_command(alloc, &.{"git", "clone", "https://github.com/PortAudio/portaudio.git", "portaudio"});
        var portaudio_git = cwd.openDir("portaudio", .{}) catch @panic("Can't open directory");
        update_headers(alloc, &cwd, &portaudio_git, current_time);
    }
    
    const portaudio_c_file = cwd.createFile(args[1], .{}) catch @panic("File create error");
    defer portaudio_c_file.close();
    var buffer: [1024]u8 = undefined;
    var writer = portaudio_c_file.writer(&buffer);
    writer.interface.writeAll(dummy_c_source) catch @panic("Write error");
    writer.interface.flush() catch @panic("Write error");
}

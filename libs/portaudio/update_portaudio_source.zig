const std = @import("std");

const day_in_seconds = 24 * 60 * 60;

const dummy_c_source = 
    \\#include "portaudio.h"
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

fn update_headers(alloc: std.mem.Allocator, io: std.Io, cwd: *std.Io.Dir, portaudio_git: *std.Io.Dir, time: i64) void {
    _ = alloc;
    _ = portaudio_git;
    const update_file = cwd.createFile(io, "last_portaudio_update", .{}) catch @panic("Can't open file");
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
    if (cwd.openDir(io, "portaudio", .{})) |portaudio_git_c| {
        var portaudio_git = portaudio_git_c;
        defer portaudio_git.close(io);
        var needs_updating = true;
        if (cwd.readFileAlloc(io, "last_portaudio_update", alloc, .limited(256))) |last_update_txt| {
            defer alloc.free(last_update_txt);
            const last_update = std.fmt.parseInt(i64, last_update_txt, 10) catch @panic("Number parse error");
            if (current_time < last_update + day_in_seconds) {
                needs_updating = false;
            }
        } else |_| {}
        if (needs_updating) {
            run_command(io, &.{"git", "pull"}, portaudio_git);
            update_headers(alloc, io, &cwd, &portaudio_git, current_time);
        }
    } else |_| {
        run_command(io, &.{"git", "clone", "https://github.com/PortAudio/portaudio.git", "portaudio"}, cwd);
        var portaudio_git = cwd.openDir(io, "portaudio", .{}) catch @panic("Can't open directory");
        portaudio_git.close(io);
        update_headers(alloc, io, &cwd, &portaudio_git, current_time);
    }
    
    const portaudio_c_file = cwd.createFile(io, output_file, .{}) catch @panic("File create error");
    defer portaudio_c_file.close(io);
    var buffer: [1024]u8 = undefined;
    var writer = portaudio_c_file.writer(io, &buffer);
    writer.interface.writeAll(dummy_c_source) catch @panic("Write error");
    writer.interface.flush() catch @panic("Write error");
}

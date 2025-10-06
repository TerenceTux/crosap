const builtin = @import("builtin");
const std = @import("std");
const u = @import("util");
const Crosap_main = @import("crosap_main.zig").Crosap_main;
const crosap_api = @import("crosap_api");
const Button_type = crosap_api.Button_type;
const Button_state = crosap_api.Button_state;
const Pointer = crosap_api.Pointer;


var cr_main: Crosap_main = undefined;

pub fn main() void {
    cr_main.init();
    const backend = &cr_main.cr.backend;
    
    main_loop: while (true) {
        if (cr_main.cr.should_close) {
            u.log(.{"App wanted to close, so we quit"});
            break;
        }
        
        u.log_start(.{"Polling for events"});
        backend.poll_events();
        u.log_end(.{});
        u.log_start(.{"Handling event queue"});
        while (backend.get_event()) |event| {
            switch (event) {
                .key_update => |event_info| {
                    cr_main.key_update(event_info.key, event_info.state);
                },
                .pointer_start => |event_info| {
                    cr_main.pointer_start(event_info.pointer);
                },
                .pointer_update => |event_info| {
                    cr_main.pointer_update(event_info.pointer);
                },
                .pointer_scroll => |event_info| {
                    cr_main.pointer_scroll(event_info.pointer, event_info.offset);
                },
                .pointer_stop => |event_info| {
                    cr_main.pointer_stop(event_info.pointer);
                },
                .quit => |_| {
                    u.log(.{"Close button was pressed, so we quit"});
                    u.log_end(.{"Ignore other events"});
                    break:main_loop;
                }
            }
        }
        u.log_end(.{"No more events"});
        
        cr_main.update();
    }
    
    cr_main.deinit();
}

fn print_file_line(stderr: *std.Io.Writer, file_name: []const u8, line: u64, column: u64) !void {
    const file = try std.fs.cwd().openFile(file_name, .{});
    defer file.close();
    
    var read_buffer: [4096]u8 = undefined;
    var reader = file.reader(&read_buffer);
    if (line == 0) {
        return;
    }
    for (0 .. line - 1) |_| {
        _ = reader.interface.discardDelimiterInclusive('\n') catch return;
    }
    
    while (true) {
        const char = reader.interface.takeByte() catch return;
        if (char == '\n' or char == '\r' or char == 0) {
            break;
        }
        stderr.writeByte(char) catch return;
    }
    stderr.print("\n", .{}) catch return;
    
    if (column == 0) {
        return;
    }
    for (0 .. column - 1) |_| {
        stderr.print(" ", .{}) catch return;
    }
    stderr.print("^", .{}) catch return;
}

fn panic_stacktrace(stderr: *std.Io.Writer, start_address: ?u64) void {
    const debug_info = std.debug.getSelfDebugInfo() catch |err| {
        stderr.print("Unable to dump stack trace: Unable to open debug info: {s}\n", .{@errorName(err)}) catch return;
        return;
    };
    
    var context: std.debug.ThreadContext = undefined;
    const has_context = std.debug.getContext(&context);
    if (!has_context) {
        stderr.print("We don't have thread context\n", .{}) catch return;
    }
    var it: std.debug.StackIterator = undefined;
    if (has_context) {
        it = std.debug.StackIterator.initWithContext(start_address, debug_info, &context) catch return;
    } else {
        it = std.debug.StackIterator.init(start_address, null);
    }
    defer it.deinit();
    
    var last_address: ?u64 = null;
    while (it.next()) |return_address| {
        if (last_address == return_address) {
            stderr.print("(Stack trace is repeating)\n", .{}) catch return;
            break;
        }
        last_address = return_address;
        
        const module = debug_info.getModuleForAddress(return_address) catch break;
        const symbol = module.getSymbolAtAddress(u.alloc, return_address) catch break;
        if (symbol.source_location) |source_location| {
            stderr.print("{s}:{d}:{d} - in function {s}\n", .{source_location.file_name, source_location.line, source_location.column, symbol.name}) catch return;
            print_file_line(stderr, source_location.file_name, source_location.line, source_location.column) catch {};
        } else {
            stderr.print("in function {s}\n", .{symbol.name}) catch return;
        }
        stderr.print("\n", .{}) catch return;
    }
}

fn panic_handler(msg: []const u8, first_trace_addr: ?usize) noreturn {
    const address = @returnAddress();
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    var stderr_file = std.fs.File.stderr().writer(&.{});
    var stderr = &stderr_file.interface;
    
    if (builtin.single_threaded) {
        stderr.print("panic: ", .{}) catch std.posix.abort();
    } else {
        const current_thread_id = std.Thread.getCurrentId();
        stderr.print("thread {} panic: ", .{current_thread_id}) catch std.posix.abort();
    }
    stderr.print("{s}\n", .{msg}) catch std.posix.abort();
    
    stderr.print("first trace addr = {?}\n", .{first_trace_addr}) catch std.posix.abort();
    
    panic_stacktrace(stderr, first_trace_addr orelse address);
    
    std.posix.abort();
}

//pub const panic = std.debug.FullPanic(panic_handler);

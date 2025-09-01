const builtin = @import("builtin");
const std = @import("std");
const u = @import("util");
const Backend = @import("backend").Backend;
const Crosap_main = @import("crosap_main").Crosap_main;
const Button_type = @import("crosap_main").Button_type;
const Button_state = @import("crosap_main").Button_state;
const Pointer = @import("crosap_main").Pointer;


var cr_main: Crosap_main = undefined;

pub fn main() void {
    cr_main.init();
    var backend = &cr_main.cr().backend;
    
    var pointer = Pointer {
        .position = .zero,
        .button_left = .up,
        .button_right = .up,
        .button_middle = .up,
    };
    var pointer_active = false; // pointer_in_window or pointer.button_*.is_pressed()
    var pointer_in_window = false;
    
    while (true) {
        if (cr_main.cr().should_close) {
            u.log(.{"App wanted to close, so we quit"});
            break;
        }
        
        u.log_start(.{"Polling for events"});
        backend.poll_events();
        u.log_end(.{});
        if (backend.should_close()) {
            u.log(.{"Close button was pressed, so we quit"});
            break;
        }
        u.log_start(.{"Handling event queue"});
        while (backend.events.pop_start()) |event| {
            switch (event) {
                .key_pressed => |keycode| {
                    if (glfw_keycode_to_key(keycode)) |key| {
                        cr_main.button_update(key, .down);
                    } else {
                        u.log(.{"Unsupported keycode ",keycode," pressed"});
                    }
                },
                .key_released => |keycode| {
                    if (glfw_keycode_to_key(keycode)) |key| {
                        cr_main.button_update(key, .up);
                    } else {
                        u.log(.{"Unsupported keycode ",keycode," released"});
                    }
                },
                .mouse_moved => |position| {
                    const changed = !position.equal_exact(pointer.position);
                    pointer.position = position;
                    if (pointer_active) {
                        if (changed) {
                            cr_main.pointer_update(&pointer);
                        }
                    } else {
                        if (pointer_in_window) {
                            pointer_active = true;
                            cr_main.pointer_start(&pointer);
                        }
                    }
                },
                .mouse_enter => |entered| {
                    pointer_in_window = entered;
                    if (pointer_active and !entered) {
                        if (!pointer.button_left.is_pressed() and !pointer.button_right.is_pressed() and !pointer.button_middle.is_pressed()) {
                            cr_main.pointer_stop(&pointer);
                            pointer_active = false;
                        }
                    }
                },
                .mouse_button_pressed => |button| {
                    var pointer_button_o: ?*Button_state = null;
                    if (button == 0) {
                        pointer_button_o = &pointer.button_left;
                    } else if (button == 1) {
                        pointer_button_o = &pointer.button_right;
                    } else if (button == 2) {
                        pointer_button_o = &pointer.button_middle;
                    }
                    if (pointer_button_o) |pointer_button| {
                        const changed = !pointer_button.is_pressed();
                        pointer_button.* = .up;
                        if (pointer_active) {
                            if (changed) {
                                cr_main.pointer_update(&pointer);
                            }
                        } else {
                            u.log(.{"Button press but pointer is not active"});
                        }
                    } else {
                        u.log(.{"Press of unknown button ",button});
                    }
                    
                },
                .mouse_button_released => |button| {
                    var pointer_button_o: ?*Button_state = null;
                    if (button == 0) {
                        pointer_button_o = &pointer.button_left;
                    } else if (button == 1) {
                        pointer_button_o = &pointer.button_right;
                    } else if (button == 2) {
                        pointer_button_o = &pointer.button_middle;
                    }
                    if (pointer_button_o) |pointer_button| {
                        const changed = pointer_button.is_pressed();
                        pointer_button.* = .up;
                        if (changed) {
                            if (pointer_active) {
                                if (!pointer_in_window and !pointer.button_left.is_pressed() and !pointer.button_right.is_pressed() and !pointer.button_middle.is_pressed()) {
                                    cr_main.pointer_stop(&pointer);
                                    pointer_active = false;
                                } else {
                                    cr_main.pointer_update(&pointer);
                                }
                            } else {
                                u.log(.{"There was a button release, but the pointer was not active"});
                            }
                        }
                    } else {
                        u.log(.{"Release of unknown button ",button});
                    }
                },
                .scroll => |direction| {
                    if (!direction.equal_exact(.zero)) {
                        if (pointer_active) {
                            cr_main.pointer_scroll(&pointer, direction);
                        } else {
                            u.log(.{"There was a scrolling event, but the pointer was not active"});
                        }
                    }
                }
            }
        }
        u.log_end(.{"No more events"});
        
        cr_main.update();
    }
    
    cr_main.deinit();
}

fn glfw_keycode_to_key(keycode: c_int) ?Button_type {
    // https://www.glfw.org/docs/3.3/group__keys.html
    return switch (keycode) {
        32 => .space,
        39 => .apostrophe,
        44 => .comma,
        45 => .minus,
        46 => .dot,
        47 => .slash,
        48 => .num_0,
        49 => .num_1,
        50 => .num_2,
        51 => .num_3,
        52 => .num_4,
        53 => .num_5,
        54 => .num_6,
        55 => .num_7,
        56 => .num_8,
        57 => .num_9,
        59 => .semicolon,
        61 => .equals,
        65 => .a,
        66 => .b,
        67 => .c,
        68 => .d,
        69 => .e,
        70 => .f,
        71 => .g,
        72 => .h,
        73 => .i,
        74 => .j,
        75 => .k,
        76 => .l,
        77 => .m,
        78 => .n,
        79 => .o,
        80 => .p,
        81 => .q,
        82 => .r,
        83 => .s,
        84 => .t,
        85 => .u,
        86 => .v,
        87 => .w,
        88 => .x,
        89 => .y,
        90 => .z,
        91 => .square_bracket_open,
        92 => .backslash,
        93 => .square_bracket_close,
        96 => .tick,
        256 => .escape,
        257 => .enter,
        258 => .tab,
        259 => .backspace,
        260 => .insert,
        261 => .delete,
        262 => .arrow_right,
        263 => .arrow_left,
        264 => .arrow_down,
        265 => .arrow_up,
        266 => .page_up,
        267 => .page_down,
        268 => .home,
        269 => .end,
        290 => .f1,
        291 => .f2,
        292 => .f3,
        293 => .f4,
        294 => .f5,
        295 => .f6,
        296 => .f7,
        297 => .f8,
        298 => .f9,
        299 => .f10,
        300 => .f11,
        301 => .f12,
        340 => .left_shift,
        341 => .left_control,
        342 => .left_alt,
        343 => .super,
        344 => .right_shift,
        345 => .right_control,
        346 => .right_alt,
        else => null,
    };
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

pub const panic = std.debug.FullPanic(panic_handler);

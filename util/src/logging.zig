const std = @import("std");
const u = @import("util.zig");

pub const Debug_Logger = struct {
    level: u16,
    frame_enabled: bool,
    writer: std.fs.File.Writer,
    this_line: u.List(u8),
    line_writer: u.List(u8).Writer,
    stream: u.byte_writer.Static_interface(u.List(u8).Writer),
    
    last_log: u64,
    
    pub fn init(l: *Logger) void {
        l.level = 0;
        l.frame_enabled = false;
        l.writer = std.fs.File.stderr().writer(&.{});
        l.last_log = 0;
    }
    
    pub fn deinit(l: *Logger) void {
        if (l.level != 0) {
            @panic("A log_start was not ended");
        }
    }
    
    fn stream_print(l: *Logger, comptime format: []const u8, args: anytype) void {
        const text = std.fmt.allocPrint(u.alloc, format, args) catch @panic("no memory");
        l.stream_write(text);
        u.alloc.free(text);
    }
    
    fn stream_write(l: *Logger, text: []const u8) void {
        l.stream.write_slice(text);
    }
    
    fn start_line(l: *Logger) void {
        const time = u.time_nanoseconds();
        const time_s = time / 1000_000_000;
        const time_u = time % 1000_000_000;
        l.this_line.init();
        l.line_writer = l.this_line.writer();
        l.stream = u.byte_writer.static(&l.line_writer);
        if (time - l.last_log >= 100000000) {
            l.stream_write("\n");
        }
        const color = if (time - l.last_log >= 10000000) "31" else "36";
        l.stream_print("\x1B[{s}m{d: >10}.{d:0>9}\x1B[0m \x1B[44m|\x1B[0m  ", .{color, time_s, time_u});
        for (0..l.level) |_| {
            l.stream_write(" \x1B[33m|\x1B[0m  ");
        }
        l.last_log = time;
    }
    
    fn end_line(l: *Logger) void {
        l.stream_write("\n");
        std.debug.lockStdErr();
        l.writer.interface.writeAll(l.this_line.items()) catch @panic("print error");
        l.writer.interface.flush() catch @panic("print error");
        std.debug.unlockStdErr();
        l.this_line.deinit();
    }
    
    fn print_value_array(l: *Logger, Child: type, v: []const Child) void {
        var is_text = false;
        if (Child == u8) {
            is_text = true;
            for (v) |char| {
                if (!std.ascii.isAscii(char)) {
                    is_text = false;
                    break;
                }
            }
        }
        if (is_text) {
            if (v.len == 0) {
                l.stream_write("\"\"");
            } else {
                l.stream_write(v);
            }
        } else {
            l.stream_write("[");
            for (v, 0..) |value, i| {
                if (i != 0) {
                    l.stream_write(", ");
                }
                l.print_value(value);
            }
            l.stream_write("]");
        }
    }
    
    fn print_value(l: *Logger, v: anytype) void {
        const v_t = @typeInfo(@TypeOf(v));
        switch (v_t) {
            .@"struct", .@"enum", .@"union", .@"opaque" => {
                if (@hasDecl(@TypeOf(v), "debug_print")) {
                    v.debug_print(l.stream);
                    return;
                }
            },
            else => {},
        }
        switch (v_t) {
            .type => l.stream_write(@typeName(@TypeOf(v))),
            .void => {},
            .bool => l.stream_write(if (v) "true" else "false"),
            .noreturn => l.stream_write("<noreturn>"),
            .int => l.stream_print("{d}", .{v}),
            .float => l.stream_print("{d}", .{v}),
            .pointer => |info| switch(info.size) {
                .one => l.print_value(v.*),
                .many => l.print_value_array(info.child, std.mem.span(v)), 
                .slice => l.print_value_array(info.child, v),
                .c => l.stream_print("{p}", v),
            },
            .array => |info| l.print_value_array(info.child, &v),
            .@"struct" => |info| {
                if (info.is_tuple) {
                    l.stream_write("{");
                    inline for (info.fields, 0..) |field, i| {
                        if (i != 0) {
                            l.stream_write(", ");
                        }
                        l.print_value(@field(v, field.name));
                    }
                    l.stream_write("}");
                } else {
                    l.stream_write("{");
                    inline for (info.fields, 0..) |field, i| {
                        if (i != 0) {
                            l.stream_write(", ");
                        }
                        l.stream_write(field.name);
                        l.stream_write(": ");
                        l.print_value(@field(v, field.name));
                    }
                    l.stream_write("}");
                }
            },
            .comptime_float => l.stream_print("{d}", .{v}),
            .comptime_int => l.stream_print("{d}", .{v}),
            .undefined => l.stream_write("<undefined>"),
            .null => l.stream_write("<null>"),
            .optional => if (v) |value| {
                l.print_value(value);
            } else {
                l.stream_write("null");
            },
            .error_union => if (v) |v_val| {
                l.print_value(v_val);
            } else |v_err| {
                l.print_value(v_err);
            },
            .error_set => l.stream_write(@errorName(v)),
            .@"enum" => l.stream_write(@tagName(v)),
            .@"union" => l.stream_write(@tagName(v)),
            .@"fn" => l.stream_write(@typeName(@TypeOf(v))),
            .@"opaque" => l.stream_write("<opaque>"),
            .frame => l.stream_write("<frame>"),
            .@"anyframe" => l.stream_write("<anyframe>"),
            .vector => l.stream_write("<vector>"),
            .enum_literal => l.stream_write(@tagName(v)),
        }
    }
    
    fn print(l: *Logger, v: anytype) void {
        switch (@typeInfo(@TypeOf(v))) {
            .@"struct" => |info| {
                if (info.is_tuple) {
                    inline for (info.fields) |field| {
                        l.print_value(@field(v, field.name));
                    }
                    return;
                }
            },
            else => {},
        }
        l.print_value(v);
    }
    
    pub fn log(l: *Logger, v: anytype) void {
        l.start_line();
        l.print(v);
        l.end_line();
    }
    
    pub fn log_start(l: *Logger, v: anytype) void {
        l.start_line();
        l.stream_write(" \x1B[32m>\x1B[0m ");
        l.print(v);
        l.end_line();
        l.level += 1;
    }
    
    pub fn log_end(l: *Logger, v: anytype) void {
        std.debug.assert(l.level > 0);
        l.level -= 1;
        l.start_line();
        l.stream_write(" \x1B[35m<\x1B[0m ");
        l.print(v);
        l.end_line();
    }
    
    pub fn frame_log(l: *Logger, v: anytype) void {
        _ = l;
        _ = v;
    }
    
    pub fn frame_log_start(l: *Logger, v: anytype) void {
        _ = l;
        _ = v;
    }
    
    pub fn frame_log_end(l: *Logger, v: anytype) void {
        _ = l;
        _ = v;
    }
    
    pub fn frame_visible(l: *Logger, enable: bool) void {
        _ = l;
        _ = enable;
    }
};

const Logger = if (u.debug) Debug_Logger else struct {
    pub fn init(l: *Logger) void {
        _ = l;
    }
    pub fn deinit(l: *Logger) void {
        _ = l;
    }
    pub fn log(l: *Logger, v: anytype) void {
        _ = l;
        _ = v;
    }
    pub fn log_start(l: *Logger, v: anytype) void {
        _ = l;
        _ = v;
    }
    pub fn log_end(l: *Logger, v: anytype) void {
        _ = l;
        _ = v;
    }
    pub fn frame_log(l: *Logger, v: anytype) void {
        _ = l;
        _ = v;
    }
    pub fn frame_log_start(l: *Logger, v: anytype) void {
        _ = l;
        _ = v;
    }
    pub fn frame_log_end(l: *Logger, v: anytype) void {
        _ = l;
        _ = v;
    }
    pub fn frame_visible(l: *Logger, enable: bool) void {
        _ = l;
        _ = enable;
    }
};
pub var logger: Logger = undefined;

pub fn log(v: anytype) void {
    logger.log(v);
}
pub fn log_start(v: anytype) void {
    logger.log_start(v);
}
pub fn log_end(v: anytype) void {
    logger.log_end(v);
}
pub fn frame_log(v: anytype) void {
    logger.frame_log(v);
}
pub fn frame_log_start(v: anytype) void {
    logger.frame_log_start(v);
}
pub fn frame_log_end(v: anytype) void {
    logger.frame_log_end(v);
}
pub fn frame_visible(enable: bool) void {
    logger.frame_visible(enable);
}

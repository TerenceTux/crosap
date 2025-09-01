const u = @import("util.zig");

// a reader also works as iterator
pub fn reader(T: type) type {
    return u.interface(struct {
        read: fn() ?T,
        
        pub fn Interface(Imp: type) type {
            return struct {
                const Selfp = *const @This();
                imp: Imp,
                
                pub fn read(s: Selfp) ?T {
                    return s.imp.call(.read, .{});
                }
            };
        }
    });
}
pub const byte_reader = reader(u8);


pub fn writer(T: type) type {
    return u.interface(struct {
        write: fn(v: T) void,
        
        pub fn Interface(Imp: type) type {
            return struct {
                const Selfp = *const @This();
                imp: Imp,
                
                pub fn write(s: Selfp, v: T) void {
                    return s.imp.call(.write, .{v});
                }
                
                pub fn write_slice(s: Selfp, values: []const T) void {
                    for (values) |v| {
                        s.write(v);
                    }
                }
            };
        }
    });
}
pub const byte_writer = writer(u8);


const buffer_size = 4096;

pub fn Buffered_byte_reader(Reader: type) type {
    return struct {
        const Self = @This();
        reader: *Reader,
        buffer: [buffer_size]u8,
        size: usize,
        start: usize,
        
        pub fn init(s: *Self, p_reader: *Reader) void {
            s.size = 0;
            s.start = 0;
            s.reader = p_reader;
        }
        
        pub fn read(s: *Self) ?u8 {
            if (s.start == s.size) {
                s.start = 0;
                s.size = s.reader.read(&s.buffer) catch @panic("read error");
                if (s.size == 0) {
                    return null;
                }
            }
            u.assert(s.size > s.start);
            const v = s.buffer[s.start];
            s.start += 1;
            return v;
        }
    };
}

pub fn Buffered_byte_writer(Writer: type) type {
    return struct {
        const Self = @This();
        writer: *Writer,
        buffer: [buffer_size]u8,
        size: usize,
        
        pub fn init(s: *Self, p_writer: *Writer) void {
            s.size = 0;
            s.writer = p_writer;
        }
        
        pub fn write(s: *Self, v: u8) void {
            s.buffer[s.size] = v;
            s.size += 1;
            if (s.size >= s.buffer.len) {
                s.flush();
            }
        }
        
        pub fn flush(s: *Self) void {
            if (s.size != 0) {
                s.writer.writeAll(s.buffer[0..s.size]) catch @panic("write error");
            }
        }
    };
}

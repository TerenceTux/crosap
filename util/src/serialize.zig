const u = @import("util.zig");
const std = @import("std");

/// Serializing data as bits (not just bytes)
/// The data knows when the end is, so there may be padding at the end
/// The data is always packed, there is no padding
/// The amount of bits a type takes may depend on the value
/// Comptime only types like type are of course not supported
/// Pointers are followed / allocated
/// Integers are stored big-endian
/// usize is a bit problematic, but we store it as 32 bit and panic if it doesn't fit
/// so it's best to only use usize values that fit in 32 bits
/// Floats are bitwise written
/// Arrays/vectors are just the elements one by one
/// Slices are stored with the length as either 0<8 bit length> or 1<32 bit length> and then the content
/// Multi-value pointers are not supported because we can't allocate them, because the allocator has the right to know the size when freeing.
/// Structs are in the order how they are defined
/// Enums use their backing integer
/// Tagged unions are stored as their tag with the data (variable length)
/// Non-tagged unions are not supported
/// Optionals are either 0 for null, or 1<content>

pub fn Exporter(Writer: type) type {
    bit_writer.validate(Writer);
    return struct {
        const This = @This();
        writer: Writer,
        
        pub fn create(writer: Writer) This {
            return .{
                .writer = writer,
            };
        }
        
        pub fn write(exporter: *This, value: anytype) void {
            exporter.write_as(@TypeOf(value), &value);
        }
        
        pub fn write_as(exporter: *This, T: type, value: *const T) void {
            const type_info = @typeInfo(T);
            if (u.has_method(T, "export_to_bits")) {
                value.export_to_bits(exporter);
                return;
            }
            switch (type_info) {
                .void => {},
                .bool => if (value.*) {
                    exporter.write_1();
                } else {
                    exporter.write_0();
                },
                .int => |int_info| {
                    if (T == usize) {
                        // we always store usize as u32
                        if (int_info.bits > 32 and value.* > std.math.maxInt(u32)) {
                            std.debug.panic("usize value of {} too high to fit in 32 bits for exporting", .{value.*});
                        }
                        const truncated: u32 = @intCast(value);
                        exporter.write_as(u32, &truncated);
                    } else {
                        switch (int_info.signedness) {
                            .signed => {
                                exporter.write_as(@Type(.{
                                    .int = .{
                                        .signedness = .unsigned,
                                        .bits = int_info.bits,
                                    }
                                }), @bitCast(T));
                            },
                            .unsigned => if (int_info.bits > 0) {
                                var bit: u.Uint_that_fits(int_info.bits - 1) = int_info.bits - 1;
                                while (true) {
                                    const bit_value = value.* & (1 << bit) != 0;
                                    exporter.write_bit(@intFromBool(bit_value));
                                    if (bit == 0) {
                                        break;
                                    } else {
                                        bit -= 1;
                                    }
                                }
                            },
                        }
                    }
                },
                .float => |float_info| {
                    exporter.write_as(@Type(.{
                        .int = .{
                            .signedness = .unsigned,
                            .bits = float_info.bits,
                        }
                    }), @bitCast(T));
                },
                .pointer => |pointer_info| {
                    switch (pointer_info.size) {
                        .one => {
                            exporter.write_as(pointer_info.child, value.*);
                        },
                        .many, .c => @compileError("multi item pointers are not supported"),
                        .slice => {
                            const slice = value.*;
                            if (slice.len > 255) {
                                exporter.write_1();
                                exporter.write(slice.len);
                            } else {
                                exporter.write_0();
                                exporter.write_as(u8, @intCast(slice.len));
                            }
                            for (slice) |item| {
                                exporter.write(item);
                            }
                        },
                    }
                },
                .array => |array_info| {
                    for (value) |*item| {
                        exporter.write_as(array_info.child, item);
                    }
                },
                .@"struct" => |struct_info| {
                    inline for (struct_info.fields) |field| {
                        exporter.write_as(field.type, &@field(value, field.name));
                    }
                },
                .optional => |optional_info| {
                    if (value) |*set_value| {
                        exporter.write_1();
                        exporter.write_as(optional_info.child, set_value);
                    } else {
                        exporter.write_0();
                    }
                },
                .@"enum" => |_| {
                    exporter.write(@intFromEnum(value));
                },
                .@"union" => |union_info| {
                    const Tag_type = union_info.tag_type orelse @compileError("Union "++@typeName(T)++" must have a tag, otherwise we don't know what field to export");
                    exporter.write(@as(Tag_type, value.*));
                    switch (value) {
                        inline else => |variant| {
                            exporter.write(variant);
                        }
                    }
                },
                .vector => |vector_info| {
                    for (value) |*item| {
                        exporter.write_as(vector_info.child, item);
                    }
                },
                else => @compileError("Invalid type "++@typeName(T)),
            }
        }
        
        pub fn write_bit(exporter: *This, bit: u1) void {
            exporter.writer.write(bit);
        }
        
        pub fn write_0(exporter: *This) void {
            exporter.write_bit(0);
        }
        
        pub fn write_1(exporter: *This) void {
            exporter.write_bit(1);
        }
    };
}

pub fn create_exporter(writer: anytype) Exporter(@TypeOf(writer)) {
    return Exporter(@TypeOf(writer)).create(writer);
}

pub const bit_writer = u.writer(u1);

// You have to call .deinit() at the end to send everything!
pub fn Bit_writer_from_int(bits: u16, Writer: type) type {
    const Int = @Type(.{
        .int = .{
            .signedness = .unsigned,
            .bits = bits,
        }
    });
    u.writer(Int).validate(Writer);
    return struct {
        const This = @This();
        writer: Writer,
        current_byte: u8,
        bit_index: u3, // the bit to write to, starts at 7
        
        pub fn write(w: *This, bit: u1) void {
            w.current_byte |= @as(u8, bit) << w.bit_index;
            if (w.bit_index == 0) {
                // wrote to the last bit of the byte
                w.writer.write(w.current_byte);
                w.current_byte = 0;
                w.bit_index = 7;
            } else {
                w.bit_index -= 1;
            }
        }
        
        pub fn deinit(w: *This) void {
            if (w.bit_index != 7) {
                w.writer.write(w.current_byte);
            }
        }
    };
}

pub fn create_bit_writer(bits: u16, writer: anytype) Bit_writer_from_int(bits, @TypeOf(writer)) {
    return .{
        .writer = writer,
        .current_byte = 0,
        .bit_index = 7,
    };
}


pub fn Importer(Reader: type) type {
    bit_reader.validate(Reader);
    return struct {
        const This = @This();
        reader: Reader,
        
        pub fn create(reader: Reader) This {
            return .{
                .reader = reader,
            };
        }
        
        pub fn read(importer: *This, T: type) T {
            var value: T = undefined;
            importer.read_to(T, &value);
            return value;
        }
        
        pub fn read_to(importer: *This, T: type, value: *T) void {
            const type_info = @typeInfo(T);
            if (u.has_method(T, "export_to_bits")) {
                value.import_from_bits(importer);
                return;
            }
            switch (type_info) {
                .void => {},
                .bool => {
                    value.* = importer.read_bool();
                },
                .int => |int_info| {
                    if (T == usize) {
                        var number: u32 = undefined;
                        importer.read_to(u32, &number);
                        if (int_info.bits < 32 and number > std.math.maxInt(usize)) {
                            std.debug.panic("the import of {} does not fit in our usize", .{number});
                        }
                        value.* = @intCast(number);
                    } else {
                        switch (int_info.signedness) {
                            .signed => {
                                importer.write_as(@Type(.{
                                    .int = .{
                                        .signedness = .unsigned,
                                        .bits = int_info.bits,
                                    }
                                }), @bitCast(T));
                            },
                            .unsigned => if (int_info.bits > 0) {
                                var number: T = 0;
                                var bit: u.Uint_that_fits(int_info.bits - 1) = int_info.bits - 1;
                                while (true) {
                                    if (importer.read_bool()) {
                                        number |= 1 << bit;
                                    }
                                    if (bit == 0) {
                                        break;
                                    } else {
                                        bit -= 1;
                                    }
                                }
                                value.* = number;
                            },
                        }
                    }
                },
                .float => |float_info| {
                    const Int = @Type(.{
                        .int = .{
                            .signedness = .unsigned,
                            .bits = float_info.bits,
                        }
                    });
                    const int_val: Int = undefined;
                    importer.read_to(Int, &int_val);
                    value.* = @bitCast(int_val);
                },
                .pointer => |pointer_info| {
                    switch (pointer_info.size) {
                        .one => {
                            value.* = u.alloc_single(pointer_info.child);
                            importer.read_to(pointer_info.child, value.*);
                        },
                        .many, .c => @compileError("multi item pointers are not supported"),
                        .slice => {
                            const len = if (importer.read_bool()) (
                                importer.read(usize)
                            ) else (
                                importer.read(u8)
                            );
                            const slice = u.alloc_slice(pointer_info.child, len);
                            for (slice) |*item| {
                                importer.read_to(pointer_info.child, item);
                            }
                            value.* = slice;
                        },
                    }
                },
                .array => |array_info| {
                    for (&value) |*item| {
                        importer.read_to(array_info.child, item);
                    }
                },
                .@"struct" => |struct_info| {
                    inline for (struct_info.fields) |field| {
                        importer.read_to(field.type, &@field(value, field.name));
                    }
                },
                .optional => |optional_info| {
                    if (importer.read_bool()) {
                        value.* = @as(optional_info.child, undefined);
                        importer.read_to(optional_info.child, &value.*.?);
                    } else {
                        value.* = null;
                    }
                },
                .@"enum" => |_| {
                    value.* = @intFromEnum(value);
                },
                .@"union" => |union_info| {
                    const Tag_type = union_info.tag_type orelse @compileError("Union "++@typeName(T)++" must have a tag, otherwise we don't know what field to export");
                    const tag = importer.read(Tag_type);
                    inline for (union_info.fields) |field| {
                        if (comptime u.bytes_equal(field.name, @tagName(tag))) {
                            value.* = @unionInit(T, field.name, undefined);
                            importer.read_to(field.type, &@field(value, field.name));
                            break;
                        }
                    }
                },
                .vector => |vector_info| {
                    for (&value) |*item| {
                        importer.read_to(vector_info.child, item);
                    }
                },
                else => @compileError("Invalid type "++@typeName(T)),
            }
        }
        
        pub fn read_bit(importer: *This) u1 {
            return importer.reader.read() orelse @panic("the reader did not give enough bytes for import");
        }
        
        pub fn read_bool(importer: *This) bool {
            return importer.read_bit() != 0;
        }
    };
}

pub fn create_importer(reader: anytype) Exporter(@TypeOf(reader)) {
    return Importer(@TypeOf(reader)).create(reader);
}

pub const bit_reader = u.reader(u1);

pub fn Bit_reader_from_int(bits: u16, Reader: type) type {
    const Int = @Type(.{
        .signedness = .unsigned,
        .bits = bits,
    });
    u.reader(Int).validate(Reader);
    return struct {
        const This = @This();
        reader: Reader,
        current_byte: u8,
        bit_index: u3, // The bit we have already read, so you can read bit_index - 1
        
        pub fn read(r: *This) ?u1 {
            return if (r.read_bool()) |val| (
                if (val) 1 else 0
            ) else null;
        }
        
        fn read_bool(r: *This) ?bool {
            if (r.bit_index == 0) {
                // no bits available, we need to retrieve a new byte
                r.current_byte = r.reader.read() orelse return null;
                r.bit_index = 7;
            } else {
                r.bit_index -= 1;
            }
            return r.current_byte & (1 << r.bit_index) != 0;
        }
    };
}

pub fn create_bit_reader(bits: u16, reader: anytype) Bit_reader_from_int(bits, @TypeOf(reader)) {
    return .{
        .writer = reader,
        .current_byte = 0,
        .bit_index = 0,
    };
}

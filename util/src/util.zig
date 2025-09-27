const std = @import("std");
const builtin = @import("builtin");


pub const interface = @import("interface.zig").interface;

pub const List = @import("dynamic_structures/list.zig").List;
pub const Queue = @import("dynamic_structures/queue.zig").Queue;
pub const Resource_list = @import("dynamic_structures/resource_list.zig").Resource_list;

const hashmap = @import("dynamic_structures/hashmap.zig");
pub const Custom_map = hashmap.Custom_map;
pub const Map = hashmap.Map;
pub const String_map = hashmap.String_map;
pub const Custom_set = hashmap.Custom_set;
pub const Set = hashmap.Set;
pub const String_set = hashmap.String_set;
pub const Custom_static_map = hashmap.Custom_static_map;
pub const Static_map = hashmap.Static_map;
pub const Static_string_map = hashmap.Static_string_map;
pub const Custom_static_set = hashmap.Custom_static_set;
pub const Static_set = hashmap.Static_set;
pub const Static_string_set = hashmap.Static_string_set;

pub const Vec2i = @import("vec.zig").Vec2i;
pub const Vec2r = @import("vec.zig").Vec2r;
pub const Rect2i = @import("vec.zig").Rect2i;
pub const Rect2r = @import("vec.zig").Rect2r;

pub const Int = @import("number.zig").Int;
pub const Real = @import("number.zig").Real;

pub const Color = @import("color.zig").Color;
pub const Screen_color = @import("color.zig").Screen_color;

pub const reader = @import("reader_writer.zig").reader;
pub const writer = @import("reader_writer.zig").writer;
pub const byte_reader = @import("reader_writer.zig").byte_reader;
pub const byte_writer = @import("reader_writer.zig").byte_writer;
pub const Buffered_byte_reader = @import("reader_writer.zig").Buffered_byte_reader;
pub const Buffered_byte_writer = @import("reader_writer.zig").Buffered_byte_writer;
pub const Slice_reader = @import("reader_writer.zig").Slice_reader;

pub const drawable = @import("drawing.zig").drawable;
pub const Draw_point = @import("drawing.zig").Point;

pub const option = @import("options.zig");
pub const types = @import("types.zig");
pub const serialize = @import("serialize.zig");

pub const event = @import("event.zig");


pub var alloc: std.mem.Allocator = undefined;
const alloc_interface = &@import("allocator.zig").alloc_interface;

pub fn alloc_single(T: type) *T {
    if (@inComptime()) {
        var val: T = undefined;
        return &val;
    } else {
        alloc.create(T) catch @panic("no memory");
    }
}

pub fn free_single(ptr: anytype) void {
    if (@inComptime()) {
        // freeing is not necessary in comptime
    } else {
        alloc.destroy(ptr);
    }
}

pub fn alloc_slice(T: type, count: usize) []T {
    if (@inComptime()) {
        var val: [count]T = undefined;
        return &val;
    } else {
        return alloc.alloc(T, count) catch @panic("no memory");
    }
}

pub fn free_slice(ptr: anytype) void {
    assert(@typeInfo(@TypeOf(ptr)).pointer.size == .slice);
    if (@inComptime()) {
        // freeing is not necessary in comptime
    } else {
        alloc.free(ptr);
    }
}

pub fn realloc(ptr: anytype, new_size: usize) []@typeInfo(@TypeOf(ptr)).pointer.child {
    assert(@typeInfo(@TypeOf(ptr)).pointer.size == .slice);
    const T = @typeInfo(@TypeOf(ptr)).pointer.child;
    if (@inComptime()) {
        if (new_size <= ptr.len) {
            return ptr[0..new_size];
        } else {
            var new: [new_size]T = undefined;
            @memcpy(new[0..ptr.len], ptr);
            return &new;
        }
    } else {
        return alloc.realloc(ptr, new_size) catch @panic("no memory");
    }
}

pub fn dupe_slice(input: anytype) []@typeInfo(To_slice_type(@TypeOf(input))).pointer.child {
    const Child = @typeInfo(To_slice_type(@TypeOf(input))).pointer.child;
    const slice = to_slice(input);
    const new = alloc_slice(Child, slice.len);
    @memcpy(new, slice);
    return new;
}

fn To_slice_type(In: type) type {
    const pointer_info = @typeInfo(In).pointer;
    return switch (pointer_info.size) {
        .slice => In,
        .one => if (pointer_info.is_const) (
            return []const @typeInfo(pointer_info.child).array.child
        ) else (
            return []@typeInfo(pointer_info.child).array.child
        ),
        else => unreachable,
    };
}

fn to_slice(in: anytype) To_slice_type(@TypeOf(in)) {
    return in;
}

pub fn bytes_equal(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) {
        return false;
    }
    for (a, b) |a_c, b_c| {
        if (a_c != b_c) {
            return false;
        }
    }
    return true;
}


pub var random: std.Random = undefined;
var rng: std.Random.DefaultPrng = undefined;

pub const debug = builtin.mode == .Debug;

var start_time: std.time.Instant = undefined;

pub fn init() void {
    alloc = alloc_interface.init();
    start_time = std.time.Instant.now() catch @panic("no timer available");
    logger.init();
    rng = .init(std.crypto.random.int(u64));
    random = rng.random();
}

pub fn deinit() void {
    logger.deinit();
    alloc_interface.deinit();
}

// nanoseconds
pub fn time_nanoseconds() u64 {
    const now = std.time.Instant.now() catch @panic("no timer available");
    return now.since(start_time);
}

pub fn time_seconds() Real {
    const nanoseconds = time_nanoseconds();
    const seconds = @as(f64, @floatFromInt(nanoseconds)) / 1000_000;
    return .from_float(seconds);
}

const logging_module = @import("logging.zig");
const logger = &logging_module.logger;
pub const log = logging_module.log;
pub const log_start = logging_module.log_start;
pub const log_end = logging_module.log_end;
pub const frame_log = logging_module.frame_log;
pub const frame_log_start = logging_module.frame_log_start;
pub const frame_log_end = logging_module.frame_log_end;
pub const frame_visible = logging_module.frame_visible;

pub fn assert(must_be: bool) void {
    if (!must_be) {
        unreachable;
    }
}

pub fn has_method(Type: type, comptime name: []const u8) bool {
    const type_info = @typeInfo(Type);
    switch (type_info) {
        .@"struct", .@"enum", .@"union", .@"opaque" => {
            return @hasDecl(Type, name);
        },
        .pointer => |pointer_info| {
            if (pointer_info.size == .one) {
                const Child = pointer_info.child;
                switch (@typeInfo(Child)) {
                    .@"struct", .@"enum", .@"union", .@"opaque" => {
                        return @hasDecl(Child, name);
                    },
                    else => {},
                }
            }
        },
        else => {},
    }
    return false;
}

// Returns the unsigned integer type that can at least contain the number 0 to max (inclusive)
pub fn Uint_that_fits(comptime max: usize) type {
    const bits = std.math.log_int(usize, 2, max);
    // if max = 7, bits is 2, so we need 3 bits
    // if max = 8, bits is 3, so we need 4 bits to hold the number 8
    return @Type(.{
        .int = .{
            .signedness = .unsigned,
            .bits = bits + 1,
        },
    });
}


// https://graphics.stanford.edu/~seander/bithacks.html#RoundUpPowerOf2
pub fn next_power_of_two(inp: u32) u32 {
    if (inp == 0) {
        return 1;
    }
    var v = inp - 1;
    v |= v >> 1;
    v |= v >> 2;
    v |= v >> 4;
    v |= v >> 8;
    v |= v >> 16;
    return v + 1;
}

pub const number_chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

pub fn write_int_string(to_writer: anytype, inp: anytype, base: u8) void {
    byte_writer.validate(to_writer);
    if (inp == 0) {
        to_writer.write(number_chars[0]);
        return;
    }
    const inp_info = @typeInfo(@TypeOf(inp)).int;
    switch (inp_info.signedness) {
        .signed => {
            var absolute = inp;
            if (inp < 0) {
                to_writer.write('-');
                absolute = -inp;
            }
            const unsigned: std.meta.Int(.unsigned, inp_info.bits) = @intCast(absolute);
            write_positive_int_string(to_writer, unsigned, base);
        },
        .unsigned => {
            write_positive_int_string(to_writer, inp, base);
        },
    }
}
pub fn write_positive_int_string(to_writer: anytype, inp: anytype, base_i: u8) void {
    byte_writer.validate(to_writer);
    assert(base_i > 1);
    assert(base_i <= number_chars.len);
    const Type = @TypeOf(inp);
    assert(@typeInfo(Type).int.signedness == .unsigned);
    
    const base: Type = base_i;
    var int: Type = inp;
    if (inp < 0) {
        to_writer.write('-');
        int = -inp;
    }
    
    var factor: Type = 1;
    while (true) {
        const new_factor = factor * base;
        if (int / new_factor == 0) {
            break;
        } else {
            factor = new_factor;
        }
    }
    
    while (factor >= 1) {
        const digit = int / factor;
        assert(digit < base);
        to_writer.write(number_chars[@intCast(digit)]);
        int -= digit * factor;
        factor = factor / base;
    }
}

pub fn any(values: []const bool) bool {
    for (values) |v| {
        if (v) return true;
    }
    return false;
}

pub fn all(values: []const bool) bool {
    for (values) |v| {
        if (!v) return false;
    }
    return true;
}

pub fn sentinel_to_slice(ptr: anytype) []@typeInfo(@TypeOf(ptr)).pointer.child {
    const typeinfo = @typeInfo(@TypeOf(ptr)).pointer;
    assert(typeinfo.size == .many);
    assert(typeinfo.sentinel() != null);
    const T = typeinfo.child;
    return std.mem.span(T, ptr);
}

pub fn comptime_slice_to_array(comptime slice: anytype) [slice.len]@typeInfo(@TypeOf(slice)).pointer.child {
    return slice[0..slice.len].*;
}

pub fn comptime_to_string(comptime value: anytype) [:0]const u8 {
    const Type = @TypeOf(value);
    switch (@typeInfo(Type)) {
        .array => |array_info| {
            if (array_info.child != u8) {
                @compileError("wrong argument: not a string");
            }
            if (array_info.sentinel() == 0) {
                return &value;
            } else {
                var result: [array_info.len:0]u8 = undefined;
                @memcpy(result[0..array_info.len], value);
                result[array_info.len] = 0;
                return result;
            }
        },
        .pointer => |pointer_info| {
            switch (pointer_info.size) {
                .slice => {
                    if (pointer_info.child != u8) {
                        @compileError("wrong argument: not a string");
                    }
                    if (pointer_info.sentinel() == 0) {
                        return value;
                    } else {
                        var result: [value.len:0]u8 = undefined;
                        @memcpy(result[0..value.len], value);
                        result[value.len] = 0;
                        return &result;
                    }
                },
                .many => {
                    if (pointer_info.child != u8) {
                        @compileError("wrong argument: not a string");
                    }
                    if (pointer_info.sentinel() == 0) {
                        return std.mem.span(value);
                    } else {
                        @compileError("many pointer must be sentinel");
                    }
                },
                else => @compileError("wrong argument: pointer must be "),
            }
        },
        .@"enum" => |_| {
            return @tagName(value);
        },
        .enum_literal => {
            return @tagName(value);
        },
        else => @compileError("unsupported type"),
    }
}


pub fn callback(Fn: type) type {
    const Fn_return = @typeInfo(Fn).@"fn".return_type.?;
    const fn_params = @typeInfo(Fn).@"fn".params;
    var fn_argslist: [fn_params.len]type = undefined;
    for (&fn_argslist, fn_params) |*argtype, param| {
        argtype.* = param.type.?;
    }
    const Fn_argstuple = std.meta.Tuple(&fn_argslist);
    return interface(struct {
        call: Fn,
        
        pub fn Interface(Imp: type) type {
            return struct {
                const Selfp = *const @This();
                imp: Imp,
                
                pub fn call(s: Selfp, args: Fn_argstuple) Fn_return {
                    return s.imp.call(.call, args);
                }
            };
        }
    });
}

pub fn comptime_to_sentinel(T: type, sentinel: T, in: []const T) [:sentinel]const T {
    var array: [in.len:sentinel]T = undefined;
    @memcpy(array[0..in.len], in);
    array[in.len] = sentinel;
    const array_copy = array;
    return &array_copy;
}

pub fn Single_error_set(comptime error_name: []const u8) type {
    return @Type(.{
        .error_set = &.{
            .{
                .name = comptime_to_sentinel(u8, 0, error_name),
            },
        },
    });
}

pub fn create_error(comptime name: []const u8) Single_error_set(name) {
    return @field(Single_error_set(name), name);
}

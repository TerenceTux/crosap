const std = @import("std");
const u = @import("util.zig");


pub fn get_comptime(options: type, T: type, comptime name: []const u8) ?T {
    if (@hasDecl(options, name)) {
        var value = @field(options, name);
        return parse_value(T, &value, "") catch |err| {
            std.debug.print("Error parsing {s}: {}", .{value, err});
        };
    } else {
        return null;
    }
}

// array/tuple: a,b,c
// struct: field:value,flag
// tagged union: type(data) or type:data
fn parse_value(T: type, text: *[]const u8, end: []const u8) !T {
    switch (@typeInfo(T)) {
        .type => @compileError("You can't use a type as option"),
        .void => return void,
        .bool => {
            const value = try parse_text(text, end);
            if (string_is(value, "true")) {
                return true;
            } else if (string_is(value, "false")) {
                return false;
            } if (string_is(value, "yes")) {
                return true;
            } else if (string_is(value, "no")) {
                return false;
            } if (string_is(value, "y")) {
                return true;
            } else if (string_is(value, "n")) {
                return false;
            } if (string_is(value, "enable")) {
                return true;
            } else if (string_is(value, "disable")) {
                return false;
            } else {
                return error.not_a_boolean;
            }
        },
        .noreturn => @compileError("You can't use a noreturn as option"),
        .int => {
            const value = try parse_text(text, end);
            defer u.free_slice(value);
            return try std.fmt.parseInt(T, value, 0);
        },
        .float => {
            const value = try parse_text(text, end);
            defer u.free_slice(value);
            return try std.fmt.parseFloat(T, value);
        },
        .pointer => |pointer_info| {
            switch (pointer_info.size) {
                .one => {
                    const value = u.alloc_single(pointer_info.child);
                    value.* = try parse_value(pointer_info.child, text, end);
                    return value;
                },
                .many => @compileError("You can't use a many pointer as option"),
                .slice => {
                    if (pointer_info.child == u8 and pointer_info.is_const) {
                        return try parse_text(text, end);
                    } else {
                        return try parse_array(T, text, end);
                    }
                },
                .c => @compileError("You can't use a c pointer as option"),
            }
        },
        .array => |array_info| {
            const Child = array_info.child;
            const slice = parse_array([]Child, text, end);
            defer u.free_slice(slice);
            if (slice.len != array_info.len) {
                return error.wrong_length;
            }
            var result: T = undefined;
            @memcpy(&result, slice);
            return result;
        },
        .@"struct" => {
            return try parse_struct(T, text, end);
        },
        .comptime_float => @compileError("You can't use a comptime float as option"),
        .comptime_int => @compileError("You can't use a comptime int as option"),
        .undefined => @compileError("You can't use an undefined as option"),
        .null => return null,
        .optional => @compileError("You can't use an optional as option"),
        .error_union => @compileError("You can't use an error union as option"),
        .error_set => @compileError("You can't use an error set as option"),
        .@"enum" => |enum_info| {
            const value = try parse_text(text, end);
            defer u.free_slice(value);
            inline for (enum_info.fields) |field| {
                const name = field.name;
                if (string_is(value, name)) {
                    return @field(T, name);
                }
            }
            return error.invalid_enum;
        },
        .@"union" => |union_info| {
            if (union_info.tag_type == null) {
                @compileError("Union must be tagged");
            }
            return try parse_tagged_union(T, text, end);
        },
        .@"fn" => @compileError("You can't use a function literal as option"),
        .@"opaque" => @compileError("You can't use an opaque as option"),
        .frame => @compileError("You can't use a frame as option"),
        .@"anyframe" => @compileError("You can't use an anyframe as option"),
        .vector => |vector_info| {
            const Child = vector_info.child;
            const slice = parse_array([]Child, text, end);
            defer u.free_slice(slice);
            if (slice.len != vector_info.len) {
                return error.wrong_length;
            }
            var array: [vector_info.len]Child = undefined;
            @memcpy(&array, slice);
            return array;
        },
        .enum_literal => @compileError("You can't use an enum literal as option"),
    }
}

fn parse_text(text: *[]const u8, end: []const u8) ![]const u8 {
    const braces_possible = true;
    if (string_is_exact(end, ")")) {
        braces_possible = false;
    } else if (string_is_exact(end, "")) {
        braces_possible = false;
    }
    
    var value = u.List(u8).create();
    defer value.deinit();
    var real_count: usize = 0; // last index in value that is not a whitspace
    var braces_count: usize = 0;
    
    const in_braces = start: while (true) {
        switch (read_char(text, end)) {
            .normal => |c| {
                if (!is_whitespace(c)) {
                    if (c == '(') {
                        break:start true;
                    } else {
                        value.append(c);
                        real_count = value.count;
                        break:start false;
                    }
                }
            },
            .literal => |c| {
                value.append(c);
                real_count = value.count;
            },
            .end => {
                break:start false;
            }
        }
    };
    while (true) {
        var current_end = end;
        if (in_braces or braces_count > 0) {
            current_end = "";
        }
        switch (read_char(text, current_end)) {
            .normal => |c| {
                if (c == '(') {
                    value.append('(');
                    real_count = value.count;
                    braces_count += 1;
                } else if (c == ')') {
                    if (braces_count > 0) {
                        value.append(')');
                        real_count = value.count;
                        braces_count -= 1;
                    } else if (in_braces) {
                        break;
                    } else {
                        return error.too_many_closing_braces;
                    }
                } else if (is_whitespace(c)) {
                    value.append(c);
                } else {
                    value.append(c);
                    real_count = value.count;
                }
            },
            .literal => |c| {
                value.append(c);
                real_count = value.count;
            },
            .end => {
                if (in_braces or braces_count > 0) {
                    return error.not_enough_closing_braces;
                } else {
                    break;
                }
            }
        }
    }
    if (in_braces) {
        try read_expect_end(text, end);
    }
    if (@inComptime()) {
        const copy = value.items()[0..real_count].*;
        return &copy;
    } else {
        const duped = u.dupe_slice(value.items()[0..real_count]);
        return duped;
    }
}

fn parse_array(T: type, text: *[]const u8, s_end: []const u8) !T {
    var needs_braces = true;
    var end: []const u8 = ")";
    if (string_is_exact(s_end, ")")) {
        needs_braces = false;
    } else if (string_is_exact(s_end, "")) {
        needs_braces = false;
        end = "";
    }
    if (needs_braces) {
        try read_expect(text, '(');
    }
    
    const Child = @typeInfo(T).pointer.child;
    u.assert(@typeInfo(T).pointer.size == .slice);
    var values = u.List(Child).create();
    errdefer values.deinit();
    
    const child_end = if (string_is_exact(end, ")")) (
        "),"
    ) else if (string_is_exact(end, "")) (
        ","
    ) else @panic("unexpected end value");
    while (true) {
        const value = try parse_value(Child, text, child_end);
        values.append(value);
        const last = read_char(text, end);
        if (last == .end) {
            break;
        }
    }
    
    if (needs_braces) {
        try read_expect(text, ')');
    }
    try read_expect_end(text, s_end);
    if (@inComptime()) {
        const copy = u.comptime_slice_to_array(values.items());
        return &copy;
    } else {
        return values.convert_to_slice();
    }
}

fn parse_struct(T: type, text: *[]const u8, s_end: []const u8) !T {
    const needs_braces = true;
    const end = ")";
    if (string_is_exact(s_end, ")")) {
        needs_braces = false;
    } else if (string_is_exact(s_end, "")) {
        needs_braces = false;
        end = "";
    }
    if (needs_braces) {
        try read_expect(text, '(');
    }
    
    const fields = @typeInfo(T).@"struct";
    var result: T = undefined;
    var fields_set = [1]bool {false} ** fields.len;
    
    const name_end = if (string_is_exact(end, ")")) (
        "):"
    ) else if (string_is_exact(end, "")) (
        ":"
    ) else @panic("unexpected end value");
    const value_end = if (string_is_exact(end, ")")) (
        "),"
    ) else if (string_is_exact(end, "")) (
        ","
    ) else @panic("unexpected end value");
    struct_loop: while (true) {
        const name = parse_text(text, name_end);
        if (read_char(text, end) == .end) { // should be a colon
            return error.expected_struct_value;
        }
        
        inline for (fields, 0..) |field, index| {
            if (string_is(name, field.name)) {
                if (fields_set[index]) {
                    return error.double_struct_field;
                }
                fields_set[index] = true;
                
                const value = parse_value(field.type, text, value_end);
                @field(result, field.name) = value;
                const last = read_char(end);
                if (last == .end) {
                    break :struct_loop;
                }
                break;
            }
        }
    }
    
    if (needs_braces) {
        try read_expect(text, ')');
    }
    try read_expect_end(text, s_end);
    
    inline for (fields, 0..) |field, index| {
        if (!fields_set[index]) {
            if (field.defaultValue()) |default| {
                @field(result, field.name) = default;
            } else {
                return error.missing_struct_field;
            }
        }
    }
    return result;
}

fn parse_tagged_union(T: type, text: *[]const u8, end: []const u8) !T {
    u.assert(!contains(end, ':'));
    const tag_end = u.alloc_slice(u8, end.len + 1);
    defer u.free_slice(tag_end);
    tag_end[0] = ':';
    @memcpy(tag_end[1..], end);
    
    const tag = try parse_text(text, tag_end);
    defer u.free_slice(tag);
    const has_value = read_char(text, end) != .end; // this will also consume the colon
    
    const union_info = @typeInfo(T).@"union";
    u.assert(union_info.tag_type != null);
    inline for (union_info.fields) |field| {
        if (string_is(tag, field.name)) {
            const Child = field.type;
            if (Child == void) {
                if (has_value) {
                    return error.no_value_for_void_please;
                }
                return @unionInit(T, field.name, {});
            } else {
                if (!has_value) {
                    return error.need_value_for_union;
                }
                const value = try parse_value(Child, text, end);
                return @unionInit(T, field.name, value);
            }
        }
    }
}


const Read_result = union(enum) {
    normal: u8,
    literal: u8,
    end,
    
    pub fn char(result: Read_result) ?u8 {
        return switch (result) {
            .normal => |c| c,
            .literal => |c| c,
            .end => null,
        };
    }
    
    pub fn is_literal(result: Read_result) bool {
        return switch (result) {
            .normal => |_| false,
            .literal => |_| true,
            .end => false,
        };
    }
};

fn read_char(text: *[]const u8, end: []const u8) Read_result {
    const len = text.*.len;
    if (len > 0) {
        const c = text.*[0];
        if (c == '\\') {
            const next = text.*[1];
            text.* = text.*[2..];
            return .{
                .literal = next,
            };
        } else {
            const is_end = for (end) |end_c| {
                if (c == end_c) {
                    break true;
                }
            } else false;
            if (is_end) {
                return .end;
            } else {
                text.* = text.*[1..];
                return .{
                    .normal = c,
                };
            }
        }
    } else {
        return .end;
    }
}

fn read_expect(text: *[]const u8, expect_char: u8) !void {
    while (true) {
        switch (read_char(text, "")) {
            .normal => |c| {
                if (c == expect_char) {
                    return;
                } else if (is_whitespace(c)) {
                    continue;
                } else {
                    return error.expected_another_char;
                }
            },
            else => error.expected_another_char,
        }
    }
}

fn read_expect_end(text: *[]const u8, end: []const u8) !void {
    while (true) {
        switch (read_char(text, end)) {
            .normal => |c| {
                if (is_whitespace(c)) {
                    continue;
                } else {
                    return error.expected_the_end;
                }
            },
            .literal => error.expected_the_end,
            .end => return,
        }
    }
}

fn string_is_exact(s1: []const u8, s2: []const u8) bool {
    return std.mem.eql(u8, s1, s2);
}

fn string_is(s1: []const u8, s2: []const u8) bool {
    if (s1.len != s2.len) {
        return false;
    }
    for (s1, s2) |c1, c2| {
        if (simplify_character(c1) != simplify_character(c2)) {
            return false;
        }
    }
    return true;
}

fn simplify_character(c: u8) u8 {
    return switch (c) {
        'A'...'Z' => c + ('a' - 'A'),
        '_', '-' => ' ',
        else => c,
    };
}

fn contains(list: []const u8, value: u8) bool {
    for (list) |option| {
        if (value == option) {
            return true;
        }
    }
    return false;
}

fn is_whitespace(c: u8) bool {
    return switch (c) {
        ' ', '\t', '\n', '\r' => true,
        else => false,
    };
}

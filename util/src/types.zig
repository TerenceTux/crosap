const std = @import("std");
const u = @import("util.zig");
const Type = std.builtin.Type;


pub const Field = struct {
    name: [:0]const u8,
    type: type,
};

pub fn create_tagged_union(fields: []const Field) type {
    const count = fields.len;
    const Tag_int = u.Uint_that_fits(count - 1);
    
    var names: [count][]const u8 = undefined;
    var values: [count]Tag_int = undefined;
    var types: [count]type = undefined;
    for (&names, &values, &types, fields, 0..) |*name, *value, *field_type, field_info, i| {
        name.* = field_info.name;
        value.* = @intCast(i);
        field_type.* = field_info.type;
    }
    
    const Tag_type = @Enum(Tag_int, .exhaustive, &names, &values);
    return @Union(.auto, Tag_type, &names, &types, &@splat(.{}));
}

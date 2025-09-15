const std = @import("std");
const Type = std.builtin.Type;


pub const Field = struct {
    name: [:0]const u8,
    type: type,
};

pub fn create_tagged_union(fields: []const Field) type {
    const count = fields.len;
    var union_fields: [count]Type.UnionField = undefined;
    var enum_fields: [count]Type.EnumField = undefined;
    for (&union_fields, &enum_fields, fields, 0..) |*union_field, *enum_field, field_info, i| {
        union_field.* = .{
            .name = field_info.name,
            .type = field_info.type,
            .alignment = @alignOf(field_info.type),
        };
        enum_field.* = .{
            .name = field_info.name,
            .value = i,
        };
    }
    
    const Tag = @Type(.{
        .@"enum" = .{
            .tag_type = usize,
            .fields = &enum_fields,
            .decls = &.{},
            .is_exhaustive = true,
        },
    });
    return @Type(.{
        .@"union" = .{
            .layout = .auto,
            .tag_type = Tag,
            .fields = &union_fields,
            .decls = &.{},
        },
    });
}

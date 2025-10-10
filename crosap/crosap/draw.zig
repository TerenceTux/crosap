const std = @import("std");
const u = @import("util");
const Switching_backend = @import("switching_backend.zig").Backend;
const Backend_texture = @import("switching_backend.zig").Texture_handle;
const Crosap = @import("crosap.zig").Crosap;
const font = @import("font.zig");

const font_width = u.Real.from_float(0.25);

pub const General_map = Create_imagemap(struct {
    const Drawer = @This();
    
    pub const size = u.Vec2i.create(.create(64), .create(256));
    pub const images = .{
//         .test_img = struct {
//             pub const size = u.Vec2i.create(.create(64), .create(64));
//             pub fn draw(drawer: *Drawer, buffer: []u.Screen_color, scale: u.Int) void {
//                 _ = drawer;
//                 var img_drawer = Test_image {};
//                 const draw_interface = u.drawable.static(&img_drawer);
//                 draw_interface.draw_image(scale.multiply(.create(4)), buffer);
//             }
//         },
        .solid = struct {
            pub const image = Solid_image {};
        },
        .nfont_capital_a = struct {
            pub const image = font.Capital_a.create(font_width);
        },
        .nfont_capital_b = struct {
            pub const image = font.Capital_b.create(font_width);
        },
        .nfont_capital_c = struct {
            pub const image = font.Capital_c.create(font_width);
        },
        .nfont_capital_d = struct {
            pub const image = font.Capital_d.create(font_width);
        },
        .nfont_capital_e = struct {
            pub const image = font.Capital_e.create(font_width);
        },
        .nfont_capital_f = struct {
            pub const image = font.Capital_f.create(font_width);
        },
        .nfont_capital_g = struct {
            pub const image = font.Capital_g.create(font_width);
        },
        .nfont_capital_h = struct {
            pub const image = font.Capital_h.create(font_width);
        },
        .nfont_capital_i = struct {
            pub const image = font.Capital_i.create(font_width);
        },
        .nfont_capital_j = struct {
            pub const image = font.Capital_j.create(font_width);
        },
        .nfont_capital_k = struct {
            pub const image = font.Capital_k.create(font_width);
        },
        .nfont_capital_l = struct {
            pub const image = font.Capital_l.create(font_width);
        },
        .nfont_capital_m = struct {
            pub const image = font.Capital_m.create(font_width);
        },
        .nfont_capital_n = struct {
            pub const image = font.Capital_n.create(font_width);
        },
        .nfont_capital_o = struct {
            pub const image = font.Capital_o.create(font_width);
        },
        .nfont_capital_p = struct {
            pub const image = font.Capital_p.create(font_width);
        },
        .nfont_capital_q = struct {
            pub const image = font.Capital_q.create(font_width);
        },
        .nfont_capital_r = struct {
            pub const image = font.Capital_r.create(font_width);
        },
        .nfont_capital_s = struct {
            pub const image = font.Capital_s.create(font_width);
        },
        .nfont_capital_t = struct {
            pub const image = font.Capital_t.create(font_width);
        },
        .nfont_capital_u = struct {
            pub const image = font.Capital_u.create(font_width);
        },
        .nfont_capital_v = struct {
            pub const image = font.Capital_v.create(font_width);
        },
        .nfont_capital_w = struct {
            pub const image = font.Capital_w.create(font_width);
        },
        .nfont_capital_x = struct {
            pub const image = font.Capital_x.create(font_width);
        },
        .nfont_capital_y = struct {
            pub const image = font.Capital_y.create(font_width);
        },
        .nfont_capital_z = struct {
            pub const image = font.Capital_z.create(font_width);
        },
        .nfont_small_a = struct {
            pub const image = font.Small_a.create(font_width);
        },
        .nfont_small_b = struct {
            pub const image = font.Small_b.create(font_width);
        },
        .nfont_small_c = struct {
            pub const image = font.Small_c.create(font_width);
        },
        .nfont_small_d = struct {
            pub const image = font.Small_d.create(font_width);
        },
        .nfont_small_e = struct {
            pub const image = font.Small_e.create(font_width);
        },
        .nfont_small_f = struct {
            pub const image = font.Small_f.create(font_width);
        },
        .nfont_small_g = struct {
            pub const image = font.Small_g.create(font_width);
        },
        .nfont_small_h = struct {
            pub const image = font.Small_h.create(font_width);
        },
        .nfont_small_i = struct {
            pub const image = font.Small_i.create(font_width);
        },
        .nfont_small_j = struct {
            pub const image = font.Small_j.create(font_width);
        },
        .nfont_small_k = struct {
            pub const image = font.Small_k.create(font_width);
        },
        .nfont_small_l = struct {
            pub const image = font.Small_l.create(font_width);
        },
        .nfont_small_m = struct {
            pub const image = font.Small_m.create(font_width);
        },
        .nfont_small_n = struct {
            pub const image = font.Small_n.create(font_width);
        },
        .nfont_small_o = struct {
            pub const image = font.Small_o.create(font_width);
        },
        .nfont_small_p = struct {
            pub const image = font.Small_p.create(font_width);
        },
        .nfont_small_q = struct {
            pub const image = font.Small_q.create(font_width);
        },
        .nfont_small_r = struct {
            pub const image = font.Small_r.create(font_width);
        },
        .nfont_small_s = struct {
            pub const image = font.Small_s.create(font_width);
        },
        .nfont_small_t = struct {
            pub const image = font.Small_t.create(font_width);
        },
        .nfont_small_u = struct {
            pub const image = font.Small_u.create(font_width);
        },
        .nfont_small_v = struct {
            pub const image = font.Small_v.create(font_width);
        },
        .nfont_small_w = struct {
            pub const image = font.Small_w.create(font_width);
        },
        .nfont_small_x = struct {
            pub const image = font.Small_x.create(font_width);
        },
        .nfont_small_y = struct {
            pub const image = font.Small_y.create(font_width);
        },
        .nfont_small_z = struct {
            pub const image = font.Small_z.create(font_width);
        },
        .nfont_number_0 = struct {
            pub const image = font.Number_0.create(font_width);
        },
        .nfont_number_1 = struct {
            pub const image = font.Number_1.create(font_width);
        },
        .nfont_number_2 = struct {
            pub const image = font.Number_2.create(font_width);
        },
        .nfont_number_3 = struct {
            pub const image = font.Number_3.create(font_width);
        },
        .nfont_number_4 = struct {
            pub const image = font.Number_4.create(font_width);
        },
        .nfont_number_5 = struct {
            pub const image = font.Number_5.create(font_width);
        },
        .nfont_number_6 = struct {
            pub const image = font.Number_6.create(font_width);
        },
        .nfont_number_7 = struct {
            pub const image = font.Number_7.create(font_width);
        },
        .nfont_number_8 = struct {
            pub const image = font.Number_8.create(font_width);
        },
        .nfont_number_9 = struct {
            pub const image = font.Number_9.create(font_width);
        },
        .nfont_underscore = struct {
            pub const image = font.Underscore.create(font_width);
        },
        .nfont_colon = struct {
            pub const image = font.Colon.create(font_width);
        },
        .nfont_space = struct {
            pub const image = font.Space.create(font_width);
        },
        .nfont_dot = struct {
            pub const image = font.Dot.create(font_width);
        },
        .nfont_comma = struct {
            pub const image = font.Comma.create(font_width);
        },
        .nfont_semicolon = struct {
            pub const image = font.Semicolon.create(font_width);
        },
        .nfont_brace_open = struct {
            pub const image = font.Brace_open.create(font_width);
        },
        .nfont_brace_close = struct {
            pub const image = font.Brace_close.create(font_width);
        },
        .nfont_bracket_open = struct {
            pub const image = font.Bracket_open.create(font_width);
        },
        .nfont_bracket_close = struct {
            pub const image = font.Bracket_close.create(font_width);
        },
        .nfont_curly_brace_open = struct {
            pub const image = font.Curly_brace_open.create(font_width);
        },
        .nfont_curly_brace_close = struct {
            pub const image = font.Curly_brace_close.create(font_width);
        },
        .nfont_angle_bracket_open = struct {
            pub const image = font.Angle_bracket_open.create(font_width);
        },
        .nfont_angle_bracket_close = struct {
            pub const image = font.Angle_bracket_close.create(font_width);
        },
        .nfont_slash = struct {
            pub const image = font.Slash.create(font_width);
        },
        .nfont_backslash = struct {
            pub const image = font.Backslash.create(font_width);
        },
        .nfont_vertical_bar = struct {
            pub const image = font.Vertical_bar.create(font_width);
        },
        .nfont_apostrophe = struct {
            pub const image = font.Apostrophe.create(font_width);
        },
        .nfont_quotation_mark = struct {
            pub const image = font.Quotation_mark.create(font_width);
        },
        .nfont_dash = struct {
            pub const image = font.Dash.create(font_width);
        },
        .nfont_plus = struct {
            pub const image = font.Plus.create(font_width);
        },
        .nfont_question_mark = struct {
            pub const image = font.Question_mark.create(font_width);
        },
        .nfont_exclamation_mark = struct {
            pub const image = font.Exclamation_mark.create(font_width);
        },
        .nfont_asterisk = struct {
            pub const image = font.Asterisk.create(font_width);
        },
        .nfont_caret = struct {
            pub const image = font.Caret.create(font_width);
        },
        .nfont_hash = struct {
            pub const image = font.Hash.create(font_width);
        },
        .nfont_dollar_sign = struct {
            pub const image = font.Dollar_sign.create(font_width);
        },
        .nfont_percent = struct {
            pub const image = font.Percent.create(font_width);
        },
        .nfont_ampersand = struct {
            pub const image = font.Ampersand.create(font_width);
        },
        .nfont_at = struct {
            pub const image = font.At.create(font_width);
        },
        .nfont_backtick = struct {
            pub const image = font.Backtick.create(font_width);
        },
        .nfont_tilde = struct {
            pub const image = font.Tilde.create(font_width);
        },
    };
});

pub fn Create_imagemap(Drawer_t: type) type {
    @setEvalBranchQuota(1000000);
    const map_size = Drawer_t.size;
    var object_sizes: []const u.Vec2i = &.{};
    var subimg_drawers_build: []const type = &.{};
    var sub_image_fields_build: []const std.builtin.Type.EnumField = &.{};
    for (@typeInfo(@TypeOf(Drawer_t.images)).@"struct".fields, 0..) |field, index| {
        const name = field.name;
        const Sub_drawer = @field(Drawer_t.images, name);
        var size: u.Vec2i = undefined;
        if (@hasDecl(Sub_drawer, "image")) {
            var drawer = Sub_drawer.image;
            const draw_interface = u.drawable.static(&drawer);
            size = draw_interface.size();
            if (@hasDecl(Sub_drawer, "scale")) {
                size = size.scale_up(Sub_drawer.scale);
            }
        } else {
            size = Sub_drawer.size;
        }
        object_sizes = object_sizes ++ .{size};
        subimg_drawers_build = subimg_drawers_build ++ .{Sub_drawer};
        sub_image_fields_build = sub_image_fields_build ++ .{std.builtin.Type.EnumField {
            .name = name,
            .value = index,
        }};
    }
    const subimg_drawers = u.comptime_slice_to_array(subimg_drawers_build);
    const sub_image_fields = u.comptime_slice_to_array(sub_image_fields_build);
    const positions = imagemap_create_layout(map_size, object_sizes);
    const sizes = u.comptime_slice_to_array(object_sizes);
    return struct {
        const Image_map = @This();
        pub const Drawer = Drawer_t;
        pub const name = @typeName(Drawer);
        pub const Sub_image = @Type(.{.@"enum" = .{
            .tag_type = u16,
            .fields = &sub_image_fields,
            .decls = &.{},
            .is_exhaustive = true,
        }});
        
        drawer: Drawer,
        texture: Texture_image,
        scale: u.Int,
        
        pub fn get(image_map: *Image_map, img: Sub_image) Image {
            const index = @intFromEnum(img);
            const size = sizes[index].scale_up(image_map.scale);
            const position = positions[index].scale_up(image_map.scale);
            return .{
                .texture = &image_map.texture,
                .rect = .create(position, size),
            };
        }
        
        pub fn draw_to_buffer(image_map: *Image_map, img: Sub_image, buffer: []u.Screen_color) void {
            const size = sizes[@intFromEnum(img)];
            const pixel_size = size.scale_up(image_map.scale);
            u.assert(buffer.len == pixel_size.area().to(usize));
            switch (img) {
                inline else => |sub| {
                    const index = @intFromEnum(sub);
                    const Sub_drawer = subimg_drawers[index];
                    if (@hasDecl(Sub_drawer, "draw")) {
                        Sub_drawer.draw(&image_map.drawer, buffer, image_map.scale);
                    } else if (@hasDecl(Sub_drawer, "image")) {
                        var drawer = Sub_drawer.image;
                        var scale = u.Int.one;
                        if (@hasDecl(Sub_drawer, "scale")) {
                            scale = Sub_drawer.scale;
                        }
                        const draw_interface = u.drawable.static(&drawer);
                        draw_interface.draw_image(image_map.scale.multiply(scale), buffer);
                    } else {
                        @compileError(@typeName(Sub_drawer)++" has no 'draw' function or 'image' declaration");
                    }
                },
            }
        }
        
        pub fn redraw(image_map: *Image_map, img: Sub_image) void {
            u.log_start(.{"Redrawing subimage ",@tagName(img)});
            const image = image_map.get(img);
            const buffer = u.alloc.alloc(u.Screen_color, image.rect.size.area().to(usize));
            image_map.draw_to_buffer(img, buffer);
            image.write(buffer);
            u.alloc.free(buffer);
            u.log_end(.{});
        }
        
        pub fn redraw_all(image_map: *Image_map) void {
            u.log_start(.{"Redrawing everyting"});
            var buffer = u.List(u.Screen_color).create();
            for (0..sizes.len) |index| {
                const img: Sub_image = @enumFromInt(index);
                u.log_start(.{"Sub image ",@tagName(img)});
                const image = image_map.get(img);
                buffer.reset_size(image.rect.size.area().to(usize));
                image_map.draw_to_buffer(img, buffer.items_mut());
                image.write(buffer.items());
                u.log_end(.{});
            }
            buffer.deinit();
            u.log_end(.{});
        }
        
        pub fn init(image_map: *Image_map, drawer: Drawer, texture: Texture_image, scale: u.Int) void {
            image_map.drawer = drawer;
            image_map.texture = texture;
            image_map.scale = scale;
            u.assert(image_map.texture.size.equal(map_size.scale_up(scale)));
            image_map.redraw_all();
        }
        
        pub fn needed_size(scale: u.Int) u.Vec2i {
            return map_size.scale_up(scale);
        }
    };
}

fn imagemap_create_layout(comptime map_size: u.Vec2i, comptime objects: []const u.Vec2i) []const u.Vec2i {
    var positions: [objects.len]u.Vec2i = undefined;
    var space_taken = [1]u.Int {.zero} ** map_size.y.to(usize);
    var available = [1]bool {true} ** objects.len;
    while (true) {
        var best: ?usize = null;
        var best_height = u.Int.zero;
        for (objects, 0..) |size, index| {
            if (!available[index]) continue;
            if (size.y.higher_than(best_height)) {
                best = index;
                best_height = size.y;
            }
        }
        if (best == null) {
            break;
        }
        available[best.?] = false;
        
        const size = objects[best.?];
        if (size.y.lower_or_equal(.zero)) {
            @compileError("Image height must be greater than zero");
        }
        if (size.x.lower_or_equal(.zero)) {
            @compileError("Image width must be greater than zero");
        }
        var start_y = u.Int.zero;
        var start_x = u.Int.zero;
        for (0..objects.len) |y_u| {
            const y = u.Int.create(y_u);
            const taken = space_taken[y.to(usize)];
            const available_width = map_size.x.subtract(taken);
            const fits_here = available_width.higher_or_equal(size.x);
            if (fits_here) {
                if (taken.higher_than(start_x)) {
                    start_x = taken;
                }
                const checked_height = y.add(.one).subtract(start_y);
                if (checked_height.higher_or_equal(size.y)) {
                    break;
                }
            } else {
                start_y = y.add(.one);
                start_x = u.Int.zero;
            }
        }
        if (start_y.add(size.y).higher_or_equal(map_size.y)) {
            @compileError("Not all images fit");
        }
        for (0..size.y.to(usize)) |ry| {
            const y = u.Int.create(ry).add(start_y);
            space_taken[y.to(usize)] = start_x.add(size.x);
        }
        // @compileLog("Placed ", size.x.to(usize), "x", size.y.to(usize), " at ", start_x.to(usize), ",", start_y.to(usize));
        positions[best.?] = u.Vec2i.create(start_x, start_y);
    }
    const ret = positions;
    return &ret;
}


const Test_image = struct {
    pub fn size(image: *Test_image) u.Vec2i {
        _ = image;
        return .create(.create(16), .create(16));
    }
    
    pub fn start(image: *Test_image, scale: u.Int) void {
        _ = image;
        _ = scale;
    }
    
    pub fn end(image: *Test_image) void {
        _ = image;
    }
    
    pub fn pixel(image: *Test_image, p: u.Draw_point) u.Color {
        _ = image;
        var c = u.Color.transparent;
        if (p.in_line(.create(.from_float(7.8), .from_int(1)), .create(.from_float(7), .from_int(15)), .from_float(0.05))) {
            c.add(.from_byte_rgb(255, 255, 255));
        }
        if (p.in_line(.create(.from_float(7.9), .from_int(1)), .create(.from_float(7.2), .from_int(15)), .from_float(0.05))) {
            c.add(.from_byte_rgb(255, 255, 255));
        }
        if (p.in_line(.create(.from_float(8), .from_int(1)), .create(.from_float(7.4), .from_int(15)), .from_float(0.05))) {
            c.add(.from_byte_rgb(255, 255, 255));
        }
        if (p.in_line(.create(.from_float(8.1), .from_int(1)), .create(.from_float(7.6), .from_int(15)), .from_float(0.05))) {
            c.add(.from_byte_rgb(255, 255, 255));
        }
        if (p.in_line(.create(.from_float(8.2), .from_int(1)), .create(.from_float(7.8), .from_int(15)), .from_float(0.05))) {
            c.add(.from_byte_rgb(255, 255, 255));
        }
        return c;
    }
};

const Solid_image = struct {
    pub fn size(image: *Solid_image) u.Vec2i {
        _ = image;
        return .create(.create(1), .create(1));
    }
    
    pub fn start(image: *Solid_image, scale: u.Int) void {
        _ = image;
        _ = scale;
    }
    
    pub fn end(image: *Solid_image) void {
        _ = image;
    }
    
    pub fn pixel(image: *Solid_image, p: u.Draw_point) u.Color {
        _ = image;
        _ = p;
        return .from_byte_rgb(255, 255, 255);
    }
};


pub const Draw_context = struct {
    area: u.Rect2i,
    mask: u.Rect2i,
    cr: *Crosap,
    dtime: u.Real,
    
    pub const Align_horizontal = enum {
        left,
        center,
        right,
    };
    
    pub const Align_vertical = enum {
        top,
        center,
        bottom,
    };
    
    const default_color = u.Screen_color.colors.white;
    
    pub fn size(draw_context: *const Draw_context) u.Vec2i {
        return draw_context.area.size.scale_down(draw_context.cr.scale);
    }
    
    pub fn repeated_offset_color(draw_context: *const Draw_context, context_rect: u.Rect2i, t_image: Image, offset: u.Vec2i, color: u.Screen_color) void {
        const pixel_rect = u.Rect2i.create(context_rect.offset.scale_up(draw_context.cr.scale), context_rect.size.scale_up(draw_context.cr.scale));
        const real = pixel_rect.move(draw_context.area.offset);
        if (real.intersection(draw_context.mask)) |draw_context_rect| {
            draw_context.cr.backend.draw_object(draw_context_rect, color, t_image.texture.image, t_image.rect, offset.add(real.offset.subtract(draw_context_rect.offset)));
        }
    }
    
    pub fn repeated_offset(draw_context: *const Draw_context, context_rect: u.Rect2i, t_image: Image, offset: u.Vec2i) void {
        draw_context.repeated_offset_color(context_rect, t_image, offset, default_color);
    }
    
    pub fn repeated_align_color(draw_context: *const Draw_context, context_rect: u.Rect2i, t_image: Image, align_horizontal: Align_horizontal, align_vertical: Align_vertical, color: u.Screen_color) void {
        const draw_size = context_rect.size;
        const image_size = t_image.rect.size.scale_down(draw_context.cr.scale);
        const offset_x = switch (align_horizontal) {
            .left => u.Int.zero,
            .center => draw_size.x.divide(.create(2)).subtract(image_size.x.divide(.create(2))),
            .right => draw_size.x.subtract(image_size.x),
        };
        const offset_y = switch (align_vertical) {
            .top => u.Int.zero,
            .center => draw_size.y.divide(.create(2)).subtract(image_size.y.divide(.create(2))),
            .bottom => draw_size.y.subtract(image_size.y),
        };
        draw_context.repeated_offset_color(context_rect, t_image, .create(offset_x, offset_y), color);
    }
    
    pub fn repeated_align(draw_context: *const Draw_context, context_rect: u.Rect2i, t_image: Image, align_horizontal: Align_horizontal, align_vertical: Align_vertical) void {
        draw_context.repeated_align_color(context_rect, t_image, align_horizontal, align_vertical, default_color);
    }
    
    pub fn repeated_color(draw_context: *const Draw_context, context_rect: u.Rect2i, t_image: Image, color: u.Screen_color) void {
        draw_context.repeated_offset_color(context_rect, t_image, .zero, color);
    }
    
    pub fn repeated(draw_context: *const Draw_context, context_rect: u.Rect2i, t_image: Image) void {
        draw_context.repeated_color(context_rect, t_image, default_color);
    }
    
    pub fn image_color(draw_context: *const Draw_context, pos: u.Vec2i, t_image: Image, color: u.Screen_color) void {
        draw_context.repeated_color(.create(pos, t_image.rect.size.scale_down(draw_context.cr.scale)), t_image, color);
    }
    
    pub fn image(draw_context: *const Draw_context, pos: u.Vec2i, t_image: Image) void {
        draw_context.image_color(pos, t_image, default_color);
    }
    
    pub fn image_align_color(draw_context: *const Draw_context, pos: u.Vec2i, t_image: Image, align_horizontal: Align_horizontal, align_vertical: Align_vertical, color: u.Screen_color) void {
        const image_size = t_image.rect.size.scale_down(draw_context.cr.scale);
        const offset_x = switch (align_horizontal) {
            .left => u.Int.zero,
            .center => image_size.x.divide(.create(2)).negate(),
            .right => image_size.x.negate(),
        };
        const offset_y = switch (align_vertical) {
            .top => u.Int.zero,
            .center => image_size.y.divide(.create(2)).negate(),
            .bottom => image_size.y.negate(),
        };
        draw_context.image_color(pos.add(.create(offset_x, offset_y)), t_image, color);
    }
    
    pub fn image_align(draw_context: *const Draw_context, pos: u.Vec2i, t_image: Image, align_horizontal: Align_horizontal, align_vertical: Align_vertical) void {
        draw_context.image_align_color(pos, t_image, align_horizontal, align_vertical, default_color);
    }
    
    pub fn rect(draw_context: *const Draw_context, context_rect: u.Rect2i, color: u.Screen_color) void {
        const t_image = draw_context.cr.general.get(.solid);
        draw_context.repeated_color(context_rect, t_image, color);
    }
};

pub const Texture_image = struct {
    image: Backend_texture,
    backend: Switching_backend,
    size: u.Vec2i,
    
    pub fn deinit(teximg: *Texture_image) void {
        teximg.backend.destroy_texture(teximg.image);
    }
    
    pub fn get(teximg: *Texture_image, rect: u.Rect2i) Image {
        u.assert(rect.offset.x.higher_or_equal(.zero));
        u.assert(rect.offset.y.higher_or_equal(.zero));
        u.assert(rect.offset.x.add(rect.size.x).lower_or_equal(teximg.size.x));
        u.assert(rect.offset.y.add(rect.size.y).lower_or_equal(teximg.size.y));
        return .{
            .texture = teximg,
            .rect = rect,
        };
    }
    
    pub fn get_whole(teximg: *Texture_image) Image {
        return teximg.get(.create(.zero, teximg.size));
    }
};

pub const Image = struct {
    texture: *Texture_image,
    rect: u.Rect2i,
    
    pub fn write(image: *const Image, data: []const u.Screen_color) void {
        image.texture.backend.update_texture(
            image.texture.image,
            image.rect,
            data
        );
    }
};

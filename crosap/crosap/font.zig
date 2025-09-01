const u = @import("util");
const std = @import("std");

const Character_width = enum {
    normal, // 3 - 7
    wide,   // 2 - 8
    small,  // 4 - 6
    line,   // 5 - 5
    very_wide, // 1 - 9
    
    pub fn start(width: Character_width) u8 {
        return switch (width) {
            .normal => 3,
            .wide => 2,
            .small => 4,
            .line => 5,
            .very_wide => 1,
        };
    }
    
    pub fn end(width: Character_width) u8 {
        return switch (width) {
            .normal => 7,
            .wide => 8,
            .small => 6,
            .line => 5,
            .very_wide => 9,
        };
    }
    
    pub fn offset(width: Character_width) u.Real {
        const x_start = width.start() - 1;
        return u.Real.from_int(x_start).divide(.from_int(2));
    }
    
    pub fn size(width: Character_width) u.Real {
        const x_start = width.start() - 1;
        const x_end = width.end() + 1;
        return u.Real.from_int(x_end - x_start).divide(.from_int(2));
    }
};

const Character_height = enum {
    normal,  // 3 - 7
    big,     // 1 - 7
    low,     // 3 - 9
    big_low, // 1 - 9
    
    pub fn start(height: Character_height) u8 {
        return switch (height) {
            .normal => 3,
            .big => 1,
            .low => 3,
            .big_low => 1,
        };
    }
    
    pub fn end(height: Character_height) u8 {
        return switch (height) {
            .normal => 7,
            .big => 7,
            .low => 9,
            .big_low => 9,
        };
    }
    
    pub fn offset(height: Character_height) u.Real {
        const y_start = height.start() - 1;
        return u.Real.from_int(y_start).divide(.from_int(2));
    }
    
    pub fn size(height: Character_height) u.Real {
        const y_start = height.start() - 1;
        const y_end = height.end() + 1;
        return u.Real.from_int(y_end - y_start).divide(.from_int(2));
    }
};

const Optimal_positions = struct {
    x_left: [9]u.Real,
    x_right: [9]u.Real,
    y_up: [9]u.Real,
    y_down: [9]u.Real,
    
    pub fn init(o_pos: *Optimal_positions, scale: u.Int, width: u.Real) void {
        const round_step = scale.to_real().inverse();
        const half_w = width.divide(.from_int(2));
        
        for (&o_pos.x_left, 0..) |*val, i| {
            const pos = u.Real.from_int(i).add(.one).divide(.from_int(2));
            val.* = pos.subtract(half_w).round(round_step).add(half_w);
        }
        
        for (&o_pos.x_right, 0..) |*val, i| {
            const pos = u.Real.from_int(i).add(.one).divide(.from_int(2));
            val.* = pos.add(half_w).round(round_step).subtract(half_w);
        }
        
        for (&o_pos.y_up, 0..) |*val, i| {
            const pos = u.Real.from_int(i).add(.one).divide(.from_int(2));
            val.* = pos.subtract(half_w).round(round_step).add(half_w);
        }
        
        for (&o_pos.y_down, 0..) |*val, i| {
            const pos = u.Real.from_int(i).add(.one).divide(.from_int(2));
            val.* = pos.add(half_w).round(round_step).subtract(half_w);
        }
    }
};

const font_color = u.Color.from_byte_rgb(255, 255, 255);

const Character_draw = struct {
    width: u.Real,
    point: u.Draw_point,
    optimal_pos: Optimal_positions,
    in_char: bool,
    
    pub fn left(ch_draw: *Character_draw, pos: u8) u.Real {
        return ch_draw.optimal_pos.x_left[pos - 1];
    }
    
    pub fn right(ch_draw: *Character_draw, pos: u8) u.Real {
        return ch_draw.optimal_pos.x_right[pos - 1];
    }
    
    pub fn up(ch_draw: *Character_draw, pos: u8) u.Real {
        return ch_draw.optimal_pos.y_up[pos - 1];
    }
    
    pub fn down(ch_draw: *Character_draw, pos: u8) u.Real {
        return ch_draw.optimal_pos.y_down[pos - 1];
    }
    
    pub fn precise(ch_draw: *Character_draw, pos: f32) u.Real {
        _ = ch_draw;
        return u.Real.from_float(pos).divide(.from_int(2));
    }
    
    pub fn draw_line(ch_draw: *Character_draw, x1: u.Real, y1: u.Real, x2: u.Real, y2: u.Real) void {
        if (ch_draw.point.e_in_line(.create(x1, y1), .create(x2, y2), ch_draw.width)) {
            ch_draw.in_char = true;
        }
    }
    
    pub fn draw_ellipse(ch_draw: *Character_draw, x1: u.Real, y1: u.Real, x2: u.Real, y2: u.Real) void {
        u.assert(x2.higher_or_equal(x1));
        u.assert(y2.higher_or_equal(y1));
        const center = u.Vec2r.create(
            x1.add(x2).divide(.from_int(2)),
            y1.add(y2).divide(.from_int(2)),
        );
        const radius_x = x2.subtract(x1).divide(.from_int(2));
        const radius_y = y2.subtract(y1).divide(.from_int(2));
        if (ch_draw.point.e_in_ellipse_line(center, radius_x, radius_y, ch_draw.width)) {
            ch_draw.in_char = true;
        }
    }
    
    pub fn draw_dot(ch_draw: *Character_draw, x: u.Real, y: u.Real) void {
        if (ch_draw.point.e_in_circle(.create(x, y), ch_draw.width.divide(.from_int(2)))) {
            ch_draw.in_char = true;
        }
    }
    
    fn parse_angle(a: u.Real) u.Real {
        return a.mod(.one);
    }
    
    fn angle_from_pi(a: u.Real) u.Real {
        return parse_angle(a.divide(.from_float(@as(f32, std.math.pi) * 2)));
    }
    
    pub fn draw_ellipse_part(ch_draw: *Character_draw, x1: u.Real, y1: u.Real, x2: u.Real, y2: u.Real, mask_left: u.Real, mask_top: u.Real, mask_right: u.Real, mask_bottom: u.Real) void {
        u.assert(x2.higher_or_equal(x1));
        u.assert(y2.higher_or_equal(y1));
        u.assert(mask_right.higher_or_equal(mask_left));
        u.assert(mask_bottom.higher_or_equal(mask_top));
        const center_x = x1.add(x2).divide(.from_int(2));
        const center_y = y1.add(y2).divide(.from_int(2));
        const center = u.Vec2r.create(center_x, center_y);
        const radius_x = x2.subtract(x1).divide(.from_int(2));
        const radius_y = y2.subtract(y1).divide(.from_int(2));
        const rel_mask_left = mask_left.subtract(center_x).divide(radius_x);
        const rel_mask_right = mask_right.subtract(center_x).divide(radius_x);
        const rel_mask_top = mask_top.subtract(center_y).divide(radius_y);
        const rel_mask_bottom = mask_bottom.subtract(center_y).divide(radius_y);
        
        var top_over = false;
        var a_top1: ?u.Real = null;
        var a_top2: ?u.Real = null;
        if (rel_mask_top.higher_than(.from_int(1))) {
            return;
        } else if (rel_mask_top.higher_than(.from_int(-1))) {
            const aval = rel_mask_top.negate().acos();
            const angle_1 = parse_angle(angle_from_pi(aval).negate());
            const angle_2 = angle_from_pi(aval);
            const x_1 = u.Vec2r.from_angle(angle_1, .one).x;
            const x_2 = u.Vec2r.from_angle(angle_2, .one).x;
            if (x_1.higher_or_equal(rel_mask_left) and x_1.lower_or_equal(rel_mask_right)) {
                a_top1 = angle_1;
            }
            if (x_2.higher_or_equal(rel_mask_left) and x_2.lower_or_equal(rel_mask_right)) {
                a_top2 = angle_2;
            }
        } else {
            top_over = true;
        }
        
        var a_bottom1: ?u.Real = null;
        var a_bottom2: ?u.Real = null;
        if (rel_mask_bottom.lower_than(.from_int(-1))) {
            return;
        } else if (rel_mask_bottom.lower_than(.from_int(1))) {
            const aval = rel_mask_bottom.negate().acos();
            const angle_1 = parse_angle(angle_from_pi(aval).negate());
            const angle_2 = angle_from_pi(aval);
            const x_1 = u.Vec2r.from_angle(angle_1, .one).x;
            const x_2 = u.Vec2r.from_angle(angle_2, .one).x;
            if (x_1.higher_or_equal(rel_mask_left) and x_1.lower_or_equal(rel_mask_right)) {
                a_bottom1 = angle_1;
            }
            if (x_2.higher_or_equal(rel_mask_left) and x_2.lower_or_equal(rel_mask_right)) {
                a_bottom2 = angle_2;
            }
        }
        
        var a_left1: ?u.Real = null;
        var a_left2: ?u.Real = null;
        if (rel_mask_left.higher_than(.from_int(1))) {
            return;
        } else if (rel_mask_left.higher_than(.from_int(-1))) {
            const aval = rel_mask_left.asin();
            const angle_1 = angle_from_pi(aval);
            const angle_2 = parse_angle(u.Real.from_float(0.5).subtract(angle_from_pi(aval)));
            const y_1 = u.Vec2r.from_angle(angle_1, .one).y;
            const y_2 = u.Vec2r.from_angle(angle_2, .one).y;
            if (y_1.higher_or_equal(rel_mask_top) and y_1.lower_or_equal(rel_mask_bottom)) {
                a_left1 = angle_1;
            }
            if (y_2.higher_or_equal(rel_mask_top) and y_2.lower_or_equal(rel_mask_bottom)) {
                a_left2 = angle_2;
            }
        }
        
        var a_right1: ?u.Real = null;
        var a_right2: ?u.Real = null;
        if (rel_mask_right.lower_than(.from_int(-1))) {
            return;
        } else if (rel_mask_right.lower_than(.from_int(1))) {
            const aval = rel_mask_right.asin();
            const angle_1 = angle_from_pi(aval);
            const angle_2 = parse_angle(u.Real.from_float(0.5).subtract(angle_from_pi(aval)));
            const y_1 = u.Vec2r.from_angle(angle_1, .one).y;
            const y_2 = u.Vec2r.from_angle(angle_2, .one).y;
            if (y_1.higher_or_equal(rel_mask_top) and y_1.lower_or_equal(rel_mask_bottom)) {
                a_right1 = angle_1;
            }
            if (y_2.higher_or_equal(rel_mask_top) and y_2.lower_or_equal(rel_mask_bottom)) {
                a_right2 = angle_2;
            }
        }
        
        const Segment = struct {
            from: u.Real,
            to: u.Real,
        };
        var segments_buffer: [4]Segment = undefined;
        var segments = std.ArrayList(Segment).initBuffer(&segments_buffer);
        var current_start: ?u.Real = null;
        var overflow_end: ?u.Real = null;
        
        const points = [_]?u.Real {a_top2, a_right1, a_right2, a_bottom2, a_bottom1, a_left2, a_left1, a_top1};
        var is_start = true;
        for (points) |point| {
            if (point) |angle| {
                if (is_start) {
                    u.assert(current_start == null);
                    current_start = angle;
                } else {
                    if (current_start) |start| {
                        segments.appendBounded(.{.from = start, .to = angle}) catch unreachable;
                        current_start = null;
                    } else {
                        u.assert(overflow_end == null);
                        overflow_end = angle;
                    }
                }
            }
            is_start = !is_start;
        }
        if (current_start) |start| {
            segments.appendBounded(.{.from = start, .to = overflow_end.?}) catch unreachable;
        } else {
            u.assert(overflow_end == null);
        }
        
        if (segments.items.len == 0) {
            if (top_over) {
                if (ch_draw.point.e_in_ellipse_line(center, radius_x, radius_y, ch_draw.width)) {
                    ch_draw.in_char = true;
                }
            }
            return;
        }
        
        for (segments.items) |segment| {
            if (ch_draw.point.e_in_ellipse_line_part(center, radius_x, radius_y, ch_draw.width, segment.from, segment.to)) {
                ch_draw.in_char = true;
            }
        }
    }
};


fn Character(Drawing: type) type {
    return struct {
        const Self = @This();
        width: u.Real,
        optimal_pos: Optimal_positions,
        
        fn ch_width() Character_width {
            return Drawing.width;
        }
        
        fn ch_height() Character_height {
            return Drawing.height;
        }
        
        pub fn create(width: u.Real) Self {
            return .{
                .width = width,
                .optimal_pos = undefined,
            };
        } 
        
        pub fn size(image: *Self) u.Vec2i {
            _ = image;
            return .create(
                ch_width().size().int_ceil(),
                ch_height().size().int_ceil(),
            );
        }
        
        pub fn start(image: *Self, scale: u.Int) void {
            image.optimal_pos.init(scale, image.width);
        }
        
        pub fn end(image: *Self) void {
            _ = image;
        }
        
        pub fn pixel(image: *Self, p: u.Draw_point) u.Color {
            const offset = u.Vec2r.create(
                ch_width().offset(),
                ch_height().offset(),
            );
            const moved = u.Draw_point {
                .pos = p.pos.add(offset),
                .scale = p.scale,
            };
            var ch_draw = Character_draw {
                .width = image.width,
                .point = moved,
                .optimal_pos = image.optimal_pos,
                .in_char = false,
            };
            Drawing.draw(&ch_draw);
            if (ch_draw.in_char) {
                return font_color;
            } else {
                return .transparent;
            }
        }
    };
}


pub const Capital_a = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(5), d.up(1), d.right(7), d.down(7));
        d.draw_line(d.left(5), d.up(1), d.left(3), d.down(7));
        d.draw_line(d.precise(3.667), d.up(5), d.precise(6.333), d.up(5));
    }
});

pub const Capital_b = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(1), d.left(3), d.down(7));
        d.draw_line(d.left(3), d.up(1), d.right(5), d.up(1));
        d.draw_line(d.left(3), d.up(4), d.right(5), d.up(4));
        d.draw_line(d.left(3), d.down(7), d.right(5), d.down(7));
        d.draw_ellipse_part(d.left(3), d.up(1), d.right(7), d.up(4), d.right(5), d.up(1), d.right(7), d.up(4));
        d.draw_ellipse_part(d.left(3), d.up(4), d.right(7), d.down(7), d.right(5), d.up(4), d.right(7), d.down(7));
    }
});

pub const Capital_c = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse_part(d.left(3), d.up(1), d.right(8), d.down(7), d.left(3), d.up(1), d.right(7), d.down(7));
    }
});

pub const Capital_d = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(1), d.left(3), d.down(7));
        d.draw_line(d.left(3), d.up(1), d.right(4), d.up(1));
        d.draw_line(d.left(3), d.down(7), d.right(4), d.down(7));
        d.draw_ellipse_part(d.left(1), d.up(1), d.right(7), d.down(7), d.right(4), d.up(1), d.right(7), d.down(7));
    }
});

pub const Capital_e = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(1), d.left(3), d.down(7));
        d.draw_line(d.left(3), d.up(1), d.right(7), d.up(1));
        d.draw_line(d.left(3), d.up(4), d.right(7), d.up(4));
        d.draw_line(d.left(3), d.down(7), d.right(7), d.down(7));
    }
});

pub const Capital_f = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(1), d.left(3), d.down(7));
        d.draw_line(d.left(3), d.up(1), d.right(7), d.up(1));
        d.draw_line(d.left(3), d.down(4), d.right(7), d.down(4));
    }
});

pub const Capital_g = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse_part(d.left(3), d.up(1), d.right(8), d.down(7), d.left(3), d.up(1), d.right(7), d.down(7));
        d.draw_line(d.right(7), d.precise(6.25), d.right(7), d.up(4));
        d.draw_line(d.right(7), d.up(4), d.left(5), d.up(4));
    }
});

pub const Capital_h = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(1), d.left(3), d.down(7));
        d.draw_line(d.right(7), d.up(1), d.right(7), d.down(7));
        d.draw_line(d.left(3), d.up(4), d.right(7), d.up(4));
    }
});

pub const Capital_i = Character(struct {
    pub const width = .small;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(5), d.up(1), d.left(5), d.down(7));
        d.draw_line(d.left(4), d.up(1), d.right(6), d.up(1));
        d.draw_line(d.left(4), d.down(7), d.right(6), d.down(7));
    }
});

pub const Capital_j = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.right(6), d.up(1), d.right(6), d.up(6));
        d.draw_ellipse_part(d.left(3), d.up(5), d.right(6), d.down(7), d.left(3), d.up(6), d.right(6), d.down(7));
        d.draw_line(d.left(5), d.up(1), d.right(7), d.up(1));
    }
});

pub const Capital_k = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(1), d.left(3), d.down(7));
        d.draw_line(d.left(3), d.up(4), d.right(7), d.up(1));
        d.draw_line(d.left(3), d.up(4), d.right(7), d.down(7));
    }
});

pub const Capital_l = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(1), d.left(3), d.down(7));
        d.draw_line(d.left(3), d.down(7), d.right(7), d.down(7));
    }
});

pub const Capital_m = Character(struct {
    pub const width = .wide;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(2), d.up(1), d.left(2), d.down(7));
        d.draw_line(d.left(2), d.up(1), d.left(5), d.down(5));
        d.draw_line(d.right(8), d.up(1), d.left(5), d.down(5));
        d.draw_line(d.right(8), d.up(1), d.right(8), d.down(7));
    }
});

pub const Capital_n = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(1), d.left(3), d.down(7));
        d.draw_line(d.left(3), d.up(1), d.right(7), d.down(7));
        d.draw_line(d.right(7), d.up(1), d.right(7), d.down(7));
    }
});

pub const Capital_o = Character(struct {
    pub const width = .wide;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse(d.left(2), d.up(1), d.right(8), d.down(7));
    }
});

pub const Capital_p = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(1), d.left(3), d.down(7));
        d.draw_line(d.left(3), d.up(1), d.right(5), d.up(1));
        d.draw_line(d.left(3), d.down(4), d.right(5), d.down(4));
        d.draw_ellipse_part(d.left(3), d.up(1), d.right(7), d.down(4), d.right(5), d.up(1), d.right(7), d.down(4));
    }
});

pub const Capital_q = Character(struct {
    pub const width = .wide;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse(d.left(2), d.up(1), d.right(8), d.down(7));
        d.draw_line(d.left(6), d.up(5), d.right(8), d.down(7));
    }
});

pub const Capital_r = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(1), d.left(3), d.down(7));
        d.draw_line(d.left(3), d.up(1), d.right(5), d.up(1));
        d.draw_line(d.left(3), d.down(4), d.right(5), d.down(4));
        d.draw_ellipse_part(d.left(3), d.up(1), d.right(7), d.down(4), d.right(5), d.up(1), d.right(7), d.down(4));
        d.draw_line(d.left(4), d.up(4), d.right(7), d.down(7));
    }
});

pub const Capital_s = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse_part(d.left(3), d.up(1), d.right(7), d.up(4), d.left(3), d.up(1), d.precise(5), d.up(4));
        d.draw_ellipse_part(d.left(3), d.up(1), d.right(7), d.up(4), d.precise(5), d.up(1), d.right(7), d.down(2));
        d.draw_ellipse_part(d.left(3), d.up(4), d.right(7), d.down(7), d.precise(5), d.up(4), d.right(7), d.down(7));
        d.draw_ellipse_part(d.left(3), d.up(4), d.right(7), d.down(7), d.left(3), d.up(6), d.precise(5), d.down(7));
    }
});

pub const Capital_t = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(1), d.right(7), d.up(1));
        d.draw_line(d.left(5), d.up(1), d.left(5), d.down(7));
    }
});

pub const Capital_u = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(1), d.left(3), d.precise(5));
        d.draw_line(d.right(7), d.up(1), d.right(7), d.precise(5));
        d.draw_ellipse_part(d.left(3), d.up(3), d.right(7), d.down(7), d.left(3), d.precise(5), d.right(7), d.down(7));
    }
});

pub const Capital_v = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(1), d.left(5), d.down(7));
        d.draw_line(d.left(5), d.down(7), d.right(7), d.up(1));
    }
});

pub const Capital_w = Character(struct {
    pub const width = .very_wide;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(1), d.up(1), d.left(3), d.down(7));
        d.draw_line(d.left(5), d.up(1), d.left(3), d.down(7));
        d.draw_line(d.left(5), d.up(1), d.right(7), d.down(7));
        d.draw_line(d.right(9), d.up(1), d.right(7), d.down(7));
    }
});

pub const Capital_x = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(1), d.right(7), d.down(7));
        d.draw_line(d.right(7), d.up(1), d.left(3), d.down(7));
    }
});

pub const Capital_y = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(1), d.left(5), d.down(4));
        d.draw_line(d.right(7), d.up(1), d.left(5), d.down(4));
        d.draw_line(d.left(5), d.down(7), d.left(5), d.down(4));
    }
});

pub const Capital_z = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(1), d.right(7), d.up(1));
        d.draw_line(d.left(3), d.down(7), d.right(7), d.up(1));
        d.draw_line(d.left(3), d.down(7), d.right(7), d.down(7));
    }
});

pub const Small_a = Character(struct {
    pub const width = .normal;
    pub const height = .normal;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse(d.left(3), d.up(3), d.right(7), d.down(7));
        d.draw_line(d.right(7), d.up(3), d.right(7), d.down(7));
//         d.draw_ellipse(d.left(3), d.up(5), d.right(7), d.down(7));
//         d.draw_line(d.right(7), d.up(4), d.right(7), d.down(7));
//         d.draw_ellipse_part(d.left(3), d.up(3), d.right(7), d.down(6), d.left(3), d.up(3), d.right(7), d.up(4));
    }
});

pub const Small_b = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse(d.left(3), d.up(3), d.right(7), d.down(7));
        d.draw_line(d.left(3), d.up(1), d.left(3), d.down(7));
    }
});

pub const Small_c = Character(struct {
    pub const width = .normal;
    pub const height = .normal;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse_part(d.left(3), d.up(3), d.right(8), d.down(7), d.left(3), d.up(3), d.right(7), d.down(7));
    }
});

pub const Small_d = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse(d.left(3), d.up(3), d.right(7), d.down(7));
        d.draw_line(d.right(7), d.up(1), d.right(7), d.down(7));
    }
});

pub const Small_e = Character(struct {
    pub const width = .normal;
    pub const height = .normal;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse_part(d.left(3), d.up(3), d.right(7), d.down(7), d.left(3), d.up(3), d.right(7), d.down(5));
        d.draw_ellipse_part(d.left(3), d.up(3), d.right(7), d.down(7), d.left(3), d.down(5), d.right(6), d.down(7));
        d.draw_line(d.left(3), d.down(5), d.right(7), d.down(5));
    }
});

pub const Small_f = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(5), d.up(3), d.left(5), d.down(7));
        d.draw_line(d.left(3), d.up(3), d.right(7), d.up(3));
        d.draw_ellipse_part(d.left(5), d.up(1), d.right(8), d.down(5), d.left(5), d.up(1), d.right(7), d.up(3));
    }
});

pub const Small_g = Character(struct {
    pub const width = .normal;
    pub const height = .low;
    pub fn draw(d: *Character_draw) void {
        //d.draw_ellipse(d.left(3), d.up(3), d.right(7), d.down(7));
        d.draw_ellipse_part(d.left(3), d.up(3), d.right(7), d.down(5), d.left(3), d.up(3), d.right(7), d.up(4));
        d.draw_ellipse_part(d.left(3), d.up(5), d.right(7), d.down(7), d.left(3), d.down(6), d.right(7), d.down(7));
        d.draw_line(d.left(3), d.up(4), d.left(3), d.down(6));
        d.draw_line(d.right(7), d.up(4), d.right(7), d.down(8));
        d.draw_ellipse_part(d.left(3), d.up(7), d.right(7), d.down(9), d.left(3), d.up(8), d.right(7), d.down(9));
    }
});

pub const Small_h = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse_part(d.left(3), d.up(3), d.right(7), d.down(7), d.left(3), d.up(3), d.right(7), d.up(5));
        d.draw_line(d.left(3), d.up(1), d.left(3), d.down(7));
        d.draw_line(d.right(7), d.up(5), d.right(7), d.down(7));
    }
});

pub const Small_i = Character(struct {
    pub const width = .line;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(5), d.up(3), d.left(5), d.down(7));
        d.draw_dot(d.left(5), d.up(1));
    }
});

pub const Small_j = Character(struct {
    pub const width = .small;
    pub const height = .big_low;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.right(6), d.up(3), d.right(6), d.precise(7.5));
        d.draw_dot(d.left(6), d.up(1));
        d.draw_ellipse_part(d.left(3), d.up(6), d.right(6), d.down(9), d.left(4), d.precise(7.5), d.right(6), d.down(9));
    }
});

pub const Small_k = Character(struct {
    pub const width = .small;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(4), d.up(1), d.left(4), d.down(7));
        d.draw_line(d.left(4), d.up(5), d.right(6), d.up(3));
        d.draw_line(d.left(4), d.up(5), d.right(6), d.down(7));
    }
});

pub const Small_l = Character(struct {
    pub const width = .line;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(5), d.up(1), d.left(5), d.down(7));
    }
});

pub const Small_m = Character(struct {
    pub const width = .wide;
    pub const height = .normal;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse_part(d.left(2), d.up(3), d.right(5), d.down(7), d.left(2), d.up(3), d.right(5), d.down(5));
        d.draw_ellipse_part(d.right(5), d.up(3), d.right(8), d.down(7), d.right(5), d.up(3), d.right(8), d.down(5));
        d.draw_line(d.left(2), d.up(3), d.left(2), d.down(7));
        d.draw_line(d.right(5), d.down(5), d.right(5), d.down(7));
        d.draw_line(d.right(8), d.down(5), d.right(8), d.down(7));
    }
});

pub const Small_n = Character(struct {
    pub const width = .normal;
    pub const height = .normal;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse_part(d.left(3), d.up(3), d.right(7), d.down(7), d.left(3), d.up(3), d.right(7), d.down(5));
        d.draw_line(d.left(3), d.up(3), d.left(3), d.down(7));
        d.draw_line(d.right(7), d.down(5), d.right(7), d.down(7));
    }
});

pub const Small_o = Character(struct {
    pub const width = .normal;
    pub const height = .normal;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse(d.left(3), d.up(3), d.right(7), d.down(7));
    }
});

pub const Small_p = Character(struct {
    pub const width = .normal;
    pub const height = .low;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse(d.left(3), d.up(3), d.right(7), d.down(7));
        d.draw_line(d.left(3), d.up(3), d.left(3), d.down(9));
    }
});

pub const Small_q = Character(struct {
    pub const width = .normal;
    pub const height = .low;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse(d.left(3), d.up(3), d.right(7), d.down(7));
        d.draw_line(d.right(7), d.up(3), d.right(7), d.down(9));
    }
});

pub const Small_r = Character(struct {
    pub const width = .small;
    pub const height = .normal;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(4), d.up(3), d.left(4), d.down(7));
        d.draw_ellipse_part(d.left(4), d.up(3), d.right(7), d.down(5), d.left(4), d.up(3), d.right(6), d.down(4));
    }
});

pub const Small_s = Character(struct {
    pub const width = .small;
    pub const height = .normal;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse_part(d.left(4), d.up(3), d.right(6), d.down(5), d.left(4), d.up(3), d.right(5), d.down(5));
        d.draw_ellipse_part(d.left(4), d.up(3), d.right(6), d.down(5), d.right(5), d.up(3), d.right(6), d.down(4));
        d.draw_ellipse_part(d.left(4), d.up(5), d.right(6), d.down(7), d.left(5), d.up(5), d.right(6), d.down(7));
        d.draw_ellipse_part(d.left(4), d.up(5), d.right(6), d.down(7), d.left(4), d.up(6), d.left(5), d.down(7));
    }
});

pub const Small_t = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(5), d.up(1), d.left(5), d.up(6));
        d.draw_line(d.left(3), d.up(3), d.right(7), d.up(3));
        d.draw_ellipse_part(d.left(5), d.up(5), d.right(8), d.down(7), d.left(5), d.up(6), d.right(7), d.down(7));
    }
});

pub const Small_u = Character(struct {
    pub const width = .normal;
    pub const height = .normal;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse_part(d.left(3), d.up(3), d.right(7), d.down(7), d.left(3), d.up(5), d.right(7), d.down(7));
        d.draw_line(d.left(3), d.up(3), d.left(3), d.down(5));
        d.draw_line(d.right(7), d.down(3), d.right(7), d.down(7));
    }
});

pub const Small_v = Character(struct {
    pub const width = .normal;
    pub const height = .normal;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(3), d.left(5), d.down(7));
        d.draw_line(d.right(7), d.up(3), d.left(5), d.down(7));
    }
});

pub const Small_w = Character(struct {
    pub const width = .wide;
    pub const height = .normal;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(2), d.up(3), d.left(4), d.down(7));
        d.draw_line(d.left(5), d.up(4), d.left(4), d.down(7));
        d.draw_line(d.left(5), d.up(4), d.right(6), d.down(7));
        d.draw_line(d.right(8), d.up(3), d.right(6), d.down(7));
    }
});

pub const Small_x = Character(struct {
    pub const width = .normal;
    pub const height = .normal;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(3), d.right(7), d.down(7));
        d.draw_line(d.right(7), d.up(3), d.left(3), d.down(7));
    }
});

pub const Small_y = Character(struct {
    pub const width = .normal;
    pub const height = .low;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.right(7), d.up(3), d.left(3), d.down(9));
        d.draw_line(d.left(3), d.up(3), d.right(5), d.down(6));
    }
});

pub const Small_z = Character(struct {
    pub const width = .normal;
    pub const height = .normal;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(3), d.right(7), d.up(3));
        d.draw_line(d.left(3), d.down(7), d.right(7), d.up(3));
        d.draw_line(d.left(3), d.down(7), d.right(7), d.down(7));
    }
});

pub const Number_0 = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse(d.left(3), d.up(1), d.right(7), d.down(7));
    }
});

pub const Number_1 = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.down(3), d.right(5), d.up(1));
        d.draw_line(d.right(5), d.down(7), d.right(5), d.up(1));
        d.draw_line(d.left(3), d.down(7), d.right(7), d.down(7));
    }
});

pub const Number_2 = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse_part(d.left(3), d.up(1), d.precise(6.5), d.precise(4.5), d.left(3), d.up(1), d.precise(5), d.down(2));
        d.draw_ellipse_part(d.left(3), d.up(1), d.precise(6.5), d.precise(4.5), d.precise(5), d.up(1), d.precise(6.5), d.precise(4));
        d.draw_line(d.precise(6), d.precise(4), d.left(3), d.down(7));
        d.draw_line(d.left(3), d.down(7), d.right(7), d.down(7));
        
    }
});

pub const Number_3 = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse_part(d.left(3), d.up(1), d.right(7), d.up(4), d.left(3), d.up(1), d.precise(5), d.precise(2.5));
        d.draw_ellipse_part(d.left(3), d.up(1), d.right(7), d.up(4), d.precise(5), d.up(1), d.right(7), d.up(4));
        d.draw_ellipse_part(d.left(3), d.up(4), d.right(7), d.down(7), d.left(3), d.precise(5.5), d.precise(5), d.down(7));
        d.draw_ellipse_part(d.left(3), d.up(4), d.right(7), d.down(7), d.precise(5), d.up(4), d.right(7), d.down(7));
    }
});

pub const Number_4 = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.right(6), d.down(7), d.right(6), d.up(1));
        d.draw_line(d.right(6), d.up(1), d.left(3), d.down(5));
        d.draw_line(d.left(3), d.down(5), d.right(7), d.down(5));
    }
});

pub const Number_5 = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(1), d.right(7), d.up(1));
        d.draw_line(d.left(3), d.up(1), d.left(3), d.precise(3.5));
        d.draw_ellipse_part(d.left(2), d.up(3), d.right(7), d.down(7), d.left(3), d.up(3), d.right(7), d.down(7));
    }
});

pub const Number_6 = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse(d.left(3), d.up(3), d.right(7), d.down(7));
        d.draw_ellipse_part(d.left(3), d.up(1), d.right(8), d.down(7), d.left(3), d.up(1), d.right(7), d.precise(4));
        d.draw_line(d.left(3), d.precise(4), d.left(3), d.precise(5));
    }
});

pub const Number_7 = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(1), d.right(7), d.up(1));
        d.draw_line(d.right(7), d.up(1), d.left(4), d.down(7));
    }
});

pub const Number_8 = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse(d.left(3), d.up(1), d.right(7), d.up(4));
        d.draw_ellipse(d.left(3), d.up(4), d.right(7), d.down(7));
    }
});

pub const Number_9 = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse(d.left(3), d.up(1), d.right(7), d.down(5));
        d.draw_ellipse_part(d.left(2), d.up(1), d.right(7), d.down(7), d.left(3), d.precise(4), d.right(7), d.down(7));
        d.draw_line(d.right(7), d.precise(4), d.right(7), d.precise(5));
    }
});

pub const Underscore = Character(struct {
    pub const width = .normal;
    pub const height = .normal;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.down(7), d.right(7), d.down(7));
    }
});

pub const Colon = Character(struct {
    pub const width = .line;
    pub const height = .normal;
    pub fn draw(d: *Character_draw) void {
        d.draw_dot(d.left(5), d.up(3));
        d.draw_dot(d.left(5), d.down(7));
    }
});

pub const Space = Character(struct {
    pub const width = .line;
    pub const height = .normal;
    pub fn draw(d: *Character_draw) void {
        _ = d;
    }
});

pub const Dot = Character(struct {
    pub const width = .line;
    pub const height = .normal;
    pub fn draw(d: *Character_draw) void {
        d.draw_dot(d.left(5), d.down(7));
    }
});

pub const Comma = Character(struct {
    pub const width = .line;
    pub const height = .low;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(5), d.up(7), d.left(5), d.down(8));
    }
});

pub const Semicolon = Character(struct {
    pub const width = .line;
    pub const height = .low;
    pub fn draw(d: *Character_draw) void {
        d.draw_dot(d.right(5), d.up(3));
        d.draw_line(d.left(5), d.up(7), d.left(5), d.down(8));
    }
});

pub const Brace_open = Character(struct {
    pub const width = .small;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse_part(d.left(4), d.up(1), d.right(8), d.down(7), d.left(4), d.up(1), d.right(6), d.down(7));
    }
});

pub const Brace_close = Character(struct {
    pub const width = .small;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse_part(d.left(2), d.up(1), d.right(6), d.down(7), d.left(4), d.up(1), d.right(6), d.down(7));
    }
});

pub const Bracket_open = Character(struct {
    pub const width = .small;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(4), d.up(1), d.left(4), d.down(7));
        d.draw_line(d.left(4), d.up(1), d.right(6), d.up(1));
        d.draw_line(d.left(4), d.down(7), d.right(6), d.down(7));
    }
});

pub const Bracket_close = Character(struct {
    pub const width = .small;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.right(6), d.up(1), d.right(6), d.down(7));
        d.draw_line(d.left(4), d.up(1), d.right(6), d.up(1));
        d.draw_line(d.left(4), d.down(7), d.right(6), d.down(7));
    }
});

pub const Curly_brace_open = Character(struct {
    pub const width = .small;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse_part(d.left(5), d.up(1), d.right(7), d.down(5), d.left(5), d.up(1), d.right(6), d.up(3));
        d.draw_ellipse_part(d.left(5), d.up(3), d.right(7), d.down(7), d.left(5), d.down(5), d.right(6), d.down(7));
        d.draw_ellipse_part(d.left(3), d.up(2), d.right(5), d.down(4), d.left(4), d.up(3), d.right(5), d.down(4));
        d.draw_ellipse_part(d.left(3), d.up(4), d.right(5), d.down(6), d.left(4), d.up(4), d.right(5), d.down(5));
    }
});

pub const Curly_brace_close = Character(struct {
    pub const width = .small;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse_part(d.left(3), d.up(1), d.right(5), d.down(5), d.left(4), d.up(1), d.right(5), d.up(3));
        d.draw_ellipse_part(d.left(3), d.up(3), d.right(5), d.down(7), d.left(4), d.down(5), d.right(5), d.down(7));
        d.draw_ellipse_part(d.left(5), d.up(2), d.right(7), d.down(4), d.left(5), d.up(3), d.right(6), d.down(4));
        d.draw_ellipse_part(d.left(5), d.up(4), d.right(7), d.down(6), d.left(5), d.up(4), d.right(6), d.down(5));
    }
});

pub const Angle_bracket_open = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(4), d.right(7), d.up(2));
        d.draw_line(d.left(3), d.up(4), d.right(7), d.down(6));
    }
});

pub const Angle_bracket_close = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.right(7), d.up(4), d.left(3), d.up(2));
        d.draw_line(d.right(7), d.up(4), d.left(3), d.down(6));
    }
});

pub const Slash = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.right(7), d.up(1), d.left(3), d.down(7));
    }
});

pub const Backslash = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(1), d.right(7), d.down(7));
    }
});

pub const Vertical_bar = Character(struct {
    pub const width = .line;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(5), d.up(1), d.left(5), d.down(7));
    }
});

pub const Apostrophe = Character(struct {
    pub const width = .line;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(5), d.up(1), d.left(5), d.down(3));
    }
});

pub const Quotation_mark = Character(struct {
    pub const width = .small;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(4), d.up(1), d.left(4), d.down(3));
        d.draw_line(d.right(6), d.up(1), d.right(6), d.down(3));
    }
});

pub const Dash = Character(struct {
    pub const width = .small;
    pub const height = .normal;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(4), d.up(5), d.right(6), d.up(5));
    }
});

pub const Plus = Character(struct {
    pub const width = .small;
    pub const height = .normal;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(4), d.up(5), d.right(6), d.up(5));
        d.draw_line(d.left(5), d.up(4), d.left(5), d.down(6));
    }
});

pub const Question_mark = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse_part(d.left(3), d.up(1), d.precise(6.5), d.precise(4.5), d.left(3), d.up(1), d.precise(6.5), d.precise(2));
        d.draw_ellipse_part(d.left(3), d.up(1), d.precise(6.5), d.precise(4.5), d.precise(6), d.precise(2), d.precise(6.5), d.precise(4));
        d.draw_line(d.precise(6), d.precise(4), d.precise(5.5), d.precise(4.5));
        d.draw_ellipse_part(d.left(5), d.up(4), d.precise(8.5), d.precise(7.5), d.left(5), d.up(4), d.precise(5.5), d.precise(5.75));
        d.draw_dot(d.left(5), d.down(7));
    }
});

pub const Exclamation_mark = Character(struct {
    pub const width = .line;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(5), d.up(1), d.left(5), d.down(5));
        d.draw_dot(d.left(5), d.down(7));
    }
});

pub const Asterisk = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(5), d.up(1), d.left(5), d.down(5));
        d.draw_line(d.precise(3.5), d.up(2), d.precise(6.5), d.down(4));
        d.draw_line(d.precise(6.5), d.up(2), d.precise(3.5), d.down(4));
    }
});

pub const Caret = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(5), d.up(1), d.left(3), d.down(4));
        d.draw_line(d.left(5), d.up(1), d.right(7), d.down(4));
    }
});

pub const Hash = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.left(3), d.up(3), d.right(7), d.up(3));
        d.draw_line(d.left(3), d.down(5), d.right(7), d.down(5));
        d.draw_line(d.right(5), d.up(1), d.left(3), d.down(7));
        d.draw_line(d.right(7), d.up(1), d.left(5), d.down(7));
    }
});

pub const Dollar_sign = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_ellipse_part(d.left(3), d.up(1), d.right(7), d.up(4), d.left(3), d.up(1), d.precise(5), d.up(4));
        d.draw_ellipse_part(d.left(3), d.up(1), d.right(7), d.up(4), d.precise(5), d.up(1), d.right(7), d.down(2));
        d.draw_ellipse_part(d.left(3), d.up(4), d.right(7), d.down(7), d.precise(5), d.up(4), d.right(7), d.down(7));
        d.draw_ellipse_part(d.left(3), d.up(4), d.right(7), d.down(7), d.left(3), d.up(6), d.precise(5), d.down(7));
        d.draw_line(d.left(5), d.up(1), d.left(5), d.down(7));
    }
});

pub const Percent = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.right(7), d.up(1), d.left(3), d.down(7));
        d.draw_ellipse(d.left(3), d.up(1), d.right(5), d.down(3));
        d.draw_ellipse(d.left(5), d.up(5), d.right(7), d.down(7));
    }
});

pub const Ampersand = Character(struct {
    pub const width = .normal;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.right(7), d.down(7), d.precise(4.25), d.precise(3.25));
        d.draw_ellipse_part(d.left(4), d.up(1), d.right(6), d.precise(3.5), d.left(4), d.up(1), d.right(6), d.precise(3.25));
        d.draw_line(d.precise(5.5), d.precise(3.33), d.precise(3.4), d.precise(5));
        d.draw_ellipse_part(d.left(3), d.precise(4.5), d.precise(7), d.down(7), d.left(3), d.precise(5), d.precise(5), d.down(7));
        d.draw_ellipse_part(d.precise(3), d.precise(3), d.right(7), d.down(7), d.precise(5), d.up(5), d.right(7), d.down(7));
    }
});

pub const At = Character(struct {
    pub const width = .wide;
    pub const height = .big;
    pub fn draw(d: *Character_draw) void {
        d.draw_line(d.right(6), d.up(2), d.right(6), d.down(6));
        d.draw_ellipse_part(d.left(3), d.up(2), d.right(7), d.down(6), d.left(3), d.up(2), d.right(6), d.down(6));
        d.draw_ellipse_part(d.left(2), d.up(1), d.right(8), d.down(7), d.left(5), d.up(1), d.right(8), d.down(6));
        d.draw_ellipse_part(d.left(2), d.up(1), d.right(8), d.down(7), d.left(2), d.up(1), d.right(5), d.down(7));
        d.draw_line(d.right(6), d.down(6), d.precise(7.2), d.down(6));
        
    }
});

const u = @import("util.zig");

pub const Point = struct {
    pos: u.Vec2r, // logical position, not in pixels, pos * scale is in pixels
    scale: u.Int,
    
    pub fn round(p: Point, e_pos: u.Vec2r) u.Vec2r {
        const round_step = p.scale.to_real().inverse();
        return .create(
            e_pos.x.round(round_step),
            e_pos.y.round(round_step),
        );
    }
    
    pub fn round_rect(p: Point, e_rect: u.Rect2r) u.Rect2r {
        return .create(
            p.round(e_rect.offset),
            p.round(e_rect.size),
        );
    }
    
    pub fn e_in_rect(p: Point, rect: u.Rect2r) bool {
        return rect.includes(p.pos);
    }
    
    pub fn in_rect(p: Point, rect: u.Rect2r) bool {
        return p.e_in_rect(p.round_rect(rect));
    }
    
    pub fn e_in_circle_rect(p: Point, rect: u.Rect2r) bool {
        if (!rect.includes(p.pos)) return false;
        
        const size_2 = u.Vec2r.create(.from_int(2), .from_int(2));
        const in_2 = p.pos.map_from_to(rect, .create(.zero, size_2));
        const distance_squared = in_2.distance_squared(.create(.one, .one));
        return distance_squared.lower_or_equal(.one);
    }
    
    pub fn in_circle_rect(p: Point, rect: u.Rect2r) bool {
        return p.e_in_circle_rect(p.round_rect(rect));
    }
    
    pub fn e_in_ellipse(p: Point, center: u.Vec2r, radius_x: u.Real, radius_y: u.Real) bool {
        const top_left = center.subtract(.create(radius_x, radius_y));
        const size = u.Vec2r.create(radius_x.multiply(.from_int(2)), radius_y.multiply(.from_int(2)));
        return p.e_in_circle_rect(.create(top_left, size));
    }
    
    pub fn in_ellipse(p: Point, center: u.Vec2r, radius_x: u.Real, radius_y: u.Real) bool {
        const top_left = center.subtract(.create(radius_x, radius_y));
        const size = u.Vec2r.create(radius_x.multiply(.from_int(2)), radius_y.multiply(.from_int(2)));
        return p.in_circle_rect(.create(top_left, size));
    }
    
    pub fn e_in_circle(p: Point, center: u.Vec2r, radius: u.Real) bool {
        return p.e_in_ellipse(center, radius, radius);
    }
    
    pub fn in_circle(p: Point, center: u.Vec2r, radius: u.Real) bool {
        return p.in_ellipse(center, radius, radius);
    }
    
    pub fn distance_line_squared(p: Point, p1: u.Vec2r, p2: u.Vec2r) u.Real {
        const l2 = p1.distance_squared(p2);
        if (l2.to_float(f32) == 0.0) return p.pos.distance_squared(p1);
        const v_to_p = p.pos.subtract(p1);
        const v_to_w = p2.subtract(p1);
        const t = v_to_p.dot_product(v_to_w).divide(l2).clamp(.zero, .one);
        const projection = p1.add(v_to_w.scale(t));
        return p.pos.distance(projection);
    }
    
    pub fn e_in_line(p: Point, p1: u.Vec2r, p2: u.Vec2r, width: u.Real) bool {
        const distance = p.distance_line_squared(p1, p2);
        return distance.lower_or_equal(width.divide(.from_int(2)));
    }
    
    pub fn e_in_line_rect(p: Point, rect: u.Rect2r, width: u.Real) bool {
        const radius = width.divide(.from_int(2));
        const space = u.Vec2r.create(radius, radius);
        return p.e_in_line(rect.top_left().add(space), rect.bottom_right().subtract(space), width);
    }
    
    pub fn in_line_rect(p: Point, rect: u.Rect2r, width: u.Real) bool {
        return p.e_in_line_rect(p.round_rect(rect), width);
    }
    
    pub fn e_in_line_rect_mirror(p: Point, rect: u.Rect2r, width: u.Real) bool {
        const radius = width.divide(.from_int(2));
        const offset_top_right = u.Vec2r.create(radius.negate(), radius);
        const offset_bottom_left = u.Vec2r.create(radius, radius.negate());
        return p.e_in_line(rect.top_right().add(offset_top_right), rect.bottom_left().add(offset_bottom_left), width);
    }
    
    pub fn in_line_rect_mirror(p: Point, rect: u.Rect2r, width: u.Real) bool {
        return p.e_in_line_rect_mirror(p.round_rect(rect), width);
    }
    
    pub fn in_hline(p: Point, y: u.Real, x1: u.Real, x2: u.Real, width: u.Real) bool {
        const radius = width.divide(.from_int(2));
        const left_e = u.Real.min(&.{x1, x2});
        const right_e = u.Real.max(&.{x1, x2});
        const round_step = p.scale.to_real().inverse();
        const left = left_e.subtract(radius).round(round_step);
        const right = right_e.add(radius).round(round_step);
        const round_up = y.subtract(radius).round(round_step).add(radius);
        const round_down = y.add(radius).round(round_step).subtract(radius);
        const round_y = if (y.difference(round_up).lower_or_equal(y.difference(round_down))) round_up else round_down;
        return p.e_in_line(.create(left.add(radius), round_y), .create(right.subtract(radius), round_y), width);
    }
    
    pub fn in_vline(p: Point, x: u.Real, y1: u.Real, y2: u.Real, width: u.Real) bool {
        const radius = width.divide(.from_int(2));
        const top_e = u.Real.min(&.{y1, y2});
        const bottom_e = u.Real.max(&.{y1, y2});
        const round_step = p.scale.to_real().inverse();
        const top = top_e.subtract(radius).round(round_step);
        const bottom = bottom_e.add(radius).round(round_step);
        const round_left = x.subtract(radius).round(round_step).add(radius);
        const round_right = x.add(radius).round(round_step).subtract(radius);
        const round_x = if (x.difference(round_left).lower_or_equal(x.difference(round_right))) round_left else round_right;
        return p.e_in_line(.create(round_x, top.add(radius)), .create(round_x, bottom.subtract(radius)), width);
    }
    
    pub fn in_line(p: Point, p1: u.Vec2r, p2: u.Vec2r, width: u.Real) bool {
        const x_diff = p1.x.difference(p2.x);
        const y_diff = p1.y.difference(p2.y);
        const min_diff = width.divide(.from_int(16));
        if (x_diff.lower_than(min_diff) and y_diff.lower_than(min_diff)) {
            return p.in_circle(p1, width.divide(.from_int(2)));
        } else if (x_diff.lower_than(min_diff)) {
            return p.in_vline(p1.x, p1.y, p2.y, width);
        } else if (y_diff.lower_than(min_diff)) {
            return p.in_hline(p1.y, p1.x, p2.x, width);
        } else {
            if (p2.x.higher_than(p1.x)) {
                if (p2.y.higher_than(p1.y)) {
                    // to bottom right
                    return p.in_line_rect(.create(p1, p2.subtract(p1)), width);
                } else {
                    // to top right
                    const top_left = u.Vec2r.create(p1.x, p2.y);
                    const bottom_right = u.Vec2r.create(p2.x, p1.y);
                    return p.in_line_rect_mirror(.create(top_left, bottom_right.subtract(top_left)), width);
                }
            } else {
                if (p2.y.higher_than(p1.y)) {
                    // to bottom left
                    const top_left = u.Vec2r.create(p2.x, p1.y);
                    const bottom_right = u.Vec2r.create(p1.x, p2.y);
                    return p.in_line_rect_mirror(.create(top_left, bottom_right.subtract(top_left)), width);
                } else {
                    // to top left
                    return p.in_line_rect(.create(p2, p1.subtract(p2)), width);
                }
            }
        }
    }
    
    pub fn e_in_ellipse_line(p: Point, center: u.Vec2r, radius_x: u.Real, radius_y: u.Real, width: u.Real) bool {
        const radius = width.divide(.from_int(2));
        return p.e_in_ellipse(center, radius_x.add(radius), radius_y.add(radius)) and !p.e_in_ellipse(center, radius_x.subtract(radius), radius_y.subtract(radius));
    }
    
    pub fn in_ellipse_line(p: Point, center: u.Vec2r, radius_x: u.Real, radius_y: u.Real, width: u.Real) bool {
        const radius = width.divide(.from_int(2));
        const outer_e = u.Rect2r.create(
            center.move_left(radius_x.add(radius)).move_up(radius_y.add(radius)),
            .create(radius_x.multiply(.from_int(2)).add(width), radius_y.multiply(.from_int(2)).add(width))
        );
        const outer = p.round_rect(outer_e);
        const inner_top_left = outer.top_left().move_right(width).move_down(width);
        const inner_bottom_right = outer.bottom_right().move_left(width).move_up(width);
        const inner = u.Rect2r.create(inner_top_left, inner_bottom_right.subtract(inner_top_left));
        return p.e_in_circle_rect(outer) and !p.e_in_circle_rect(inner);
    }
    
    pub fn e_in_circle_line(p: Point, center: u.Vec2r, radius: u.Real, width: u.Real) bool {
        return p.e_in_ellipse_line(center, radius, radius, width);
    }
    
    pub fn in_circle_line(p: Point, center: u.Vec2r, radius: u.Real, width: u.Real) bool {
        return p.in_ellipse_line(center, radius, radius, width);
    }
    
    pub fn angle_from(p: Point, base: u.Vec2r) u.Real {
        const rel = p.pos.subtract(base);
        return rel.angle_fraction();
    }
    
    fn angle_is_between(angle: u.Real, angle_start_i: u.Real, angle_end_i: u.Real) bool {
        const angle_start = angle_start_i.mod(.one);
        const angle_end = angle_end_i.mod(.one);
        if (angle_start.lower_or_equal(angle_end)) {
            return angle.higher_or_equal(angle_start) and angle.lower_or_equal(angle_end);
        } else {
            // cross zero
            return angle.higher_or_equal(angle_start) or angle.lower_or_equal(angle_end);
        }
    }
    
    pub fn e_in_ellipse_line_part(p: Point, center: u.Vec2r, radius_x: u.Real, radius_y: u.Real, width: u.Real, angle_start: u.Real, angle_end: u.Real) bool {
        const radius = width.divide(.from_int(2));
        const start_point_rel = u.Vec2r.from_angle(angle_start, .one);
        const start_point = center.add(.create(start_point_rel.x.multiply(radius_x), start_point_rel.y.multiply(radius_y)));
        if (p.e_in_circle(start_point, radius)) {
            return true;
        }
        const end_point_rel = u.Vec2r.from_angle(angle_end, .one);
        const end_point = center.add(.create(end_point_rel.x.multiply(radius_x), end_point_rel.y.multiply(radius_y)));
        if (p.e_in_circle(end_point, radius)) {
            return true;
        }
        if (!p.e_in_ellipse_line(center, radius_x, radius_y, width)) {
            return false;
        }
        const diff = p.pos.subtract(center);
        const rel = u.Vec2r.create(diff.x.divide(radius_x), diff.y.divide(radius_y));
        const angle = rel.angle_fraction();
        return angle_is_between(angle, angle_start, angle_end);
    }
    
    pub fn in_ellipse_line_part(p: Point, center: u.Vec2r, radius_x: u.Real, radius_y: u.Real, width: u.Real, angle_start: u.Real, angle_end: u.Real) bool {
        const radius = width.divide(.from_int(2));
        const start_point_rel = u.Vec2r.from_angle(angle_start, .one);
        const start_point = center.add(.create(start_point_rel.x.multiply(radius_x), start_point_rel.y.multiply(radius_y)));
        if (p.in_circle(start_point, radius)) {
            return true;
        }
        const end_point_rel = u.Vec2r.from_angle(angle_end, .one);
        const end_point = center.add(.create(end_point_rel.x.multiply(radius_x), end_point_rel.y.multiply(radius_y)));
        if (p.in_circle(end_point, radius)) {
            return true;
        }
        if (!p.in_ellipse_line(center, radius_x, radius_y, width)) {
            return false;
        }
        const diff = p.pos.subtract(center);
        const rel = u.Vec2r.create(diff.x.divide(radius_x), diff.y.divide(radius_y));
        const angle = rel.angle_fraction();
        return angle_is_between(angle, angle_start, angle_end);
    }
    
    pub fn e_in_circle_line_part(p: Point, center: u.Vec2r, radius: u.Real, width: u.Real, angle_start: u.Real, angle_end: u.Real) bool {
        return p.e_in_ellipse_line_part(center, radius, radius, width, angle_start, angle_end);
    }
    
    pub fn in_circle_line_part(p: Point, center: u.Vec2r, radius: u.Real, width: u.Real, angle_start: u.Real, angle_end: u.Real) bool {
        return p.in_ellipse_line_part(center, radius, radius, width, angle_start, angle_end);
    }
};

pub const drawable = u.interface(struct {
    size: fn() u.Vec2i,
    start: fn(scale: u.Int) void,
    pixel: fn(p: Point) u.Color,
    end: fn() void,
    
    pub fn Interface(Imp: type) type {
        return struct {
            const Selfp = *const @This();
            imp: Imp,
            
            fn pixel_antialias(s: Selfp, scale: u.Int, pixel: u.Vec2i, antialias: u.Int) u.Color {
                //u.log_start(.{"Calculating pixel ",pixel});
                const samples = antialias.multiply(antialias);
                const samples_multiply = samples.to_real().inverse();
                const inverse_scale = scale.to_real().inverse();
                const inverse_antialias = antialias.to_real().inverse();
                var total_red = u.Real.zero;
                var total_green = u.Real.zero;
                var total_blue = u.Real.zero;
                var total_alpha = u.Real.zero;
                
                var antialias_y = u.Int.zero;
                while (antialias_y.lower_than(antialias)) {
                    var antialias_x = u.Int.zero;
                    while (antialias_x.lower_than(antialias)) {
                        const half = u.Real.one.divide(.from_int(2));
                        const antialias_pos_x = antialias_x.to_real().add(half);
                        const antialias_pos_y = antialias_y.to_real().add(half);
                        const pixel_offset = u.Vec2r.create(
                            antialias_pos_x.multiply(inverse_antialias),
                            antialias_pos_y.multiply(inverse_antialias),
                        );
                        const pixel_pos = pixel.to_vec2r().add(pixel_offset);
                        const point = Point {
                            .pos = pixel_pos.scale(inverse_scale),
                            .scale = scale,
                        };
                        //u.log(.{"Call with logical position ",point.pos});
                        const this_color = s.imp.call(.pixel, .{point});
                        //u.log(.{"This color is ",this_color});
                        total_red = total_red.add(this_color.red);
                        total_green = total_green.add(this_color.green);
                        total_blue = total_blue.add(this_color.blue);
                        total_alpha = total_alpha.add(this_color.alpha);
                        antialias_x.increase();
                    }
                    antialias_y.increase();
                }
                
                const result = u.Color {
                    .red = total_red.multiply(samples_multiply),
                    .green = total_green.multiply(samples_multiply),
                    .blue = total_blue.multiply(samples_multiply),
                    .alpha = total_alpha.multiply(samples_multiply),
                };
                //u.log_end(.{"Result: ",result});
                return result;
            }
            
            pub fn draw_image_using(s: Selfp, scale: u.Int, buffer: []u.Screen_color, antialias: u.Int) void {
                const lsize = s.size();
                const pixel_width = lsize.x.multiply(scale);
                const pixel_height = lsize.y.multiply(scale);
                u.assert(buffer.len == pixel_width.multiply(pixel_height).to(usize));
                
                s.imp.call(.start, .{scale});
                var pixel_y: u.Int = .zero;
                while (pixel_y.lower_than(pixel_height)) {
                    var pixel_x: u.Int = .zero;
                    while (pixel_x.lower_than(pixel_width)) {
                        const color = s.pixel_antialias(scale, .create(pixel_x, pixel_y), antialias);
                        const screen_color = color.to_screen_color();
                        const index = pixel_y.multiply(pixel_width).add(pixel_x);
                        buffer[index.to(usize)] = screen_color;
                        pixel_x.increase();
                    }
                    pixel_y.increase();
                }
                s.imp.call(.end, .{});
            }
            
            pub fn draw_image(s: Selfp, scale: u.Int, buffer: []u.Screen_color) void {
                s.draw_image_using(scale, buffer, .create(4));
            }
            
            pub fn size(s: Selfp) u.Vec2i {
                return s.imp.call(.size, .{});
            }
        };
    }
});

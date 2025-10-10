const std = @import("std");
const u = @import("util.zig");

pub const Vec2i = struct {
    x: u.Int,
    y: u.Int,
    
    pub const zero = create(.zero, .zero);
    pub const unit_x = create(.one, .zero);
    pub const unit_y = create(.zero, .one);
    
    pub fn create(x: u.Int, y: u.Int) Vec2i {
        return .{
            .x = x,
            .y = y,
        };
    }
    
    pub fn debug_print(vec: Vec2i, stream: anytype) void {
        u.byte_writer.validate(stream);
        vec.x.debug_print(stream);
        stream.write_slice(",");
        vec.y.debug_print(stream);
    }
    
    pub fn add(v1: Vec2i, v2: Vec2i) Vec2i {
        return .create(v1.x.add(v2.x), v1.y.add(v2.y));
    }
    
    pub fn mut_add(v: *Vec2i, v2: Vec2i) void {
        v.* = v.add(v2);
    }
    
    pub fn subtract(v1: Vec2i, v2: Vec2i) Vec2i {
        return .create(v1.x.subtract(v2.x), v1.y.subtract(v2.y));
    }
    
    pub fn mut_subtract(v: *Vec2i, v2: Vec2i) void {
        v.* = v.subtract(v2);
    }
    
    /// a.add(a.offset_to(b)) == b
    pub fn offset_to(v1: Vec2i, v2: Vec2i) Vec2i {
        return v2.subtract(v1);
    }
    
    pub fn scale_up(v: Vec2i, f: u.Int) Vec2i {
        return .create(v.x.multiply(f), v.y.multiply(f));
    }
    
    pub fn scale_down(v: Vec2i, f: u.Int) Vec2i {
        return .create(v.x.divide(f), v.y.divide(f));
    }
    
    pub fn to_vec2r(v: Vec2i) Vec2r {
        return .create(v.x.to_real(), v.y.to_real());
    }
    
    pub fn equal(v1: Vec2i, v2: Vec2i) bool {
        return v1.x.equal(v2.x) and v1.y.equal(v2.y);
    }
    
    pub fn area(v: Vec2i) u.Int {
        return v.x.multiply(v.y);
    }
    
    pub fn move_left(v: Vec2i, amount: u.Int) Vec2i {
        return .create(v.x.subtract(amount), v.y);
    }
    
    pub fn move_right(v: Vec2i, amount: u.Int) Vec2i {
        return .create(v.x.add(amount), v.y);
    }
    
    pub fn move_up(v: Vec2i, amount: u.Int) Vec2i {
        return .create(v.x, v.y.subtract(amount));
    }
    
    pub fn move_down(v: Vec2i, amount: u.Int) Vec2i {
        return .create(v.x, v.y.add(amount));
    }
};

pub const Vec2r = struct {
    x: u.Real,
    y: u.Real,
    
    pub const zero = create(.zero, .zero);
    pub const unit_x = create(.one, .zero);
    pub const unit_y = create(.zero, .one);
    
    pub fn create(x: u.Real, y: u.Real) Vec2r {
        return .{
            .x = x,
            .y = y,
        };
    }
    
    pub fn debug_print(vec: Vec2r, stream: anytype) void {
        u.byte_writer.validate(stream);
        vec.x.debug_print(stream);
        stream.write_slice(",");
        vec.y.debug_print(stream);
    }
    
    pub fn add(v1: Vec2r, v2: Vec2r) Vec2r {
        return .create(v1.x.add(v2.x), v1.y.add(v2.y));
    }
    
    pub fn mut_add(v: *Vec2r, v2: Vec2r) void {
        v.* = v.add(v2);
    }
    
    pub fn subtract(v1: Vec2r, v2: Vec2r) Vec2r {
        return .create(v1.x.subtract(v2.x), v1.y.subtract(v2.y));
    }
    
    pub fn mut_subtract(v: *Vec2r, v2: Vec2r) void {
        v.* = v.subtract(v2);
    }
    
    /// a.add(a.offset_to(b)) == b
    pub fn offset_to(v1: Vec2r, v2: Vec2r) Vec2r {
        return v2.subtract(v1);
    }
    
    pub fn scale(v: Vec2r, f: u.Real) Vec2r {
        return .create(v.x.multiply(f), v.y.multiply(f));
    }
    
    pub fn scale_down(v: Vec2r, f: u.Real) Vec2r {
        return v.scale(f.inverse());
    }
    
    pub fn round_to_vec2i(v: Vec2r) Vec2i {
        return .create(v.x.int_round(), v.y.int_round());
    }
    
    pub fn from_angle(angle: u.Real, v_length: u.Real) Vec2r {
        const angle_pi = angle.to_float(f32) * (std.math.pi * 2);
        const x = @sin(angle_pi);
        const y = -@cos(angle_pi);
        const norm = create(.from_float(x), .from_float(y));
        return norm.scale(v_length);
    }
    
    // to unit
    pub fn map_from_rect(v: Vec2r, rect: Rect2r) Vec2r {
        const relative = v.subtract(rect.offset);
        return .create(
            relative.x.divide(rect.size.x),
            relative.y.divide(rect.size.y),
        );
    }
    
    // from unit
    pub fn map_to_rect(v: Vec2r, rect: Rect2r) Vec2r {
        const scaled = Vec2r.create(
            v.x.multiply(rect.size.x),
            v.y.multiply(rect.size.y),
        );
        return scaled.add(rect.offset);
    }
    
    pub fn map_from_to(v: Vec2r, from: Rect2r, to: Rect2r) Vec2r {
        return v.map_from_rect(from).map_to_rect(to);
    }
    
    // only works for small vectors
    pub fn distance_squared(v1: Vec2r, v2: Vec2r) u.Real {
        const diff = v2.subtract(v1);
        return diff.length_squared();
    }
    
    pub fn distance(v1: Vec2r, v2: Vec2r) u.Real {
        return v2.subtract(v1).length();
    }
    
    // only works for small vectors
    pub fn length_squared(v: Vec2r) u.Real {
        return v.x.multiply(v.x).add(v.y.multiply(v.y));
    }
    
    pub fn length(v: Vec2r) u.Real {
        const x = v.x.to_float(f64);
        const y = v.y.to_float(f64);
        const squared = x * x + y * y;
        return .from_float(@sqrt(squared));
    }
    
    pub fn area(v: Vec2r) u.Real {
        return v.x.multiply(v.y);
    }
    
    pub fn dot_product(v1: Vec2r, v2: Vec2r) u.Real {
        return v1.x.multiply(v2.x).add(v1.y.multiply(v2.y));
    }
    
    pub fn move_left(v: Vec2r, amount: u.Real) Vec2r {
        return .create(v.x.subtract(amount), v.y);
    }
    
    pub fn move_right(v: Vec2r, amount: u.Real) Vec2r {
        return .create(v.x.add(amount), v.y);
    }
    
    pub fn move_up(v: Vec2r, amount: u.Real) Vec2r {
        return .create(v.x, v.y.subtract(amount));
    }
    
    pub fn move_down(v: Vec2r, amount: u.Real) Vec2r {
        return .create(v.x, v.y.add(amount));
    }
    
    fn base_increase_result(base: u.Real, increase: u.Real) u.Real {
        if (base.lower_than(.from_float(0.000001))) {
            return .one;
        }
        const fraction = increase.divide(base);
        const to_hpi = std.math.atan(fraction.to_float(f32));
        return .from_float(to_hpi / (@as(f32, std.math.pi) / 2));
    }
    
    pub fn angle_fraction(v: Vec2r) u.Real {
        var base_amount = u.Real.one;
        var increase_amount = u.Real.one;
        var offset = u.Real.zero;
        if (v.x.higher_or_equal(.zero) and v.y.lower_than(.zero)) {
            // top right
            offset = .zero;
            base_amount = v.y.negate();
            increase_amount = v.x;
        } else if (v.x.higher_or_equal(.zero)) {
            // bottom right
            offset = .from_float(0.25);
            base_amount = v.x;
            increase_amount = v.y;
        } else if (v.y.higher_or_equal(.zero)) {
            // bottom left
            offset = .from_float(0.5);
            base_amount = v.y;
            increase_amount = v.x.negate();
        } else {
            // top left
            offset = .from_float(0.75);
            base_amount = v.x.negate();
            increase_amount = v.y.negate();
        }
        const in_part = base_increase_result(base_amount, increase_amount);
        return in_part.divide(.from_int(4)).add(offset);
    }
    
    pub fn equal_exact(v1: Vec2r, v2: Vec2r) bool {
        return v1.x.equal_exact(v2.x) and v1.y.equal_exact(v2.y);
    }
};

pub const Rect2i = struct {
    offset: Vec2i,
    size: Vec2i,
    
    pub fn create(offset: Vec2i, size: Vec2i) Rect2i {
        return .{
            .offset = offset,
            .size = size,
        };
    }
    
    pub fn debug_print(rect: Rect2i, stream: anytype) void {
        u.byte_writer.validate(stream);
        rect.offset.debug_print(stream);
        stream.write_slice(":");
        rect.size.debug_print(stream);
    }
    
    pub fn move(rect: Rect2i, offset: Vec2i) Rect2i {
        return .create(
            rect.offset.add(offset),
                       rect.size,
        );
    }
    
    pub fn left(rect: Rect2i) u.Int {
        return rect.offset.x;
    }
    
    pub fn right(rect: Rect2i) u.Int {
        return rect.offset.x.add(rect.size.x);
    }
    
    pub fn top(rect: Rect2i) u.Int {
        return rect.offset.y;
    }
    
    pub fn bottom(rect: Rect2i) u.Int {
        return rect.offset.y.add(rect.size.y);
    }
    
    pub fn intersection(r1: Rect2i, r2: Rect2i) ?Rect2i {
        const r_left = u.Int.max(&.{r1.left(), r2.left()});
        const r_right = u.Int.min(&.{r1.right(), r2.right()});
        const r_top = u.Int.max(&.{r1.top(), r2.top()});
        const r_bottom = u.Int.min(&.{r1.bottom(), r2.bottom()});
        
        if (r_left.higher_or_equal(r_right) or r_top.higher_or_equal(r_bottom)) {
            return null;
        } else {
            return .create(
                .create(r_left, r_top),
                .create(r_right.subtract(r_left), r_bottom.subtract(r_top)),
            );
        }
    }
    
    pub fn equal(r1: Rect2i, r2: Rect2i) bool {
        return r1.offset.equal(r2.offset) and r1.size.equal(r2.size);
    }
};

pub const Rect2r = struct {
    offset: Vec2r,
    size: Vec2r,
    
    pub const unit = create(.zero, .create(.one, .one));
    
    pub fn create(offset: Vec2r, size: Vec2r) Rect2r {
        return .{
            .offset = offset,
            .size = size,
        };
    }
    
    pub fn debug_print(rect: Rect2r, stream: anytype) void {
        u.byte_writer.validate(stream);
        rect.offset.debug_print(stream);
        stream.write_slice(":");
        rect.size.debug_print(stream);
    }
    
    pub fn move(rect: Rect2r, offset: Vec2r) Rect2r {
        return .create(
            rect.offset.add(offset),
            rect.size,
        );
    }
    
    pub fn left(rect: Rect2r) u.Real {
        return rect.offset.x;
    }
    
    pub fn right(rect: Rect2r) u.Real {
        return rect.offset.x.add(rect.size.x);
    }
    
    pub fn top(rect: Rect2r) u.Real {
        return rect.offset.y;
    }
    
    pub fn bottom(rect: Rect2r) u.Real {
        return rect.offset.y.add(rect.size.y);
    }
    
    pub fn top_left(rect: Rect2r) u.Vec2r {
        return rect.offset;
    }
    
    pub fn top_right(rect: Rect2r) u.Vec2r {
        return rect.offset.move_right(rect.size.x);
    }
    
    pub fn bottom_left(rect: Rect2r) u.Vec2r {
        return rect.offset.move_down(rect.size.y);
    }
    
    pub fn bottom_right(rect: Rect2r) u.Vec2r {
        return rect.offset.add(rect.size);
    }
    
    pub fn intersection(r1: Rect2r, r2: Rect2r) ?Rect2r {
        const r_left = u.Real.max(&.{r1.left(), r2.left()});
        const r_right = u.Real.min(&.{r1.right(), r2.right()});
        const r_top = u.Real.max(&.{r1.top(), r2.top()});
        const r_bottom = u.Real.min(&.{r1.bottom(), r2.bottom()});
        
        if (r_left.higher_or_equal(r_right) or r_top.higher_or_equal(r_bottom)) {
            return null;
        } else {
            return .create(
                .create(r_left, r_top),
                .create(r_right.subtract(r_left), r_bottom.subtract(r_top)),
            );
        }
    }
    
    pub fn includes(rect: Rect2r, point: Vec2r) bool {
        return u.all(&.{
            point.x.higher_or_equal(rect.left()),
            point.x.lower_or_equal(rect.right()),
            point.y.higher_or_equal(rect.top()),
            point.y.lower_or_equal(rect.bottom()),
        });
    }
};

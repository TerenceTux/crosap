const std = @import("std");
const u = @import("util.zig");

pub const Int = struct {
    v: i32,
    
    pub const zero = create(0);
    pub const one = create(1);
    
    pub fn debug_print(i: Int, stream: anytype) void {
        u.byte_writer.validate(stream);
        i.write_as_string(stream, .create(10));
    }
    
    pub fn write_as_string(i: Int, stream: anytype, base: Int) void {
        u.byte_writer.validate(stream);
        u.write_int_string(stream, i.v, base.to(u8));
    }
    
    pub fn create(value: anytype) Int {
        return .{
            .v = @intCast(value),
        };
    }
    
    pub fn to(i: Int, T: type) T {
        return @intCast(i.v);
    }
    
    pub fn to_real(i: Int) Real {
        return .from_int(i.v);
    }
    
    pub fn add(v1: Int, v2: Int) Int {
        return .create(
            v1.v + v2.v
        );
    }
    
    pub fn mut_add(v: *Int, v2: Int) void {
        v.* = v.add(v2);
    }
    
    pub fn subtract(v1: Int, v2: Int) Int {
        return .create(
            v1.v - v2.v
        );
    }
    
    pub fn mut_subtract(v: *Int, v2: Int) void {
        v.* = v.subtract(v2);
    }
    
    pub fn multiply(v1: Int, v2: Int) Int {
        return .create(
            v1.v * v2.v
        );
    }
    
    pub fn divide(v1: Int, v2: Int) Int {
        return .create(
            @divFloor(v1.v, v2.v)
        );
    }
    
    pub fn negate(i: Int) Int {
        return .create(
            -i.v,
        );
    }
    
    pub fn absolute(i: Int) Int {
        return .create(
            @abs(i.v),
        );
    }
    
    pub fn difference(v1: Int, v2: Int) Int {
        return v1.subtract(v2).absolute();
    }
    
    pub fn mod(v1: Int, v2: Int) Int {
        return .create(
            @mod(v1.v, v2.v),
        );
    }
    
    pub fn equal(v1: Int, v2: Int) bool {
        return v1.v == v2.v;
    }
    
    pub fn lower_than(v1: Int, v2: Int) bool {
        return v1.v < v2.v;
    }
    
    pub fn lower_or_equal(v1: Int, v2: Int) bool {
        return v1.v <= v2.v;
    }
    
    pub fn higher_than(v1: Int, v2: Int) bool {
        return v1.v > v2.v;
    }
    
    pub fn higher_or_equal(v1: Int, v2: Int) bool {
        return v1.v >= v2.v;
    }
    
    pub fn max(values: []const Int) Int {
        u.assert(values.len > 0);
        var v = values[0];
        for (values[1..]) |n| {
            if (n.higher_than(v)) {
                v = n;
            }
        }
        return v;
    }
    
    pub fn min(values: []const Int) Int {
        u.assert(values.len > 0);
        var v = values[0];
        for (values[1..]) |n| {
            if (n.lower_than(v)) {
                v = n;
            }
        }
        return v;
    }
    
    pub fn increase_by(i: *Int, by: Int) void {
        i.v += by.v;
    }
    
    pub fn increase(i: *Int) void {
        i.v += 1;
    }
    
    pub fn decrease_by(i: *Int, by: Int) void {
        i.v -= by.v;
    }
    
    pub fn decrease(i: *Int) void {
        i.v -= 1;
    }
    
    pub fn clamp(i: Int, lowest: Int, highest: Int) Int {
        u.assert(highest.higher_or_equal(lowest));
        if (i.lower_than(lowest)) {
            return lowest;
        } else if(i.higher_than(highest)) {
            return highest;
        } else {
            return i;
        }
    }
};

pub const Real = struct {
    const fraction_bits = 32;
    const int_bits = 64 - fraction_bits;
    const int_mask = ~@as(i64, 0) << fraction_bits;
    const factor = 1 << fraction_bits;
    v: i64,
    
    pub const zero = Real {.v = 0};
    pub const one = Real {.v = factor};
    
    pub fn debug_print(r: Real, stream: anytype) void {
        u.byte_writer.validate(stream);
        r.write_as_string(stream, .create(10));
    }
    
    const printing_precision = Real{.v = 256};
    const printing_base_info = info_calc: {
        const Info = struct {
            digits: usize,
            adding: Real,
        };
        const precision_inverse = printing_precision.inverse().int_round().to(u32);
        var result: [u.number_chars.len - 1]Info = undefined;
        for (&result, 0..) |*info, index| {
            const base: u32 = @intCast(index + 2);
            const digits = std.math.log(u32, base, precision_inverse);
            const real_precision_inv = std.math.pow(u32, base, digits);
            const real_precision = Real.from_int(real_precision_inv).inverse();
            info.digits = digits;
            info.adding = real_precision.divide(.from_int(2));
        }
        break:info_calc result;
    };
    
    pub fn write_as_string(r: Real, stream: anytype, base_i: Int) void {
        u.byte_writer.validate(stream);
        const base = base_i.to(u32);
        
        u.assert(base > 1);
        u.assert(base <= u.number_chars.len);
        
        const printing_info = printing_base_info[base - 2];
        var added: Real = undefined;
        if (r.lower_than(.zero)) {
            stream.write('-');
            added = r.negate().add(printing_info.adding);
        } else {
            added = r.add(printing_info.adding);
        }
        const unsigned: u64 = @intCast(added.v);
        const int_part: u32 = @intCast(unsigned >> fraction_bits);
        u.write_int_string(stream, int_part, base_i.to(u8));
        
        var current: u64 = @intCast(unsigned & ~int_mask);
        var printed_dot = false;
        var skipped_zeroes: usize = 0;
        
        for (0..printing_info.digits) |_| {
            current *= base;
            const digit = current >> fraction_bits;
            current -= digit << fraction_bits;
            u.assert(digit < base);
            if (digit == 0) {
                skipped_zeroes += 1;
            } else {
                if (!printed_dot) {
                    stream.write('.');
                    printed_dot = true;
                }
                for (0..skipped_zeroes) |_| {
                    stream.write(u.number_chars[0]);
                }
                skipped_zeroes = 0;
                stream.write(u.number_chars[digit]);
            }
        }
    }
    
    pub fn from_int(value: anytype) Real {
        const int_part: i32 = @intCast(value);
        return .{
            .v = @as(i64, int_part) << 32,
        };
    }
    
    pub fn from_float(value: anytype) Real {
        const scaled_float = value * factor;
        const scaled_int: i64 = @intFromFloat(scaled_float);
        return .{
            .v = scaled_int,
        };
    }
    
    pub fn from_fraction(value: anytype, divide_by: anytype) Real {
        return from_int(value).divide(from_int(divide_by));
    }
    
    pub fn from_add_fraction(start: anytype, value: anytype, divide_by: anytype) Real {
        return from_int(start).add(from_fraction(value, divide_by));
    }
    
    pub fn to_float(r: Real, Type: type) Type {
        const scaled_float: Type = @floatFromInt(r.v);
        return scaled_float / factor;
    }
    
    pub fn int_floor(r: Real) Int {
        return .create(r.v >> fraction_bits);
    }
    
    pub fn int_round(r: Real) Int {
        const added = r.v + factor / 2;
        return .create(added >> fraction_bits);
    }
    
    pub fn int_ceil(r: Real) Int {
        const fraction = r.v & ~int_mask;
        if (fraction == 0) {
            return .create(r.v >> fraction_bits);
        } else {
            return .create((r.v >> fraction_bits) + 1);
        }
    }
    
    pub fn add(r1: Real, r2: Real) Real {
        return .{
            .v = r1.v + r2.v,
        };
    }
    
    pub fn mut_add(v: *Real, v2: Real) void {
        v.* = v.add(v2);
    }
    
    pub fn negate(r: Real) Real {
        return .{
            .v = -r.v,
        };
    }
    
    pub fn absolute(r: Real) Real {
        return .{
            .v = @intCast(@abs(r.v)),
        };
    }
    
    pub fn subtract(r1: Real, r2: Real) Real {
        return .{
            .v = r1.v - r2.v,
        };
    }
    
    pub fn mut_subtract(v: *Real, v2: Real) void {
        v.* = v.subtract(v2);
    }
    
    pub fn difference(r1: Real, r2: Real) Real {
        return r1.subtract(r2).absolute();
    }
    
    pub fn multiply(r1: Real, r2: Real) Real {
        const result = @as(i96, r1.v) * @as(i96, r2.v);
        return .{
            .v = @intCast(result >> fraction_bits),
        };
    }
    
    pub fn divide(r1: Real, r2: Real) Real {
        const scaled_1 = @as(i96, r1.v) << fraction_bits;
        return .{
            .v = @intCast(@divFloor(scaled_1, @as(i96, r2.v))),
        };
    }
    
    pub fn round(r: Real, step: Real) Real {
        const scaled = r.divide(step);
        const added = scaled.v + factor / 2;
        const rounded = Real {.v = added & int_mask};
        return rounded.multiply(step);
    }
    
    pub fn floor(r: Real, step: Real) Real {
        const scaled = r.multiply(step);
        const rounded = Real {.v = scaled.v & int_mask};
        return rounded.divide(step);
    }
    
    pub fn mod(r: Real, rmax: Real) Real {
        const floored = r.floor(rmax);
        return r.subtract(floored);
    }
    
    pub fn lower_than(r1: Real, r2: Real) bool {
        return r1.v < r2.v;
    }
    
    pub fn lower_or_equal(r1: Real, r2: Real) bool {
        return r1.v <= r2.v;
    }
    
    pub fn higher_than(r1: Real, r2: Real) bool {
        return r1.v > r2.v;
    }
    
    pub fn higher_or_equal(r1: Real, r2: Real) bool {
        return r1.v >= r2.v;
    }
    
    pub fn max(values: []const Real) Real {
        u.assert(values.len > 0);
        var v = values[0];
        for (values[1..]) |n| {
            if (n.higher_than(v)) {
                v = n;
            }
        }
        return v;
    }
    
    pub fn min(values: []const Real) Real {
        u.assert(values.len > 0);
        var v = values[0];
        for (values[1..]) |n| {
            if (n.lower_than(v)) {
                v = n;
            }
        }
        return v;
    }
    
    pub fn inverse(r: Real) Real {
        return one.divide(r);
    }
    
    pub fn square(r: Real) Real {
        return r.multiply(r);
    }
    
    // to 0-1
    pub fn map_from(r: Real, m_zero: Real, m_one: Real) Real {
        const diff = m_one.subtract(m_zero);
        return r.subtract(m_zero).divide(diff);
    }
    
    // from 0-1
    pub fn map_to(r: Real, m_zero: Real, m_one: Real) Real {
        const diff = m_one.subtract(m_zero);
        return r.multiply(diff).add(m_zero);
    }
    
    pub fn map(r: Real, from_1: Real, from_2: Real, to_1: Real, to_2: Real) Real {
        return r.map_from(from_1, from_2).map_to(to_1, to_2);
    }
    
    pub fn square_root(r: Real) Real {
        u.assert(r.higher_or_equal(.zero));
        
        var result: u64 = 0; // in fixed point
        var multiplied: u64 = 0;
        var bit_nr: u6 = 47;
        var bit: u64 = @as(u64, 1) << bit_nr; // to add to result
        var factor1: u64 = 0;
        while (true) {
            const result_when_add = result | bit;
            //const mult_when_add: u64 = @intCast((@as(i96, result_when_add) * @as(i96, result_when_add)) >> fraction_bits);
            //const factor1: u64 = @intCast(@as(u128, result) << (bit_nr + 1) >> fraction_bits);
            const f2_shift: i8 = @as(i8, bit_nr) + @as(i8, bit_nr) - fraction_bits;
            const factor2 = if (f2_shift > 0) @as(u64, 1) << @intCast(f2_shift) else 0;
            //const factor2: u64 = @intCast(@as(u128, bit) << bit_nr >> fraction_bits);
            const mult_when_add = multiplied + factor1 + factor2;
            if (mult_when_add <= r.v) {
                result = result_when_add;
                factor1 |= factor2 << 1;
                if (mult_when_add == r.v) {
                    break;
                }
                multiplied = mult_when_add;
                //u.log(.{"Result now: ",result});
            }
            if (bit_nr == 0) {
                break;
            }
            bit >>= 1;
            bit_nr -= 1;
            factor1 >>= 1;
        }
        return .{.v = @intCast(result)};
    }
    
    pub fn other_square_root(r: Real) Real{
        // https://botian.replnotes.com/posts/fast_integer_square_root
        u.assert(r.higher_or_equal(.zero));
        
        const input = @as(u128, @intCast(r.v)) << fraction_bits;
        var value = input;
        var result: u128 = 0;
        
        var bit: u128 = 1 << 126;
        while (bit > input) {
            bit >>= 2;
        }
        
        while (bit != 0) {
            if (value >= result + bit) {
                value -= result + bit;
                result = (result >> 1) | bit;
            } else {
                result >>= 1;
            }
            bit >>= 2;
        }
        return .{.v = @intCast(result)};
    }
    
    pub fn power(r: Real, p: Real) Real {
        var result = one;
        if (p.lower_than(.zero)) {
            return power(r, p.negate()).inverse();
        }
        const p_unsigned: u64 = @intCast(p.v);
        const int_mask_u: u64 = @as(u64, @bitCast(int_mask));
        
        var current_bit: u32 = 1;
        var power_int: u32 = @intCast((p_unsigned & int_mask_u) >> fraction_bits);
        if (power_int != 0) {
            var current_multiply = r;
            while (true) {
                if (power_int & current_bit != 0) {
                    result = result.multiply(current_multiply);
                    power_int -= current_bit;
                    
                    if (power_int == 0) {
                        break;
                    }
                }
                current_bit <<= 1;
                current_multiply = current_multiply.multiply(current_multiply);
            }
        }
        
        current_bit = 1 << 31;
        var power_fraction: u32 = @intCast(p_unsigned & ~int_mask_u);
        if (power_fraction != 0) {
            var current_multiply = r.square_root();
            while (true) {
                if (power_fraction & current_bit != 0) {
                    result = result.multiply(current_multiply);
                    power_fraction -= current_bit;
                    
                    if (power_fraction == 0) {
                        break;
                    }
                }
                current_bit >>= 1;
                current_multiply = current_multiply.square_root();
            }
        }
        
        return result;
    }
    
    pub fn clamp(r: Real, lowest: Real, highest: Real) Real {
        u.assert(highest.higher_or_equal(lowest));
        if (r.lower_than(lowest)) {
            return lowest;
        } else if(r.higher_than(highest)) {
            return highest;
        } else {
            return r;
        }
    }
    
    pub fn equal_exact(r1: Real, r2: Real) bool {
        return r1.v == r2.v;
    }
    
    pub fn sin(r: Real) Real {
        return .from_float(@sin(r.to_float(f32)));
    }
    
    pub fn cos(r: Real) Real {
        return .from_float(@cos(r.to_float(f32)));
    }
    
    pub fn tan(r: Real) Real {
        return .from_float(@tan(r.to_float(f32)));
    }
    
    pub fn asin(r: Real) Real {
        return .from_float(std.math.asin(r.to_float(f32)));
    }
    
    pub fn acos(r: Real) Real {
        return .from_float(std.math.acos(r.to_float(f32)));
    }
    
    pub fn atan(r: Real) Real {
        return .from_float(std.math.atan(r.to_float(f32)));
    }
};

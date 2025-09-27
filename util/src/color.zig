const u = @import("util.zig");
const Real = u.Real;

const linear_to_srgb = srgb_to_linear.inverse();
const srgb_to_linear = Real.from_float(2.2);

// High precision and outside of ranges
pub const Color = struct {
    // stored premultiplied in linear space
    red: Real,
    green: Real,
    blue: Real,
    alpha: Real,
    
    pub const transparent = from_real_rgba(.zero, .zero, .zero, .zero);
    
    pub fn debug_print(c: Color, stream: anytype) void {
        u.byte_writer.validate(stream);
        stream.write_slice("[");
        c.red.debug_print(stream);
        stream.write_slice(",");
        c.green.debug_print(stream);
        stream.write_slice(",");
        c.blue.debug_print(stream);
        stream.write_slice(",");
        c.alpha.debug_print(stream);
        stream.write_slice("]");
    }
    
    pub fn from_real_rgba(red: Real, green: Real, blue: Real, alpha: Real) Color {
        return .{
            .red = red.multiply(alpha),
            .green = green.multiply(alpha),
            .blue = blue.multiply(alpha),
            .alpha = alpha,
        };
    }
    
    pub fn from_real_rgb(red: Real, green: Real, blue: Real) Color {
        return .from_real_rgba(red, green, blue, .one);
    }
    
    pub fn from_byte_rgb(red: u8, green: u8, blue: u8) Color {
        return from_real_rgb(
            Real.from_int(red).divide(.from_int(255)),
            Real.from_int(green).divide(.from_int(255)),
            Real.from_int(blue).divide(.from_int(255)),
        );
    }
    
    pub fn to_screen_color(c: Color) Screen_color {
//         const red_srgb = c.red.power(linear_to_srgb);
//         const green_srgb = c.green.power(linear_to_srgb);
//         const blue_srgb = c.blue.power(linear_to_srgb);
        const red_srgb = c.red.square_root();
        const green_srgb = c.green.square_root();
        const blue_srgb = c.blue.square_root();
//         const red_srgb = c.red;
//         const green_srgb = c.green;
//         const blue_srgb = c.blue;
        
        const alpha_byte = c.alpha.multiply(.from_int(255));
        const red_byte = red_srgb.multiply(.from_int(255));
        const green_byte = green_srgb.multiply(.from_int(255));
        const blue_byte = blue_srgb.multiply(.from_int(255));
        
        const alpha_int = alpha_byte.int_round().clamp(.create(0), .create(255));
        const red_int = red_byte.int_round().clamp(.create(0), .create(255));
        const green_int = green_byte.int_round().clamp(.create(0), .create(255));
        const blue_int = blue_byte.int_round().clamp(.create(0), .create(255));
        return .{
            .red = red_int.to(u8),
            .green = green_int.to(u8),
            .blue = blue_int.to(u8),
            .alpha = alpha_int.to(u8),
        };
    }
    
    pub fn mix(c1: Color, c2: Color, factor: u.Real) Color {
        return .{
            .red = factor.map_to(c1.red, c2.red),
            .green = factor.map_to(c1.green, c2.green),
            .blue = factor.map_to(c1.blue, c2.blue),
            .alpha = factor.map_to(c1.alpha, c2.alpha),
        };
    }
    
    pub fn add(c1: *Color, c2: Color) void {
        c1.* = over(c1.*, c2);
    }
    
    pub fn over(c1: Color, c2: Color) Color {
        const one_minus_alpha = Real.one.subtract(c2.alpha);
        return .{
            .red = c2.red.add(c1.red.multiply(one_minus_alpha)),
            .green = c2.green.add(c1.green.multiply(one_minus_alpha)),
            .blue = c2.blue.add(c1.blue.multiply(one_minus_alpha)),
            .alpha = c2.alpha.add(c1.alpha.multiply(one_minus_alpha)),
        };
    }
};

// Compact with 24 bit precision
pub const Screen_color = struct {
    // stored premultiplied in srgb space
    red: u8,
    green: u8,
    blue: u8,
    alpha: u8,
    
    pub fn debug_print(c: Screen_color, stream: anytype) void {
        u.byte_writer.validate(stream);
        stream.write_slice("[");
        u.Int.create(c.red).debug_print(stream);
        stream.write_slice(",");
        u.Int.create(c.green).debug_print(stream);
        stream.write_slice(",");
        u.Int.create(c.blue).debug_print(stream);
        stream.write_slice(",");
        u.Int.create(c.alpha).debug_print(stream);
        stream.write_slice("]");
    }
    
    pub const colors = struct {
        pub const transparent = Screen_color {.red = 0, .green = 0, .blue = 0, .alpha = 0};
        pub const black = from_rgb(0, 0, 0);
        pub const red = from_rgb(255, 0, 0);
        pub const green = from_rgb(0, 255, 0);
        pub const yellow = from_rgb(255, 255, 0);
        pub const blue = from_rgb(0, 0, 255);
        pub const pink = from_rgb(255, 0, 255);
        pub const cyan = from_rgb(0, 255, 255);
        pub const white = from_rgb(255, 255, 255);
    };
    
    pub fn from_rgb(red: u8, green: u8, blue: u8) Screen_color {
        return .{
            .red = red,
            .green = green,
            .blue = blue,
            .alpha = 255,
        };
    }
    
    pub fn to_real_color(c: Screen_color) Color {
        const multiply_for_norm = comptime Real.from_int(1).divide(.from_int(255));
        const alpha = Real.from_int(c.alpha).multiply(multiply_for_norm);
        const red_srgb = Real.from_int(c.red).multiply(multiply_for_norm);
        const green_srgb = Real.from_int(c.green).multiply(multiply_for_norm);
        const blue_srgb = Real.from_int(c.blue).multiply(multiply_for_norm);
        
        return .{
//             .red = red_srgb.power(srgb_to_linear),
//             .green = green_srgb.power(srgb_to_linear),
//             .blue = blue_srgb.power(srgb_to_linear),
            .red = red_srgb.square(),
            .green = green_srgb.square(),
            .blue = blue_srgb.square(),
            .alpha = alpha,
        };
    }
};

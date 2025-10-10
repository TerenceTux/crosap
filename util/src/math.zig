const Real = @import("number.zig").Real;
const Vec2r = @import("vec.zig").Vec2r;
const assert = @import("util.zig").assert;
const u = @import("util.zig");

pub fn move_linear_to(current: Real, target: Real, dtime: Real, max_speed: Real) Real {
    assert(dtime.higher_or_equal(.zero));
    assert(max_speed.higher_or_equal(.zero));
    
    var diff = target.subtract(current);
    const max_distance = max_speed.multiply(dtime);
    if (diff.higher_than(max_distance)) {
        diff = max_distance;
    } else if (diff.negate().higher_than(max_distance)) {
        diff = max_distance.negate();
    }
    return current.add(diff);
}

// pub fn move_linear_to2()

// pub fn move_smooth_to()


pub fn move_smooth_to2(current: *Vec2r, speed: *Vec2r, target: Vec2r, dtime: Real, max_accel: Real) void {
    assert(dtime.higher_or_equal(.zero));
    assert(max_accel.higher_or_equal(.zero));
    u.log_start(.{"Start to move from ",current.*," to ",target," with speed ",speed.*,", dtime: ",dtime,", max_accel: ",max_accel});
    defer u.log_end(.{});
    
    const start_speed = speed.*;
    const diff = current.offset_to(target);
    u.log(.{"Diff: ",diff});
}

// pub fn move_smooth_to2(current: *Vec2r, speed: *Vec2r, target: Vec2r, dtime: Real, max_accel: Real) void {
//     assert(dtime.higher_or_equal(.zero));
//     assert(max_accel.higher_or_equal(.zero));
//     u.log_start(.{"Start to move from ",current.*," to ",target," with speed ",speed.*,", dtime: ",dtime,", max_accel: ",max_accel});
//     defer u.log_end(.{});
//     
//     const start_speed = speed.*;
//     const diff = current.offset_to(target);
//     u.log(.{"Diff: ",diff});
//     
//     const diff_len = diff.length();
//     const max_speed = diff_len.multiply(max_accel).multiply(.from_float(1.5)).square_root();
//     
//     // with this speed, we would end at the target:
//     const opt_avg_speed = diff.scale(dtime.inverse());
//     u.log(.{"opt avg speed: ",opt_avg_speed});
//     // but we can only change the speed linear in this frame,
//     // so to have an average speed of `optimal_speed` the end speed must be:
//     var opt_end_speed = opt_avg_speed.add(start_speed.offset_to(opt_avg_speed));
//     u.log(.{"opt end speed: ",opt_end_speed});
//     const opt_speed_len = opt_end_speed.length();
//     if (opt_speed_len.higher_than(max_speed)) {
//         opt_end_speed = opt_end_speed.scale(max_speed.divide(opt_speed_len));
//     }
//     u.log(.{"opt end speed: ",opt_end_speed});
//     
//     // to reach this optimal end speed, we need an acceleration of:
//     const opt_speed_change = speed.offset_to(opt_end_speed);
//     var accel = opt_speed_change.scale(dtime.inverse());
//     u.log(.{"accel: ",accel});
//     const accel_len = accel.length(); // can we do this without square root?
//     if (accel_len.higher_than(max_accel)) {
//         accel = accel.scale(max_accel.divide(accel_len));
//     }
//     u.log(.{"accel: ",accel});
//     
//     const speed_change = accel.scale(dtime);
//     const end_speed = start_speed.add(speed_change);
//     u.log(.{"end_speed: ",end_speed});
//     const avg_speed = start_speed.add(end_speed).scale(.from_float(0.5));
//     const movement = avg_speed.scale(dtime);
//     u.log(.{"movement: ",movement});
//     current.mut_add(movement);
//     speed.* = end_speed;
// }

// Consider this situation:
// 
//    current ----> speed
//       \
//        _| diff
//       target
//
// Ending at the target takes t time
// The average speed is avg = diff / t
// We call the initial speed v1
//
// The speed to end at target looks like this:
// 
//   * v1
//   |\
//   | \ a
//   |  \       0
//   |---------*---
//   |    \   / a
//   |     \ /
//   |      * v2
//   <------X-->
//      t1   t2
//   <--------->
//        t
//
// t = t1 + t2
// v1 and diff is known, we need to calculate the others (notably v2)
// avg = diff / t
// avg = ((v1 + v2) / 2 * t1 + 0.5 * v2 * t2) / t
// (v1 + v2) / 2 * t1 + 0.5 * v2 * t2 = diff
// (v1 + v2) * 0.5 * t1 + v2 * 0.5 * t2 = diff
// (v1 + v2) * t1 + v2 * t2 = diff * 2
// |v1 - v2| = t1 * a
// |v2| = t2 * a
// v2 * v2 = (t2 * a)^2 = t2^2 * a^2
// t2^2 = (v2 * v2) / a^2
// t1 = |v1 - v2| / a
// t2 = |v2| / a
// (v1 + v2) * sqrt((v1 - v2) * (v1 - v2)) / a + v2 * sqrt(v2 * v2) / a = diff * 2

// https://www.wolframalpha.com/input?i2d=true&i=solve+%5C%2840%29v+%2B+w%5C%2841%29Divide%5BSqrt%5B%5C%2840%29v+-+w%5C%2841%29+*+%5C%2840%29v+-+w%5C%2841%29%5D%2Ca%5D+%2B+wDivide%5BSqrt%5Bw+*+w%5D%2Ca%5D+%3D+2+d+for+w
// v2 = +- sqrt((v1 * v1 +- 2 * a * diff) / 2)
// v2 = sqrt((v1 * v1 + 2 * a * diff) / 2)

// (v1 + v2) * sqrt((v1 - v2) * (v1 - v2)) + v2 * sqrt(v2 * v2) = diff * 2 * a
// v1 * sqrt((v1 - v2) * (v1 - v2)) + v2 * sqrt((v1 - v2) * (v1 - v2)) + v2 * sqrt(v2 * v2) = diff * 2 * a
// sqrt((v1 + v2) * (v1 + v2) * (v1 - v2) * (v1 - v2)) + v2 * sqrt(v2 * v2) = diff * 2 * a

// ((v1 + v2) * (v1 - v2))^2
// (v1 * (v1 - v2) + v2 * (v1 - v2))^2
// (v1 * v1 - v1 * v2 + v2 * v1 - v2 * v2)^2
// (v1 * v1 - v2 * v2)^2
// sqrt((v1 * v1 - v2 * v2)^2) + v2 * sqrt(v2 * v2) = diff * 2 * a

// (v1x + v2x) * (v1x - v2x) + (v1y + v2y) * (v1y - v2y)
// v1x * v1x - v2x * v2x + v1y * v1y - v2y * v2y
// 

// v1x * sqrt((v1x - v2x)^2 + (v1y - v2y)^2) + v2x * sqrt((v1x - v2x)^2 + (v1y - v2y)^2) + v2x * sqrt(v2x^2 * v2y^2) = diffx * 2 * a
// v1y * sqrt((v1 - v2) * (v1 - v2)) + v2y * sqrt((v1 - v2) * (v1 - v2)) + v2y * sqrt(v2 * v2) = diffy * 2 * a

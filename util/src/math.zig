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

pub fn move_smooth_to(current: *Real, speed: *Real, target: Real, dtime: Real, max_accel: Real) void {
    const to_left = speed.*.lower_than(.zero);
    const start_speed = if (to_left) speed.*.negate() else speed.*;
    const real_diff = target.subtract(current.*);
    const diff_unchecked = if (to_left) real_diff.negate() else real_diff;
    const diff = diff_unchecked.clamp(.from_int(-100_000), .from_int(100_000));
    
    // Time to stop if we brake now
    const stop_t = start_speed.divide(max_accel);
    // Distance we move if we brake now
    const stop_d = stop_t.multiply(start_speed).multiply(.from_float(0.5));
    
    var a1 = max_accel;
    var t1 = Real.zero;
    var total_t = stop_t;
    // The speed changes with a1 for t1 seconds, then with -a1 for (total_t - t1) seconds and then stops
    if (diff.higher_than(stop_d)) {
        // We need to accelerate more
        const extra_d = diff.subtract(stop_d);
        t1 = start_speed.multiply(start_speed).add(extra_d.multiply(max_accel)).square_root().subtract(start_speed).divide(max_accel);
        a1 = max_accel;
        total_t = t1.add(stop_t);
    } else if (diff.lower_than(stop_d)) {
        // We need to stop and go back
        const back_d = stop_d.subtract(diff);
        const turn_t = back_d.divide(max_accel).square_root();
        a1 = max_accel.negate();
        t1 = stop_t.add(turn_t);
        total_t = t1.add(turn_t);
    }
    
    const v1 = start_speed.add(t1.multiply(a1));
    const calc_time = if (dtime.higher_than(total_t)) total_t else dtime;
    var end_speed: Real = undefined;
    var moved: Real = undefined;
    if (calc_time.lower_than(t1)) {
        // first segment
        end_speed = start_speed.add(calc_time.multiply(a1));
        moved = start_speed.add(end_speed).multiply(.from_float(0.5)).multiply(calc_time);
    } else {
        // second segment
        const a2 = a1.negate();
        const v2_time = calc_time.subtract(t1);
        end_speed = v1.add(v2_time.multiply(a2));
        const v1_avg = start_speed.add(v1).multiply(.from_float(0.5));
        const v2_avg = v1.add(end_speed).multiply(.from_float(0.5));
        moved = v1_avg.multiply(t1).add(v2_avg.multiply(v2_time));
    }
    
    if (to_left) {
        speed.* = end_speed.negate();
        current.mut_subtract(moved);
    } else {
        speed.* = end_speed;
        current.mut_add(moved);
    }
}


pub fn move_smooth_to2(current: *Vec2r, speed: *Vec2r, target: Vec2r, dtime: Real, max_accel: Real) void {
    assert(dtime.higher_or_equal(.zero));
    assert(max_accel.higher_or_equal(.zero));
    u.log_start(.{"Start to move from ",current.*," to ",target," with speed ",speed.*,", dtime: ",dtime,", max_accel: ",max_accel});
    defer u.log_end(.{});
    
    const start_speed = speed.*;
    const diff = current.offset_to(target);
    u.log(.{"Diff: ",diff});
    
    var dir1 = Vec2r.create(.from_int(1), .from_int(0));
    var target1 = Real.zero;
    if (!diff.equal_exact(.zero)) {
        target1 = diff.length();
        dir1 = diff.scale_down(target1);
    }
    const dir2 = Vec2r.create(dir1.y, dir1.x.negate()); // rotated to right
    
    var speed1 = start_speed.dot_product(dir1);
    var speed2 = start_speed.dot_product(dir2);
    var move1 = Real.zero;
    var move2 = Real.zero;
    move_smooth_to(&move1, &speed1, target1, dtime, max_accel);
    move_smooth_to(&move2, &speed2, .zero, dtime, max_accel);
    
    speed.* = dir1.scale(speed1).add(dir2.scale(speed2));
    const movement = dir1.scale(move1).add(dir2.scale(move2));
    current.mut_add(movement);
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

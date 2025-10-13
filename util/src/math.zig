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

const u = @import("util");
const ui = @import("ui.zig");
const Crosap = @import("crosap.zig").Crosap;
const Draw_context = @import("crosap.zig").Draw_context;
const Update_context = @import("crosap.zig").Update_context;

/// An object in 1D has a velocity of `velocity`, but we'd like the velocity to be `target`
/// The maximum acceleration however is `accel`
/// This functions handles one frame of both changing the velocity and moving the object
/// It returns the movement of the object in this frame.
pub fn auto_velocity_update(velocity: *u.Real, target: u.Real, dtime: u.Real, accel: u.Real) u.Real {
    const start_vel = velocity.*;
    const diff = start_vel.offset_to(target);
    if (diff.equal_exact(.zero)) {
        return start_vel.multiply(dtime);
    }
    const dir = if (diff.higher_or_equal(.zero)) u.Real.from_int(1) else u.Real.from_int(-1);
    const end_time = diff.absolute().divide(accel);
    if (dtime.higher_or_equal(end_time)) {
        // We reach the target velocity in this frame, so this frame consists of two parts:
        // First the velocity moves to target, then we stay at target for `time_2`
        velocity.* = target;
        const avg_1 = u.Real.average(&.{start_vel, target}); // Average velocity in the moving part
        const time_2 = dtime.subtract(end_time);
        return avg_1.multiply(end_time).add(target.multiply(time_2));
    } else {
        // We do not reach the target in this frame, so we just change the velocity with `accel`
        velocity.* = start_vel.add(accel.multiply(dtime).multiply(dir));
        const avg = u.Real.average(&.{start_vel, velocity.*}); // The average velocity in this frame is the average of the start and end velocity
        return avg.multiply(dtime);
    }
}

/// An object in 2D has a velocity of `velocity`, but we'd like the velocity to be `target`
/// The maximum acceleration however is `accel`
/// This functions handles one frame of both changing the velocity and moving the object
/// It returns the movement of the object in this frame.
pub fn auto_velocity_update_2d(velocity: *u.Vec2r, target: u.Vec2r, dtime: u.Real, accel: u.Real) u.Vec2r {
    const start_vel = velocity.*;
    const diff = start_vel.offset_to(target);
    if (diff.equal_exact(.create(.zero, .zero))) {
        return start_vel.scale(dtime);
    }
    
    const length = diff.length();
    const dir = diff.scale_down(length);
    
    const end_time = length.divide(accel);
    if (dtime.higher_or_equal(end_time)) {
        // We reach the target velocity in this frame, so this frame consists of two parts:
        // First the velocity moves to target, then we stay at target for `time_2`
        velocity.* = target;
        const avg_1 = u.Vec2r.average(&.{start_vel, target}); // Average velocity in the moving part
        const time_2 = dtime.subtract(end_time);
        return avg_1.scale(end_time).add(target.scale(time_2));
    } else {
        // We do not reach the target in this frame, so we just change the velocity with `accel`
        velocity.* = start_vel.add(dir.scale(accel.multiply(dtime)));
        const avg = u.Vec2r.average(&.{start_vel, velocity.*}); // The average velocity in this frame is the average of the start and end velocity
        return avg.scale(dtime);
    }
}

pub const Scroll_state = struct {
    center: u.Int, // the position that is currently in the center
    auto_buildup: u.Real,
    auto_velocity: u.Real,
    
    pub fn init(state: *Scroll_state) void {
        state.center = .zero;
        state.auto_buildup = .zero;
        state.auto_velocity = .zero;
    }
    
    pub fn offset(state: *Scroll_state, size: u.Int) u.Int {
        const center_pos = size.divide(.create(2));
        return center_pos.subtract(state.center);
    }
    
    pub fn set_auto(state: *Scroll_state, velocity: u.Real) void {
        state.auto_buildup = .zero;
        state.auto_velocity = velocity;
    }
    
    pub fn end_scroll(state: *Scroll_state, velocity: u.Real, max: u.Int, size: u.Int) u.Real {
        state.within_bounds(max, size);
        const center_pos = size.divide(.create(2));
        const smallest = center_pos;
        const largest = max.subtract(size.subtract(center_pos));
        if (state.center.lower_or_equal(smallest) and velocity.lower_than(.zero)) {
            return velocity;
        } else if (state.center.higher_or_equal(largest) and velocity.higher_than(.zero)) {
            return velocity;
        } else {
            state.set_auto(velocity);
            return .zero;
        }
    }
    
    pub fn update(state: *Scroll_state, scrolled: ?u.Int, max: u.Int, size: u.Int, dtime: u.Real) ?u.Int {
        state.within_bounds(max, size);
        if (scrolled) |scroll_amount| {
            state.center.increase(scroll_amount);
            const set_to = state.center;
            state.within_bounds(max, size);
            const too_much = set_to.subtract(state.center);
            if (too_much.equal(.zero)) {
                return null;
            } else {
                return too_much;
            }
        } else {
            state.auto_buildup.increase(auto_velocity_update(&state.auto_velocity, .zero, dtime, .from_int(1024)));
            const moved = state.auto_buildup.int_round();
            state.auto_buildup.decrease(moved.to_real());
            state.center.increase(moved);
            state.within_bounds(max, size);
            return null;
        }
    }
    
    fn within_bounds(state: *Scroll_state, max: u.Int, size: u.Int) void {
        if (size.higher_than(max)) {
            state.center = max.divide(.create(2));
        } else {
            const center_pos = size.divide(.create(2));
            const smallest = center_pos;
            const largest = max.subtract(size.subtract(center_pos));
            if (state.center.lower_than(smallest)) {
                state.center = smallest;
            }
            if (state.center.higher_than(largest)) {
                state.center = largest;
            }
        }
    }
};

pub const Scroll_state_2d = struct {
    center: u.Vec2i, // The position of the child that is currently in the center of the container
    auto_buildup: u.Vec2r,
    auto_velocity: u.Vec2r,
    
    pub fn init(state: *Scroll_state_2d) void {
        state.center = .zero;
        state.auto_buildup = .zero;
        state.auto_velocity = .zero;
    }
    
    pub fn offset(state: *Scroll_state_2d, size: u.Vec2i) u.Vec2i {
        const center_pos = size.scale_down(.create(2));
        return center_pos.subtract(state.center);
    }
    
    pub fn set_auto(state: *Scroll_state_2d, velocity: u.Vec2r) void {
        state.auto_buildup = .zero;
        state.auto_velocity = velocity;
    }
    
    pub fn end_scroll(state: *Scroll_state_2d, velocity: u.Vec2r, max: u.Vec2i, size: u.Vec2i) u.Vec2r {
        state.within_bounds(max, size);
        const center_pos = size.scale_down(.create(2));
        const top_left = center_pos;
        const top = top_left.y;
        const left = top_left.x;
        const bottom_right = max.subtract(size.subtract(center_pos));
        const bottom = bottom_right.y;
        const right = bottom_right.x;
        
        var use_velocity = u.Vec2r.zero;
        const wall_left = state.center.x.lower_or_equal(left) and velocity.x.lower_than(.zero);
        const wall_right = state.center.x.higher_or_equal(right) and velocity.x.higher_than(.zero);
        if (!wall_left and !wall_right) {
            use_velocity.x = velocity.x;
        }
        const wall_top = state.center.y.lower_or_equal(top) and velocity.y.lower_than(.zero);
        const wall_bottom = state.center.y.higher_or_equal(bottom) and velocity.y.higher_than(.zero);
        if (!wall_top and !wall_bottom) {
            use_velocity.y = velocity.y;
        }
        state.set_auto(use_velocity);
        return velocity.subtract(use_velocity);
    }
    
    pub fn update(state: *Scroll_state_2d, scrolled: ?u.Vec2i, max: u.Vec2i, size: u.Vec2i, dtime: u.Real) ?u.Vec2i {
        state.within_bounds(max, size);
        if (scrolled) |scroll_amount| {
            state.center.increase(scroll_amount);
            const set_to = state.center;
            state.within_bounds(max, size);
            const too_much = set_to.subtract(state.center);
            if (too_much.equal(.zero)) {
                return null;
            } else {
                return too_much;
            }
        } else {
            state.auto_buildup.increase(auto_velocity_update_2d(&state.auto_velocity, .zero, dtime, .from_int(1024)));
            const moved = state.auto_buildup.round_to_vec2i();
            state.auto_buildup.decrease(moved.to_vec2r());
            state.center.increase(moved);
            state.within_bounds(max, size);
            return null;
        }
    }
    
    fn within_bounds(state: *Scroll_state_2d, max: u.Vec2i, size: u.Vec2i) void {
        const child_center = max.scale_down(.create(2));
        const center_pos = size.scale_down(.create(2));
        const top_left = center_pos;
        const top = top_left.y;
        const left = top_left.x;
        const bottom_right = max.subtract(size.subtract(center_pos));
        const bottom = bottom_right.y;
        const right = bottom_right.x;
        
        if (right.lower_than(left)) {
            state.center.x = child_center.x;
        } else {
            state.center.x = state.center.x.clamp(left, right);
        }
        if (bottom.lower_than(top)) {
            state.center.y = child_center.y;
        } else {
            state.center.y = state.center.y.clamp(top, bottom);
        }
    }
};


// fixed to flexible
pub const Scroll_container = struct {
    pub const get_element = ui.create_flexible_element(Scroll_container);
    child: ui.fixed_element.Dynamic_interface, // managed by user
    state: Scroll_state_2d,
    
    pub fn init(el: *Scroll_container, child: ui.fixed_element.Dynamic_interface) void {
        el.child = child;
        el.state.init();
    }
    
    pub fn deinit(el: *Scroll_container) void {
        _ = el;
    }
    
    pub fn update(el: *Scroll_container, ctx: Update_context, size: u.Vec2i) void {
        const child_size = ctx.child_fixed(el.child);
        
        const scroll = ctx.get_scroll();
        if (el.state.update(scroll, child_size, size, ctx.dtime)) |returning| {
            ctx.return_scroll(returning);
        }
        
        ctx.set_child_pos(el.child.get_element(), el.state.offset(size));
    }
    
    pub fn frame(el: *Scroll_container, draw: Draw_context) void {
        _ = el;
        _ = draw;
    }
    
    pub fn pointer_start(el: *Scroll_container, info: ui.Pointer_context) void {
        info.add_for_scrolling(el.get_element());
    }
    
    pub fn scroll_end(el: *Scroll_container, cr: *Crosap, velocity: u.Vec2r) u.Vec2r {
        const child_size = cr.get_element_size(el.child.get_element());
        const our_size = cr.get_element_size(el.get_element());
        return el.state.end_scroll(velocity, child_size, our_size);
    }
    
    pub const scroll_step = ui.element_no_scroll_step(Scroll_container);
};

// fixed to y_flex
pub const Y_scroll_fixed = struct {
    pub const get_element = ui.create_y_flex_element(Y_scroll_fixed);
    child: ui.fixed_element.Dynamic_interface, // managed by user
    state: Scroll_state,
    
    pub fn init(el: *Y_scroll_fixed, child: ui.fixed_element.Dynamic_interface) void {
        el.child = child;
        el.state.init();
    }
    
    pub fn deinit(el: *Y_scroll_fixed) void {
        _ = el;
    }
    
    pub fn update(el: *Y_scroll_fixed, ctx: Update_context, height: u.Int) u.Int {
        const child_size = ctx.child_fixed(el.child);
        
        const scroll = ctx.get_scroll();
        var returning = if (scroll) |scrolled| u.Vec2i.create(scrolled.x, .zero) else u.Vec2i.zero;
        const scrolled_y = if (scroll) |scrolled| scrolled.y else null;
        if (el.state.update(scrolled_y, child_size.y, height, ctx.dtime)) |returned| {
            returning.increase(.create(.zero, returned));
        }
        if (!returning.equal(.zero)) {
            ctx.return_scroll(returning);
        }
        
        ctx.set_child_pos(el.child.get_element(), .create(.zero, el.state.offset(height)));
        return child_size.x;
    }
    
    pub fn frame(el: *Y_scroll_fixed, draw: Draw_context) void {
        _ = el;
        _ = draw;
    }
    
    pub fn pointer_start(el: *Y_scroll_fixed, info: ui.Pointer_context) void {
        info.add_for_scrolling(el.get_element());
    }
    
    pub fn scroll_end(el: *Y_scroll_fixed, cr: *Crosap, velocity: u.Vec2r) u.Vec2r {
        const child_height = cr.get_element_size(el.child.get_element()).y;
        const our_height = cr.get_element_size(el.get_element()).y;
        return .create(
            velocity.x,
            el.state.end_scroll(velocity.y, child_height, our_height),
        );
    }
    
    pub const scroll_step = ui.element_no_scroll_step(Y_scroll_fixed);
};

// fixed to x_flex
pub const X_scroll_fixed = struct {
    pub const get_element = ui.create_x_flex_element(X_scroll_fixed);
    child: ui.fixed_element.Dynamic_interface, // managed by user
    state: Scroll_state,
    
    pub fn init(el: *X_scroll_fixed, child: ui.fixed_element.Dynamic_interface) void {
        el.child = child;
        el.state.init();
    }
    
    pub fn deinit(el: *X_scroll_fixed) void {
        _ = el;
    }
    
    pub fn update(el: *X_scroll_fixed, ctx: Update_context, width: u.Int) u.Int {
        const child_size = ctx.child_fixed(el.child);
        
        const scroll = ctx.get_scroll();
        var returning = if (scroll) |scrolled| u.Vec2i.create(.zero, scrolled.y) else u.Vec2i.zero;
        const scrolled_x = if (scroll) |scrolled| scrolled.x else null;
        if (el.state.update(scrolled_x, child_size.x, width, ctx.dtime)) |returned| {
            returning.increase(.create(returned, .zero));
        }
        if (!returning.equal(.zero)) {
            ctx.return_scroll(returning);
        }
        
        ctx.set_child_pos(el.child.get_element(), .create(el.state.offset(width), .zero));
        return child_size.y;
    }
    
    pub fn frame(el: *X_scroll_fixed, draw: Draw_context) void {
        _ = el;
        _ = draw;
    }
    
    pub fn pointer_start(el: *X_scroll_fixed, info: ui.Pointer_context) void {
        info.add_for_scrolling(el.get_element());
    }
    
    pub fn scroll_end(el: *X_scroll_fixed, cr: *Crosap, velocity: u.Vec2r) u.Vec2r {
        const child_width = cr.get_element_size(el.child.get_element()).x;
        const our_width = cr.get_element_size(el.get_element()).x;
        return .create(
            el.state.end_scroll(velocity.x, child_width, our_width),
            velocity.y,
        );
    }
    
    pub const scroll_step = ui.element_no_scroll_step(X_scroll_fixed);
};

// x_flex to flexible
pub const Y_scroll = struct {
    pub const get_element = ui.create_flexible_element(Y_scroll);
    child: ui.x_flex_element.Dynamic_interface, // managed by user
    state: Scroll_state,
    
    pub fn init(el: *Y_scroll, child: ui.x_flex_element.Dynamic_interface) void {
        el.child = child;
        el.state.init();
    }
    
    pub fn deinit(el: *Y_scroll) void {
        _ = el;
    }
    
    pub fn update(el: *Y_scroll, ctx: Update_context, size: u.Vec2i) void {
        const child_height = ctx.child_x_flex(el.child, size.x);
        
        const scroll = ctx.get_scroll();
        var returning = if (scroll) |scrolled| u.Vec2i.create(scrolled.x, .zero) else u.Vec2i.zero;
        const scrolled_y = if (scroll) |scrolled| scrolled.y else null;
        if (el.state.update(scrolled_y, child_height, size.y, ctx.dtime)) |returned| {
            returning.increase(.create(.zero, returned));
        }
        if (!returning.equal(.zero)) {
            ctx.return_scroll(returning);
        }
        
        ctx.set_child_pos(el.child.get_element(), .create(.zero, el.state.offset(size.y)));
    }
    
    pub fn frame(el: *Y_scroll, draw: Draw_context) void {
        _ = el;
        _ = draw;
    }
    
    pub fn pointer_start(el: *Y_scroll, info: ui.Pointer_context) void {
        info.add_for_scrolling(el.get_element());
    }
    
    pub fn scroll_end(el: *Y_scroll, cr: *Crosap, velocity: u.Vec2r) u.Vec2r {
        const child_height = cr.get_element_size(el.child.get_element()).y;
        const our_height = cr.get_element_size(el.get_element()).y;
        return .create(
            velocity.x,
            el.state.end_scroll(velocity.y, child_height, our_height),
        );
    }
    
    pub const scroll_step = ui.element_no_scroll_step(Y_scroll);
};

// y_flex to flexible
pub const X_scroll = struct {
    pub const get_element = ui.create_flexible_element(X_scroll);
    child: ui.y_flex_element.Dynamic_interface, // managed by user
    state: Scroll_state,
    
    pub fn init(el: *X_scroll, child: ui.y_flex_element.Dynamic_interface) void {
        el.child = child;
        el.state.init();
    }
    
    pub fn deinit(el: *X_scroll) void {
        _ = el;
    }
    
    pub fn update(el: *X_scroll, ctx: Update_context, size: u.Vec2i) void {
        const child_width = ctx.child_y_flex(el.child);
        
        const scroll = ctx.get_scroll();
        var returning = if (scroll) |scrolled| u.Vec2i.create(.zero, scrolled.y) else u.Vec2i.zero;
        const scrolled_x = if (scroll) |scrolled| scrolled.x else null;
        if (el.state.update(scrolled_x, child_width, size.x, ctx.dtime)) |returned| {
            returning.increase(.create(returned, .zero));
        }
        if (!returning.equal(.zero)) {
            ctx.return_scroll(returning);
        }
        
        ctx.set_child_pos(el.child.get_element(), .create(el.state.offset(size.x), .zero));
    }
    
    pub fn frame(el: *X_scroll, draw: Draw_context) void {
        _ = el;
        _ = draw;
    }
    
    pub fn pointer_start(el: *X_scroll, info: ui.Pointer_context) void {
        info.add_for_scrolling(el.get_element());
    }
    
    pub fn scroll_end(el: *X_scroll, cr: *Crosap, velocity: u.Vec2r) u.Vec2r {
        const child_width = cr.get_element_size(el.child.get_element()).x;
        const our_width = cr.get_element_size(el.get_element()).x;
        return .create(
            el.state.end_scroll(velocity.x, child_width, our_width),
            velocity.y,
        );
    }
    
    pub const scroll_step = ui.element_no_scroll_step(X_scroll);
};

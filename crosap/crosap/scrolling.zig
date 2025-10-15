const u = @import("util");
const ui = @import("ui.zig");
const Crosap = @import("crosap.zig").Crosap;
const Draw_context = @import("crosap.zig").Draw_context;

pub fn auto_velocity_update(velocity: *u.Real, target: u.Real, dtime: u.Real, accel: u.Real) u.Real {
    const start_vel = velocity.*;
    const diff = start_vel.offset_to(target);
    if (diff.equal_exact(.zero)) {
        return start_vel.multiply(dtime);
    }
    const dir = if (diff.higher_or_equal(.zero)) u.Real.from_int(1) else u.Real.from_int(-1);
    const end_time = diff.absolute().divide(accel);
    if (dtime.higher_or_equal(end_time)) {
        velocity.* = target;
        const avg_1 = start_vel.add(target).multiply(.from_float(0.5));
        const time_2 = dtime.subtract(end_time);
        return avg_1.multiply(end_time).add(target.multiply(time_2));
    } else {
        velocity.* = start_vel.add(accel.multiply(dtime).multiply(dir));
        const avg = start_vel.add(velocity.*).multiply(.from_float(0.5));
        return avg.multiply(dtime);
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
        if (state.center.equal(smallest) and velocity.lower_than(.zero)) {
            return velocity;
        } else if (state.center.equal(largest) and velocity.higher_than(.zero)) {
            return velocity;
        } else {
            state.set_auto(velocity);
            return .zero;
        }
    }
    
    pub fn update(state: *Scroll_state, scrolled: ?u.Int, max: u.Int, size: u.Int, dtime: u.Real) ?u.Int {
        state.within_bounds(max, size);
        if (scrolled) |scroll_amount| {
            state.center.mut_add(scroll_amount);
            const set_to = state.center;
            state.within_bounds(max, size);
            const too_much = set_to.subtract(state.center);
            if (too_much.equal(.zero)) {
                return null;
            } else {
                return too_much;
            }
        } else {
            state.auto_buildup.mut_add(auto_velocity_update(&state.auto_velocity, .zero, dtime, .from_int(1024)));
            const moved = state.auto_buildup.int_round();
            state.auto_buildup.mut_subtract(moved.to_real());
            state.center.mut_add(moved);
            state.within_bounds(max, size);
            return null;
        }
    }
    
    fn within_bounds(state: *Scroll_state, max: u.Int, size: u.Int) void {
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
};

pub const Scroll_state_2d = struct {
    offset: u.Vec2i,
    auto_buildup: u.Vec2r,
    auto_velocity: u.Vec2r,
    
    
};


// fixed to flexible
pub const Scroll_container = struct {
    
};

// fixed to y_flex
pub const Y_scroll_fixed = struct {
    
};

// fixed to x_flex
pub const X_scroll_fixed = struct {
    
};

// x_flex to flexible
pub const Y_scroll = struct {
    pub const get_element = ui.create_flexible_element(Y_scroll);
    child: ui.x_flex_element.Dynamic_interface, // managed by user
    state: Scroll_state,
    height: u.Int, // our height
    child_height: u.Int,
    width: u.Int, // both the with of us and the child
    
    pub fn init(el: *Y_scroll, child: ui.x_flex_element.Dynamic_interface) void {
        el.child = child;
        el.state.init();
        el.height = .zero;
    }
    
    pub fn deinit(el: *Y_scroll) void {
        _ = el;
    }
    
    pub fn update(el: *Y_scroll, cr: *Crosap, dtime: u.Real, size: u.Vec2i) void {
        el.width = size.x;
        el.height = size.y;
        el.child.update(cr, dtime, size.x);
        el.child_height = el.child.get_height(cr);
        
        const scroll = cr.get_scroll(el.get_element());
        var returning = if (scroll) |scrolled| u.Vec2i.create(scrolled.x, .zero) else u.Vec2i.zero;
        const scrolled_y = if (scroll) |scrolled| scrolled.y else null;
        if (el.state.update(scrolled_y, el.child_height, el.height, dtime)) |returned| {
            returning.mut_add(.create(.zero, returned));
        }
        if (!returning.equal(.zero)) {
            cr.return_scroll(el.get_element(), returning);
        }
    }
    
    pub fn frame(el: *Y_scroll, draw: Draw_context) void {
        const child_offset = el.state.offset(el.height);
        const child_el = el.child.get_element();
        child_el.frame(draw.sub(
            .create(
                .create(.zero, child_offset),
                .create(draw.size().x, el.child_height),
            ),
            .create(.zero, draw.size()),
        ));
    }
    
    pub fn pointer_start(el: *Y_scroll, info: ui.Pointer_context) void {
        const child_el = el.child.get_element();
        const child_offset = el.state.offset(el.height);
        if (info.sub(.create(
            .create(.zero, child_offset),
            .create(el.width, el.child_height),
        ))) |child_info| {
            child_el.pointer_start(child_info);
        }
        info.add_for_scrolling(ui.element.dynamic(el));
    }
    
    pub fn scroll_end(el: *Y_scroll, cr: *Crosap, velocity: u.Vec2r) u.Vec2r {
        _ = cr;
        return .create(
            velocity.x,
            el.state.end_scroll(velocity.y, el.child_height, el.height),
        );
    }
    
    pub const scroll_step = ui.element_no_scroll_step(Y_scroll);
};

// y_flex to flexible
pub const X_scroll = struct {
    
};

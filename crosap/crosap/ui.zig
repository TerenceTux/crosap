const std = @import("std");
const u = @import("util");
const Draw_context = @import("draw.zig").Draw_context;
const Crosap = @import("crosap.zig").Crosap;

pub const element = u.interface(struct {
    deinit: fn(cr: *Crosap) void,
    // when this is called, the position is known, so you can get the scroll offset
    frame: fn(draw: Draw_context) void,
    pointer_start: fn(info: *Pointer_context) void,
    scroll_end: fn(cr: *Crosap, velocity: u.Vec2r) void,
    scroll_step: fn(cr: *Crosap, steps: u.Int) ?u.Int, // null means this element does not benefit from discrete scrolling, then a normal scroll event is simulated.
    
    pub fn Interface(Imp: type) type {
        return struct {
            const Selfp = *const @This();
            imp: Imp,
            
            pub fn deinit(s: Selfp, cr: *Crosap) void {
                s.imp.call(.deinit, .{cr});
            }
            
            pub fn frame(s: Selfp, draw: Draw_context) void {
                s.imp.call(.frame, .{draw});
            }
            
            pub fn pointer_start(s: Selfp, info: *Pointer_context) void {
                s.imp.call(.pointer_start, .{info});
            }
            
            pub fn scroll_end(s: Selfp, cr: *Crosap, velocity: u.Vec2r) void {
                s.imp.call(.scroll_end, .{cr, velocity});
            }
            
            pub fn scroll_step(s: Selfp, cr: *Crosap, steps: u.Int) ?u.Int {
                return s.imp.call(.scroll_step, .{cr, steps});
            }
        };
    }
});

pub const Pointer_context = struct {
    cr: *Crosap,
    pos: u.Vec2i,
    element_chain: u.List(Dynamic_element),
    click_handler: ?click_handler.Dynamic_interface,
};

pub const Dynamic_element = struct {
    element: *anyopaque,
    vtable: *anyopaque,
    
    pub fn from_element(el: element.Dynamic_interface) Dynamic_element {
        return .{
            .element = el.imp.imp,
            .vtable = el.imp.fns,
        };
    }
    
    pub fn to_element(dyn_el: Dynamic_element) element.Dynamic_interface {
        return .{
            .imp = .{
                .imp = dyn_el.element,
                .fns = dyn_el.vtable,
            },
        };
    }
};

pub const flexible_element = u.interface(struct {
    get_element: fn() element.Dynamic_interface,
    update: fn(cr: *Crosap, dtime: u.Real, size: u.Vec2i) void,
    
    pub fn Interface(Imp: type) type {
        return struct {
            const Selfp = *const @This();
            imp: Imp,
            
            pub fn get_element(s: Selfp) element.Dynamic_interface {
                return s.imp.call(.get_element, .{});
            }
            
            pub fn update(s: Selfp, cr: *Crosap, dtime: u.Real, size: u.Vec2i) void {
                s.imp.call(.update, .{cr, dtime, size});
            }
        };
    }
});

pub const x_flex_element = u.interface(struct {
    get_element: fn() element.Dynamic_interface,
    update: fn(cr: *Crosap, dtime: u.Real, width: u.Int) void,
    get_height: fn(cr: *Crosap) u.Int,
    
    pub fn Interface(Imp: type) type {
        return struct {
            const Selfp = *const @This();
            imp: Imp,
            
            pub fn get_element(s: Selfp) element.Dynamic_interface {
                return s.imp.call(.get_element, .{});
            }
            
            pub fn update(s: Selfp, cr: *Crosap, dtime: u.Real, width: u.Int) void {
                s.imp.call(.update, .{cr, dtime, width});
            }
            
            pub fn get_height(s: Selfp, cr: *Crosap) u.Int {
                return s.imp.call(.get_height, .{cr});
            }
        };
    }
});

pub const y_flex_element = u.interface(struct {
    get_element: fn() element.Dynamic_interface,
    update: fn(cr: *Crosap, dtime: u.Real, height: u.Int) void,
    get_width: fn(cr: *Crosap) u.Int,
    
    pub fn Interface(Imp: type) type {
        return struct {
            const Selfp = *const @This();
            imp: Imp,
            
            pub fn get_element(s: Selfp) element.Dynamic_interface {
                return s.imp.call(.get_element, .{});
            }
            
            pub fn update(s: Selfp, cr: *Crosap, dtime: u.Real, height: u.Int) void {
                s.imp.call(.update, .{cr, dtime, height});
            }
            
            pub fn get_width(s: Selfp, cr: *Crosap) u.Int {
                return s.imp.call(.get_width, .{cr});
            }
        };
    }
});

pub const fixed_element = u.interface(struct {
    get_element: fn() element.Dynamic_interface,
    update: fn(cr: *Crosap, dtime: u.Real) void,
    get_size: fn(cr: *Crosap) u.Vec2i,
    
    pub fn Interface(Imp: type) type {
        return struct {
            const Selfp = *const @This();
            imp: Imp,
            
            pub fn get_element(s: Selfp) element.Dynamic_interface {
                return s.imp.call(.get_element, .{});
            }
            
            pub fn update(s: Selfp, cr: *Crosap, dtime: u.Real) void {
                s.imp.call(.update, .{cr, dtime});
            }
            
            pub fn get_size(s: Selfp, cr: *Crosap) u.Vec2i {
                return s.imp.call(.get_size, .{cr});
            }
        };
    }
});

pub const click_handler = u.interface(struct {
    // Exactly one of these functions will be called
    normal: fn() void,
    long: fn() void,
    cancel: fn() void,
    
    pub fn Interface(Imp: type) type {
        return struct {
            const Selfp = *const @This();
            imp: Imp,
        };
    }
});

pub fn create_flexible_element(Element: type) fn(el: *Element) element.Dynamic_interface {
    return struct {
        pub fn f(el: *Element) element.Dynamic_interface {
            return element.dynamic(el);
        }
    }.f;
}


pub const Plain_color = struct { // flexible_element
    pub const get_element = create_flexible_element(Plain_color);
    color: u.Screen_color,
    
    pub fn init(el: *Plain_color, color: u.Color) void {
        el.color = color.to_screen_color();
    }
    
    pub fn deinit(el: *Plain_color) void {
        _ = el;
    }
    
    pub fn update(el: *Plain_color) void {
        _ = el;
    }
    
    pub fn frame(el: *Plain_color, draw: Draw_context) void {
        draw.rect(draw.area, el.color);
    }
    
    pub fn pointer_start(el: *Plain_color, info: *Pointer_context) void {
        _ = el;
        _ = info;
    }
    
    pub fn scroll_end(el: *Plain_color, cr: *Crosap, velocity: u.Vec2r) void {
        _ = el;
        _ = cr;
        _ = velocity;
    }
    
    pub fn scroll_step(el: *Plain_color, cr: *Crosap, steps: u.Int) ?u.Int {
        _ = el;
        _ = cr;
        _ = steps;
        return null;
    }
};

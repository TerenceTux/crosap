const u = @import("util");
const ui = @import("ui.zig");
const Crosap = @import("crosap.zig").Crosap;
const Draw_context = @import("crosap.zig").Draw_context;
const Update_context = @import("crosap.zig").Update_context;

/// stack multiple y_flex horizontally
pub const X_stack = struct {
    pub const get_element = ui.create_y_flex_element(X_stack);
    items: u.List(ui.y_flex_element.Dynamic_interface), // We free the list, but the user can add/remove items and manages the elements
    
    pub fn init(el: *X_stack, items: []const ui.y_flex_element.Dynamic_interface) void {
        el.items.init_copy_slice(items);
    }
    
    pub fn init_empty(el: *X_stack) void {
        el.init(&.{});
    }
    
    pub fn deinit(el: *X_stack) void {
        el.items.deinit();
    }
    
    pub fn update(el: *X_stack, ctx: Update_context, height: u.Int) u.Int {
        var x: u.Int = .zero;
        for (el.items.items()) |item| {
            const width = ctx.child_y_flex_at(item, height, .create(x, .zero));
            x.increase(width);
        }
        return x;
    }
    
    pub fn frame(el: *X_stack, draw: Draw_context) void {
        _ = el;
        _ = draw;
    }
    
    pub fn pointer_start(el: *X_stack, info: ui.Pointer_context) void {
        _ = el;
        _ = info;
    }
    
    pub const scroll_end = ui.element_no_scroll_end(X_stack);
    pub const scroll_step = ui.element_no_scroll_step(X_stack);
};


/// stack multiple x_flex vertically
pub const Y_stack = struct {
    pub const get_element = ui.create_x_flex_element(Y_stack);
    items: u.List(ui.x_flex_element.Dynamic_interface), // We free the list, but the user can add/remove items and manages the elements
    
    pub fn init(el: *Y_stack, items: []const ui.x_flex_element.Dynamic_interface) void {
        el.items.init_copy_slice(items);
    }
    
    pub fn init_empty(el: *Y_stack) void {
        el.init(&.{});
    }
    
    pub fn deinit(el: *Y_stack) void {
        el.items.deinit();
    }
    
    pub fn update(el: *Y_stack, ctx: Update_context, width: u.Int) u.Int {
        var y: u.Int = .zero;
        for (el.items.items()) |item| {
            const height = ctx.child_x_flex_at(item, width, .create(.zero, y));
            y.increase(height);
        }
        return y;
    }
    
    pub fn frame(el: *Y_stack, draw: Draw_context) void {
        _ = el;
        _ = draw;
    }
    
    pub fn pointer_start(el: *Y_stack, info: ui.Pointer_context) void {
        _ = el;
        _ = info;
    }
    
    pub const scroll_end = ui.element_no_scroll_end(Y_stack);
    pub const scroll_step = ui.element_no_scroll_step(Y_stack);
};

const u = @import("util");
const Crosap = @import("crosap.zig").Crosap;
const ui = @import("ui.zig");
const Button_type = @import("crosap.zig").Button_type;

pub const activity = u.interface(struct {
    deinit: fn(cr: *Crosap) void,
    free: fn() void,
    root_element: fn(cr: *Crosap) ui.flexible_element.Dynamic_interface,
    export_data: fn(cr: *Crosap, writer: u.serialize.bit_writer.Dynamic_interface) void,
    update: fn(cr: *Crosap, dtime: u.Real) Keyboard_info, // root_element.update will also be called after this, so don't do that yourself
    key_input: fn(cr: *Crosap, key: Button_type, event: Key_event) void,
    
    pub fn Interface(Imp: type) type {
        return struct {
            const Selfp = *const @This();
            imp: Imp,
            
            pub fn deinit(s: Selfp, cr: *Crosap) void {
                return s.imp.call(.deinit, .{cr});
            }
            
            pub fn free(s: Selfp) void {
                return s.imp.call(.free, .{});
            }
            
            pub fn root_element(s: Selfp, cr: *Crosap) ui.flexible_element.Dynamic_interface {
                return s.imp.call(.root_element, .{cr});
            }
            
            pub fn export_data(s: Selfp, cr: *Crosap, writer: u.serialize.bit_writer.Dynamic_interface) void {
                s.imp.call(.export_data, .{cr, writer});
            }
            
            pub fn update(s: Selfp, cr: *Crosap, dtime: u.Real) void {
                return s.imp.call(.update, .{cr, dtime});
            }
            
            pub fn key_input(s: Selfp, cr: *Crosap, key: Button_type, event: Key_event) void {
                s.imp.call(.key_input, .{cr, key, event});
            }
        };
    }
});

pub const Key_event = enum {
    press,
    release,
    repeat,
};

pub const Keyboard_info = enum {
    keyboard_not_needed,
    keyboard_needed,
};

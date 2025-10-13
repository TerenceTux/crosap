const builtin = @import("builtin");
const std = @import("std");
const u = @import("util");
const Switching_backend = @import("switching_backend.zig").Backend;
const Draw_frame = @import("backend").Draw_frame;
const draw = @import("draw.zig");

const crosap_api = @import("crosap_api");
pub const Key = crosap_api.Key;
pub const Pointer = crosap_api.Pointer;
pub const ui = @import("ui.zig");
pub const Draw_context = draw.Draw_context;
pub const Create_imagemap = draw.Create_imagemap;

pub const activity = @import("activity.zig").activity;
pub const Key_event = @import("activity.zig").Key_event;
pub const Keyboard_info = @import("activity.zig").Keyboard_info;

const Dynamic_element = ui.element.Dynamic_interface;

pub const Crosap = struct {
    backend: Switching_backend,
    general: draw.General_map,
    scale: u.Int,
    should_close: bool,
    keyboard_state: std.EnumArray(Key, bool),
    to_scroll: u.Map(Dynamic_element, To_scroll_info),
    
    const To_scroll_info = struct {
        amount: u.Vec2i,
        otherwise: ?Dynamic_element,
    };
    
    pub fn init(cr: *Crosap) void {
        cr.should_close = false;
        cr.scale = .create(4);
        cr.keyboard_state = .initFill(false);
        cr.to_scroll.init_with_capacity(32);
        cr.backend.init();
        
        cr.init_imagemap(&cr.general, draw.General_map.Drawer {});
    }
    
    pub fn deinit(cr: *Crosap) void {
        cr.deinit_imagemap(&cr.general);
        
        cr.backend.deinit();
        cr.to_scroll.deinit();
    }
    
    pub fn new_frame(cr: *Crosap, dtime: u.Real) ?Draw_context {
        cr.update_imagemap(&cr.general);
        if (cr.backend.new_frame()) |frame_size| {
            return .{
                .area = .create(.zero, frame_size),
                .mask = .create(.zero, frame_size),
                .cr = cr,
                .dtime = dtime,
            };
        } else {
            return null;
        }
    }
    
    pub fn end_frame(cr: *Crosap) void {
        cr.backend.end_frame();
    }
    
    pub fn create_texture_image(cr: *Crosap, size: u.Vec2i) draw.Texture_image {
        const backend_image = cr.backend.create_texture(size);
        return .{
            .image = backend_image,
            .backend = cr.backend,
            .size = size,
        };
    }
    
    pub fn init_imagemap(cr: *Crosap, map: anytype, drawer: anytype) void {
        const Image_map = @typeInfo(@TypeOf(map)).pointer.child;
        u.log_start("Creating image map "++Image_map.name);
        const needed_size = Image_map.needed_size(cr.scale);
        u.log(.{"Needed size: ",needed_size});
        const texture = cr.create_texture_image(needed_size);
        map.init(drawer, texture, cr.scale);
        u.log_end({});
    }
    
    pub fn update_imagemap(cr: *Crosap, map: anytype) void {
        const Image_map = @typeInfo(@TypeOf(map)).pointer.child;
        if (!cr.scale.equal(map.scale)) {
            u.log_start(.{"Image map "++Image_map.name++" had scale ",map.scale," but we now use scale ",cr.scale});
            map.texture.deinit();
            const needed_size = Image_map.needed_size(cr.scale);
            u.log(.{"Needed size: ",needed_size});
            const texture = cr.create_texture_image(needed_size);
            map.texture = texture;
            map.scale = cr.scale;
            map.redraw_all();
            u.log_end(.{});
        }
    }
    
    pub fn deinit_imagemap(cr: *Crosap, map: anytype) void {
        _ = cr;
        map.texture.deinit();
    }
    
    pub fn deinit_element(cr: *Crosap, element: anytype) void {
        const general_element = ui.element.dynamic(element);
        // remove it from our administration
        general_element.deinit(cr);
    }
    
    pub fn key_is_pressed(cr: *Crosap, key: Key) bool {
        return cr.keyboard_state.get(key);
    }
    
    pub fn get_scroll(cr: *Crosap, element: Dynamic_element) ?u.Vec2i {
        if (cr.to_scroll.get_ptr(element)) |scroll_info| {
            return scroll_info.amount;
        } else {
            return null;
        }
    }
    
    // only call if `get_scroll` did not return null
    pub fn return_scroll(cr: *Crosap, element: Dynamic_element, amount: u.Vec2i) void {
        const scroll_info = cr.to_scroll.get_ptr(element).?;
        if (scroll_info.otherwise) |to_el| {
            const to_scroll_info = cr.to_scroll.get_ptr(to_el).?;
            to_scroll_info.amount.mut_add(amount);
        }
    }
    
    pub fn pixel_to_position(cr: *Crosap, pixel: u.Vec2r) u.Vec2i {
        const exact = cr.pixel_to_position_exact(pixel);
        return .create(
            exact.x.int_floor(),
            exact.y.int_floor(),
        );
    }
    
    pub fn pixel_to_position_exact(cr: *Crosap, pixel: u.Vec2r) u.Vec2r {
        return .create(
            pixel.x.divide(cr.scale.to_real()),
            pixel.y.divide(cr.scale.to_real()),
        );
    }
    
    pub fn position_to_pixel(cr: *Crosap, pos: u.Vec2i) u.Vec2i {
        return pos.scale(cr.scale);
    }
};

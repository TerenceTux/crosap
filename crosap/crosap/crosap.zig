const builtin = @import("builtin");
const std = @import("std");
const u = @import("util");
const Switching_backend = @import("switching_backend.zig").Backend;
const Draw_frame = @import("backend").Draw_frame;
const draw = @import("draw.zig");

pub const Draw_context = draw.Draw_context;
pub const Create_imagemap = draw.Create_imagemap;

pub const Crosap = struct {
    backend: Switching_backend,
    general: draw.General_map,
    scale: u.Int,
    should_close: bool,
    
    pub fn init(cr: *Crosap) void {
        u.log("Welcome to crosap.");
        switch (builtin.mode) {
            .Debug => u.log("Running in DEBUG mode. Performance will be bad!"),
            .ReleaseSafe => std.debug.print("WARNING: running in ReleaseSafe mode, which can have lower performance, because a lot of runtime checks are enabled. Consider using ReleaseFast.", .{}),
            .ReleaseFast => {},
            .ReleaseSmall => std.debug.print("WARNING: running in ReleaseSmall mode, which can have lower performance, because not all performance optimizations are applied. Consider using ReleaseFast.", .{}),
        }
        
        u.log(.{"Built for ",@tagName(builtin.cpu.arch)," (", @sizeOf(usize)*8, " bit ",builtin.cpu.arch.endian()," endian)"});
        cr.should_close = false;
        cr.scale = .create(4);
        cr.backend.init();
        
        cr.init_imagemap(&cr.general, draw.General_map.Drawer {.some_members = .zero});
    }
    
    pub fn deinit(cr: *Crosap) void {
        cr.deinit_imagemap(&cr.general);
        
        cr.backend.deinit();
    }
    
    pub fn new_frame(cr: *Crosap) ?Draw_context {
        cr.update_imagemap(&cr.general);
        if (cr.backend.new_frame()) |frame_size| {
            return .{
                .area = .create(.zero, frame_size),
                .mask = .create(.zero, frame_size),
                .cr = cr,
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
};

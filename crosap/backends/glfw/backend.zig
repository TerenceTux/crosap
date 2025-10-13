const u = @import("util");
const lib_glfw = @import("glfw");
const crosap_api = @import("crosap_api");
const Event = crosap_api.Event;
const Pointer = crosap_api.Pointer;
const Key = crosap_api.Key;
const render_vulkan = @import("render_vulkan");

const Backend_event = union(enum) {
    key_update: struct {
        key: Key,
        state: bool
    },
    mouse_start: Pointer,
    mouse_end,
    mouse_move: u.Vec2r,
    mouse_button_left: bool,
    mouse_button_right: bool,
    mouse_button_middle: bool,
    mouse_scroll: u.Vec2r,
    quit,
};

pub const Render_type = enum {
    vulkan,
    //opengl,
    //cpu,
};

pub fn Backend(render_type: Render_type) type {
    const Render_data = switch (render_type) {
        .vulkan => render_vulkan.Render,
    };
    const Texture = switch (render_type) {
        .vulkan => render_vulkan.Texture,
    };
    return struct {
        const This = @This();
        render: Render_data,
        
        events: u.Queue(Backend_event),
        glfw: lib_glfw.Loader,
        window: lib_glfw.Window,
        
        mouse_in_window: bool,
        mouse_active: bool,
        mouse: Pointer, // undefined on !mouse_active
        mouse_button_left: bool,
        mouse_button_right: bool,
        mouse_button_middle: bool,
        
        key_callback: Key_callback,
        mouse_button_callback: Mouse_button_callback,
        cursor_move_callback: Cursor_move_callback,
        cursor_enter_callback: Cursor_enter_callback,
        scroll_callback: Scroll_callback,
        
        const Key_callback = struct {
            b: *This,
            
            pub fn call(context: *Key_callback, key: c_int, action: lib_glfw.types.Key_action, mods: c_int) void {
                u.log(.{"GLFW key callback, key: ",key,", action: ",action,", mods: ",mods});
                
                if (glfw_keycode_to_key(key)) |button| {
                    if (action == .press) {
                        context.b.events.add_end(.{
                            .key_update = .{
                                .key = button,
                                .state = true,
                            },
                        });
                    } else if (action == .release) {
                        context.b.events.add_end(.{
                            .key_update = .{
                                .key = button,
                                .state = false,
                            },
                        });
                    }
                } else {
                    u.log(.{"Unsupported key"});
                }
                
            }
        };
        
        const Mouse_button_callback = struct {
            b: *This,
            
            pub fn call(context: *Mouse_button_callback, button: c_int, action: lib_glfw.types.Key_action, mods: c_int) void {
                u.log(.{"GLFW button callback, button: ",button,", action: ",action,", mods: ",mods});
                const b = context.b;
                const state = switch (action) {
                    .press => true,
                    .release => false,
                    else => return,
                };
                if (b.mouse_active) {
                    var event: Backend_event = undefined;
                    switch (button) {
                        0 => {
                            b.mouse_button_left = state;
                            event = .{
                                .mouse_button_left = state,
                            };
                        },
                        1 => {
                            b.mouse_button_right = state;
                            event = .{
                                .mouse_button_right = state,
                            };
                        },
                        2 => {
                            b.mouse_button_middle = state;
                            event = .{
                                .mouse_button_middle = state,
                            };
                        },
                        else => {
                            u.log(.{"Unsupported button"});
                            return;
                        },
                    }
                    b.events.add_end(event);
                    if (!b.mouse_in_window) {
                        if (!u.any(&.{
                            b.mouse_button_left,
                            b.mouse_button_right,
                            b.mouse_button_middle,
                        })) {
                            b.events.add_end(.{
                                .mouse_end = {},
                            });
                            b.mouse_active = false;
                        }
                    }
                }
            }
        };
        
        const Cursor_move_callback = struct {
            b: *This,
            
            pub fn call(context: *Cursor_move_callback, x_pos: f64, y_pos: f64) void {
                u.log(.{"GLFW cursor move callback, x_pos: ",x_pos,", y_pos: ",y_pos});
                if (context.b.mouse_active) {
                    context.b.events.add_end(.{
                        .mouse_move = .create(.from_float(x_pos), .from_float(y_pos)),
                    });
                } else if (context.b.mouse_in_window) {
                    context.b.mouse_active = true;
                    context.b.events.add_end(.{
                        .mouse_start = .{
                            .position = .create(.from_float(x_pos), .from_float(y_pos)),
                            .button_left = false,
                            .button_right = false,
                            .button_middle = false,
                        },
                    });
                }
                
            }
        };
        
        const Cursor_enter_callback = struct {
            b: *This,
            
            pub fn call(context: *Cursor_enter_callback, entered: bool) void {
                const b = context.b;
                b.mouse_in_window = entered;
                if (entered) {
                    u.log(.{"GLFW cursor entered window callback"});
                } else {
                    u.log(.{"GLFW cursor leaved window callback"});
                    if (b.mouse_active and !u.any(&.{
                        b.mouse_button_left,
                        b.mouse_button_right,
                        b.mouse_button_middle,
                    })) {
                        b.events.add_end(.mouse_end);
                        b.mouse_active = false;
                    }
                }
            }
        };
        
        const Scroll_callback = struct {
            b: *This,
            
            pub fn call(context: *Scroll_callback, x_offset: f64, y_offset: f64) void {
                u.log(.{"GLFW scroll callback, x_offset: ",x_offset,", y_offset: ",y_offset});
                if (context.b.mouse_active) {
                    context.b.events.add_end(.{
                        .mouse_scroll = .create(.from_float(x_offset), .from_float(y_offset)),
                    });
                }
            }
        };
        
        pub fn init(b: *This) !void {
            b.mouse_active = false;
            b.mouse_in_window = false;
            b.events.init();
            b.key_callback = .{.b = b};
            b.mouse_button_callback = .{.b = b};
            b.cursor_move_callback = .{.b = b};
            b.cursor_enter_callback = .{.b = b};
            b.scroll_callback = .{.b = b};
            
            try b.glfw.init();
            if (!b.glfw.vulkan_supported()) {
                @panic("Glfw reports vulkan not supported");
            }
            
            switch (render_type) {
                .vulkan => {
                    const required_extensions = try b.glfw.required_vulkan_extensions();
                    defer u.alloc.free(required_extensions);
                    try b.render.init_without_surface(required_extensions);
                },
            }
            
            u.log_start("Create glfw window");
            defer u.log_end({});
            
            try b.glfw.set_window_hint(.maximized, lib_glfw.types.window_hint_value.v_true);
            try b.glfw.set_window_hint(.depth_bits, 0);
            try b.glfw.set_window_hint(.stencil_bits, 0);
            try b.glfw.set_window_hint(.alpha_bits, 0);
            switch (render_type) {
                .vulkan => {
                    try b.glfw.set_window_hint(.client_api, lib_glfw.types.window_hint_value.no_api);
                },
            }
            
            u.log("Window");
            try b.glfw.create_window(&b.window, 800, 600, "window");
            b.window.key_callback = lib_glfw.Window.Key_callback.dynamic(&b.key_callback);
            b.window.mouse_button_callback = lib_glfw.Window.Mouse_button_callback.dynamic(&b.mouse_button_callback);
            b.window.cursor_move_callback = lib_glfw.Window.Cursor_move_callback.dynamic(&b.cursor_move_callback);
            b.window.cursor_enter_callback = lib_glfw.Window.Cursor_enter_callback.dynamic(&b.cursor_enter_callback);
            b.window.scroll_callback = lib_glfw.Window.Scroll_callback.dynamic(&b.scroll_callback);
            
            u.log("Surface");
            switch (render_type) {
                .vulkan => {
                    const vulkan_surface = try b.window.create_vulkan_surface(b.render.instance.instance);
                    try b.render.set_surface(vulkan_surface);
                },
            }
        }
        
        pub fn deinit(b: *This) void {
            b.render.deinit();
            b.window.deinit();
            b.glfw.deinit();
            b.events.deinit();
        }
        
        pub fn create_texture(b: *This, size: u.Vec2i) !*anyopaque {
            return try b.render.create_texture(size);
        }
        
        pub fn destroy_texture(b: *This, texture_opaque: *anyopaque) void {
            const texture: *Texture = @alignCast(@ptrCast(texture_opaque));
            b.render.destroy_texture(texture);
        }
        
        pub fn update_texture(b: *This, texture_opaque: *anyopaque, rect: u.Rect2i, data: []const u.Screen_color) !void {
            const texture: *Texture = @alignCast(@ptrCast(texture_opaque));
            try b.render.update_texture(texture, rect, data);
        }
        
        pub fn new_frame(b: *This) !?u.Vec2i {
            const window_size = try b.window.get_framebuffer_size();
            return try b.render.new_frame(.create(.create(window_size[0]), .create(window_size[1])));
        }
        
        pub fn draw_object(b: *This, rect: u.Rect2i, color: u.Screen_color, texture_opaque: *anyopaque, texture_rect: u.Rect2i, texture_offset: u.Vec2i) !void {
            const texture: *Texture = @alignCast(@ptrCast(texture_opaque));
            try b.render.draw_object(rect, color, texture, texture_rect, texture_offset);
        }
        
        pub fn end_frame(b: *This) !void {
            try b.render.end_frame();
        }
        
        pub fn poll_events(b: *This) !void {
            try b.glfw.poll_events();
            if (b.window.should_close()) {
                b.events.add_end(.{
                    .quit = {},
                });
            }
        }
        
        pub fn get_event(b: *This) !?Event {
            if (b.events.pop_start()) |b_event| {
                switch (b_event) {
                    .key_update => |key_info| {
                        return Event {
                            .key_update = .{
                                .key = key_info.key,
                                .state = key_info.state,
                            },
                        };
                    },
                    .mouse_start => |pointer_state| {
                        b.mouse = pointer_state;
                        return Event {
                            .pointer_start = .{
                                .pointer = &b.mouse,
                            },
                        };
                    },
                    .mouse_end => {
                        return Event {
                            .pointer_stop = .{
                                .pointer = &b.mouse,
                            },
                        };
                    },
                    .mouse_move => |pos| {
                        b.mouse.position = pos;
                        return Event {
                            .pointer_update = .{
                                .pointer = &b.mouse,
                            },
                        };
                    },
                    .mouse_button_left => |state| {
                        b.mouse.button_left = state;
                        return Event {
                            .pointer_update = .{
                                .pointer = &b.mouse,
                            },
                        };
                    },
                    .mouse_button_right => |state| {
                        b.mouse.button_right = state;
                        return Event {
                            .pointer_update = .{
                                .pointer = &b.mouse,
                            },
                        };
                    },
                    .mouse_button_middle => |state| {
                        b.mouse.button_middle = state;
                        return Event {
                            .pointer_update = .{
                                .pointer = &b.mouse,
                            },
                        };
                    },
                    .mouse_scroll => |offset| {
                        return Event {
                            .pointer_scroll = .{
                                .pointer = &b.mouse,
                                .offset = offset,
                            },
                        };
                    },
                    .quit => {
                        return Event {
                            .quit = .{},
                        };
                    },
                }
            } else {
                return null;
            }
            return b.events.pop_start();
        }
    };
}

fn glfw_keycode_to_key(keycode: c_int) ?Key {
    // https://www.glfw.org/docs/3.3/group__keys.html
    return switch (keycode) {
        32 => .space,
        39 => .apostrophe,
        44 => .comma,
        45 => .minus,
        46 => .dot,
        47 => .slash,
        48 => .num_0,
        49 => .num_1,
        50 => .num_2,
        51 => .num_3,
        52 => .num_4,
        53 => .num_5,
        54 => .num_6,
        55 => .num_7,
        56 => .num_8,
        57 => .num_9,
        59 => .semicolon,
        61 => .equals,
        65 => .a,
        66 => .b,
        67 => .c,
        68 => .d,
        69 => .e,
        70 => .f,
        71 => .g,
        72 => .h,
        73 => .i,
        74 => .j,
        75 => .k,
        76 => .l,
        77 => .m,
        78 => .n,
        79 => .o,
        80 => .p,
        81 => .q,
        82 => .r,
        83 => .s,
        84 => .t,
        85 => .u,
        86 => .v,
        87 => .w,
        88 => .x,
        89 => .y,
        90 => .z,
        91 => .square_bracket_open,
        92 => .backslash,
        93 => .square_bracket_close,
        96 => .tick,
        256 => .escape,
        257 => .enter,
        258 => .tab,
        259 => .backspace,
        260 => .insert,
        261 => .delete,
        262 => .arrow_right,
        263 => .arrow_left,
        264 => .arrow_down,
        265 => .arrow_up,
        266 => .page_up,
        267 => .page_down,
        268 => .home,
        269 => .end,
        290 => .f1,
        291 => .f2,
        292 => .f3,
        293 => .f4,
        294 => .f5,
        295 => .f6,
        296 => .f7,
        297 => .f8,
        298 => .f9,
        299 => .f10,
        300 => .f11,
        301 => .f12,
        340 => .left_shift,
        341 => .left_control,
        342 => .left_alt,
        343 => .super,
        344 => .right_shift,
        345 => .right_control,
        346 => .right_alt,
        else => null,
    };
}

const u = @import("util");
const lib_glfw = @import("glfw");
const crosap_api = @import("crosap_api");
const Event = crosap_api.Event;
const Pointer = crosap_api.Pointer;
const Button_type = crosap_api.Button_type;
const Button_state = crosap_api.Button_state;
const render_vulkan = @import("render_vulkan");

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
        
        events: u.Queue(Event),
        glfw: lib_glfw.Loader,
        window: lib_glfw.Window,
        
        mouse_in_window: bool,
        mouse_active: bool,
        mouse: Pointer, // undefined on !mouse_active
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
                            .button_update = .{
                                .button = button,
                                .state = .down,
                            },
                        });
                    } else if (action == .release) {
                        context.b.events.add_end(.{
                            .button_update = .{
                                .button = button,
                                .state = .up,
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
                const state: Button_state = switch (action) {
                    .press => .down,
                    .release => .up,
                    else => return,
                };
                if (context.b.mouse_active) {
                    const mouse = &context.b.mouse;
                    switch (button) {
                        1 => mouse.button_left = state,
                        2 => mouse.button_right = state,
                        3 => mouse.button_middle = state,
                        else => {
                            u.log(.{"Unsupported button"});
                            return;
                        },
                    }
                    context.b.events.add_end(.{
                        .pointer_update = .{
                            .pointer = mouse,
                        },
                    });
                    if (!context.b.mouse_in_window) {
                        if (!u.any(&.{
                            mouse.button_left.is_pressed(),
                                   mouse.button_right.is_pressed(),
                                   mouse.button_middle.is_pressed(),
                        })) {
                            context.b.events.add_end(.{
                                .pointer_stop = .{
                                    .pointer = mouse,
                                },
                            });
                            context.b.mouse_active = false;
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
                    context.b.mouse.position = .create(.from_float(x_pos), .from_float(y_pos));
                    context.b.events.add_end(.{
                        .pointer_update = .{
                            .pointer = &context.b.mouse,
                        },
                    });
                } else if (context.b.mouse_in_window) {
                    context.b.mouse_active = true;
                    context.b.mouse = .{
                        .position = .create(.from_float(x_pos), .from_float(y_pos)),
                        .button_left = .up,
                        .button_right = .up,
                        .button_middle = .up,
                    };
                    context.b.events.add_end(.{
                        .pointer_start = .{
                            .pointer = &context.b.mouse,
                        },
                    });
                }
                
            }
        };
        
        const Cursor_enter_callback = struct {
            b: *This,
            
            pub fn call(context: *Cursor_enter_callback, entered: bool) void {
                context.b.mouse_in_window = entered;
                if (entered) {
                    u.log(.{"GLFW cursor entered window callback"});
                } else {
                    u.log(.{"GLFW cursor leaved window callback"});
                    if (!u.any(&.{
                        context.b.mouse.button_left.is_pressed(),
                        context.b.mouse.button_right.is_pressed(),
                        context.b.mouse.button_middle.is_pressed(),
                    })) {
                        context.b.events.add_end(.{
                            .pointer_stop = .{
                                .pointer = &context.b.mouse,
                            },
                        });
                        context.b.mouse_active = false;
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
                        .pointer_scroll = .{
                            .pointer = &context.b.mouse,
                            .offset = .create(.from_float(x_offset), .from_float(y_offset)),
                        },
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
                    .quit = .{},
                });
            }
        }
        
        pub fn get_event(b: *This) !?Event {
            return b.events.pop_start();
        }
    };
}

fn glfw_keycode_to_key(keycode: c_int) ?Button_type {
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

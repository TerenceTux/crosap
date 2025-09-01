
pub const Get_instance_proc_addr_type = *const fn(instance: ?*anyopaque, pName: [*:0]const u8) callconv(.c) ?*const fn() callconv(.c) void;
pub const Get_device_proc_addr_type = *const fn(device: ?*anyopaque, pName: [*:0]const u8) callconv(.c) ?*const fn() callconv(.c) void;

pub const GLFWwindow = opaque {};
pub const GLFWmonitor = opaque {};

pub const GLFWkeyfun = *const fn(window: *GLFWwindow, key: c_int, scancode: c_int, action: Key_action, mods: c_int) callconv(.c) void;
pub const GLFWmousebuttonfun = *const fn(window: *GLFWwindow, button: c_int, action: Key_action, mods: c_int) callconv(.c) void;
pub const GLFWcursorposfun = *const fn(window: *GLFWwindow, xpos: f64, ypos: f64) callconv(.c) void;
pub const GLFWcursorenterfun = *const fn(window: *GLFWwindow, entered: Bool) callconv(.c) void;
pub const GLFWscrollfun = *const fn(window: *GLFWwindow, xoffset: f64, yoffset: f64) callconv(.c) void;

pub const Bool = enum(c_int) {
    false = 0,
    true = 1,
    
    pub fn from_bool(v: bool) Bool {
        return if (v) .true else .false;
    }
    
    pub fn to_bool(v: Bool) bool {
        return switch (v) {
            .false => false,
            .true => true,
        };
    }
};

pub const Result = extern struct {
    bool: Bool,
};

pub const Error = enum(c_int) {
    no_error = 0,
    not_initialized = 0x00010001,
    no_current_context = 0x00010002,
    invalid_enum = 0x00010003,
    invalid_value = 0x00010004,
    out_of_memory = 0x00010005,
    api_unavailable = 0x00010006,
    version_unavailable = 0x00010007,
    platform_error = 0x00010008,
    format_unavailable = 0x00010009,
    no_window_context = 0x0001000A,
};

pub const Init_hint = enum(c_int) {
    joystick_hat_buttons = 0x00050001,
    cocoa_chdir_resources = 0x00051001,
    cocoa_menubar = 0x00051002,
    wayland_libdecor = 0x00053001,
};

pub const init_hint_values = struct {
    pub const no: c_int = 0;
    pub const yes: c_int = 1;
    pub const wayland_prefer_libdecor: c_int = 0x00038001;
    pub const wayland_disable_libdecor: c_int = 0x00038002;
};

pub const Window_hint = enum(c_int) {
    resizable = 0x00020003,
    visible = 0x00020004,
    decorated = 0x00020005,
    focused = 0x00020001,
    auto_iconify = 0x00020002,
    floating = 0x00020007,
    maximized = 0x00020008,
    center_cursor = 0x00020009,
    transparent_framebuffer = 0x0002000A,
    focus_on_show = 0x0002000C,
    scale_to_monitor = 0x0002200C,
    red_bits = 0x00021001,
    green_bits = 0x00021002,
    blue_bits = 0x00021003,
    alpha_bits = 0x00021004,
    depth_bits = 0x00021005,
    stencil_bits = 0x00021006,
    accum_red_bits = 0x00021007,
    accum_green_bits = 0x00021008,
    accum_blue_bits = 0x00021009,
    accum_alpha_bits = 0x0002100A,
    aux_buffers = 0x0002100B,
    samples = 0x0002100D,
    refresh_rate = 0x0002100F,
    stereo = 0x0002100C,
    srgb_capable = 0x0002100E,
    doublebuffer = 0x00021010,
    client_api = 0x00022001,
    context_creation_api = 0x0002200B,
    context_version_major = 0x00022002,
    context_version_minor = 0x00022003,
    context_robustness = 0x00022005,
    context_release_behavior = 0x00022009,
    opengl_forward_compat = 0x00022006,
    opengl_debug_context = 0x00022007,
    opengl_profile = 0x00022008,
    cocoa_retina_framebuffer = 0x00023001,
    cocoa_graphics_switching = 0x00023003,
};

pub const Window_hint_string = enum(c_int) {
    cocoa_frame_name = 0x00023002,
    x11_class_name = 0x00024001,
    x11_instance_name = 0x00024002,
};

pub const window_hint_value = struct {
    pub const v_true: c_int = 1;
    pub const v_false: c_int = 0;
    pub const dont_care: c_int = -1;
    pub const opengl_api: c_int = 0x00030001;
    pub const opengl_es_api: c_int = 0x00030002;
    pub const no_api: c_int = 0;
    pub const native_context_api: c_int = 0x00036001;
    pub const egl_context_api: c_int = 0x00036002;
    pub const osmesa_context_api: c_int = 0x00036003;
    pub const no_robustness: c_int = 0;
    pub const no_reset_notification: c_int = 0x00031001;
    pub const lose_context_on_reset: c_int = 0x00031002;
    pub const any_release_behavior: c_int = 0;
    pub const release_behavior_flush: c_int = 0x00035001;
    pub const release_behavior_none: c_int = 0x00035002;
    pub const opengl_any_profile: c_int = 0;
    pub const opengl_compat_profile: c_int = 0x00032002;
    pub const opengl_core_profile: c_int = 0x00032001;
};

pub const Key_action = enum(c_int) {
    release = 0,
    press = 1,
    repeat = 2,
};

pub const key_mods = struct {
    pub const shift: c_int = 0x0001;
    pub const control: c_int = 0x0002;
    pub const alt: c_int = 0x0004;
    pub const super: c_int = 0x0008;
    pub const caps_lock: c_int = 0x0010;
    pub const num_lock: c_int = 0x0020;
};

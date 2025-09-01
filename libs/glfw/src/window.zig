const u = @import("util");
const std = @import("std");
const types = @import("types.zig");
const Loader = @import("main.zig").Loader;

pub const Window = struct {
    window: *types.GLFWwindow,
    l: *Loader,
    key_callback: ?Key_callback.Dynamic_interface,
    mouse_button_callback: ?Mouse_button_callback.Dynamic_interface,
    cursor_move_callback: ?Cursor_move_callback.Dynamic_interface,
    cursor_enter_callback: ?Cursor_enter_callback.Dynamic_interface,
    scroll_callback: ?Scroll_callback.Dynamic_interface,
    
    pub const Key_callback = u.callback(fn(key: c_int, action: types.Key_action, mods: c_int) void);
    pub const Mouse_button_callback = u.callback(fn(button: c_int, action: types.Key_action, mods: c_int) void);
    pub const Cursor_move_callback = u.callback(fn(x_pos: f64, y_pos: f64) void);
    pub const Cursor_enter_callback = u.callback(fn(entered: bool) void);
    pub const Scroll_callback = u.callback(fn(x_offset: f64, y_offset: f64) void);
    
    // otherwise there is no way to access the glfwGetWindowUserPointer function needed to reference back to our window object
    var glfw_loader: *Loader = undefined;
    fn get_window_object(glfw_window: *types.GLFWwindow) *Window {
        const user_pointer = glfw_loader.fns.glfwGetWindowUserPointer(glfw_window);
        return @ptrCast(@alignCast(user_pointer));
    }
    
    fn glfw_key_callback(glfw_window: *types.GLFWwindow, key: c_int, scancode: c_int, action: types.Key_action, mods: c_int) callconv(.c) void {
        _ = scancode;
        const window = get_window_object(glfw_window);
        if (window.key_callback) |callback| {
            callback.call(.{key, action, mods});
        }
    }
    
    fn glfw_mouse_button_callback(glfw_window: *types.GLFWwindow, button: c_int, action: types.Key_action, mods: c_int) callconv(.c) void {
        const window = get_window_object(glfw_window);
        if (window.mouse_button_callback) |callback| {
            callback.call(.{button, action, mods});
        }
    }
    
    fn glfw_cursor_move_callback(glfw_window: *types.GLFWwindow, xpos: f64, ypos: f64) callconv(.c) void {
        const window = get_window_object(glfw_window);
        if (window.cursor_move_callback) |callback| {
            callback.call(.{xpos, ypos});
        }
    }
    
    fn glfw_cursor_enter_callback(glfw_window: *types.GLFWwindow, entered: types.Bool) callconv(.c) void {
        const window = get_window_object(glfw_window);
        if (window.cursor_enter_callback) |callback| {
            callback.call(.{entered.to_bool()});
        }
    }
    
    fn glfw_scroll_callback(glfw_window: *types.GLFWwindow, xoffset: f64, yoffset: f64) callconv(.c) void {
        const window = get_window_object(glfw_window);
        if (window.scroll_callback) |callback| {
            callback.call(.{xoffset, yoffset});
        }
    }
    
    pub fn init(window: *Window) void {
        window.key_callback = null;
        window.mouse_button_callback = null;
        window.cursor_move_callback = null;
        window.cursor_enter_callback = null;
        window.scroll_callback = null;
        glfw_loader = window.l;
        window.l.fns.glfwSetWindowUserPointer(window.window, window);
        _ = window.l.fns.glfwSetKeyCallback(window.window, glfw_key_callback);
        _ = window.l.fns.glfwSetMouseButtonCallback(window.window, glfw_mouse_button_callback);
        _ = window.l.fns.glfwSetCursorPosCallback(window.window, glfw_cursor_move_callback);
        _ = window.l.fns.glfwSetCursorEnterCallback(window.window, glfw_cursor_enter_callback);
        _ = window.l.fns.glfwSetScrollCallback(window.window, glfw_scroll_callback);
    }
    
    pub fn deinit(window: *Window) void {
        window.l.fns.glfwDestroyWindow(window.window);
    }
    
    pub fn create_vulkan_surface(window: *Window, instance: *anyopaque) !u64 {
        var surface: u64 = undefined;
        const result = try window.l.call(.glfwCreateWindowSurface, .{instance, window.window, null, &surface});
        if (result != 0) {
            return error.surface_creation_failed;
        }
        return surface;
    }
    
    pub fn get_framebuffer_size(window: *Window) ![2]u32 {
        var width: c_int = undefined;
        var height: c_int = undefined;
        try window.l.call(.glfwGetFramebufferSize, .{window.window, &width, &height});
        return .{
            @intCast(width),
            @intCast(height),
        };
    }
    
    pub fn should_close(window: *Window) bool {
        return window.l.fns.glfwWindowShouldClose(window.window) != 0;
    }
    
    pub fn get_cursor_position(window: *Window) u.Vec2r {
        var x_pos: f64 = undefined;
        var y_pos: f64 = undefined;
        window.l.check_error(window.l.fns.glfwGetCursorPos(window.window, &x_pos, &y_pos));
        return .create(.from_float(x_pos), .from_float(y_pos));
    }
};

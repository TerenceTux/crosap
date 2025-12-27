const u = @import("util");
const std = @import("std");
const builtin = @import("builtin");
const types = @import("types.zig");
const Window = @import("main.zig").Window;
const vulkan = @import("vulkan");
const static_linked = @import("options").static_linked;
const glfw_c = @import("glfw_c");

const lib_paths = switch(builtin.os.tag) {
    .linux => [_][]const u8 {
        "libglfw.so.3",
        //"/usr/lib/libglfw.so",
        //"/usr/lib/libglfw.so.3",
    },
    .windows => [_][]const u8 {
        "glfw3.dll",
    },
    else => [_][]const u8 {},
};

const Vulkan_instance_extension = vulkan.types.Instance_extension; 
const instance_extension_reverse = vulkan.instance_extension_reverse;

pub const Loader = struct {
    pub const Version = struct {
        major: u32,
        minor: u32,
        patch: u32,
        
        pub fn create(major: u32, minor: u32, patch: u32) Version {
            return .{
                .major = major,
                .minor = minor,
                .patch = patch,
            };
        }
        
        // true if version >= compare
        pub fn is_at_least(version: Version, compare: Version) bool {
            if (version.major > compare.major) {
                return true;
            } else if (version.major == compare.major) {
                if (version.minor > compare.minor) {
                    return true;
                } else if (version.minor == compare.minor) {
                    return version.patch >= compare.patch;
                } else {
                    return false;
                }
            } else {
                return false;
            }
        }
        
        pub fn debug_print(version: Version, stream: anytype) void {
            u.byte_writer.validate(stream);
            u.write_int_string(stream, version.major, 10);
            stream.write_slice(".");
            u.write_int_string(stream, version.minor, 10);
            stream.write_slice(".");
            u.write_int_string(stream, version.patch, 10);
        }
    };
    
    dynlib: if (static_linked) void else std.DynLib,
    version: Version,
    fns: struct {
        glfwInit: *const fn (
        ) callconv(.c) types.Result,
        glfwTerminate: *const fn(
        ) callconv(.c) void,
        glfwGetError: *const fn(
            description: ?*?[*:0]const u8,
        ) callconv(.c) types.Error,
        glfwGetVersion: *const fn(
            major: ?*c_int,
            minor: ?*c_int,
            rev: ?*c_int,
        ) callconv(.c) void,
        glfwGetVersionString: *const fn(
        ) callconv(.c) [*:0]const u8,
        glfwVulkanSupported: *const fn(
        ) callconv(.c) types.Bool,
        glfwGetInstanceProcAddress: types.Get_instance_proc_addr_type,
        glfwGetRequiredInstanceExtensions: *const fn(
            count: *u32,
        ) callconv(.c) ?[*]const [*:0]const u8,
        glfwGetPhysicalDevicePresentationSupport: *const fn(
            instance: *anyopaque,
            device: *anyopaque,
            queuefamily: u32,
        ) callconv(.c) types.Bool,
        glfwWindowHint: *const fn(
            hint: types.Window_hint,
            value: c_int,
        ) callconv(.c) void,
        glfwCreateWindow: *const fn(
            width: c_int,
            height: c_int,
            title: [*:0]const u8,
            monitor: ?*types.GLFWmonitor,
            share: ?*types.GLFWwindow,
        ) callconv(.c) ?*types.GLFWwindow,
        glfwDestroyWindow: *const fn(
            window: *types.GLFWwindow,
        ) callconv(.c) void,
        glfwCreateWindowSurface: *const fn(
            instance: *anyopaque,
            window: *types.GLFWwindow,
            allocator: ?*const anyopaque,
            surface: *u64
        ) callconv(.c) c_int,
        glfwGetFramebufferSize: *const fn(
            window: *types.GLFWwindow,
            width: ?*c_int,
            height: ?*c_int,
        ) callconv(.c) void,
        glfwPollEvents: *const fn(
        ) callconv(.c) void,
        glfwWindowShouldClose: *const fn(
            window: *types.GLFWwindow,
        ) callconv(.c) c_int,
        glfwInitHint: *const fn(
            hint: types.Init_hint,
            value: c_int,
        ) callconv(.c) void,
        glfwSetWindowUserPointer: *const fn(
            window: *types.GLFWwindow,
            pointer: ?*anyopaque,
        ) callconv(.c) void,
        glfwGetWindowUserPointer: *const fn(
            window: *types.GLFWwindow,
        ) callconv(.c) ?*anyopaque,
        glfwSetKeyCallback: *const fn(
            window: *types.GLFWwindow,
            callback: types.GLFWkeyfun,
        ) callconv(.c) types.GLFWkeyfun,
        glfwSetMouseButtonCallback: *const fn(
            window: *types.GLFWwindow,
            callback: types.GLFWmousebuttonfun,
        ) callconv(.c) types.GLFWmousebuttonfun,
        glfwSetCursorPosCallback: *const fn(
            window: *types.GLFWwindow,
            callback: types.GLFWcursorposfun,
        ) callconv(.c) types.GLFWcursorposfun,
        glfwSetCursorEnterCallback: *const fn(
            window: *types.GLFWwindow,
            callback: types.GLFWcursorenterfun,
        ) callconv(.c) types.GLFWcursorenterfun,
        glfwSetScrollCallback: *const fn(
            window: *types.GLFWwindow,
            callback: types.GLFWscrollfun,
        ) callconv(.c) types.GLFWscrollfun,
        glfwGetCursorPos: *const fn(
            window: *types.GLFWwindow,
            xpos: *f64,
            ypos: *f64,
        ) callconv(.c) void,
    },
    
    pub fn init(loader: *Loader) !void {
        if (comptime static_linked) {
            u.log("Loading static glfw functions");
            inline for (@typeInfo(@TypeOf(loader.fns)).@"struct".fields) |field| {
                const c_fn = &@field(glfw_c, field.name);
                @field(loader.fns, field.name) = @ptrCast(c_fn);
            }
            
        } else {
            u.log("Finding the dynamic glfw libary");
            loader.dynlib = try find_dynlib();
            
            u.log("Loading functions");
            inline for (@typeInfo(@TypeOf(loader.fns)).@"struct".fields) |field| {
                const fn_type = @TypeOf(@field(loader.fns, field.name));
                const fn_ptr = loader.dynlib.lookup(fn_type, field.name);
                if (fn_ptr == null) {
                    u.log(.{"Error getting function ",field.name});
                    return error.function_not_available;
                }
                
                @field(loader.fns, field.name) = fn_ptr orelse unreachable;
            }
        }
        
        loader.version = loader.get_version();
        const version_string = loader.get_version_string();
        u.log(.{"Glfw version ",version_string," [",loader.version,"]"});
        if (!loader.version.is_at_least(.create(3, 0, 0))) {
            u.log(.{"Error: GLFW is too old"});
            return error.glfw_too_old;
        }
        if (loader.version.is_at_least(.create(4, 0, 0))) {
            u.log(.{"Warning: GLFW is too new, there is a high change things will not work"});
        }
        
        try loader.call(.glfwInitHint, .{.joystick_hat_buttons, types.init_hint_values.no});
        try loader.call(.glfwInitHint, .{.cocoa_chdir_resources, types.init_hint_values.no});
        try loader.call(.glfwInitHint, .{.cocoa_menubar, types.init_hint_values.no});
        if (loader.version.is_at_least(.create(3, 3, 9))) {
            try loader.call(.glfwInitHint, .{.wayland_libdecor, types.init_hint_values.wayland_disable_libdecor});
        }
        
        u.log("Glfw init");
        try loader.call(.glfwInit, .{});
        u.log("Glfw init done");
    }
    
    fn find_dynlib() !std.DynLib {
        for (lib_paths) |path| {
            if (std.DynLib.open(path)) |dyn_lib| {
                return dyn_lib;
            } else |_| {}
        }
        return error.not_found;
    }
    
    pub fn deinit(loader: *Loader) void {
        loader.fns.glfwTerminate();
        if (comptime !static_linked) {
            loader.dynlib.close();
        }
    }
    
    const Glfw_errors = b: {
        const result_fields = @typeInfo(types.Error).@"enum".fields;
        var errors: [result_fields.len]std.builtin.Type.Error = undefined;
        for (&errors, result_fields) |*error_field, result_field| {
            error_field.* = .{
                .name = result_field.name,
            };
        }
        break:b @Type(.{
            .error_set = &errors,
        });
    };
    
    fn Call_functiontype(function: @Type(.enum_literal)) type {
        const function_name = @tagName(function);
        const Function_map = @FieldType(Loader, "fns");
        const fn_pointer = @FieldType(Function_map, function_name);
        return @typeInfo(fn_pointer).@"pointer".child;
    }
    
    fn Call_arguments(function: @Type(.enum_literal)) type {
        return std.meta.ArgsTuple(Call_functiontype(function));
    }
    
    fn Call_convert_return_type(original: type) type {
        if (original == types.Result) {
            return Glfw_errors!void;
        } else {
            return Glfw_errors!original;
        }
    }
    
    fn Call_return_type(function: @Type(.enum_literal)) type {
        const typeinfo = @typeInfo(Call_functiontype(function));
        const return_type = typeinfo.@"fn".return_type.?;
        return Call_convert_return_type(return_type);
    }
    
    pub fn call(loader: *Loader, function: @Type(.enum_literal), args: Call_arguments(function)) Call_return_type(function) {
        const fn_pointer = @field(loader.fns, @tagName(function));
        const result = @call(.auto, fn_pointer, args);
        return loader.check_error(result);
    }
    
    pub fn check_error(loader: *Loader, val: anytype) Call_convert_return_type(@TypeOf(val)) {
        var description_ptr: ?[*:0]const u8 = undefined;
        const error_code = loader.fns.glfwGetError(&description_ptr);
        if (description_ptr) |description| {
            u.log(.{"GLFW error: ",description});
            switch (error_code) {
                inline else => |error_enum| return u.create_error(@tagName(error_enum)),
            }
        }
        if (@TypeOf(val) == types.Result) {
            return;
        }
        return val;
    }
    
    pub fn get_version_string(loader: *Loader) []const u8 {
        const c_str = loader.fns.glfwGetVersionString();
        return std.mem.span(c_str);
    }
    
    pub fn vulkan_supported(loader: *Loader) bool {
        return loader.fns.glfwVulkanSupported().to_bool();
    }
    
    pub fn vulkan_get_instance_proc(loader: *Loader) types.Get_instance_proc_addr_type {
        return loader.fns.glfwGetInstanceProcAddress;
    }
    
    pub fn vulkan_get_device_proc(loader: *Loader) types.Get_device_proc_addr_type {
        const fn_ptr = loader.fns.glfwGetInstanceProcAddress(null, "vkGetDeviceProcAddr");
        if (fn_ptr) |fn_p| {
            return @ptrCast(fn_p);
        } else {
            @panic("Could not load vkGetDeviceProcAddr");
        }
    }
    
    pub fn required_vulkan_extensions(loader: *Loader) ![]const Vulkan_instance_extension {
        var count: u32 = undefined;
        const strings_ptr = (try loader.call(.glfwGetRequiredInstanceExtensions, .{&count})).?;
        
        const extensions = u.alloc.alloc(Vulkan_instance_extension, count) catch @panic("No memory");
        for (extensions, strings_ptr) |*extension, c_str| {
            extension.* = instance_extension_reverse.get(std.mem.span(c_str)) orelse {
                u.log(.{"Unknown extension: ",c_str});
                return error.unknown_extension;
            };
        }
        return extensions;
    }
    
    pub fn physical_device_can_present(loader: *Loader, instance: *anyopaque, device: *anyopaque, queue_family: u32) !bool {
        return loader.call(.glfwGetPhysicalDevicePresentationSupport, .{instance, device, queue_family}).bool();
    }
    
    pub fn get_version(loader: *Loader) Version {
        var major: c_int = undefined;
        var minor: c_int = undefined;
        var rev: c_int = undefined;
        
        loader.fns.glfwGetVersion(&major, &minor, &rev);
        
        return .{
            .major = @intCast(major),
            .minor = @intCast(minor),
            .patch = @intCast(rev),
        };
    }
    
    pub fn set_window_hint(loader: *Loader, hint: types.Window_hint, value: c_int) !void {
        return try loader.call(.glfwWindowHint, .{hint, value});
    }
    
    pub fn create_window(loader: *Loader, window: *Window, width: u32, height: u32, title: []const u8) !void {
        const title_z = u.alloc.dupeZ(u8, title) catch @panic("No memory");
        defer u.alloc.free(title_z);
        
        const result = try loader.call(.glfwCreateWindow, .{@intCast(width), @intCast(height), title_z, null, null});
        
        window.window = result.?;
        window.l = loader;
        window.init();
    }
    
    pub fn poll_events(loader: *Loader) !void {
        try loader.call(.glfwPollEvents, .{});
    }
};

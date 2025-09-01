const u = @import("util");
const std = @import("std");
const types = @import("types");
const Instance = @import("instance.zig").Instance;

const lib_paths = [_][]const u8 {
    "/usr/lib/libvulkan.so",
    "/usr/lib/libvulkan.so.1",
    "/lib/libvulkan.so",
};

pub const Loader = struct {
    pub const Get_instance_proc_addr_type = *const types.get_instance_proc_addr.function;
    pub const Get_device_proc_addr_type = *const types.get_device_proc_addr.function;
    
    dynlib: ?std.DynLib,
    get_instance_proc_addr: Get_instance_proc_addr_type,
    get_device_proc_addr: Get_device_proc_addr_type,
    fns: types.Global_commands,
    
    pub fn init(loader: *Loader) void {
        u.log("Loading vulkan libary");
        loader.dynlib = find_dynlib() catch @panic("vulkan library not found");
        loader.get_instance_proc_addr = loader.dynlib.lookup(@TypeOf(loader.get_instance_proc_addr), "vkGetInstanceProcAddr") orelse @panic("Can't load vkGetInstanceProcAddr");
        loader.get_device_proc_addr = loader.dynlib.lookup(@TypeOf(loader.get_device_proc_addr), "vkGetDeviceProcAddr") orelse @panic("Can't load vkGetDeviceProcAddr");
        init_functions();
    }
    
    pub fn init_from_get_proc(loader: *Loader, get_instance_proc_addr: Get_instance_proc_addr_type, get_device_proc_addr: Get_device_proc_addr_type) void {
        loader.dynlib = null;
        loader.get_instance_proc_addr = get_instance_proc_addr;
        loader.get_device_proc_addr = get_device_proc_addr;
        loader.init_functions();
    }
    
    fn init_functions(loader: *Loader) void {
        u.log("Loading base functions");
        inline for (@typeInfo(@TypeOf(loader.fns)).@"struct".fields) |field| {
            const fn_ptr = loader.vkGetInstanceProcAddr(null, field.name);
            if (fn_ptr == null) {
                @panic("Error getting function "++field.name);
            }
            
            @field(loader.fns, field.name) = @ptrCast(fn_ptr);
        }
    }
    
    fn find_dynlib() !std.DynLib {
        for (lib_paths) |path| {
            if (std.DynLib.open(path)) |dyn_lib| {
                return dyn_lib;
            } else |_| {}
        }
        return error.NotFound;
    }
    
    pub fn deinit(loader: *Loader) void {
        if (loader.dynlib) |*dynlib| dynlib.close();
    }
    
    pub fn get_command(function: @Type(.enum_literal)) types.Command {
        const function_name = @tagName(function);
        return @field(types, function_name);
    }
    
    pub fn call(loader: *Loader, function: @Type(.enum_literal), args: get_command(function).Call_arguments()) get_command(function).Call_return_type() {
        const command = get_command(function);
        const function_pointer = @field(loader.fns, @tagName(function));
        return command.call(function_pointer, args);
    }
    
    pub fn instance_version(loader: *Loader) types.Version {
        var version_num: u32 = undefined;
        types.handle_error(loader.fns.vkEnumerateInstanceVersion(&version_num));
        return .from_u32(version_num);
    }
    
    pub const Layer_info = struct {
        name: []const u8,
        vulkan_version: types.Version,
        layer_version: u32,
        description: []const u8,
        
        pub fn from_vulkan_layer(layer_properties: *const types.VkLayerProperties) Layer_info {
            const name_ptr: [*:0]const u8 = &layer_properties.layerName;
            const description_ptr: [*:0]const u8 = &layer_properties.description;
            return .{
                .name = u.alloc.dupe(u8, std.mem.span(name_ptr)) catch @panic("No memory"),
                .vulkan_version = .from_u32(layer_properties.specVersion),
                .layer_version = layer_properties.implementationVersion,
                .description = u.alloc.dupe(u8, std.mem.span(description_ptr)) catch @panic("No memory"),
            };
        }
        
        pub fn deinit(layer_info: *Layer_info) void {
            u.alloc.free(layer_info.name);
            u.alloc.free(layer_info.description);
        }
    };
    
    pub const Layer_list = struct {
        items: []Layer_info,
        
        pub fn deinit(layers: *Layer_list) void {
            for (layers.items) |*layer| {
                layer.deinit();
            }
            u.alloc.free(layers.items);
        }
    };
    
    pub fn get_layers(loader: *Loader) Layer_list {
        var count: u32 = undefined;
        loader.call(.enumerate_instance_layer_properties, .{&count, null});
        if (count == 0) {
            return .{
                .items = &.{},
            };
        } else {
            const layer_properties = u.alloc.alloc(types.VkLayerProperties, count) catch @panic("No memory");
            loader.call(.enumerate_instance_layer_properties, .{&count, layer_properties.ptr});
            
            const layers = u.alloc.alloc(Layer_info, count) catch @panic("No memory");
            for (layers, layer_properties) |*layer, *vk_properties| {
                layer.* = .from_vulkan_layer(vk_properties);
            }
            
            u.alloc.free(layer_properties);
            return .{
                .items = layers,
            };
        }
    }
    
    pub const Extension_info = struct {
        name: []const u8,
        version: u32,
        
        pub fn from_vulkan_extension(extension_properties: *const types.VkExtensionProperties) Extension_info {
            const name_ptr: [*:0]const u8 = &extension_properties.extensionName;
            return .{
                .name = u.alloc.dupe(u8, std.mem.span(name_ptr)) catch @panic("No memory"),
                .version = extension_properties.specVersion,
            };
        }
        
        pub fn deinit(extension_info: *Extension_info) void {
            u.alloc.free(extension_info.name);
        }
    };
    
    pub const Extension_list = struct {
        items: []Extension_info,
        
        pub fn empty() Extension_list {
            return .{
                .items = &.{},
            };
        }
        
        pub fn from_vulkan(extension_properties: []types.VkExtensionProperties) Extension_list {
            const extensions = u.alloc.alloc(Extension_info, extension_properties.len) catch @panic("No memory");
            for (extensions, extension_properties) |*extension, *vk_properties| {
                extension.* = .from_vulkan_extension(vk_properties);
            }
            return .{
                .items = extensions,
            };
        }
        
        pub fn deinit(extensions: *Extension_list) void {
            for (extensions.items) |*extension| {
                extension.deinit();
            }
            u.alloc.free(extensions.items);
        }
    };
    
    pub fn get_extensions(loader: *Loader, layer: ?[]const u8) Extension_list {
        const layer_nullt = if (layer) |layer_name| (
            u.alloc.dupeZ(u8, layer_name) catch @panic("No memory")
        ) else null;
        defer if (layer_nullt) |layer_name| u.alloc.free(layer_name);
        const layer_ptr = if (layer_nullt) |layer_name| layer_name.ptr else null;
        
        var count: u32 = undefined;
        loader.call(.enumerate_instance_extension_properties, .{layer_ptr, &count, null});
        if (count == 0) {
            return .empty();
        } else {
            const extension_properties = u.alloc.alloc(types.VkExtensionProperties, count) catch @panic("No memory");
            loader.call(.enumerate_instance_extension_properties, .{layer_ptr, &count, extension_properties.ptr});
            
            const extension_list = Extension_list.from_vulkan(extension_properties);
            
            u.alloc.free(extension_properties);
            return extension_list;
        }
    }
    
    pub const Name_and_version = struct {
        name: []const u8,
        version: u32,
    };
    
    pub const Layer_setting = struct {
        layer: []const u8,
        setting: []const u8,
        value: Value,
        
        pub const Value = union(enum) {
            boolean: bool,
            int: i64,
            float: f64,
            string: []const u8,
            multiple_booleans: []const bool,
            multiple_ints: []const i64,
            multiple_floats: []const f64,
            multiple_strings: []const []const u8,
        };
        
        pub const Free_info = struct {
            layer: [:0]const u8,
            setting: [:0]const u8,
            strings: [][:0]const u8,
            booleans: []types.VkBool32,
            
            pub fn free(free_info: *const Free_info) void {
                u.alloc.free(free_info.layer);
                u.alloc.free(free_info.setting);
                if (free_info.strings.len > 0) {
                    for (free_info.strings) |string| {
                        u.alloc.free(string);
                    }
                    u.alloc.free(free_info.strings);
                }
                if (free_info.booleans.len > 0) {
                    u.alloc.free(free_info.booleans);
                }
            }
        };
        
        pub fn create_vulkan(setting: *const Layer_setting, free_info: *Free_info) types.VkLayerSettingEXT {
            free_info.layer = u.alloc.dupeZ(u8, setting.layer) catch @panic("no memory");
            free_info.setting = u.alloc.dupeZ(u8, setting.setting) catch @panic("no memory");
            free_info.strings = &.{};
            free_info.booleans = &.{};
            var value_type: types.VkLayerSettingTypeEXT = undefined;
            var count: usize = 1;
            var pointer: *const anyopaque = undefined;
            switch (setting.value) {
                .int => |*value| {
                    value_type = .int64;
                    pointer = value;
                },
                .multiple_ints => |values| {
                    value_type = .int64;
                    count = values.len;
                    pointer = values.ptr;
                },
                .float => |*value| {
                    value_type = .float64;
                    pointer = value;
                },
                .multiple_floats => |values| {
                    value_type = .float64;
                    count = values.len;
                    pointer = values.ptr;
                },
                .boolean => |value| {
                    value_type = .bool32;
                    free_info.booleans = u.alloc.alloc(types.VkBool32, 1) catch @panic("no memory");
                    free_info.booleans[0] = .from(value);
                    pointer = @ptrCast(free_info.booleans.ptr);
                },
                .multiple_booleans => |values| {
                    value_type = .bool32;
                    free_info.booleans = u.alloc.alloc(types.VkBool32, values.len) catch @panic("no memory");
                    for (free_info.booleans, values) |*store, value| {
                        store.* = .from(value);
                    }
                    count = values.len;
                    pointer = @ptrCast(free_info.booleans.ptr);
                },
                .string => |value| {
                    value_type = .string;
                    free_info.strings = u.alloc.alloc([:0]const u8, 1) catch @panic("no memory");
                    free_info.strings[0] = u.alloc.dupeZ(u8, value) catch @panic("no memory");
                    pointer = @ptrCast(free_info.strings.ptr);
                },
                .multiple_strings => |values| {
                    value_type = .string;
                    free_info.strings = u.alloc.alloc([:0]const u8, values.len) catch @panic("no memory");
                    for (free_info.strings, values) |*store, value| {
                        store.* = u.alloc.dupeZ(u8, value) catch @panic("no memory");
                    }
                    count = values.len;
                    pointer = @ptrCast(free_info.strings.ptr);
                },
            }
            
            return .{
                .pLayerName = free_info.layer.ptr,
                .pSettingName = free_info.setting.ptr,
                .type = value_type,
                .valueCount = @intCast(count),
                .pValues = pointer,
            };
        }
    };
    
    pub fn create_instance(loader: *Loader, application: ?Name_and_version, engine: ?Name_and_version, layers: []const []const u8, extensions: []const []const u8, layer_settings: []const Layer_setting) !Instance {
        const application_name = if (application) |application_v| (
            u.alloc.dupeZ(u8, application_v.name) catch @panic("No memory")
        ) else null;
        defer if (application_name) |name| u.alloc.free(name);
        const application_version = if (application) |application_v| application_v.version else 0;
        
        const engine_name = if (engine) |engine_v| (
            u.alloc.dupeZ(u8, engine_v.name) catch @panic("No memory")
        ) else null;
        defer if (engine_name) |name| u.alloc.free(name);
        const engine_version = if (engine) |engine_v| engine_v.version else 0;
        
        const layers_s = u.alloc.alloc([:0]const u8, layers.len) catch @panic("No memory");
        defer u.alloc.free(layers_s);
        const layers_z = u.alloc.alloc([*:0]const u8, layers.len) catch @panic("No memory");
        defer u.alloc.free(layers_z);
        for (layers, layers_s, layers_z) |layer, *slice, *ptr| {
            slice.* = u.alloc.dupeZ(u8, layer) catch @panic("No memory");
            ptr.* = slice.*.ptr;
        }
        defer for (layers_s) |slice| {
            u.alloc.free(slice);
        };
        
        const extensions_s = u.alloc.alloc([:0]const u8, extensions.len) catch @panic("No memory");
        defer u.alloc.free(extensions_s);
        const extensions_z = u.alloc.alloc([*:0]const u8, extensions.len) catch @panic("No memory");
        defer u.alloc.free(extensions_z);
        for (extensions, extensions_s, extensions_z) |extension, *slice, *ptr| {
            slice.* = u.alloc.dupeZ(u8, extension) catch @panic("No memory");
            ptr.* = slice.*.ptr;
        }
        defer for (extensions_s) |slice| {
            u.alloc.free(slice);
        };
        
        var create_info = types.VkInstanceCreateInfo {
            .pApplicationInfo = &.{
                .pApplicationName = if (application_name) |name| name.ptr else null,
                .applicationVersion = application_version,
                .pEngineName = if (engine_name) |name| name.ptr else null,
                .engineVersion = engine_version,
                .apiVersion = (types.Version {
                    .variant = 0,
                    .major = 1,
                    .minor = 1,
                    .patch = 0,
                }).to_u32(),
            },
            .enabledLayerCount = @intCast(layers_z.len),
            .ppEnabledLayerNames = layers_z.ptr,
            .enabledExtensionCount = @intCast(extensions_z.len),
            .ppEnabledExtensionNames = extensions_z.ptr,
        };
        
        var layer_settings_free_info: []Layer_setting.Free_info = undefined;
        var layer_settings_list: []types.VkLayerSettingEXT = undefined;
        var layer_settings_info: types.VkLayerSettingsCreateInfoEXT = undefined;
        if (layer_settings.len > 0) {
            layer_settings_free_info = u.alloc.alloc(Layer_setting.Free_info, layer_settings.len) catch @panic("no memory");
            layer_settings_list = u.alloc.alloc(types.VkLayerSettingEXT, layer_settings.len) catch @panic("no memory");
            for (layer_settings, layer_settings_free_info, layer_settings_list) |setting, *free_info, *item| {
                item.* = setting.create_vulkan(free_info);
            }
            layer_settings_info = .{
                .settingCount = @intCast(layer_settings_list.len),
                .pSettings = layer_settings_list.ptr,
            };
            create_info.pNext = &layer_settings_info;
        }
        defer if (layer_settings.len > 0) {
            for (layer_settings_free_info) |free_info| {
                free_info.free();
            }
            u.alloc.free(layer_settings_free_info);
            u.alloc.free(layer_settings_list);
        };
        
        var instance: types.VkInstance = undefined;
        try loader.call(.create_instance, .{&create_info, null, &instance});
        
        return try .init(instance, loader);
    }
};

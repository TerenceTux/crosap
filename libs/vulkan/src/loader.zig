const u = @import("util");
const builtin = @import("builtin");
const std = @import("std");
const types = @import("types");
const Instance = @import("instance.zig").Instance;

const lib_paths = switch(builtin.os.tag) {
    .linux => [_][]const u8 {
        "libvulkan.so.1"
        //"/usr/lib/libvulkan.so",
        //"/usr/lib/libvulkan.so.1",
        //"/lib/libvulkan.so",
    },
    .windows => [_][]const u8 {
        "vulkan-1.dll",
        // "C:/Windows/System32/vulkan-1.dll"
    },
    else => [_][]const u8 {},
};

pub fn get_command(function: @Type(.enum_literal)) types.Command {
    const function_name = @tagName(function);
    return @field(types, function_name);
}

pub const Command_item = struct {
    index: usize,
    name: [*:0]const u8,
};

fn index_in_struct(Struct: type, comptime name: []const u8) ?usize {
    for (@typeInfo(Struct).@"struct".fields, 0..) |field_info, i| {
        if (std.mem.eql(u8, field_info.name, name)) {
            return i;
        }
    }
    return null;
}

pub fn create_extension_command_map(Extension_enum: type, Commands_struct: type) std.EnumArray(Extension_enum, []const Command_item) {
    const Map_value = []const Command_item;
    const Value_struct = std.enums.EnumFieldStruct(Extension_enum, Map_value, null);
    var array_values: Value_struct = undefined;
    
    @setEvalBranchQuota(@typeInfo(Value_struct).@"struct".fields.len * 100000);
    for (@typeInfo(Value_struct).@"struct".fields) |field_info| {
        const extension_name = field_info.name;
        const extension_commands = @field(types.extension_commands, extension_name).commands;
        
        var command_count: usize = 0;
        for (extension_commands) |command_name| {
            if (index_in_struct(Commands_struct, @tagName(command_name)) != null) {
                command_count += 1;
            }
        }
        
        var values: [command_count]Command_item = undefined;
        command_count = 0;
        for (extension_commands) |command_name| {
            if (index_in_struct(Commands_struct, @tagName(command_name))) |index| {
                const command = @field(types, @tagName(command_name));
                values[command_count] = Command_item {
                    .index = index,
                    .name = u.comptime_to_sentinel(u8, 0, command.name),
                };
                command_count += 1;
            }
        }
        
        const values_copy = values;
        @field(array_values, extension_name) = &values_copy;
    }
    return std.EnumArray(Extension_enum, Map_value).init(array_values);
}

pub const core_versions = b: {
    const versions_fields = @typeInfo(types.Core_version).@"enum".fields;
    var values: [versions_fields.len]types.Core_version = undefined;
    for (&values, versions_fields) |*value, field| {
        value.* = @field(types.Core_version, field.name);
    }
    break:b values;
};



pub fn create_extension_maps(Extension: type) struct {
    std.EnumArray(Extension, [:0]const u8),
    std.StaticStringMap(Extension),
} {
    const extension_fields = @typeInfo(Extension).@"enum".fields;
    @setEvalBranchQuota(extension_fields.len * 1000);
    
    const Map_values = std.enums.EnumFieldStruct(Extension, [:0]const u8, null);
    var map_values: Map_values = undefined;
    
    const Reverse_entry = struct {
        []const u8,
        Extension,
    };
    var reverse_values: [extension_fields.len]Reverse_entry = undefined;
    
    for (&reverse_values, extension_fields) |*reverse_value, enum_field| {
        const name = enum_field.name;
        const vk_name = @field(types.extension_commands, name).name;
        @field(map_values, name) = vk_name;
        reverse_value.* = .{
            vk_name,
            @field(Extension, name),
        };
    }
    
    return .{
        std.EnumArray(Extension, [:0]const u8).init(map_values),
        std.StaticStringMap(Extension).initComptime(reverse_values),
    };
}

const instance_extension_maps = create_extension_maps(types.Instance_extension);
pub const instance_extension_map = instance_extension_maps[0];
pub const instance_extension_reverse = instance_extension_maps[1];
const device_extension_maps = create_extension_maps(types.Device_extension);
pub const device_extension_map = device_extension_maps[0];
pub const device_extension_reverse = device_extension_maps[1];

pub const Loader = struct {
    pub const Get_instance_proc_addr_type = *const types.get_instance_proc_addr.function;
    pub const Get_device_proc_addr_type = *const types.get_device_proc_addr.function;
    
    dynlib: ?std.DynLib,
    get_instance_proc_addr: Get_instance_proc_addr_type,
    get_device_proc_addr: Get_device_proc_addr_type,
    fns: types.Global_commands,
    
    pub fn init(loader: *Loader) !void {
        u.log("Loading vulkan libary");
        loader.dynlib = try find_dynlib();
        loader.get_instance_proc_addr = loader.dynlib.?.lookup(@TypeOf(loader.get_instance_proc_addr), "vkGetInstanceProcAddr") orelse return error.vulkan_function_not_found;
        loader.get_device_proc_addr = loader.dynlib.?.lookup(@TypeOf(loader.get_device_proc_addr), "vkGetDeviceProcAddr") orelse return error.vulkan_function_not_found;
        try loader.init_functions();
    }
    
    pub fn init_from_get_proc(loader: *Loader, get_instance_proc_addr: Get_instance_proc_addr_type, get_device_proc_addr: Get_device_proc_addr_type) !void {
        loader.dynlib = null;
        loader.get_instance_proc_addr = get_instance_proc_addr;
        loader.get_device_proc_addr = get_device_proc_addr;
        try loader.init_functions();
    }
    
    fn init_functions(loader: *Loader) !void {
        u.log_start(.{"Loading base functions"});
        defer u.log_end(.{});
        inline for (@typeInfo(@TypeOf(loader.fns)).@"struct".fields) |field| {
            const vk_name = @field(types, field.name).name;
            const fn_ptr = loader.get_instance_proc_addr(null, vk_name);
            if (fn_ptr == null) {
                u.log(.{"Error getting function ",field.name});
                return error.function_not_found;
            }
            @field(loader.fns, field.name) = @ptrCast(fn_ptr.?);
        }
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
        if (loader.dynlib) |*dynlib| dynlib.close();
    }
    
    pub fn call(loader: *Loader, function: @Type(.enum_literal), args: get_command(function).Call_arguments()) get_command(function).Call_return_type() {
        const command = get_command(function);
        const function_pointer = @field(loader.fns, @tagName(function));
        return command.call(function_pointer, args);
    }
    
    pub fn instance_version(loader: *Loader) !types.Version {
        var version_num: u32 = undefined;
        try loader.call(.enumerate_instance_version, .{&version_num});
        return .from_u32(version_num);
    }
    
    pub const Layer_info = struct {
        name: []const u8,
        vulkan_version: types.Version,
        layer_version: u32,
        description: []const u8,
        
        pub fn from_vulkan_layer(layer_properties: *const types.Layer_properties) Layer_info {
            const name_ptr: [*:0]const u8 = &layer_properties.layer_name;
            const description_ptr: [*:0]const u8 = &layer_properties.description;
            return .{
                .name = u.alloc.dupe(u8, std.mem.span(name_ptr)) catch @panic("No memory"),
                .vulkan_version = .from_u32(layer_properties.spec_version),
                .layer_version = layer_properties.implementation_version,
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
    
    pub fn get_layers(loader: *Loader) !Layer_list {
        var count: u32 = undefined;
        try loader.call(.enumerate_instance_layer_properties, .{&count, null});
        if (count == 0) {
            return .{
                .items = &.{},
            };
        } else {
            const layer_properties = u.alloc.alloc(types.Layer_properties, count) catch @panic("No memory");
            try loader.call(.enumerate_instance_layer_properties, .{&count, layer_properties.ptr});
            
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
        extension: types.Instance_extension,
        version: u32,
        
        pub fn from_vulkan_extension(extension_properties: *const types.Extension_properties) ?Extension_info {
            const name_ptr: [*:0]const u8 = &extension_properties.extension_name;
            const extension = instance_extension_reverse.get(std.mem.span(name_ptr)) orelse return null;
            return .{
                .extension = extension,
                .version = extension_properties.spec_version,
            };
        }
    };
    
    pub fn get_extensions(loader: *Loader, layer: ?[]const u8) ![]Extension_info {
        const layer_nullt = if (layer) |layer_name| (
            u.alloc.dupeZ(u8, layer_name) catch @panic("No memory")
        ) else null;
        defer if (layer_nullt) |layer_name| u.alloc.free(layer_name);
        const layer_ptr = if (layer_nullt) |layer_name| layer_name.ptr else null;
        
        var count: u32 = undefined;
        try loader.call(.enumerate_instance_extension_properties, .{layer_ptr, &count, null});
        if (count == 0) {
            return &.{};
        } else {
            const extension_properties = u.alloc.alloc(types.Extension_properties, count) catch @panic("No memory");
            defer u.alloc.free(extension_properties);
            try loader.call(.enumerate_instance_extension_properties, .{layer_ptr, &count, extension_properties.ptr});
            
            var known_count: usize = 0;
            for (extension_properties) |extension_prop| {
                if (Extension_info.from_vulkan_extension(&extension_prop) != null) {
                    known_count += 1;
                } else {
                    u.log(.{"Ignoring unknown extension ",extension_prop.extension_name});
                }
            }
            
            const extension_list = u.alloc.alloc(Extension_info, known_count) catch @panic("no memory");
            
            known_count = 0;
            for (extension_properties) |extension_prop| {
                if (Extension_info.from_vulkan_extension(&extension_prop)) |extension_info| {
                    extension_list[known_count] = extension_info;
                    known_count += 1;
                }
            }
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
            booleans: []types.Bool,
            
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
        
        pub fn create_vulkan(setting: *const Layer_setting, free_info: *Free_info) types.Ext_layer_setting {
            free_info.layer = u.alloc.dupeZ(u8, setting.layer) catch @panic("no memory");
            free_info.setting = u.alloc.dupeZ(u8, setting.setting) catch @panic("no memory");
            free_info.strings = &.{};
            free_info.booleans = &.{};
            var value_type: types.Ext_layer_setting_type = undefined;
            var count: usize = 1;
            var pointer: *const anyopaque = undefined;
            switch (setting.value) {
                .int => |*value| {
                    value_type = .int_64;
                    pointer = value;
                },
                .multiple_ints => |values| {
                    value_type = .int_64;
                    count = values.len;
                    pointer = values.ptr;
                },
                .float => |*value| {
                    value_type = .float_64;
                    pointer = value;
                },
                .multiple_floats => |values| {
                    value_type = .float_64;
                    count = values.len;
                    pointer = values.ptr;
                },
                .boolean => |value| {
                    value_type = .bool_32;
                    free_info.booleans = u.alloc.alloc(types.Bool, 1) catch @panic("no memory");
                    free_info.booleans[0] = .from(value);
                    pointer = @ptrCast(free_info.booleans.ptr);
                },
                .multiple_booleans => |values| {
                    value_type = .bool_32;
                    free_info.booleans = u.alloc.alloc(types.Bool, values.len) catch @panic("no memory");
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
                .layer_name = free_info.layer.ptr,
                .setting_name = free_info.setting.ptr,
                .type = value_type,
                .value_count = @intCast(count),
                .values = @ptrCast(pointer),
            };
        }
    };
    
    pub fn create_instance(loader: *Loader, application: ?Name_and_version, engine: ?Name_and_version, layers: []const []const u8, extensions: []const types.Instance_extension, layer_settings: []const Layer_setting) !Instance {
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
        
        const extensions_z = u.alloc.alloc([*:0]const u8, extensions.len) catch @panic("No memory");
        defer u.alloc.free(extensions_z);
        for (extensions, extensions_z) |extension, *ptr| {
            ptr.* = instance_extension_map.get(extension);
        }
        
        var create_info = types.Instance_create_info {
            .application_info = &.{
                .application_name = if (application_name) |name| name.ptr else null,
                .application_version = application_version,
                .engine_name = if (engine_name) |name| name.ptr else null,
                .engine_version = engine_version,
                .api_version = (types.Version {
                    .variant = 0,
                    .major = 1,
                    .minor = 1,
                    .patch = 0,
                }).to_u32(),
            },
            .enabled_layer_count = @intCast(layers_z.len),
            .enabled_layer_names_pp = layers_z.ptr,
            .enabled_extension_count = @intCast(extensions_z.len),
            .enabled_extension_names_pp = extensions_z.ptr,
        };
        
        var layer_settings_free_info: []Layer_setting.Free_info = undefined;
        var layer_settings_list: []types.Ext_layer_setting = undefined;
        var layer_settings_info: types.Ext_layer_settings_create_info = undefined;
        if (layer_settings.len > 0) {
            layer_settings_free_info = u.alloc.alloc(Layer_setting.Free_info, layer_settings.len) catch @panic("no memory");
            layer_settings_list = u.alloc.alloc(types.Ext_layer_setting, layer_settings.len) catch @panic("no memory");
            for (layer_settings, layer_settings_free_info, layer_settings_list) |setting, *free_info, *item| {
                item.* = setting.create_vulkan(free_info);
            }
            layer_settings_info = .{
                .setting_count = @intCast(layer_settings_list.len),
                .settings = layer_settings_list.ptr,
            };
            create_info.next = &layer_settings_info;
        }
        defer if (layer_settings.len > 0) {
            for (layer_settings_free_info) |free_info| {
                free_info.free();
            }
            u.alloc.free(layer_settings_free_info);
            u.alloc.free(layer_settings_list);
        };
        
        var instance: types.Instance = undefined;
        try loader.call(.create_instance, .{&create_info, null, &instance});
        
        return try .init(instance, loader, .version_1_0, extensions);
    }
};

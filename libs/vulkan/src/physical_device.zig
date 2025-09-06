const u = @import("util");
const std = @import("std");
const types = @import("types");
const Instance = @import("main.zig").Instance;
const Device = @import("main.zig").Device;
const Surface = @import("main.zig").Surface;

const device_extension_map = @import("loader.zig").device_extension_map;
const device_extension_reverse = @import("loader.zig").device_extension_reverse;

pub const Physical_device = struct {
    instance: *Instance,
    physical_device: types.Physical_device,
    
    pub const Properties = struct {
        vulkan_version: types.Version,
        name: []const u8,
        device_type: types.Physical_device_type,
        vendor_id: u32,
        device_id: u32,
        driver_version: u32,
        
        pub fn from_vulkan(properties: *const types.Physical_device_properties) Properties {
            const name_ptr: [*:0]const u8 = &properties.device_name;
            return .{
                .vulkan_version = .from_u32(properties.api_version),
                .name = u.alloc.dupe(u8, std.mem.span(name_ptr)) catch @panic("No memory"),
                .device_type = properties.device_type,
                .vendor_id = properties.vendor_id,
                .device_id = properties.device_id,
                .driver_version = properties.driver_version,
            };
        }
        
        pub fn deinit(properties: *Properties) void {
            u.alloc.free(properties.name);
        }
    };
    
    pub fn get_properties(pd: *Physical_device) Properties {
        var vk_properties: types.Physical_device_properties = undefined;
        pd.instance.call(.get_physical_device_properties, .{pd.physical_device, &vk_properties});
        
        return .from_vulkan(&vk_properties);
    }
    
    pub const Extension_info = struct {
        extension: types.Device_extension,
        version: u32,
        
        pub fn from_vulkan_extension(extension_properties: *const types.Extension_properties) ?Extension_info {
            const name_ptr: [*:0]const u8 = &extension_properties.extension_name;
            const extension = device_extension_reverse.get(std.mem.span(name_ptr)) orelse return null;
            return .{
                .extension = extension,
                .version = extension_properties.spec_version,
            };
        }
    };
    
    pub fn get_extensions(pd: *Physical_device, layer: ?[]const u8) ![]Extension_info {
        const layer_nullt = if (layer) |layer_name| (
            u.alloc.dupeZ(u8, layer_name) catch @panic("No memory")
        ) else null;
        defer if (layer_nullt) |layer_name| u.alloc.free(layer_name);
        const layer_ptr = if (layer_nullt) |layer_name| layer_name.ptr else null;
        
        var count: u32 = undefined;
        try pd.instance.call(.enumerate_device_extension_properties, .{pd.physical_device, layer_ptr, &count, null});
        if (count == 0) {
            return &.{};
        } else {
            const extension_properties = u.alloc.alloc(types.Extension_properties, count) catch @panic("No memory");
            defer u.alloc.free(extension_properties);
            try pd.instance.call(.enumerate_device_extension_properties, .{pd.physical_device, layer_ptr, &count, extension_properties.ptr});
            
            var known_count: usize = 0;
            for (extension_properties) |extension_prop| {
                if (Extension_info.from_vulkan_extension(&extension_prop) != null) {
                    known_count += 1;
                } else {
                    u.log(.{"Ignoring unknown extension ",&extension_prop.extension_name});
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
    
    pub const Queue_type = struct {
        index: u32,
        count: u32,
        support_graphics: bool,
        support_compute: bool,
        support_transfer: bool,
    };
    
    pub fn get_queue_types(pd: *Physical_device) []Queue_type {
        var count: u32 = undefined;
        pd.instance.call(.get_physical_device_queue_family_properties, .{pd.physical_device, &count, null});
        if (count == 0) {
            return &.{};
        } else {
            const queue_properties = u.alloc.alloc(types.Queue_family_properties, count) catch @panic("No memory");
            pd.instance.call(.get_physical_device_queue_family_properties, .{pd.physical_device, &count, queue_properties.ptr});
            
            const list = u.alloc.alloc(Queue_type, count) catch @panic("No memory");
            for (queue_properties, list, 0..) |properties, *dest, index| {
                const flags = properties.queue_flags;
                dest.* = .{
                    .index = @intCast(index),
                    .count = properties.queue_count,
                    .support_graphics = flags.has(.graphics),
                    .support_compute = flags.has(.compute),
                    .support_transfer = flags.has(.transfer),
                };
            }
            
            u.alloc.free(queue_properties);
            return list;
        }
    }
    
    pub fn create_device_with_queue_index(pd: *Physical_device, queue_index: u32, extensions: []const types.Device_extension) !Device {
        const extensions_z = u.alloc.alloc([*:0]const u8, extensions.len) catch @panic("No memory");
        defer u.alloc.free(extensions_z);
        for (extensions, extensions_z) |extension, *ptr| {
            ptr.* = device_extension_map.get(extension);
        }
        
        var device: types.Device = undefined;
        
        const queue_priorities = [_]f32{ 1 };
        const queue_info = [_]types.Device_queue_create_info{
            .{
                .queue_family_index = queue_index,
                .queue_count = 1,
                .queue_priorities = (&queue_priorities).ptr,
            },
        };
        try pd.instance.call(.create_device, .{pd.physical_device, &.{
            .queue_create_info_count = queue_info.len,
            .queue_create_infos = &queue_info,
            .enabled_extension_count = @intCast(extensions_z.len),
            .enabled_extension_names_pp = extensions_z.ptr,
            .enabled_layer_count = 0, // deprecated
            .enabled_layer_names_pp = undefined, // deprecated
            .enabled_features = null,
        }, null, &device});
        
        return try .init(pd.instance.loader.get_device_proc_addr, device, pd, queue_index, .version_1_0, extensions);
    }
    
    pub fn create_device(pd: *Physical_device, extensions: []const types.Device_extension) !Device {
        const queue_type_index = pd.best_queue_type_index() orelse return error.no_good_queue_available;
        return try pd.create_device_with_queue_index(queue_type_index, extensions);
    }
    
    pub fn best_queue_type_index(pd: *Physical_device) ?u32 {
        const queue_types = pd.get_queue_types();
        defer u.alloc.free(queue_types);
        for (queue_types) |queue_type| {
            if (queue_type.support_graphics and queue_type.support_compute) {
                return queue_type.index;
            }
        }
        return null;
    }
    
    pub fn import_surface(pd: *Physical_device, surface: types.Khr_surface) Surface {
        return .{
            .surface = surface,
            .physical_device = pd,
        };
    }
    
    pub fn get_memory_info(pd: *Physical_device) types.Physical_device_memory_properties {
        var properties: types.Physical_device_memory_properties = undefined;
        pd.instance.call(.get_physical_device_memory_properties, .{pd.physical_device, &properties});
        return properties;
    }
    
    pub fn supports_surface_on_queue(pd: *Physical_device, surface: types.Khr_surface, queue_index: u32) !bool {
        var supported: types.Bool = undefined;
        try pd.instance.call(.khr_get_physical_device_surface_support, .{pd.physical_device, queue_index, surface, &supported});
        return supported.to_bool();
    }
};

const u = @import("util");
const std = @import("std");
const types = @import("types");
const Instance = @import("main.zig").Instance;
const Device = @import("main.zig").Device;
const Surface = @import("main.zig").Surface;

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
            const name_ptr: [*:0]const u8 = &properties.deviceName;
            return .{
                .vulkan_version = .from_u32(properties.apiVersion),
                .name = u.alloc.dupe(u8, std.mem.span(name_ptr)) catch @panic("No memory"),
                .device_type = properties.deviceType,
                .vendor_id = properties.vendorID,
                .device_id = properties.deviceID,
                .driver_version = properties.driverVersion,
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
    
    const Extension_list = @import("loader.zig").Loader.Extension_list;
    
    pub fn get_extensions(pd: *Physical_device, layer: ?[]const u8) !Extension_list {
        const layer_nullt = if (layer) |layer_name| (
            u.alloc.dupeZ(u8, layer_name) catch @panic("No memory")
        ) else null;
        defer if (layer_nullt) |layer_name| u.alloc.free(layer_name);
        const layer_ptr = if (layer_nullt) |layer_name| layer_name.ptr else null;
        
        var count: u32 = undefined;
        try pd.instance.call(.enumerate_device_extension_properties, .{pd.physical_device, layer_ptr, &count, null});
        if (count == 0) {
            return .empty();
        } else {
            const extension_properties = u.alloc.alloc(types.Extension_properties, count) catch @panic("No memory");
            try pd.instance.call(.enumerate_device_extension_properties, .{pd.physical_device, layer_ptr, &count, extension_properties.ptr});
            
            const extension_list = Extension_list.from_vulkan(extension_properties);
            
            u.alloc.free(extension_properties);
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
                const flags = properties.queueFlags;
                dest.* = .{
                    .index = @intCast(index),
                    .count = properties.queueCount,
                    .support_graphics = flags.has(.graphics),
                    .support_compute = flags.has(.compute),
                    .support_transfer = flags.has(.transfer),
                };
            }
            
            u.alloc.free(queue_properties);
            return list;
        }
    }
    
    pub fn create_device_with_queue_index(pd: *Physical_device, queue_index: u32, extensions: []const []const u8) !Device {
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
        
        var device: types.Device = undefined;
        
        const queue_priorities = [_]f32{ 1 };
        const queue_info = [_]types.Device_queue_create_info{
            .{
                .queueFamilyIndex = queue_index,
                .queueCount = 1,
                .pQueuePriorities = (&queue_priorities).ptr,
            },
        };
        try pd.instance.call(.create_device, .{pd.physical_device, &.{
            .queueCreateInfoCount = queue_info.len,
            .pQueueCreateInfos = &queue_info,
            .enabledExtensionCount = @intCast(extensions_z.len),
            .ppEnabledExtensionNames = extensions_z.ptr,
            .pEnabledFeatures = null,
        }, null, &device});
        
        var queue: types.Queue = undefined;
        pd.instance.call(.get_device_queue, .{device, queue_index, 0, &queue});
        
        return try .init(pd.instance.loader.get_device_proc_addr, device, pd, queue, queue_index);
    }
    
    pub fn create_device(pd: *Physical_device, extensions: []const []const u8) Device {
        const queue_type_index = pd.best_queue_type_index() orelse @panic("No suitable queue type available");
        return pd.create_device_with_queue_index(queue_type_index, extensions);
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
};

const u = @import("util");
const std = @import("std");
const types = @import("types");
const Instance = @import("loader.zig").Instance;
const Physical_device = @import("main.zig").Physical_device;

pub const Surface = struct {
    surface: types.Khr_surface,
    physical_device: *Physical_device,
    
    pub fn deinit(surface: *Surface) void {
        surface.physical_device.instance.call(.khr_destroy_surface, .{
            surface.physical_device.instance.instance,
            surface.surface,
            null,
        });
    }
    
    const Properties = struct {
        min_swapchain_images: u32,
        max_swapchain_images: ?u32,
        current_size: ?types.Extent_2d,
        min_size: types.Extent_2d,
        max_size: types.Extent_2d,
        max_array_layers: u32,
        current_transform: types.Khr_surface_transform_flag_option,
        supported_transforms: types.Khr_surface_transform_flags,
        supported_alpha_composite_mode: types.Khr_composite_alpha_flags,
    };
    
    pub fn get_properties(surface: *Surface) !Properties {
        var properties: types.Khr_surface_capabilities = undefined;
        try surface.physical_device.instance.call(.khr_get_physical_device_surface_capabilities, .{
            surface.physical_device.physical_device,
            surface.surface,
            &properties,
        });
        const extent_unspecified = types.Extent_2d {
            .width = 0xFFFFFFFF,
            .height = 0xFFFFFFFF,
        };
        return .{
            .min_swapchain_images = properties.min_image_count,
            .max_swapchain_images = if (properties.max_image_count == 0) null else properties.max_image_count,
            .current_size = if (std.meta.eql(properties.current_extent, extent_unspecified)) null else properties.current_extent,
            .min_size = properties.min_image_extent,
            .max_size = properties.max_image_extent,
            .max_array_layers = properties.max_image_array_layers,
            .current_transform = properties.current_transform,
            .supported_transforms = properties.supported_transforms,
            .supported_alpha_composite_mode = properties.supported_composite_alpha,
        };
    }
    
    const Format = struct {
        format: types.Format,
        color_space: types.Khr_color_space,
    };
    
    pub fn get_supported_formats(surface: *Surface) ![]Format {
        var count: u32 = 0;
        try surface.physical_device.instance.call(.khr_get_physical_device_surface_formats, .{
            surface.physical_device.physical_device,
            surface.surface,
            &count,
            null,
        });
        
        if (count == 0) {
            return &.{};
        }
        
        const vk_formats = u.alloc.alloc(types.Khr_surface_format, count) catch @panic("no memory");
        defer u.alloc.free(vk_formats);
        try surface.physical_device.instance.call(.khr_get_physical_device_surface_formats, .{
            surface.physical_device.physical_device,
            surface.surface,
            &count,
            vk_formats.ptr,
        });
        
        const list = u.alloc.alloc(Format, count) catch @panic("no memory");
        for (vk_formats, list) |vk_format, *dest| {
            dest.* = .{
                .format = vk_format.format,
                .color_space = vk_format.color_space,
            };
        }
        return list;
    }
    
    pub const Present_mode = types.Khr_present_mode;
    
    pub fn get_supported_present_modes(surface: *Surface) ![]Present_mode {
        var count: u32 = 0;
        
        try surface.physical_device.instance.call(.khr_get_physical_device_surface_present_modes, .{
            surface.physical_device.physical_device,
            surface.surface,
            &count,
            null,
        });
        if (count == 0) {
            return &.{};
        }
        
        const present_modes = u.alloc.alloc(Present_mode, count) catch @panic("no memory");
        try surface.physical_device.instance.call(.khr_get_physical_device_surface_present_modes, .{
            surface.physical_device.physical_device,
            surface.surface,
            &count,
            present_modes.ptr,
        });
        
        return present_modes;
    }
};

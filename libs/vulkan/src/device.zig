const u = @import("util");
const std = @import("std");
const types = @import("types");
const get_command = @import("loader.zig").get_command;
const create_extension_command_map = @import("loader.zig").create_extension_command_map;
const core_versions = @import("loader.zig").core_versions;
const Get_device_proc_addr_type = @import("loader.zig").Loader.Get_device_proc_addr_type;
const Physical_device = @import("main.zig").Physical_device;
const Swapchain = @import("main.zig").Swapchain;
const Graphics_pipeline = @import("main.zig").Graphics_pipeline;
const Task_allocator = @import("main.zig").Task_allocator;
const Buffer = @import("main.zig").Buffer;
const Image = @import("main.zig").Image;
const Descriptor_pool = @import("main.zig").Descriptor_pool;


const Core_commands_map = create_extension_command_map(types.Core_version, types.Device_commands);
const Extension_commands_map = create_extension_command_map(types.Device_extension, types.Device_commands);

pub const Device = struct {
    device: types.Device,
    queue: types.Queue,
    queue_index: u32,
    memory_info: types.Physical_device_memory_properties,
    get_device_proc_addr: Get_device_proc_addr_type,
    fns: types.Device_commands,
    
    pub fn init(get_device_proc_addr: Get_device_proc_addr_type, vk_device: types.Device, physical_device: *Physical_device, queue_index: u32, core_version: types.Core_version, extensions: []const types.Device_extension) !Device {
        var device: Device = undefined;
        device.device = vk_device;
        device.queue_index = queue_index;
        device.get_device_proc_addr = get_device_proc_addr;
        
        u.log_start(.{"Loading device functions"});
        defer u.log_end(.{});
        
        for (core_versions) |current_version| {
            try device.load_commands(get_device_proc_addr, Core_commands_map.get(current_version));
            if (current_version == core_version) {
                break;
            }
        }
        for (extensions) |extension| {
            try device.load_commands(get_device_proc_addr, Extension_commands_map.get(extension));
        }
        
        device.call(.get_device_queue, .{vk_device, queue_index, 0, &device.queue});
        device.memory_info = physical_device.get_memory_info();
        
        return device;
    }
    
    const Command_items = []const @import("loader.zig").Command_item;
    fn load_commands(device: *Device, get_device_proc_addr: Get_device_proc_addr_type, commands: Command_items) !void {
        for (commands) |command| {
            const fn_ptr = get_device_proc_addr(device.device, command.name);
            if (fn_ptr == null) {
                u.log(.{"Error getting function ",command.name});
                return error.function_not_found;
            }
            const fn_list: [*]*const anyopaque = @ptrCast(&device.fns);
            fn_list[command.index] = @ptrCast(fn_ptr.?);
        }
    }
    
    pub fn call(device: *Device, function: @Type(.enum_literal), args: get_command(function).Call_arguments()) get_command(function).Call_return_type() {
        const command = get_command(function);
        const function_pointer = @field(device.fns, @tagName(function));
        return command.call(function_pointer, args);
    }
    
    pub fn deinit(device: *Device) void {
        device.call(.destroy_device, .{device.device, null});
    }
    
    pub fn create_swapchain(device: *Device, surface: types.Khr_surface,
                            min_images: u32, image_format: types.Format, image_color_space: types.Khr_color_space, image_size: types.Extent_2d, image_array_layers: u32,
                            transform_mode: types.Khr_surface_transform_flag_option, alpha_composite_mode: types.Khr_composite_alpha_flag_option, present_mode: types.Khr_present_mode,
                            old_swapchain: ?types.Khr_swapchain) !Swapchain {
        const create_info = types.Khr_swapchain_create_info {
            .flags = .empty(),
            .surface = surface,
            .min_image_count = min_images,
            .image_format = image_format,
            .image_color_space = image_color_space,
            .image_extent = image_size,
            .image_array_layers = image_array_layers,
            .image_usage = .just(.color_attachment),
            .image_sharing_mode = .exclusive,
            .queue_family_index_count = 0,
            .queue_family_indices = undefined,
            .pre_transform = transform_mode,
            .composite_alpha = alpha_composite_mode,
            .present_mode = present_mode,
            .clipped = .from(true),
            .old_swapchain = if (old_swapchain) |old| old else types.null_handle,
        };
        
        var swapchain: types.Khr_swapchain = undefined;
        try device.call(.khr_create_swapchain, .{device.device, &create_info, null, &swapchain});
        return .{
            .swapchain = swapchain,
            .device = device,
        };
    }
    
    pub fn create_image_view(device: *Device, image: types.Image, format: types.Format) !types.Image_view {
        const create_info = types.Image_view_create_info {
            .flags = .empty(),
            .image = image,
            .view_type = .@"2d",
            .format = format,
            .components = .{
                .r = .identity,
                .g = .identity,
                .b = .identity,
                .a = .identity,
            },
            .subresource_range = .{
                .aspect_mask = .just(.color),
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = 1,
            },
        };
        
        var image_view: types.Image_view = undefined;
        try device.call(.create_image_view, .{device.device, &create_info, null, &image_view});
        return image_view;
    }
    
    pub fn destroy_image_view(device: *Device, image_view: types.Image_view) void {
        device.call(.destroy_image_view, .{device.device, image_view, null});
    }
    
    pub fn create_graphics_pipeline(device: *Device, create_info: *const Graphics_pipeline.Create_info) !Graphics_pipeline {
        return try .init(device, create_info);
    }
    
    pub fn create_framebuffer(device: *Device, render_pass: types.Render_pass, attachments: []const types.Image_view, width: u32, height: u32, layers: u32) !types.Framebuffer {
        const create_info = types.Framebuffer_create_info {
            .flags = .empty(),
            .render_pass = render_pass,
            .attachment_count = @intCast(attachments.len),
            .attachments = attachments.ptr,
            .width = width,
            .height = height,
            .layers = layers,
        };
        var framebuffer: types.Framebuffer = undefined;
        try device.call(.create_framebuffer, .{device.device, &create_info, null, &framebuffer});
        return framebuffer;
    }
    
    pub fn destroy_framebuffer(device: *Device, framebuffer: types.Framebuffer) void {
        device.call(.destroy_framebuffer, .{device.device, framebuffer, null});
    }
    
    pub fn create_task_allocator(device: *Device, transient: bool, resettable: bool) !Task_allocator {
        var flags = types.Command_pool_create_flags.empty();
        if (transient) {
            flags = flags.add(.transient);
        }
        if (resettable) {
            flags = flags.add(.reset_command_buffer);
        }
        const create_info = types.Command_pool_create_info {
            .flags = flags,
            .queue_family_index = device.queue_index,
        };
        var command_pool: types.Command_pool = undefined;
        try device.call(.create_command_pool, .{device.device, &create_info, null, &command_pool});
        return .{
            .command_pool = command_pool,
            .device = device,
        };
    }
    
    pub fn create_semaphore(device: *Device) !types.Semaphore {
        const create_info = types.Semaphore_create_info {
            .flags = .empty(),
        };
        var semaphore: types.Semaphore = undefined;
        try device.call(.create_semaphore, .{device.device, &create_info, null, &semaphore});
        return semaphore;
    }
    
    pub fn destroy_semaphore(device: *Device, semaphore: types.Semaphore) void {
        device.call(.destroy_semaphore, .{device.device, semaphore, null});
    }
    
    pub fn create_fence(device: *Device, signaled: bool) !types.Fence {
        const create_info = types.Fence_create_info {
            .flags = if (signaled) .just(.signaled) else .empty(),
        };
        var fence: types.Fence = undefined;
        try device.call(.create_fence, .{device.device, &create_info, null, &fence});
        return fence;
    }
    
    pub fn destroy_fence(device: *Device, fence: types.Fence) void {
        device.call(.destroy_fence, .{device.device, fence, null});
    }
    
    pub fn wait_for_fence(device: *Device, fence: types.Fence, timeout: ?u64) !void {
        const fences = [_]types.Fence {
            fence,
        };
        try device.call(.wait_for_fences, .{device.device, fences.len, &fences, .true, timeout orelse std.math.maxInt(u64)});
        try device.call(.reset_fences, .{device.device, fences.len, &fences});
    }
    
    pub fn wait_everything_finished(device: *Device) !void {
        try device.call(.device_wait_idle, .{device.device});
    }
    
    pub fn memory_types(device: *Device) []types.Memory_type {
        return device.memory_info.memory_types[0..device.memory_info.memory_type_count];
    }
    
    pub const Memory_access_pattern = enum {
        infrequent_write,
        stream,
        staging,
        
        pub fn flags_is_preferred(access: Memory_access_pattern, flags: types.Memory_property_flags) bool {
            return switch (access) {
                .infrequent_write => flags.has(.device_local) and !flags.has(.host_visible),
                .stream => flags.has(.host_visible) and !flags.has(.host_cached),
                .staging => flags.has(.device_local) and flags.has(.host_visible),
            };
        }
        
        pub fn flags_is_good(access: Memory_access_pattern, flags: types.Memory_property_flags) bool {
            return switch (access) {
                .infrequent_write => flags.has(.device_local),
                .stream => flags.has(.host_visible),
                .staging => flags.has(.host_visible),
            };
        }
        
        pub fn flags_is_acceptable(access: Memory_access_pattern, flags: types.Memory_property_flags) bool {
            return switch (access) {
                .infrequent_write => true,
                .stream => true,
                .staging => flags.has(.host_visible),
            };
        }
    };
    
    pub fn allocate_memory(device: *Device, requirements: types.Memory_requirements, access_pattern: Memory_access_pattern) !struct {memory: types.Device_memory, index: u32} {
        u.log_start(.{"Allocating ",requirements.size," bytes of device memory, access pattern: ",access_pattern});
        defer u.log_end({});
        const memory_index = memory_index: {
            const functions = [_]fn(access: Memory_access_pattern, flags: types.Memory_property_flags) bool {
                Memory_access_pattern.flags_is_preferred,
                Memory_access_pattern.flags_is_good,
                Memory_access_pattern.flags_is_acceptable,
            };
            const names = [_][]const u8 {
                "preferred",
                "good",
                "acceptable"
            };
            inline for (functions, names) |function, name| {
                u.log(.{"Try for ",name});
                for (device.memory_types(), 0..) |memory_type, i| {
                    const mask: u32 = @as(u32, 1) << @intCast(i);
                    if ((requirements.memory_type_bits & mask) != 0) {
                        u.log(.{"Index ",i," is valid"});
                        if (function(access_pattern, memory_type.property_flags)) {
                            u.log(.{"Choosing index ",i});
                            u.log(.{"Flags: ",memory_type.property_flags});
                            break:memory_index i;
                        }
                    }
                }
            }
            @panic("no valid memory type");
        };
        const allocate_info = types.Memory_allocate_info {
            .allocation_size = requirements.size,
            .memory_type_index = @intCast(memory_index),
        };
        var memory: types.Device_memory = undefined;
        try device.call(.allocate_memory, .{device.device, &allocate_info, null, &memory});
        return .{
            .memory = memory,
            .index = @intCast(memory_index),
        };
    }
    
    pub fn create_buffer(device: *Device, size: usize, usage: types.Buffer_usage_flags, access_pattern: Memory_access_pattern) !Buffer {
        const buffer_info = types.Buffer_create_info {
            .flags = .empty(),
            .size = size,
            .usage = usage.add(.transfer_dst),
            .sharing_mode = .exclusive,
            .queue_family_index_count = 0,
            .queue_family_indices = undefined,
        };
        var buffer: types.Buffer = undefined;
        try device.call(.create_buffer, .{device.device, &buffer_info, null, &buffer});
        
        var memory_requirements: types.Memory_requirements = undefined;
        device.call(.get_buffer_memory_requirements, .{device.device, buffer, &memory_requirements});
        
        const allocated = try device.allocate_memory(memory_requirements, access_pattern);
        const memory_flags = device.memory_info.memory_types[allocated.index].property_flags;
        const mapped = if (memory_flags.has(.host_visible)) map: {
            var map_ptr: [*]u8 = undefined;
            try device.call(.map_memory, .{device.device, allocated.memory, 0, types.whole_size, .empty(), @ptrCast(&map_ptr)});
            break:map map_ptr;
        } else null;
        try device.call(.bind_buffer_memory, .{device.device, buffer, allocated.memory, 0});
        
        return .{
            .device = device,
            .buffer = buffer,
            .memory = allocated.memory,
            .size = size,
            .mapped = mapped,
            .coherent = memory_flags.has(.host_coherent),
        };
    }
    
    pub fn create_image(device: *Device, width: u32, height: u32, format: types.Format, usage: types.Image_usage_flags) !Image {
        const image_info = types.Image_create_info {
            .flags = .empty(),
            .image_type = .@"2d",
            .format = format,
            .extent = .{
                .width = width,
                .height = height,
                .depth = 1,
            },
            .mip_levels = 1,
            .array_layers = 1,
            .samples = .@"1",
            .tiling = .optimal,
            .usage = usage,
            .sharing_mode = .exclusive,
            .queue_family_index_count = 0,
            .queue_family_indices = undefined,
            .initial_layout = .undefined,
        };
        var image: types.Image = undefined;
        try device.call(.create_image, .{device.device, &image_info, null, &image});
        
        var memory_requirements: types.Memory_requirements = undefined;
        device.call(.get_image_memory_requirements, .{device.device, image, &memory_requirements});
        
        const allocated = try device.allocate_memory(memory_requirements, .infrequent_write);
        try device.call(.bind_image_memory, .{device.device, image, allocated.memory, 0});
        
        const view = try device.create_image_view(image, format);
        
        return .{
            .device = device,
            .image = image,
            .memory = allocated.memory,
            .view = view,
        };
    }
    
    pub fn create_descriptor_set_layout(device: *Device, bindings: []const types.Descriptor_set_layout_binding) !types.Descriptor_set_layout {
        const create_info = types.Descriptor_set_layout_create_info {
            .flags = .empty(),
            .binding_count = @intCast(bindings.len),
            .bindings = bindings.ptr,
        };
        var descriptor_set_layout: types.Descriptor_set_layout = undefined;
        try device.call(.create_descriptor_set_layout, .{device.device, &create_info, null, &descriptor_set_layout});
        return descriptor_set_layout;
    }
    
    pub fn destroy_descriptor_set_layout(device: *Device, dset_layout: types.Descriptor_set_layout) void {
        device.call(.destroy_descriptor_set_layout, .{device.device, dset_layout, null});
    }
    
    pub fn create_descriptor_pool(device: *Device, max_sets: u32, max_types: []const types.Descriptor_pool_size) !Descriptor_pool {
        const create_info = types.Descriptor_pool_create_info {
            .flags = .empty(),
            .max_sets = max_sets,
            .pool_size_count = @intCast(max_types.len),
            .pool_sizes = max_types.ptr,
        };
        var descriptor_pool: types.Descriptor_pool = undefined;
        try device.call(.create_descriptor_pool, .{device.device, &create_info, null, &descriptor_pool});
        return .{
            .descriptor_pool = descriptor_pool,
            .device = device,
        };
    }
};

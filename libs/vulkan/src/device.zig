const u = @import("util");
const std = @import("std");
const types = @import("types");
const Get_device_proc_addr_type = *const @import("loader.zig").Loader.Get_device_proc_addr_type;
const Physical_device = @import("main.zig").Physical_device;
const Swapchain = @import("main.zig").Swapchain;
const Graphics_pipeline = @import("main.zig").Graphics_pipeline;
const Task_allocator = @import("main.zig").Task_allocator;
const Buffer = @import("main.zig").Buffer;
const Image = @import("main.zig").Image;
const Descriptor_pool = @import("main.zig").Descriptor_pool;

pub const Device = struct {
    device: types.Device,
    queue: types.Queue,
    queue_index: u32,
    memory_info: types.Physical_device_memory_properties,
    get_device_proc_addr: Get_device_proc_addr_type,
    fns: types.Device_commands,
    
    pub fn init(get_device_proc_addr: Get_device_proc_addr_type, vk_device: types.Device, physical_device: *Physical_device, vk_queue: types.Queue, queue_index: u32) !Device {
        var device: Device = undefined;
        device.device = vk_device;
        device.queue = vk_queue;
        device.queue_index = queue_index;
        device.get_device_proc_addr = get_device_proc_addr;
        
        u.log("Loading device functions");
        inline for (@typeInfo(@TypeOf(device.fns)).@"struct".fields) |field| {
            const fn_ptr = device.get_device_proc_addr(device.device, field.name);
            if (fn_ptr == null) {
                u.log(.{"Error getting function ",field.name});
                return error.function_not_found;
            }
            @field(device.fns, field.name) = @ptrCast(fn_ptr);
        }
        
        device.memory_info = physical_device.get_memory_info();
        
        return device;
    }
    
    pub fn deinit(device: *Device) void {
        device.fns.vkDestroyDevice(device.device, null);
    }
    
    pub fn create_swapchain(device: *Device, surface: types.VkSurfaceKHR,
                            min_images: u32, image_format: types.VkFormat, image_color_space: types.VkColorSpaceKHR, image_size: types.VkExtent2D, image_array_layers: u32,
                            transform_mode: types.VkSurfaceTransformFlagBitsKHR, alpha_composite_mode: types.VkCompositeAlphaFlagBitsKHR, present_mode: types.VkPresentModeKHR,
                            old_swapchain: ?types.VkSwapchainKHR) Swapchain {
        const create_info = types.VkSwapchainCreateInfoKHR {
            .flags = .empty(),
            .surface = surface,
            .minImageCount = min_images,
            .imageFormat = image_format,
            .imageColorSpace = image_color_space,
            .imageExtent = image_size,
            .imageArrayLayers = image_array_layers,
            .imageUsage = .just(.color_attachment),
            .imageSharingMode = .exclusive,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = undefined,
            .preTransform = transform_mode,
            .compositeAlpha = alpha_composite_mode,
            .presentMode = present_mode,
            .clipped = .from(true),
            .oldSwapchain = if (old_swapchain) |old| old else types.VK_NULL_HANDLE,
        };
        
        var swapchain: types.VkSwapchainKHR = undefined;
        types.handle_error(device.fns.vkCreateSwapchainKHR(device.device, &create_info, null, &swapchain));
        return .{
            .swapchain = swapchain,
            .device = device,
        };
    }
    
    pub fn create_image_view(device: *Device, image: types.VkImage, format: types.VkFormat) types.VkImageView {
        const create_info = types.VkImageViewCreateInfo {
            .flags = .empty(),
            .image = image,
            .viewType = .type_2d,
            .format = format,
            .components = .{
                .r = .identity,
                .g = .identity,
                .b = .identity,
                .a = .identity,
            },
            .subresourceRange = .{
                .aspectMask = .just(.color),
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        };
        
        var image_view: types.VkImageView = undefined;
        types.handle_error(device.fns.vkCreateImageView(device.device, &create_info, null, &image_view));
        return image_view;
    }
    
    pub fn destroy_image_view(device: *Device, image_view: types.VkImageView) void {
        device.fns.vkDestroyImageView(device.device, image_view, null);
    }
    
    pub fn create_graphics_pipeline(device: *Device, create_info: *const Graphics_pipeline.Create_info) Graphics_pipeline {
        return .init(device, create_info);
    }
    
    pub fn create_framebuffer(device: *Device, render_pass: types.VkRenderPass, attachments: []const types.VkImageView, width: u32, height: u32, layers: u32) types.VkFramebuffer {
        const create_info = types.VkFramebufferCreateInfo {
            .flags = .empty(),
            .renderPass = render_pass,
            .attachmentCount = @intCast(attachments.len),
            .pAttachments = attachments.ptr,
            .width = width,
            .height = height,
            .layers = layers,
        };
        var framebuffer: types.VkFramebuffer = undefined;
        types.handle_error(device.fns.vkCreateFramebuffer(device.device, &create_info, null, &framebuffer));
        return framebuffer;
    }
    
    pub fn destroy_framebuffer(device: *Device, framebuffer: types.VkFramebuffer) void {
        device.fns.vkDestroyFramebuffer(device.device, framebuffer, null);
    }
    
    pub fn create_task_allocator(device: *Device, transient: bool, resettable: bool) Task_allocator {
        var flags = types.VkCommandPoolCreateFlags.empty();
        if (transient) {
            flags = flags.add(.transient);
        }
        if (resettable) {
            flags = flags.add(.reset_command_buffer);
        }
        const create_info = types.VkCommandPoolCreateInfo {
            .flags = flags,
            .queueFamilyIndex = device.queue_index,
        };
        var command_pool: types.VkCommandPool = undefined;
        types.handle_error(device.fns.vkCreateCommandPool(device.device, &create_info, null, &command_pool));
        return .{
            .command_pool = command_pool,
            .device = device,
        };
    }
    
    pub fn create_semaphore(device: *Device) types.VkSemaphore {
        const create_info = types.VkSemaphoreCreateInfo {
            .flags = .empty(),
        };
        var semaphore: types.VkSemaphore = undefined;
        types.handle_error(device.fns.vkCreateSemaphore(device.device, &create_info, null, &semaphore));
        return semaphore;
    }
    
    pub fn destroy_semaphore(device: *Device, semaphore: types.VkSemaphore) void {
        device.fns.vkDestroySemaphore(device.device, semaphore, null);
    }
    
    pub fn create_fence(device: *Device, signaled: bool) types.VkFence {
        const create_info = types.VkFenceCreateInfo {
            .flags = if (signaled) .just(.signaled) else .empty(),
        };
        var fence: types.VkFence = undefined;
        types.handle_error(device.fns.vkCreateFence(device.device, &create_info, null, &fence));
        return fence;
    }
    
    pub fn destroy_fence(device: *Device, fence: types.VkFence) void {
        device.fns.vkDestroyFence(device.device, fence, null);
    }
    
    pub fn wait_for_fence(device: *Device, fence: types.VkFence, timeout: ?u64) void {
        const fences = [_]types.VkFence {
            fence,
        };
        types.handle_error(device.fns.vkWaitForFences(device.device, fences.len, &fences, .true, timeout orelse std.math.maxInt(u64)));
        types.handle_error(device.fns.vkResetFences(device.device, fences.len, &fences));
    }
    
    pub fn wait_everything_finished(device: *Device) void {
        types.handle_error(device.fns.vkDeviceWaitIdle(device.device));
    }
    
    pub fn memory_types(device: *Device) []types.VkMemoryType {
        return device.memory_info.memoryTypes[0..device.memory_info.memoryTypeCount];
    }
    
    pub const Memory_access_pattern = enum {
        infrequent_write,
        stream,
        staging,
        
        pub fn flags_is_preferred(access: Memory_access_pattern, flags: types.VkMemoryPropertyFlags) bool {
            return switch (access) {
                .infrequent_write => flags.has(.device_local) and !flags.has(.host_visible),
                .stream => flags.has(.host_visible) and !flags.has(.host_cached),
                .staging => flags.has(.device_local) and flags.has(.host_visible),
            };
        }
        
        pub fn flags_is_good(access: Memory_access_pattern, flags: types.VkMemoryPropertyFlags) bool {
            return switch (access) {
                .infrequent_write => flags.has(.device_local),
                .stream => flags.has(.host_visible),
                .staging => flags.has(.host_visible),
            };
        }
        
        pub fn flags_is_acceptable(access: Memory_access_pattern, flags: types.VkMemoryPropertyFlags) bool {
            return switch (access) {
                .infrequent_write => true,
                .stream => true,
                .staging => flags.has(.host_visible),
            };
        }
    };
    
    pub fn allocate_memory(device: *Device, requirements: types.VkMemoryRequirements, access_pattern: Memory_access_pattern) struct {memory: types.VkDeviceMemory, index: u32} {
        u.log_start(.{"Allocating ",requirements.size," bytes of device memory, access pattern: ",access_pattern});
        defer u.log_end({});
        const memory_index = memory_index: {
            const functions = [_]fn(access: Memory_access_pattern, flags: types.VkMemoryPropertyFlags) bool {
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
                    if ((requirements.memoryTypeBits & mask) != 0) {
                        u.log(.{"Index ",i," is valid"});
                        if (function(access_pattern, memory_type.propertyFlags)) {
                            u.log(.{"Choosing index ",i});
                            u.log(.{"Flags: ",memory_type.propertyFlags});
                            break:memory_index i;
                        }
                    }
                }
            }
            @panic("no valid memory type");
        };
        const allocate_info = types.VkMemoryAllocateInfo {
            .allocationSize = requirements.size,
            .memoryTypeIndex = @intCast(memory_index),
        };
        var memory: types.VkDeviceMemory = undefined;
        types.handle_error(device.fns.vkAllocateMemory(device.device, &allocate_info, null, &memory));
        return .{
            .memory = memory,
            .index = @intCast(memory_index),
        };
    }
    
    pub fn create_buffer(device: *Device, size: usize, usage: types.VkBufferUsageFlags, access_pattern: Memory_access_pattern) Buffer {
        const buffer_info = types.VkBufferCreateInfo {
            .flags = .empty(),
            .size = size,
            .usage = usage.add(.transfer_dst),
            .sharingMode = .exclusive,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = undefined,
        };
        var buffer: types.VkBuffer = undefined;
        types.handle_error(device.fns.vkCreateBuffer(device.device, &buffer_info, null, &buffer));
        
        var memory_requirements: types.VkMemoryRequirements = undefined;
        device.fns.vkGetBufferMemoryRequirements(device.device, buffer, &memory_requirements);
        
        const allocated = device.allocate_memory(memory_requirements, access_pattern);
        const memory_flags = device.memory_info.memoryTypes[allocated.index].propertyFlags;
        const mapped = if (memory_flags.has(.host_visible)) map: {
            var map_ptr: [*]u8 = undefined;
            types.handle_error(device.fns.vkMapMemory(device.device, allocated.memory, 0, types.VK_WHOLE_SIZE, .empty(), &map_ptr));
            break:map map_ptr;
        } else null;
        types.handle_error(device.fns.vkBindBufferMemory(device.device, buffer, allocated.memory, 0));
        
        return .{
            .device = device,
            .buffer = buffer,
            .memory = allocated.memory,
            .size = size,
            .mapped = mapped,
            .coherent = memory_flags.has(.host_coherent),
        };
    }
    
    pub fn create_image(device: *Device, width: u32, height: u32, format: types.VkFormat, usage: types.VkImageUsageFlags) Image {
        const image_info = types.VkImageCreateInfo {
            .flags = .empty(),
            .imageType = .dim_2d,
            .format = format,
            .extent = .{
                .width = width,
                .height = height,
                .depth = 1,
            },
            .mipLevels = 1,
            .arrayLayers = 1,
            .samples = .sample_1,
            .tiling = .optimal,
            .usage = usage,
            .sharingMode = .exclusive,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = undefined,
            .initialLayout = .undefined,
        };
        var image: types.VkImage = undefined;
        types.handle_error(device.fns.vkCreateImage(device.device, &image_info, null, &image));
        
        var memory_requirements: types.VkMemoryRequirements = undefined;
        device.fns.vkGetImageMemoryRequirements(device.device, image, &memory_requirements);
        
        const allocated = device.allocate_memory(memory_requirements, .infrequent_write);
        types.handle_error(device.fns.vkBindImageMemory(device.device, image, allocated.memory, 0));
        
        const view = device.create_image_view(image, format);
        
        return .{
            .device = device,
            .image = image,
            .memory = allocated.memory,
            .view = view,
        };
    }
    
    pub fn create_descriptor_set_layout(device: *Device, bindings: []const types.VkDescriptorSetLayoutBinding) types.VkDescriptorSetLayout {
        const create_info = types.VkDescriptorSetLayoutCreateInfo {
            .flags = .empty(),
            .bindingCount = @intCast(bindings.len),
            .pBindings = bindings.ptr,
        };
        var descriptor_set_layout: types.VkDescriptorSetLayout = undefined;
        types.handle_error(device.fns.vkCreateDescriptorSetLayout(device.device, &create_info, null, &descriptor_set_layout));
        return descriptor_set_layout;
    }
    
    pub fn destroy_descriptor_set_layout(device: *Device, dset_layout: types.VkDescriptorSetLayout) void {
        device.fns.vkDestroyDescriptorSetLayout(device.device, dset_layout, null);
    }
    
    pub fn create_descriptor_pool(device: *Device, max_sets: u32, max_types: []const types.VkDescriptorPoolSize) Descriptor_pool {
        const create_info = types.VkDescriptorPoolCreateInfo {
            .flags = .empty(),
            .maxSets = max_sets,
            .poolSizeCount = @intCast(max_types.len),
            .pPoolSizes = max_types.ptr,
        };
        var descriptor_pool: types.VkDescriptorPool = undefined;
        types.handle_error(device.fns.vkCreateDescriptorPool(device.device, &create_info, null, &descriptor_pool));
        return .{
            .descriptor_pool = descriptor_pool,
            .device = device,
        };
    }
};

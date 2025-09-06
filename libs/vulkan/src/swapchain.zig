const u = @import("util");
const std = @import("std");
const types = @import("types");
const Device = @import("main.zig").Device;

pub const Swapchain = struct {
    swapchain: types.Khr_swapchain,
    device: *Device,
    
    pub fn deinit(swapchain: *Swapchain) void {
        swapchain.device.call(.khr_destroy_swapchain, .{swapchain.device.device, swapchain.swapchain, null});
    }
    
    pub fn get_images(swapchain: *Swapchain) ![]types.Image {
        var count: u32 = undefined;
        try swapchain.device.call(.khr_get_swapchain_images, .{
            swapchain.device.device,
            swapchain.swapchain,
            &count,
            null,
        });
        
        if (count == 0) {
            return &.{};
        }
        
        const list = u.alloc.alloc(types.Image, count) catch @panic("no memory");
        try swapchain.device.call(.khr_get_swapchain_images, .{
            swapchain.device.device,
            swapchain.swapchain,
            &count,
            list.ptr,
        });
        return list;
    }
    
    pub fn aquire_next_image(swapchain: *Swapchain, semaphore: ?types.Semaphore, fence: ?types.Fence) !u32 {
        var image_index: u32 = undefined;
        const result = swapchain.device.call(.khr_acquire_next_image, .{
            swapchain.device.device,
            swapchain.swapchain,
            std.math.maxInt(u64),
            semaphore orelse types.null_handle,
            fence orelse types.null_handle,
            &image_index,
        });
        result catch |err| switch (err) {
            error.suboptimal => {
                if (fence) |e_fence| {
                    try swapchain.device.wait_for_fence(e_fence, null);
                }
                return err;
            },
            else => return err,
        };
        
        return image_index;
    }
    
    pub fn submit_present(swapchain: *Swapchain, image_index: u32, wait_semaphores: []const types.Semaphore) !void {
        const swapchains = [_]types.Khr_swapchain {
            swapchain.swapchain,
        };
        const image_indexes = [_]u32 {
            image_index,
        };
        const present_info = types.Khr_present_info {
            .wait_semaphore_count = @intCast(wait_semaphores.len),
            .wait_semaphores = wait_semaphores.ptr,
            .swapchain_count = swapchains.len,
            .swapchains = &swapchains,
            .image_indices = &image_indexes,
            .results = null,
        };
        try swapchain.device.call(.khr_queue_present, .{swapchain.device.queue, &present_info});
    }
};

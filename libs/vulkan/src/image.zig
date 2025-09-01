const u = @import("util");
const std = @import("std");
const types = @import("types");
const Device = @import("main.zig").Device;

pub const Image = struct {
    device: *Device,
    image: types.Image,
    memory: types.Device_memory,
    view: types.Image_view,
    
    pub fn deinit(buffer: *Image) void {
        buffer.device.call(.destroy_image_view, .{buffer.device.device, buffer.view, null});
        buffer.device.call(.destroy_image, .{buffer.device.device, buffer.image, null});
        buffer.device.call(.free_memory, .{buffer.device.device, buffer.memory, null});
    }
};

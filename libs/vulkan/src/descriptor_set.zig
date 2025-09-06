const u = @import("util");
const std = @import("std");
const types = @import("types");
const Device = @import("main.zig").Device;

pub const Descriptor_set = struct {
    descriptor_set: types.Descriptor_set,
    device: *Device,
    
    pub fn set_image(desc_set: Descriptor_set, binding: u32, element: u32, descriptor_type: types.Descriptor_type, sampler: types.Sampler, image_view: types.Image_view, image_layout: types.Image_layout) void {
        const image_infos = [_]types.Descriptor_image_info {
            .{
                .sampler = sampler,
                .image_view = image_view,
                .image_layout = image_layout,
            },
        };
        const write_infos = [_]types.Write_descriptor_set {
            .{
                .dst_set = desc_set.descriptor_set,
                .dst_binding = binding,
                .dst_array_element = element,
                .descriptor_count = 1,
                .descriptor_type = descriptor_type,
                .image_info = &image_infos,
                .buffer_info = undefined,
                .texel_buffer_view = undefined,
            },
        };
        desc_set.device.call(.update_descriptor_sets, .{desc_set.device.device, write_infos.len, &write_infos, 0, undefined});
    }
};

pub const Descriptor_pool = struct {
    descriptor_pool: types.Descriptor_pool,
    device: *Device,
    
    pub fn deinit(desc_pool: *Descriptor_pool) void {
        desc_pool.device.call(.destroy_descriptor_pool, .{desc_pool.device.device, desc_pool.descriptor_pool, null});
    }
    
    pub fn reset(desc_pool: *Descriptor_pool) !void {
        try desc_pool.device.call(.reset_descriptor_pool, .{desc_pool.device.device, desc_pool.descriptor_pool, .empty()});
    }
    
    pub fn allocate_descriptor_set(desc_pool: *Descriptor_pool, layout: types.Descriptor_set_layout) !Descriptor_set {
        const layouts = [1]types.Descriptor_set_layout { layout };
        const create_info = types.Descriptor_set_allocate_info {
            .descriptor_pool = desc_pool.descriptor_pool,
            .descriptor_set_count = 1,
            .set_layouts = &layouts,
        };
        var descriptor_sets: [1]types.Descriptor_set = undefined;
        try desc_pool.device.call(.allocate_descriptor_sets, .{desc_pool.device.device, &create_info, &descriptor_sets});
        return .{
            .descriptor_set = descriptor_sets[0],
            .device = desc_pool.device,
        };
    }
};

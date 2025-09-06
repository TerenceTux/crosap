const u = @import("util");
const std = @import("std");
const types = @import("types");
const Device = @import("main.zig").Device;

pub const Graphics_pipeline = struct {
    device: *Device,
    pipeline: types.Pipeline,
    layout: types.Pipeline_layout,
    render_pass: types.Render_pass,
    
    pub const Specialization_info = struct {
        id: u32,
        data: []const u8,
    };
    
    pub const Blend_mode = enum {
        no,
        premultiplied,
    };
    
    pub const Create_info = struct {
        vertex_code: []const u32,
        vertex_specialization: []const Specialization_info,
        fragment_code: []const u32,
        fragment_specialization: []const Specialization_info,
        vertex_bindings: []const types.Vertex_input_binding_description,
        vertex_attributes: []const types.Vertex_input_attribute_description,
        descriptor_set_layouts: []const types.Descriptor_set_layout,
        blend_mode: Blend_mode,
        width: u32,
        height: u32,
        image_format: types.Format,
        keep_previous: bool,
    };
    
    fn create_specialization_entries(specialization: []const Specialization_info) []types.Specialization_map_entry {
        const entries = u.alloc.alloc(types.Specialization_map_entry, specialization.len) catch @panic("no memory");
        var offset: usize = 0;
        for (specialization, entries) |info, *entry| {
            entry.* = .{
                .constant_id = info.id,
                .offset = @intCast(offset),
                .size = info.data.len,
            };
            offset += info.data.len;
        }
        return entries;
    }
    
    fn create_specialization_data(specialization: []const Specialization_info) []u8 {
        var size: usize = 0;
        for (specialization) |info| {
            size += info.data.len;
        }
        const data = u.alloc.alloc(u8, size) catch @panic("no memory");
        var offset: usize = 0;
        for (specialization) |info| {
            @memcpy(data[offset .. offset + info.data.len], info.data);
            offset += info.data.len;
        }
        return data;
    }
    
    pub fn init(device: *Device, create_info: *const Create_info) !Graphics_pipeline {
        var vertex_shader: types.Shader_module = undefined;
        const vertex_shader_info = types.Shader_module_create_info {
            .flags = .empty(),
            .code_size = create_info.vertex_code.len * 4,
            .code = create_info.vertex_code.ptr,
        };
        try device.call(.create_shader_module, .{device.device, &vertex_shader_info, null, &vertex_shader});
        
        var fragment_shader: types.Shader_module = undefined;
        const fragment_shader_info = types.Shader_module_create_info {
            .flags = .empty(),
            .code_size = create_info.fragment_code.len * 4,
            .code = create_info.fragment_code.ptr,
        };
        try device.call(.create_shader_module, .{device.device, &fragment_shader_info, null, &fragment_shader});
        
        var vertex_specialization_info: ?types.Specialization_info = null;
        var vertex_specialization_entries: []types.Specialization_map_entry = undefined;
        var vertex_specialization_data: []u8 = undefined;
        if (create_info.vertex_specialization.len > 0) {
            vertex_specialization_entries = create_specialization_entries(create_info.vertex_specialization);
            vertex_specialization_data = create_specialization_data(create_info.vertex_specialization);
            vertex_specialization_info = .{
                .map_entry_count = @intCast(vertex_specialization_entries.len),
                .map_entries = vertex_specialization_entries.ptr,
                .data_size = vertex_specialization_data.len,
                .data = vertex_specialization_data.ptr,
            };
        }
        defer if (vertex_specialization_info != null) {
            u.alloc.free(vertex_specialization_entries);
            u.alloc.free(vertex_specialization_data);
        };
        var fragment_specialization_info: ?types.Specialization_info = null;
        var fragment_specialization_entries: []types.Specialization_map_entry = undefined;
        var fragment_specialization_data: []u8 = undefined;
        if (create_info.fragment_specialization.len > 0) {
            fragment_specialization_entries = create_specialization_entries(create_info.fragment_specialization);
            fragment_specialization_data = create_specialization_data(create_info.fragment_specialization);
            fragment_specialization_info = .{
                .map_entry_count = @intCast(fragment_specialization_entries.len),
                .map_entries = fragment_specialization_entries.ptr,
                .data_size = fragment_specialization_data.len,
                .data = fragment_specialization_data.ptr,
            };
        }
        defer if (fragment_specialization_info != null) {
            u.alloc.free(fragment_specialization_entries);
            u.alloc.free(fragment_specialization_data);
        };
        const shader_stages = [_]types.Pipeline_shader_stage_create_info {
            .{
                .flags = .empty(),
                .stage = .vertex,
                .module = vertex_shader,
                .name = "main",
                .specialization_info = if (vertex_specialization_info) |info| &info else null,
            },
            .{
                .flags = .empty(),
                .stage = .fragment,
                .module = fragment_shader,
                .name = "main",
                .specialization_info = if (fragment_specialization_info) |info| &info else null,
            },
        };
        
        const dynamic_states = [_]types.Dynamic_state {};
        const dynamic_state = types.Pipeline_dynamic_state_create_info {
            .flags = .empty(),
            .dynamic_state_count = dynamic_states.len,
            .dynamic_states = &dynamic_states,
        };
        
        const vertex_input_info = types.Pipeline_vertex_input_state_create_info {
            .flags = .empty(),
            .vertex_binding_description_count = @intCast(create_info.vertex_bindings.len),
            .vertex_binding_descriptions = create_info.vertex_bindings.ptr,
            .vertex_attribute_description_count = @intCast(create_info.vertex_attributes.len),
            .vertex_attribute_descriptions = create_info.vertex_attributes.ptr,
        };
        
        const primitive_assembly_info = types.Pipeline_input_assembly_state_create_info {
            .flags = .empty(),
            .topology = .triangle_list,
            .primitive_restart_enable = .false,
        };
        
        const tessellation_info = types.Pipeline_tessellation_state_create_info {
            .flags = .empty(),
            .patch_control_points = 0,
        };
        
        const viewports = [_]types.Viewport {
            .{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(create_info.width),
                .height = @floatFromInt(create_info.height),
                .min_depth = 0,
                .max_depth = 1,
            },
        };
        const scissors = [_]types.Rect_2d {
            .{
                .offset = .{.x = 0, .y = 0},
                .extent = .{.width = create_info.width, .height = create_info.height},
            },
        };
        const viewport_info = types.Pipeline_viewport_state_create_info {
            .flags = .empty(),
            .viewport_count = viewports.len,
            .viewports = &viewports,
            .scissor_count = scissors.len,
            .scissors = &scissors,
        };
        
        const rasterize_info = types.Pipeline_rasterization_state_create_info {
            .flags = .empty(),
            .depth_clamp_enable = .false,
            .rasterizer_discard_enable = .false,
            .polygon_mode = .fill,
            .cull_mode = .empty(),
            .front_face = .clockwise,
            .depth_bias_enable = .false,
            .depth_bias_constant_factor = 0,
            .depth_bias_clamp = 0,
            .depth_bias_slope_factor = 0,
            .line_width = 1,
        };
        
        const multisampling_info = types.Pipeline_multisample_state_create_info {
            .flags = .empty(),
            .rasterization_samples = .@"1",
            .sample_shading_enable = .false,
            .min_sample_shading = 1,
            .sample_mask = null,
            .alpha_to_coverage_enable = .false,
            .alpha_to_one_enable = .false,
        };
        
        const attachment_blending = switch (create_info.blend_mode) {
            .no => types.Pipeline_color_blend_attachment_state {
                .blend_enable = .false,
                .src_color_blend_factor = .one,
                .dst_color_blend_factor = .zero,
                .color_blend_op = .add,
                .src_alpha_blend_factor = .one,
                .dst_alpha_blend_factor = .zero,
                .alpha_blend_op = .add,
                .color_write_mask = .create(&.{.r, .g, .b, .a}),
            },
            .premultiplied => types.Pipeline_color_blend_attachment_state {
                .blend_enable = .true,
                .src_color_blend_factor = .one,
                .dst_color_blend_factor = .one_minus_src_alpha,
                .color_blend_op = .add,
                .src_alpha_blend_factor = .zero,
                .dst_alpha_blend_factor = .zero,
                .alpha_blend_op = .add,
                .color_write_mask = .create(&.{.r, .g, .b}),
            },
        };
        const color_blending_info = types.Pipeline_color_blend_state_create_info {
            .flags = .empty(),
            .logic_op_enable = .false,
            .logic_op = .copy,
            .attachment_count = 1,
            .attachments = &.{attachment_blending},
            .blend_constants = .{0, 0, 0, 0},
        };
        
        var layout: types.Pipeline_layout = undefined;
        const push_constant_ranges = [_]types.Push_constant_range {};
        const layout_info = types.Pipeline_layout_create_info {
            .flags = .empty(),
            .set_layout_count = @intCast(create_info.descriptor_set_layouts.len),
            .set_layouts = create_info.descriptor_set_layouts.ptr,
            .push_constant_range_count = push_constant_ranges.len,
            .push_constant_ranges = &push_constant_ranges,
        };
        try device.call(.create_pipeline_layout, .{device.device, &layout_info, null, &layout});
        
        var render_pass: types.Render_pass = undefined;
        const attachments = [_]types.Attachment_description {
            .{
                .flags = .empty(),
                .format = create_info.image_format,
                .samples = .@"1",
                .load_op = if (create_info.keep_previous) .load else .clear,
                .store_op = .store,
                .stencil_load_op = .dont_care,
                .stencil_store_op = .dont_care,
                .initial_layout = if (create_info.keep_previous) .present_src else .undefined,
                .final_layout = .present_src,
            }
        };
        const color_attachments = [_]types.Attachment_reference {
            .{
                .attachment = 0,
                .layout = .color_attachment_optimal,
            }
        };
        const input_attachments = [_]types.Attachment_reference {};
        const preserve_attachments = [_]u32 {};
        const subpasses = [_]types.Subpass_description {
            .{
                .flags = .empty(),
                .pipeline_bind_point = .graphics,
                .input_attachment_count = input_attachments.len,
                .input_attachments = &input_attachments,
                .color_attachment_count = color_attachments.len,
                .color_attachments = &color_attachments,
                .resolve_attachments = null,
                .depth_stencil_attachment = null,
                .preserve_attachment_count = preserve_attachments.len,
                .preserve_attachments = &preserve_attachments,
            }
        };
        const subpass_dependencies = [_]types.Subpass_dependency {};
        const render_pass_info = types.Render_pass_create_info {
            .flags = .empty(),
            .attachment_count = attachments.len,
            .attachments = &attachments,
            .subpass_count = subpasses.len,
            .subpasses = &subpasses,
            .dependency_count = subpass_dependencies.len,
            .dependencies = &subpass_dependencies,
        };
        try device.call(.create_render_pass, .{device.device, &render_pass_info, null, &render_pass});
        
        var pipeline: types.Pipeline = undefined;
        const pipeline_create_info = types.Graphics_pipeline_create_info {
            .flags = .empty(),
            .stage_count = shader_stages.len,
            .stages = &shader_stages,
            .vertex_input_state = &vertex_input_info,
            .input_assembly_state = &primitive_assembly_info,
            .tessellation_state = &tessellation_info,
            .viewport_state = &viewport_info,
            .rasterization_state = &rasterize_info,
            .multisample_state = &multisampling_info,
            .depth_stencil_state = null,
            .color_blend_state = &color_blending_info,
            .dynamic_state = &dynamic_state,
            .layout = layout,
            .render_pass = render_pass,
            .subpass = 0,
            .base_pipeline_handle = undefined,
            .base_pipeline_index = undefined,
        };
        try device.call(.create_graphics_pipelines, .{device.device, types.null_handle, 1, @ptrCast(&pipeline_create_info), null, @ptrCast(&pipeline)});
        
        device.call(.destroy_shader_module, .{device.device, vertex_shader, null});
        device.call(.destroy_shader_module, .{device.device, fragment_shader, null});
        return .{
            .device = device,
            .pipeline = pipeline,
            .layout = layout,
            .render_pass = render_pass,
        };
    }
    
    pub fn deinit(graphics_pipeline: *Graphics_pipeline) void {
        graphics_pipeline.device.call(.destroy_pipeline, .{graphics_pipeline.device.device, graphics_pipeline.pipeline, null});
        graphics_pipeline.device.call(.destroy_pipeline_layout, .{graphics_pipeline.device.device, graphics_pipeline.layout, null});
        graphics_pipeline.device.call(.destroy_render_pass, .{graphics_pipeline.device.device, graphics_pipeline.render_pass, null});
    }
};

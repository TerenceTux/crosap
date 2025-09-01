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
                .constantID = info.id,
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
            .codeSize = create_info.vertex_code.len * 4,
            .pCode = create_info.vertex_code.ptr,
        };
        try device.cal(.create_shader_module, .{device.device, &vertex_shader_info, null, &vertex_shader});
        
        var fragment_shader: types.Shader_module = undefined;
        const fragment_shader_info = types.Shader_module_create_info {
            .flags = .empty(),
            .codeSize = create_info.fragment_code.len * 4,
            .pCode = create_info.fragment_code.ptr,
        };
        try device.call(.create_shader_module, .{device.device, &fragment_shader_info, null, &fragment_shader});
        
        var vertex_specialization_info: ?types.Specialization_info = null;
        var vertex_specialization_entries: []types.Specialization_map_entry = undefined;
        var vertex_specialization_data: []u8 = undefined;
        if (create_info.vertex_specialization.len > 0) {
            vertex_specialization_entries = create_specialization_entries(create_info.vertex_specialization);
            vertex_specialization_data = create_specialization_data(create_info.vertex_specialization);
            vertex_specialization_info = .{
                .mapEntryCount = @intCast(vertex_specialization_entries.len),
                .pMapEntries = vertex_specialization_entries.ptr,
                .dataSize = vertex_specialization_data.len,
                .pData = vertex_specialization_data.ptr,
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
                .mapEntryCount = @intCast(fragment_specialization_entries.len),
                .pMapEntries = fragment_specialization_entries.ptr,
                .dataSize = fragment_specialization_data.len,
                .pData = fragment_specialization_data.ptr,
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
                .pName = "main",
                .pSpecializationInfo = if (vertex_specialization_info) |info| &info else null,
            },
            .{
                .flags = .empty(),
                .stage = .fragment,
                .module = fragment_shader,
                .pName = "main",
                .pSpecializationInfo = if (fragment_specialization_info) |info| &info else null,
            },
        };
        
        const dynamic_states = [_]types.Dynamic_state {};
        const dynamic_state = types.Pipeline_dynamic_state_create_info {
            .flags = .empty(),
            .dynamicStateCount = dynamic_states.len,
            .pDynamicStates = &dynamic_states,
        };
        
        const vertex_input_info = types.Pipeline_vertex_input_state_create_info {
            .flags = .empty(),
            .vertexBindingDescriptionCount = @intCast(create_info.vertex_bindings.len),
            .pVertexBindingDescriptions = create_info.vertex_bindings.ptr,
            .vertexAttributeDescriptionCount = @intCast(create_info.vertex_attributes.len),
            .pVertexAttributeDescriptions = create_info.vertex_attributes.ptr,
        };
        
        const primitive_assembly_info = types.Pipeline_input_assembly_state_create_info {
            .flags = .empty(),
            .topology = .triangle_list,
            .primitiveRestartEnable = .false,
        };
        
        const tessellation_info = types.Pipeline_tessellation_state_create_info {
            .flags = .empty(),
            .patchControlPoints = 0,
        };
        
        const viewports = [_]types.Viewport {
            .{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(create_info.width),
                .height = @floatFromInt(create_info.height),
                .minDepth = 0,
                .maxDepth = 1,
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
            .viewportCount = viewports.len,
            .pViewports = &viewports,
            .scissorCount = scissors.len,
            .pScissors = &scissors,
        };
        
        const rasterize_info = types.Pipeline_rasterization_state_create_info {
            .flags = .empty(),
            .depthClampEnable = .false,
            .rasterizerDiscardEnable = .false,
            .polygonMode = .fill,
            .cullMode = .empty(),
            .frontFace = .clockwise,
            .depthBiasEnable = .false,
            .depthBiasConstantFactor = 0,
            .depthBiasClamp = 0,
            .depthBiasSlopeFactor = 0,
            .lineWidth = 1,
        };
        
        const multisampling_info = types.Pipeline_multisample_state_create_info {
            .flags = .empty(),
            .rasterizationSamples = .sample_1,
            .sampleShadingEnable = .false,
            .minSampleShading = 1,
            .pSampleMask = null,
            .alphaToCoverageEnable = .false,
            .alphaToOneEnable = .false,
        };
        
        const attachment_blending = switch (create_info.blend_mode) {
            .no => types.Pipeline_color_blend_attachment_state {
                .blendEnable = .false,
                .srcColorBlendFactor = .one,
                .dstColorBlendFactor = .zero,
                .colorBlendOp = .add,
                .srcAlphaBlendFactor = .one,
                .dstAlphaBlendFactor = .zero,
                .alphaBlendOp = .add,
                .colorWriteMask = .create(&.{.r, .g, .b, .a}),
            },
            .premultiplied => types.Pipeline_color_blend_attachment_state {
                .blendEnable = .true,
                .srcColorBlendFactor = .one,
                .dstColorBlendFactor = .one_minus_src_alpha,
                .colorBlendOp = .add,
                .srcAlphaBlendFactor = .zero,
                .dstAlphaBlendFactor = .zero,
                .alphaBlendOp = .add,
                .colorWriteMask = .create(&.{.r, .g, .b}),
            },
        };
        const color_blending_info = types.Pipeline_color_blend_state_create_info {
            .flags = .empty(),
            .logicOpEnable = .false,
            .logicOp = .copy,
            .attachmentCount = 1,
            .pAttachments = &.{attachment_blending},
            .blendConstants = .{0, 0, 0, 0},
        };
        
        var layout: types.Pipeline_layout = undefined;
        const push_constant_ranges = [_]types.Push_constant_range {};
        const layout_info = types.Pipeline_layout_create_info {
            .flags = .empty(),
            .setLayoutCount = @intCast(create_info.descriptor_set_layouts.len),
            .pSetLayouts = create_info.descriptor_set_layouts.ptr,
            .pushConstantRangeCount = push_constant_ranges.len,
            .pPushConstantRanges = &push_constant_ranges,
        };
        try device.call(.create_pipeline_layout, .{device.device, &layout_info, null, &layout});
        
        var render_pass: types.Render_pass = undefined;
        const attachments = [_]types.Attachment_description {
            .{
                .flags = .empty(),
                .format = create_info.image_format,
                .samples = .sample_1,
                .loadOp = if (create_info.keep_previous) .load else .clear,
                .storeOp = .store,
                .stencilLoadOp = .dont_care,
                .stencilStoreOp = .dont_care,
                .initialLayout = if (create_info.keep_previous) .present_src else .undefined,
                .finalLayout = .present_src,
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
                .pipelineBindPoint = .graphics,
                .inputAttachmentCount = input_attachments.len,
                .pInputAttachments = &input_attachments,
                .colorAttachmentCount = color_attachments.len,
                .pColorAttachments = &color_attachments,
                .pResolveAttachments = null,
                .pDepthStencilAttachment = null,
                .preserveAttachmentCount = preserve_attachments.len,
                .pPreserveAttachments = &preserve_attachments,
            }
        };
        const subpass_dependencies = [_]types.Subpass_dependency {};
        const render_pass_info = types.Render_pass_create_info {
            .flags = .empty(),
            .attachmentCount = attachments.len,
            .pAttachments = &attachments,
            .subpassCount = subpasses.len,
            .pSubpasses = &subpasses,
            .dependencyCount = subpass_dependencies.len,
            .pDependencies = &subpass_dependencies,
        };
        try device.call(.create_render_pass, .{device.device, &render_pass_info, null, &render_pass});
        
        var pipeline: types.Pipeline = undefined;
        const pipeline_create_info = types.Graphics_pipeline_create_info {
            .flags = .empty(),
            .stageCount = shader_stages.len,
            .pStages = &shader_stages,
            .pVertexInputState = &vertex_input_info,
            .pInputAssemblyState = &primitive_assembly_info,
            .pTessellationState = &tessellation_info,
            .pViewportState = &viewport_info,
            .pRasterizationState = &rasterize_info,
            .pMultisampleState = &multisampling_info,
            .pDepthStencilState = null,
            .pColorBlendState = &color_blending_info,
            .pDynamicState = &dynamic_state,
            .layout = layout,
            .renderPass = render_pass,
            .subpass = 0,
            .basePipelineHandle = undefined,
            .basePipelineIndex = undefined,
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

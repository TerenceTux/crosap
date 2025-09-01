const u = @import("util");
const std = @import("std");
const types = @import("types");
const Device = @import("main.zig").Device;

pub const Task = struct {
    command_buffer: types.Command_buffer,
    command_pool: types.Command_pool,
    device: *Device,
    
    pub fn deinit(task: *Task) void {
        const command_buffers = [_]types.Command_buffer {
            task.command_buffer,
        };
        task.device.call(.free_command_buffers, .{task.device.device, task.command_pool, command_buffers.len, &command_buffers});
    }
    
    pub fn start_recording(task: *Task, submit_once: bool) !void {
        const flags: types.Command_buffer_usage_flags = if (submit_once) .just(.one_time_submit) else .empty();
        const begin_info = types.Command_buffer_begin_info {
            .flags = flags,
            .pInheritanceInfo = undefined,
        };
        try task.device.call(.begin_command_buffer, .{task.command_buffer, &begin_info});
    }
    
    pub fn end_recording(task: *Task) !void {
        try task.device.call(.end_command_buffer, .{task.command_buffer});
    }
    
    pub fn reset(task: *Task) !void {
        try task.device.call(.reset_command_buffer, .{task.command_buffer, .empty()});
    }
    
    pub fn submit(task: *Task, wait_semaphores: []const types.Semaphore, signal_semaphore: ?types.Semaphore, signal_fence: ?types.Fence) !void {
        var one_wait_mask = [_] types.Pipeline_stage_flags { .just(.top_of_pipe) };
        var wait_mask: []types.pipeline_stage_flags = &one_wait_mask;
        if (wait_semaphores.len > one_wait_mask.len) {
            wait_mask = u.alloc.alloc(types.Pipeline_stage_flags, wait_semaphores.len) catch @panic("no memory");
            for (wait_mask) |*item| {
                item.* = .just(.top_of_pipe);
            }
        }
        defer if (wait_semaphores.len > one_wait_mask.len) {
            u.alloc.free(wait_mask);
        };
        
        const command_buffers = [_]types.Command_buffer {
            task.command_buffer,
        };
        const signal_semaphores = [1]types.Semaphore {
            signal_semaphore orelse undefined,
        };
        const submits = [_]types.Submit_info {
            .{
                .waitSemaphoreCount = @intCast(wait_semaphores.len),
                .pWaitSemaphores = wait_semaphores.ptr,
                .pWaitDstStageMask = wait_mask.ptr,
                .commandBufferCount = command_buffers.len,
                .pCommandBuffers = &command_buffers,
                .signalSemaphoreCount = if (signal_semaphore != null) 1 else 0,
                .pSignalSemaphores = &signal_semaphores,
            }
        };
        try task.device.call(.queue_submit, .{task.device.queue, submits.len, &submits, signal_fence orelse types.null_handle});
    }
    
    pub fn start_render_pass(task: *Task, framebuffer: types.Framebuffer, render_size: types.Extent_2d, render_pass: types.Render_pass, clear_values: []const types.Clear_value) void {
        const render_info = types.Render_pass_begin_info {
            .renderPass = render_pass,
            .framebuffer = framebuffer,
            .renderArea = .{
                .offset = .{.x = 0, .y = 0},
                .extent = render_size,
            },
            .clearValueCount = @intCast(clear_values.len),
            .pClearValues = clear_values.ptr,
        };
        task.device.call(.cmd_begin_render_pass, .{task.command_buffer, &render_info, .content_inline});
    }
    
    pub fn end_render_pass(task: *Task) void {
        task.device.call(.cmd_end_render_pass, .{task.command_buffer});
    }
    
    pub fn bind_pipeline(task: *Task, kind: types.Pipeline_bind_point, pipeline: types.Pipeline) void {
        task.device.call(.cmd_bind_pipeline, .{task.command_buffer, kind, pipeline});
    }
    
    pub fn bind_vertex_buffer(task: *Task, binding: u32, buffer: types.Buffer) void {
        const buffers = [_]types.Buffer { buffer };
        const offsets = [_]types.Device_size { 0 };
        task.device.call(.cmd_bind_vertex_buffers, .{task.command_buffer, binding, 1, &buffers, &offsets});
    }
    
    pub fn bind_index_buffer(task: *Task, buffer: types.Buffer) void {
        task.device.call(.cmd_bind_index_buffer, .{task.command_buffer, buffer, 0, .uint16});
    }
    
    pub fn bind_descriptor_set(task: *Task, kind: types.Pipeline_bind_point, layout: types.Pipeline_layout, set_number: u32, descriptor_set: types.Descriptor_set) void {
        const descriptor_sets = [_]types.Descriptor_set {
            descriptor_set,
        };
        task.device.call(.cmd_bind_descriptor_sets, .{task.command_buffer, kind, layout, set_number, descriptor_sets.len, &descriptor_sets, 0, undefined});
    }
    
    pub fn draw(task: *Task, first_instance: u32, instance_count: u32, first_vertex: u32, vertex_count: u32) void {
        task.device.call(.cmd_draw, .{task.command_buffer, vertex_count, instance_count, first_vertex, first_instance});
    }
    
    pub fn draw_indexed(task: *Task, first_instance: u32, instance_count: u32, first_index: u32, index_count: u32, vertex_offset: i32) void {
        task.device.call(.cmd_draw_indexed, .{task.command_buffer, index_count, instance_count, first_index, vertex_offset, first_instance});
    }
    
    pub fn draw_indirect(task: *Task, buffer: types.Buffer, offset: types.Device_size, draw_count: u32, stride: u32) void {
        task.device.call(.cmd_draw_indirect, .{task.command_buffer, buffer, offset, draw_count, stride});
    }
    
    pub fn draw_indexed_indirect(task: *Task, buffer: types.Buffer, offset: types.Device_size, draw_count: u32, stride: u32) void {
        task.device.call(.cmd_draw_indexed_indirect, .{task.command_buffer, buffer, offset, draw_count, stride});
    }
    
    pub fn copy_buffer(task: *Task, size: usize, source: types.Buffer, source_offset: usize, destination: types.Buffer, destination_offset: usize) void {
        const regions = [_]types.Buffer_copy {
            .{
                .srcOffset = source_offset,
                .dstOffset = destination_offset,
                .size = size,
            },
        };
        task.device.call(.cmd_copy_buffer, .{task.command_buffer, source, destination, regions.len, &regions});
    }
    
    pub fn copy_buffer_to_image(task: *Task, buffer: types.Buffer, image: types.Image, offset_x: u32, offset_y: u32, width: u32, height: u32) void {
        const regions = [_]types.Buffer_image_copy {
            .{
                .bufferOffset = 0,
                .bufferRowLength = 0,
                .bufferImageHeight = 0,
                .imageSubresource = .{
                    .aspectMask = .just(.color),
                    .mipLevel = 0,
                    .baseArrayLayer = 0,
                    .layerCount = 1,
                },
                .imageOffset = .{
                    .x = @intCast(offset_x),
                    .y = @intCast(offset_y),
                    .z = 0,
                },
                .imageExtent = .{
                    .width = width,
                    .height = height,
                    .depth = 1,
                },
            }
        };
        task.device.call(.cmd_copy_buffer_to_image, .{task.command_buffer, buffer, image, .transfer_dst_optimal, regions.len, &regions});
    }
    
    pub fn barrier(
        task: *Task, after_stages: types.Pipeline_stage_flags, before_stages: types.Pipeline_stage_flags,
        memory_barriers: []const types.Memory_barrier, buffer_barriers: []const types.Buffer_memory_barrier, image_barriers: []const types.Image_memory_barrier
    ) void {
        task.device.call(.cmd_pipeline_barrier, .{
            task.command_buffer,
            after_stages, before_stages,
            .empty(),
            @intCast(memory_barriers.len), memory_barriers.ptr,
            @intCast(buffer_barriers.len), buffer_barriers.ptr,
            @intCast(image_barriers.len), image_barriers.ptr,
        });
    }
};

pub const Task_allocator = struct {
    command_pool: types.Command_pool,
    device: *Device,
    
    pub fn deinit(task_allocator: *Task_allocator) void {
        task_allocator.device.call(.destroy_command_pool, .{task_allocator.device.device, task_allocator.command_pool, null});
    }
    
    pub fn create_task(task_allocator: *Task_allocator) !Task {
        const create_info = types.Command_buffer_allocate_info {
            .commandPool = task_allocator.command_pool,
            .level = .primary,
            .commandBufferCount = 1,
        };
        var command_buffer: types.Command_buffer = undefined;
        try task_allocator.device.call(.allocate_command_buffers, .{task_allocator.device.device, &create_info, @ptrCast(&command_buffer)});
        return .{
            .command_buffer = command_buffer,
            .command_pool = task_allocator.command_pool,
            .device = task_allocator.device,
        };
    }
};

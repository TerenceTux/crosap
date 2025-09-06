const u = @import("util");
const std = @import("std");
const types = @import("types");
const Device = @import("main.zig").Device;

pub const Buffer = struct {
    device: *Device,
    buffer: types.Buffer,
    memory: types.Device_memory,
    size: usize,
    mapped: ?[*]volatile u8,
    coherent: bool,
    
    pub fn deinit(buffer: *Buffer) void {
        if (buffer.mapped) |_| {
            buffer.device.call(.unmap_memory, .{buffer.device.device, buffer.memory});
        }
        buffer.device.call(.destroy_buffer, .{buffer.device.device, buffer.buffer, null});
        buffer.device.call(.free_memory, .{buffer.device.device, buffer.memory, null});
    }
    
    pub fn flush_region(buffer: *Buffer, offset: usize, size: usize) !void {
        if (!buffer.coherent) {
            const ranges = [_]types.Mapped_memory_range {
                .{
                    .memory = buffer.memory,
                    .offset = offset,
                    .size = if (size == buffer.size) types.whole_size else size,
                },
            };
            try buffer.device.call(.flush_mapped_memory_ranges, .{buffer.device.device, ranges.len, &ranges});
        }
    }
    
    pub fn flush_whole(buffer: *Buffer) void {
        buffer.flush_region(0, buffer.size);
    }
};

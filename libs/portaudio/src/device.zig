const u = @import("util");
const std = @import("std");
const types = @import("types.zig");
const Portaudio = @import("main.zig").Portaudio;
const Stream = @import("stream.zig").Stream;
const stream_callback = @import("main.zig").stream_callback;


pub const Device = struct {
    pa: *Portaudio,
    index: types.Device_index,
    name: []const u8,
    host_api_index: types.Host_api_index,
    max_input_channels: u32,
    max_output_channels: u32,
    default_low_input_latency: f64,
    default_low_output_latency: f64,
    default_high_input_latency: f64,
    default_high_output_latency: f64,
    default_sample_rate: f64,
    
    pub fn create_output_stream(device: *Device, stream: *Stream, channel_count: u32, sample_format: types.Sample_format, suggested_latency: f64, sample_rate: f64, frames_per_buffer: ?usize, stream_flags: types.Stream_flags, callback: stream_callback.Dynamic_interface) !void {
        try device.pa.create_stream(stream, null, .{
            .device = device,
            .channel_count = channel_count,
            .sample_format = sample_format,
            .suggested_latency = suggested_latency,
        }, sample_rate, frames_per_buffer, stream_flags, callback);
    }
    
    pub fn create_default_output_stream(device: *Device, stream: *Stream, channel_count: u32, sample_format: types.Sample_format, sample_rate: f64, callback: stream_callback.Dynamic_interface) !void {
        var latency: f64 = 0.01;
        if (device.default_low_input_latency > latency) {
            latency = device.default_low_input_latency;
        }
        try device.create_output_stream(stream, channel_count, sample_format, latency, sample_rate, null, .just(.prime_output_buffers_using_stream_callback), callback);
    }
};

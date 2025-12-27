const u = @import("util");
const std = @import("std");
const types = @import("types.zig");
const Portaudio = @import("main.zig").Portaudio;
const stream_callback = @import("main.zig").stream_callback;


pub const Stream = struct {
    pa: *Portaudio,
    stream: *types.Stream,
    callback: stream_callback.Dynamic_interface,
    input_latency: f64,
    output_latency: f64,
    sample_rate: f64,
    
    pub fn pa_callback(input: [*]const u8, output: [*]u8, frame_count: c_long, time_info: *const types.Stream_callback_time_info, status_flags: types.Stream_callback_flags, user_data: ?*anyopaque) callconv(.c) types.Stream_callback_result {
        const stream: *Stream = @ptrCast(@alignCast(user_data));
        return stream.callback.call(.{input, output, @intCast(frame_count), time_info, status_flags});
    }
    
    pub fn close(stream: *Stream) void {
        stream.pa.fns.Pa_CloseStream(stream.stream).ignore();
    }
    
    pub fn start(stream: *Stream) !void {
        try stream.pa.fns.Pa_StartStream(stream.stream).handle();
    }
    
    pub fn stop(stream: *Stream) !void {
        try stream.pa.fns.Pa_StopStream(stream.stream).handle();
    }
    
    pub fn abort(stream: *Stream) !void {
        try stream.pa.fns.Pa_AbortStream(stream.stream).handle();
    }
};

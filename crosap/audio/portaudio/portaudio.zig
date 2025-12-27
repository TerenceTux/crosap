const u = @import("util");
const std = @import("std");
const lib_portaudio = @import("lib_portaudio");

pub const Audio = struct {
    portaudio: lib_portaudio.Portaudio,
    device: lib_portaudio.Device,
    stream: lib_portaudio.Stream,
    stream_callback: Stream_callback,
    
    const Stream_callback = struct {
        a: *Audio,
        
        pub fn call(callback: *Stream_callback, input: [*]const u8, output: [*]u8, frame_count: usize, time_info: *const lib_portaudio.types.Stream_callback_time_info, status_flags: lib_portaudio.types.Stream_callback_flags) lib_portaudio.types.Stream_callback_result {
            const output_i8: [*]i16 = @ptrCast(@alignCast(output));
            const output_frames = output_i8[0..frame_count];
            for (output_frames) |*sample| {
                sample.* = u.random.int(i16);
            }
            _ = input;
            _ = callback;
            _ = time_info;
            _ = status_flags;
            return .cont;
        }
    };
    
    pub fn init(a: *Audio) !void {
        try a.portaudio.init();
        
        if (u.debug) {
            const default_host_api = a.portaudio.get_default_host_api_index();
            const default_output_device = a.portaudio.get_default_output_device_index();
            const default_input_device = a.portaudio.get_default_input_device_index();
            const host_apis = a.portaudio.get_host_apis();
            defer u.free_slice(host_apis);
            u.log_start(.{"Host api's (",host_apis.len,"):"});
            var host_api_index: c_int = 0;
            for (host_apis) |host_api| {
                u.log_start(.{host_api.name});
                if (host_api_index == default_host_api) {
                    u.log(.{"This is the default host api"});
                }
                const devices = host_api.get_devices();
                defer u.free_slice(devices);
                u.log_start(.{"Devices (",devices.len,"):"});
                for (devices) |device| {
                    u.log_start(.{device.name});
                    if (device.index == default_output_device) {
                        u.log(.{"This is the global default output device"});
                    }
                    if (device.index == default_input_device) {
                        u.log(.{"This is the global default input device"});
                    }
                    if (device.index == host_api.default_output_device) {
                        u.log(.{"This is the default output device of this host api"});
                    }
                    if (device.index == host_api.default_input_device) {
                        u.log(.{"This is the default input device of this host api"});
                    }
                    
                    u.log(.{"Max input channels: ",device.max_input_channels});
                    u.log(.{"Max output channels: ",device.max_output_channels});
                    u.log(.{"Default low input latency: ",device.default_low_input_latency});
                    u.log(.{"Default low output latency: ",device.default_low_output_latency});
                    u.log(.{"Default high input latency: ",device.default_high_input_latency});
                    u.log(.{"Default high output latency: ",device.default_high_output_latency});
                    u.log(.{"Default sample rate: ",device.default_sample_rate});
                    
                    u.log_end(.{});
                }
                u.log_end(.{});
                u.log_end(.{});
                host_api_index += 1;
            }
            u.log_end(.{});
        }
        
        var best_index = a.portaudio.get_default_output_device_index();
        var current_index: c_int = 0;
        const device_count = a.portaudio.get_device_count();
        while (current_index < device_count): (current_index += 1) {
            const device = a.portaudio.get_device_by_index(current_index);
            if (std.mem.eql(u8, device.name, "pipewire")) {
                best_index = current_index;
                break;
            }
        }
        a.device = a.portaudio.get_device_by_index(best_index);
        u.log(.{"Using default output device: ",a.device.name});
        
        a.stream_callback = .{
            .a = a,
        };
        try a.device.create_default_output_stream(&a.stream, 2, .int_16, 48000, lib_portaudio.stream_callback.dynamic(&a.stream_callback));
        u.log(.{"Created output stream with sample rate ",a.stream.sample_rate," and output latency ",a.stream.output_latency});
        try a.stream.start();
    }
    
    pub fn deinit(a: *Audio) void {
        a.stream.close();
        a.portaudio.deinit();
    }
    
    pub fn send(a: *Audio, buffer: []const u8) !void {
        _ = a;
        _ = buffer;
    }
};

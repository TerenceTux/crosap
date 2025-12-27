const u = @import("util");
const std = @import("std");
const builtin = @import("builtin");
pub const types = @import("types.zig");
const static_linked = @import("options").static_linked;
const portaudio_c = @import("portaudio_c");

const lib_paths = switch(builtin.os.tag) {
    .linux => [_][]const u8 {
        "libportaudio.so.2",
        "libportaudio.so",
        //"/usr/lib/libglfw.so",
        //"/usr/lib/libglfw.so.3",
    },
    .windows => [_][]const u8 {
        "portaudio.dll",
    },
    else => [_][]const u8 {},
};

const supported_version = 19;

pub const stream_callback = u.callback(fn(input: [*]const u8, output: [*]u8, frame_count: usize, time_info: *const types.Stream_callback_time_info, status_flags: types.Stream_callback_flags) types.Stream_callback_result);

pub const Portaudio = struct {
    dynlib: if (static_linked) void else std.DynLib,
    fns: types.Functions,
    
    pub fn init(pa: *Portaudio) !void {
        if (comptime static_linked) {
            u.log("Loading static portaudio functions");
            inline for (@typeInfo(@TypeOf(pa.fns)).@"struct".fields) |field| {
                const c_fn = &@field(portaudio_c, field.name);
                @field(pa.fns, field.name) = @ptrCast(c_fn);
            }
            
        } else {
            u.log("Finding the dynamic portaudio libary");
            pa.dynlib = try find_dynlib();
            
            u.log("Loading functions");
            inline for (@typeInfo(@TypeOf(pa.fns)).@"struct".fields) |field| {
                const fn_type = @TypeOf(@field(pa.fns, field.name));
                const fn_ptr = pa.dynlib.lookup(fn_type, field.name);
                if (fn_ptr == null) {
                    u.log(.{"Error getting function ",field.name});
                    return error.function_not_available;
                }
                
                @field(pa.fns, field.name) = fn_ptr orelse unreachable;
            }
        }
        try pa.fns.Pa_Initialize().handle();
        const version_info = pa.fns.Pa_GetVersionInfo();
        u.log(.{"Initialized portaudio ",version_info.major," ",version_info.minor," ",version_info.sub_minor," [",version_info.control_revision,"] (\"",version_info.text,"\")"});
        if (version_info.major < supported_version) {
            u.log(.{"This portaudio version is too old, I need version ",supported_version});
            return error.portaudio_too_old;
        }
        if (version_info.major > supported_version) {
            u.log(.{"This portaudio version is newer than the version this application was made for (",supported_version,")"});
        }
    }
    
    fn find_dynlib() !std.DynLib {
        for (lib_paths) |path| {
            if (std.DynLib.open(path)) |dyn_lib| {
                return dyn_lib;
            } else |_| {}
        }
        return error.not_found;
    }
    
    pub fn deinit(pa: *Portaudio) void {
        pa.fns.Pa_Terminate().ignore();
        if (comptime !static_linked) {
            pa.dynlib.close();
        }
    }
    
    pub fn host_api_count(pa: *Portaudio) c_int {
        return pa.fns.Pa_GetHostApiCount();
    }
    
    pub fn get_host_api_by_index(pa: *Portaudio, index: c_int) Host_api {
        const host_api_info = pa.fns.Pa_GetHostApiInfo(index);
        return .{
            .pa = pa,
            .index = index,
            .type = host_api_info.type,
            .name = std.mem.span(host_api_info.name),
            .device_count = host_api_info.device_count,
            .default_input_device = host_api_info.default_input_device,
            .default_output_device = host_api_info.default_output_device,
        };
    }
    
    pub fn get_default_host_api_index(pa: *Portaudio) c_int {
        return pa.fns.Pa_GetDefaultHostApi();
    }
    
    pub fn get_default_host_api(pa: *Portaudio) Host_api {
        return pa.get_host_api_by_index(pa.get_default_host_api_index());
    }
    
    // free with u.free_slice please
    pub fn get_host_apis(pa: *Portaudio) []Host_api {
        const count = pa.host_api_count();
        const host_apis = u.alloc_slice(Host_api, @intCast(count));
        for (host_apis, 0..) |*host_api, index| {
            host_api.* = pa.get_host_api_by_index(@intCast(index));
        }
        return host_apis;
    }
    
    pub fn get_device_by_index(pa: *Portaudio, index: c_int) Device {
        const device_info = pa.fns.Pa_GetDeviceInfo(index);
        return .{
            .pa = pa,
            .index = index,
            .name = std.mem.span(device_info.name),
            .host_api_index = device_info.host_api,
            .max_input_channels = @intCast(device_info.max_input_channels),
            .max_output_channels = @intCast(device_info.max_output_channels),
            .default_low_input_latency = device_info.default_low_input_latency,
            .default_low_output_latency = device_info.default_low_output_latency,
            .default_high_input_latency = device_info.default_high_input_latency,
            .default_high_output_latency = device_info.default_high_output_latency,
            .default_sample_rate = device_info.default_sample_rate,
        };
    }
    
    pub fn get_default_output_device_index(pa: *Portaudio) c_int {
        return pa.fns.Pa_GetDefaultOutputDevice();
    }
    
    pub fn get_default_input_device_index(pa: *Portaudio) c_int {
        return pa.fns.Pa_GetDefaultInputDevice();
    }
    
    pub fn get_device_count(pa: *Portaudio) c_int {
        return pa.fns.Pa_GetDeviceCount();
    }
    
    pub fn get_default_output_device(pa: *Portaudio) Device {
        return pa.get_device_by_index(pa.get_default_output_device_index());
    }
    
    pub fn get_default_input_device(pa: *Portaudio) Device {
        return pa.get_device_by_index(pa.get_default_index_device_index());
    }
    
    const Stream_parameters = struct {
        device: *const Device,
        channel_count: u32,
        sample_format: types.Sample_format,
        suggested_latency: f64,
        
        pub fn to_pa_parameters(params: Stream_parameters) types.Stream_parameters {
            return .{
                .device = params.device.index,
                .channel_count = @intCast(params.channel_count),
                .sample_format = params.sample_format,
                .suggested_latency = params.suggested_latency,
                .host_api_specific_stream_info = null,
            };
        }
    };
    
    pub fn create_stream(pa: *Portaudio, stream: *Stream, input_parameters: ?Stream_parameters, output_parameters: ?Stream_parameters, sample_rate: f64, frames_per_buffer: ?usize, stream_flags: types.Stream_flags, callback: stream_callback.Dynamic_interface) !void {
        var pa_stream: *types.Stream = undefined;
        const pa_in_parameters = if (input_parameters) |in_param| in_param.to_pa_parameters() else undefined;
        const pa_out_parameters = if (output_parameters) |out_param| out_param.to_pa_parameters() else undefined;
        try pa.fns.Pa_OpenStream(
            &pa_stream,
            if (input_parameters != null) &pa_in_parameters else null,
            if (output_parameters != null) &pa_out_parameters else null,
            sample_rate,
            @intCast(frames_per_buffer orelse 0),
            stream_flags,
            &Stream.pa_callback,
            stream,
        ).handle();
        
        stream.pa = pa;
        stream.stream = pa_stream;
        stream.callback = callback;
        const stream_info = pa.fns.Pa_GetStreamInfo(pa_stream);
        stream.input_latency = stream_info.input_latency;
        stream.output_latency = stream_info.output_latency;
        stream.sample_rate = stream_info.sample_rate;
    }
};

pub const Host_api = @import("host_api.zig").Host_api;
pub const Device = @import("device.zig").Device;
pub const Stream = @import("stream.zig").Stream;

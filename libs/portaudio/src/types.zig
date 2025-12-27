const u = @import("util");

pub const Functions = struct {
    Pa_GetVersion: *const fn(
    ) callconv(.c) c_int,
    
    // Pa_GetVersionText is deprecated
    
    Pa_GetVersionInfo: *const fn(
    ) callconv(.c) *const Version_info,
    
    Pa_GetErrorText: *const fn(
        errorCode: Error,
    ) callconv(.c) [*:0]u8,
    
    Pa_Initialize: *const fn(
    ) callconv(.c) Error,
    
    Pa_Terminate: *const fn(
    ) callconv(.c) Error,
    
    Pa_GetHostApiCount: *const fn(
    ) callconv(.c) Host_api_index,
    
    Pa_GetDefaultHostApi: *const fn(
    ) callconv(.c) Host_api_index,
    
    Pa_GetHostApiInfo: *const fn(
        host_api: Host_api_index,
    ) callconv(.c) *const Host_api_info,
    
    Pa_HostApiTypeIdToHostApiIndex: *const fn(
        type: Host_api_type_id,
    ) callconv(.c) Host_api_index,
    
    Pa_HostApiDeviceIndexToDeviceIndex: *const fn(
        host_api: Host_api_index,
        host_api_device_index: c_int,
    ) callconv(.c) Device_index,
    
    Pa_GetLastHostErrorInfo: *const fn(
    ) callconv(.c) *const Host_error_info,
    
    Pa_GetDeviceCount: *const fn(
    ) callconv(.c) Device_index,
    
    Pa_GetDefaultInputDevice: *const fn(
    ) callconv(.c) Device_index,
    
    Pa_GetDefaultOutputDevice: *const fn(
    ) callconv(.c) Device_index,
    
    Pa_GetDeviceInfo: *const fn(
        device: Device_index,
    ) callconv(.c) *const Device_info,
    
    Pa_IsFormatSupported: *const fn(
        input_parameters: ?*const Stream_parameters,
        output_parameters: ?*const Stream_parameters,
        sample_rate: f64,
    ) callconv(.c) Error, // no error means supported
    
    Pa_OpenStream: *const fn(
        stream: **Stream,
        input_parameters: ?*const Stream_parameters,
        output_parameters: ?*const Stream_parameters,
        sample_rate: f64,
        frames_per_buffer: c_long,
        stream_flags: Stream_flags,
        stream_callback: Stream_callback,
        user_data: ?*anyopaque,
    ) callconv(.c) Error,
    
    Pa_OpenDefaultStream: *const fn(
        stream: **Stream,
        num_input_channels: c_int,
        num_output_channels: c_int,
        sample_format: Sample_format,
        sample_rate: f64,
        frames_per_buffer: c_long,
        stream_callback: Stream_callback,
        user_data: ?*anyopaque,
    ) callconv(.c) Error,
    
    Pa_CloseStream: *const fn(
        stream: *Stream,
    ) callconv(.c) Error,
    
    Pa_SetStreamFinishedCallback: *const fn(
        stream: *Stream,
        stream_finished_callback: Stream_finished_callback,
    ) callconv(.c) Error,
    
    Pa_StartStream: *const fn(
        stream: *Stream,
    ) callconv(.c) Error,
    
    Pa_StopStream: *const fn(
        stream: *Stream,
    ) callconv(.c) Error,
    
    Pa_AbortStream: *const fn(
        stream: *Stream,
    ) callconv(.c) Error,
    
    Pa_IsStreamStopped: *const fn(
        stream: *Stream,
    ) callconv(.c) c_int, // 1, 0, or Error
    
    Pa_IsStreamActive: *const fn(
        stream: *Stream,
    ) callconv(.c) c_int, // 1, 0, or Error
    
    Pa_GetStreamInfo: *const fn(
        stream: *Stream,
    ) callconv(.c) *const Stream_info,
    
    Pa_GetStreamTime: *const fn(
        stream: *Stream,
    ) callconv(.c) Time,
    
    Pa_GetStreamCpuLoad: *const fn(
        stream: *Stream,
    ) callconv(.c) f64,
    
    Pa_ReadStream: *const fn(
        stream: *Stream,
        buffer: [*]u8,
        frames: c_ulong,
    ) callconv(.c) Error,
    
    Pa_WriteStream: *const fn(
        stream: *Stream,
        buffer: [*]const u8,
        frames: c_ulong,
    ) callconv(.c) Error,
    
    Pa_GetStreamReadAvailable: *const fn(
        stream: *Stream
    ) callconv(.c) c_long,
    
    Pa_GetStreamWriteAvailable: *const fn(
        stream: *Stream,
    ) callconv(.c) c_long,
    
    Pa_GetSampleSize: *const fn(
        format: Sample_format,
    ) callconv(.c) c_int, // or Error.sample_format_not_supported
    
    // Zig has own alternative for Pa_Sleep
};


pub const Version_info = extern struct {
    major: c_int,
    minor: c_int,
    sub_minor: c_int,
    control_revision: [*:0]u8,
    text: [*:0]u8,
};

pub const Host_api_info = extern struct {
    struct_version: c_int, // 1
    type: Host_api_type_id,
    name: [*:0]u8,
    device_count: c_int,
    default_input_device: Device_index,
    default_output_device: Device_index,
};

pub const Host_error_info = extern struct {
    host_api_type: Host_api_type_id,
    error_code: c_long,
    error_text: [*:0]u8,
};

pub const Device_info = extern struct {
    struct_version: c_int, // 2
    name: [*:0]u8,
    host_api: Host_api_index,
    max_input_channels: c_int,
    max_output_channels: c_int,
    default_low_input_latency: Time,
    default_low_output_latency: Time,
    default_high_input_latency: Time,
    default_high_output_latency: Time,
    default_sample_rate: f64,
};

pub const Stream_parameters = extern struct {
    device: Device_index,
    channel_count: c_int,
    sample_format: Sample_format,
    suggested_latency: Time,
    host_api_specific_stream_info: ?*anyopaque,
};

pub const Stream_callback_time_info = extern struct {
    input_buffer_adc_time: Time,
    current_time: Time,
    output_buffer_dac_time: Time,
};

pub const Stream_info = extern struct {
    struct_version: c_int, // 1
    input_latency: Time,
    output_latency: Time,
    sample_rate: f64,
};

pub const Error = enum(c_int) {
    no_error = 0,
    not_initialized = -10000,
    unanticipated_host_error,
    invalid_channel_count,
    invalid_sample_rate,
    invalid_device,
    invalid_flag,
    sample_format_not_supported,
    bad_io_device_combination,
    insufficient_memory,
    buffer_too_big,
    buffer_too_small,
    null_callback,
    bad_stream_ptr,
    timed_out,
    internal_error,
    device_unavailable,
    incompatible_host_api_specific_stream_info,
    stream_is_stopped,
    stream_is_not_stopped,
    input_overflowed,
    output_underflowed,
    host_api_not_found,
    invalid_host_api,
    can_not_read_from_a_callback_stream,
    can_not_write_to_a_callback_stream,
    can_not_read_from_an_output_only_stream,
    can_not_write_to_an_input_only_stream,
    incompatible_stream_host_api,
    bad_buffer_ptr,
    can_not_initialize_recursively,
    _,
    
    pub fn handle(error_code: Error) !void {
        switch (error_code) {
            .no_error => return,
            inline else => |err| {
                u.log(.{"Portaudio error: ",@tagName(err)});
                return u.create_error(@tagName(err));
            },
            _ => |err| {
                u.log(.{"Unknown portaudio error (",err,")"});
                return error.unknown;
            },
        }
    }
    
    pub fn ignore(err: Error) void {
        err.handle() catch {
            u.log(.{"Error ignored"});
        };
    }
};

pub const Host_api_type_id = enum(c_int) {
    in_development = 0,
    direct_sound = 1,
    mme = 2,
    asio = 3,
    sound_manager = 4,
    core_audio = 5,
    oss = 7,
    alsa = 8,
    al = 9,
    be_os = 10,
    wdmks = 11,
    jack = 12,
    wasapi = 13,
    audio_science_hpi = 14,
    audio_io = 15,
    pulse_audio = 16,
    sndio = 17,
    _,
};

pub const Stream_callback_result = enum(c_int) {
    cont = 0,
    complete = 1,
    abort = 2,
};

pub const Sample_format = enum(c_ulong) {
    float_32 = 0x1,
    int_32 = 0x2,
    int_24 = 0x4,
    int_16 = 0x8,
    int_8 = 0x10,
    uint_8 = 0x20,
    custom = 0x10000,
    // missing interleaved
};

pub const Stream_flags = Flags(enum (c_ulong) {
    clip_off = 0x1,
    dither_off = 0x2,
    never_drop_input = 0x4,
    prime_output_buffers_using_stream_callback = 0x8,
});

pub const Stream_callback_flags = Flags(enum (c_ulong) {
    input_underflow = 0x1,
    input_overflow = 0x2,
    output_underflow = 0x4,
    output_overflow = 0x8,
    priming_output = 0x10,
});

pub const Stream_callback = *const fn(input: [*]const u8, output: [*]u8, frame_count: c_long, time_info: *const Stream_callback_time_info, status_flags: Stream_callback_flags, user_data: ?*anyopaque) callconv(.c) Stream_callback_result;

pub const Stream_finished_callback = *const fn(user_data: ?*anyopaque) callconv(.c) void;

pub const Device_index = c_int;

pub const Host_api_index = c_int;

pub const Time = f64; // in seconds

pub const Stream = opaque {};


fn Flags(Option: type) type {
    return extern struct {
        const Self = @This();
        value: c_ulong,
        
        pub fn empty() Self {
            return .{
                .value = 0,
            };
        }
        
        pub fn add(f: Self, option: Option) Self {
            return .{
                .value = f.value | @intFromEnum(option),
            };
        }
        
        pub fn remove(f: Self, option: Option) Self {
            return .{
                .value = f.value & ~@intFromEnum(option),
            };
        }
        
        pub fn just(option: Option) Self {
            return .{
                .value = @intFromEnum(option),
            };
        }
        
        pub fn combine(f1: Self, f2: Self) Self {
            return .{
                .value = f1.value | f2.value,
            };
        }
        
        pub fn create(options: []const Option) Self {
            var value: c_int = 0;
            for (options) |option| {
                value |= @intFromEnum(option);
            }
            return .{.value = value};
        }
        
        pub fn has(f: Self, option: Option) bool {
            return (f.value & @intFromEnum(option)) != 0;
        }
        
        pub fn debug_print(f: Self, stream: anytype) void {
            u.byte_writer.validate(stream);
            var count: usize = 0;
            const fields = @typeInfo(Option).@"enum".fields;
            inline for (fields) |field| {
                const name = field.name;
                if (f.has(@field(Option, name))) {
                    if (count != 0) {
                        stream.write_slice(" + ");
                    }
                    stream.write_slice(name);
                    count += 1;
                }
            }
            
            if (count == 0) {
                stream.write_slice("(empty)");
            }
        }
    };
}

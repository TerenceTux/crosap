const u = @import("../util.zig");
const std = @import("std");
const ogg = @import("ogg.zig");
const vorbis = @import("vorbis.zig");

pub const Decoded_audio = struct {
    data: []f32,
    sample_rate: u32,
    channels: u8,
    
    pub fn free(decoded: *Decoded_audio) void {
        u.free_slice(decoded.data);
    }
    
    /// Result is allocated, free with u.free_slice
    pub fn convert(decoded: *Decoded_audio, T: type, channels: u8, sample_rate: f32) []T {
        const samples_in = decoded.data.len / decoded.channels;
        const time: f64 = @as(f64, @floatFromInt(samples_in)) / @as(f64, @floatFromInt(decoded.sample_rate));
        const samples_out: usize = @round(time * sample_rate);
        const result = u.alloc_slice(T, channels * samples_out);
        const s_per_out = @as(f32, @floatFromInt(decoded.sample_rate)) / sample_rate; // amount of input samples per output sample
        
        var current_index: usize = 0;
        const current_value = u.alloc_slice(f32, channels);
        defer u.free_slice(current_value);
        decoded.get_sample_converted(current_index, f32, current_value);
        const current_out = u.alloc_slice(f32, channels);
        defer u.free_slice(current_out);
        var current_available: f32 = 1;
        for (0..samples_out) |sample_out| {
            @memset(current_out, 0);
            var in_to_do = s_per_out; // amount of input samples to add
            while (in_to_do > 0) {
                if (in_to_do <= current_available) {
                    current_available -= in_to_do;
                    add_sample_part(current_out, current_value, in_to_do / s_per_out);
                    break;
                } else {
                    in_to_do -= current_available;
                    add_sample_part(current_out, current_value, current_available / s_per_out);
                    
                    current_index += 1;
                    decoded.get_sample_converted(current_index, f32, current_value);
                    current_available = 1;
                }
            }
            
            const this_out = result[sample_out * channels ..][0..channels];
            for (this_out, current_out) |*store, value| {
                store.* = convert_value(value, T);
            }
        }
        return result;
    }
    
    fn add_sample_part(out: []f32, part: []const f32, factor: f32) void {
        for (out, part) |*o, i| {
            o.* += i * factor;
        }
    }
    
    /// Zeroes when out of range
    fn get_sample_converted(decoded: *Decoded_audio, index: usize, T: type, out: []T) void {
        const samples_count = decoded.data.len / decoded.channels;
        if (index < 0 or index >= samples_count) {
            @memset(out, 0);
        } else {
            convert_sample(decoded.data[index * decoded.channels ..][0..decoded.channels], T, out);
        }
    }
    
    fn convert_sample(in: []const f32, T: type, out: []T) void {
        var center: f32 = 0;
        var left: f32 = 0;
        var right: f32 = 0;
        var rear_center: f32 = 0;
        var rear_left: f32 = 0;
        var rear_right: f32 = 0;
        var side_left: f32 = 0;
        var side_right: f32 = 0;
        var lfe: f32 = 0;
        switch (in.len) {
            0 => {},
            1 => {
                center = in[0];
            },
            2 => {
                left = in[0];
                right = in[1];
            },
            3 => {
                left = in[0];
                center = in[1];
                right = in[2];
            },
            4 => {
                left = in[0];
                right = in[1];
                rear_left = in[2];
                rear_right = in[3];
            },
            5 => {
                left = in[0];
                center = in[1];
                right = in[2];
                rear_left = in[3];
                rear_right = in[4];
            },
            6 => {
                left = in[0];
                center = in[1];
                right = in[2];
                rear_left = in[3];
                rear_right = in[4];
                lfe = in[5];
            },
            7 => {
                left = in[0];
                center = in[1];
                right = in[2];
                side_left = in[3];
                side_right = in[4];
                rear_center = in[5];
                lfe = in[6];
            },
            else => {
                left = in[0];
                center = in[1];
                right = in[2];
                side_left = in[3];
                side_right = in[4];
                rear_left = in[5];
                rear_right = in[6];
                lfe = in[7];
            },
        }
        switch (out.len) {
            1 => {
                out[0] = center + left * 0.7 + right * 0.7 + side_left * 0.5 + side_right * 0.5 + rear_center * 0.5 + rear_left * 0.35 + rear_right * 0.35;
            },
            2 => {
                out[0] = left + center * 0.7 + side_left * 0.7 + rear_left * 0.5 + rear_center * 0.35;
                out[1] = right + center * 0.7 + side_right * 0.7 + rear_right * 0.5 + rear_center * 0.35;
            },
            3 => {
                out[0] = left + side_left * 0.7 + rear_left * 0.5;
                out[1] = center + rear_center * 0.5;
                out[2] = right + side_right * 0.7 + rear_right * 0.5;
            },
            4 => {
                out[0] = left + center * 0.7;
                out[1] = right + center * 0.7;
                out[2] = rear_left + side_left * 0.7 + rear_center * 0.7;
                out[3] = rear_right + side_right * 0.7 + rear_center * 0.7;
            },
            5 => {
                out[0] = left;
                out[1] = center;
                out[2] = right;
                out[3] = rear_left + side_left * 0.7 + rear_center * 0.7;
                out[4] = rear_right + side_right * 0.7 + rear_center * 0.7;
            },
            6 => {
                out[0] = left;
                out[1] = center;
                out[2] = right;
                out[3] = rear_left + side_left * 0.7 + rear_center * 0.7;
                out[4] = rear_right + side_right * 0.7 + rear_center * 0.7;
                out[5] = lfe;
            },
            7 => {
                out[0] = left;
                out[1] = center;
                out[2] = right;
                out[3] = side_left + rear_left * 0.7;
                out[4] = side_right + rear_right * 0.7;
                out[5] = rear_center;
                out[6] = lfe;
            },
            else => {
                out[0] = left;
                out[1] = center;
                out[2] = right;
                out[3] = side_left;
                out[4] = side_right;
                out[5] = rear_left + rear_center * 0.7;
                out[6] = rear_right + rear_center * 0.7;
                out[7] = lfe;
                @memset(out[8..], 0);
            },
        }
    }
    
    fn convert_value(value: f32, T: type) T {
        if (@typeInfo(T) == .float) {
            return @floatCast(value);
        } else {
            const min = std.math.minInt(T);
            const max = std.math.maxInt(T);
            const mid = comptime (min + max) / 2;
            var scaled = value * (max - min) * 0.5 + mid;
            if (scaled > max) {
                scaled = max;
            } else if (scaled < min) {
                scaled = min;
            }
            return @intFromFloat(scaled);
        }
    }
};

pub fn decode_ogg_vorbis(encoded: []const u8) !Decoded_audio {
    var reader = std.Io.Reader.fixed(encoded);
    var ogg_decoder = ogg.Decoder.create(&reader);
    defer ogg_decoder.deinit();
    var vorbis_decoder = vorbis.Decoder.create();
    defer vorbis_decoder.deinit();
    var result = u.List(f32).create();
    errdefer result.deinit();
    
    while (true) {
        const packet = ogg_decoder.next_packet() catch |err| switch (err) {
            error.end => break,
            else => {
                u.log(.{"Error: ",err});
                return err;
            },
        };
        u.log(.{"Received packet of ",packet.data.len," bytes for stream ",packet.stream});
        const audio = vorbis_decoder.next(packet.data) catch |err| {
            u.log(.{"Error: ",err});
            return err;
        };
        result.append_slice(audio);
    }
    if (vorbis_decoder.init_state != .ready) {
        return error.file_too_short;
    }
    
    return .{
        .data = result.convert_to_slice(),
        .sample_rate = vorbis_decoder.sample_rate,
        .channels = vorbis_decoder.channels,
    };
}

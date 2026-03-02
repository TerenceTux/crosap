const u = @import("util.zig");
const std = @import("std");

/// Stores at most 1 seconds of 48KHz 16-bit stereo audio.
/// Supports reading audio at the same time as adding audio, i.e from another thread.
/// However, there can not be multiple writers, or multiple readers.
/// The producer and the consumer should both write/read at the correct rate (i.e. 48k samples per second)
/// Small drift will be corrected (up to 0.1% difference)
/// The producer and consumer should write/read at an consistent rate, though some fluctuation is allowed.
/// In that case, the delay of this buffer should be between 1 and 3 times the highest call interval.
pub const Audio_buffer = struct {
    const rate = 48000;
    const max_samples = 1 * rate;
    content: []i16,
    start: usize,
    end: usize,
    used_fraction: u.Real, // Fraction of the first available sample that is already used. Between 0 (incl.) and 1 (excl.)
    last_consume_size: usize,
    count_to_discard: usize, // when 0, the next added sample must be discarded. This must then be reset to 1000 so 0.1% of the samples are being discarded.
    count_to_double: usize,
    
    pub fn init(buffer: *Audio_buffer) void {
        buffer.content = u.alloc_slice(i16, max_samples * 2 + 2); // We can't fill it entirely because then start == end
        buffer.start = 0;
        buffer.end = 0;
        buffer.used_fraction = .zero;
        buffer.last_consume_size = 0;
        buffer.count_to_discard = 500;
        buffer.count_to_discard = 500;
    }
    
    pub fn deinit(buffer: *Audio_buffer) void {
        u.free_slice(buffer.content);
    }
    
    pub fn add_audio(buffer: *Audio_buffer, audio: []const i16) void {
        // Before adding the audio to the buffer, we preferably want the audio buffer to store around 1 until 2 frames of audio.
        // We can keep track of the 8 points and use this to calculate a variation.
        // Or: the variation is either the current added audio or the last removed audio
        // Then, some audio samples that are added below the buffer size of variation will be doubled
        // And some audio samples for a buffer size higher than 3 * variation will be discarded
        
        const samples = @divExact(audio.len, 2);
        u.log(.{"Adding ",samples," samples"});
        
        const last_consume_size = @atomicLoad(usize, &buffer.last_consume_size, .acquire);
        const variation = @max(samples, last_consume_size);
        const double_until = @min(variation, max_samples); // Added samples when the audio buffer is lower than this should be extended
        const normal_until = @min(variation * 3, max_samples);
        const discard_until = max_samples;
        
        const buffer_start = @atomicLoad(usize, &buffer.start, .acquire);
        var buffer_end = @atomicLoad(usize, &buffer.end, .acquire);
        var buffer_length = if (buffer_end >= buffer_start) buffer_end - buffer_start else (max_samples + 1) - buffer_start + buffer_end;
        u.log(.{"Buffer currently ",buffer_length});
        
        for (0..samples) |index| {
            const left = audio[index * 2];
            const right = audio[index * 2 + 1];
            
            var add_times: usize = 1;
            if (buffer_length < double_until) {
                if (buffer.count_to_double == 0) {
                    add_times = 2; // double this sample
                    buffer.count_to_double = 999;
                } else {
                    buffer.count_to_double -= 1;
                }
            } else if (buffer_length < normal_until) {
                // always add the sample
            } else if (buffer_length < discard_until) {
                if (buffer.count_to_discard == 0) {
                    add_times = 0; // discard this sample
                    buffer.count_to_discard = 999;
                } else {
                    buffer.count_to_discard -= 1;
                }
            } else {
                break;
            }
            
            for (0..add_times) |_| {
                buffer.content[buffer_end * 2] = left;
                buffer.content[buffer_end * 2 + 1] = right;
                buffer_end = (buffer_end + 1) % (max_samples + 1);
                buffer_length += 1;
            }
        }
        u.log(.{"Buffer now ",buffer_length});
        @atomicStore(usize, &buffer.end, buffer_end, .release);
    }
    
    pub fn get_audio(buffer: *Audio_buffer, channel_type: Channel_type, T: type, output_rate: usize, audio: []T) void {
        // seconds_per_element = 1 / output_rate
        // samples_per_second = rate
        // samples_per_element = seconds_per_element * samples_per_second = rate / output_rate
        const samples_per_element = u.Real.from_int(rate).divide(.from_int(output_rate));
        const weight_per_sample = samples_per_element.inverse();
        
        var buffer_start = @atomicLoad(usize, &buffer.start, .acquire);
        const buffer_end = @atomicLoad(usize, &buffer.end, .acquire);
        var samples_read: usize = 0;
        
        const elements = switch (channel_type) {
            .mono => audio.len,
            .stereo => @divExact(audio.len, 2),
        };
        for (0..elements) |index| {
            var left = u.Real.zero;
            var right = u.Real.zero;
            if (buffer_start != buffer_end) {
                const current_left = buffer.buffer_read(buffer_start * 2);
                const current_right = buffer.buffer_read(buffer_start * 2 + 1);
                const available_fraction = u.Real.one.subtract(buffer.used_fraction);
                if (available_fraction.higher_than(samples_per_element)) { // this sample is enough
                    buffer.used_fraction.increase(samples_per_element);
                    left = current_left;
                    right = current_right;
                } else {
                    left = current_left.multiply(available_fraction.multiply(weight_per_sample));
                    right = current_right.multiply(available_fraction.multiply(weight_per_sample));
                    advance_next_sample(&buffer_start, &samples_read);
                    const needed_samples = samples_per_element.subtract(available_fraction);
                    const whole_samples = needed_samples.int_floor();
                    const final_fraction = needed_samples.subtract(whole_samples.to_real());
                    for (0..whole_samples.to(usize)) |_| {
                        if (buffer_start == buffer_end) {
                            continue;
                        }
                        const this_left = buffer.buffer_read(buffer_start * 2);
                        const this_right = buffer.buffer_read(buffer_start * 2 + 1);
                        advance_next_sample(&buffer_start, &samples_read);
                        left.increase(this_left.multiply(weight_per_sample));
                        right.increase(this_right.multiply(weight_per_sample));
                    }
                    if (buffer_start == buffer_end) {
                        buffer.used_fraction = .zero;
                    } else {
                        const final_left = buffer.buffer_read(buffer_start * 2);
                        const final_right = buffer.buffer_read(buffer_start * 2 + 1);
                        left.increase(final_left.multiply(final_fraction.multiply(weight_per_sample)));
                        right.increase(final_right.multiply(final_fraction.multiply(weight_per_sample)));
                        buffer.used_fraction = final_fraction;
                    }
                }
            }
            switch (channel_type) {
                .mono => {
                    audio[index] = convert_result(T, left.add(right).divide(.from_int(2)));
                },
                .stereo => {
                    audio[index * 2] = convert_result(T, left);
                    audio[index * 2 + 1] = convert_result(T, right);
                },
            }
        }
        
        @atomicStore(usize, &buffer.start, buffer_start, .release);
        @atomicStore(usize, &buffer.last_consume_size, samples_read, .release);
    }
    
    fn buffer_read(buffer: *Audio_buffer, index: usize) u.Real {
        return u.Real.from_int(buffer.content[index]).divide(.from_int(32768));
    }
    
    fn advance_next_sample(buffer_start: *usize, samples_read: *usize) void {
        buffer_start.* = (buffer_start.* + 1) % (max_samples + 1);
        samples_read.* += 1;
    }
    
    fn convert_result(T: type, result: u.Real) T {
        if (T == u.Real) {
            return result;
        } else switch (@typeInfo(T)) {
            .float => {
                return result.to_float(T);
            },
            .int => {
                const int_min = std.math.minInt(T);
                const int_max = std.math.maxInt(T);
                const scaled = result.multiply(u.Real.from_int(int_max - int_min).divide(.from_int(2)));
                const mid = u.Real.from_int(int_min).add(.from_int(int_max)).divide(.from_int(2));
                return scaled.add(mid).int_round().to(T);
            },
            else => @compileError("Only ints, floats, or u.Real are supported"),
        }
    }
};

pub const Channel_type = enum {
    mono,
    stereo,
};

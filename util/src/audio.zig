const u = @import("util.zig");

/// Stores at most 1 seconds of 48KHz 16-bit audio. 
pub const Audio_buffer = struct {
    const rate = 48000;
    const max_samples = 1 * rate;
    content: []i16,
    start: usize,
    length: usize,
    used_fraction: u.Real, // Fraction of the first available sample that is already used. Between 0 (incl.) and 1 (excl.)
    
    pub fn init(buffer: *Audio_buffer) void {
        buffer.content = u.alloc_slice(i16, max_samples);
        buffer.start = 0;
        buffer.length = 0;
        buffer.used_fraction = .zero;
    }
    
    pub fn deinit(buffer: *Audio_buffer) void {
        u.free_slice(buffer.content);
    }
    
    pub fn add_audio(buffer: *Audio_buffer, audio: []i16) void {
        var available1: []i16 = undefined;
        var available2: []i16 = undefined;
        if (buffer.start + buffer.length > buffer.content.len) { // buffer is currently wrapping
            const first_available = (buffer.start + buffer.length) % buffer.content.len;
            available1 = buffer.content[first_available .. buffer.start];
            available2 = &.{};
        } else { // the used part is somewhere in the middle
            available1 = buffer.content[buffer.start + buffer.length .. buffer.content.len];
            available2 = buffer.content[0 .. buffer.start];
        }
        const write_to_1 = @min(available1.len, audio.len);
        const write_to_2 = @min(available2.len, audio.len - write_to_2);
        @memcpy(available1, audio[0 .. write_to_1]);
        @memcpy(available2, audio[write_to_1 .. write_to_1 + write_to_2]);
    }
    
    pub fn get_audio(buffer: *Audio, T: type, audio: []) void {
        
    }
}

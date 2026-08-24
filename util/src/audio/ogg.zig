const std = @import("std");
const u = @import("../util.zig");

pub const Page_header = struct {
    page_nr: u32,
    stream_id: u32,
    position: u64,
    continued: bool,
    begin_of_stream: bool,
    end_of_stream: bool,
    checksum: u32,
    segment_count: u8,
    segments: [255]u8,
};

pub const Packet = struct {
    data: []const u8,
    stream: u32,
};


pub const Decoder = struct {
    reader: *std.Io.Reader,
    current_packet: u.List(u8),
    current_segment: u8,
    current_page: Page_header, // only valid for current_segment > 0
    need_clear: bool,
    
    pub fn init(decoder: *Decoder, reader: *std.Io.Reader) void {
        decoder.reader = reader;
        decoder.current_packet.init();
        decoder.current_segment = 0;
        decoder.need_clear = true;
    }
    
    pub fn create(reader: *std.Io.Reader) Decoder {
        var decoder: Decoder = undefined;
        decoder.init(reader);
        return decoder;
    }
    
    pub fn deinit(decoder: *Decoder) void {
        decoder.current_packet.deinit();
    }
    
    pub fn read_page_header(decoder: *Decoder) !void {
        var header: [27]u8 = undefined;
        decoder.reader.readSliceAll(&header) catch |err| switch (err) {
            error.EndOfStream => return error.end,
            else => return err,
        };
        //u.log(.{"Header: ",header});
        if (!std.mem.eql(u8, header[0..4], "OggS")) {
            return error.wrong_capture;
        }
        if (header[4] != 0) {
            return error.unsupported_version;
        }
        
        const header_type = header[4];
        const current_page = &decoder.current_page;
        current_page.continued = header_type & 0x01 != 0;
        current_page.begin_of_stream = header_type & 0x02 != 0;
        current_page.end_of_stream = header_type & 0x04 != 0;
        
        current_page.position = std.mem.readInt(u64, header[6..14], .little);
        current_page.stream_id = std.mem.readInt(u32, header[14..18], .little);
        current_page.page_nr = std.mem.readInt(u32, header[18..22], .little);
        current_page.checksum = std.mem.readInt(u32, header[22..26], .little);
        current_page.segment_count = header[26];
        
        try decoder.reader.readSliceAll(current_page.segments[0..current_page.segment_count]);
        //u.log(.{"Segments: ",current_page.segments[0..current_page.segment_count]});
    }
    
    pub fn try_read_packet(decoder: *Decoder) !?Packet {
        if (decoder.current_segment == 0) {
            try decoder.read_page_header();
        }
        if (decoder.need_clear) {
            //u.log(.{"Resetting"});
            decoder.current_packet.clear();
        }
        
        var size: usize = 0;
        var end_of_packet = false;
        while (true) {
            if (decoder.current_segment >= decoder.current_page.segment_count) {
                // end of page, but packet continues on next page
                decoder.current_segment = 0;
                break;
            }
            
            const segment_size = decoder.current_page.segments[decoder.current_segment];
            //u.log(.{"Segment ",decoder.current_segment,": ",segment_size});
            decoder.current_segment += 1;
            size += segment_size;
            
            if (segment_size < 255) {
                if (decoder.current_segment == decoder.current_page.segment_count) {
                    // end of packet and end of page
                    decoder.current_segment = 0;
                } else {
                    // end of packet, but there is another packet on this page
                }
                end_of_packet = true;
                break;
            }
        }
        
        //u.log(.{"Reading ",size," bytes of data"});
        const data = decoder.current_packet.get_append_slice(size);
        try decoder.reader.readSliceAll(data);
        decoder.need_clear = end_of_packet;
        if (end_of_packet) {
            return .{
                .data = decoder.current_packet.items(),
                .stream = decoder.current_page.stream_id,
            };
        } else {
            //u.log(.{"The packet is not finished"});
            return null;
        }
    }
    
    pub fn next_packet(decoder: *Decoder) !Packet {
        while (true) {
            if (try decoder.try_read_packet()) |packet| return packet;
        }
    }
};

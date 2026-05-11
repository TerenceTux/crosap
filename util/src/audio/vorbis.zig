const u = @import("../util.zig");
const std = @import("std");

// defined in the forbis specification as the amount of bits to the right of the most significant 1 including the 1 itself
//   |==|
// 001011 > 4
fn ilog(num: anytype) @TypeOf(num) {
    const T = @TypeOf(num);
    const leading_zeros = @clz(num);
    const total_bits: T = @typeInfo(T).int.bits;
    return total_bits - leading_zeros;
}

const Packet_reader = struct {
    data: []const u8,
    byte_pos: usize,
    current_data: u64,
    available: u8,
    end: bool,
    
    pub fn init(read: *Packet_reader, data: []const u8) void {
        read.* = .{
            .data = data,
            .byte_pos = 0,
            .current_data = 0,
            .available = 0,
            .end = false,
        };
    }
    
    pub fn create(data: []const u8) Packet_reader {
        var read: Packet_reader = undefined;
        read.init(data);
        return read;
    }
    
    pub fn ensure_available(read: *Packet_reader, bits: u8, ignore_end: bool) !void {
        u.assert(bits <= 32);
        if (read.end) {
            if (ignore_end) {
                return;
            } else {
                return error.unexpeced_end;
            }
        }
        while (read.available < bits) {
            if (read.byte_pos >= read.data.len) {
                if (ignore_end) {
                    return;
                } else {
                    read.end = true;
                    return error.unexpeced_end;
                }
            }
            const byte = read.data[read.byte_pos];
            read.byte_pos += 1;
            read.current_data |= @as(u64, byte) << @intCast(read.available);
            read.available += 8;
        }
    }
    
    /// Peeking after end of packet is allowed and will return zeros.
    pub fn peek_bits(read: *Packet_reader, bits: u8) u32 {
        read.ensure_available(bits, true) catch {};
        const mask = (@as(u64, 1) << @intCast(bits)) - 1;
        return @intCast(read.current_data & mask);
    }
    
    pub fn consume_bits(read: *Packet_reader, bits: u8) !void {
        try read.ensure_available(bits, false);
        read.available -= bits;
        read.current_data >>= @intCast(bits);
    }
    
    pub fn read_bits(read: *Packet_reader, bits: u8) !u32 {
        try read.ensure_available(bits, false);
        const mask = (@as(u64, 1) << @intCast(bits)) - 1;
        const data: u32 = @intCast(read.current_data & mask);
        read.available -= bits;
        read.current_data >>= @intCast(bits);
        return data;
    }
    
    pub fn boolean(read: *Packet_reader) !bool {
        const bit = try read.read_bits(1);
        return bit != 0;
    }
    
    pub fn int_bits(read: *Packet_reader, T: type, bits: u16) !T {
        u.assert(bits <= @typeInfo(T).int.bits);
        if (bits <= 32) {
            return @intCast(try read.read_bits(@intCast(bits)));
        }
        var result: T = 0;
        var current_bit: u16 = 0;
        while (current_bit < bits) {
            const remaining = bits - current_bit;
            const this_bits = @min(remaining, 8);
            const data = try read.read_bits(this_bits);
            result |= @as(T, @intCast(data)) << @intCast(current_bit);
            current_bit += this_bits;
        }
        return result;
    }
    
    pub fn int_max(read: *Packet_reader, T: type, max: T) !T {
        return try read.int_bits(T, @intCast(ilog(max)));
    }
    
    pub fn int(read: *Packet_reader, T: type) !T {
        const bits = @typeInfo(T).int.bits;
        switch (@typeInfo(T).int.signedness) {
            .unsigned => return try read.int_bits(T, bits),
            .signed => return @bitCast(try read.int(@Int(.unsigned, bits))),
        }
    }
    
    pub fn array(read: *Packet_reader, T: type, comptime count: usize) ![count]T {
        var result: [count]T = undefined;
        for (0..count) |i| {
            result[i] = try read.int(T);
        }
        return result;
    }
    
    pub fn int_add_one(read: *Packet_reader, comptime bits: u16) !@Int(.unsigned, bits + 1) {
        const readed: @Int(.unsigned, bits + 1) = try read.int(@Int(.unsigned, bits));
        return readed + 1;
    }
    
    pub fn float(read: *Packet_reader) !f32 {
        const bits = try read.int(u32);
        const mantissa: f32 = @floatFromInt(bits & 0x1fffff);
        const sign = bits & 0x80000000;
        const exponent = @as(f32, @floatFromInt((bits & 0x7fe00000) >> 21)) - 788;
        if (sign == 0) {
            return mantissa * (std.math.pow(f32, 2, exponent));
        } else {
            return -mantissa * (std.math.pow(f32, 2, exponent));
        }
    }
};

const Codebook = struct {
    entries: u24,
    dimensions: u16,
    code_table: union(enum) {
        unordered: Unordered_table,
        ordered: Ordered_table,
    },
    fast_bits: u8,
    fast_table: []Fast_result,
    lookup_type: Lookup_type,
    // only when storing values
    minimum_value: f32,
    delta_value: f32,
    sequence_p: bool,
    multiplicands: []f32,
    vector_entries: u.List(u32),
    vectors: []f32,
    
    const Unordered_table = struct {
        entries: u.List(Entry),
        
        const Entry = struct {
            next_0: i32, // negative means final entry result
            next_1: i32, // if final: vector index
        };
    };
    
    const Ordered_table = struct {
        // For each depth, we store how many nodes end in this depth, the nodes that are not ending are doubled in next layer
        // The first layer corresponds to the root node
        layers: u.List(Layer),
        
        const Layer = struct {
            end_count: u32,
            start: u32,
        };
    };
    
    const Lookup_type = enum {
        no,
        type_1,
        type_2,
    };
    
    const Fast_result = struct {
        consumed_bits: u8,
        result: i32, // either the result (then negative), entry to continue (unordered), or pos (ordered)
        vector_index: u32,
    };
    
    pub fn init(cb: *Codebook, read: *Packet_reader) !void {
        u.log_start(.{"Reading codebook"});
        defer u.log_end(.{});
        const sync_pattern = try read.array(u8, 3);
        if (!std.mem.eql(u8, &sync_pattern, &.{0x42, 0x43, 0x56})) {
            return error.wrong_sync_pattern;
        }
        
        cb.dimensions = try read.int(u16);
        cb.entries = try read.int(u24);
        u.log(.{"This codebook contains ",cb.entries," entries"});
        u.log(.{"It stores ",cb.dimensions," dimensional vectors"});
        
        cb.vector_entries.init();
        errdefer cb.vector_entries.deinit();
        const ordered = try read.boolean();
        if (ordered) {
            try cb.read_ordered_table(read);
        } else {
            try cb.read_unordered_table(read);
        }
        errdefer u.free_slice(cb.fast_table);
        errdefer if (ordered) {
            cb.code_table.ordered.layers.deinit();
        } else {
            cb.code_table.unordered.entries.deinit();
        };
        
        cb.lookup_type = switch (try read.int(u4)) {
            0 => .no,
            1 => .type_1,
            2 => .type_2,
            else => return error.invalid_lookup_type,
        };
        if (cb.lookup_type != .no) {
            u.log(.{"Lookup is ",cb.lookup_type});
            cb.minimum_value = try read.float();
            u.log(.{"Minimum value: ",cb.minimum_value});
            cb.delta_value = try read.float();
            u.log(.{"Delta value: ",cb.delta_value});
            const value_bits = try read.int_add_one(4);
            u.log(.{"Bits per value: ",value_bits});
            cb.sequence_p = try read.boolean();
            u.log(.{"Sequence p: ",cb.sequence_p});
            
            var values: usize = cb.entries * cb.dimensions;
            if (cb.lookup_type == .type_1) {
                const dimensions_f: f64 = @floatFromInt(cb.dimensions);
                const entries_f: f64 = @floatFromInt(cb.entries);
                const needed_values = std.math.pow(f64, entries_f, 1.0 / dimensions_f);
                values = @intFromFloat(needed_values);
            }
            u.log(.{"Reading ",values," values"});
            cb.multiplicands = u.alloc_slice(f32, values);
            for (cb.multiplicands) |*value| {
                const val: f32 = @floatFromInt(try read.int_bits(u16, value_bits));
                value.* = val * cb.delta_value + cb.minimum_value;
            }
            
            cb.vectors = u.alloc_slice(f32, cb.vector_entries.count * cb.dimensions);
            for (cb.vector_entries.items(), 0..) |entry, i| {
                cb.store_vector(entry, cb.vectors[i * cb.dimensions ..][0..cb.dimensions]);
            }
        } else {
            u.log(.{"This codebook doesn't store values"});
        }
    }
    
    fn read_unordered_table(cb: *Codebook, read: *Packet_reader) !void {
        u.log(.{"Reading unordered table"});
        cb.code_table = .{
            .unordered = .{
                .entries = undefined,
            },
        };
        const entries = &cb.code_table.unordered.entries;
        entries.init();
        errdefer entries.deinit();
        var path: u.List(u32) = undefined;
        path.init();
        defer path.deinit();
        var min_depth: u.List(?u32) = undefined;
        min_depth.init();
        defer min_depth.deinit();
        entries.append(.{
            .next_0 = 0,
            .next_1 = 0,
        });
        min_depth.append(0);
        
        const sparse = try read.boolean();
        if (sparse) {
            u.log(.{"This table is sparse"});
        } else {
            u.log(.{"This table is not sparse"});
        }
        var count: usize = 0;
        var current_vector_index: usize = 0;
        for (0..cb.entries) |entry_usize| {
            const entry: u32 = @intCast(entry_usize);
            if (sparse) {
                if (!try read.boolean()) {
                    continue;
                }
            }
            
            cb.vector_entries.append(entry);
            
            const code_length = try read.int_add_one(5);
            u.log(.{"Entry ",entry," has code length ",code_length});
            if (min_depth.get(0) == null) {
                return error.overspecified_tree;
            }
            if (min_depth.get(0).? > code_length) {
                return error.impossible_code_length;
            }
            path.clear();
            path.ensure_capacity(code_length + 1);
            var current_position: u32 = 0;
            path.append(current_position);
            for (0..code_length) |depth_usize| {
                const depth_to_go = code_length - @as(u32, @intCast(depth_usize));
                const next_0 = entries.get(current_position).next_0;
                const next_1 = entries.get(current_position).next_1;
                if (next_0 == 0) {
                    const new_position: u32 = @intCast(entries.count);
                    entries.append(.{
                        .next_0 = 0,
                        .next_1 = 0,
                    });
                    min_depth.append(0);
                    entries.get_mut(current_position).next_0 = @intCast(new_position);
                    current_position = new_position;
                } else if (min_depth.get(@intCast(next_0)) != null and depth_to_go >= min_depth.get(@intCast(next_0)).? + 1) {
                    current_position = @intCast(next_0);
                } else if (next_1 == 0) {
                    const new_position: u32 = @intCast(entries.count);
                    entries.append(.{
                        .next_0 = 0,
                        .next_1 = 0,
                    });
                    min_depth.append(0);
                    entries.get_mut(current_position).next_1 = @intCast(new_position);
                    current_position = new_position;
                } else {
                    u.assert(depth_to_go >= min_depth.get(@intCast(next_1)).? + 1);
                    current_position = @intCast(next_1);
                }
                path.append(current_position);
            }
            entries.set(current_position, .{
                .next_0 = -@as(i32, @intCast(entry)) - 1,
                .next_1 = @intCast(current_vector_index),
            });
            min_depth.set(current_position, null);
            _ = path.pop();
            while (path.pop()) |position| {
                const next_0: u32 = @intCast(entries.get(position).next_0);
                const next_1: u32 = @intCast(entries.get(position).next_1);
                var depth: ?u32 = null;
                
                for ([2]u32 {next_0, next_1}) |next| {
                    const new_depth = if (next == 0) 1 else if (min_depth.get(next)) |d| d + 1 else null;
                    if (new_depth) |new| {
                        if (depth == null or new < depth.?) {
                            depth = new;
                        }
                    }
                }
                
                if (depth == min_depth.get(position)) {
                    break; // If this one does not change, our parents will also not change
                } else {
                    min_depth.set(position, depth);
                }
            }
            count += 1;
            current_vector_index += cb.dimensions;
        }
        
        if (count == 1) {
            const value = entries.get(1).next_0;
            if (value >= 0) {
                return error.invalid_single_entry;
            }
            entries.append(.{
                .next_0 = value,
                .next_1 = entries.get(1).next_1,
            });
            entries.get_mut(0).next_1 = 2;
        } else if (min_depth.get(0) != null) {
            return error.underspecified_tree;
        }
        
        const fast_bits = ilog(entries.count);
        if (fast_bits < 1) {
            cb.fast_bits = 1;
        } else if (fast_bits > 32) {
            cb.fast_bits = 32;
        } else {
            cb.fast_bits = @intCast(fast_bits);
        }
        cb.fast_table = u.alloc_slice(Fast_result, @as(usize, 1) << @intCast(cb.fast_bits));
        errdefer u.free_slice(cb.fast_table);
        
        for (cb.fast_table, 0..) |*result, bits_c| {
            var bits = bits_c;
            var current_pos: u32 = 0;
            for (0..cb.fast_bits) |bit_nr| {
                const entry = entries.get(current_pos);
                if (entry.next_0 < 0) {
                    result.consumed_bits = @intCast(bit_nr);
                    result.result = entry.next_0;
                    result.vector_index = @intCast(entry.next_1);
                    break;
                }
                if (bits & 1 != 0) {
                    current_pos = @intCast(entry.next_1);
                } else {
                    current_pos = @intCast(entry.next_0);
                }
                bits >>= 1;
            } else {
                const entry = entries.get(current_pos);
                if (entry.next_0 < 0) {
                    result.consumed_bits = cb.fast_bits;
                    result.result = entry.next_0;
                    result.vector_index = @intCast(entry.next_1);
                } else {
                    result.consumed_bits = cb.fast_bits;
                    result.result = @intCast(current_pos);
                }
            }
        }
    }
    
    fn read_ordered_table(cb: *Codebook, read: *Packet_reader) !void {
        u.log(.{"Reading ordered table"});
        cb.code_table = .{
            .ordered = .{
                .layers = undefined,
            },
        };
        const layers = &cb.code_table.ordered.layers;
        layers.init();
        errdefer layers.deinit();
        
        const starting_level = try read.int_add_one(5);
        u.log(.{"Starting level is ",starting_level});
        for (0..starting_level) |_| {
            layers.append(.{
                .end_count = 0,
                .start = 0,
            });
        }
        var entries_to_go = cb.entries;
        var start: u32 = 0;
        while (entries_to_go > 0) {
            const number = try read.int_max(u24, entries_to_go);
            u.log(.{"Setting level ",layers.count," to ",number});
            if (number > entries_to_go) {
                return error.exceeded_entry_count;
            }
            layers.append(.{
                .end_count = number,
                .start = start,
            });
            start += number;
            entries_to_go -= number;
        }
        
        for (0..cb.entries) |entry| {
            cb.vector_entries.append(@intCast(entry));
        }
        
        const fast_bits = ilog(cb.entries);
        if (fast_bits < 1) {
            cb.fast_bits = 1;
        } else if (fast_bits > 32) {
            cb.fast_bits = 32;
        } else {
            cb.fast_bits = @intCast(fast_bits);
        }
        cb.fast_table = u.alloc_slice(Fast_result, @as(usize, 1) << @intCast(cb.fast_bits));
        errdefer u.free_slice(cb.fast_table);
        
        for (cb.fast_table, 0..) |*result, bits_c| {
            var bits = bits_c;
            var pos: u32 = 0;
            var layer_i: usize = 0;
            for (0..cb.fast_bits) |bit_nr| {
                const layer = layers.get(layer_i);
                const count_end = layer.end_count;
                if (pos < count_end) {
                    result.consumed_bits = @intCast(bit_nr);
                    const entry = layer.start + pos;
                    result.result = -1 - @as(i32, @intCast(entry));
                    result.vector_index = entry * cb.dimensions;
                    break;
                }
                layer_i += 1;
                pos -= count_end;
                pos *= 2;
                if (bits & 1 != 0) {
                    pos += 1;
                }
                bits >>= 1;
            } else {
                const layer = layers.get(layer_i);
                const count_end = layer.end_count;
                if (pos < count_end) {
                    result.consumed_bits = cb.fast_bits;
                    const entry = layer.start + pos;
                    result.result = -1 - @as(i32, @intCast(entry));
                    result.vector_index = entry * cb.dimensions;
                } else {
                    result.consumed_bits = cb.fast_bits;
                    result.result = @intCast(pos);
                }
            }
        }
    }
    
    pub fn deinit(cb: *Codebook) void {
        switch (cb.code_table) {
            .unordered => |*table| {
                table.entries.deinit();
            },
            .ordered => |*table| {
                table.layers.deinit();
            },
        }
        cb.vector_entries.deinit();
        u.free_slice(cb.fast_table);
        if (cb.lookup_type != .no) {
            u.free_slice(cb.multiplicands);
            u.free_slice(cb.vectors);
        }
    }
    
    const Read_result = struct {
        entry: u32,
        vector_index: u32,
    };
    pub fn read_both(cb: *Codebook, read: *Packet_reader) !Read_result {
        const fast_bits = read.peek_bits(cb.fast_bits);
        const fast_result = cb.fast_table[fast_bits];
        try read.consume_bits(fast_result.consumed_bits);
        if (fast_result.result < 0) {
            return .{
                .entry = @intCast(-fast_result.result - 1),
                .vector_index = fast_result.vector_index,
            };
        }
        
        switch (cb.code_table) {
            .unordered => |*table| {
                var current_pos: u32 = @intCast(fast_result.result);
                while (true) {
                    const entry = table.entries.get(current_pos);
                    if (entry.next_0 < 0) {
                        return .{
                            .entry = @intCast(-entry.next_0 - 1),
                            .vector_index = @intCast(entry.next_1),
                        };
                    }
                    if (try read.boolean()) {
                        current_pos = @intCast(entry.next_1);
                    } else {
                        current_pos = @intCast(entry.next_0);
                    }
                }
            },
            .ordered => |*table| {
                var pos: u32 = @intCast(fast_result.result);
                for (table.layers.items()[fast_result.consumed_bits..]) |layer| {
                    const count_end = layer.end_count;
                    if (pos < count_end) {
                        return .{
                            .entry = layer.start + pos,
                            .vector_index = (layer.start + pos) * cb.dimensions,
                        };
                    }
                    pos -= count_end;
                    pos *= 2;
                    if (try read.boolean()) {
                        pos += 1;
                    }
                }
                return error.invalid_code_table;
            },
        }
    }
    
    pub fn read_scalar(cb: *Codebook, read: *Packet_reader) !u32 {
        const result = try cb.read_both(read);
        return result.entry;
    }
    
    pub fn read_vector(cb: *Codebook, read: *Packet_reader) ![]const f32 {
        if (cb.lookup_type == .no) {
            return error.codebook_doesnt_store_values;
        }
        const result = try cb.read_both(read);
        return cb.vectors[result.vector_index..][0..cb.dimensions];
    }
    
    fn store_vector(cb: *Codebook, entry: u32, store: []f32) void {
        u.assert(store.len == cb.dimensions);
        switch (cb.lookup_type) {
            .no => {},
            .type_1 => {
                var last: f32 = 0;
                var index_divisor: u32 = 1;
                for (store) |*result| {
                    const multiplicand = (entry / index_divisor) % cb.multiplicands.len;
                    result.* = cb.multiplicands[multiplicand] + last;
                    if (cb.sequence_p) {
                        last = result.*;
                    }
                    index_divisor *= @intCast(cb.multiplicands.len);
                }
            },
            .type_2 => {
                var last: f32 = 0;
                var multiplicand: u32 = entry * cb.dimensions;
                for (store) |*result| {
                    result.* = cb.multiplicands[multiplicand] + last;
                    if (cb.sequence_p) {
                        last = result.*;
                    }
                    multiplicand += 1;
                }
            },
        }
    }
};

const Floor_0 = struct {
    order: u8,
    rate: u16,
    bark_map_size: u16,
    amplitude_bits: u6,
    amplitude_offset: u8,
    books: []u8,
    
    coefficients: []f32,
    
    pub fn init(floor: *Floor_0, read: *Packet_reader, codebook_count: usize) !void {
        u.log_start(.{"Reading floor 0 configuration"});
        defer u.log_end(.{});
        floor.order = try read.int(u8);
        u.log(.{"Order: ",floor.order});
        floor.rate = try read.int(u16);
        u.log(.{"Rate: ",floor.rate});
        floor.bark_map_size = try read.int(u16);
        u.log(.{"Bark map size: ",floor.bark_map_size});
        floor.amplitude_bits = try read.int(u6);
        u.log(.{"Amplitude bits: ",floor.amplitude_bits});
        floor.amplitude_offset = try read.int(u8);
        u.log(.{"Amplitude offset: ",floor.amplitude_offset});
        
        const book_count = try read.int_add_one(5);
        floor.books = u.alloc_slice(u8, book_count);
        errdefer u.free_slice(floor.books);
        for (floor.books, 0..) |*book, i| {
            book.* = try read.int(u8);
            u.log(.{"Book ",i,": ",book.*});
            if (book.* >= codebook_count) {
                return error.invalid_codebook;
            }
        }
        
        floor.coefficients = u.alloc_slice(f32, floor.order);
    }
    
    pub fn deinit(floor: *Floor_0) void {
        u.free_slice(floor.books);
        u.free_slice(floor.coefficients);
    }
    
    pub fn decode(floor: *Floor_0, result: []f32, read: *Packet_reader, codebooks: []Codebook) !bool {
        const amplitude = try read.int_bits(u64, floor.amplitude_bits);
        u.log(.{"Amplitude: ",amplitude});
        if (amplitude == 0) {
            @memset(result, 0);
            return false;
        }
        
        const book_nr = try read.int_max(u64, floor.books.len);
        if (book_nr >= floor.books.len) {
            return error.invalid_book;
        }
        u.log(.{"Using codebook ",floor.books[book_nr]," (nr ",book_nr,")"});
        const codebook = &codebooks[floor.books[book_nr]];
        
        var count: usize = 0;
        while (count < floor.order) {
            const vector = try codebook.read_vector(read);
            const last = if (count > 0) floor.coefficients[count - 1] else 0;
            const add = @min(vector.len, floor.order - count);
            for (vector[0..add], floor.coefficients[count .. count + add]) |value, *store| {
                store.* = value + last;
            }
            count += add;
        }
        
        var map_i: f32 = 1; // First iteration will result in 0, which will cause a recomputation
        var value: f32 = 0;
        for (result, 0..) |*store, i| {
            const new_map = floor.map_value(@intCast(i), @intCast(result.len));
            if (new_map != map_i) {
                map_i = new_map;
                const bark_map_size: f32 = @floatFromInt(floor.bark_map_size);
                const w = std.math.pi * map_i / bark_map_size;
                const cos_w = std.math.cos(w);
                
                const order_odd = floor.order % 2 != 0;
                const p_factor = if (order_odd) 1 - cos_w * cos_w else 1.0/4.0;
                const q_factor = if (order_odd) (1 - cos_w) / 2 else (1 + cos_w) / 2;
                
                var sum_even: f32 = 1;
                var sum_odd: f32 = 1;
                for (floor.coefficients, 0..) |coefficient, co_i| {
                    const value1 = std.math.cos(coefficient) - cos_w;
                    const value2 = 4 * value1 * value1;
                    if (co_i % 2 == 0) {
                        sum_even *= value2;
                    } else {
                        sum_odd *= value2;
                    }
                }
                
                const root = std.math.sqrt(p_factor * sum_odd + q_factor * sum_even);
                const amplitude_f: f32 = @floatFromInt(amplitude);
                const amplitude_offset: f32 = @floatFromInt(floor.amplitude_offset);
                const max_amplitude: f32 = @floatFromInt(@as(u64, 1) << floor.amplitude_bits - 1);
                const division = amplitude_f * amplitude_offset / (max_amplitude * root);
                value = std.math.exp(0.11512925 * (division - amplitude_offset));
            }
            store.* = value;
        }
        return true;
    }
    
    fn map_value(floor: *Floor_0, i: u32, n: u32) f32 {
        const rate: f32 = @floatFromInt(floor.rate);
        const bark_map_size: f32 = @floatFromInt(floor.bark_map_size);
        const i_f: f32 = @floatFromInt(i);
        const n_f: f32 = @floatFromInt(n);
        
        const left = bark(rate * i_f / (2 * n_f));
        const right = bark_map_size / bark(0.5 * rate);
        
        const value = std.math.floor(left * right);
        if (value > bark_map_size - 1) {
            return bark_map_size - 1;
        } else {
            return value;
        }
    }
    
    fn bark(x: f32) f32 {
        return 13.1 * std.math.atan(0.00074 * x) + 2.24 * std.math.atan(0.0000000185 * x*x) + 0.0001 * x;
    }
};

const Floor_1 = struct {
    partitions: []u4,
    classes: []Class,
    multiplier: u3,
    x_list: []u16,
    sort_map: []u16,
    neighbour_low: []u16,
    neighbour_high: []u16,
    y_list: []u16,
    final_y: []i16,
    step2_flag: []bool,
    
    const Class = struct {
        dimensions: u4,
        subclasses: u2,
        master_book: u8,
        sub_books: []?u8,
    };
    
    pub fn init(floor: *Floor_1, read: *Packet_reader, codebook_count: usize) !void {
        u.log_start(.{"Reading floor 1 configuration"});
        defer u.log_end(.{});
        
        const partition_count = try read.int(u5);
        floor.partitions = u.alloc_slice(u4, partition_count);
        errdefer u.free_slice(floor.partitions);
        var max_class: i5 = -1;
        for (floor.partitions, 0..) |*class, i| {
            class.* = try read.int(u4);
            u.log(.{"Partition ",i," uses class ",class.*});
            if (class.* > max_class) {
                max_class = class.*;
            }
        }
        
        floor.classes = u.alloc_slice(Class, @intCast(max_class + 1));
        errdefer u.free_slice(floor.classes);
        var classes_initialized: usize = 0;
        errdefer for (floor.classes[0..classes_initialized]) |*class| {
            u.free_slice(class.sub_books);
        };
        for (floor.classes, 0..) |*class, class_i| {
            u.log_start(.{"Class ",class_i});
            defer u.log_end(.{});
            class.dimensions = try read.int_add_one(3);
            u.log(.{"Dimensions: ",class.dimensions});
            class.subclasses = try read.int(u2);
            u.log(.{"Subclasses: ",class.subclasses});
            if (class.subclasses > 0) {
                class.master_book = try read.int(u8);
                u.log(.{"Master book: ",class.master_book});
                if (class.master_book >= codebook_count) {
                    return error.invalid_codebook;
                }
            }
            const sub_book_count = @as(u16, 1) << class.subclasses;
            class.sub_books = u.alloc_slice(?u8, sub_book_count);
            classes_initialized += 1;
            for (class.sub_books, 0..) |*sub_book, book_i| {
                const book = try read.int(u8);
                u.log(.{"Sub book ",book_i,": ",book});
                if (book > 0) {
                    sub_book.* = book - 1;
                    if (sub_book.*.? >= codebook_count) {
                        return error.invalid_codebook;
                    }
                } else {
                    sub_book.* = null;
                }
            }
        }
        
        var total_values: usize = 2;
        for (floor.partitions) |class| {
            total_values += floor.classes[class].dimensions;
        }
        
        floor.multiplier = try read.int_add_one(2);
        u.log(.{"Multiplier: ",floor.multiplier});
        if (total_values > 65) {
            return error.too_many_x_values;
        }
        const range_bits = try read.int(u4);
        floor.x_list = u.alloc_slice(u16, total_values);
        errdefer u.free_slice(floor.x_list);
        floor.x_list[0] = 0;
        floor.x_list[1] = @as(u16, 1) << range_bits;
        {
            u.log_start(.{"There are ",total_values," x values"});
            defer u.log_end(.{});
            for (floor.x_list[2..], 2..) |*item, i| {
                item.* = try read.int_bits(u16, range_bits);
                u.log(.{i,": ",item.*});
            }
        }
        
        floor.sort_map = u.alloc_slice(u16, total_values);
        for (floor.sort_map, 0..) |*map, i| {
            map.* = @intCast(i);
        }
        const Sort_context = struct {
            x_list: []u16,
            sort_map: []u16,
            
            pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
                return ctx.x_list[ctx.sort_map[a]] < ctx.x_list[ctx.sort_map[b]];
            }
            
            pub fn swap(ctx: @This(), a: usize, b: usize) void {
                std.mem.swap(u16, &ctx.sort_map[a], &ctx.sort_map[b]);
            }
        };
        std.sort.pdqContext(0, total_values, Sort_context {.x_list = floor.x_list, .sort_map = floor.sort_map});
        
        floor.neighbour_low = u.alloc_slice(u16, total_values);
        errdefer u.free_slice(floor.neighbour_low);
        floor.neighbour_high = u.alloc_slice(u16, total_values);
        errdefer u.free_slice(floor.neighbour_high);
        for (floor.x_list, floor.neighbour_low, floor.neighbour_high, 0..) |x, *low, *high, i| {
            if (i < 2) {
                continue;
            }
            low.* = @intCast(highest_below(floor.x_list[0..i], x) orelse return error.invalid_x_value);
            high.* = @intCast(lowest_above(floor.x_list[0..i], x) orelse return error.invalid_x_value);
        }
        
        floor.y_list = u.alloc_slice(u16, total_values);
        floor.final_y = u.alloc_slice(i16, total_values);
        floor.step2_flag = u.alloc_slice(bool, total_values);
    }
    
    pub fn deinit(floor: *Floor_1) void {
        u.free_slice(floor.partitions);
        for (floor.classes) |*class| {
            u.free_slice(class.sub_books);
        }
        u.free_slice(floor.classes);
        u.free_slice(floor.x_list);
        u.free_slice(floor.sort_map);
        u.free_slice(floor.y_list);
        u.free_slice(floor.final_y);
        u.free_slice(floor.step2_flag);
    }
    
    pub fn decode(floor: *Floor_1, result: []f32, read: *Packet_reader, codebooks: []Codebook) !bool {
        u.log_start(.{"Decoding floor 1"});
        defer u.log_end(.{});
        if (!try read.boolean()) { // nonzero bit
            @memset(result, 0);
            return false;
        }
        const possible_ranges = [_]u16 {256, 128, 86, 64};
        const range = possible_ranges[floor.multiplier - 1];
        //u.log(.{"Range: ",range});
        //u.log(.{"N = ",result.len});
        
        floor.y_list[0] = try read.int_max(u16, range - 1);
        floor.y_list[1] = try read.int_max(u16, range - 1);
        //u.log(.{"y[0]: ",floor.y_list[0]});
        //u.log(.{"y[1]: ",floor.y_list[1]});
        var offset: usize = 2;
        for (floor.partitions) |class_nr| {
            //u.log(.{"Class ",class_nr});
            const class = floor.classes[class_nr];
            const cdim = class.dimensions;
            const cbits = class.subclasses;
            const csub = (@as(u4, 1) << cbits) - 1;
            var cval: u32 = 0;
            if (cbits > 0) {
                const master_codebook = &codebooks[class.master_book];
                cval = try master_codebook.read_scalar(read);
                //u.log(.{"Read cval ",cval," from book ",class.master_book});
            }
            for (0..cdim) |_| {
                //u.log(.{"Sub book ",cval & csub});
                if (class.sub_books[cval & csub]) |sub_book_nr| {
                    const sub_book = &codebooks[sub_book_nr];
                    const read_value = try sub_book.read_scalar(read);
                    //u.log(.{"Read value: ",read_value," from book ",sub_book_nr});
                    if (read_value > std.math.maxInt(u16)) {
                        return error.value_too_large;
                    }
                    floor.y_list[offset] = @intCast(read_value);
                } else {
                    //u.log(.{"Sub book is empty"});
                    floor.y_list[offset] = 0;
                }
                cval >>= cbits;
                offset += 1;
            }
        }
        
        floor.step2_flag[0] = true;
        floor.step2_flag[1] = true;
        floor.final_y[0] = @intCast(floor.y_list[0]);
        floor.final_y[1] = @intCast(floor.y_list[1]);
        u.log(.{"x0: ",floor.x_list[0]});
        u.log(.{"x1: ",floor.x_list[1]});
        for (2..floor.y_list.len) |i| {
            const x = floor.x_list[i];
            //u.log(.{"x",i,": ",x});
            const low_neighbor_i = floor.neighbour_low[i];
            const high_neighbor_i = floor.neighbour_high[i];
            const low_x = floor.x_list[low_neighbor_i];
            const low_y = floor.final_y[low_neighbor_i];
            const high_x = floor.x_list[high_neighbor_i];
            const high_y = floor.final_y[high_neighbor_i];
            if (x > std.math.maxInt(i16)) {
                return error.x_out_of_range;
            }
            if (low_x > std.math.maxInt(i16)) {
                return error.x_out_of_range;
            }
            if (high_x > std.math.maxInt(i16)) {
                return error.x_out_of_range;
            }
            const predicted = try render_point(@intCast(low_x), low_y, @intCast(high_x), high_y, @intCast(x));
            //u.log(.{"(",low_x,", ",low_y,"), (",high_x,", ",high_y,") -> (",x,", ",predicted,")"});
            
            if (floor.y_list[i] > std.math.maxInt(i16)) {
                return error.value_out_of_range;
            }
            const value: i16 = @intCast(floor.y_list[i]);
            const highroom = @as(i16, @intCast(range)) - predicted;
            const lowroom = predicted;
            const room = if (highroom < lowroom) highroom * 2 else lowroom * 2;
            
            if (value == 0) {
                floor.step2_flag[i] = false;
                if (predicted < 0 or predicted >= range) {
                    return error.value_out_of_range;
                }
                floor.final_y[i] = predicted;
                continue;
            }
            
            floor.step2_flag[low_neighbor_i] = true;
            floor.step2_flag[high_neighbor_i] = true;
            floor.step2_flag[i] = true;
            
            var result_y: i16 = undefined;
            if (value >= room) {
                if (highroom > lowroom) {
                    result_y = value - lowroom + predicted;
                } else {
                    result_y = predicted - value + highroom - 1;
                }
            } else {
                if (@mod(value, 2) != 0) { // value is odd
                    result_y = predicted - @divTrunc((value + 1), 2);
                } else { // value is even
                    result_y = predicted + @divTrunc(value, 2);
                }
            }
            if (result_y < 0 or result_y >= range) {
                return error.value_out_of_range;
            }
            floor.final_y[i] = result_y;
        }
        
        u.log_start(.{"Draw line"});
        defer u.log_end(.{});
        var prev_x: i16 = 0;
        var prev_y = floor.final_y[0] * floor.multiplier;
        for (floor.sort_map[1..]) |i| {
            if (floor.step2_flag[i]) {
                const new_x: i16 = @intCast(floor.x_list[i]);
                const new_y = floor.final_y[i] *  floor.multiplier;
                u.log(.{i,": ",new_x,", ",new_y});
                render_line(prev_x, prev_y, new_x, new_y, result);
                prev_x = new_x;
                prev_y = new_y;
            }
        }
        if (prev_x < result.len) {
            render_line(prev_x, prev_y, @intCast(result.len), prev_y, result);
        }
        return true;
    }
    
    fn highest_below(list: []u16, below: u16) ?usize {
        var index: ?usize = null;
        var highest: ?u16 = null;
        for (list, 0..) |value, i| {
            if (value < below) {
                if (highest == null or value > highest.?) {
                    index = i;
                    highest = value;
                }
            }
        }
        return index;
    }
    
    fn lowest_above(list: []u16, above: u16) ?usize {
        var index: ?usize = null;
        var lowest: ?u16 = null;
        for (list, 0..) |value, i| {
            if (value > above) {
                if (lowest == null or value < lowest.?) {
                    index = i;
                    lowest = value;
                }
            }
        }
        return index;
    }
    
    fn render_point(x0: i32, y0: i32, x1: i32, y1: i32, x: i32) !i16 {
        const dy = y1 - y0;
        const adx = x1 - x0;
        const ady: i16 = @intCast(@abs(dy));
        const err = ady * (x - x0);
        const off = @divTrunc(err, adx);
        if (adx == 0) {
            return error.division_by_zero;
        }
        const result = if (dy < 0) y0 - off else y0 + off;
        return std.math.cast(i16, result) orelse return error.overflow;
    }
    
    fn render_line(x0: i32, y0: i32, x1: i32, y1: i32, v: []f32) void {
        const dy = y1 - y0;
        const adx = x1 - x0;
        var y = y0;
        v[@intCast(x0)] = lookup_db_table(y);
        if (adx == 0) {
            return;
        }
        const base = @divTrunc(dy, adx);
        var err: i32 = 0;
        
        const sy = if (dy < 0) base - 1 else base + 1;
        const dy_abs: i32 = @intCast(@abs(dy));
        const base_abs: i32 = @intCast(@abs(base));
        const ady = dy_abs - base_abs * adx;
        var x = x0 + 1;
        while (x < x1): (x += 1) {
            err += ady;
            if (err >= adx) {
                err -= adx;
                y += sy;
            } else {
                y += base;
            }
            v[@intCast(x)] = lookup_db_table(y);
        }
    }
    
    fn lookup_db_table(index: i32) f32 {
        if (index < 0 or index >= 256) {
            return 0.0;
        } else {
            return inverse_db_table[@intCast(index)];
        }
    }
};

const inverse_db_table = [256]f32 {
    1.0649863e-07, 1.1341951e-07, 1.2079015e-07, 1.2863978e-07,
    1.3699951e-07, 1.4590251e-07, 1.5538408e-07, 1.6548181e-07,
    1.7623575e-07, 1.8768855e-07, 1.9988561e-07, 2.1287530e-07,
    2.2670913e-07, 2.4144197e-07, 2.5713223e-07, 2.7384213e-07,
    2.9163793e-07, 3.1059021e-07, 3.3077411e-07, 3.5226968e-07,
    3.7516214e-07, 3.9954229e-07, 4.2550680e-07, 4.5315863e-07,
    4.8260743e-07, 5.1396998e-07, 5.4737065e-07, 5.8294187e-07,
    6.2082472e-07, 6.6116941e-07, 7.0413592e-07, 7.4989464e-07,
    7.9862701e-07, 8.5052630e-07, 9.0579828e-07, 9.6466216e-07,
    1.0273513e-06, 1.0941144e-06, 1.1652161e-06, 1.2409384e-06,
    1.3215816e-06, 1.4074654e-06, 1.4989305e-06, 1.5963394e-06,
    1.7000785e-06, 1.8105592e-06, 1.9282195e-06, 2.0535261e-06,
    2.1869758e-06, 2.3290978e-06, 2.4804557e-06, 2.6416497e-06,
    2.8133190e-06, 2.9961443e-06, 3.1908506e-06, 3.3982101e-06,
    3.6190449e-06, 3.8542308e-06, 4.1047004e-06, 4.3714470e-06,
    4.6555282e-06, 4.9580707e-06, 5.2802740e-06, 5.6234160e-06,
    5.9888572e-06, 6.3780469e-06, 6.7925283e-06, 7.2339451e-06,
    7.7040476e-06, 8.2047000e-06, 8.7378876e-06, 9.3057248e-06,
    9.9104632e-06, 1.0554501e-05, 1.1240392e-05, 1.1970856e-05,
    1.2748789e-05, 1.3577278e-05, 1.4459606e-05, 1.5399272e-05,
    1.6400004e-05, 1.7465768e-05, 1.8600792e-05, 1.9809576e-05,
    2.1096914e-05, 2.2467911e-05, 2.3928002e-05, 2.5482978e-05,
    2.7139006e-05, 2.8902651e-05, 3.0780908e-05, 3.2781225e-05,
    3.4911534e-05, 3.7180282e-05, 3.9596466e-05, 4.2169667e-05,
    4.4910090e-05, 4.7828601e-05, 5.0936773e-05, 5.4246931e-05,
    5.7772202e-05, 6.1526565e-05, 6.5524908e-05, 6.9783085e-05,
    7.4317983e-05, 7.9147585e-05, 8.4291040e-05, 8.9768747e-05,
    9.5602426e-05, 0.00010181521, 0.00010843174, 0.00011547824,
    0.00012298267, 0.00013097477, 0.00013948625, 0.00014855085,
    0.00015820453, 0.00016848555, 0.00017943469, 0.00019109536,
    0.00020351382, 0.00021673929, 0.00023082423, 0.00024582449,
    0.00026179955, 0.00027881276, 0.00029693158, 0.00031622787,
    0.00033677814, 0.00035866388, 0.00038197188, 0.00040679456,
    0.00043323036, 0.00046138411, 0.00049136745, 0.00052329927,
    0.00055730621, 0.00059352311, 0.00063209358, 0.00067317058,
    0.00071691700, 0.00076350630, 0.00081312324, 0.00086596457,
    0.00092223983, 0.00098217216, 0.0010459992,  0.0011139742,
    0.0011863665,  0.0012634633,  0.0013455702,  0.0014330129,
    0.0015261382,  0.0016253153,  0.0017309374,  0.0018434235,
    0.0019632195,  0.0020908006,  0.0022266726,  0.0023713743,
    0.0025254795,  0.0026895994,  0.0028643847,  0.0030505286,
    0.0032487691,  0.0034598925,  0.0036847358,  0.0039241906,
    0.0041792066,  0.0044507950,  0.0047400328,  0.0050480668,
    0.0053761186,  0.0057254891,  0.0060975636,  0.0064938176,
    0.0069158225,  0.0073652516,  0.0078438871,  0.0083536271,
    0.0088964928,  0.009474637,   0.010090352,   0.010746080,
    0.011444421,   0.012188144,   0.012980198,   0.013823725,
    0.014722068,   0.015678791,   0.016697687,   0.017782797,
    0.018938423,   0.020169149,   0.021479854,   0.022875735,
    0.024362330,   0.025945531,   0.027631618,   0.029427276,
    0.031339626,   0.033376252,   0.035545228,   0.037855157,
    0.040315199,   0.042935108,   0.045725273,   0.048696758,
    0.051861348,   0.055231591,   0.058820850,   0.062643361,
    0.066714279,   0.071049749,   0.075666962,   0.080584227,
    0.085821044,   0.091398179,   0.097337747,   0.10366330,
    0.11039993,    0.11757434,    0.12521498,    0.13335215,
    0.14201813,    0.15124727,    0.16107617,    0.17154380,
    0.18269168,    0.19456402,    0.20720788,    0.22067342,
    0.23501402,    0.25028656,    0.26655159,    0.28387361,
    0.30232132,    0.32196786,    0.34289114,    0.36517414,
    0.38890521,    0.41417847,    0.44109412,    0.46975890,
    0.50028648,    0.53279791,    0.56742212,    0.60429640,
    0.64356699,    0.68538959,    0.72993007,    0.77736504,
    0.82788260,    0.88168307,    0.9389798,     1,
};

const Residu = struct {
    res_type: Type,
    begin: u24,
    end: u24,
    partition_size: u25,
    classbook: u8,
    books: [][8]?u8,
    max_pass: u8,
    
    const Type = enum {
        type_0,
        type_1,
        type_2,
    };
    
    pub fn init(residu: *Residu, read: *Packet_reader) !void {
        u.log_start(.{"Parsing residu"});
        defer u.log_end(.{});
        const residu_type = try read.int(u16);
        residu.res_type = switch (residu_type) {
            0 => .type_0,
            1 => .type_1,
            2 => .type_2,
            else => return error.invalid_residu_type,
        };
        u.log(.{"Type is ",residu.res_type});
        
        residu.begin = try read.int(u24);
        u.log(.{"Begin: ",residu.begin});
        residu.end = try read.int(u24);
        u.log(.{"End: ",residu.end});
        residu.partition_size = try read.int_add_one(24);
        u.log(.{"Partition_size: ",residu.partition_size});
        const classification_count = try read.int_add_one(6);
        u.log(.{"Classifications: ",classification_count});
        residu.classbook = try read.int(u8);
        u.log(.{"Classbook: ",residu.classbook});
        
        const cascade = u.alloc_slice(u8, classification_count);
        defer u.free_slice(cascade);
        for (cascade, 0..) |*element, i| {
            var high_bits: u8 = 0;
            const low_bits: u8 = try read.int(u3);
            if (try read.boolean()) {
                high_bits = try read.int(u5);
            }
            element.* = (high_bits << 3) + low_bits;
            u.log(.{"Cascade ",i,": ",element.*});
        }
        
        residu.max_pass = 0;
        residu.books = u.alloc_slice([8]?u8, classification_count);
        errdefer u.free_slice(cascade);
        for (residu.books, cascade, 0..) |*books, used, class_i| {
            var bit_mask: u8 = 1;
            for (books, 0..) |*book, pass| {
                if (used & bit_mask != 0) {
                    book.* = try read.int(u8);
                    if (pass + 1 > residu.max_pass) {
                        residu.max_pass = @intCast(pass + 1);
                    }
                } else {
                    book.* = null;
                }
                bit_mask <<= 1;
            }
            u.log(.{"Books class ",class_i,": ",books});
        }
    }
    
    pub fn deinit(residu: *Residu) void {
        u.free_slice(residu.books);
    }
    
    pub fn decode(residu: *Residu, read: *Packet_reader, channels: []u8, length: usize, residu_result: []f32, no_residu: []bool, result_stride: usize, codebooks: []Codebook, classifications: []u8) !void {
        switch (residu.res_type) {
            .type_0 => u.log_start(.{"Reading residu type 0"}),
            .type_1 => u.log_start(.{"Reading residu type 1"}),
            .type_2 => u.log_start(.{"Reading residu type 2"}),
        }
        defer u.log_end(.{});
        for (channels) |channel| {
            @memset(residu_result[channel * result_stride ..][0..length], 0);
        }
        if (residu.res_type == .type_2) {
            for (channels) |channel| {
                if (!no_residu[channel]) break;
            } else return;
        }
        
        var vector_count = channels.len;
        var vector_length = length;
        if (residu.res_type == .type_2) {
            vector_count = 1;
            vector_length = length * channels.len;
        }
        u.log(.{"Reading ",vector_count," vectors of size ",vector_length});
        const residu_begin = @min(residu.begin, vector_length);
        const residu_end = @min(residu.end, vector_length);
        if (residu_end < residu_begin) {
            return error.invalid_residu_begin;
        }
        const classbook = &codebooks[residu.classbook];
        const classwords_per_codeword = classbook.dimensions;
        u.log(.{"Classwords per codeword: ",classwords_per_codeword});
        const n_to_read = residu_end - residu_begin;
        const partitions_to_read = n_to_read / residu.partition_size;
        u.log(.{"We have to read ",n_to_read," items, so ",partitions_to_read," partitions"});
        if (n_to_read == 0) {
            u.log(.{"Nothing to read"});
            return;
        }
        
        for (0..residu.max_pass) |pass| {
            u.log_start(.{"Pass ",pass});
            defer u.log_end(.{});
            var partition: usize = 0;
            while (partition < partitions_to_read) {
                if (pass == 0) {
                    for (0..vector_count) |vector| {
                        if (residu.res_type == .type_2 or !no_residu[channels[vector]]) {
                            var temp = try classbook.read_scalar(read);
                            //u.log(.{"Read from classbook: ",temp});
                            var i = classwords_per_codeword;
                            while (i > 0) {
                                i -= 1;
                                if (partition + i < partitions_to_read) {
                                    classifications[vector * partitions_to_read + partition + i] = @intCast(temp % residu.books.len);
                                    temp /= @intCast(residu.books.len);
                                }
                            }
                        }
                    }
                }
                for (0..classwords_per_codeword) |_| {
                    if (partition >= partitions_to_read) break;
                    for (0..vector_count) |vector| {
                        if (residu.res_type == .type_2 or !no_residu[channels[vector]]) {
                            //u.log(.{"Partition ",partition," of vector ",vector});
                            const vqclass = classifications[vector * partitions_to_read + partition];
                            if (residu.books[vqclass][pass]) |vqbook| {
                                //u.log(.{"Class ",vqclass,", so book ",vqbook});
                                const offset = residu_begin + partition * residu.partition_size;
                                const codebook = &codebooks[vqbook];
                                switch (residu.res_type) {
                                    .type_0 => try residu.decode_partition_0(read, vector, offset, codebook, residu_result, result_stride),
                                    .type_1 => try residu.decode_partition_1(read, vector, offset, codebook, residu_result, result_stride),
                                    .type_2 => try residu.decode_partition_2(read, channels.len, offset, codebook, residu_result, result_stride),
                                }
                            }
                        }
                    }
                    partition += 1;
                }
            }
        }
    }
    
    fn decode_partition_0(residu: *Residu, read: *Packet_reader, vector: usize, offset: usize, codebook: *Codebook, result: []f32, result_stride: usize) !void {
        u.assert(residu.partition_size % codebook.dimensions == 0);
        const step = residu.partition_size / codebook.dimensions;
        for (0..step) |i| {
            const entry = try codebook.read_vector(read);
            for (0..codebook.dimensions) |j| {
                add_to_vector(result, result_stride, vector, offset + i + j * step, entry[j]);
            }
        }
    }
    
    fn decode_partition_1(residu: *Residu, read: *Packet_reader, vector: usize, offset: usize, codebook: *Codebook, result: []f32, result_stride: usize) !void {
        u.assert(residu.partition_size % codebook.dimensions == 0);
        var i: usize = 0;
        while (i < residu.partition_size) {
            const entry = try codebook.read_vector(read);
             for (0..codebook.dimensions) |j| {
                 add_to_vector(result, result_stride, vector, offset + i, entry[j]);
                 i += 1;
             }
        }
    }
    
    fn decode_partition_2(residu: *Residu, read: *Packet_reader, vectors: usize, offset: usize, codebook: *Codebook, result: []f32, result_stride: usize) !void {
        u.assert(residu.partition_size % codebook.dimensions == 0);
        if (vectors == 2 and codebook.dimensions % 2 == 0 and offset % 2 == 0) {
            try residu.decode_partition_2_stereo(read, offset, codebook, result, result_stride);
            return;
        }
        var i: usize = 0;
        var write_index: usize = offset / vectors;
        var write_vector: usize = offset % vectors;
        while (i < residu.partition_size) {
            const entry = try codebook.read_vector(read);
            for (0..codebook.dimensions) |j| {
                add_to_vector(result, result_stride, write_vector, write_index, entry[j]);
                write_vector += 1;
                if (write_vector == vectors) {
                    write_index += 1;
                    write_vector = 0;
                }
                i += 1;
            }
        }
    }
    
    fn decode_partition_2_stereo(residu: *Residu, read: *Packet_reader, offset: usize, codebook: *Codebook, result: []f32, result_stride: usize) !void {
        u.assert(residu.partition_size % codebook.dimensions == 0);
        var i: usize = 0;
        var write_index: usize = offset / 2;
        while (i < residu.partition_size) {
            const entry = try codebook.read_vector(read);
            var j: usize = 0;
            while (j < codebook.dimensions) {
                result[write_index] += entry[j];
                result[result_stride + write_index] += entry[j + 1];
                j += 2;
                write_index += 1;
            }
            i += codebook.dimensions;
        }
    }
    
    fn add_to_vector(result: []f32, result_stride: usize, vector: usize, index: usize, value: f32) void {
        result[vector * result_stride + index] += value;
    }
};

pub const Mapping = struct {
    coupling: []Couple,
    multiplex: []u5, // channel to submap
    submaps: []Submap,
    submap_channels: []u8, // the channels for each submap concatenated
    submap_count: []u8, // amount of numbers in submap_channels that belong to this submap
    
    const Couple = struct {
        magnitude: u8,
        angle: u8,
    };
    
    const Submap = struct {
        floor: u8,
        residu: u8,
    };
    
    pub fn init(mapping: *Mapping, read: *Packet_reader, channel_count: u8, floor_count: usize, residu_count: usize) !void {
        u.log_start(.{"Parsing mapping"});
        defer u.log_end(.{});
        if (try read.int(u16) != 0) {
            return error.invalid_mapping_type;
        }
        
        var submap_count: u5 = 1;
        if (try read.boolean()) {
            submap_count = try read.int_add_one(4);
        }
        u.log(.{"Submaps: ",submap_count});
        
        if (try read.boolean()) {
            const coupling_steps = try read.int_add_one(8);
            mapping.coupling = u.alloc_slice(Couple, coupling_steps);
        } else {
            mapping.coupling = &.{};
        }
        errdefer if (mapping.coupling.len > 0) u.free_slice(mapping.coupling);
        for (mapping.coupling) |*couple| {
            couple.magnitude = try read.int_max(u8, @intCast(channel_count - 1));
            couple.angle = try read.int_max(u8, @intCast(channel_count - 1));
            u.log(.{"Coupling ",couple.magnitude," - ",couple.angle});
            if (couple.magnitude == couple.angle) {
                return error.invalid_coupling;
            }
        }
        
        if (try read.int(u2) != 0) {
            return error.invalid_reserved_field;
        }
        mapping.multiplex = u.alloc_slice(u5, channel_count);
        errdefer u.free_slice(mapping.multiplex);
        if (submap_count > 1) {
            for (mapping.multiplex, 0..) |*mux, i| {
                mux.* = try read.int(u4); // the submap that this channels uses
                u.log(.{"Multiplex ",i,": ",mux.*});
                if (mux.* >= submap_count) {
                    return error.invalid_submap;
                }
            }
        } else {
            @memset(mapping.multiplex, 0);
        }
        
        mapping.submap_channels = u.alloc_slice(u8, channel_count);
        errdefer u.free_slice(mapping.submap_channels);
        mapping.submap_count = u.alloc_slice(u8, submap_count);
        errdefer u.free_slice(mapping.submap_count);
        var channels_index: usize = 0;
        for (mapping.submap_count, 0..) |*channels_in_map, submap| {
            channels_in_map.* = 0;
            for (mapping.multiplex, 0..) |channel_submap, channel| {
                if (channel_submap == submap) {
                    mapping.submap_channels[channels_index] = @intCast(channel);
                    channels_index += 1;
                    channels_in_map.* += 1;
                }
            }
        }
        u.assert(channels_index == channel_count);
        
        mapping.submaps = u.alloc_slice(Submap, submap_count);
        for (mapping.submaps, 0..) |*submap, i| {
            _ = try read.int(u8); // unused time configuration
            submap.floor = try read.int(u8);
            u.log(.{"Submap ",i," floor: ",submap.floor});
            if (submap.floor >= floor_count) {
                return error.invalid_floor;
            }
            submap.residu = try read.int(u8);
            u.log(.{"Submap ",i," residu: ",submap.residu});
            if (submap.residu >= residu_count) {
                return error.invalid_residu;
            }
        }
    }
    
    pub fn deinit(mapping: *Mapping) void {
        if (mapping.coupling.len > 0) {
            u.free_slice(mapping.coupling);
        }
        u.free_slice(mapping.multiplex);
        u.free_slice(mapping.submaps);
        u.free_slice(mapping.submap_channels);
        u.free_slice(mapping.submap_count);
    }
};

pub const Mode = struct {
    long_block: bool,
    mapping: u8,
    
    pub fn init(mode: *Mode, read: *Packet_reader, mapping_count: usize) !void {
        u.log_start(.{"Parsing mode"});
        defer u.log_end(.{});
        
        mode.long_block = try read.boolean();
        u.log(.{"Long block: ",mode.long_block});
        if (try read.int(u16) != 0) {
            return error.invalid_window_type;
        }
        if (try read.int(u16) != 0) {
            return error.invalid_transform_type;
        }
        
        mode.mapping = try read.int(u8);
        u.log(.{"Mapping: ",mode.mapping});
        if (mode.mapping >= mapping_count) {
            return error.invalid_mapping;
        }
    }
};

pub const Precomputed = struct {
    window_shape: []f32, // size / 2
    // Twiddle factors as described in https://media.taricorp.net/eusipco_corrected.pdf
    imdct_a: []f32, // size / 2
    imdct_b: []f32, // size / 2
    imdct_c: []f32, // size / 4
    bitreverse: []usize, // size / 8
    
    pub fn init(pre: *Precomputed, size: usize) void {
        pre.window_shape = u.alloc_slice(f32, size / 2);
        pre.imdct_a = u.alloc_slice(f32, size / 2);
        pre.imdct_b = u.alloc_slice(f32, size / 2);
        pre.imdct_c = u.alloc_slice(f32, size / 4);
        pre.bitreverse = u.alloc_slice(usize, size / 8);
        draw_window(pre.window_shape);
        
        const size_f: f32 = @floatFromInt(size);
        var i_f: f32 = 0;
        for (0 .. size / 4) |i| {
            const angle = 4 * i_f * std.math.pi / size_f;
            pre.imdct_a[2 * i] = std.math.cos(angle);
            pre.imdct_a[2 * i + 1] = -std.math.sin(angle);
            i_f += 1;
        }
        
        i_f = 0;
        for (0 .. size / 4) |i| {
            const angle = (2 * i_f + 1) * std.math.pi / (2 * size_f);
            pre.imdct_b[2 * i] = std.math.cos(angle);
            pre.imdct_b[2 * i + 1] = std.math.sin(angle);
            i_f += 1;
        }
        
        i_f = 0;
        for (0 .. size / 8) |i| {
            const angle = 2 * (2 * i_f + 1) * std.math.pi / size_f;
            pre.imdct_c[2 * i] = std.math.cos(angle);
            pre.imdct_c[2 * i + 1] = -std.math.sin(angle);
            i_f += 1;
        }
        
        var reverse: usize = 0;
        for (0 .. size / 8) |i| {
            pre.bitreverse[i] = reverse;
            var bit: usize = (size / 8) >> 1;
            while (reverse & bit > 0) {
                reverse ^= bit;
                bit >>= 1;
            }
            reverse |= bit;
        }
    }
    
    fn draw_window(result: []f32) void {
        const window_size: f32 = @floatFromInt(result.len * 2);
        var x: f32 = 0.5;
        for (result) |*store| {
            const inner = std.math.sin(x / window_size * std.math.pi);
            store.* = std.math.sin(0.5 * std.math.pi * inner * inner);
            x += 1;
        }
    }
    
    pub fn deinit(pre: *Precomputed) void {
        u.free_slice(pre.window_shape);
        u.free_slice(pre.imdct_a);
        u.free_slice(pre.imdct_b);
        u.free_slice(pre.imdct_c);
        u.free_slice(pre.bitreverse);
    }
};

pub const Decoder = struct {
    const Init_state = enum {
        start, // no packets received yet, waiting for identification header
        identification, // received identification header, waiting for comment header
        comment, // received identification and comment header, waiting for setup header
        ready, // ready to decode audio
    };
    init_state: Init_state,
    
    channels: u8,
    sample_rate: u32,
    nominal_bitrate: ?u32,
    minimum_bitrate: ?u32,
    maximum_bitrate: ?u32,
    blocksize_0: usize,
    blocksize_1: usize,
    
    vendor_comment: []u8,
    comments: [][]u8,
    
    codebooks: []Codebook,
    floors: []Floor_type,
    residu: []Residu,
    mappings: []Mapping,
    modes: []Mode,
    
    precomputed: [2]Precomputed,
    floor_result: []f32,
    no_residu: []bool,
    residu_result: []f32,
    residu_classifications: []u8,
    imdct_temp: []f32, // blocksize_1
    imdct_temp_stereo: []@Vector(2, f32), // blocksize_1, only if channels == 2
    signal: []f32, // blocksize_1 * channels
    result_1: []f32, // blocksize_1 / 2 * channels
    result_2: []f32,
    result_current: bool, // false means old right in 1, new left in 1, new right in 2. true means old right in 2, new left in 2, new right in 1.
    is_first: bool,
    next_merge_start: usize,
    
    const Floor_type = union (enum) {
        type_0: Floor_0,
        type_1: Floor_1,
    };
    
    pub fn init(d: *Decoder) void {
        d.init_state = .start;
        d.channels = 0;
        d.sample_rate = 0;
    }
    
    pub fn deinit(d: *Decoder) void {
        switch (d.init_state) {
            .start, .identification => {},
            .comment, .ready => {
                u.free_slice(d.vendor_comment);
                for (d.comments) |comment| {
                    u.free_slice(comment);
                }
                u.free_slice(d.comments);
            },
        }
        if (d.init_state == .ready) {
            for (d.codebooks) |*codebook| {
                codebook.deinit();
            }
            u.free_slice(d.codebooks);
            for (d.floors) |*floor| {
                switch (floor.*) {
                    .type_0 => |*floor_0| floor_0.deinit(),
                    .type_1 => |*floor_1| floor_1.deinit(),
                }
            }
            u.free_slice(d.floors);
            for (d.residu) |*residu| {
                residu.deinit();
            }
            u.free_slice(d.residu);
            for (d.mappings) |*mapping| {
                mapping.deinit();
            }
            u.free_slice(d.mappings);
            u.free_slice(d.modes);
            d.precomputed[0].deinit();
            d.precomputed[1].deinit();
            u.free_slice(d.floor_result);
            u.free_slice(d.no_residu);
            u.free_slice(d.residu_result);
            u.free_slice(d.residu_classifications);
            u.free_slice(d.imdct_temp);
            if (d.channels == 2) {
                u.free_slice(d.imdct_temp_stereo);
            }
            u.free_slice(d.signal);
            u.free_slice(d.result_1);
            u.free_slice(d.result_2);
        }
    }
    
    pub fn create() Decoder {
        var d: Decoder = undefined;
        d.init();
        return d;
    }
    
    /// Process the next vorbis packet
    /// The packets send to this function must be in order
    /// Returns the audio that this packet generated (if any)
    /// The returned slice needs to be freed with u.free_slice
    pub fn next(d: *Decoder, packet: []const u8) ![]f32 {
        var read = Packet_reader.create(packet);
        
        switch(d.init_state) {
            .start => {
                try d.parse_identification_header(&read);
                d.init_state = .identification;
                return &.{};
            },
            .identification => {
                try d.parse_comment_header(&read);
                d.init_state = .comment;
                return &.{};
            },
            .comment => {
                try d.parse_setup_header(&read);
                d.init_state = .ready;
                return &.{};
            },
            .ready => {
                return try d.decode_audio(&read);
            },
        }
    }
    
    fn parse_identification_header(d: *Decoder, read: *Packet_reader) !void {
        u.log_start(.{"Reading identification header"});
        defer u.log_end(.{});
        
        try expect_header_start(read, 1);
        const version = try read.int(u32);
        if (version != 0) return error.wrong_version;
        
        d.channels = try read.int(u8);
        if (d.channels == 0) {
            return error.no_channels;
        }
        u.log(.{d.channels," channels"});
        d.sample_rate = try read.int(u32);
        if (d.sample_rate == 0) {
            return error.no_sample_rate;
        }
        u.log(.{"Sample rate: ",d.sample_rate});
        
        d.maximum_bitrate = try read.int(u32);
        if (d.maximum_bitrate == 0) {
            d.maximum_bitrate = null;
        }
        d.nominal_bitrate = try read.int(u32);
        if (d.nominal_bitrate == 0) {
            d.nominal_bitrate = null;
        }
        d.minimum_bitrate = try read.int(u32);
        if (d.minimum_bitrate == 0) {
            d.minimum_bitrate = null;
        }
        if (d.nominal_bitrate) |nominal| {
            u.log(.{"Nominal bitrate: ",nominal});
        }
        if (d.minimum_bitrate) |minimum| {
            u.log(.{"Minimum bitrate: ",minimum});
        }
        if (d.maximum_bitrate) |maximum| {
            u.log(.{"Maximum bitrate: ",maximum});
        }
        
        d.blocksize_0 = try read_identification_blocksize(read);
        d.blocksize_1 = try read_identification_blocksize(read);
        if (d.blocksize_0 > d.blocksize_1) {
            return error.wrong_blocksize_combination;
        }
        u.log(.{"Blocksize 0: ",d.blocksize_0});
        u.log(.{"Blocksize 1: ",d.blocksize_1});
        
        if (!try read.boolean()) { // framing flag
            return error.framing_flag_not_set;
        }
    }
    
    fn read_identification_blocksize(read: *Packet_reader) !usize {
        const exponent = try read.int(u4);
        if (exponent < 6) { // 2^6 = 64
            return error.blocksize_too_low;
        }
        if (exponent > 13) { // 2^13 = 8192
            return error.blocksize_too_high;
        }
        return @as(usize, 1) << exponent;
    }
    
    fn parse_comment_header(d: *Decoder, read: *Packet_reader) !void {
        u.log_start(.{"Reading comment header"});
        defer u.log_end(.{});
        try expect_header_start(read, 3);
        
        d.vendor_comment = try read_length_encoded_string(read);
        u.log(.{"Vendor comment: ",d.vendor_comment});
        const comment_count = try read.int(u32);
        d.comments = u.alloc_slice([]u8, comment_count);
        u.log_start(.{"Comments"});
        for (d.comments) |*comment| {
            comment.* = try read_length_encoded_string(read);
            u.log(comment.*);
        }
        u.log_end(.{});
        
        if (!try read.boolean()) { // framing flag
            return error.framing_flag_not_set;
        }
    }
    
    fn read_length_encoded_string(read: *Packet_reader) ![]u8 {
        const size = try read.int(u32);
        const data = u.alloc_slice(u8, size);
        for (data) |*c| {
            c.* = try read.int(u8);
        }
        return data;
    }
    
    fn parse_setup_header(d: *Decoder, read: *Packet_reader) !void {
        u.log_start(.{"Reading setup header"});
        defer u.log_end(.{});
        try expect_header_start(read, 5);
        
        try d.parse_codebooks(read);
        
        const count_time_transforms = try read.int_add_one(6);
        for (0..count_time_transforms) |_| {
            if (try read.int(u16) != 0) {
                return error.time_transform_not_zero;
            }
        }
        
        const count_floors = try read.int_add_one(6);
        d.floors = u.alloc_slice(Floor_type, count_floors);
        for (d.floors) |*store_floor| {
            const floor_type = try read.int(u16);
            if (floor_type == 0) {
                store_floor.* = .{
                    .type_0 = undefined,
                };
                try store_floor.type_0.init(read, d.codebooks.len);
            } else if (floor_type == 1) {
                store_floor.* = .{
                    .type_1 = undefined,
                };
                try store_floor.type_1.init(read, d.codebooks.len);
            } else {
                return error.invalid_floor_type;
            }
        }
        
        const residu_count = try read.int_add_one(6);
        d.residu = u.alloc_slice(Residu, residu_count);
        for (d.residu) |*residu| {
            try residu.init(read);
        }
        
        const mapping_count = try read.int_add_one(6);
        d.mappings = u.alloc_slice(Mapping, mapping_count);
        for (d.mappings) |*mapping| {
            try mapping.init(read, d.channels, d.floors.len, d.residu.len);
        }
        
        const mode_count = try read.int_add_one(6);
        d.modes = u.alloc_slice(Mode, mode_count);
        for (d.modes) |*mode| {
            try mode.init(read, mapping_count);
        }
        
        if (!try read.boolean()) { // framing flag
            return error.framing_flag_not_set;
        }
        
        const result_stride = d.blocksize_1 / 2;
        d.precomputed[0].init(d.blocksize_0);
        d.precomputed[1].init(d.blocksize_1);
        d.floor_result = u.alloc_slice(f32, d.channels * result_stride);
        d.no_residu = u.alloc_slice(bool, d.channels);
        d.residu_result = u.alloc_slice(f32, d.channels * result_stride);
        d.residu_classifications = u.alloc_slice(u8, d.channels * result_stride);
        d.imdct_temp = u.alloc_slice(f32, d.blocksize_1);
        if (d.channels == 2) {
            d.imdct_temp_stereo = u.alloc_slice(@Vector(2, f32), d.blocksize_1);
        }
        d.signal = u.alloc_slice(f32, d.channels * d.blocksize_1);
        d.result_1 = u.alloc_slice(f32, d.channels * result_stride);
        d.result_2 = u.alloc_slice(f32, d.channels * result_stride);
        d.result_current = false;
        d.is_first = true;
    }
    
    fn parse_codebooks(d: *Decoder, read: *Packet_reader) !void {
        const count = try read.int_add_one(8);
        d.codebooks = u.alloc_slice(Codebook, count);
        for (d.codebooks) |*codebook| {
            try codebook.init(read);
        }
    }
    
    fn decode_audio(d: *Decoder, read: *Packet_reader) ![]f32 {
        u.log_start(.{"Reading audio packet"});
        defer u.log_end(.{});
        
        if (try read.boolean()) {
            return error.expected_audio_packet;
        }
        const mode_number = try read.int_max(usize, d.modes.len - 1);
        u.log(.{"Mode ",mode_number});
        const mode = d.modes[mode_number];
        const current_blocksize = if (mode.long_block) d.blocksize_1 else d.blocksize_0;
        u.log(.{"Current blocksize ",current_blocksize});
        const spectrum_size = current_blocksize / 2;
        const result_stride = d.blocksize_1 / 2;
        
        var previous_long: bool = undefined;
        var next_long: bool = undefined;
        if (mode.long_block) {
            previous_long = try read.boolean();
            next_long = try read.boolean();
        }
        const window_center = current_blocksize / 2;
        var left_window_start: usize = 0;
        var left_window_end = window_center;
        var left_window_size = current_blocksize / 2;
        if (mode.long_block and !previous_long) {
            left_window_start = current_blocksize / 4 - d.blocksize_0 / 4;
            left_window_end = current_blocksize / 4 + d.blocksize_0 / 4;
            left_window_size = d.blocksize_0 / 2;
        }
        var right_window_start = window_center;
        var right_window_end = current_blocksize;
        var right_window_size = current_blocksize / 2;
        if (mode.long_block and !next_long) {
            right_window_start = current_blocksize * 3 / 4 - d.blocksize_0 / 4;
            right_window_end = current_blocksize * 3 / 4 + d.blocksize_0 / 4;
            right_window_size = d.blocksize_0 / 2;
        }
        
        const mapping = &d.mappings[mode.mapping];
        for (0..d.channels, d.no_residu) |channel, *no_residu| {
            const channel_floor = d.floor_result[channel * result_stride ..][0..spectrum_size];
            const submap_nr = mapping.multiplex[channel];
            const submap = mapping.submaps[submap_nr];
            const floor = &d.floors[submap.floor];
            no_residu.* = switch (floor.*) {
                .type_0 => |*floor_0| !try floor_0.decode(channel_floor, read, d.codebooks),
                .type_1 => |*floor_1| !try floor_1.decode(channel_floor, read, d.codebooks),
            };
            u.log(.{"No residu: ",no_residu.*});
        }
        
        var channel_index: usize = 0;
        for (0..mapping.submaps.len, mapping.submap_count) |submap, channel_count| {
            const channels = mapping.submap_channels[channel_index..][0..channel_count];
            const residu = &d.residu[mapping.submaps[submap].residu];
            try residu.decode(read, channels, spectrum_size, d.residu_result, d.no_residu, result_stride, d.codebooks, d.residu_classifications);
            channel_index += channel_count;
        }
        
        if (d.channels == 2 and mapping.coupling.len == 1 and mapping.coupling[0].magnitude == 0 and mapping.coupling[0].angle == 1) {
            d.inverse_mdct_stereo(spectrum_size * 2);
        } else {
            var coupling_i: usize = mapping.coupling.len;
            while (coupling_i > 0) {
                coupling_i -= 1;
                const couple = mapping.coupling[coupling_i];
                const mag_residu = d.residu_result[result_stride * couple.magnitude ..][0..spectrum_size];
                const angle_residu = d.residu_result[result_stride * couple.angle ..][0..spectrum_size];
                for (mag_residu, angle_residu) |*m, *a| {
                    do_coupling(m, a);
                }
            }
            
            for (0..d.channels) |channel| {
                d.inverse_mdct(@intCast(channel), spectrum_size * 2);
            }
        }
        
        // channels are interleaved
        const result_merge = if (d.result_current) d.result_2 else d.result_1;
        const result_next = if (d.result_current) d.result_1 else d.result_2;
        // left_window_start .. window_center will be stored at result_merge[merge_start ..]
        // window_center .. right_window_end will be stored at result_next with next_extra zeros
        var merge_start: usize = 0;
        if (!d.is_first) {
            merge_start = d.next_merge_start;
            d.fill_result(result_merge, merge_start, left_window_start, left_window_end, .start, true);
            d.fill_result(result_merge, merge_start + left_window_size, left_window_end, window_center, .one, false);
//             d.fill_result(result_merge, merge_start, d.floor_result, d.residu_result, result_stride, spectrum_size, left_window_start, left_window_end, .start, true);
//             d.fill_result(result_merge, merge_start + left_window_size, d.floor_result, d.residu_result, result_stride, spectrum_size, left_window_end, window_center, .one, false);
        } // otherwise no merge
        d.fill_result(result_next, 0, window_center, right_window_start, .one, false);
        d.fill_result(result_next, right_window_start - window_center, right_window_start, right_window_end, .end, false);
//         d.fill_result(result_next, 0, d.floor_result, d.residu_result, result_stride, spectrum_size, window_center, right_window_start, .one, false);
//         d.fill_result(result_next, right_window_start - window_center, d.floor_result, d.residu_result, result_stride, spectrum_size, right_window_start, right_window_end, .end, false);
        
        //d.fill_result(result_next, 0, d.floor_result, d.residu_result, result_stride, spectrum_size, 0, window_center, .one, false);
        
        d.result_current = !d.result_current;
        d.next_merge_start = right_window_start - window_center;
        if (d.is_first) {
            d.is_first = false;
            return &.{};
        } else {
            return result_merge[0 .. (merge_start + window_center - left_window_start) * d.channels];
        }
    }
    
    fn do_coupling(m: *f32, a: *f32) void {
        const old_m = m.*;
        const old_a = a.*;
        const m_h: usize = @intFromBool(old_m > 0);
        const a_h: usize = @intFromBool(old_a > 0);
        const m_list = [4]f32 {-1, 0, 1, 0};
        const a_list = [4]f32 {0, 1, 0, -1};
        const m_f = m_list[m_h * 2 + a_h];
        const a_f = a_list[m_h * 2 + a_h];
        m.* = old_m + m_f * old_a;
        a.* = old_m + a_f * old_a;
    }
    
    /// n = blocksize (output)
    fn inverse_mdct(d: *Decoder, channel: u8, n: usize) void {
        // As described in https://media.taricorp.net/eusipco_corrected.pdf
        const values = d.imdct_temp;
        const floor = d.floor_result[channel * d.blocksize_1 / 2 ..][0 .. n / 2];
        const residu = d.residu_result[channel * d.blocksize_1 / 2 ..][0 .. n / 2];
        const pre = if (n == d.blocksize_0) (
            d.precomputed[0]
        ) else if (n == d.blocksize_1) (
            d.precomputed[1]
        ) else @panic("called with wrong blocksize"); // should be unreachable
        
        // prepare
        for (0 .. n / 2) |i| {
            const val = floor[i] * residu[i];
            values[i] = val;
            values[n - 1 - i] = -val;
        }
        
        // step 1
        for (0 .. n / 4) |i| {
            const a = values[4 * i] - values[n - 4 * i - 1];
            const b = values[4 * i + 2] - values[n - 4 * i - 3];
            const imdct_a1 = pre.imdct_a[2 * i];
            const imdct_a2 = pre.imdct_a[2 * i + 1];
            values[n - 4 * i - 1] = a * imdct_a1 - b * imdct_a2;
            values[n - 4 * i - 3] = a * imdct_a2 + b * imdct_a1;
        }
        
        // step 2
        for (0 .. n / 8) |i| {
            const a1 = values[n / 2 + 3 + 4 * i];
            const a2 = values[4 * i + 3];
            const b1 = values[n / 2 + 1 + 4 * i];
            const b2 = values[4 * i + 1];
            values[n / 2 + 3 + 4 * i] = a1 + a2;
            values[n / 2 + 1 + 4 * i] = b1 + b2;
            const a = a1 - a2;
            const b = b1 - b2;
            const imdct_a1 = pre.imdct_a[n / 2 - 4 - 4 * i];
            const imdct_a2 = pre.imdct_a[n / 2 - 3 - 4 * i];
            values[4 * i + 3] = a * imdct_a1 - b * imdct_a2;
            values[4 * i + 1] = b * imdct_a1 + a * imdct_a2;
        }
        
        // step 3
        var lval: usize = 2; // 2 ^ (l + 1)
        // 2 ^ (log(n) - 4 + 1) = 2 ^ (log(n) - 3) = 2 ^ log(n) / 2^3 = n / 8
        while (lval <= n / 8): (lval *= 2) {
            const k_0 = n / (lval * 2);
            const k_1 = lval * 4;
            for (0 .. n / (lval * 8)) |r| {
                for (0 .. lval) |s| {
                    const a1_i = n - 1 - k_0 * 2 * s - 4 * r;
                    const a2_i = n - 1 - k_0 * (2 * s + 1) - 4 * r;
                    const b1_i = n - 3 - k_0 * 2 * s - 4 * r;
                    const b2_i = n - 3 - k_0 * (2 * s + 1) - 4 * r;
                    const a1 = values[a1_i];
                    const a2 = values[a2_i];
                    const b1 = values[b1_i];
                    const b2 = values[b2_i];
                    const a = a1 - a2;
                    const b = b1 - b2;
                    const imdct_a1 = pre.imdct_a[r * k_1];
                    const imdct_a2 = pre.imdct_a[r * k_1 + 1];
                    values[a1_i] = a1 + a2;
                    values[b1_i] = b1 + b2;
                    values[a2_i] = a * imdct_a1 - b * imdct_a2;
                    values[b2_i] = b * imdct_a1 + a * imdct_a2;
                }
            }
        }
        
        // step 4
        for (1 .. n / 8 - 1) |i| {
            const j = pre.bitreverse[i];
            if (i < j) {
                const v1 = values[8 * j + 1];
                const v2 = values[8 * j + 3];
                const v3 = values[8 * j + 5];
                const v4 = values[8 * j + 7];
                values[8 * j + 1] = values[8 * i + 1];
                values[8 * j + 3] = values[8 * i + 3];
                values[8 * j + 5] = values[8 * i + 5];
                values[8 * j + 7] = values[8 * i + 7];
                values[8 * i + 1] = v1;
                values[8 * i + 3] = v2;
                values[8 * i + 5] = v3;
                values[8 * i + 7] = v4;
            }
        }
        
        // step 5
        for (0 .. n / 2) |i| {
            values[i] = values[2 * i + 1];
        }
        
        // step 6
        for (0 .. n / 8) |i| {
            const v1 = values[4 * i];
            const v2 = values[4 * i + 1];
            const v3 = values[4 * i + 2];
            const v4 = values[4 * i + 3];
            values[n - 1 - 2 * i] = v1;
            values[n - 2 - 2 * i] = v2;
            values[3 * n / 4 - 1 - 2 * i] = v3;
            values[3 * n / 4 - 2 - 2 * i] = v4;
        }
        
        // step 7
        for (0 .. n / 8) |i| {
            const a0 = values[n / 2 + 2 * i];
            const a1 = values[n / 2 + 2 * i + 1];
            const b0 = values[n - 2 - 2 * i];
            const b1 = values[n - 2 - 2 * i + 1];
            const c0 = pre.imdct_c[2 * i];
            const c1 = pre.imdct_c[2 * i + 1];
            values[n / 2 + 2 * i] = (a0 + b0 + c1 * (a0 - b0) + c0 * (a1 + b1)) / 2;
            values[n - 2 - 2 * i] = (a0 + b0 - c1 * (a0 - b0) - c0 * (a1 + b1)) / 2;
            values[n / 2 + 1 + 2 * i] = (a1 - b1 + c1 * (a1 + b1) - c0 * (a0 - b0)) / 2;
            values[n - 2 * i - 1] = (-a1 + b1 + c1 * (a1 + b1) - c0 * (a0 - b0)) / 2;
        }
        
        // step 8
        for (0 .. n / 4) |i| {
            const a0 = values[2 * i + n / 2];
            const a1 = values[2 * i + n / 2 + 1];
            const b0 = pre.imdct_b[2 * i];
            const b1 = pre.imdct_b[2 * i + 1];
            const v1 = 0.5 * (a0 * b0 + a1 * b1);
            const v2 = 0.5 * (a0 * b1 - a1 * b0);
            d.signal[(i + n * 3 / 4) * d.channels + channel] = -v1;
            d.signal[(n * 3 / 4 - 1 - i) * d.channels + channel] = -v1;
            d.signal[(n / 4 + i) * d.channels + channel] = -v2;
            d.signal[(n / 4 - 1 - i) * d.channels + channel] = v2;
        }
    }
    
    /// n = blocksize (output)
    fn inverse_mdct_stereo(d: *Decoder, n: usize) void {
        // As described in https://media.taricorp.net/eusipco_corrected.pdf
        const n2 = n / 2;
        const n8 = n / 8;
        const n32 = n * 3 / 2;
        const n34 = n * 3 / 4;
        const values = d.imdct_temp_stereo;
        const floor0 = d.floor_result[0 .. n / 2];
        const floor1 = d.floor_result[d.blocksize_1 / 2 ..][0 .. n / 2];
        const residu_mag = d.residu_result[0 .. n / 2];
        const residu_ang = d.residu_result[d.blocksize_1 / 2 ..][0 .. n / 2];
        const pre = if (n == d.blocksize_0) (
            d.precomputed[0]
        ) else if (n == d.blocksize_1) (
            d.precomputed[1]
        ) else @panic("called with wrong blocksize"); // should be unreachable
        
        // prepare
        for (0 .. n2) |i| {
            const old_m = residu_mag[i];
            const old_a = residu_ang[i];
            const m_h: usize = @intFromBool(old_m > 0);
            const a_h: usize = @intFromBool(old_a > 0);
            const m_list = [4]f32 {-1, 0, 1, 0};
            const a_list = [4]f32 {0, 1, 0, -1};
            const m_f = m_list[m_h * 2 + a_h];
            const a_f = a_list[m_h * 2 + a_h];
            const res_0 = old_m + m_f * old_a;
            const res_1 = old_m + a_f * old_a;
            
            const val = @Vector(2, f32) {
                floor0[i] * res_0,
                floor1[i] * res_1,
            };
            values[i] = val;
            values[n - 1 - i] = -val;
        }
        
        // step 1
        var k: usize = 0;
        var k2: usize = n + 3;
        while (k < n2): (k += 2) {
            k2 -= 4;
            const a = values[2 * k] - values[k2];
            const b = values[2 * k + 2] - values[k2 - 2];
            const imdct_a1: @Vector(2, f32) = @splat(pre.imdct_a[k]);
            const imdct_a2: @Vector(2, f32) = @splat(pre.imdct_a[k + 1]);
            values[k2] = a * imdct_a1 - b * imdct_a2;
            values[k2 - 2] = a * imdct_a2 + b * imdct_a1;
        }
        
        // step 2
        k = 0;
        while (k < n2): (k += 4) {
            const a1 = values[n2 + k + 3];
            const a2 = values[k + 3];
            const b1 = values[n2 + k + 1];
            const b2 = values[k + 1];
            values[n2 + k + 3] = a1 + a2;
            values[n2 + k + 1] = b1 + b2;
            const a = a1 - a2;
            const b = b1 - b2;
            const imdct_a1: @Vector(2, f32) = @splat(pre.imdct_a[n2 - k - 4]);
            const imdct_a2: @Vector(2, f32) = @splat(pre.imdct_a[n2 - k - 3]);
            values[k + 3] = a * imdct_a1 - b * imdct_a2;
            values[k + 1] = b * imdct_a1 + a * imdct_a2;
        }
        
        // step 3
        var lval: usize = 2; // 2 ^ (l + 1)
        // 2 ^ (log(n) - 4 + 1) = 2 ^ (log(n) - 3) = 2 ^ log(n) / 2^3 = n / 8
        while (lval <= n8): (lval *= 2) {
            const k_0 = n / (lval * 2);
            const k_1 = lval * 4;
            for (0 .. n / (lval * 8)) |r| {
                const imdct_a1: @Vector(2, f32) = @splat(pre.imdct_a[r * k_1]);
                const imdct_a2: @Vector(2, f32) = @splat(pre.imdct_a[r * k_1 + 1]);
                for (0 .. lval) |s| {
                    const a1_i = n - 1 - k_0 * 2 * s - 4 * r;
                    const a2_i = n - 1 - k_0 * (2 * s + 1) - 4 * r;
                    const b1_i = n - 3 - k_0 * 2 * s - 4 * r;
                    const b2_i = n - 3 - k_0 * (2 * s + 1) - 4 * r;
                    const a1 = values[a1_i];
                    const a2 = values[a2_i];
                    const b1 = values[b1_i];
                    const b2 = values[b2_i];
                    const a = a1 - a2;
                    const b = b1 - b2;
                    values[a1_i] = a1 + a2;
                    values[b1_i] = b1 + b2;
                    values[a2_i] = a * imdct_a1 - b * imdct_a2;
                    values[b2_i] = b * imdct_a1 + a * imdct_a2;
                }
            }
        }
        
        // step 4
        for (1 .. n8 - 1) |i| {
            const j = pre.bitreverse[i];
            if (i < j) {
                const v1 = values[8 * j + 1];
                const v2 = values[8 * j + 3];
                const v3 = values[8 * j + 5];
                const v4 = values[8 * j + 7];
                values[8 * j + 1] = values[8 * i + 1];
                values[8 * j + 3] = values[8 * i + 3];
                values[8 * j + 5] = values[8 * i + 5];
                values[8 * j + 7] = values[8 * i + 7];
                values[8 * i + 1] = v1;
                values[8 * i + 3] = v2;
                values[8 * i + 5] = v3;
                values[8 * i + 7] = v4;
            }
        }
        
        // step 5
        for (0 .. n2) |i| {
            values[i] = values[2 * i + 1];
        }
        
        // step 6
        for (0 .. n8) |i| {
            const v1 = values[4 * i];
            const v2 = values[4 * i + 1];
            const v3 = values[4 * i + 2];
            const v4 = values[4 * i + 3];
            values[n - 2 * i - 1] = v1;
            values[n - 2 * i - 2] = v2;
            values[n34 - 2 * i - 1] = v3;
            values[n34 - 2 * i - 2] = v4;
        }
        
        // step 7
        for (0 .. n8) |i| {
            const a0 = values[n2 + 2 * i];
            const a1 = values[n2 + 2 * i + 1];
            const b0 = values[n - 2 - 2 * i];
            const b1 = values[n - 2 - 2 * i + 1];
            const c0: @Vector(2, f32) = @splat(pre.imdct_c[2 * i]);
            const c1: @Vector(2, f32) = @splat(pre.imdct_c[2 * i + 1]);
            const factor: @Vector(2, f32) = @splat(0.25);
            values[n2 + 2 * i] = (a0 + b0 + c1 * (a0 - b0) + c0 * (a1 + b1)) * factor;
            values[n - 2 - 2 * i] = (a0 + b0 - c1 * (a0 - b0) - c0 * (a1 + b1)) * factor;
            values[n2 + 1 + 2 * i] = (a1 - b1 + c1 * (a1 + b1) - c0 * (a0 - b0)) * factor;
            values[n - 2 * i - 1] = (-a1 + b1 + c1 * (a1 + b1) - c0 * (a0 - b0)) * factor;
        }
        
        // step 8
        k = 0;
        while (k < n2): (k += 2) {
            const a0 = values[k + n2];
            const a1 = values[k + n2 + 1];
            const b0: @Vector(2, f32) = @splat(pre.imdct_b[k]);
            const b1: @Vector(2, f32) = @splat(pre.imdct_b[k + 1]);
            const v1 = a0 * b0 + a1 * b1;
            const v2 = a0 * b1 - a1 * b0;
            d.signal[n32 + k] = -v1[0];
            d.signal[n32 + k + 1] = -v1[1];
            d.signal[n32 - k - 2] = -v1[0];
            d.signal[n32 - k - 1] = -v1[1];
            d.signal[n2 + k] = -v2[0];
            d.signal[n2 + k + 1] = -v2[1];
            d.signal[n2 - k - 2] = v2[0];
            d.signal[n2 - k - 1] = v2[1];
        }
    }
    
    const window_mode = enum {
        one,
        start,
        end,
    };
    fn fill_result(d: *Decoder, result: []f32, r_offset: usize, start: usize, end: usize, mode: window_mode, add: bool) void {
        if (start == end) {
            return;
        }
        if (d.channels == 2) {
            d.fill_result_stereo(result, r_offset, start, end, mode, add);
            return;
        }
        const len = end - start;
        var window_shape: []f32 = undefined;
        if (mode != .one) {
            if (end - start == d.blocksize_0 / 2) {
                window_shape = d.precomputed[0].window_shape;
            } else if (end - start == d.blocksize_1 / 2) {
                window_shape = d.precomputed[1].window_shape;
            } else @panic("vorbis: invalid fill range");
        }
        for (start..end, 0..) |index, offset| {
            const window_factor = switch (mode) {
                .one => 1,
                .start => window_shape[offset],
                .end => window_shape[len - 1 - offset],
            };
            const signal = d.signal[index * d.channels ..][0..d.channels];
            for (0..d.channels) |channel| {
                const value = signal[channel] * window_factor;
                const result_i = (r_offset + offset) * d.channels + channel;
                if (add) {
                    result[result_i] += value;
                } else {
                    result[result_i] = value;
                }
            }
        }
    }
    
    fn fill_result_stereo(d: *Decoder, result: []f32, r_offset: usize, start: usize, end: usize, mode: window_mode, add: bool) void {
        const len = end - start;
        var window_shape: []f32 = undefined;
        if (mode != .one) {
            if (end - start == d.blocksize_0 / 2) {
                window_shape = d.precomputed[0].window_shape;
            } else if (end - start == d.blocksize_1 / 2) {
                window_shape = d.precomputed[1].window_shape;
            } else @panic("vorbis: invalid fill range");
        }
        
        var index: usize = start * 2;
        var offset: usize = 0;
        const store: []f32 = result[r_offset * 2 ..];
        if (add) {
            const stop = end * 2;
            while (index < stop) {
                const window_factor = switch (mode) {
                    .one => 1,
                    .start => window_shape[offset],
                    .end => window_shape[len - 1 - offset],
                };
                store[offset * 2] += d.signal[index] * window_factor;
                store[offset * 2 + 1] += d.signal[index + 1] * window_factor;
                index += 2;
                offset += 1;
            }
        } else {
            const stop = end * 2;
            while (index < stop) {
                const window_factor = switch (mode) {
                    .one => 1,
                    .start => window_shape[offset],
                    .end => window_shape[len - 1 - offset],
                };
                store[offset * 2] = d.signal[index] * window_factor;
                store[offset * 2 + 1] = d.signal[index + 1] * window_factor;
                index += 2;
                offset += 1;
            }
        }
    }
    
    
    
    fn calculate_sample(index: usize, floor: []f32, residu: []f32) f32 {
        var result: f32 = 0;
        const size_f: f32 = @floatFromInt(floor.len);
        const index_f: f32 = @floatFromInt(index);
        for (floor, residu, 0..) |f, r, i| {
            const i_f: f32 = @floatFromInt(i);
            result += f * r * std.math.cos(std.math.pi / size_f * (index_f + 0.5 + size_f / 2) * (i_f + 0.5));
        }
        return result;
    }
    
    fn expect_header_start(read: *Packet_reader, packet_type: u8) !void {
        if (try read.int(u8) != packet_type) return error.wrong_packet_type;
        
        const header_pattern = try read.array(u8, 6);
        if (!std.mem.eql(u8, &header_pattern, "vorbis")) {
            return error.wrong_header_pattern;
        }
    }
};

const std = @import("std");
const u = @import("../util.zig");

const initial_capacity = 8;

pub fn List(Type: type) type {
    return struct {
        const Self = @This();
        buffer: []Type,
        count: usize,
        
        pub fn init_with_capacity(list: *Self, capacity: usize) void {
            list.buffer = u.alloc.alloc(Type, capacity) catch @panic("no memory");
            list.count = 0;
        }
        
        pub fn init(list: *Self) void {
            list.init_with_capacity(initial_capacity);
        }
        
        pub fn create_with_capacity(capacity: usize) Self {
            var list: Self = undefined;
            list.init_with_capacity(capacity);
            return list;
        }
        
        pub fn create() Self {
            return create_with_capacity(initial_capacity);
        }
        
        pub fn deinit(list: *Self) void {
            u.alloc.free(list.buffer);
        }
        
        pub fn get(list: *Self, index: usize) Type {
            u.assert(index < list.count);
            return list.buffer[index];
        }
        
        pub fn get_ptr(list: *Self, index: usize) *const Type {
            return list.get_mut(index);
        }
        
        pub fn get_mut(list: *Self, index: usize) *Type {
            u.assert(index < list.count);
            return &list.buffer[index];
        }
        
        pub fn set(list: *Self, index: usize, value: Type) void {
            u.assert(index < list.count);
            list.buffer[index] = value;
        }
        
        pub fn items(list: *Self) []const Type {
            return list.items_mut();
        }
        
        pub fn items_mut(list: *Self) []Type {
            return list.buffer[0..list.count];
        }
        
        pub fn ensure_capacity(list: *Self, capacity: usize) void {
            if (list.buffer.len < capacity) {
                const new_capacity: usize = u.next_power_of_two(@intCast(capacity));
                list.buffer = u.alloc.realloc(list.buffer, new_capacity) catch @panic("no memory");
            }
        }
        
        pub fn append_undefined(list: *Self, count: usize) void {
            const new_size = list.count + count;
            list.ensure_capacity(new_size);
            list.count = new_size;
        }
        
        pub fn append(list: *Self, value: Type) void {
            list.append_undefined(1);
            list.set(list.count - 1, value);
        }
        
        pub fn append_slice(list: *Self, values: []const Type) void {
            list.append_undefined(values.len);
            @memcpy(list.buffer[list.count-values.len..list.count], values);
        }
        
        pub fn get_append_ptr(list: *Self) *Type {
            list.append_undefined(1);
            return &list.buffer[list.count - 1];
        }
        
        pub fn get_append_slice(list: *Self, count: usize) []Type {
            list.append_undefined(count);
            return list.buffer[list.count-count..list.count];
        }
        
        pub fn remove_count(list: *Self, count: usize) void {
            u.assert(list.count >= count);
            list.count -= count;
        }
        
        pub fn pop(list: *Self) ?Type {
            if (list.count == 0) {
                return null;
            } else {
                const item = list.get(list.count - 1);
                list.count -= 1;
                return item;
            }
        }
        
        pub fn clear(list: *Self) void {
            list.count = 0;
        }
        
        pub fn reset_size(list: *Self, size: usize) void {
            list.clear();
            list.append_undefined(size);
        }
        
        pub const Writer = struct {
            list: *Self,
            
            pub fn write(w: *Writer, value: Type) void {
                w.list.append(value);
            }
        };
        
        pub fn writer(list: *Self) Writer {
            return .{
                .list = list,
            };
        }
        
        pub const Reader = struct {
            list: *Self,
            index: usize,
            
            pub fn read(r: *Reader) ?Type {
                if (r.index < r.list.count) {
                    return r.list.items()[r.index];
                } else {
                    return null;
                }
            }
        };
        
        pub fn iterator(list: *Self) Reader {
            return .{
                .list = list,
                .index = 0,
            };
        }
    };
}

const std = @import("std");
const u = @import("../util.zig");

const initial_capacity = 8;

pub fn Queue(Type: type) type {
    return struct {
        const Self = @This();
        buffer: []Type,
        start: usize, // start is always < buffer.len
        count: usize,
        
        pub fn init_with_capacity(queue: *Self, capacity: usize) void {
            queue.buffer = u.alloc_slice(Type, capacity);
            queue.start = 0;
            queue.count = 0;
        }
        
        pub fn init(queue: *Self) void {
            queue.init_with_capacity(initial_capacity);
        }
        
        pub fn create_with_capacity(capacity: usize) Self {
            var queue: Self = undefined;
            queue.init_with_capacity(capacity);
            return queue;
        }
        
        pub fn create() Self {
            return create_with_capacity(initial_capacity);
        }
        
        pub fn deinit(queue: *Self) void {
            u.alloc.free(queue.buffer);
        }
        
        pub fn is_empty(queue: *Self) bool {
            return queue.count == 0;
        }
        
        pub fn clear(queue: *Self) void {
            queue.start = 0;
            queue.count = 0;
        }
        
        pub fn get_mut(queue: *Self, index: usize) *Type {
            u.assert(index < queue.count);
            const buffer_index = queue.start + index;
            if (buffer_index >= queue.buffer.len) {
                return &queue.buffer[buffer_index - queue.buffer.len];
            } else {
                return &queue.buffer[buffer_index];
            }
        }
        
        pub fn get_ptr(queue: *Self, index: usize) *const Type {
            return queue.get_mut(index);
        }
        
        pub fn get(queue: *Self, index: usize) Type {
            return queue.get_ptr(index).*;
        }
        
        pub fn get_from_end_mut(queue: *Self, index: usize) *Type {
            u.assert(index < queue.count);
            return queue.get_mut(queue.count - 1 - index);
        }
        
        pub fn get_from_end_ptr(queue: *Self, index: usize) *const Type {
            return queue.get_from_end_mut(index);
        }
        
        pub fn get_from_end(queue: *Self, index: usize) Type {
            return queue.get_from_end_ptr(index).*;
        }
        
        pub fn get_start_mut(queue: *Self) *Type {
            return queue.get_mut(0);
        }
        
        pub fn get_start_ptr(queue: *Self) *const Type {
            return queue.get_start_mut();
        }
        
        pub fn get_start(queue: *Self) Type {
            return queue.get_start_ptr().*;
        }
        
        pub fn get_end_mut(queue: *Self) *Type {
            return queue.get_from_end_mut(0);
        }
        
        pub fn get_end_ptr(queue: *Self) *const Type {
            return queue.get_end_mut();
        }
        
        pub fn get_end(queue: *Self) Type {
            return queue.get_end_ptr().*;
        }
        
        fn ensure_capacity(queue: *Self, capacity: usize) void {
            const old_capacity = queue.buffer.len;
            if (old_capacity < capacity) {
                const new_capacity: usize = u.next_power_of_two(@intCast(capacity));
                queue.buffer = u.realloc(queue.buffer, new_capacity);
                
                u.assert(new_capacity >= old_capacity * 2);
                if (queue.start + queue.count > old_capacity) {
                    const overflowed_size = queue.start + queue.count - old_capacity;
                    @memcpy(queue.buffer[old_capacity .. old_capacity + overflowed_size], queue.buffer[0..overflowed_size]);
                }
            }
        }
        
        pub fn extend_start(queue: *Self, add_count: usize) void {
            queue.ensure_capacity(queue.count + add_count);
            queue.count += add_count;
            if (add_count > queue.start) { 
                queue.start += queue.buffer.len;
            }
            queue.start -= add_count;
        }
        
        pub fn extend_end(queue: *Self, add_count: usize) void {
            queue.ensure_capacity(queue.count + add_count);
            queue.count += add_count;
        }
        
        pub fn add_start_ptr(queue: *Self) *Type {
            queue.extend_start(1);
            return queue.get_start_mut();
        }
        
        pub fn add_start(queue: *Self, item: Type) void {
            queue.add_start_ptr().* = item;
        }
        
        pub fn add_end_ptr(queue: *Self) *Type {
            queue.extend_end(1);
            return queue.get_end_mut();
        }
        
        pub fn add_end(queue: *Self, item: Type) void {
            queue.add_end_ptr().* = item;
        }
        
        pub fn remove_start(queue: *Self, remove_count: usize) void {
            u.assert(queue.count >= remove_count);
            queue.count -= remove_count;
            queue.start += remove_count;
            if (queue.start >= queue.buffer.len) {
                queue.start -= queue.buffer.len;
            }
        }
        
        pub fn remove_end(queue: *Self, remove_count: usize) void {
            u.assert(queue.count >= remove_count);
            queue.count -= remove_count;
        }
        
        pub fn unsafe_pop_start_mut(queue: *Self) *Type {
            const popped = queue.get_start_mut();
            queue.remove_start(1);
            return popped;
        }
        
        pub fn unsafe_pop_start_ptr(queue: *Self) *const Type {
            return queue.unsafe_pop_start_mut();
        }
        
        pub fn unsafe_pop_start(queue: *Self) Type {
            return queue.unsafe_pop_start_ptr().*;
        }
        
        pub fn pop_start_mut(queue: *Self) ?*Type {
            if (queue.count > 0) {
                return queue.unsafe_pop_start_mut();
            } else {
                return null;
            }
        }
        
        pub fn pop_start_ptr(queue: *Self) ?*const Type {
            return queue.pop_start_mut();
        }
        
        pub fn pop_start(queue: *Self) ?Type {
            if (queue.pop_start_ptr()) |ptr| {
                return ptr.*;
            } else {
                return null;
            }
        }
        
        pub fn unsafe_pop_end_mut(queue: *Self) *Type {
            const popped = queue.get_end_mut();
            queue.remove_end(1);
            return popped;
        }
        
        pub fn unsafe_pop_end_ptr(queue: *Self) *const Type {
            return queue.unsafe_pop_end_mut();
        }
        
        pub fn unsafe_pop_end(queue: *Self) Type {
            return queue.unsafe_pop_end_ptr().*;
        }
        
        pub fn pop_end_mut(queue: *Self) ?*Type {
            if (queue.count > 0) {
                return queue.unsafe_pop_end_mut();
            } else {
                return null;
            }
        }
        
        pub fn pop_end_ptr(queue: *Self) ?*const Type {
            return queue.pop_end_mut();
        }
        
        pub fn pop_end(queue: *Self) ?Type {
            if (queue.pop_end_ptr()) |ptr| {
                return ptr.*;
            } else {
                return null;
            }
        }
        
        pub const Start_reader = struct {
            queue: *Self,
            
            pub fn read(r: *Start_reader) ?Type {
                return r.pop_start();
            }
        };
        
        pub fn start_reader(queue: *Self) Start_reader {
            return .{
                .queue = queue,
            };
        }
        
        pub const End_reader = struct {
            queue: *Self,
            
            pub fn read(r: *End_reader) ?Type {
                return r.pop_end();
            }
        };
        
        pub fn end_reader(queue: *Self) End_reader {
            return .{
                .queue = queue,
            };
        }
        
        pub const Start_writer = struct {
            queue: *Self,
            
            pub fn write(w: *Start_writer, value: Type) void {
                w.queue.add_start(value);
            }
        };
        
        pub fn start_writer(queue: *Self) Start_writer {
            return .{
                .queue = queue,
            };
        }
        
        pub const End_writer = struct {
            queue: *Self,
            
            pub fn write(w: *End_writer, value: Type) void {
                w.queue.add_end(value);
            }
        };
        
        pub fn end_writer(queue: *Self) End_writer {
            return .{
                .queue = queue,
            };
        }
    };
}

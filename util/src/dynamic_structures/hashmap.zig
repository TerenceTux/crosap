const u = @import("../util.zig");
const std = @import("std");


// https://en.wikipedia.org/wiki/Fowler–Noll–Vo_hash_function
pub fn general_hash(data: []const u8) u32 {
    const prime = 0x01000193;
    var value: u32 = 0x811c9dc5;
    for (data) |c| {
        value ^= c;
        value *%= prime;
    }
    return value;
}

pub fn mod_power_2(value: u32, max: u32) u32 {
    u.assert(u.next_power_of_two(max) == max);
    return value & (max - 1);
}

const initial_capacity = 8;

fn Custom_map(Key: type, Value: type, fns: type) type {
    const eql_function = fns.eql;
    const hash_function = fns.hash;
    return struct {
        const This = @This();
        content: Content,
        count: usize,
        
        pub const KV = struct {
            key: Key,
            value: Value,
        };
        
        pub const KV_ptr = struct {
            key: Key,
            value: *Value,
        };
        
        pub const Gop_result = struct {
            value: *Value,
            new: bool
        };
        
        pub const Iterator = struct {
            iterator_ptr: Iterator_ptr,
            
            pub fn next(it: *Iterator) ?KV {
                if (it.iterator_ptr.next()) |kv_ptr| {
                    return .{
                        .key = kv_ptr.key,
                        .value = kv_ptr.value.*,
                    };
                } else {
                    return null;
                }
            }
        };
        
        pub const Iterator_ptr = struct {
            content: *Content,
            current_item: ?*Content.Item,
            next_index: usize,
            
            pub fn init(it: *Iterator_ptr) void {
                it.current_item = null;
                it.next_index = 0;
                while (it.current_item == null and it.next_index < it.content.size()) {
                    it.try_next_index();
                }
            }
            
            pub fn next(it: *Iterator_ptr) ?KV_ptr {
                const ret = if (it.current_item) |item| KV_ptr {
                    .key = item.key,
                    .value = &item.value,
                } else return null;
                it.current_item = it.current_item.?.next;
                while (it.current_item == null and it.next_index < it.content.size()) {
                    it.try_next_index();
                }
                return ret;
            }
            
            pub fn try_next_index(it: *Iterator_ptr) void {
                const index = it.next_index;
                it.next_index += 1;
                const item_ptr = &it.content.items[index];
                if (item_ptr.*) |*item| {
                    it.current_item = item;
                } else {
                    it.current_item = null;
                }
            }
        };
        
        const Content = struct {
            items: []?Item,
            
            const Item = struct {
                key: Key,
                next: ?*Item,
                value: Value,
                
                pub fn key_is(item: *Item, test_key: Key) bool {
                    return eql_function(item.key, test_key);
                }
            };
            
            pub fn init(content: *Content, capacity: usize) void {
                u.assert(u.next_power_of_two(@intCast(capacity)) == capacity);
                content.items = u.alloc_slice(?Item, capacity);
                for (content.items) |*item| {
                    item.* = null;
                }
            }
            
            pub fn deinit(content: *Content) void {
                content.clear();
                u.free_slice(content.items);
            }
            
            pub fn size(content: *Content) usize {
                return content.items.len;
            }
            
            fn index_of_key(content: *Content, key: Key) usize {
                const hashed = hash_function(key);
                return mod_power_2(hashed, @intCast(content.items.len));
            }
            
            pub fn get_ptr(content: *Content, key: Key) ?*Value {
                const index = content.index_of_key(key);
                const first_item = &content.items[index];
                var current_item = if (first_item.*) |*item| item else null;
                while (current_item) |item| {
                    if (item.key_is(key)) {
                        return &item.value;
                    }
                    current_item = item.next;
                }
                return null;
            }
            
            pub fn get_or_put(content: *Content, key: Key) Gop_result {
                const index = content.index_of_key(key);
                const first_item = &content.items[index];
                var current_item = if (first_item.*) |*item| item else {
                    first_item.* = .{
                        .key = key,
                        .value = undefined,
                        .next = null,
                    };
                    return .{
                        .value = &first_item.*.?.value,
                        .new = true,
                    };
                };
                while (true) {
                    if (current_item.key_is(key)) {
                        return .{
                            .value = &current_item.value,
                            .new = false,
                        };
                    }
                    if (current_item.next) |next| {
                        current_item.next = next;
                    } else {
                        const new = u.alloc_single(Item);
                        current_item.next = new;
                        new.* = .{
                            .key = key,
                            .value = undefined,
                            .next = null,
                        };
                        return .{
                            .value = &new.value,
                            .new = true,
                        };
                    }
                }
            }
            
            pub fn iterator_ptr(content: *Content) Iterator_ptr {
                var ret_iterator: Iterator_ptr = undefined;
                ret_iterator.content = content;
                ret_iterator.init();
                return ret_iterator;
            }
            
            pub fn clear(content: *Content) void {
                for (content.items) |*item_o| {
                    const first = item_o.* orelse continue;
                    var current_item = first.next;
                    item_o.* = null;
                    while (current_item) |item| {
                        const next = item.next;
                        u.free_single(item);
                        current_item = next;
                    }
                }
            }
            
            pub fn remove(content: *Content, key: Key) error{does_not_exist}!void {
                const index = content.index_of_key(key);
                const first_item = &content.items[index];
                var current_item = if (first_item.*) |*item| item else {
                    return error.does_not_exist;
                };
                if (current_item.key_is(key)) {
                    first_item.* = null;
                    return;
                }
                while (true) {
                    const next = current_item.next orelse return error.does_not_exist;
                    if (next.key_is(key)) {
                        current_item.next = next.next;
                        u.free_single(next);
                        return;
                    }
                    current_item = next;
                }
            }
        };
        
        pub fn init(map: *This) void {
            map.init_with_capacity(initial_capacity);
        }
        
        pub fn init_with_capacity(map: *This, capacity: usize) void {
            map.content.init(capacity);
            map.count = 0;
        }
        
        pub fn create() This {
            const map: This = undefined;
            map.init();
            return map;
        }
        
        pub fn create_with_capacity(capacity: usize) This {
            const map: This = undefined;
            map.init_with_capacity(capacity);
            return map;
        }
        
        pub fn deinit(map: *This) void {
            map.content.deinit();
        }
        
        pub fn grow(map: *This) void {
            var new_content: Content = undefined;
            new_content.init(map.content.size() * 2);
            var old_iterator = map.content.iterator_ptr();
            while (old_iterator.next()) |kv| {
                const gop_result = new_content.get_or_put(kv.key);
                u.assert(gop_result.new);
                gop_result.value.* = kv.value.*;
            }
            map.content.deinit();
            map.content = new_content;
        }
        
        pub fn check_for_grow(map: *This) void {
            if (map.count >= map.content.size() * 4 / 3) {
                map.grow();
            }
        }
        
        pub fn get_ptr(map: *This, key: Key) ?*Value {
            return map.content.get_ptr(key);
        }
        
        pub fn get(map: *This, key: Key) ?Value {
            if (map.get_ptr(key)) |ptr| {
                return ptr.*;
            } else {
                return null;
            }
        }
        
        pub fn contains(map: *This, key: Key) bool {
            return map.get_ptr(key) != null;
        }
        
        pub fn get_or_put(map: *This, key: Key) Gop_result {
            map.check_for_grow();
            const result = map.content.get_or_put(key);
            if (result.new) {
                map.count += 1;
            }
            return result;
        }
        
        pub fn put_new(map: *This, key: Key, value: Value) void {
            const gop_result = map.get_or_put(key);
            u.assert(gop_result.new);
            gop_result.value.* = value;
        }
        
        pub fn put_or_replace(map: *This, key: Key, value: Value) void {
            const gop_result = map.get_or_put(key);
            gop_result.value.* = value;
        }
        
        pub fn remove(map: *This, key: Key) error{does_not_exist}!void {
            const result = map.content.remove(key);
            if (result) {
                map.count -= 1;
            } else |_| {}
            return result;
        }
        
        pub fn clear(map: *This) void {
            map.content.clear();
            map.count = 0;
        }
        
        pub fn iterator(map: *This) Iterator {
            return .{
                .iterator_ptr = map.iterator_ptr(),
            };
        }
        
        pub fn iterator_ptr(map: *This) Iterator_ptr {
            return map.content.iterator_ptr();
        }
    };
}

pub fn Map(Key: type, Value: type) type {
    return Custom_map(Key, Value, struct {
        pub fn eql(a: Key, b: Key) bool {
            return std.meta.eql(a, b);
        }
        pub fn hash(k: Key) u32 {
            return general_hash(std.mem.asBytes(&k));
        }
    });
}

pub fn String_map(Value: type) type {
    return Custom_map([]const u8, Value, struct {
        pub fn eql(a: []const u8, b: []const u8) bool {
            return u.bytes_equal(a, b);
        }
        pub fn hash(k: []const u8) u32 {
            return general_hash(k);
        }
    });
}

pub fn Custom_set(Value: type, fns: type) type {
    const Hashmap = Custom_map(Value, void, fns);
    return struct {
        const This = @This();
        map: Hashmap,
        
        pub fn init(set: *This) void {
            set.map.init();
        }
        
        pub fn init_with_capacity(set: *This, capacity: usize) void {
            set.map.init_with_capacity(capacity);
        }
        
        pub fn create() This {
            const set: This = undefined;
            set.init();
            return set;
        }
        
        pub fn create_with_capacity(capacity: usize) This {
            const set: This = undefined;
            set.init_with_capacity(capacity);
            return set;
        }
        
        pub fn deinit(set: *This) void {
            set.map.deinit();
        }
        
        pub fn add(set: *This, value: Value) void {
            set.map.put_or_replace(value);
        }
        
        pub fn add_new(set: *This, value: Value) void {
            set.map.put_new(value);
        }
        
        pub fn contains(set: *This, value: Value) bool {
            return set.map.contains(value);
        }
        
        pub fn remove(set: *This, value: Value) error{does_not_exist}!void {
            return set.map.remove(value);
        }
        
        pub fn clear(set: *This) void {
            set.map.clear();
        }
        
        pub const Iterator = struct {
            map_iterator: Hashmap.Iterator,
            
            pub fn next(it: Iterator) ?Value {
                return it.map_iterator.value;
            }
        };
        
        pub fn iterator(set: *This) Iterator {
            return .{
                .map_iterator = set.map.iterator(),
            };
        }
    };
}

pub fn Set(Key: type) type {
    return Custom_set(Key, struct {
        pub fn eql(a: Key, b: Key) bool {
            return std.meta.eql(a, b);
        }
        pub fn hash(k: Key) u32 {
            return general_hash(std.asBytes(&k));
        }
    });
}

pub const String_set = Custom_set([]const u8, struct {
    pub fn eql(a: []const u8, b: []const u8) bool {
        return u.bytes_equal(a, b);
    }
    pub fn hash(k: []const u8) u32 {
        return general_hash(k);
    }
});


pub fn Custom_static_map(Key: type, Value: type, fns: type) type {
    const eql_function = fns.eql;
    const hash_function = fns.hash;
    return struct {
        const This = @This();
        items: []?KV,
        
        pub const KV = struct {
            key: Key,
            value: Value,
        };
        
        pub const KV_ptr = struct {
            key: Key,
            value: *Value,
        };
        
        pub fn init(map: *This, content: []KV) void {
            const size = u.next_power_of_two(content.len * 2);
            map.items = u.alloc_slice(?KV, size);
            for (map.items) |*item| {
                item.* = null;
            }
            for (content) |item| {
                var index = mod_power_2(hash_function(item.key), size);
                while (map.items[index] != null) {
                    index += 1;
                    if (index == size) {
                        index = 0;
                    }
                }
                map.items[index] = item;
            }
        }
        
        pub fn create(content: []KV) This {
            var map: This = undefined;
            map.init(content);
            return map;
        }
        
        pub fn deinit(map: *This) void {
            u.free_slice(map.items);
        }
        
        pub fn get_ptr(map: *This, key: Key) ?*Value {
            var index = mod_power_2(hash_function(key), map.items.size);
            while (true) {
                if (map.items[index]) |*kv| {
                    if (eql_function(kv.key, key)) {
                        return &kv.value;
                    }
                } else {
                    return null;
                }
                index += 1;
                if (index == map.items.size) {
                    index += 1;
                }
            }
        }
        
        pub fn get(map: *This, key: Key) ?Value {
            return if (map.get_ptr(key)) |ptr| ptr.* else null;
        }
        
        pub fn contains(map: *This, key: Key) bool {
            return map.get_ptr(key) != null;
        }
        
        pub const Iterator = struct {
            map: *This,
            index: u32,
            
            pub fn next(it: *Iterator) ?KV {
                while (true) {
                    if (it.index >= it.map.items.len) {
                        return null;
                    }
                    if (it.map.items[it.index]) |kv| {
                        it.index += 1;
                        return kv;
                    }
                    it.index += 1;
                }
            }
        };
        
        pub fn iterator(map: *This) Iterator {
            return .{
                .map = map,
                .index = 0,
            };
        }
        
        pub const Iterator_ptr = struct {
            map: *This,
            index: u32,
            
            pub fn next(it: *Iterator_ptr) ?KV_ptr {
                while (true) {
                    if (it.index >= it.map.items.len) {
                        return null;
                    }
                    if (it.map.items[it.index]) |*kv| {
                        it.index += 1;
                        return .{
                            .key = kv.key,
                            .value = &kv.value,
                        };
                    }
                    it.index += 1;
                }
            }
        };
        
        pub fn iterator_ptr(map: *This) Iterator_ptr {
            return .{
                .map = map,
                .index = 0,
            };
        }
    };
}

pub fn Static_map(Key: type, Value: type) type {
    return Custom_static_map(Key, Value, struct {
        pub fn eql(a: Key, b: Key) bool {
            return std.meta.eql(a, b);
        }
        pub fn hash(k: Key) u32 {
            return general_hash(std.asBytes(&k));
        }
    });
}

pub fn Static_string_map(Value: type) type {
    return Custom_static_map([]const u8, Value, struct {
        pub fn eql(a: []const u8, b: []const u8) bool {
            return u.bytes_equal(a, b);
        }
        pub fn hash(k: []const u8) u32 {
            return general_hash(k);
        }
    });
}

pub fn Custom_static_set(Value: type, fns: type) type {
    const Hashmap = Custom_static_map(Value, void, fns);
    return struct {
        const This = @This();
        map: Hashmap,
        
        pub fn init(set: *This, content: []Value) void {
            const map_content = u.alloc_slice(Hashmap.KV, content.len);
            defer u.free_slice(map_content);
            for (map_content, content) |*map_item, value| {
                map_item.* = .{
                    .key = value,
                    .value = {},
                };
            }
            set.map.init(map_content);
        }
        
        pub fn create(content: []Value) This {
            var map: This = undefined;
            map.init(content);
            return map;
        }
        
        pub fn deinit(set: *This) void {
            set.map.deinit();
        }
        
        pub fn contains(set: *This, value: Value) bool {
            return set.map.contains(value);
        }
        
        pub const Iterator = struct {
            map_iterator: Hashmap.Iterator,
            
            pub fn next(it: Iterator) ?Value {
                return it.map_iterator.key;
            }
        };
        
        pub fn iterator(set: *This) Iterator {
            return .{
                .map_iterator = set.map.iterator(),
            };
        }
    };
}

pub fn Static_set(Key: type) type {
    return Custom_static_set(Key, struct {
        pub fn eql(a: Key, b: Key) bool {
            return std.meta.eql(a, b);
        }
        pub fn hash(k: Key) u32 {
            return general_hash(std.asBytes(&k));
        }
    });
}

pub const Static_string_set = Custom_static_set([]const u8, struct {
    pub fn eql(a: []const u8, b: []const u8) bool {
        return u.bytes_equal(a, b);
    }
    pub fn hash(k: []const u8) u32 {
        return general_hash(k);
    }
});

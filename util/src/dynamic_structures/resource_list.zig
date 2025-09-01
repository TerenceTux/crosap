const std = @import("std");
const u = @import("../util.zig");
const List = @import("list.zig").List;


const Index = u32;

pub fn Resource_list(Type: type) type {
    const Item = union(enum) {
        free,
        used: Type,
    };
    return struct {
        const Self = @This();
        items: List(Item),
        free_items: List(Index),
        
        pub fn init(rl: *Self) void {
            rl.items.init();
            rl.free_items.init();
        }
        
        pub fn deinit(rl: *Self) void {
            rl.items.deinit();
            rl.free_items.deinit();
        }
        
        pub fn get_mut(rl: *Self, index: Index) *Type {
            const item_o = rl.items.get_mut(index);
            switch (item_o.*) {
                .free => unreachable,
                .used => |*item| return item,
            }
        }
        
        pub fn get_ptr(rl: *Self, index: Index) *const Type {
            return rl.get_mut(index);
        }
        
        pub fn get(rl: *Self, index: Index) Type {
            return rl.get_ptr(index).*;
        }
        
        pub fn set(rl: *Self, index: Index, value: Type) void {
            rl.get_mut(index).* = value;
        }
        
        pub fn create(rl: *Self) Index {
            const item_to_add = Item {
                .used = undefined,
            };
            if (rl.free_items.pop()) |index| {
                rl.items.set(index, item_to_add);
                return index;
            } else {
                rl.items.append(item_to_add);
                return @intCast(rl.items.count - 1);
            }
        }
        
        pub fn destroy(rl: *Self, index: Index) void {
            switch (rl.items.get(index)) {
                .free => unreachable,
                .used => |_| {},
            }
            rl.free_items.append(index);
            rl.items.set(index, .free);
        }
        
        pub const Reader = struct {
            rl: *Self,
            next_index: Index,
            
            pub fn read(reader: *Reader) ?Type {
                while (true) {
                    if (reader.next_index >= reader.rl.items.count) {
                        return null;
                    }
                    const item = reader.rl.items.get(reader.next_index);
                    switch (item) {
                        .free => reader.next_index += 1,
                        .used => |val| return val,
                    }
                }
            }
        };
        
        pub fn iterator(rl: *Self) Reader {
            return .{
                .rl = rl,
                .next_index = 0,
            };
        }
    };
}

const std = @import("std");
const builtin = @import("builtin");
const u = @import("util.zig");

const allocator_to_use = if (u.debug) .debug else if (builtin.cpu.arch == .wasm32 or builtin.cpu.arch == .wasm64) .wasm else .fast;

const Alloc_debug = struct {
    debug_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init,
    
    pub fn init(alloc_i: *Alloc_debug) std.mem.Allocator {
        return alloc_i.debug_allocator.allocator();
    }
    
    pub fn deinit(alloc_i: *Alloc_debug) void {
        _ = alloc_i.debug_allocator.deinit();
    }
};

const Alloc_fast = struct {    
    pub fn init(alloc_i: *Alloc_fast) std.mem.Allocator {
        _ = alloc_i;
        return std.heap.smp_allocator;
    }
    
    pub fn deinit(alloc_i: *Alloc_fast) void {
        _ = alloc_i;
    }
};

const Alloc_wasm = struct {    
    pub fn init(alloc_i: *Alloc_wasm) std.mem.Allocator {
        _ = alloc_i;
        return std.heap.wasm_allocator;
    }
    
    pub fn deinit(alloc_i: *Alloc_wasm) void {
        _ = alloc_i;
    }
};

pub var alloc_interface = switch (allocator_to_use) {
    .debug => Alloc_debug{},
    .fast => Alloc_fast{},
    .wasm => Alloc_wasm{},
    else => unreachable,
};

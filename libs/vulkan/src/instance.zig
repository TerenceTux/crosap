const u = @import("util");
const std = @import("std");
const types = @import("types");
const Loader = @import("loader.zig").Loader;
const get_command = @import("loader.zig").get_command;
const create_extension_command_map = @import("loader.zig").create_extension_command_map;
const core_versions = @import("loader.zig").core_versions;
const Physical_device = @import("main.zig").Physical_device;


const Core_commands_map = create_extension_command_map(types.Core_version, types.Instance_commands);
const Extension_commands_map = create_extension_command_map(types.Instance_extension, types.Instance_commands);

pub const Instance = struct {
    instance: types.Instance,
    loader: *Loader,
    fns: types.Instance_commands,
    
    pub fn init(vk_instance: types.Instance, loader: *Loader, core_version: types.Core_version, extensions: []const types.Instance_extension) !Instance {
        var instance: Instance = undefined;
        instance.instance = vk_instance;
        instance.loader = loader;
        const get_instance_proc_addr = loader.get_instance_proc_addr;
        
        u.log_start(.{"Loading instance functions"});
        defer u.log_end(.{});
        
        for (core_versions) |current_version| {
            try instance.load_commands(get_instance_proc_addr, Core_commands_map.get(current_version));
            if (current_version == core_version) {
                break;
            }
        }
        for (extensions) |extension| {
            try instance.load_commands(get_instance_proc_addr, Extension_commands_map.get(extension));
        }
        
        return instance;
    }
    
    const Command_items = []const @import("loader.zig").Command_item;
    fn load_commands(instance: *Instance, get_instance_proc_addr: *const types.get_instance_proc_addr.function, commands: Command_items) !void {
        for (commands) |command| {
            const fn_ptr = get_instance_proc_addr(instance.instance, command.name);
            if (fn_ptr == null) {
                u.log(.{"Error getting function ",command.name});
                return error.function_not_found;
            }
            const fn_list: [*]*const anyopaque = @ptrCast(&instance.fns);
            fn_list[command.index] = @ptrCast(fn_ptr.?);
        }
    }
    
    pub fn call(instance: *Instance, function: @Type(.enum_literal), args: get_command(function).Call_arguments()) get_command(function).Call_return_type() {
        const command = get_command(function);
        const function_pointer = @field(instance.fns, @tagName(function));
        return command.call(function_pointer, args);
    }
    
    pub fn deinit(instance: *Instance) void {
        instance.call(.destroy_instance, .{instance.instance, null});
    }
    
    pub fn get_physical_devices(instance: *Instance) ![]Physical_device {
        var count: u32 = undefined;
        try instance.call(.enumerate_physical_devices, .{instance.instance, &count, null});
        
        const devices = u.alloc.alloc(types.Physical_device, count) catch @panic("No memory");
        defer u.alloc.free(devices);
        try instance.call(.enumerate_physical_devices, .{instance.instance, &count, devices.ptr});
        
        const list = u.alloc.alloc(Physical_device, count) catch @panic("No memory");
        for (devices, list) |device, *dest| {
            dest.* = .{
                .instance = instance,
                .physical_device = device,
            };
        }
        return list;
    }
};

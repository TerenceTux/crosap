const u = @import("util");
const std = @import("std");
const types = @import("types");
const Loader = @import("loader.zig").Loader;
const Physical_device = @import("main.zig").Physical_device;

pub const Instance = struct {
    instance: types.Instance,
    loader: *Loader,
    fns: types.Instance_commands,
    
    pub fn init(vk_instance: types.Instance, loader: *Loader) Instance {
        var instance: Instance = undefined;
        instance.instance = vk_instance;
        instance.loader = loader;
        const vkGetInstanceProcAddr = loader.vkGetInstanceProcAddr;
        
        u.log("Loading instance functions");
        inline for (@typeInfo(@TypeOf(instance.fns)).@"struct".fields) |field| {
            const fn_ptr = vkGetInstanceProcAddr(instance.instance, field.name);
            if (fn_ptr == null) {
                @panic("Error getting function "++field.name);
            }
            
            @field(instance.fns, field.name) = @ptrCast(fn_ptr);
        }
        
        return instance;
    }
    
    pub fn deinit(instance: *Instance) void {
        instance.fns.vkDestroyInstance(instance.instance, null);
    }
    
    pub fn get_physical_devices(instance: *Instance) []Physical_device {
        var count: u32 = undefined;
        types.handle_error(instance.fns.vkEnumeratePhysicalDevices(instance.instance, &count, null));
        
        const devices = u.alloc.alloc(types.VkPhysicalDevice, count) catch @panic("No memory");
        defer u.alloc.free(devices);
        types.handle_error(instance.fns.vkEnumeratePhysicalDevices(instance.instance, &count, devices.ptr));
        
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

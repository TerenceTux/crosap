const u = @import("util");
const std = @import("std");
const types = @import("types.zig");
const Portaudio = @import("main.zig").Portaudio;
const Device = @import("device.zig").Device;

pub const Host_api = struct {
    pa: *Portaudio,
    index: types.Host_api_index,
    type: types.Host_api_type_id,
    name: []const u8,
    device_count: c_int,
    default_input_device: types.Device_index,
    default_output_device: types.Device_index,
    
    pub fn get_devices(host_api: *const Host_api) []Device {
        const count: usize = @intCast(host_api.device_count);
        const devices = u.alloc_slice(Device, count);
        for (devices, 0..) |*device, index| {
            const device_index = host_api.pa.fns.Pa_HostApiDeviceIndexToDeviceIndex(host_api.index, @intCast(index));
            device.* = host_api.pa.get_device_by_index(device_index);
        }
        return devices;
    }
    
    pub fn get_default_output_device(host_api: *Host_api) Device {
        return host_api.pa.get_device_by_index(host_api.default_output_device);
    }
    
    pub fn get_default_input_device(host_api: *Host_api) Device {
        return host_api.pa.get_device_by_index(host_api.default_input_device);
    }
};

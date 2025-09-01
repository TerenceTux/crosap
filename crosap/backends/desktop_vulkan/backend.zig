const u = @import("util");
const std = @import("std");
const lib_vulkan = @import("lib_vulkan");
const lib_glfw = @import("lib_glfw");

const vertex_shader_code = @embedFile("shaders/vertex.spv");
const fragment_shader_code = @embedFile("shaders/fragment.spv");

fn parse_spv_code(size: usize, bytes: *const [size*4]u8) [size]u32 {
    var array: [size]u32 = undefined;
    for (&array, 0..) |*dest, i| {
        dest.* = std.mem.readInt(u32, bytes[i*4..(i+1)*4], .little);
    }
    return array;
}
const vertex_shader_spv = parse_spv_code(vertex_shader_code.len / 4, vertex_shader_code);
const fragment_shader_spv = parse_spv_code(fragment_shader_code.len / 4, fragment_shader_code);

const index_data = [_]u16 {0, 1, 2, 1, 3, 2};


// 25 bytes
const Draw_object = extern struct {
    position_x: i16,
    position_y: i16,
    size_x: i16,
    size_y: i16,
    color_r: u8,
    color_g: u8,
    color_b: u8,
    color_a: u8,
    tex_pos_x: i16,
    tex_pos_y: i16,
    tex_size_x: i16,
    tex_size_y: i16,
    tex_offset_x: i16,
    tex_offset_y: i16,
    tex_id: u8,
};
const draw_buffer_size = 1 << 16; // 65536, buffer size is around 2 MB
const staging_buffer_size = @max(draw_buffer_size * @sizeOf(Draw_object), 2048 * 2048 * 4); // around 16 MB
const textures_per_rendering = 8;

const max_swapchain_size = 32;

pub const Event = union(enum) {
    key_pressed: c_int,
    key_released: c_int,
    mouse_moved: u.Vec2r,
    mouse_enter: bool,
    mouse_button_pressed: u8,
    mouse_button_released: u8,
    scroll: u.Vec2r,
};

pub const Backend = struct {
    events: u.Queue(Event),
    
    glfw: lib_glfw.Loader,
    loader: lib_vulkan.Loader,
    instance: lib_vulkan.Instance,
    physical_device: lib_vulkan.Physical_device,
    window: lib_glfw.Window,
    surface: lib_vulkan.Surface,
    
    device: lib_vulkan.Device,
    wait_fence: lib_vulkan.Fence,
    task_allocator: lib_vulkan.Task_allocator,
    temp_task: lib_vulkan.Task,
    index_buffer: lib_vulkan.Buffer,
    staging_buffer: lib_vulkan.Buffer,
    descriptor_set_layout: lib_vulkan.types.VkDescriptorSetLayout,
    descriptor_pool: lib_vulkan.Descriptor_pool,
    dummy_image: Texture_image,
    
    rendering_active: bool,
    swapchain_min_image_count: u32,
    swapchain_image_format: lib_vulkan.types.VkFormat,
    swapchain_image_colorspace: lib_vulkan.types.VkColorSpaceKHR,
    render_size: lib_vulkan.types.VkExtent2D,
    swapchain_tranform: lib_vulkan.types.VkSurfaceTransformFlagBitsKHR,
    swapchain_alpha_composite: lib_vulkan.types.VkCompositeAlphaFlagBitsKHR,
    selected_present_mode: lib_vulkan.types.VkPresentModeKHR,
    swapchain: lib_vulkan.Swapchain,
    swapimages: []Swapimage,
    pipeline: lib_vulkan.Graphics_pipeline,
    pipeline_keep: lib_vulkan.Graphics_pipeline,
    
    key_callback: Key_callback,
    mouse_button_callback: Mouse_button_callback,
    cursor_move_callback: Cursor_move_callback,
    cursor_enter_callback: Cursor_enter_callback,
    scroll_callback: Scroll_callback,
    
//     pub const Key_callback = u.callback(fn(key: c_int, action: types.Key_action, mods: c_int) void);
//     pub const Mouse_button_callback = u.callback(fn(button: c_int, action: types.Key_action, mods: c_int) void);
//     pub const Cursor_move_callback = u.callback(fn(x_pos: f64, y_pos: f64) void);
//     pub const Cursor_enter_callback = u.callback(fn(entered: bool) void);
    //     pub const Scroll_callback = u.callback(fn(x_offset: f64, y_offset: f64) void);
    
    const Key_callback = struct {
        b: *Backend,
        
        pub fn call(context: *Key_callback, key: c_int, action: lib_glfw.types.Key_action, mods: c_int) void {
            u.log(.{"GLFW key callback, key: ",key,", action: ",action,", mods: ",mods});
            if (action == .press) {
                context.b.events.add_end(.{
                    .key_pressed = key,
                });
            } else if (action == .release) {
                context.b.events.add_end(.{
                    .key_released = key,
                });
            }
        }
    };
    
    const Mouse_button_callback = struct {
        b: *Backend,
        
        pub fn call(context: *Mouse_button_callback, button: c_int, action: lib_glfw.types.Key_action, mods: c_int) void {
            u.log(.{"GLFW button callback, button: ",button,", action: ",action,", mods: ",mods});
            if (action == .press) {
                context.b.events.add_end(.{
                    .mouse_button_pressed = @intCast(button),
                });
            } else if (action == .release) {
                context.b.events.add_end(.{
                    .mouse_button_released = @intCast(button),
                });
            }
        }
    };
    
    const Cursor_move_callback = struct {
        b: *Backend,
        
        pub fn call(context: *Cursor_move_callback, x_pos: f64, y_pos: f64) void {
            u.log(.{"GLFW cursor move callback, x_pos: ",x_pos,", y_pos: ",y_pos});
            context.b.events.add_end(.{
                .mouse_moved = .create(.from_float(x_pos), .from_float(y_pos)),
            });
        }
    };
    
    const Cursor_enter_callback = struct {
        b: *Backend,
        
        pub fn call(context: *Cursor_enter_callback, entered: bool) void {
            if (entered) {
                u.log(.{"GLFW cursor entered window callback"});
            } else {
                u.log(.{"GLFW cursor leaved window callback"});
            }
            context.b.events.add_end(.{
                .mouse_enter = entered,
            });
        }
    };
    
    const Scroll_callback = struct {
        b: *Backend,
        
        pub fn call(context: *Scroll_callback, x_offset: f64, y_offset: f64) void {
            u.log(.{"GLFW scroll callback, x_offset: ",x_offset,", y_offset: ",y_offset});
            context.b.events.add_end(.{
                .scroll = .create(.from_float(x_offset), .from_float(y_offset)),
            });
        }
    };
    
    pub fn init(b: *Backend) void {
        b.events.init();
        b.key_callback = .{.b = b};
        b.mouse_button_callback = .{.b = b};
        b.cursor_move_callback = .{.b = b};
        b.cursor_enter_callback = .{.b = b};
        b.scroll_callback = .{.b = b};
        
        b.init_glfw();
        b.loader.init_from_get_proc(@ptrCast(b.glfw.vulkan_get_instance_proc()), @ptrCast(b.glfw.vulkan_get_device_proc()));
        b.init_instance();
        b.init_physical_device();
        b.init_window();
        b.init_device();
        b.wait_fence = b.device.create_fence(false);
        b.task_allocator = b.device.create_task_allocator(true, true);
        b.temp_task = b.task_allocator.create_task();
        b.staging_buffer = b.device.create_buffer(staging_buffer_size, .just(.transfer_src), .staging);
        b.index_buffer = b.device.create_buffer(@sizeOf(@TypeOf(index_data)), .create(&.{.index_buffer, .transfer_dst}), .infrequent_write);
        b.write_whole_buffer(&b.index_buffer, std.mem.sliceAsBytes(&index_data));
        u.assert(b.staging_buffer.mapped != null);
        b.init_descriptor_info();
        b.dummy_image = b.create_texture_image(1, 1);
        b.rendering_active = false;
        b.render_state_check();
    }
    
    pub fn render_state_check(b: *Backend) void {
        const surface_size = b.window.get_framebuffer_size();
        const surface_width = surface_size[0];
        const surface_height = surface_size[1];
        if (surface_width == 0 or surface_height == 0) {
            if (b.rendering_active) {
                u.log("Surface is now empty");
                b.rendering_disable();
            }
        } else {
            if (!b.rendering_active) {
                u.log("Surface now has a size");
                b.rendering_enable(.create(.create(surface_width), .create(surface_height)));
            } else if (b.render_size.width != surface_width or b.render_size.height != surface_height) {
                u.log("Surface size changed");
                b.rendering_disable();
                b.rendering_enable(.create(.create(surface_width), .create(surface_height)));
            }
            u.assert(b.render_size.width == surface_width);
            u.assert(b.render_size.height == surface_height);
        }
    }
    
    pub fn rendering_enable(b: *Backend, size: u.Vec2i) void {
        u.log_start(.{"Enabling rendering with size ", size});
        u.assert(!b.rendering_active);
        b.render_size = .{
            .width = size.x.to(u32),
            .height = size.y.to(u32),
        };
        b.init_swapchain();
        b.init_pipeline();
        b.init_swapchain_images();
        b.rendering_active = true;
        u.log_end({});
    }
    
    pub fn rendering_disable(b: *Backend) void {
        u.log_start("Disabling rendering");
        u.assert(b.rendering_active);
        u.log("Wait for all drawing commands");
        b.device.wait_everything_finished();
        u.log("Pipeline");
        b.descriptor_pool.reset();
        b.pipeline.deinit();
        b.pipeline_keep.deinit();
        u.log("Swapchain");
        for (b.swapimages) |*swapimage| {
            swapimage.deinit();
        }
        u.alloc.free(b.swapimages);
        b.swapchain.deinit();
        b.rendering_active = false;
        u.log_end({});
    }
    
    fn init_glfw(b: *Backend) void {
        b.glfw.init();
        const version_string = b.glfw.get_version_string();
        u.log(.{"Initialised glfw version ",version_string});
        if (!b.glfw.vulkan_supported()) {
            @panic("Glfw reports vulkan not supported");
        }
        
    }
    
    fn init_instance(b: *Backend) void {
        const required_extensions = b.glfw.required_vulkan_extensions();
        defer {
            for (required_extensions) |extension| {
                u.alloc.free(extension);
            }
            u.alloc.free(required_extensions);
        }
        u.log_start("Required vulkan extensions by glfw:");
        for (required_extensions) |extension| {
            u.log(extension);
        }
        u.log_end({});
        
        const validation_layer_name = "VK_LAYER_KHRONOS_validation";
        var validation_layer_available = false;
        var validation_layer_settings_available = false;
        if (u.debug) {
            const version = b.loader.instance_version();
            u.log(.{"Vulkan version: ",version});
            
            u.log_start("Instance extensions:");
            var extensions = b.loader.get_extensions(null);
            for (extensions.items) |extension| {
                u.log(.{extension.name," (version ",extension.version,")"});
            }
            extensions.deinit();
            u.log_end({});
            
            u.log_start("Available layers:");
            var layers = b.loader.get_layers();
            for (layers.items) |layer| {
                var this_is_the_validation_layer = false;
                if (std.mem.eql(u8, layer.name, validation_layer_name)) {
                    this_is_the_validation_layer = true;
                    validation_layer_available = true;
                }
                u.log(.{layer.name," (version ",layer.layer_version,"): ",layer.description," - for vulkan ",layer.vulkan_version});
                
                u.log_start("This layer provides the following extensions:");
                var layer_extensions = b.loader.get_extensions(layer.name);
                for (layer_extensions.items) |extension| {
                    u.log(.{extension.name," (version ",extension.version,")"});
                    if (this_is_the_validation_layer and std.mem.eql(u8, extension.name, "VK_EXT_layer_settings")) {
                        validation_layer_settings_available = true;
                    }
                }
                layer_extensions.deinit();
                u.log_end({});
            }
            layers.deinit();
            u.log_end({});
        }
        
        if (validation_layer_available) {
            if (validation_layer_settings_available) {
                u.log("Enabling validation layer with custom settings");
            } else {
                u.log("Enabling validation layer without custom settings");
            }
        } else {
            u.log("Vulkan validation layer is not available");
        }
        
        var validation_extensions: [][]const u8 = undefined;
        if (validation_layer_settings_available) {
            validation_extensions = u.alloc.alloc([]const u8, required_extensions.len + 1) catch @panic("no memory");
            @memcpy(validation_extensions[0..required_extensions.len], required_extensions);
            validation_extensions[required_extensions.len] = "VK_EXT_layer_settings";
        }
        defer if (validation_layer_settings_available) {
            u.alloc.free(validation_extensions);
        };
        
        var validation_layer_settings = [_]lib_vulkan.Loader.Layer_setting {
            .{
                .layer = validation_layer_name,
                .setting = "validate_sync",
                .value = .{
                    .boolean = true,
                },
            },
//             .{
//                 .layer = validation_layer_name,
//                 .setting = "gpuav_enable",
//                 .value = .{
//                     .boolean = true,
//                 },
//             },
            .{
                .layer = validation_layer_name,
                .setting = "validate_best_practices",
                .value = .{
                    .boolean = true,
                },
            },
            .{
                .layer = validation_layer_name,
                .setting = "validate_best_practices_arm",
                .value = .{
                    .boolean = true,
                },
            },
            .{
                .layer = validation_layer_name,
                .setting = "validate_best_practices_amd",
                .value = .{
                    .boolean = true,
                },
            },
            .{
                .layer = validation_layer_name,
                .setting = "validate_best_practices_nvidia",
                .value = .{
                    .boolean = true,
                },
            },
            .{
                .layer = validation_layer_name,
                .setting = "report_flags",
                .value = .{
                    .string = "warn",
                },
            },
            .{
                .layer = validation_layer_name,
                .setting = "enable_message_limit",
                .value = .{
                    .boolean = false,
                },
            },
        };
        const layer_settings = if (validation_layer_settings_available) &validation_layer_settings else &.{};
        const using_layers: []const []const u8 = if (validation_layer_available) &.{validation_layer_name} else &.{};
        const using_extensions = if (validation_layer_settings_available) validation_extensions else required_extensions;
        b.instance = b.loader.create_instance(null, .{
            .name = "crosap",
            .version = 0,
        }, using_layers, using_extensions, layer_settings) catch @panic("Can't create instance");
    }
    
    fn init_physical_device(b: *Backend) void {
        u.log_start("Physical devices:");
        const physical_devices = b.instance.get_physical_devices();
        defer u.alloc.free(physical_devices);
        for (physical_devices) |*physical_device| {
            var properties = physical_device.get_properties();
            u.log_start(properties.name);
            
            u.log(.{"Vulkan version ",properties.vulkan_version});
            switch (properties.device_type) {
                .integrated_gpu => u.log("This is an integrated gpu"),
                .discrete_gpu => u.log("This is a discrete gpu"),
                .virtual_gpu => u.log("This is a virtual gpu"),
                .cpu => u.log("This is cpu emulated"),
                .other => u.log("GPU type unknown"),
            }
            u.log(.{"Vendor id: ",properties.vendor_id});
            u.log(.{"Device id: ",properties.device_id});
            u.log(.{"Driver version: ",properties.driver_version});
            
            u.log_start("Device extensions:");
            var extensions = physical_device.get_extensions(null);
            for (extensions.items) |extension| {
                u.log(.{extension.name," (version ",extension.version,")"});
            }
            extensions.deinit();
            u.log_end({});
            
            u.log_start("Queue types:");
            const queue_types = physical_device.get_queue_types();
            for (queue_types) |queue_type| {
                u.log_start(.{"Index ",queue_type.index});
                u.log(.{"Count: ",queue_type.count});
                if (queue_type.support_graphics) u.log("This queue supports graphics commands");
                if (queue_type.support_compute) u.log("This queue supports compute commands");
                if (queue_type.support_transfer) u.log("This queue supports transfer commands");
                u.log_end({});
            }
            u.alloc.free(queue_types);
            u.log_end({});
            
            const memory_info = physical_device.get_memory_info();
            u.log_start("Memory heaps:");
            for (memory_info.memoryHeaps[0..memory_info.memoryHeapCount], 0..) |heap, i| {
                u.log(.{i,": ",heap.size," bytes (located on ",if (heap.flags.has(.device_local)) "device" else "host",")"});
            }
            u.log_end({});
            u.log_start("Memory types:");
            for (memory_info.memoryTypes[0..memory_info.memoryTypeCount], 0..) |memtype, i| {
                u.log_start(.{i,": on heap ",memtype.heapIndex});
                const flags = memtype.propertyFlags;
                if (flags.has(.device_local)) {
                    u.log("This memory is fast for the GPU");
                } else {
                    u.log("This memory is on the host, so not fast for the GPU");
                }
                if (flags.has(.host_visible)) {
                    u.log("This memory is accessable/mappable by the host");
                }
                if (flags.has(.host_coherent)) {
                    u.log("This memory is directly connected, so flushing/invalidating is not needed");
                }
                if (flags.has(.host_cached)) {
                    u.log("This is cached by the host, so fast to read");
                }
                if (flags.has(.lazily_allocated)) {
                    u.log("This memory could be lazily allocated and can't be accesed by the host");
                }
                u.log_end({});
            }
            u.log_end({});
            
            u.log_end({});
            properties.deinit();
        }
        u.log_end({});
        
        const best_physical_device = b.pick_physical_device(physical_devices, &.{}) orelse @panic("No suitable physical devices");
        b.physical_device = best_physical_device.*;
    }
    
    fn pick_physical_device(b: *Backend, physical_devices: []lib_vulkan.Physical_device, preferred: []const u16) ?*lib_vulkan.Physical_device {
        const type_order = [_]lib_vulkan.types.VkPhysicalDeviceType{
            .integrated_gpu,
            .discrete_gpu,
            .virtual_gpu,
            .other,
            .cpu,
        };
        
        for (preferred) |index| {
            if (index >= physical_devices.len) continue;
            
            const physical_device = &physical_devices[index];
            if (b.physical_device_is_usable(physical_device)) {
                return physical_device;
            }
        }
        
        for (type_order) |gpu_type| {
            for (physical_devices) |*physical_device| {
                var properties = physical_device.get_properties();
                defer properties.deinit();
                if (properties.device_type != gpu_type) continue;
                
                if (b.physical_device_is_usable(physical_device)) {
                    return physical_device;
                }
            }
        }
        
        return null;
    }
    
    fn physical_device_is_usable(b: *Backend, physical_device: *lib_vulkan.Physical_device) bool {
        const queue_type_index = physical_device.best_queue_type_index() orelse return false;
        if (!b.glfw.physical_device_can_present(b.instance.instance, physical_device.physical_device, queue_type_index)) {
            return false;
        }
        
        return true;
    }
    
    fn init_window(b: *Backend) void {
        u.log_start("Create glfw window");
        b.glfw.set_window_hint(.client_api, lib_glfw.types.window_hint_value.no_api);
        u.log("Window");
        b.glfw.create_window(&b.window, 800, 600, "window");
        b.window.key_callback = lib_glfw.Window.Key_callback.dynamic(&b.key_callback);
        b.window.mouse_button_callback = lib_glfw.Window.Mouse_button_callback.dynamic(&b.mouse_button_callback);
        b.window.cursor_move_callback = lib_glfw.Window.Cursor_move_callback.dynamic(&b.cursor_move_callback);
        b.window.cursor_enter_callback = lib_glfw.Window.Cursor_enter_callback.dynamic(&b.cursor_enter_callback);
        b.window.scroll_callback = lib_glfw.Window.Scroll_callback.dynamic(&b.scroll_callback);
        
        u.log("Surface");
        const vulkan_surface = b.window.create_vulkan_surface(b.instance.instance);
        b.surface = b.physical_device.import_surface(vulkan_surface);
        
        u.log_end({});
    }
    
    fn init_device(b: *Backend) void {
        u.log("Creating device");
        const extensions = [_][]const u8 {
            "VK_KHR_swapchain",
        };
        b.device = b.physical_device.create_device(&extensions);
    }
    
    fn init_descriptor_info(b: *Backend) void {
        const bindings = [_]lib_vulkan.types.VkDescriptorSetLayoutBinding {
            .{
                .binding = 0,
                .descriptorType = .sampled_image,
                .descriptorCount = 8,
                .stageFlags = .just(.fragment),
                .pImmutableSamplers = null,
            },
        };
        b.descriptor_set_layout = b.device.create_descriptor_set_layout(&bindings);
        const max_sizes = [_]lib_vulkan.types.VkDescriptorPoolSize {
            .{
                .type = .sampled_image,
                .descriptorCount = 8 * max_swapchain_size,
            },
        };
        b.descriptor_pool = b.device.create_descriptor_pool(max_swapchain_size, &max_sizes);
    }
    
    fn init_swapchain(b: *Backend) void {
        const surface_properties = b.surface.get_properties();
        
        if (surface_properties.max_swapchain_images) |max_swapchain_images| {
            u.log(.{"Swapchain image count must be between ",surface_properties.min_swapchain_images," and ",max_swapchain_images});
        } else {
            u.log(.{"Swapchain image count must be at least ",surface_properties.min_swapchain_images});
        }
        b.swapchain_min_image_count = 3;
        if (surface_properties.min_swapchain_images > b.swapchain_min_image_count) {
            b.swapchain_min_image_count = surface_properties.min_swapchain_images;
        }
        if (surface_properties.max_swapchain_images) |max_swapchain_images| {
            if (max_swapchain_images < b.swapchain_min_image_count) {
                b.swapchain_min_image_count = max_swapchain_images;
            }
        }
        u.log(.{"Choosing a swapchain image count of ",b.swapchain_min_image_count});
        
        u.log(.{"Surface size must be between ",surface_properties.min_size," and ",surface_properties.max_size});
        if (surface_properties.current_size) |current_size| {
            u.log(.{"Surface size is currently ",current_size});
        } else {
            u.log(.{"Surface size will be determined by system"});
        }
        u.log(.{"We want to use the size ",b.render_size});
        if (b.render_size.width < surface_properties.min_size.width) {
            @panic("Render width too small");
        }
        if (b.render_size.height < surface_properties.min_size.height) {
            @panic("Render height too small");
        }
        if (b.render_size.width > surface_properties.max_size.width) {
            @panic("Render width too big");
        }
        if (b.render_size.height > surface_properties.max_size.height) {
            @panic("Render height too big");
        }
        
        u.log(.{"Max array layers: ",surface_properties.max_array_layers});
        u.log(.{"Supported transforms: ",surface_properties.supported_transforms," (currently ",surface_properties.current_transform,")"});
        b.swapchain_tranform = surface_properties.supported_transforms.select_best(&.{
            .identity,
            .inherit,
            .rotate_180,
            .rotate_90,
            .rotate_270,
            .horizontal_mirror,
            .horizontal_mirror_rotate_180,
            .horizontal_mirror_rotate_90,
            .horizontal_mirror_rotate_270,
        });
        u.log(.{"Selecting transform: ",b.swapchain_tranform});
        u.log(.{"Supported alpha composite modes: ",surface_properties.supported_alpha_composite_mode});
        b.swapchain_alpha_composite = surface_properties.supported_alpha_composite_mode.select_best(&.{
            .fully_opaque,
            .inherit,
            .pre_multiplied,
            .post_multiplied,
        });
        u.log(.{"Selecting alpha composite mode: ",b.swapchain_alpha_composite});
        
        const supported_formats = b.surface.get_supported_formats();
        u.log_start("Supported formats:");
        for (supported_formats) |format| {
            u.log(.{"Format: ",format.format,", color space: ",format.color_space});
        }
        u.log_end({});
        
        var selected_format = supported_formats[0];
        const preferred_formats = [_]lib_vulkan.types.VkFormat {
            .b8g8r8a8_srgb,
            .r8g8b8a8_srgb,
            .b8g8r8a8_unorm,
            .r8g8b8a8_unorm,
            .r5g6b5_unorm_pack16,
        };
        
        for (preferred_formats) |good_format| {
            var found = false;
            for (supported_formats) |format| {
                if (format.format == good_format and format.color_space == .srgb_nonlinear) {
                    selected_format = format;
                    found = true;
                    break;
                }
            }
            if (found) {
                break;
            }
        }
        u.alloc.free(supported_formats);
        u.log(.{"Selected format ",selected_format.format," with color space ",selected_format.color_space});
        b.swapchain_image_format = selected_format.format;
        b.swapchain_image_colorspace = selected_format.color_space;
        
        const supported_present_modes = b.surface.get_supported_present_modes();
        u.log_start("Supported present modes:");
        for (supported_present_modes) |present_mode| {
            u.log(present_mode);
        }
        u.log_end({});
        
        const preferred_present_modes = [_]lib_vulkan.Surface.Present_mode {
            .fifo,
            .fifo_relaxed,
            .mailbox,
            .immediate,
        };
        b.selected_present_mode = select_best(lib_vulkan.Surface.Present_mode, supported_present_modes, &preferred_present_modes) orelse @panic("No present mode available");
        u.log(.{"Selected present mode ",b.selected_present_mode});
        u.alloc.free(supported_present_modes);
        
        b.swapchain = b.device.create_swapchain(b.surface.surface, b.swapchain_min_image_count, b.swapchain_image_format, b.swapchain_image_colorspace, b.render_size, 1,
                                                b.swapchain_tranform, b.swapchain_alpha_composite, b.selected_present_mode, null);
        
    }
    
    fn init_swapchain_images(b: *Backend) void {
        const swapchain_images = b.swapchain.get_images();
        if (swapchain_images.len > max_swapchain_size) {
            @panic("swapchain is too large");
        }
        b.swapimages = u.alloc.alloc(Swapimage, swapchain_images.len) catch @panic("no memory");
        for (swapchain_images, b.swapimages) |image, *swapimage| {
            swapimage.* = .init_from(image, b);
        }
        u.alloc.free(swapchain_images);
    }
    
    fn select_best(T: type, available: []const T, order: []const T) ?T {
        for (order) |good| {
            for (available) |item| {
                if (item == good) {
                    return item;
                }
            }
        }
        return null;
    }
    
    fn init_pipeline(b: *Backend) void {
        u.log_start("Create graphics pipeline");
        const width: u32 = b.render_size.width;
        const height: u32 = b.render_size.height;
        const vertex_specialization = [_]lib_vulkan.Graphics_pipeline.Specialization_info {
            .{
                .id = 0,
                .data = std.mem.asBytes(&width),
            },
            .{
                .id = 1,
                .data = std.mem.asBytes(&height),
            },
        };
        const vertex_bindings = [_]lib_vulkan.types.VkVertexInputBindingDescription {
            .{
                .binding = 0,
                .stride = @sizeOf(Draw_object),
                .inputRate = .instance,
            },
        };
        const vertex_attributes = [_]lib_vulkan.types.VkVertexInputAttributeDescription {
            .{
                .location = 0, // position
                .binding = 0,
                .format = .r16g16_sint,
                .offset = 0,
            },
            .{
                .location = 1, // size
                .binding = 0,
                .format = .r16g16_sint,
                .offset = 4,
            },
            .{
                .location = 2, // color
                .binding = 0,
                .format = .r8g8b8a8_unorm,
                .offset = 8,
            },
            .{
                .location = 3, // tex_pos
                .binding = 0,
                .format = .r16g16_sint,
                .offset = 12,
            },
            .{
                .location = 4, // tex_size
                .binding = 0,
                .format = .r16g16_sint,
                .offset = 16,
            },
            .{
                .location = 5, // tex_offset
                .binding = 0,
                .format = .r16g16_sint,
                .offset = 20,
            },
            .{
                .location = 6, // tex_id
                .binding = 0,
                .format = .r8_sint,
                .offset = 24,
            },
        };
        const descriptor_set_layouts = [_]lib_vulkan.types.VkDescriptorSetLayout {
            b.descriptor_set_layout,
        };
        const create_info = lib_vulkan.Graphics_pipeline.Create_info {
            .vertex_code = &vertex_shader_spv,
            .vertex_specialization = &vertex_specialization,
            .fragment_code = &fragment_shader_spv,
            .fragment_specialization = &.{},
            .vertex_bindings = &vertex_bindings,
            .vertex_attributes = &vertex_attributes,
            .descriptor_set_layouts = &descriptor_set_layouts,
            .blend_mode = .premultiplied,
            .width = b.render_size.width,
            .height = b.render_size.height,
            .image_format = b.swapchain_image_format,
            .keep_previous = false,
        };
        b.pipeline = b.device.create_graphics_pipeline(&create_info);
        var create_info_keep = create_info;
        create_info_keep.keep_previous = true;
        b.pipeline_keep = b.device.create_graphics_pipeline(&create_info_keep);
        u.log_end({});
    }
    
    pub fn deinit(b: *Backend) void {
        u.log_start("Deinit backend");
        if (b.rendering_active) {
            b.rendering_disable();
        }
        u.log("Tasks");
        b.temp_task.deinit();
        b.task_allocator.deinit();
        u.log("General objects");
        b.dummy_image.deinit();
        b.descriptor_pool.deinit();
        b.device.destroy_descriptor_set_layout(b.descriptor_set_layout);
        b.staging_buffer.deinit();
        b.index_buffer.deinit();
        b.device.destroy_fence(b.wait_fence);
        u.log("Device");
        b.device.deinit();
        u.log("Window");
        b.surface.deinit();
        b.window.deinit();
        u.log("Instance");
        b.instance.deinit();
        b.loader.deinit();
        u.log("Glfw");
        b.glfw.deinit();
        b.events.deinit();
        u.log_end({});
    }
    
    pub fn should_close(b: *Backend) bool {
        return b.window.should_close();
    }
    
    pub fn poll_events(b: *Backend) void {
        b.glfw.poll_events();
    }
    
    pub fn new_draw_frame(b: *Backend) ?Draw_frame {
        b.render_state_check();
        if (!b.rendering_active) {
            u.log("Rendering not active");
            return null;
        }
        u.log(.{"Aquiring swapchain image"});
        const index = b.swapchain.aquire_next_image(null, b.wait_fence) orelse {
            u.log("Swapchain broken, disabling rendering");
            b.rendering_disable();
            u.log("Not rendering this frame");
            return null;
        };
        u.log(.{"Aquired image index: ",index});
        u.log(.{"Wait until the image is useable"});
        b.device.wait_for_fence(b.wait_fence, null);
        u.log(.{"We can now use the image"});
        
        const swapimage = &b.swapimages[index];
        return .{
            .swapimage = swapimage,
            .index = index,
            .draw_objects = undefined,
            .draw_count = 0,
            .already_drawn = false,
            .using_images = [1]?*lib_vulkan.Image { null } ** textures_per_rendering,
        };
    }
    
    pub fn write_buffer(b: *Backend, buffer: *lib_vulkan.Buffer, offset: usize, data: []const u8) void {
        if (buffer.mapped) |write_ptr| {
            @memcpy(write_ptr[offset..offset+data.len], data);
            buffer.flush_region(offset, data.len);
        } else {
            b.write_buffer(&b.staging_buffer, 0, data);
            b.temp_task.start_recording(true);
            b.temp_task.copy_buffer(data.len, b.staging_buffer.buffer, 0, buffer.buffer, offset);
            b.temp_task.end_recording();
            b.temp_task.submit(&.{}, null, b.wait_fence);
            b.device.wait_for_fence(b.wait_fence, null);
            b.temp_task.reset();
        }
    }
    
    pub fn write_whole_buffer(b: *Backend, buffer: *lib_vulkan.Buffer, data: []const u8) void {
        u.assert(data.len == buffer.size);
        b.write_buffer(buffer, 0, data);
    }
    
    pub fn create_texture_image(b: *Backend, width: u32, height: u32) Texture_image {
        const image = b.device.create_image(width, height, .r8g8b8a8_srgb, .create(&.{.transfer_dst, .sampled}));
        
        b.temp_task.start_recording(true);
        const image_subresource = lib_vulkan.types.VkImageSubresourceRange {
            .aspectMask = .just(.color),
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1,
        };
        const image_barrier = lib_vulkan.types.VkImageMemoryBarrier {
            .srcAccessMask = .empty(),
            .dstAccessMask = .just(.shader_read),
            .oldLayout = .undefined,
            .newLayout = .shader_read_only_optimal,
            .srcQueueFamilyIndex = lib_vulkan.types.VK_QUEUE_FAMILY_IGNORED,
            .dstQueueFamilyIndex = lib_vulkan.types.VK_QUEUE_FAMILY_IGNORED,
            .image = image.image,
            .subresourceRange = image_subresource,
        };
        b.temp_task.barrier(.just(.top_of_pipe), .just(.fragment_shader), &.{}, &.{}, &.{image_barrier});
        b.temp_task.end_recording();
        b.temp_task.submit(&.{}, null, b.wait_fence);
        b.device.wait_for_fence(b.wait_fence, null);
        b.temp_task.reset();
        
        return .{
            .image = image,
            .b = b,
        };
    }
};

const Swapimage = struct {
    b: *Backend,
    image: lib_vulkan.types.VkImage,
    view: lib_vulkan.types.VkImageView,
    framebuffer: lib_vulkan.types.VkFramebuffer,
    descriptor_set: lib_vulkan.Descriptor_set,
    draw_task: lib_vulkan.Task,
    render_finished_semaphore: lib_vulkan.Semaphore,
    vertex_buffer: lib_vulkan.Buffer,
    indirect_buffer: lib_vulkan.Buffer,
    is_rendering: bool,
    render_done_fence: lib_vulkan.Fence,
    bound_images: [textures_per_rendering]lib_vulkan.types.VkImageView,
    
    pub fn init_from(image: lib_vulkan.types.VkImage, b: *Backend) Swapimage {
        const view = b.device.create_image_view(image, b.swapchain_image_format);
        const attachments = [_]lib_vulkan.types.VkImageView {view};
        const framebuffer = b.device.create_framebuffer(b.pipeline.render_pass, &attachments, b.render_size.width, b.render_size.height, 1);
        const descriptor_set = b.descriptor_pool.allocate_descriptor_set(b.descriptor_set_layout);
        for (0..textures_per_rendering) |i| {
            descriptor_set.set_image(0, @intCast(i), .sampled_image, undefined, b.dummy_image.image.view, .shader_read_only_optimal);
        }
        const render_finished_semaphore = b.device.create_semaphore();
        const render_done_fence = b.device.create_fence(false);
        const vertex_buffer = b.device.create_buffer(@sizeOf(Draw_object) * draw_buffer_size, .just(.vertex_buffer), .stream);
        var indirect_buffer = b.device.create_buffer(@sizeOf(lib_vulkan.types.VkDrawIndexedIndirectCommand), .just(.indirect_buffer), .stream);
        if (vertex_buffer.mapped == null) {
            @panic("vertex buffer must be mappable");
        }
        const draw_command = lib_vulkan.types.VkDrawIndexedIndirectCommand {
            .indexCount = 6,
            .instanceCount = 0,
            .firstIndex = 0,
            .vertexOffset = 0,
            .firstInstance = 0,
        };
        b.write_whole_buffer(&indirect_buffer, std.mem.asBytes(&draw_command));
        
        const draw_task = b.task_allocator.create_task();
        
        return .{
            .b = b,
            .image = image,
            .view = view,
            .framebuffer = framebuffer,
            .descriptor_set = descriptor_set,
            .draw_task = draw_task,
            .render_finished_semaphore = render_finished_semaphore,
            .vertex_buffer = vertex_buffer,
            .indirect_buffer = indirect_buffer,
            .is_rendering = false,
            .render_done_fence = render_done_fence,
            .bound_images = [1]lib_vulkan.types.VkImageView { b.dummy_image.image.view } ** textures_per_rendering,
        };
    }
    
    pub fn deinit(swapimage: *Swapimage) void {
        swapimage.indirect_buffer.deinit();
        swapimage.vertex_buffer.deinit();
        swapimage.draw_task.deinit();
        swapimage.b.device.destroy_fence(swapimage.render_done_fence);
        swapimage.b.device.destroy_semaphore(swapimage.render_finished_semaphore);
        swapimage.b.device.destroy_framebuffer(swapimage.framebuffer);
        swapimage.b.device.destroy_image_view(swapimage.view);
    }
    
    pub fn wait_rendering_done(swapimage: *Swapimage) void {
        if (swapimage.is_rendering) {
            swapimage.b.device.wait_for_fence(swapimage.render_done_fence, null);
            swapimage.is_rendering = false;
        }
    }
    
    pub fn bind_image(swapimage: *Swapimage, index: u32, image: *lib_vulkan.Image) void {
        swapimage.bound_images[index] = image.view;
        swapimage.descriptor_set.set_image(0, index, .sampled_image, undefined, image.view, .shader_read_only_optimal);
    }
};

pub const Draw_frame = struct {
    swapimage: *Swapimage,
    index: u32,
    draw_objects: [draw_buffer_size]Draw_object,
    draw_count: u32,
    already_drawn: bool,
    using_images: [textures_per_rendering]?*lib_vulkan.Image,
    
    fn submit_draw(draw_frame: *Draw_frame, present: bool) void {
        u.log_start(.{"Submitting draw commands"});
        u.log(.{"Wait until rendering is done"});
        draw_frame.swapimage.wait_rendering_done();
        draw_frame.write_objects();
        draw_frame.swapimage.is_rendering = true;
        const semaphore = if (present) draw_frame.swapimage.render_finished_semaphore else null;
        
        u.log(.{"Binding textures"});
        const dummy_image = &draw_frame.swapimage.b.dummy_image.image;
        for (draw_frame.using_images, 0..textures_per_rendering) |image, index| {
            draw_frame.swapimage.bind_image(@intCast(index), image orelse dummy_image);
        }
        
        u.log(.{"Record task"});
        if (draw_frame.already_drawn) {
            u.log(.{"Draw over existing"});
        } else {
            u.log(.{"Clear and draw"});
        }
        const pipeline = if (draw_frame.already_drawn) draw_frame.swapimage.b.pipeline_keep else draw_frame.swapimage.b.pipeline;
        var draw_task = draw_frame.swapimage.draw_task;
        draw_task.reset();
        draw_task.start_recording(false);
        const clear_values = [_]lib_vulkan.types.VkClearValue {
            .{
                .color = .{
                    .float32 = .{0, 0, 0, 1}
                }
            }
        };
        draw_task.start_render_pass(draw_frame.swapimage.framebuffer, draw_frame.swapimage.b.render_size, pipeline.render_pass, &clear_values);
        draw_task.bind_pipeline(.graphics, pipeline.pipeline);
        draw_task.bind_vertex_buffer(0, draw_frame.swapimage.vertex_buffer.buffer);
        draw_task.bind_index_buffer(draw_frame.swapimage.b.index_buffer.buffer);
        draw_task.bind_descriptor_set(.graphics, pipeline.layout, 0, draw_frame.swapimage.descriptor_set.descriptor_set);
        draw_task.draw_indexed_indirect(draw_frame.swapimage.indirect_buffer.buffer, 0, 1, @sizeOf(lib_vulkan.types.VkDrawIndexedIndirectCommand));
        draw_task.end_render_pass();
        draw_task.end_recording();
        u.log(.{"Submit"});
        draw_task.submit(&.{}, semaphore, draw_frame.swapimage.render_done_fence);
        
        draw_frame.already_drawn = true;
        draw_frame.draw_count = 0;
        draw_frame.using_images = [1]*lib_vulkan.Image { dummy_image } ** textures_per_rendering;
        if (present) {
            u.log(.{"Also submit present"});
            draw_frame.swapimage.b.swapchain.submit_present(draw_frame.index, &.{draw_frame.swapimage.render_finished_semaphore});
        } else {
            u.log(.{"Not presenting yet"});
        }
        u.log_end(.{"Submitting done"});
    }
    
    pub fn draw_object(draw_frame: *Draw_frame, rect: u.Rect2i, color: u.Screen_color, tex_image: *Texture_image, texture_rect: u.Rect2i, texture_offset: u.Vec2i) void {
        if (draw_frame.draw_count >= draw_buffer_size) {
            if (!draw_frame.already_drawn) {
                u.log(.{"WARNING: Too many objects, this is slow! "});
            }
            draw_frame.submit_draw(false);
        }
        std.debug.assert(draw_frame.draw_count < draw_buffer_size);
        
        const add_image = &tex_image.image;
        var texture_index: i32 = -1;
        for (&draw_frame.using_images, 0..) |*image, index| {
            if (image.* == add_image) {
                texture_index = @intCast(index);
                break;
            }
            if (image.* == null) {
                image.* = add_image;
                texture_index = @intCast(index);
                break;
            }
        }
        if (texture_index == -1) {
            if (!draw_frame.already_drawn) {
                u.log(.{"WARNING: Too many textures, this is slow! "});
            }
            draw_frame.submit_draw(false);
            u.assert(draw_frame.using_images[0] == null);
            draw_frame.using_images[0] = add_image;
            texture_index = 0;
        }
        
        const object = Draw_object {
            .position_x = rect.offset.x.to(i16),
            .position_y = rect.offset.y.to(i16),
            .size_x = rect.size.x.to(i16),
            .size_y = rect.size.y.to(i16),
            .color_r = color.red,
            .color_g = color.green,
            .color_b = color.blue,
            .color_a = color.alpha,
            .tex_pos_x = texture_rect.offset.x.to(i16),
            .tex_pos_y = texture_rect.offset.y.to(i16),
            .tex_size_x = texture_rect.size.x.to(i16),
            .tex_size_y = texture_rect.size.y.to(i16),
            .tex_offset_x = texture_offset.x.to(i16),
            .tex_offset_y = texture_offset.y.to(i16),
            .tex_id = @intCast(texture_index),
        };
        draw_frame.draw_objects[draw_frame.draw_count] = object;
        draw_frame.draw_count += 1;
    }
    
    fn write_objects(draw_frame: *Draw_frame) void {
        u.log(.{"Upload ",draw_frame.draw_count," objects"});
        draw_frame.swapimage.b.write_buffer(&draw_frame.swapimage.vertex_buffer, 0, std.mem.sliceAsBytes(draw_frame.draw_objects[0..draw_frame.draw_count]));
        const draw_count: u32 = draw_frame.draw_count;
        draw_frame.swapimage.b.write_buffer(&draw_frame.swapimage.indirect_buffer, 4, std.mem.asBytes(&draw_count));
    }
    
    pub fn finish(draw_frame: *Draw_frame) void {
        draw_frame.submit_draw(true);
    }
    
    pub fn size(draw_frame: *Draw_frame) u.Vec2i {
        const extent = draw_frame.swapimage.b.render_size;
        return .create(
            .create(extent.width),
            .create(extent.height),
        );
    }
};

pub const Texture_image = struct {
    image: lib_vulkan.Image,
    b: *Backend,
    
    pub fn write(image: *Texture_image, offset_x: u32, offset_y: u32, width: u32, height: u32, data: []const u.Screen_color) void {
        const b = image.b;
        u.assert(data.len == width * height);
        u.log_start(.{"Writing ",data.len," bytes to image"});
        u.log("Writing to staging buffer");
        b.write_buffer(&b.staging_buffer, 0, std.mem.sliceAsBytes(data));
        u.log("Wait until the image is not used");
        image.wait_rendering_done();
        
        u.log("Record command");
        b.temp_task.start_recording(true);
        const image_subresource = lib_vulkan.types.VkImageSubresourceRange {
            .aspectMask = .just(.color),
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1,
        };
        const image_barrier_1 = lib_vulkan.types.VkImageMemoryBarrier {
            .srcAccessMask = .just(.shader_read),
            .dstAccessMask = .just(.transfer_write),
            .oldLayout = .shader_read_only_optimal,
            .newLayout = .transfer_dst_optimal,
            .srcQueueFamilyIndex = lib_vulkan.types.VK_QUEUE_FAMILY_IGNORED,
            .dstQueueFamilyIndex = lib_vulkan.types.VK_QUEUE_FAMILY_IGNORED,
            .image = image.image.image,
            .subresourceRange = image_subresource,
        };
        b.temp_task.barrier(.just(.fragment_shader), .just(.transfer), &.{}, &.{}, &.{image_barrier_1});
        b.temp_task.copy_buffer_to_image(b.staging_buffer.buffer, image.image.image, offset_x, offset_y, width, height);
        const image_barrier_2 = lib_vulkan.types.VkImageMemoryBarrier {
            .srcAccessMask = .just(.transfer_write),
            .dstAccessMask = .just(.shader_read),
            .oldLayout = .transfer_dst_optimal,
            .newLayout = .shader_read_only_optimal,
            .srcQueueFamilyIndex = lib_vulkan.types.VK_QUEUE_FAMILY_IGNORED,
            .dstQueueFamilyIndex = lib_vulkan.types.VK_QUEUE_FAMILY_IGNORED,
            .image = image.image.image,
            .subresourceRange = image_subresource,
        };
        b.temp_task.barrier(.just(.transfer), .just(.fragment_shader), &.{}, &.{}, &.{image_barrier_2});
        b.temp_task.end_recording();
        u.log("Submit command");
        b.temp_task.submit(&.{}, null, b.wait_fence);
        b.device.wait_for_fence(b.wait_fence, null);
        u.log("Finished");
        b.temp_task.reset();
        u.log_end({});
    }
    
    pub fn wait_rendering_done(image: *Texture_image) void {
        if (image.b.rendering_active) {
            for (image.b.swapimages) |*swapimage| {
                if (swapimage.is_rendering) {
                    const is_using_this_image = for (swapimage.bound_images) |using_image| {
                        if (using_image == image.image.view) {
                            break true;
                        }
                    } else false;
                    if (is_using_this_image) {
                        swapimage.wait_rendering_done();
                    }
                }
            }
        }
    }
    
    pub fn deinit(image: *Texture_image) void {
        image.wait_rendering_done();
        image.image.deinit();
    }
};

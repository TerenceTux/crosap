const u = @import("util");
const std = @import("std");
const lib_vulkan = @import("lib_vulkan");

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

// 0*>-1   0   1*
// | /       / |
// 2   3   2-<-3
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
const textures_per_rendering = 8; // must match the shader

const max_swapchain_size = 32;

pub const Render = struct {
    loader: lib_vulkan.Loader,
    instance: lib_vulkan.Instance,
    physical_device: lib_vulkan.Physical_device,
    
    device: lib_vulkan.Device,
    wait_fence: lib_vulkan.Fence,
    task_allocator: lib_vulkan.Task_allocator,
    temp_task: lib_vulkan.Task,
    index_buffer: lib_vulkan.Buffer,
    staging_buffer: lib_vulkan.Buffer,
    descriptor_set_layout: lib_vulkan.types.Descriptor_set_layout,
    descriptor_pool: lib_vulkan.Descriptor_pool,
    dummy_image: *Texture,
    
    surface_available: bool,
    surface: lib_vulkan.Surface,
    render_size: lib_vulkan.types.Extent_2d, // size of the swapchain. 0 if there is no swapchain
    swapchain_min_image_count: u32,
    swapchain_image_format: lib_vulkan.types.Format,
    swapchain_image_colorspace: lib_vulkan.types.Khr_color_space,
    swapchain_tranform: lib_vulkan.types.Khr_surface_transform_flag_option,
    swapchain_alpha_composite: lib_vulkan.types.Khr_composite_alpha_flag_option,
    selected_present_mode: lib_vulkan.types.Khr_present_mode,
    swapchain: lib_vulkan.Swapchain,
    swapimages: []Swapimage,
    pipeline: lib_vulkan.Graphics_pipeline,
    pipeline_keep: lib_vulkan.Graphics_pipeline,
    
    draw_frame: Draw_frame, // only valid between new_frame and end_frame
    
    pub fn init(r: *Render, required_extensions: []const lib_vulkan.types.Instance_extension) !void {
        r.loader.init();
        r.init_instance(required_extensions);
        r.init_physical_device();
        r.init_device();
        r.wait_fence = r.device.create_fence(false);
        r.task_allocator = r.device.create_task_allocator(true, true);
        r.temp_task = r.task_allocator.create_task();
        r.staging_buffer = r.device.create_buffer(staging_buffer_size, .just(.transfer_src), .staging);
        r.index_buffer = r.device.create_buffer(@sizeOf(@TypeOf(index_data)), .create(&.{.index_buffer, .transfer_dst}), .infrequent_write);
        r.write_whole_buffer(&r.index_buffer, std.mem.sliceAsBytes(&index_data));
        u.assert(r.staging_buffer.mapped != null);
        r.init_descriptor_info();
        r.dummy_image = try r.create_texture(.create(.create(1), .create(1)));
        r.render_size = .{
            .width = 0,
            .height = 0,
        };
        r.draw_active = false;
    }
    
    pub fn rendering_active(r: *Render) bool {
        return r.render_size.width > 0 and r.render_size.height > 0;
    }
    
    pub fn rendering_enable(r: *Render, size: u.Vec2i) void {
        u.log_start(.{"Enabling rendering with size ", size});
        defer u.log_end({});
        
        u.assert(!r.rendering_active);
        r.render_size = .{
            .width = size.x.to(u32),
            .height = size.y.to(u32),
        };
        r.init_swapchain();
        r.init_pipeline();
        r.init_swapchain_images();
    }
    
    pub fn rendering_disable(r: *Render) void {
        u.log_start("Disabling rendering");
        defer u.log_end({});
        u.assert(r.rendering_active);
        
        u.log("Wait for all drawing commands");
        r.device.wait_everything_finished();
        u.log("Pipeline");
        r.descriptor_pool.reset();
        r.pipeline.deinit();
        r.pipeline_keep.deinit();
        u.log("Swapchain");
        for (r.swapimages) |*swapimage| {
            swapimage.deinit();
        }
        u.alloc.free(r.swapimages);
        r.swapchain.deinit();
        r.render_size = .{
            .width = 0,
            .height = 0,
        };
    }
    
    fn init_instance(r: *Render, required_extensions: []const lib_vulkan.types.Instance_extension) void {
        u.log_start("Required vulkan extensions:");
        for (required_extensions) |extension| {
            u.log(extension);
        }
        u.log_end({});
        
        const validation_layer_name = "VK_LAYER_KHRONOS_validation";
        var validation_layer_available = false;
        var validation_layer_settings_available = false;
        if (u.debug) {
            const version = r.loader.instance_version();
            u.log(.{"Vulkan version: ",version});
            
            u.log_start("Instance extensions:");
            var extensions = r.loader.get_extensions(null);
            for (extensions.items) |extension| {
                u.log(.{extension.name," (version ",extension.version,")"});
            }
            extensions.deinit();
            u.log_end({});
            
            u.log_start("Available layers:");
            var layers = r.loader.get_layers();
            for (layers.items) |layer| {
                var this_is_the_validation_layer = false;
                if (std.mem.eql(u8, layer.name, validation_layer_name)) {
                    this_is_the_validation_layer = true;
                    validation_layer_available = true;
                }
                u.log(.{layer.name," (version ",layer.layer_version,"): ",layer.description," - for vulkan ",layer.vulkan_version});
                
                u.log_start("This layer provides the following extensions:");
                var layer_extensions = r.loader.get_extensions(layer.name);
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
        r.instance = r.loader.create_instance(null, .{
            .name = "crosap",
            .version = 0,
        }, using_layers, using_extensions, layer_settings) catch @panic("Can't create instance");
    }
    
    fn init_physical_device(r: *Render) void {
        u.log_start("Physical devices:");
        const physical_devices = r.instance.get_physical_devices();
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
        
        const best_physical_device = r.pick_physical_device(physical_devices, &.{}) orelse @panic("No suitable physical devices");
        r.physical_device = best_physical_device.*;
    }
    
    fn pick_physical_device(r: *Render, physical_devices: []lib_vulkan.Physical_device, preferred: []const u16) ?*lib_vulkan.Physical_device {
        const type_order = [_]lib_vulkan.types.Physical_device_type {
            .integrated_gpu,
            .discrete_gpu,
            .virtual_gpu,
            .other,
            .cpu,
        };
        
        for (preferred) |index| {
            if (index >= physical_devices.len) continue;
            
            const physical_device = &physical_devices[index];
            if (r.physical_device_is_usable(physical_device)) {
                return physical_device;
            }
        }
        
        for (type_order) |gpu_type| {
            for (physical_devices) |*physical_device| {
                var properties = physical_device.get_properties();
                defer properties.deinit();
                if (properties.device_type != gpu_type) continue;
                
                if (r.physical_device_is_usable(physical_device)) {
                    return physical_device;
                }
            }
        }
        
        return null;
    }
    
    fn physical_device_is_usable(r: *Render, physical_device: *lib_vulkan.Physical_device) bool {
        const queue_type_index = physical_device.best_queue_type_index() orelse return false;
        if (!r.glfw.physical_device_can_present(r.instance.instance, physical_device.physical_device, queue_type_index)) {
            return false;
        }
        
        return true;
    }
    
    fn init_device(r: *Render) void {
        u.log("Creating device");
        const extensions = [_][]const u8 {
            "VK_KHR_swapchain",
        };
        r.device = r.physical_device.create_device(&extensions);
    }
    
    fn init_descriptor_info(r: *Render) void {
        const bindings = [_]lib_vulkan.types.Descriptor_set_layout_binding {
            .{
                .binding = 0,
                .descriptorType = .sampled_image,
                .descriptorCount = 8,
                .stageFlags = .just(.fragment),
                .pImmutableSamplers = null,
            },
        };
        r.descriptor_set_layout = r.device.create_descriptor_set_layout(&bindings);
        const max_sizes = [_]lib_vulkan.types.Descriptor_pool_size {
            .{
                .type = .sampled_image,
                .descriptorCount = 8 * max_swapchain_size,
            },
        };
        r.descriptor_pool = r.device.create_descriptor_pool(max_swapchain_size, &max_sizes);
    }
    
    fn init_swapchain(r: *Render) void {
        const surface_properties = r.surface.get_properties();
        
        if (surface_properties.max_swapchain_images) |max_swapchain_images| {
            u.log(.{"Swapchain image count must be between ",surface_properties.min_swapchain_images," and ",max_swapchain_images});
        } else {
            u.log(.{"Swapchain image count must be at least ",surface_properties.min_swapchain_images});
        }
        r.swapchain_min_image_count = 3;
        if (surface_properties.min_swapchain_images > r.swapchain_min_image_count) {
            r.swapchain_min_image_count = surface_properties.min_swapchain_images;
        }
        if (surface_properties.max_swapchain_images) |max_swapchain_images| {
            if (max_swapchain_images < r.swapchain_min_image_count) {
                r.swapchain_min_image_count = max_swapchain_images;
            }
        }
        u.log(.{"Choosing a swapchain image count of ",r.swapchain_min_image_count});
        
        u.log(.{"Surface size must be between ",surface_properties.min_size," and ",surface_properties.max_size});
        if (surface_properties.current_size) |current_size| {
            u.log(.{"Surface size is currently ",current_size});
        } else {
            u.log(.{"Surface size will be determined by system"});
        }
        u.log(.{"We want to use the size ",r.render_size});
        if (r.render_size.width < surface_properties.min_size.width) {
            @panic("Render width too small");
        }
        if (r.render_size.height < surface_properties.min_size.height) {
            @panic("Render height too small");
        }
        if (r.render_size.width > surface_properties.max_size.width) {
            @panic("Render width too big");
        }
        if (r.render_size.height > surface_properties.max_size.height) {
            @panic("Render height too big");
        }
        
        u.log(.{"Max array layers: ",surface_properties.max_array_layers});
        u.log(.{"Supported transforms: ",surface_properties.supported_transforms," (currently ",surface_properties.current_transform,")"});
        r.swapchain_tranform = surface_properties.supported_transforms.select_best(&.{
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
        u.log(.{"Selecting transform: ",r.swapchain_tranform});
        u.log(.{"Supported alpha composite modes: ",surface_properties.supported_alpha_composite_mode});
        r.swapchain_alpha_composite = surface_properties.supported_alpha_composite_mode.select_best(&.{
            .fully_opaque,
            .inherit,
            .pre_multiplied,
            .post_multiplied,
        });
        u.log(.{"Selecting alpha composite mode: ",r.swapchain_alpha_composite});
        
        const supported_formats = r.surface.get_supported_formats();
        u.log_start("Supported formats:");
        for (supported_formats) |format| {
            u.log(.{"Format: ",format.format,", color space: ",format.color_space});
        }
        u.log_end({});
        
        var selected_format = supported_formats[0];
        const preferred_formats = [_]lib_vulkan.types.Format {
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
        r.swapchain_image_format = selected_format.format;
        r.swapchain_image_colorspace = selected_format.color_space;
        
        const supported_present_modes = r.surface.get_supported_present_modes();
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
        r.selected_present_mode = select_best(lib_vulkan.Surface.Present_mode, supported_present_modes, &preferred_present_modes) orelse @panic("No present mode available");
        u.log(.{"Selected present mode ",r.selected_present_mode});
        u.alloc.free(supported_present_modes);
        
        r.swapchain = r.device.create_swapchain(r.surface.surface, r.swapchain_min_image_count, r.swapchain_image_format, r.swapchain_image_colorspace, r.render_size, 1,
                                                r.swapchain_tranform, r.swapchain_alpha_composite, r.selected_present_mode, null);
        
    }
    
    fn init_swapchain_images(r: *Render) void {
        const swapchain_images = r.swapchain.get_images();
        if (swapchain_images.len > max_swapchain_size) {
            @panic("swapchain is too large");
        }
        r.swapimages = u.alloc.alloc(Swapimage, swapchain_images.len) catch @panic("no memory");
        for (swapchain_images, r.swapimages) |image, *swapimage| {
            swapimage.* = .init_from(image, r);
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
    
    fn init_pipeline(r: *Render) void {
        u.log_start("Create graphics pipeline");
        const width: u32 = r.render_size.width;
        const height: u32 = r.render_size.height;
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
        const vertex_bindings = [_]lib_vulkan.types.Vertex_input_binding_description {
            .{
                .binding = 0,
                .stride = @sizeOf(Draw_object),
                .inputRate = .instance,
            },
        };
        const vertex_attributes = [_]lib_vulkan.types.Vertex_input_attribute_description {
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
        const descriptor_set_layouts = [_]lib_vulkan.types.Descriptor_set_layout {
            r.descriptor_set_layout,
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
            .width = r.render_size.width,
            .height = r.render_size.height,
            .image_format = r.swapchain_image_format,
            .keep_previous = false,
        };
        r.pipeline = r.device.create_graphics_pipeline(&create_info);
        var create_info_keep = create_info;
        create_info_keep.keep_previous = true;
        r.pipeline_keep = r.device.create_graphics_pipeline(&create_info_keep);
        u.log_end({});
    }
    
    pub fn deinit(r: *Render) void {
        u.log_start("Deinit vulkan render");
        if (r.rendering_active) {
            r.rendering_disable();
        }
        u.log("Tasks");
        r.temp_task.deinit();
        r.task_allocator.deinit();
        u.log("General objects");
        r.dummy_image.deinit();
        r.descriptor_pool.deinit();
        r.device.destroy_descriptor_set_layout(r.descriptor_set_layout);
        r.staging_buffer.deinit();
        r.index_buffer.deinit();
        r.device.destroy_fence(r.wait_fence);
        u.log("Device");
        r.device.deinit();
        u.log("Window");
        r.surface.deinit();
        u.log("Instance");
        r.instance.deinit();
        r.loader.deinit();
        u.log_end({});
    }
    
    pub fn create_texture(r: *Render, size: u.Vec2i) !*Texture {
        const image = r.device.create_image(size.x.to(u32), size.y.to(u32), .r8g8b8a8_srgb, .create(&.{.transfer_dst, .sampled}));
        
        r.temp_task.start_recording(true);
        const image_subresource = lib_vulkan.types.Image_subresource_range {
            .aspectMask = .just(.color),
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1,
        };
        const image_barrier = lib_vulkan.types.Image_memory_barrier {
            .srcAccessMask = .empty(),
            .dstAccessMask = .just(.shader_read),
            .oldLayout = .undefined,
            .newLayout = .shader_read_only_optimal,
            .srcQueueFamilyIndex = lib_vulkan.types.queue_family_ignored,
            .dstQueueFamilyIndex = lib_vulkan.types.queue_family_ignored,
            .image = image.image,
            .subresourceRange = image_subresource,
        };
        r.temp_task.barrier(.just(.top_of_pipe), .just(.fragment_shader), &.{}, &.{}, &.{image_barrier});
        r.temp_task.end_recording();
        r.temp_task.submit(&.{}, null, r.wait_fence);
        r.device.wait_for_fence(r.wait_fence, null);
        r.temp_task.reset();
        
        const texture = u.alloc.create(Texture) catch @panic("no memory");
        texture.* = .{
            .image = image,
            .r = r,
        };
        return texture;
    }
    
    pub fn destroy_texture(r: *Render, texture: *Texture) void {
        _ = r;
        texture.deinit();
        u.alloc.destroy(texture);
    }
    
    pub fn update_texture(r: *Render, texture: *Texture, rect: u.Rect2i, data: []const u.Screen_color) !void {
        _ = r;
        texture.write(rect.left().to(u32), rect.top().to(u32), rect.size.x.to(u32), rect.size.y.to(u32), data);
    }
    
    
    // if the vulkan surface has a current size, we use that.
    // otherwise, we use the parameter (but within the surface limits)
    // if that's not available, we use the max size (for lack of better option)
    pub fn new_frame(r: *Render, suggested_size: ?u.Vec2i) !?u.Vec2i {
        u.log_start(.{"New frame requested"});
        defer u.log_end(.{});
        if (!r.surface_available) {
            u.log(.{"No surface available, so we can't render"});
            return null;
        }
        
        const surface_properties = r.surface.get_properties();
        var use_size = if (surface_properties.current_size) |surface_size| (
            surface_size
        ) else if (suggested_size) |size_available| (
            .{
                .width = size_available.x.to(u32),
                .height = size_available.y.to(u32),
            }
        ) else (
            surface_properties.max_size
        );
        if (use_size.width < surface_properties.min_size.width) {
            use_size.width = surface_properties.min_size.width;
        }
        if (use_size.width > surface_properties.max_size.width) {
            use_size.width = surface_properties.max_size.width;
        }
        if (use_size.height < surface_properties.min_size.height) {
            use_size.height = surface_properties.min_size.height;
        }
        if (use_size.height > surface_properties.max_size.height) {
            use_size.height = surface_properties.max_size.height;
        }
        u.log(.{"Size: ",use_size});
        if (use_size != r.render_size) {
            u.log(.{"This is different that the old size ",r.render_size});
            if (use_size.width == 0 or use_size.height == 0) {
                r.rendering_disable();
            } else if (r.render_size.width == 0 or r.render_size.height == 0) {
                r.rendering_enable(.create(.create(use_size.width), .create(use_size.height)));
            } else {
                r.rendering_disable();
                r.rendering_enable(.create(.create(use_size.width), .create(use_size.height)));
            }
            u.assert(r.render_size.width == use_size.width);
            u.assert(r.render_size.height == use_size.height);
        }
        
        if (!r.rendering_active) {
            u.log("Surface is empty, so not rendering");
            return null;
        }
        u.log(.{"Aquiring swapchain image"});
        const index = r.swapchain.aquire_next_image(null, r.wait_fence) orelse {
            u.log(.{"Swapchain broken, disabling rendering"});
            r.rendering_disable();
            u.log(.{"Not rendering this frame"});
            return null;
        };
        u.log(.{"Aquired image index: ",index});
        u.log(.{"Wait until the image is useable"});
        r.device.wait_for_fence(r.wait_fence, null);
        u.log(.{"We can now use the image"});
        
        const swapimage = &r.swapimages[index];
        r.draw_active = true;
        r.draw_frame = .{
            .swapimage = swapimage,
            .index = index,
            .draw_objects = undefined,
            .draw_count = 0,
            .already_drawn = false,
            .using_images = [1]?*lib_vulkan.Image { null } ** textures_per_rendering,
        };
    }
    
    pub fn draw_object(r: *Render, rect: u.Rect2i, color: u.Screen_color, texture: *Texture, texture_rect: u.Rect2i, texture_offset: u.Vec2i) !void {
        r.draw_frame.draw_object(rect, color, texture, texture_rect, texture_offset);
    }
    
    pub fn end_frame(r: *Render) !void {
        r.draw_frame.finish();
    }
    
    pub fn write_buffer(r: *Render, buffer: *lib_vulkan.Buffer, offset: usize, data: []const u8) void {
        if (buffer.mapped) |write_ptr| {
            @memcpy(write_ptr[offset..offset+data.len], data);
            buffer.flush_region(offset, data.len);
        } else {
            r.write_buffer(&r.staging_buffer, 0, data);
            r.temp_task.start_recording(true);
            r.temp_task.copy_buffer(data.len, r.staging_buffer.buffer, 0, buffer.buffer, offset);
            r.temp_task.end_recording();
            r.temp_task.submit(&.{}, null, r.wait_fence);
            r.device.wait_for_fence(r.wait_fence, null);
            r.temp_task.reset();
        }
    }
    
    pub fn write_whole_buffer(r: *Render, buffer: *lib_vulkan.Buffer, data: []const u8) void {
        u.assert(data.len == buffer.size);
        r.write_buffer(buffer, 0, data);
    }
};

const Swapimage = struct {
    r: *Render,
    image: lib_vulkan.types.Image,
    view: lib_vulkan.types.Image_view,
    framebuffer: lib_vulkan.types.Framebuffer,
    descriptor_set: lib_vulkan.Descriptor_set,
    draw_task: lib_vulkan.Task,
    render_finished_semaphore: lib_vulkan.Semaphore,
    vertex_buffer: lib_vulkan.Buffer,
    indirect_buffer: lib_vulkan.Buffer,
    is_rendering: bool,
    render_done_fence: lib_vulkan.Fence,
    bound_images: [textures_per_rendering]lib_vulkan.types.Image_view,
    
    pub fn init_from(image: lib_vulkan.types.Image, r: *Render) Swapimage {
        const view = r.device.create_image_view(image, r.swapchain_image_format);
        const attachments = [_]lib_vulkan.types.Image_view {view};
        const framebuffer = r.device.create_framebuffer(r.pipeline.render_pass, &attachments, r.render_size.width, r.render_size.height, 1);
        const descriptor_set = r.descriptor_pool.allocate_descriptor_set(r.descriptor_set_layout);
        for (0..textures_per_rendering) |i| {
            descriptor_set.set_image(0, @intCast(i), .sampled_image, undefined, r.dummy_image.image.view, .shader_read_only_optimal);
        }
        const render_finished_semaphore = r.device.create_semaphore();
        const render_done_fence = r.device.create_fence(false);
        const vertex_buffer = r.device.create_buffer(@sizeOf(Draw_object) * draw_buffer_size, .just(.vertex_buffer), .stream);
        var indirect_buffer = r.device.create_buffer(@sizeOf(lib_vulkan.types.Draw_indexed_indirect_command), .just(.indirect_buffer), .stream);
        if (vertex_buffer.mapped == null) {
            @panic("vertex buffer must be mappable");
        }
        const draw_command = lib_vulkan.types.Draw_indexed_indirect_command {
            .indexCount = 6,
            .instanceCount = 0,
            .firstIndex = 0,
            .vertexOffset = 0,
            .firstInstance = 0,
        };
        r.write_whole_buffer(&indirect_buffer, std.mem.asBytes(&draw_command));
        
        const draw_task = r.task_allocator.create_task();
        
        return .{
            .r = r,
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
            .bound_images = [1]lib_vulkan.types.Image_view { r.dummy_image.image.view } ** textures_per_rendering,
        };
    }
    
    pub fn deinit(swapimage: *Swapimage) void {
        swapimage.indirect_buffer.deinit();
        swapimage.vertex_buffer.deinit();
        swapimage.draw_task.deinit();
        swapimage.r.device.destroy_fence(swapimage.render_done_fence);
        swapimage.r.device.destroy_semaphore(swapimage.render_finished_semaphore);
        swapimage.r.device.destroy_framebuffer(swapimage.framebuffer);
        swapimage.r.device.destroy_image_view(swapimage.view);
    }
    
    pub fn wait_rendering_done(swapimage: *Swapimage) void {
        if (swapimage.is_rendering) {
            swapimage.r.device.wait_for_fence(swapimage.render_done_fence, null);
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
        const dummy_image = &draw_frame.swapimage.r.dummy_image.image;
        for (draw_frame.using_images, 0..textures_per_rendering) |image, index| {
            draw_frame.swapimage.bind_image(@intCast(index), image orelse dummy_image);
        }
        
        u.log(.{"Record task"});
        if (draw_frame.already_drawn) {
            u.log(.{"Draw over existing"});
        } else {
            u.log(.{"Clear and draw"});
        }
        const pipeline = if (draw_frame.already_drawn) draw_frame.swapimage.r.pipeline_keep else draw_frame.swapimage.r.pipeline;
        var draw_task = draw_frame.swapimage.draw_task;
        draw_task.reset();
        draw_task.start_recording(false);
        const clear_values = [_]lib_vulkan.types.Clear_value {
            .{
                .color = .{
                    .float32 = .{0, 0, 0, 1}
                }
            }
        };
        draw_task.start_render_pass(draw_frame.swapimage.framebuffer, draw_frame.swapimage.r.render_size, pipeline.render_pass, &clear_values);
        draw_task.bind_pipeline(.graphics, pipeline.pipeline);
        draw_task.bind_vertex_buffer(0, draw_frame.swapimage.vertex_buffer.buffer);
        draw_task.bind_index_buffer(draw_frame.swapimage.r.index_buffer.buffer);
        draw_task.bind_descriptor_set(.graphics, pipeline.layout, 0, draw_frame.swapimage.descriptor_set.descriptor_set);
        draw_task.draw_indexed_indirect(draw_frame.swapimage.indirect_buffer.buffer, 0, 1, @sizeOf(lib_vulkan.types.Draw_indexed_indirect_command));
        draw_task.end_render_pass();
        draw_task.end_recording();
        u.log(.{"Submit"});
        draw_task.submit(&.{}, semaphore, draw_frame.swapimage.render_done_fence);
        
        draw_frame.already_drawn = true;
        draw_frame.draw_count = 0;
        draw_frame.using_images = [1]*lib_vulkan.Image { dummy_image } ** textures_per_rendering;
        if (present) {
            u.log(.{"Also submit present"});
            draw_frame.swapimage.r.swapchain.submit_present(draw_frame.index, &.{draw_frame.swapimage.render_finished_semaphore});
        } else {
            u.log(.{"Not presenting yet"});
        }
        u.log_end(.{"Submitting done"});
    }
    
    pub fn draw_object(draw_frame: *Draw_frame, rect: u.Rect2i, color: u.Screen_color, tex_image: *Texture, texture_rect: u.Rect2i, texture_offset: u.Vec2i) void {
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
        draw_frame.swapimage.r.write_buffer(&draw_frame.swapimage.vertex_buffer, 0, std.mem.sliceAsBytes(draw_frame.draw_objects[0..draw_frame.draw_count]));
        const draw_count: u32 = draw_frame.draw_count;
        draw_frame.swapimage.r.write_buffer(&draw_frame.swapimage.indirect_buffer, 4, std.mem.asBytes(&draw_count));
    }
    
    pub fn finish(draw_frame: *Draw_frame) void {
        draw_frame.submit_draw(true);
    }
    
    pub fn size(draw_frame: *Draw_frame) u.Vec2i {
        const extent = draw_frame.swapimage.r.render_size;
        return .create(
            .create(extent.width),
                       .create(extent.height),
        );
    }
};

pub const Texture = struct {
    image: lib_vulkan.Image,
    r: *Render,
    
    pub fn write(image: *Texture, offset_x: u32, offset_y: u32, width: u32, height: u32, data: []const u.Screen_color) void {
        const r = image.r;
        u.assert(data.len == width * height);
        u.log_start(.{"Writing ",data.len," bytes to image"});
        u.log("Writing to staging buffer");
        r.write_buffer(&r.staging_buffer, 0, std.mem.sliceAsBytes(data));
        u.log("Wait until the image is not used");
        image.wait_rendering_done();
        
        u.log("Record command");
        r.temp_task.start_recording(true);
        const image_subresource = lib_vulkan.types.Image_subresource_range {
            .aspectMask = .just(.color),
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1,
        };
        const image_barrier_1 = lib_vulkan.types.Image_memory_barrier {
            .srcAccessMask = .just(.shader_read),
            .dstAccessMask = .just(.transfer_write),
            .oldLayout = .shader_read_only_optimal,
            .newLayout = .transfer_dst_optimal,
            .srcQueueFamilyIndex = lib_vulkan.types.queue_family_ignored,
            .dstQueueFamilyIndex = lib_vulkan.types.queue_family_ignored,
            .image = image.image.image,
            .subresourceRange = image_subresource,
        };
        r.temp_task.barrier(.just(.fragment_shader), .just(.transfer), &.{}, &.{}, &.{image_barrier_1});
        r.temp_task.copy_buffer_to_image(r.staging_buffer.buffer, image.image.image, offset_x, offset_y, width, height);
        const image_barrier_2 = lib_vulkan.types.Image_memory_barrier {
            .srcAccessMask = .just(.transfer_write),
            .dstAccessMask = .just(.shader_read),
            .oldLayout = .transfer_dst_optimal,
            .newLayout = .shader_read_only_optimal,
            .srcQueueFamilyIndex = lib_vulkan.types.queue_family_ignored,
            .dstQueueFamilyIndex = lib_vulkan.types.queue_family_ignored,
            .image = image.image.image,
            .subresourceRange = image_subresource,
        };
        r.temp_task.barrier(.just(.transfer), .just(.fragment_shader), &.{}, &.{}, &.{image_barrier_2});
        r.temp_task.end_recording();
        u.log("Submit command");
        r.temp_task.submit(&.{}, null, r.wait_fence);
        r.device.wait_for_fence(r.wait_fence, null);
        u.log("Finished");
        r.temp_task.reset();
        u.log_end({});
    }
    
    pub fn wait_rendering_done(image: *Texture) void {
        if (image.r.rendering_active) {
            for (image.r.swapimages) |*swapimage| {
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
    
    pub fn deinit(image: *Texture) void {
        image.wait_rendering_done();
        image.image.deinit();
    }
};

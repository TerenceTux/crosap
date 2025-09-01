const std = @import("std");
const u = @import("util");

pub const Version = struct {
    variant: u3,
    major: u7,
    minor: u10,
    patch: u12,
    
    pub fn from_u32(num: u32) Version {
        return .{
            .variant = @intCast((num & 0b11100000000000000000000000000000) >> 29),
            .major   = @intCast((num & 0b00011111110000000000000000000000) >> 22),
            .minor   = @intCast((num & 0b00000000001111111111000000000000) >> 12),
            .patch   = @intCast((num & 0b00000000000000000000111111111111) >> 0),
        };
    }
    
    pub fn to_u32(version: Version) u32 {
        var num: u32 = 0;
        num |= @as(u32, version.variant) << 29;
        num |= @as(u32, version.major) << 22;
        num |= @as(u32, version.minor) << 12;
        num |= @as(u32, version.patch) << 0;
        return num;
    }
    
    pub fn debug_print(version: Version, stream: anytype) void {
        u.byte_writer.validate(stream);
        const text = std.fmt.allocPrint(u.alloc, "{d}.{d}.{d}.{d}", .{version.variant, version.major, version.minor, version.patch}) catch @panic("No memory");
        stream.write_slice(text);
        u.alloc.free(text);
    }
};

//////// ENUMS

pub const VkResult = enum(c_int) {
    success = 0,
    not_ready = 1,
    timeout = 2,
    event_set = 3,
    event_reset = 4,
    incomplete = 5,
    error_out_of_host_memory = -1,
    error_out_of_device_memory = -2,
    error_initialization_failed = -3,
    error_device_lost = -4,
    error_memory_map_failed = -5,
    error_layer_not_present = -6,
    error_extension_not_present = -7,
    error_feature_not_present = -8,
    error_incompatible_driver = -9,
    error_too_many_objects = -10,
    error_format_not_supported = -11,
    error_fragmented_pool = -12,
    error_unknown = -13,
    suboptimal_khr = 1000001003,
    out_of_date_khr = -1000001004,
    
    pub fn name(result: VkResult) []const u8 {
        return switch (result) {
            .success => "success",
            .not_ready => "not ready",
            .timeout => "timeout",
            .event_set => "event set",
            .event_reset => "event reset",
            .incomplete => "incomplete",
            .error_out_of_host_memory => "error: out of host memory",
            .error_out_of_device_memory => "error: out of device memory",
            .error_initialization_failed => "error: initialization failed",
            .error_device_lost => "error: device lost",
            .error_memory_map_failed => "error: memory map failed",
            .error_layer_not_present => "error: layer not present",
            .error_extension_not_present => "error: extension not present",
            .error_feature_not_present => "error: feature not present",
            .error_incompatible_driver => "error: incompatible driver",
            .error_too_many_objects => "error: too many objects",
            .error_format_not_supported => "error: format not supported",
            .error_fragmented_pool => "error: fragmented pool",
            .error_unknown => "error: unknown",
            .suboptimal_khr => "suboptimal",
            .out_of_date_khr => "error: out of date",
        };
    }
};

pub fn handle_error(result: VkResult) void {
    if (result != .success) {
        @branchHint(.cold);
        std.debug.panic("Vulkan error: {s}", .{result.name()});
    }
}

pub const VkSystemAllocationScope = enum(c_int) {
    command = 0,
    object = 1,
    cache = 2,
    device = 3,
    instance = 4,
};

pub const VkInternalAllocationType = enum(c_int) {
    executable = 0,
};

pub const VkStructureType = enum(c_int) {
    VkApplicationInfo = 0,
    VkInstanceCreateInfo = 1,
    VkDeviceQueueCreateInfo = 2,
    VkDeviceCreateInfo = 3,
    VkSubmitInfo = 4,
    VkMemoryAllocateInfo = 5,
    VkMappedMemoryRange = 6,
    VkBindSparseInfo = 7,
    VkFenceCreateInfo = 8,
    VkSemaphoreCreateInfo = 9,
    VkEventCreateInfo = 10,
    VkQueryPoolCreateInfo = 11,
    VkBufferCreateInfo = 12,
    VkBufferViewCreateInfo = 13,
    VkImageCreateInfo = 14,
    VkImageViewCreateInfo = 15,
    VkShaderModuleCreateInfo = 16,
    VkPipelineCacheCreateInfo = 17,
    VkPipelineShaderStageCreateInfo = 18,
    VkPipelineVertexInputStateCreateInfo = 19,
    VkPipelineInputAssemblyStateCreateInfo = 20,
    VkPipelineTessellationStateCreateInfo = 21,
    VkPipelineViewportStateCreateInfo = 22,
    VkPipelineRasterizationStateCreateInfo = 23,
    VkPipelineMultisampleStateCreateInfo = 24,
    VkPipelineDepthStencilStateCreateInfo = 25,
    VkPipelineColorBlendStateCreateInfo = 26,
    VkPipelineDynamicStateCreateInfo = 27,
    VkGraphicsPipelineCreateInfo = 28,
    VkComputePipelineCreateInfo = 29,
    VkPipelineLayoutCreateInfo = 30,
    VkSamplerCreateInfo = 31,
    VkDescriptorSetLayoutCreateInfo = 32,
    VkDescriptorPoolCreateInfo = 33,
    VkDescriptorSetAllocateInfo = 34,
    VkWriteDescriptorSet = 35,
    VkCopyDescriptorSet = 36,
    VkFramebufferCreateInfo = 37,
    VkRenderPassCreateInfo = 38,
    VkCommandPoolCreateInfo = 39,
    VkCommandBufferAllocateInfo = 40,
    VkCommandBufferInheritanceInfo = 41,
    VkCommandBufferBeginInfo = 42,
    VkRenderPassBeginInfo = 43,
    VkBufferMemoryBarrier = 44,
    VkImageMemoryBarrier = 45,
    VkMemoryBarrier = 46,
    VkLoaderInstanceCreateInfo = 47,
    VkLoaderDeviceCreateInfo = 48,
    VkSwapchainCreateInfoKHR = 1000001000,
    VkPresentInfoKHR = 1000001001,
    VkLayerSettingsCreateInfoEXT = 1000496000,
};

pub const VkPhysicalDeviceType = enum(c_int) {
    other = 0,
    integrated_gpu = 1,
    discrete_gpu = 2,
    virtual_gpu = 3,
    cpu = 4,
};

pub const VkBool32 = enum(u32) {
    false = 0,
    true = 1,
    
    pub fn from(v: bool) VkBool32 {
        return if (v) .true else .false;
    }
    
    pub fn to_bool(v: VkBool32) bool {
        return switch (v) {
            .false => false,
            .true => true,
        };
    }
};

pub const VkFormat = enum(c_int) {
    undefined = 0,
    r4g4_unorm_pack8 = 1,
    r4g4b4a4_unorm_pack16 = 2,
    b4g4r4a4_unorm_pack16 = 3,
    r5g6b5_unorm_pack16 = 4,
    b5g6r5_unorm_pack16 = 5,
    r5g5b5a1_unorm_pack16 = 6,
    b5g5r5a1_unorm_pack16 = 7,
    a1r5g5b5_unorm_pack16 = 8,
    r8_unorm = 9,
    r8_snorm = 10,
    r8_uscaled = 11,
    r8_sscaled = 12,
    r8_uint = 13,
    r8_sint = 14,
    r8_srgb = 15,
    r8g8_unorm = 16,
    r8g8_snorm = 17,
    r8g8_uscaled = 18,
    r8g8_sscaled = 19,
    r8g8_uint = 20,
    r8g8_sint = 21,
    r8g8_srgb = 22,
    r8g8b8_unorm = 23,
    r8g8b8_snorm = 24,
    r8g8b8_uscaled = 25,
    r8g8b8_sscaled = 26,
    r8g8b8_uint = 27,
    r8g8b8_sint = 28,
    r8g8b8_srgb = 29,
    b8g8r8_unorm = 30,
    b8g8r8_snorm = 31,
    b8g8r8_uscaled = 32,
    b8g8r8_sscaled = 33,
    b8g8r8_uint = 34,
    b8g8r8_sint = 35,
    b8g8r8_srgb = 36,
    r8g8b8a8_unorm = 37,
    r8g8b8a8_snorm = 38,
    r8g8b8a8_uscaled = 39,
    r8g8b8a8_sscaled = 40,
    r8g8b8a8_uint = 41,
    r8g8b8a8_sint = 42,
    r8g8b8a8_srgb = 43,
    b8g8r8a8_unorm = 44,
    b8g8r8a8_snorm = 45,
    b8g8r8a8_uscaled = 46,
    b8g8r8a8_sscaled = 47,
    b8g8r8a8_uint = 48,
    b8g8r8a8_sint = 49,
    b8g8r8a8_srgb = 50,
    a8b8g8r8_unorm_pack32 = 51,
    a8b8g8r8_snorm_pack32 = 52,
    a8b8g8r8_uscaled_pack32 = 53,
    a8b8g8r8_sscaled_pack32 = 54,
    a8b8g8r8_uint_pack32 = 55,
    a8b8g8r8_sint_pack32 = 56,
    a8b8g8r8_srgb_pack32 = 57,
    a2r10g10b10_unorm_pack32 = 58,
    a2r10g10b10_snorm_pack32 = 59,
    a2r10g10b10_uscaled_pack32 = 60,
    a2r10g10b10_sscaled_pack32 = 61,
    a2r10g10b10_uint_pack32 = 62,
    a2r10g10b10_sint_pack32 = 63,
    a2b10g10r10_unorm_pack32 = 64,
    a2b10g10r10_snorm_pack32 = 65,
    a2b10g10r10_uscaled_pack32 = 66,
    a2b10g10r10_sscaled_pack32 = 67,
    a2b10g10r10_uint_pack32 = 68,
    a2b10g10r10_sint_pack32 = 69,
    r16_unorm = 70,
    r16_snorm = 71,
    r16_uscaled = 72,
    r16_sscaled = 73,
    r16_uint = 74,
    r16_sint = 75,
    r16_sfloat = 76,
    r16g16_unorm = 77,
    r16g16_snorm = 78,
    r16g16_uscaled = 79,
    r16g16_sscaled = 80,
    r16g16_uint = 81,
    r16g16_sint = 82,
    r16g16_sfloat = 83,
    r16g16b16_unorm = 84,
    r16g16b16_snorm = 85,
    r16g16b16_uscaled = 86,
    r16g16b16_sscaled = 87,
    r16g16b16_uint = 88,
    r16g16b16_sint = 89,
    r16g16b16_sfloat = 90,
    r16g16b16a16_unorm = 91,
    r16g16b16a16_snorm = 92,
    r16g16b16a16_uscaled = 93,
    r16g16b16a16_sscaled = 94,
    r16g16b16a16_uint = 95,
    r16g16b16a16_sint = 96,
    r16g16b16a16_sfloat = 97,
    r32_uint = 98,
    r32_sint = 99,
    r32_sfloat = 100,
    r32g32_uint = 101,
    r32g32_sint = 102,
    r32g32_sfloat = 103,
    r32g32b32_uint = 104,
    r32g32b32_sint = 105,
    r32g32b32_sfloat = 106,
    r32g32b32a32_uint = 107,
    r32g32b32a32_sint = 108,
    r32g32b32a32_sfloat = 109,
    r64_uint = 110,
    r64_sint = 111,
    r64_sfloat = 112,
    r64g64_uint = 113,
    r64g64_sint = 114,
    r64g64_sfloat = 115,
    r64g64b64_uint = 116,
    r64g64b64_sint = 117,
    r64g64b64_sfloat = 118,
    r64g64b64a64_uint = 119,
    r64g64b64a64_sint = 120,
    r64g64b64a64_sfloat = 121,
    b10g11r11_ufloat_pack32 = 122,
    e5b9g9r9_ufloat_pack32 = 123,
    d16_unorm = 124,
    x8_d24_unorm_pack32 = 125,
    d32_sfloat = 126,
    s8_uint = 127,
    d16_unorm_s8_uint = 128,
    d24_unorm_s8_uint = 129,
    d32_sfloat_s8_uint = 130,
    bc1_rgb_unorm_block = 131,
    bc1_rgb_srgb_block = 132,
    bc1_rgba_unorm_block = 133,
    bc1_rgba_srgb_block = 134,
    bc2_unorm_block = 135,
    bc2_srgb_block = 136,
    bc3_unorm_block = 137,
    bc3_srgb_block = 138,
    bc4_unorm_block = 139,
    bc4_snorm_block = 140,
    bc5_unorm_block = 141,
    bc5_snorm_block = 142,
    bc6h_ufloat_block = 143,
    bc6h_sfloat_block = 144,
    bc7_unorm_block = 145,
    bc7_srgb_block = 146,
    etc2_r8g8b8_unorm_block = 147,
    etc2_r8g8b8_srgb_block = 148,
    etc2_r8g8b8a1_unorm_block = 149,
    etc2_r8g8b8a1_srgb_block = 150,
    etc2_r8g8b8a8_unorm_block = 151,
    etc2_r8g8b8a8_srgb_block = 152,
    eac_r11_unorm_block = 153,
    eac_r11_snorm_block = 154,
    eac_r11g11_unorm_block = 155,
    eac_r11g11_snorm_block = 156,
    astc_4x4_unorm_block = 157,
    astc_4x4_srgb_block = 158,
    astc_5x4_unorm_block = 159,
    astc_5x4_srgb_block = 160,
    astc_5x5_unorm_block = 161,
    astc_5x5_srgb_block = 162,
    astc_6x5_unorm_block = 163,
    astc_6x5_srgb_block = 164,
    astc_6x6_unorm_block = 165,
    astc_6x6_srgb_block = 166,
    astc_8x5_unorm_block = 167,
    astc_8x5_srgb_block = 168,
    astc_8x6_unorm_block = 169,
    astc_8x6_srgb_block = 170,
    astc_8x8_unorm_block = 171,
    astc_8x8_srgb_block = 172,
    astc_10x5_unorm_block = 173,
    astc_10x5_srgb_block = 174,
    astc_10x6_unorm_block = 175,
    astc_10x6_srgb_block = 176,
    astc_10x8_unorm_block = 177,
    astc_10x8_srgb_block = 178,
    astc_10x10_unorm_block = 179,
    astc_10x10_srgb_block = 180,
    astc_12x10_unorm_block = 181,
    astc_12x10_srgb_block = 182,
    astc_12x12_unorm_block = 183,
    astc_12x12_srgb_block = 184,
};

pub const VkColorSpaceKHR = enum(c_int) {
    srgb_nonlinear = 0,
    display_p3_nonlinear = 1000104001,
    extended_srgb_linear = 1000104002,
    display_p3_linear = 1000104003,
    dci_p3_nonlinear = 1000104004,
    bt709_linear = 1000104005,
    bt709_nonlinear = 1000104006,
    bt2020_linear = 1000104007,
    hdr10_st2084 = 1000104008,
    dolbyvision = 1000104009,
    hdr10_hlg = 1000104010,
    adobergb_linear = 1000104011,
    adobergb_nonlinear = 1000104012,
    pass_through = 1000104013,
    extended_srgb_nonlinear = 1000104014,
    display_native = 1000213000,
};

pub const VkPresentModeKHR = enum(c_int) {
    immediate = 0,
    mailbox = 1,
    fifo = 2,
    fifo_relaxed = 3,
};

pub const VkSharingMode = enum(c_int) {
    exclusive = 0,
    concurrent = 1,
};

pub const VkImageViewType = enum(c_int) {
    type_1d = 0,
    type_2d = 1,
    type_3d = 2,
    type_cube = 3,
    type_1d_array = 4,
    type_2d_array = 5,
    type_cube_array = 6,
};

pub const VkComponentSwizzle = enum(c_int) {
    identity = 0,
    zero = 1,
    one = 2,
    r = 3,
    g = 4,
    b = 5,
    a = 6,
};

pub const VkAttachmentLoadOp = enum(c_int) {
    load = 0,
    clear = 1,
    dont_care = 2,
};

pub const VkAttachmentStoreOp = enum(c_int) {
    store = 0,
    dont_care = 1,
};

pub const VkImageLayout = enum(c_int) {
    undefined = 0,
    general = 1,
    color_attachment_optimal = 2,
    depth_stencil_attachment_optimal = 3,
    depth_stencil_read_only_optimal = 4,
    shader_read_only_optimal = 5,
    transfer_src_optimal = 6,
    transfer_dst_optimal = 7,
    preinitialized = 8,
    present_src = 1000001002,
};

pub const VkPipelineBindPoint = enum(c_int) {
    graphics = 0,
    compute = 1,
};

pub const VkVertexInputRate = enum(c_int) {
    vertex = 0,
    instance = 1,
};

pub const VkPrimitiveTopology = enum(c_int) {
    point_list = 0,
    line_list = 1,
    line_strip = 2,
    triangle_list = 3,
    triangle_strip = 4,
    triangle_fan = 5,
    line_list_with_adjacency = 6,
    line_strip_with_adjacency = 7,
    triangle_list_with_adjacency = 8,
    triangle_strip_with_adjacency = 9,
    patch_list = 10,
};

pub const VkPolygonMode = enum(c_int) {
    fill = 0,
    line = 1,
    point = 2,
};

pub const VkFrontFace = enum(c_int) {
    counter_clockwise = 0,
    clockwise = 1,
};

pub const VkCompareOp = enum(c_int) {
    never = 0,
    less = 1,
    equal = 2,
    less_or_equal = 3,
    greater = 4,
    not_equal = 5,
    greater_or_equal = 6,
    always = 7,
};

pub const VkStencilOp = enum(c_int) {
    keep = 0,
    zero = 1,
    replace = 2,
    increment_and_clamp = 3,
    decrement_and_clamp = 4,
    invert = 5,
    increment_and_wrap = 6,
    decrement_and_wrap = 7,
};

pub const VkLogicOp = enum(c_int) {
    clear = 0,
    l_and = 1,
    and_reverse = 2,
    copy = 3,
    and_inverted = 4,
    no_op = 5,
    xor = 6,
    l_or = 7,
    nor = 8,
    equivalent = 9,
    invert = 10,
    or_reverse = 11,
    copy_inverted = 12,
    or_inverted = 13,
    nand = 14,
    set = 15,
};

pub const VkBlendFactor = enum(c_int) {
    zero = 0,
    one = 1,
    src_color = 2,
    one_minus_src_color = 3,
    dst_color = 4,
    one_minus_dst_color = 5,
    src_alpha = 6,
    one_minus_src_alpha = 7,
    dst_alpha = 8,
    one_minus_dst_alpha = 9,
    constant_color = 10,
    one_minus_constant_color = 11,
    constant_alpha = 12,
    one_minus_constant_alpha = 13,
    src_alpha_saturate = 14,
    src1_color = 15,
    one_minus_src1_color = 16,
    src1_alpha = 17,
    one_minus_src1_alpha = 18,
};

pub const VkBlendOp = enum(c_int) {
    add = 0,
    subtract = 1,
    reverse_subtract = 2,
    min = 3,
    max = 4,
};

pub const VkDynamicState = enum(c_int) {
    viewport = 0,
    scissor = 1,
    line_width = 2,
    depth_bias = 3,
    blend_constants = 4,
    depth_bounds = 5,
    stencil_compare_mask = 6,
    stencil_write_mask = 7,
    stencil_reference = 8,
};

pub const VkCommandBufferLevel = enum(c_int) {
    primary = 0,
    secondary = 1,
};

pub const VkSubpassContents = enum(c_int) {
    content_inline = 0,
    secondary_command_buffers = 1,
};

pub const VkIndexType = enum(c_int) {
    uint16 = 0,
    uint32 = 1,
};

pub const VkImageType = enum(c_int) {
    dim_1d = 0,
    dim_2d = 1,
    dim_3d = 2,
};

pub const VkImageTiling = enum(c_int) {
    optimal = 0,
    linear = 1,
};

pub const VkDescriptorType = enum(c_int) {
    sampler = 0,
    combined_image_sampler = 1,
    sampled_image = 2,
    storage_image = 3,
    uniform_texel_buffer = 4,
    storage_texel_buffer = 5,
    uniform_buffer = 6,
    storage_buffer = 7,
    uniform_buffer_dynamic = 8,
    storage_buffer_dynamic = 9,
    input_attachment = 10,
};

pub const VkLayerSettingTypeEXT = enum(c_int) {
    bool32 = 0,
    int32 = 1,
    int64 = 2,
    uint32 = 3,
    uint64 = 4,
    float32 = 5,
    float64 = 6,
    string = 7,
};


//////// FLAGS

pub fn VkFlagsOption(Options: type) type {
    const fields = @typeInfo(Options).@"enum".fields;
    var type_fields: [fields.len]std.builtin.Type.EnumField = undefined;
    for (fields, &type_fields, 0..) |field, *type_field, i| {
        type_field.* = .{
            .name = field.name,
            .value = 1 << i,
        };
    }
    
    const typeinfo = std.builtin.Type {
        .@"enum" = .{
            .tag_type = u32,
            .is_exhaustive = true,
            .decls = &.{},
            .fields = &type_fields,
        }
    };
    return @Type(typeinfo);
}

pub fn VkFlags(Option: type) type {
    return extern struct {
        const Flags = @This();
        value: u32,
        
        pub fn empty() Flags {
            return .{
                .value = 0,
            };
        }
        
        pub fn add(f: Flags, option: Option) Flags {
            return .{
                .value = f.value | @intFromEnum(option),
            };
        }
        
        pub fn remove(f: Flags, option: Option) Flags {
            return .{
                .value = f.value & ~@intFromEnum(option),
            };
        }
        
        pub fn just(option: Option) Flags {
            return .{
                .value = @intFromEnum(option),
            };
        }
        
        pub fn combine(f1: Flags, f2: Flags) Flags {
            return .{
                .value = f1.value | f2.value,
            };
        }
        
        pub fn create(options: []const Option) Flags {
            var value: u32 = 0;
            for (options) |option| {
                value |= @intFromEnum(option);
            }
            return .{.value = value};
        }
        
        pub fn has(f: Flags, option: Option) bool {
            return (f.value & @intFromEnum(option)) != 0;
        }
        
        pub fn debug_print(f: Flags, stream: anytype) void {
            u.byte_writer.validate(stream);
            var count: usize = 0;
            const fields = @typeInfo(Option).@"enum".fields;
            inline for (fields) |field| {
                const name = field.name;
                if (f.has(@field(Option, name))) {
                    if (count != 0) {
                        stream.write_slice(" + ");
                    }
                    stream.write_slice(name);
                    count += 1;
                }
            }
            
            if (count == 0) {
                stream.write_slice("(empty)");
            }
        }
        
        pub fn select_best(f: Flags, order: []const Option) Option {
            for (order) |option| {
                if (f.has(option)) {
                    return option;
                }
            }
            @panic("No suitable option found");
        }
    };
}


pub const VkInstanceCreateFlagBits = VkFlagsOption(enum {});
pub const VkInstanceCreateFlags = VkFlags(VkInstanceCreateFlagBits);

pub const VkDeviceCreateFlagBits = VkFlagsOption(enum {});
pub const VkDeviceCreateFlags = VkFlags(VkDeviceCreateFlagBits);

pub const VkDeviceQueueCreateFlagBits = VkFlagsOption(enum {});
pub const VkDeviceQueueCreateFlags = VkFlags(VkDeviceQueueCreateFlagBits);

pub const VkSampleCountFlagBits = VkFlagsOption(enum {
    sample_1,
    sample_2,
    sample_4,
    sample_8,
    sample_16,
    sample_32,
    sample_64,
});
pub const VkSampleCountFlags = VkFlags(VkSampleCountFlagBits);

pub const VkQueueFlagBits = VkFlagsOption(enum {
    graphics,
    compute,
    transfer,
    sparse_binding,
});
pub const VkQueueFlags = VkFlags(VkQueueFlagBits);

pub const VkSurfaceTransformFlagBitsKHR = VkFlagsOption(enum {
    identity,
    rotate_90,
    rotate_180,
    rotate_270,
    horizontal_mirror,
    horizontal_mirror_rotate_90,
    horizontal_mirror_rotate_180,
    horizontal_mirror_rotate_270,
    inherit,
});
pub const VkSurfaceTransformFlagsKHR = VkFlags(VkSurfaceTransformFlagBitsKHR);

pub const VkCompositeAlphaFlagBitsKHR = VkFlagsOption(enum {
    fully_opaque,
    pre_multiplied,
    post_multiplied,
    inherit,
});
pub const VkCompositeAlphaFlagsKHR = VkFlags(VkCompositeAlphaFlagBitsKHR);

pub const VkImageUsageFlagBits = VkFlagsOption(enum {
    transfer_src,
    transfer_dst,
    sampled,
    storage,
    color_attachment,
    depth_stencil_attachment,
    transient_attachment,
    input_attachment,
});
pub const VkImageUsageFlags = VkFlags(VkImageUsageFlagBits);

pub const VkSwapchainCreateFlagBitsKHR = VkFlagsOption(enum {});
pub const VkSwapchainCreateFlagsKHR = VkFlags(VkSwapchainCreateFlagBitsKHR);

pub const VkImageViewCreateFlagBits = VkFlagsOption(enum {});
pub const VkImageViewCreateFlags = VkFlags(VkImageViewCreateFlagBits);

pub const VkImageAspectFlagBits = VkFlagsOption(enum {
    color,
    depth,
    stencil,
    metadata,
});
pub const VkImageAspectFlags = VkFlags(VkImageAspectFlagBits);

pub const VkShaderModuleCreateFlagBits = VkFlagsOption(enum {});
pub const VkShaderModuleCreateFlags = VkFlags(VkShaderModuleCreateFlagBits);

pub const VkRenderPassCreateFlagBits = VkFlagsOption(enum {});
pub const VkRenderPassCreateFlags = VkFlags(VkRenderPassCreateFlagBits);

pub const VkAttachmentDescriptionFlagBits = VkFlagsOption(enum {
    may_alias,
});
pub const VkAttachmentDescriptionFlags = VkFlags(VkAttachmentDescriptionFlagBits);

pub const VkSubpassDescriptionFlagBits = VkFlagsOption(enum {});
pub const VkSubpassDescriptionFlags = VkFlags(VkSubpassDescriptionFlagBits);

pub const VkPipelineStageFlagBits = VkFlagsOption(enum {
    top_of_pipe,
    draw_indirect,
    vertex_input,
    vertex_shader,
    tessellation_control_shader,
    tessellation_evaluation_shader,
    geometry_shader,
    fragment_shader,
    early_fragment_tests,
    late_fragment_tests,
    color_attachment_output,
    compute_shader,
    transfer,
    bottom_of_pipe,
    host,
    all_graphics,
    all_compute,
});
pub const VkPipelineStageFlags = VkFlags(VkPipelineStageFlagBits);

pub const VkAccessFlagBits = VkFlagsOption(enum {
    indirect_command_read,
    index_read,
    vertex_attribute_read,
    uniform_read,
    input_attachment_read,
    shader_read,
    shader_write,
    color_attachment_read,
    color_attachment_write,
    depth_stencil_attachment_read,
    depth_stencil_attachment_write,
    transfer_read,
    transfer_write,
    host_read,
    host_write,
    memory_read,
    memory_write,
});
pub const VkAccessFlags = VkFlags(VkAccessFlagBits);

pub const VkDependencyFlagBits = VkFlagsOption(enum {
    by_region,
});
pub const VkDependencyFlags = VkFlags(VkDependencyFlagBits);

pub const VkPipelineLayoutCreateFlagBits = VkFlagsOption(enum {});
pub const VkPipelineLayoutCreateFlags = VkFlags(VkPipelineLayoutCreateFlagBits);

pub const VkShaderStageFlagBits = VkFlagsOption(enum {
    vertex,
    tessellation_control,
    tessellation_evaluation,
    geometry,
    fragment,
    compute,
});
pub const VkShaderStageFlags = VkFlags(VkShaderStageFlagBits);

pub const VkPipelineCreateFlagBits = VkFlagsOption(enum {
    disable_optimization,
    allow_derivatives,
    derivative,
});
pub const VkPipelineCreateFlags = VkFlags(VkPipelineCreateFlagBits);

pub const VkPipelineShaderStageCreateFlagBits = VkFlagsOption(enum {});
pub const VkPipelineShaderStageCreateFlags = VkFlags(VkPipelineShaderStageCreateFlagBits);

pub const VkPipelineVertexInputStateCreateFlagBits = VkFlagsOption(enum {});
pub const VkPipelineVertexInputStateCreateFlags = VkFlags(VkPipelineVertexInputStateCreateFlagBits);

pub const VkPipelineInputAssemblyStateCreateFlagBits = VkFlagsOption(enum {});
pub const VkPipelineInputAssemblyStateCreateFlags = VkFlags(VkPipelineInputAssemblyStateCreateFlagBits);

pub const VkPipelineTessellationStateCreateFlagBits = VkFlagsOption(enum {});
pub const VkPipelineTessellationStateCreateFlags = VkFlags(VkPipelineTessellationStateCreateFlagBits);

pub const VkPipelineViewportStateCreateFlagBits = VkFlagsOption(enum {});
pub const VkPipelineViewportStateCreateFlags = VkFlags(VkPipelineViewportStateCreateFlagBits);

pub const VkPipelineRasterizationStateCreateFlagBits = VkFlagsOption(enum {});
pub const VkPipelineRasterizationStateCreateFlags = VkFlags(VkPipelineRasterizationStateCreateFlagBits);

pub const VkPipelineMultisampleStateCreateFlagBits = VkFlagsOption(enum {});
pub const VkPipelineMultisampleStateCreateFlags = VkFlags(VkPipelineMultisampleStateCreateFlagBits);

pub const VkPipelineDepthStencilStateCreateFlagBits = VkFlagsOption(enum {});
pub const VkPipelineDepthStencilStateCreateFlags = VkFlags(VkPipelineDepthStencilStateCreateFlagBits);

pub const VkPipelineColorBlendStateCreateFlagBits = VkFlagsOption(enum {});
pub const VkPipelineColorBlendStateCreateFlags = VkFlags(VkPipelineColorBlendStateCreateFlagBits);

pub const VkPipelineDynamicStateCreateFlagBits = VkFlagsOption(enum {});
pub const VkPipelineDynamicStateCreateFlags = VkFlags(VkPipelineDynamicStateCreateFlagBits);

pub const VkCullModeFlagBits = VkFlagsOption(enum {
    front,
    back,
});
pub const VkCullModeFlags = VkFlags(VkCullModeFlagBits);

pub const VkColorComponentFlagBits = VkFlagsOption(enum {
    r,
    g,
    b,
    a,
});
pub const VkColorComponentFlags = VkFlags(VkColorComponentFlagBits);

pub const VkFramebufferCreateFlagBits = VkFlagsOption(enum {});
pub const VkFramebufferCreateFlags = VkFlags(VkFramebufferCreateFlagBits);

pub const VkCommandPoolCreateFlagBits = VkFlagsOption(enum {
    transient,
    reset_command_buffer,
});
pub const VkCommandPoolCreateFlags = VkFlags(VkCommandPoolCreateFlagBits);

pub const VkCommandBufferUsageFlagBits = VkFlagsOption(enum {
    one_time_submit,
    render_pass_continue,
    simultaneous_use,
});
pub const VkCommandBufferUsageFlags = VkFlags(VkCommandBufferUsageFlagBits);

pub const VkQueryControlFlagBits = VkFlagsOption(enum {
    precise,
});
pub const VkQueryControlFlags = VkFlags(VkQueryControlFlagBits);

pub const VkQueryPipelineStatisticFlagBits = VkFlagsOption(enum {
    input_assembly_vertices,
    input_assembly_primitives,
    vertex_shader_invocations,
    geometry_shader_invocations,
    geometry_shader_primitives,
    clipping_invocations,
    clipping_primitives,
    fragment_shader_invocations,
    tessellation_control_shader_patches,
    tessellation_evaluation_shader_invocations,
    compute_shader_invocations,
});
pub const VkQueryPipelineStatisticFlags = VkFlags(VkQueryPipelineStatisticFlagBits);

pub const VkSemaphoreCreateFlagBits = VkFlagsOption(enum {});
pub const VkSemaphoreCreateFlags = VkFlags(VkSemaphoreCreateFlagBits);

pub const VkFenceCreateFlagBits = VkFlagsOption(enum {
    signaled,
});
pub const VkFenceCreateFlags = VkFlags(VkFenceCreateFlagBits);

pub const VkMemoryPropertyFlagBits = VkFlagsOption(enum {
    device_local,
    host_visible,
    host_coherent,
    host_cached,
    lazily_allocated,
});
pub const VkMemoryPropertyFlags = VkFlags(VkMemoryPropertyFlagBits);

pub const VkMemoryHeapFlagBits = VkFlagsOption(enum {
    device_local,
});
pub const VkMemoryHeapFlags = VkFlags(VkMemoryHeapFlagBits);

pub const VkBufferCreateFlagBits = VkFlagsOption(enum {
    sparse_binding,
    sparse_residency,
    sparse_aliased,
});
pub const VkBufferCreateFlags = VkFlags(VkBufferCreateFlagBits);

pub const VkBufferUsageFlagBits = VkFlagsOption(enum {
    transfer_src,
    transfer_dst,
    uniform_texel_buffer,
    storage_texel_buffer,
    uniform_buffer,
    storage_buffer,
    index_buffer,
    vertex_buffer,
    indirect_buffer,
});
pub const VkBufferUsageFlags = VkFlags(VkBufferUsageFlagBits);

pub const VkMemoryMapFlagBits = VkFlagsOption(enum {});
pub const VkMemoryMapFlags = VkFlags(VkMemoryMapFlagBits);

pub const VkCommandBufferResetFlagBits = VkFlagsOption(enum {
    release_resources,
});
pub const VkCommandBufferResetFlags = VkFlags(VkCommandBufferResetFlagBits);

pub const VkImageCreateFlagBits = VkFlagsOption(enum {
    sparse_binding,
    sparse_residency,
    sparse_aliased,
    mutable_format,
    cube_compatible,
});
pub const VkImageCreateFlags = VkFlags(VkImageCreateFlagBits);

pub const VkDescriptorSetLayoutCreateFlagBits = VkFlagsOption(enum {});
pub const VkDescriptorSetLayoutCreateFlags = VkFlags(VkDescriptorSetLayoutCreateFlagBits);

pub const VkDescriptorPoolCreateFlagBits = VkFlagsOption(enum {
    free_descriptor_set,
});
pub const VkDescriptorPoolCreateFlags = VkFlags(VkDescriptorPoolCreateFlagBits);

pub const VkDescriptorPoolResetFlagBits = VkFlagsOption(enum {});
pub const VkDescriptorPoolResetFlags = VkFlags(VkDescriptorPoolResetFlagBits);


//////// UNIONS

pub const VkClearValue = extern union {
    color: VkClearColorValue,
    depthStencil: VkClearDepthStencilValue,
};

pub const VkClearColorValue = extern union {
    float32: [4]f32,
    int32: [4]i32,
    uint32: [4]u32,
};


//////// SIMPLE STRUCTS

pub const VkExtent2D = extern struct {
    width: u32,
    height: u32,
    
    pub fn debug_print(extent: VkExtent2D, stream: anytype) void {
        u.byte_writer.validate(stream);
        u.Int.create(extent.width).debug_print(stream);
        stream.write_slice("x");
        u.Int.create(extent.height).debug_print(stream);
    }
};

pub const VkExtent3D = extern struct {
    width: u32,
    height: u32,
    depth: u32,
    
    pub fn debug_print(extent: VkExtent3D, stream: anytype) void {
        u.byte_writer.validate(stream);
        u.Int.create(extent.width).debug_print(stream);
        stream.write_slice("x");
        u.Int.create(extent.height).debug_print(stream);
        stream.write_slice("x");
        u.Int.create(extent.depth).debug_print(stream);
    }
};

pub const VkOffset2D = extern struct {
    x: i32,
    y: i32,
    
    pub fn debug_print(offset: VkOffset2D, stream: anytype) void {
        u.byte_writer.validate(stream);
        u.Int.create(offset.x).debug_print(stream);
        stream.write_slice(",");
        u.Int.create(offset.y).debug_print(stream);
    }
};

pub const VkOffset3D = extern struct {
    x: i32,
    y: i32,
    z: i32,
    
    pub fn debug_print(offset: VkOffset3D, stream: anytype) void {
        u.byte_writer.validate(stream);
        u.Int.create(offset.x).debug_print(stream);
        stream.write_slice(",");
        u.Int.create(offset.y).debug_print(stream);
        stream.write_slice(",");
        u.Int.create(offset.z).debug_print(stream);
    }
};

pub const VkRect2D = extern struct {
    offset: VkOffset2D,
    extent: VkExtent2D,
    
    
    pub fn debug_print(rect: VkRect2D, stream: anytype) void {
        u.byte_writer.validate(stream);
        rect.offset.debug_print(stream);
        stream.write_slice(":");
        rect.extent.debug_print(stream);
    }
};


//////// STRUCTS

pub const VkExtensionProperties = extern struct {
    extensionName: [VK_MAX_EXTENSION_NAME_SIZE-1:0]u8,
    specVersion: u32,
};

pub const VkLayerProperties = extern struct {
    layerName: [VK_MAX_EXTENSION_NAME_SIZE-1:0]u8,
    specVersion: u32,
    implementationVersion: u32,
    description: [VK_MAX_DESCRIPTION_SIZE-1:0]u8,
};

pub const VkAllocationCallbacks = extern struct {
    pUserData: *anyopaque,
    pfnAllocation: *const fn(pUserData: *anyopaque, size: usize, alignment: usize, allocationScope: VkSystemAllocationScope) callconv(.c) ?*anyopaque,
    pfnReallocation: *const fn(pUserData: *anyopaque, pOriginal: *anyopaque, size: usize, alignment: usize, allocationScope: VkSystemAllocationScope) callconv(.c) ?*anyopaque,
    pfnFree: *const fn(pUserData: *anyopaque, pMemory: ?*anyopaque) callconv(.c) ?*anyopaque,
    pfnInternalAllocation: *const fn(pUserData: *anyopaque, size: usize, allocationType: VkInternalAllocationType, allocationScope: VkSystemAllocationScope) callconv(.c) ?*anyopaque,
    pfnInternalFree: *const fn(pUserData: *anyopaque, size: usize, allocationType: VkInternalAllocationType, allocationScope: VkSystemAllocationScope) callconv(.c) ?*anyopaque,
};

pub const VkPhysicalDeviceProperties = extern struct {
    apiVersion: u32,
    driverVersion: u32,
    vendorID: u32,
    deviceID: u32,
    deviceType: VkPhysicalDeviceType,
    deviceName: [VK_MAX_PHYSICAL_DEVICE_NAME_SIZE-1:0]u8,
    pipelineCacheUUID: [VK_UUID_SIZE]u8,
    limits: VkPhysicalDeviceLimits,
    sparseProperties: VkPhysicalDeviceSparseProperties,
};

pub const VkPhysicalDeviceLimits = extern struct {
    maxImageDimension1D: u32,
    maxImageDimension2D: u32,
    maxImageDimension3D: u32,
    maxImageDimensionCube: u32,
    maxImageArrayLayers: u32,
    maxTexelBufferElements: u32,
    maxUniformBufferRange: u32,
    maxStorageBufferRange: u32,
    maxPushConstantsSize: u32,
    maxMemoryAllocationCount: u32,
    maxSamplerAllocationCount: u32,
    bufferImageGranularity: VkDeviceSize,
    sparseAddressSpaceSize: VkDeviceSize,
    maxBoundDescriptorSets: u32,
    maxPerStageDescriptorSamplers: u32,
    maxPerStageDescriptorUniformBuffers: u32,
    maxPerStageDescriptorStorageBuffers: u32,
    maxPerStageDescriptorSampledImages: u32,
    maxPerStageDescriptorStorageImages: u32,
    maxPerStageDescriptorInputAttachments: u32,
    maxPerStageResources: u32,
    maxDescriptorSetSamplers: u32,
    maxDescriptorSetUniformBuffers: u32,
    maxDescriptorSetUniformBuffersDynamic: u32,
    maxDescriptorSetStorageBuffers: u32,
    maxDescriptorSetStorageBuffersDynamic: u32,
    maxDescriptorSetSampledImages: u32,
    maxDescriptorSetStorageImages: u32,
    maxDescriptorSetInputAttachments: u32,
    maxVertexInputAttributes: u32,
    maxVertexInputBindings: u32,
    maxVertexInputAttributeOffset: u32,
    maxVertexInputBindingStride: u32,
    maxVertexOutputComponents: u32,
    maxTessellationGenerationLevel: u32,
    maxTessellationPatchSize: u32,
    maxTessellationControlPerVertexInputComponents: u32,
    maxTessellationControlPerVertexOutputComponents: u32,
    maxTessellationControlPerPatchOutputComponents: u32,
    maxTessellationControlTotalOutputComponents: u32,
    maxTessellationEvaluationInputComponents: u32,
    maxTessellationEvaluationOutputComponents: u32,
    maxGeometryShaderInvocations: u32,
    maxGeometryInputComponents: u32,
    maxGeometryOutputComponents: u32,
    maxGeometryOutputVertices: u32,
    maxGeometryTotalOutputComponents: u32,
    maxFragmentInputComponents: u32,
    maxFragmentOutputAttachments: u32,
    maxFragmentDualSrcAttachments: u32,
    maxFragmentCombinedOutputResources: u32,
    maxComputeSharedMemorySize: u32,
    maxComputeWorkGroupCount: [3]u32,
    maxComputeWorkGroupInvocations: u32,
    maxComputeWorkGroupSize: [3]u32,
    subPixelPrecisionBits: u32,
    subTexelPrecisionBits: u32,
    mipmapPrecisionBits: u32,
    maxDrawIndexedIndexValue: u32,
    maxDrawIndirectCount: u32,
    maxSamplerLodBias: f32,
    maxSamplerAnisotropy: f32,
    maxViewports: u32,
    maxViewportDimensions: [2]u32,
    viewportBoundsRange: [2]f32,
    viewportSubPixelBits: u32,
    minMemoryMapAlignment: usize,
    minTexelBufferOffsetAlignment: VkDeviceSize,
    minUniformBufferOffsetAlignment: VkDeviceSize,
    minStorageBufferOffsetAlignment: VkDeviceSize,
    minTexelOffset: i32,
    maxTexelOffset: u32,
    minTexelGatherOffset: i32,
    maxTexelGatherOffset: u32,
    minInterpolationOffset: f32,
    maxInterpolationOffset: f32,
    subPixelInterpolationOffsetBits: u32,
    maxFramebufferWidth: u32,
    maxFramebufferHeight: u32,
    maxFramebufferLayers: u32,
    framebufferColorSampleCounts: VkSampleCountFlags,
    framebufferDepthSampleCounts: VkSampleCountFlags,
    framebufferStencilSampleCounts: VkSampleCountFlags,
    framebufferNoAttachmentsSampleCounts: VkSampleCountFlags,
    maxColorAttachments: u32,
    sampledImageColorSampleCounts: VkSampleCountFlags,
    sampledImageIntegerSampleCounts: VkSampleCountFlags,
    sampledImageDepthSampleCounts: VkSampleCountFlags,
    sampledImageStencilSampleCounts: VkSampleCountFlags,
    storageImageSampleCounts: VkSampleCountFlags,
    maxSampleMaskWords: u32,
    timestampComputeAndGraphics: VkBool32,
    timestampPeriod: f32,
    maxClipDistances: u32,
    maxCullDistances: u32,
    maxCombinedClipAndCullDistances: u32,
    discreteQueuePriorities: u32,
    pointSizeRange: [2]f32,
    lineWidthRange: [2]f32,
    pointSizeGranularity: f32,
    lineWidthGranularity: f32,
    strictLines: VkBool32,
    standardSampleLocations: VkBool32,
    optimalBufferCopyOffsetAlignment: u32,
    optimalBufferCopyRowPitchAlignment: u32,
    nonCoherentAtomSize: u32,
};

pub const VkPhysicalDeviceSparseProperties = extern struct {
    residencyStandard2DBlockShape: VkBool32,
    residencyStandard2DMultisampleBlockShape: VkBool32,
    residencyStandard3DBlockShape: VkBool32,
    residencyAlignedMipSize: VkBool32,
    residencyNonResidentStrict: VkBool32,
};

pub const VkQueueFamilyProperties = extern struct {
    queueFlags: VkQueueFlags,
    queueCount: u32,
    timestampValidBits: u32,
    minImageTransferGranularity: VkExtent3D,
};

pub const VkPhysicalDeviceFeatures = extern struct {
    robustBufferAccess: VkBool32,
    fullDrawIndexUint32: VkBool32,
    imageCubeArray: VkBool32,
    independentBlend: VkBool32,
    geometryShader: VkBool32,
    tessellationShader: VkBool32,
    sampleRateShading: VkBool32,
    dualSrcBlend: VkBool32,
    logicOp: VkBool32,
    multiDrawIndirect: VkBool32,
    drawIndirectFirstInstance: VkBool32,
    depthClamp: VkBool32,
    depthBiasClamp: VkBool32,
    fillModeNonSolid: VkBool32,
    depthBounds: VkBool32,
    wideLines: VkBool32,
    largePoints: VkBool32,
    alphaToOne: VkBool32,
    multiViewport: VkBool32,
    samplerAnisotropy: VkBool32,
    textureCompressionETC2: VkBool32,
    textureCompressionASTC_LDR: VkBool32,
    textureCompressionBC: VkBool32,
    occlusionQueryPrecise: VkBool32,
    pipelineStatisticsQuery: VkBool32,
    vertexPipelineStoresAndAtomics: VkBool32,
    fragmentStoresAndAtomics: VkBool32,
    shaderTessellationAndGeometryPointSize: VkBool32,
    shaderImageGatherExtended: VkBool32,
    shaderStorageImageExtendedFormats: VkBool32,
    shaderStorageImageMultisample: VkBool32,
    shaderStorageImageReadWithoutFormat: VkBool32,
    shaderStorageImageWriteWithoutFormat: VkBool32,
    shaderUniformBufferArrayDynamicIndexing: VkBool32,
    shaderSampledImageArrayDynamicIndexing: VkBool32,
    shaderStorageBufferArrayDynamicIndexing: VkBool32,
    shaderStorageImageArrayDynamicIndexing: VkBool32,
    shaderClipDistance: VkBool32,
    shaderCullDistance: VkBool32,
    shaderFloat64: VkBool32,
    shaderInt64: VkBool32,
    shaderInt16: VkBool32,
    shaderResourceResidency: VkBool32,
    shaderResourceMinLod: VkBool32,
    sparseBinding: VkBool32,
    sparseResidencyBuffer: VkBool32,
    sparseResidencyImage2D: VkBool32,
    sparseResidencyImage3D: VkBool32,
    sparseResidency2Samples: VkBool32,
    sparseResidency4Samples: VkBool32,
    sparseResidency8Samples: VkBool32,
    sparseResidency16Samples: VkBool32,
    sparseResidencyAliased: VkBool32,
    variableMultisampleRate: VkBool32,
    inheritedQueries: VkBool32,
};

pub const VkSurfaceCapabilitiesKHR = extern struct {
    minImageCount: u32,
    maxImageCount: u32,
    currentExtent: VkExtent2D,
    minImageExtent: VkExtent2D,
    maxImageExtent: VkExtent2D,
    maxImageArrayLayers: u32,
    supportedTransforms: VkSurfaceTransformFlagsKHR,
    currentTransform: VkSurfaceTransformFlagBitsKHR,
    supportedCompositeAlpha: VkCompositeAlphaFlagsKHR,
    supportedUsageFlags: VkImageUsageFlags,
};

pub const VkSurfaceFormatKHR = extern struct {
    format: VkFormat,
    colorSpace: VkColorSpaceKHR,
};

pub const VkComponentMapping = extern struct {
    r: VkComponentSwizzle,
    g: VkComponentSwizzle,
    b: VkComponentSwizzle,
    a: VkComponentSwizzle,
};

pub const VkImageSubresourceRange = extern struct {
    aspectMask: VkImageAspectFlags,
    baseMipLevel: u32,
    levelCount: u32,
    baseArrayLayer: u32,
    layerCount: u32,
};

pub const VkAttachmentDescription = extern struct {
    flags: VkAttachmentDescriptionFlags,
    format: VkFormat,
    samples: VkSampleCountFlagBits,
    loadOp: VkAttachmentLoadOp,
    storeOp: VkAttachmentStoreOp,
    stencilLoadOp: VkAttachmentLoadOp,
    stencilStoreOp: VkAttachmentStoreOp,
    initialLayout: VkImageLayout,
    finalLayout: VkImageLayout,
};

pub const VkSubpassDescription = extern struct {
    flags: VkSubpassDescriptionFlags,
    pipelineBindPoint: VkPipelineBindPoint,
    inputAttachmentCount: u32,
    pInputAttachments: [*]const VkAttachmentReference,
    colorAttachmentCount: u32,
    pColorAttachments: [*]const VkAttachmentReference,
    pResolveAttachments: ?[*]const VkAttachmentReference,
    pDepthStencilAttachment: ?[*]const VkAttachmentReference,
    preserveAttachmentCount: u32,
    pPreserveAttachments: [*]const u32,
};

pub const VkAttachmentReference = extern struct {
    attachment: u32,
    layout: VkImageLayout,
};

pub const VkSubpassDependency = extern struct {
    srcSubpass: u32,
    dstSubpass: u32,
    srcStageMask: VkPipelineStageFlags,
    dstStageMask: VkPipelineStageFlags,
    srcAccessMask: VkAccessFlags,
    dstAccessMask: VkAccessFlags,
    dependencyFlags: VkDependencyFlags,
};

pub const VkPushConstantRange = extern struct {
    stageFlags: VkShaderStageFlags,
    offset: u32,
    size: u32,
};

pub const VkSpecializationInfo = extern struct {
    mapEntryCount: u32,
    pMapEntries: [*]const VkSpecializationMapEntry,
    dataSize: usize,
    pData: [*]const u8,
};

pub const VkSpecializationMapEntry = extern struct {
    constantID: u32,
    offset: u32,
    size: usize,
};

pub const VkVertexInputBindingDescription = extern struct {
    binding: u32,
    stride: u32,
    inputRate: VkVertexInputRate,
};

pub const VkVertexInputAttributeDescription = extern struct {
    location: u32,
    binding: u32,
    format: VkFormat,
    offset: u32,
};

pub const VkViewport = extern struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    minDepth: f32,
    maxDepth: f32,
};

pub const VkStencilOpState = extern struct {
    failOp: VkStencilOp,
    passOp: VkStencilOp,
    depthFailOp: VkStencilOp,
    compareOp: VkCompareOp,
    compareMask: u32,
    writeMask: u32,
    reference: u32,
};

pub const VkPipelineColorBlendAttachmentState = extern struct {
    blendEnable: VkBool32,
    srcColorBlendFactor: VkBlendFactor,
    dstColorBlendFactor: VkBlendFactor,
    colorBlendOp: VkBlendOp,
    srcAlphaBlendFactor: VkBlendFactor,
    dstAlphaBlendFactor: VkBlendFactor,
    alphaBlendOp: VkBlendOp,
    colorWriteMask: VkColorComponentFlags,
};

pub const VkClearDepthStencilValue = extern struct {
    depth: f32,
    stencil: u32,
};

pub const VkDrawIndirectCommand = extern struct {
    vertexCount: u32,
    instanceCount: u32,
    firstVertex: u32,
    firstInstance: u32,
};

pub const VkDrawIndexedIndirectCommand = extern struct {
    indexCount: u32,
    instanceCount: u32,
    firstIndex: u32,
    vertexOffset: i32,
    firstInstance: u32,
};

pub const VkPhysicalDeviceMemoryProperties = extern struct {
    memoryTypeCount: u32,
    memoryTypes: [VK_MAX_MEMORY_TYPES]VkMemoryType,
    memoryHeapCount: u32,
    memoryHeaps: [VK_MAX_MEMORY_HEAPS]VkMemoryHeap,
};

pub const VkMemoryType = extern struct {
    propertyFlags: VkMemoryPropertyFlags,
    heapIndex: u32,
};

pub const VkMemoryHeap = extern struct {
    size: VkDeviceSize,
    flags: VkMemoryHeapFlags,
};

pub const VkMemoryRequirements = extern struct {
    size: VkDeviceSize,
    alignment: VkDeviceSize,
    memoryTypeBits: u32,
};

pub const VkBufferCopy = extern struct {
    srcOffset: VkDeviceSize,
    dstOffset: VkDeviceSize,
    size: VkDeviceSize,
};

pub const VkBufferImageCopy = extern struct {
    bufferOffset: VkDeviceSize,
    bufferRowLength: u32,
    bufferImageHeight: u32,
    imageSubresource: VkImageSubresourceLayers,
    imageOffset: VkOffset3D,
    imageExtent: VkExtent3D,
};

pub const VkImageSubresourceLayers = extern struct {
    aspectMask: VkImageAspectFlags,
    mipLevel: u32,
    baseArrayLayer: u32,
    layerCount: u32,
};

pub const VkDescriptorSetLayoutBinding = extern struct {
    binding: u32,
    descriptorType: VkDescriptorType,
    descriptorCount: u32,
    stageFlags: VkShaderStageFlags,
    pImmutableSamplers: ?[*]const VkSampler,
};

pub const VkDescriptorPoolSize = extern struct {
    type: VkDescriptorType,
    descriptorCount: u32,
};

pub const VkDescriptorImageInfo = extern struct {
    sampler: VkSampler,
    imageView: VkImageView,
    imageLayout: VkImageLayout,
};

pub const VkDescriptorBufferInfo = extern struct {
    buffer: VkBuffer,
    offset: VkDeviceSize,
    range: VkDeviceSize,
};

pub const VkLayerSettingEXT = extern struct {
    pLayerName: [*]const u8,
    pSettingName: [*]const u8,
    type: VkLayerSettingTypeEXT,
    valueCount: u32,
    pValues: *const anyopaque,
};


//////// REGISTERED STRUCTS

pub const VkApplicationInfo = extern struct {
    sType: VkStructureType = .VkApplicationInfo,
    pNext: ?*const anyopaque = null,
    pApplicationName: ?[*:0]u8,
    applicationVersion: u32,
    pEngineName: ?[*:0]u8,
    engineVersion: u32,
    apiVersion: u32,
};

pub const VkInstanceCreateInfo = extern struct {
    sType: VkStructureType = .VkInstanceCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkInstanceCreateFlags = .empty(),
    pApplicationInfo: ?*const VkApplicationInfo,
    enabledLayerCount: u32,
    ppEnabledLayerNames: [*]const [*:0]const u8,
    enabledExtensionCount: u32,
    ppEnabledExtensionNames: [*]const [*:0]const u8,
};

pub const VkDeviceCreateInfo = extern struct {
    sType: VkStructureType = .VkDeviceCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkDeviceCreateFlags = .empty(),
    queueCreateInfoCount: u32,
    pQueueCreateInfos: [*]const VkDeviceQueueCreateInfo,
    enabledLayerCount: u32 = 0,
    ppEnabledLayerNames: [*]const [*:0]const u8 = undefined,
    enabledExtensionCount: u32,
    ppEnabledExtensionNames: [*]const [*:0]const u8,
    pEnabledFeatures: ?*const VkPhysicalDeviceFeatures,
};

pub const VkDeviceQueueCreateInfo = extern struct {
    sType: VkStructureType = .VkDeviceQueueCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkDeviceQueueCreateFlags = .empty(),
    queueFamilyIndex: u32,
    queueCount: u32,
    pQueuePriorities: [*]const f32,
};

pub const VkSwapchainCreateInfoKHR = extern struct {
    sType: VkStructureType = .VkSwapchainCreateInfoKHR,
    pNext: ?*const anyopaque = null,
    flags: VkSwapchainCreateFlagsKHR,
    surface: VkSurfaceKHR,
    minImageCount: u32,
    imageFormat: VkFormat,
    imageColorSpace: VkColorSpaceKHR,
    imageExtent: VkExtent2D,
    imageArrayLayers: u32,
    imageUsage: VkImageUsageFlags,
    imageSharingMode: VkSharingMode,
    queueFamilyIndexCount: u32,
    pQueueFamilyIndices: [*]u32,
    preTransform: VkSurfaceTransformFlagBitsKHR,
    compositeAlpha: VkCompositeAlphaFlagBitsKHR,
    presentMode: VkPresentModeKHR,
    clipped: VkBool32,
    oldSwapchain: VkSwapchainKHR,
};

pub const VkImageViewCreateInfo = extern struct {
    sType: VkStructureType = .VkImageViewCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkImageViewCreateFlags,
    image: VkImage,
    viewType: VkImageViewType,
    format: VkFormat,
    components: VkComponentMapping,
    subresourceRange: VkImageSubresourceRange,
};

pub const VkShaderModuleCreateInfo = extern struct {
    sType: VkStructureType = .VkShaderModuleCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkShaderModuleCreateFlags,
    codeSize: usize,
    pCode: [*]const u32,
};

pub const VkRenderPassCreateInfo = extern struct {
    sType: VkStructureType = .VkRenderPassCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkRenderPassCreateFlags,
    attachmentCount: u32,
    pAttachments: [*]const VkAttachmentDescription,
    subpassCount: u32,
    pSubpasses: [*]const VkSubpassDescription,
    dependencyCount: u32,
    pDependencies: [*]const VkSubpassDependency,
};

pub const VkPipelineLayoutCreateInfo = extern struct {
    sType: VkStructureType = .VkPipelineLayoutCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkPipelineLayoutCreateFlags,
    setLayoutCount: u32,
    pSetLayouts: [*]const VkDescriptorSetLayout,
    pushConstantRangeCount: u32,
    pPushConstantRanges: [*]const VkPushConstantRange,
};

pub const VkGraphicsPipelineCreateInfo = extern struct {
    sType: VkStructureType = .VkGraphicsPipelineCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkPipelineCreateFlags,
    stageCount: u32,
    pStages: [*]const VkPipelineShaderStageCreateInfo,
    pVertexInputState: ?*const VkPipelineVertexInputStateCreateInfo,
    pInputAssemblyState: ?*const VkPipelineInputAssemblyStateCreateInfo,
    pTessellationState: ?*const VkPipelineTessellationStateCreateInfo,
    pViewportState: ?*const VkPipelineViewportStateCreateInfo,
    pRasterizationState: ?*const VkPipelineRasterizationStateCreateInfo,
    pMultisampleState: ?*const VkPipelineMultisampleStateCreateInfo,
    pDepthStencilState: ?*const VkPipelineDepthStencilStateCreateInfo,
    pColorBlendState: ?*const VkPipelineColorBlendStateCreateInfo,
    pDynamicState: ?*const VkPipelineDynamicStateCreateInfo,
    layout: VkPipelineLayout,
    renderPass: VkRenderPass,
    subpass: u32,
    basePipelineHandle: VkPipeline,
    basePipelineIndex: u32,
};

pub const VkPipelineShaderStageCreateInfo = extern struct {
    sType: VkStructureType = .VkPipelineShaderStageCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkPipelineShaderStageCreateFlags,
    stage: VkShaderStageFlagBits,
    module: VkShaderModule,
    pName: [*:0]const u8,
    pSpecializationInfo: ?*const VkSpecializationInfo,
};

pub const VkPipelineVertexInputStateCreateInfo = extern struct {
    sType: VkStructureType = .VkPipelineVertexInputStateCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkPipelineVertexInputStateCreateFlags,
    vertexBindingDescriptionCount: u32,
    pVertexBindingDescriptions: [*]const VkVertexInputBindingDescription,
    vertexAttributeDescriptionCount: u32,
    pVertexAttributeDescriptions: [*]const VkVertexInputAttributeDescription,
};

pub const VkPipelineInputAssemblyStateCreateInfo = extern struct {
    sType: VkStructureType = .VkPipelineInputAssemblyStateCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkPipelineInputAssemblyStateCreateFlags,
    topology: VkPrimitiveTopology,
    primitiveRestartEnable: VkBool32,
};

pub const VkPipelineTessellationStateCreateInfo = extern struct {
    sType: VkStructureType = .VkPipelineTessellationStateCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkPipelineTessellationStateCreateFlags,
    patchControlPoints: u32,
};

pub const VkPipelineViewportStateCreateInfo = extern struct {
    sType: VkStructureType = .VkPipelineViewportStateCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkPipelineViewportStateCreateFlags,
    viewportCount: u32,
    pViewports: [*]const VkViewport,
    scissorCount: u32,
    pScissors: [*]const VkRect2D,
};

pub const VkPipelineRasterizationStateCreateInfo = extern struct {
    sType: VkStructureType = .VkPipelineRasterizationStateCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkPipelineRasterizationStateCreateFlags,
    depthClampEnable: VkBool32,
    rasterizerDiscardEnable: VkBool32,
    polygonMode: VkPolygonMode,
    cullMode: VkCullModeFlags,
    frontFace: VkFrontFace,
    depthBiasEnable: VkBool32,
    depthBiasConstantFactor: f32,
    depthBiasClamp: f32,
    depthBiasSlopeFactor: f32,
    lineWidth: f32,
};

pub const VkPipelineMultisampleStateCreateInfo = extern struct {
    sType: VkStructureType = .VkPipelineMultisampleStateCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkPipelineMultisampleStateCreateFlags,
    rasterizationSamples: VkSampleCountFlagBits,
    sampleShadingEnable: VkBool32,
    minSampleShading: f32,
    pSampleMask: ?[*]const VkSampleMask,
    alphaToCoverageEnable: VkBool32,
    alphaToOneEnable: VkBool32,
};

pub const VkPipelineDepthStencilStateCreateInfo = extern struct {
    sType: VkStructureType = .VkPipelineDepthStencilStateCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkPipelineDepthStencilStateCreateFlags,
    depthTestEnable: VkBool32,
    depthWriteEnable: VkBool32,
    depthCompareOp: VkCompareOp,
    depthBoundsTestEnable: VkBool32,
    stencilTestEnable: VkBool32,
    front: VkStencilOpState,
    back: VkStencilOpState,
    minDepthBounds: f32,
    maxDepthBounds: f32,
};

pub const VkPipelineColorBlendStateCreateInfo = extern struct {
    sType: VkStructureType = .VkPipelineColorBlendStateCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkPipelineColorBlendStateCreateFlags,
    logicOpEnable: VkBool32,
    logicOp: VkLogicOp,
    attachmentCount: u32,
    pAttachments: [*]const VkPipelineColorBlendAttachmentState,
    blendConstants: [4]f32,
};

pub const VkPipelineDynamicStateCreateInfo = extern struct {
    sType: VkStructureType = .VkPipelineDynamicStateCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkPipelineDynamicStateCreateFlags,
    dynamicStateCount: u32,
    pDynamicStates: [*]const VkDynamicState,
};

pub const VkFramebufferCreateInfo = extern struct {
    sType: VkStructureType = .VkFramebufferCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkFramebufferCreateFlags,
    renderPass: VkRenderPass,
    attachmentCount: u32,
    pAttachments: [*]const VkImageView,
    width: u32,
    height: u32,
    layers: u32,
};

pub const VkCommandPoolCreateInfo = extern struct {
    sType: VkStructureType = .VkCommandPoolCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkCommandPoolCreateFlags,
    queueFamilyIndex: u32,
};

pub const VkCommandBufferAllocateInfo = extern struct {
    sType: VkStructureType = .VkCommandBufferAllocateInfo,
    pNext: ?*const anyopaque = null,
    commandPool: VkCommandPool,
    level: VkCommandBufferLevel,
    commandBufferCount: u32,
};

pub const VkCommandBufferBeginInfo = extern struct {
    sType: VkStructureType = .VkCommandBufferBeginInfo,
    pNext: ?*const anyopaque = null,
    flags: VkCommandBufferUsageFlags,
    pInheritanceInfo: *const VkCommandBufferInheritanceInfo,
};

pub const VkCommandBufferInheritanceInfo = extern struct {
    sType: VkStructureType = .VkCommandBufferInheritanceInfo,
    pNext: ?*const anyopaque = null,
    renderPass: VkRenderPass,
    subpass: u32,
    framebuffer: VkFramebuffer,
    occlusionQueryEnable: VkBool32,
    queryFlags: VkQueryControlFlags,
    pipelineStatistics: VkQueryPipelineStatisticFlags,
};

pub const VkRenderPassBeginInfo = extern struct {
    sType: VkStructureType = .VkRenderPassBeginInfo,
    pNext: ?*const anyopaque = null,
    renderPass: VkRenderPass,
    framebuffer: VkFramebuffer,
    renderArea: VkRect2D,
    clearValueCount: u32,
    pClearValues: [*]const VkClearValue,
};

pub const VkSemaphoreCreateInfo = extern struct {
    sType: VkStructureType = .VkSemaphoreCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkSemaphoreCreateFlags,
};

pub const VkFenceCreateInfo = extern struct {
    sType: VkStructureType = .VkFenceCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkFenceCreateFlags,
};

pub const VkSubmitInfo = extern struct {
    sType: VkStructureType = .VkSubmitInfo,
    pNext: ?*const anyopaque = null,
    waitSemaphoreCount: u32,
    pWaitSemaphores: [*]const VkSemaphore,
    pWaitDstStageMask: [*]const VkPipelineStageFlags,
    commandBufferCount: u32,
    pCommandBuffers: [*]const VkCommandBuffer,
    signalSemaphoreCount: u32,
    pSignalSemaphores: [*]const VkSemaphore,
};

pub const VkPresentInfoKHR = extern struct {
    sType: VkStructureType = .VkPresentInfoKHR,
    pNext: ?*const anyopaque = null,
    waitSemaphoreCount: u32,
    pWaitSemaphores: [*]const VkSemaphore,
    swapchainCount: u32,
    pSwapchains: [*]const VkSwapchainKHR,
    pImageIndices: [*]const u32,
    pResults: ?[*]VkResult,
};

pub const VkBufferCreateInfo = extern struct {
    sType: VkStructureType = .VkBufferCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkBufferCreateFlags,
    size: VkDeviceSize,
    usage: VkBufferUsageFlags,
    sharingMode: VkSharingMode,
    queueFamilyIndexCount: u32,
    pQueueFamilyIndices: [*]const u32,
};

pub const VkMemoryAllocateInfo = extern struct {
    sType: VkStructureType = .VkMemoryAllocateInfo,
    pNext: ?*const anyopaque = null,
    allocationSize: VkDeviceSize,
    memoryTypeIndex: u32,
};

pub const VkMappedMemoryRange = extern struct {
    sType: VkStructureType = .VkMappedMemoryRange,
    pNext: ?*const anyopaque = null,
    memory: VkDeviceMemory,
    offset: VkDeviceSize,
    size: VkDeviceSize,
};

pub const VkImageCreateInfo = extern struct {
    sType: VkStructureType = .VkImageCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkImageCreateFlags,
    imageType: VkImageType,
    format: VkFormat,
    extent: VkExtent3D,
    mipLevels: u32,
    arrayLayers: u32,
    samples: VkSampleCountFlagBits,
    tiling: VkImageTiling,
    usage: VkImageUsageFlags,
    sharingMode: VkSharingMode,
    queueFamilyIndexCount: u32,
    pQueueFamilyIndices: [*]const u32,
    initialLayout: VkImageLayout,
};

pub const VkMemoryBarrier = extern struct {
    sType: VkStructureType = .VkMemoryBarrier,
    pNext: ?*const anyopaque = null,
    srcAccessMask: VkAccessFlags,
    dstAccessMask: VkAccessFlags,
};

pub const VkBufferMemoryBarrier = extern struct {
    sType: VkStructureType = .VkBufferMemoryBarrier,
    pNext: ?*const anyopaque = null,
    srcAccessMask: VkAccessFlags,
    dstAccessMask: VkAccessFlags,
    srcQueueFamilyIndex: u32,
    dstQueueFamilyIndex: u32,
    buffer: VkBuffer,
    offset: VkDeviceSize,
    size: VkDeviceSize,
};

pub const VkImageMemoryBarrier = extern struct {
    sType: VkStructureType = .VkImageMemoryBarrier,
    pNext: ?*const anyopaque = null,
    srcAccessMask: VkAccessFlags,
    dstAccessMask: VkAccessFlags,
    oldLayout: VkImageLayout,
    newLayout: VkImageLayout,
    srcQueueFamilyIndex: u32,
    dstQueueFamilyIndex: u32,
    image: VkImage,
    subresourceRange: VkImageSubresourceRange,
};

pub const VkDescriptorSetLayoutCreateInfo = extern struct {
    sType: VkStructureType = .VkDescriptorSetLayoutCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkDescriptorSetLayoutCreateFlags,
    bindingCount: u32,
    pBindings: [*]const VkDescriptorSetLayoutBinding,
};

pub const VkDescriptorPoolCreateInfo = extern struct {
    sType: VkStructureType = .VkDescriptorPoolCreateInfo,
    pNext: ?*const anyopaque = null,
    flags: VkDescriptorPoolCreateFlags,
    maxSets: u32,
    poolSizeCount: u32,
    pPoolSizes: [*]const VkDescriptorPoolSize,
};

pub const VkDescriptorSetAllocateInfo = extern struct {
    sType: VkStructureType = .VkDescriptorSetAllocateInfo,
    pNext: ?*const anyopaque = null,
    descriptorPool: VkDescriptorPool,
    descriptorSetCount: u32,
    pSetLayouts: [*]const VkDescriptorSetLayout,
};

pub const VkWriteDescriptorSet = extern struct {
    sType: VkStructureType = .VkWriteDescriptorSet,
    pNext: ?*const anyopaque = null,
    dstSet: VkDescriptorSet,
    dstBinding: u32,
    dstArrayElement: u32,
    descriptorCount: u32,
    descriptorType: VkDescriptorType,
    pImageInfo: [*]const VkDescriptorImageInfo,
    pBufferInfo: [*]const VkDescriptorBufferInfo,
    pTexelBufferView: [*]const VkBufferView,
};

pub const VkCopyDescriptorSet = extern struct {
    sType: VkStructureType = .VkCopyDescriptorSet,
    pNext: ?*const anyopaque = null,
    srcSet: VkDescriptorSet,
    srcBinding: u32,
    srcArrayElement: u32,
    dstSet: VkDescriptorSet,
    dstBinding: u32,
    dstArrayElement: u32,
    descriptorCount: u32,
};

pub const VkLayerSettingsCreateInfoEXT = extern struct {
    sType: VkStructureType = .VkLayerSettingsCreateInfoEXT,
    pNext: ?*const anyopaque = null,
    settingCount: u32,
    pSettings: [*]const VkLayerSettingEXT,
};


//////// OPAQUE

// VK_DEFINE_HANDLE
pub const VkInstance = *opaque {};
pub const VkPhysicalDevice = *opaque {};
pub const VkDevice = *opaque {};
pub const VkQueue = *opaque {};
pub const VkCommandBuffer = *opaque {};

// VK_DEFINE_NON_DISPATCHABLE_HANDLE
pub const VK_NULL_HANDLE: u64 = 0;
pub const VkSurfaceKHR = u64;
pub const VkSwapchainKHR = u64;
pub const VkImage = u64;
pub const VkImageView = u64;
pub const VkDescriptorSetLayout = u64;
pub const VkPipelineCache = u64;
pub const VkShaderModule = u64;
pub const VkPipelineLayout = u64;
pub const VkRenderPass = u64;
pub const VkPipeline = u64;
pub const VkFramebuffer = u64;
pub const VkCommandPool = u64;
pub const VkBuffer = u64;
pub const VkSemaphore = u64;
pub const VkFence = u64;
pub const VkDeviceMemory = u64;
pub const VkSampler = u64;
pub const VkDescriptorPool = u64;
pub const VkDescriptorSet = u64;
pub const VkBufferView = u64;


//////// ALIASES

pub const VkDeviceSize = u64;
pub const VkSampleMask = u32;
//pub const VkFlags = u32;


//////// CONSTANTS

pub const VK_MAX_EXTENSION_NAME_SIZE = 256;
pub const VK_MAX_DESCRIPTION_SIZE = 256;
pub const VK_MAX_PHYSICAL_DEVICE_NAME_SIZE = 256;
pub const VK_UUID_SIZE = 16;
pub const VK_MAX_MEMORY_TYPES = 32;
pub const VK_MAX_MEMORY_HEAPS = 16;
pub const VK_WHOLE_SIZE = ~@as(VkDeviceSize, 0);
pub const VK_QUEUE_FAMILY_IGNORED = ~@as(u32, 0);

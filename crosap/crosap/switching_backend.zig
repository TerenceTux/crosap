const u = @import("util");
const std = @import("std");
const crosap_api = @import("crosap_api");
const Event = crosap_api.Event;
const backend_imports = @import("backend_modules").imports;

const backend_modules = b: {
    const import_decls = @typeInfo(backend_imports).@"struct".decls;
    var list: [import_decls.len][:0]const u8 = undefined;
    for (&list, import_decls) |*item, decl| {
        item.* = decl.name;
    }
    break:b list;
};
const Backend_option = b: {
    var fields: [backend_modules.len]u.types.Field = undefined;
    for (&fields, backend_modules) |*field, backend_name| {
        const Backend_var = @field(backend_imports, backend_name).Backend;
        const field_type = switch(@typeInfo(@TypeOf(Backend_var))) {
            .@"struct" => void,
            .@"fn" => |fn_info| t: {
                const arguments = fn_info.params;
                u.assert(arguments.len == 1);
                break:t arguments[0].type.?;
            },
            else => unreachable,
        };
        field.* = .{
            .name = backend_name,
            .type = field_type,
        };
    }
    break:b u.types.create_tagged_union(&fields);
};

const Text_option = b: {
    var fields: [backend_modules.len]u.types.Field = undefined;
    for (&fields, backend_modules) |*field, backend_name| {
        const Backend_var = @field(backend_imports, backend_name).Backend;
        const field_type = switch(@typeInfo(@TypeOf(Backend_var))) {
            .@"struct" => void,
            .@"fn" => []const u8,
            else => unreachable,
        };
        field.* = .{
            .name = backend_name,
            .type = field_type,
        };
    }
    break:b u.types.create_tagged_union(&fields);
};

const options = @import("options");
const backends_options = u.option.get_comptime(options, []const Backend_option, "backend") orelse @panic("no backend option");
const text_options = u.option.get_comptime(options, []const Text_option, "backend") orelse @panic("no backend option");

pub const Variant = struct {
    name: []const u8,
    imp: type,
};


const variants = b: {
    var result: [backends_options.len]Variant = undefined;
    for (&result, backends_options, text_options) |*variant, backend_option, text_option| {
        const mod_name = @tagName(std.meta.activeTag(backend_option));
        const option_argument = @field(backend_option, mod_name);
        const option_text = @field(text_option, mod_name);
        const Backend_var = @field(backend_imports, mod_name).Backend;
        const Imp = switch(@typeInfo(@TypeOf(Backend_var))) {
            .@"struct" => Backend_var,
            .@"fn" => Backend_var(option_argument),
            else => unreachable,
        };
        const name = switch(@typeInfo(@TypeOf(Backend_var))) {
            .@"struct" => mod_name,
            .@"fn" => std.fmt.comptimePrint("{s}:{s}", .{mod_name, option_text}),
            else => unreachable,
        };
        variant.* = .{
            .name = name,
            .imp = Imp,
        };
    }
    break:b result;
};

// You can and should copy this
pub const Texture_handle = struct {
    index: u32,
};

pub const Backend = struct {
    const allowed_variants = variants;
    const order = b: {
        var result: [variants.len][]const u8 = undefined;
        for (&result, variants) |*item, variant| {
            item.* = variant.name;
        }
        break:b result;
    };
    const Variant_type = variant_type: {
        var fields: [order.len]std.builtin.Type.EnumField = undefined;
        for (&fields, order, 0..) |*field, name, index| {
            field.* = .{
                .name = u.comptime_to_string(name),
                .value = index,
            };
        }
        break:variant_type @Type(.{
            .@"enum" = .{
                .tag_type = usize,
                .fields = &fields,
                .decls = &.{},
                .is_exhaustive = true,
            },
        });
    };
    const Variants = variants: {
        var fields: [allowed_variants.len]std.builtin.Type.UnionField = undefined;
        for (&fields, allowed_variants) |*field, variant| {
            field.* = .{
                .name = u.comptime_to_string(variant.name),
                .type = variant.imp,
                .alignment = @alignOf(variant.imp),
            };
        }
        break:variants @Type(.{
            .@"union" = .{
                .layout = .auto,
                .tag_type = null,
                .fields = &fields,
                .decls = &.{},
            },
        });
    };
    const variant_count = order.len;
    
    const Texture_info = struct {
        imp: *anyopaque,
        size: u.Vec2i,
        data: []u.Screen_color,
    };
    
    current_variant: Variant_type,
    variants: Variants,
    textures: u.Resource_list(Texture_info),
    
    
    pub fn init(b: *Backend) void {
        u.log_start("Initializing backend");
        b.textures.init();
        
        var variant_index: usize = 0;
        b.current_variant = @enumFromInt(0);
        while (variant_index < variant_count) {
            b.current_variant = @enumFromInt(variant_index);
            u.log(.{"Trying variant ",b.current_variant," (index ",variant_index,")"});
            if (b.variant_call(.init, .{})) {
                u.log_end(.{"Initialized variant ",b.current_variant});
                return;
            } else |err| {
                u.log(.{"Variant ",b.current_variant," gave error ",err});
                // try next
            }
            variant_index += 1;
        }
        @panic("all backends failed initializing");
    }
    
    fn Return_of_function(function: @Type(.enum_literal)) type {
        var Return_type: ?type = null;
        
        inline for (@typeInfo(Variants).@"union".fields) |field| {
            const Fn = @TypeOf(@field(field.type, u.comptime_to_string(function)));
            const Type = @typeInfo(Fn).@"fn".return_type.?;
            if (Return_type == null) {
                Return_type = Type;
            } else if (Return_type != Type) {
                @compileError("Function "++@tagName(function)++" has inconsistent return types "++@typeName(Return_type)++" and "++@typeName(Type));
            }
        }
        return Return_type.?;
    }
    
    fn Arguments_of_function(function: @Type(.enum_literal)) type {
        var Arguments: ?type = null;
        
        inline for (@typeInfo(Variants).@"union".fields) |field| {
            const Fn = @TypeOf(@field(field.type, u.comptime_to_string(function)));
            const params = @typeInfo(Fn).@"fn".params;
            var types_list: [params.len - 1]type = undefined;
            for (&types_list, params[1..]) |*item, param| {
                item.* = param.type.?;
            }
            const Type = std.meta.Tuple(&types_list);
            if (Arguments == null) {
                Arguments = Type;
            } else if (Arguments != Type) {
                @compileError("Function "++@tagName(function)++" has inconsistent argument types "++@typeName(Arguments)++" and "++@typeName(Type));
            }
        }
        return Arguments.?;
    }
    
    fn variant_call(b: *Backend, comptime function: @Type(.enum_literal), args: Arguments_of_function(function)) Return_of_function(function) {
        switch (b.current_variant) {
            inline else => |variant_type| {
                const current_variant = &@field(b.variants, @tagName(variant_type));
                
                const Call_arguments = comptime call_arguments: {
                    const params = @typeInfo(@TypeOf(args)).@"struct".fields;
                    var arguments_list: [params.len]type = undefined;
                    for (&arguments_list, params) |*argument, param| {
                        argument.* = param.type;
                    }
                    break:call_arguments std.meta.Tuple(&([1]type {@TypeOf(current_variant)} ++ arguments_list));
                };
                var call_arguments: Call_arguments = undefined;
                call_arguments[0] = current_variant;
                inline for (0..call_arguments.len-1) |i| {
                    call_arguments[i + 1] = args[i];
                }
                
                const Current_variant = @typeInfo(@TypeOf(current_variant)).@"pointer".child;
                return @call(.auto, @field(Current_variant, u.comptime_to_string(function)), call_arguments);
            },
        }
    }
    
    fn restore_after_switch(b: *Backend) !void {
        var texture_index: u32 = 0;
        errdefer {
            // free textures that we did initialize
            while (true) {
                switch (b.textures.items.get(texture_index)) {
                    .free => {},
                    .used => |tex_info| {
                        b.variant_call(.destroy_texture, .{tex_info.imp});
                    },
                }
                if (texture_index == 0) {
                    break;
                } else {
                    texture_index -= 1;
                }
            }
        }
        while (texture_index < b.textures.items.count) {
            switch (b.textures.items.get_mut(texture_index).*) {
                .free => {},
                .used => |*tex_info| {
                    tex_info.imp = try b.variant_call(.create_texture, .{tex_info.size});
                    b.variant_call(.update_texture, .{tex_info.imp, .create(.zero, tex_info.size), tex_info.data}) catch {};
                },
            }
            texture_index += 1;
        }
        // TODO: we could cancel input
    }
    
    fn switch_variant(b: *Backend) bool {
        u.log_start(.{"Switching variant"});
        const next_index = @intFromEnum(b.current_variant) + 1;
        if (next_index >= variant_count) {
            u.log(.{"There are no more variants, so we panic"});
            @panic("all backends failed");
        }
        u.log(.{"Init ",b.current_variant});
        b.variant_call(.init, .{}) catch |err| {
            u.log_end(.{"Init error: ",err});
            return false;
        };
        u.log(.{"Restoring data"});
        b.restore_after_switch() catch |err| {
            u.log_end(.{"Error: ",err});
            b.deinit_for_switch();
            return false;
        };
        
        u.log_end(.{"Successfully switched to ",b.current_variant});
        return true;
    }
    
    pub fn Return_for_call(function: @Type(.enum_literal)) type {
        const Return_type = Return_of_function(function);
        switch (@typeInfo(Return_type)) {
            .error_union => |error_info| return error_info.payload,
            else => return Return_type,
        }
    }
    
    fn call(b: *Backend, comptime function: @Type(.enum_literal), args: Arguments_of_function(function)) Return_for_call(function) {
        u.log_start(.{"Backend function ",function," called"});
        if (@typeInfo(Return_of_function(function)) == .error_union) {
            while (true) {
                if (b.variant_call(function, args)) |ret_val| {
                    u.log_end(.{});
                    return ret_val;
                } else |err| {
                    u.log_end(.{"This function failed on ",b.current_variant," with error: ",err});
                    b.deinit_for_switch();
                    while (true) {
                        if (b.switch_variant()) {
                            break;
                        } else {
                            // new variant failed, switch again
                        }
                    }
                }
            }
        } else { // function can't fail
            const ret_val = b.variant_call(function, args);
            u.log_end(.{});
            return ret_val;
        }
    }
    
    fn deinit_for_switch(b: *Backend) void {
        u.log_start(.{"Deinit ",b.current_variant," for switching"});
        var texture_iterator = b.textures.iterator();
        while (texture_iterator.read()) |index| {
            const texture_imp = index.imp;
            b.call(.destroy_texture, .{texture_imp});
        }
        b.variant_call(.deinit, .{});
        u.log_end(.{});
    }
    
    pub fn deinit(b: *Backend) void {
        if (u.debug) {
            var texture_iterator = b.textures.iterator();
            u.assert(texture_iterator.read() == null);
        }
        b.variant_call(.deinit, .{});
        b.textures.deinit();
    }
    
    // The following are called by crosap
    
    pub fn create_texture(b: *Backend, size: u.Vec2i) Texture_handle {
        const texture_imp = b.call(.create_texture, .{size});
        const index = b.textures.create();
        const data = u.alloc.alloc(u.Screen_color, size.x.multiply(size.y).to(usize)) catch @panic("no memory");
        b.textures.set(index, .{
            .imp = texture_imp,
            .size = size,
            .data = data,
        });
        return .{.index = index};
    }
    
    pub fn destroy_texture(b: *Backend, texture: Texture_handle) void {
        const texture_imp = b.textures.get(texture.index).imp;
        b.call(.destroy_texture, .{texture_imp});
        u.alloc.free(b.textures.get(texture.index).data);
        b.textures.destroy(texture.index);
    }
    
    pub fn update_texture(b: *Backend, texture: Texture_handle, rect: u.Rect2i, data: []const u.Screen_color) void {
        u.assert(data.len == rect.size.area().to(usize));
        const texture_info = b.textures.get(texture.index);
        b.call(.update_texture, .{texture_info.imp, rect, data});
        
        const texture_size = texture_info.size;
        const texture_data = texture_info.data;
        var y = rect.top();
        const y_end = rect.bottom();
        var update_pos: usize = 0;
        while (y.lower_than(y_end)) {
            const texture_offset = y.multiply(texture_size.x).to(usize);
            const texture_slice = texture_data[texture_offset + rect.left().to(usize) .. texture_offset + rect.right().to(usize)];
            const old_pos = update_pos;
            update_pos += rect.size.x.to(usize);
            const update_slice = data[old_pos..update_pos];
            @memcpy(texture_slice, update_slice);
            y = y.add(.one);
        }
    }
    
    pub fn new_frame(b: *Backend) ?u.Vec2i {
        return b.call(.new_frame, .{});
    }
    
    pub fn draw_object(b: *Backend, rect: u.Rect2i, color: u.Screen_color, texture: Texture_handle, texture_rect: u.Rect2i, texture_offset: u.Vec2i) void {
        const texture_imp = b.textures.get(texture.index).imp;
        b.call(.draw_object, .{rect, color, texture_imp, texture_rect, texture_offset});
    }
    
    pub fn end_frame(b: *Backend) void {
        b.call(.end_frame, .{});
    }
    
    // TODO: audio
    
    // The following are called by main
    
    pub fn poll_events(b: *Backend) void {
        b.call(.poll_events, .{});
    }
    
    pub fn get_event(b: *Backend) ?Event {
        return b.call(.get_event, .{});
    }
};

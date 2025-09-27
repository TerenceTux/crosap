const std = @import("std");

const Enum_literal = @Type(.enum_literal);

pub fn interface(info: type) type {
    const Interface_function = struct {
        name: [:0]const u8,
        arguments: []const type,
        return_type: type,
    };
    
    const members = @typeInfo(info).@"struct".fields;
    var functions_mut: [members.len]Interface_function = undefined;
    for (members, &functions_mut) |member, *function| {
        function.name = member.name;
        const typeinfo = @typeInfo(member.type).@"fn";
        function.return_type = typeinfo.return_type.?;
        var arguments_var: [typeinfo.params.len]type = undefined;
        for (typeinfo.params, &arguments_var) |param, *argument_type| {
            argument_type.* = param.type.?;
        }
        const arguments = arguments_var;
        function.arguments = &arguments;
    }
    const functions = functions_mut;
    
    var function_table_fields: [functions.len]std.builtin.Type.StructField = undefined;
    for (functions, &function_table_fields) |function, *table_field| {
        table_field.name = function.name;
        var fn_params: [1 + function.arguments.len]std.builtin.Type.Fn.Param = undefined;
        fn_params[0] = .{
            .is_generic = false,
            .is_noalias = false,
            .type = *anyopaque,
        };
        for (function.arguments, fn_params[1..]) |argument_type, *param| {
            param.is_generic = false;
            param.is_noalias = false;
            param.type = argument_type;
        }
        const fn_type = @Type(.{.@"fn" = .{
            .calling_convention = .auto,
            .is_generic = false,
            .is_var_args = false,
            .return_type = function.return_type,
            .params = &fn_params,
        }});
        table_field.type = @Type(.{.@"pointer" = .{
            .size = .one,
            .is_const = true,
            .is_volatile = false,
            .alignment = @alignOf(fn_type),
            .address_space = .generic,
            .child = fn_type,
            .is_allowzero = false,
            .sentinel_ptr = null,
        }});
        table_field.default_value_ptr = null;
        table_field.is_comptime = false;
        table_field.alignment = @alignOf(table_field.type);
    }
    
    const Function_table = @Type(.{.@"struct" = .{
        .layout = .auto,
        .fields = &function_table_fields,
        .decls = &.{},
        .is_tuple = false,
    }});
    
    return struct {
        fn find_function(comptime tag: Enum_literal) Interface_function {
            const name = @tagName(tag);
            for (functions) |function| {
                if (std.mem.eql(u8, name, function.name)) {
                    return function;
                }
            }
            @compileError("Unknown function call: "++name);
        }
        
        fn Args_of(comptime tag: Enum_literal) type {
            const function = find_function(tag);
            return std.meta.Tuple(function.arguments);
        }
        
        fn Return_of(comptime tag: Enum_literal) type {
            const function = find_function(tag);
            return function.return_type;
        }
        
        fn function_table_of(Type: type) Function_table {
            var function_table: Function_table = undefined;
            inline for (@typeInfo(Function_table).@"struct".fields) |field| {
                @field(function_table, field.name) = @ptrCast(&@field(Type, field.name));
            }
            return function_table;
        }
        
        pub const Dynamic = struct {
            const Self = @This();
            imp: *anyopaque,
            fns: *const Function_table,
            
            pub fn call(s: Self, comptime tag: Enum_literal, args: Args_of(tag)) Return_of(tag) {
                const name = @tagName(tag);
                const arguments = find_function(tag).arguments;
                const Call_tuple = std.meta.Tuple([1]type {*anyopaque} ++ arguments);
                var call_tuple: Call_tuple = undefined;
                call_tuple[0] = s.imp;
                inline for (0..arguments.len) |i| {
                    call_tuple[i + 1] = args[i];
                }
                return @call(.auto, @field(s.fns, name), call_tuple);
            }
            
            pub const is_call_layer_for = info;
        };
        
        pub fn Static(Imp: type) type {
            return struct {
                const Self = @This();
                imp: *Imp,
                
                pub fn call(s: Self, comptime tag: Enum_literal, args: Args_of(tag)) Return_of(tag) {
                    const name = @tagName(tag);
                    const arguments = find_function(tag).arguments;
                    const Call_tuple = std.meta.Tuple([1]type {*Imp} ++ arguments);
                    var call_tuple: Call_tuple = undefined;
                    call_tuple[0] = s.imp;
                    inline for (0..arguments.len) |i| {
                        call_tuple[i + 1] = args[i];
                    }
                    return @call(.auto, @field(Imp, name), call_tuple);
                }
                
                pub const is_call_layer_for = info;
            };
        }
        
        pub const Dynamic_interface = info.Interface(Dynamic);
        
        pub fn dynamic(imp: anytype) info.Interface(Dynamic) {
            const Type = switch (@typeInfo(@TypeOf(imp))) {
                .pointer => |pointer_info| pointer_info.child,
                else => @compileError("You must pass a pointer to dynamic(), got "++@typeName(imp)),
            };
            const call_layer = Dynamic {
                .imp = imp,
                .fns = &comptime function_table_of(Type),
            };
            return .{
                .imp = call_layer,
            };
        }
        
        pub fn Static_interface(Imp: type) type {
            return info.Interface(Static(Imp));
        }

        fn Static_call_layer(imp: type) type {
            switch (@typeInfo(imp)) {
                .pointer => |pointer_info| return Static(pointer_info.child),
                else => @compileError("You must pass a pointer to static(), got "++@typeName(imp)),
            }
        }
        
        pub fn static(imp: anytype) info.Interface(Static_call_layer(@TypeOf(imp))) {
            const Call_layer = Static_call_layer(@TypeOf(imp));
            const call_layer = Call_layer {
                .imp = imp,
            };
            return .{
                .imp = call_layer,
            };
        }
        
        fn validation_error(Type: type, comptime message: []const u8) noreturn {
            @compileError("interface validation failed for type "++@typeName(Type)++": "++message);
        }
        
        /// Tests if the argument is either interface.Static(Imp) or interface.Dynamic
        /// You can pass the type or a value of that type
        pub fn validate(passed_interface: anytype) void {
            const Type = if (@TypeOf(passed_interface) == type) passed_interface else @TypeOf(passed_interface);
            switch (@typeInfo(Type)) {
                .@"struct" => {},
                else => validation_error(Type, "not a struct"),
            }
            if (!@hasField(Type, "imp")) {
                validation_error(Type, "no imp field");
            }
            
            const Imp_type = @FieldType(Type, "imp");
            
            switch (@typeInfo(Imp_type)) {
                .@"struct" => {},
                else => validation_error(Type, "is is not a struct"),
            }
            if (!@hasDecl(Imp_type, "is_call_layer_for")) {
                validation_error(Imp_type, "imp is not a call layer");
            }
            if (@TypeOf(Imp_type.is_call_layer_for) != type) {
                validation_error(Type, "imp is not a call layer (is_call_layer_for is invalid)");
            }
            
            if (Imp_type.is_call_layer_for != info) {
                validation_error(Type, "this is a different interface");
            }
        }
    };
}

const std = @import("std");
const builtin = @import("builtin");

//const debug = builtin.mode == .Debug;
const debug = false;
const is_space = std.ascii.isWhitespace;

var alloc: std.mem.Allocator = undefined;


pub fn main() !void {
    var gp_allocator = std.heap.DebugAllocator(.{}).init;
    defer _ = gp_allocator.deinit();
    alloc = gp_allocator.allocator();
    
    
    var threaded: std.Io.Threaded = .init(alloc);
    defer threaded.deinit();
    const io = threaded.io();
    
    const args = std.process.argsAlloc(alloc) catch @panic("no memory");
    defer std.process.argsFree(alloc, args);
    var xml_path: ?[]const u8 = null;
    var output_path: ?[]const u8 = null;
    if (args.len >= 2) {
        xml_path = args[1];
    }
    if (args.len >= 3) {
        output_path = args[2];
    }
    
    const working_dir = std.fs.cwd();
    var file = working_dir.openFile(xml_path orelse "vk.xml", .{}) catch @panic("xml file not found");
    defer file.close();
    
    var read_buffer: [4096]u8 = undefined;
    var reader = file.reader(io, &read_buffer);
    const read_interface = &reader.interface;
    
    var output = if (output_path) |open_path| (
        working_dir.createFile(open_path, .{}) catch @panic("could not create output file")
    ) else (
        std.fs.File.stdout()
    );
    defer if (output_path != null) {
        output.close();
    };
    var write_buffer: [4096]u8 = undefined;
    var writer = output.writer(&write_buffer);
    
    var parser: Parser = undefined;
    parser.outputter.stream = &writer.interface;
    parser.outputter.init();
    defer parser.outputter.deinit();
    
    parser.init();
    defer parser.deinit();
    
    while (true) {
        const byte = read_interface.takeByte() catch |err| switch (err) {
            error.EndOfStream => break,
            else => return error.FileReadError,
        };
        parser.new_byte(byte);
    }
}

fn strings_equal(s1: []const u8, s2: []const u8) bool {
    return std.mem.eql(u8, s1, s2);
}

pub const Dynamic_string = struct {
    arraylist: std.ArrayList(u8),
    
    pub fn init(ds: *Dynamic_string) void {
        ds.arraylist = std.ArrayList(u8).initCapacity(alloc, 16) catch @panic("no memory");
    }
    
    pub fn deinit(ds: *Dynamic_string) void {
        ds.arraylist.deinit(alloc);
    }
    
    pub fn content(ds: *Dynamic_string) []u8 {
        return ds.arraylist.items;
    }
    
    pub fn add_char(ds: *Dynamic_string, char: u8) void {
        ds.arraylist.append(alloc, char) catch @panic("no memory");
    }
    
    pub fn clear(ds: *Dynamic_string) void {
        ds.arraylist.clearRetainingCapacity();
    }
};

const PropMap = std.StringHashMapUnmanaged([]const u8);

pub const Parser = struct {
    const State = enum {
        start,
        
        content,
        content_escape,
        
        tag_name,
        close_name,
        
        processing_tag,
        processing_question,
        
        comment,
        comment_dash1,
        comment_dash2,
        
        prop_start,
        prop_name,
        prop_equal,
        prop_value,
        prop_value_escape,
    };
    const Property = struct {
        name: Dynamic_string,
        value: Dynamic_string,
    };
    
    outputter: Outputter,
    state: State,
    content: Dynamic_string, // or tag name
    props: std.ArrayList(Property), // current properties, only valid in prop_*
    escape: Dynamic_string,
    
    
    pub fn init(p: *Parser) void {
        p.state = .start;
        p.content.init();
        p.escape.init();
    }
    
    pub fn deinit(p: *Parser) void {
        if (p.state == .content) {
            p.send_content();
        } else if (p.state != .start) {
            @panic("Unexpected end of file");
        }
        p.content.deinit();
        p.escape.deinit();
    }
    
    pub fn new_byte(p: *Parser, byte: u8) void {
        switch (p.state) {
            .start => {
                if (is_space(byte)) {
                    
                } else if (byte == '<') {
                    p.state = .tag_name;
                    p.content.clear();
                } else {
                    p.state = .content;
                    p.content.clear();
                    p.content.add_char(byte);
                }
            },
            .content => {
                if (byte == '<') {
                    p.send_content();
                    p.state = .tag_name;
                    p.content.clear();
                } else if (byte == '&') {
                    p.state = .content_escape;
                    p.escape.clear();
                } else {
                    p.content.add_char(byte);
                }
            },
            .content_escape => {
                if (byte == ';') {
                    p.content.add_char(p.read_escaped());
                    p.state = .content;
                } else {
                    p.escape.add_char(byte);
                }
            },
            .tag_name => {
                const first = p.content.content().len == 0;
                if (first and byte == '/') {
                    p.state = .close_name;
                } else if (first and byte == '?') {
                    p.state = .processing_tag;
                } else if (first and byte == '!') {
                    p.state = .comment;
                } else if (is_space(byte)) {
                    if (!first) { // ignore space at start
                        p.state = .prop_start;
                        p.props = std.ArrayList(Property).initCapacity(alloc, 8) catch @panic("no memory");
                    }
                } else if (byte == '>') {
                    p.state = .start;
                    p.props = std.ArrayList(Property).initCapacity(alloc, 0) catch @panic("no memory");
                    p.send_start();
                } else {
                    p.content.add_char(byte);
                }
            },
            .close_name => {
                if (byte == '>') {
                    p.outputter.close(p.content.content());
                    p.state = .start;
                } else {
                    p.content.add_char(byte);
                }
            },
            .processing_tag => {
                if (byte == '?') {
                    p.state = .processing_question;
                }
            },
            .processing_question => {
                if (byte == '>') {
                    p.state = .start;
                } else if (byte == '?') {
                    p.state = .processing_question;
                } else {
                    p.state = .processing_tag;
                }
            },
            .comment => {
                if (byte == '-') {
                    p.state = .comment_dash1;
                }
            },
            .comment_dash1 => {
                if (byte == '-') {
                    p.state = .comment_dash2;
                } else {
                    p.state = .comment;
                }
            },
            .comment_dash2 => {
                if (byte == '>') {
                    p.state = .start;
                } else if (byte == '-') {
                    p.state = .comment_dash2;
                } else {
                    p.state = .comment;
                }
            },
            .prop_start => {
                if (is_space(byte)) {
                    // ignore
                } else if (byte == '>') {
                    p.send_start();
                    p.state = .start;
                } else {
                    // start of name
                    const prop = p.props.addOne(alloc) catch @panic("no memory");
                    prop.name.init();
                    prop.value.init();
                    prop.name.add_char(byte);
                    p.state = .prop_name;
                }
            },
            .prop_name => {
                if (byte == '=') {
                    p.state = .prop_equal;
                } else if (byte == '>') {
                    var prop = p.props.pop() orelse @panic("Invalid xml");
                    if (!std.mem.eql(u8, prop.name.content(), "/")) {
                        @panic("Invalid xml");
                    }
                    prop.name.deinit();
                    prop.value.deinit();
                    p.send_start();
                    p.outputter.close(p.content.content());
                    p.state = .start;
                } else {
                    const prop = p.current_property();
                    prop.name.add_char(byte);
                }
            },
            .prop_equal => {
                if (byte == '"') {
                    p.state = .prop_value;
                } else {
                    @panic("Invalid xml");
                }
            },
            .prop_value => {
                if (byte == '"') {
                    p.state = .prop_start;
                } else if (byte == '&') {
                    p.state = .prop_value_escape;
                    p.escape.clear();
                } else {
                    const prop = p.current_property();
                    prop.value.add_char(byte);
                }
            },
            .prop_value_escape => {
                if (byte == ';') {
                    const prop = p.current_property();
                    prop.value.add_char(p.read_escaped());
                    p.state = .prop_value;
                } else {
                    p.escape.add_char(byte);
                }
            },
        }
    }
    
    pub fn current_property(p: *Parser) *Property {
        const props = p.props.items;
        return &props[props.len - 1];
    }
    
    pub fn send_content(p: *Parser) void {
        const content = p.content.content();
        const trimmed = std.mem.trimEnd(u8, content, " \t\n");
        if (trimmed.len != 0) {
            p.outputter.content(trimmed);
        }
    }
    
    pub fn send_start(p: *Parser) void {
        const props = p.props.items;
        var hashmap = PropMap.empty;
        hashmap.ensureTotalCapacity(alloc, @intCast(props.len)) catch @panic("no memory");
        for (props) |*prop| {
            hashmap.put(alloc, prop.name.content(), prop.value.content()) catch @panic("no memory");
        }
        
        p.outputter.open(p.content.content(), &hashmap);
        
        hashmap.deinit(alloc);
        for (p.props.items) |*prop| {
            prop.name.deinit();
            prop.value.deinit();
        }
        p.props.deinit(alloc);
    }
    
    pub fn read_escaped(p: *Parser) u8 {
        const escape = p.escape.content();
        if (escape.len >= 1 and escape[0] == '#') {
            @panic("TODO: implement number escape sequence");
        } else {
            if (std.mem.eql(u8, escape, "quot")) {
                return '"';
            } else if (std.mem.eql(u8, escape, "apos")) {
                return '\'';
            } else if (std.mem.eql(u8, escape, "lt")) {
                return '<';
            } else if (std.mem.eql(u8, escape, "gt")) {
                return '>';
            } else if (std.mem.eql(u8, escape, "amp")) {
                return '&';
            } else {
                @panic("Invalid escape sequence");
            }
        }
    }
};

const file_start =
\\// GENERATED - DO NOT EDIT
\\
\\const std = @import("std");
\\const u = @import("util");
\\
\\pub const Version = struct {
\\    variant: u3,
\\    major: u7,
\\    minor: u10,
\\    patch: u12,
\\    
\\    pub fn from_u32(num: u32) Version {
\\        return .{
\\            .variant = @intCast((num & 0b11100000000000000000000000000000) >> 29),
\\            .major   = @intCast((num & 0b00011111110000000000000000000000) >> 22),
\\            .minor   = @intCast((num & 0b00000000001111111111000000000000) >> 12),
\\            .patch   = @intCast((num & 0b00000000000000000000111111111111) >> 0),
\\        };
\\    }
\\    
\\    pub fn to_u32(version: Version) u32 {
\\        var num: u32 = 0;
\\        num |= @as(u32, version.variant) << 29;
\\        num |= @as(u32, version.major) << 22;
\\        num |= @as(u32, version.minor) << 12;
\\        num |= @as(u32, version.patch) << 0;
\\        return num;
\\    }
\\    
\\    pub fn debug_print(version: Version, stream: anytype) void {
\\        u.byte_writer.validate(stream);
\\        const text = std.fmt.allocPrint(u.alloc, "{d}.{d}.{d}.{d}", .{version.variant, version.major, version.minor, version.patch}) catch @panic("No memory");
\\        stream.write_slice(text);
\\        u.alloc.free(text);
\\    }
\\};
\\
\\fn Flags_option(Options: type) type {
\\    const fields = @typeInfo(Options).@"enum".fields;
\\    var type_fields: [fields.len]std.builtin.Type.EnumField = undefined;
\\    for (fields, &type_fields, 0..) |field, *type_field, i| {
\\        type_field.* = .{
\\            .name = field.name,
\\            .value = 1 << i,
\\        };
\\    }
\\    
\\    const typeinfo = std.builtin.Type {
\\        .@"enum" = .{
\\            .tag_type = u32,
\\            .is_exhaustive = true,
\\            .decls = &.{},
\\            .fields = &type_fields,
\\        }
\\    };
\\    return @Type(typeinfo);
\\}
\\
\\fn Flags(Option: type) type {
\\    return extern struct {
\\        const Self = @This();
\\        value: u32,
\\        
\\        pub fn empty() Self {
\\            return .{
\\                .value = 0,
\\            };
\\        }
\\        
\\        pub fn add(f: Self, option: Option) Self {
\\            return .{
\\                .value = f.value | @intFromEnum(option),
\\            };
\\        }
\\        
\\        pub fn remove(f: Self, option: Option) Self {
\\            return .{
\\                .value = f.value & ~@intFromEnum(option),
\\            };
\\        }
\\        
\\        pub fn just(option: Option) Self {
\\            return .{
\\                .value = @intFromEnum(option),
\\            };
\\        }
\\        
\\        pub fn combine(f1: Self, f2: Self) Self {
\\            return .{
\\                .value = f1.value | f2.value,
\\            };
\\        }
\\        
\\        pub fn create(options: []const Option) Self {
\\            var value: u32 = 0;
\\            for (options) |option| {
\\                value |= @intFromEnum(option);
\\            }
\\            return .{.value = value};
\\        }
\\        
\\        pub fn has(f: Self, option: Option) bool {
\\            return (f.value & @intFromEnum(option)) != 0;
\\        }
\\        
\\        pub fn debug_print(f: Self, stream: anytype) void {
\\            u.byte_writer.validate(stream);
\\            var count: usize = 0;
\\            const fields = @typeInfo(Option).@"enum".fields;
\\            inline for (fields) |field| {
\\                const name = field.name;
\\                if (f.has(@field(Option, name))) {
\\                    if (count != 0) {
\\                        stream.write_slice(" + ");
\\                    }
\\                    stream.write_slice(name);
\\                    count += 1;
\\                }
\\            }
\\            
\\            if (count == 0) {
\\                stream.write_slice("(empty)");
\\            }
\\        }
\\        
\\        pub fn select_best(f: Self, order: []const Option) Option {
\\            for (order) |option| {
\\                if (f.has(option)) {
\\                    return option;
\\                }
\\            }
\\            @panic("No suitable option found");
\\        }
\\    };
\\}
\\
\\pub const Bool = enum(u32) {
\\    false = 0,
\\    true = 1,
\\    
\\    pub fn from(v: bool) Bool {
\\        return if (v) .true else .false;
\\    }
\\    
\\    pub fn to_bool(v: Bool) bool {
\\        return switch (v) {
\\            .false => false,
\\            .true => true,
\\        };
\\    }
\\};
\\
\\fn Empty_flags(T: type) type {
\\    return extern struct {
\\        const Self = @This();
\\        value: T = 0,
\\        
\\        pub fn empty() Self {
\\            return .{};
\\        }
\\        
\\        pub fn debug_print(f: Self, stream: anytype) void {
\\            _ = f;
\\            stream.write_slice("(empty)");
\\        }
\\    };
\\}
\\
\\pub const Command = struct {
\\    name: [:0]const u8,
\\    function: type,
\\    errors: type,
\\    
\\    fn result_to_error(result: Result) anyerror!void {
\\        switch (result) {
\\            .success => return,
\\            inline else => |error_result| return u.create_error(@tagName(error_result)),
\\            _ => return error.unknown,
\\        }
\\    }
\\    
\\    pub fn Call_return_type(command: Command) type {
\\        const Return_type = @typeInfo(command.function).@"fn".return_type.?;
\\        if (Return_type == Result) {
\\            const error_count = @typeInfo(command.errors).error_set.?.len;
\\            if (error_count == 0) {
\\                return void;
\\            } else {
\\                return command.errors!void;
\\            }
\\        } else {
\\            return Return_type;
\\        }
\\    }
\\    
\\    pub fn Call_arguments(command: Command) type {
\\        return std.meta.ArgsTuple(command.function);
\\    }
\\    
\\    pub fn call(command: Command, func: *const command.function, args: Call_arguments(command)) Call_return_type(command) {
\\        const result = @call(.auto, func, args);
\\        if (@TypeOf(result) == Result) {
\\            if (Call_return_type(command) == void) {
\\                return;
\\            }
\\            return @errorCast(result_to_error(result));
\\        } else {
\\            return result;
\\        }
\\    }
\\};
\\
\\pub const Extension = struct {
\\    name: [:0]const u8,
\\    commands: []const @Type(.enum_literal),
\\};
\\
\\pub const null_handle: u64 = 0;
;

//@compileLog(@Type(.{.error_set = &.{.{.name = "t"}}}).t);

pub const Outputter = struct {
    const Tag = struct {
        name: []const u8,
        props: PropMap,
    };
    const Enum_type = enum {
        normal,
        flag,
        flag_big,
    };
    const Enum_value = struct {
        name: []const u8,
        value: i64,
    };
    const Enum = struct {
        type: Enum_type,
        values: std.ArrayList(Enum_value),
    };
    const Command_type = enum {
        global,
        instance,
        device,
    };
    const Command = struct {
        use: bool,
        type: Command_type,
    };
    const Extension = struct {
        name: []const u8,
        commands: std.ArrayList([]const u8),
        
        pub fn deinit(extension: *Extension) void {
            alloc.free(extension.name);
            for (extension.commands.items) |command| {
                alloc.free(command);
            }
            extension.commands.deinit(alloc);
        }
        
        pub fn write_commands(extension: *Extension, o: *Outputter) void {
            o.write("    pub const ");
            o.write_extension_name(extension.name);
            o.write(" = Extension {\n");
            o.write("        .name = \"");
            o.write(extension.name);
            o.write("\",\n");
            o.write("        .commands = &.{\n");
            for (extension.commands.items) |command| {
                o.write("            .");
                o.write_command_name(command);
                o.write(",\n");
            }
            o.write("        },\n");
            o.write("    };\n");
        }
    };
    
    stream: *std.Io.Writer,
    intent: u8,
    tree: std.ArrayList(Tag),
    current_name: ?[]const u8,
    current_type: ?[]const u8,
    current_is_const: bool,
    current_is_pointer: bool,
    current_is_double_pointer: bool,
    current_is_double_const: bool,
    current_is_array: bool,
    current_length: ?[]const u8,
    current_return_type: ?[]const u8,
    suffixes: std.ArrayList([]const u8),
    enums: std.StringHashMapUnmanaged(Enum),
    aliases: std.StringHashMapUnmanaged([]const u8),
    commands: std.StringHashMapUnmanaged(Command),
    check_command_type: ?*Command_type,
    core_versions: std.ArrayList(Extension),
    instance_extensions: std.ArrayList(Extension),
    device_extensions: std.ArrayList(Extension),
    current_extension: *Extension,
    
    
    fn write_char(o: *Outputter, char: u8) void {
        o.stream.writeByte(char) catch @panic("write error");
        if (debug) {
            o.stream.flush() catch @panic("write error");
        }
    }
    
    pub fn write(o: *Outputter, txt: []const u8) void {
        o.stream.writeAll(txt) catch @panic("write error");
        if (debug) {
            o.stream.flush() catch @panic("write error");
        }
    }
    
    pub fn print(o: *Outputter, comptime fmt: []const u8, args: anytype) void {
        o.stream.print(fmt, args) catch @panic("write error");
        if (debug) {
            o.stream.flush() catch @panic("write error");
        }
    }
    
    pub fn init(o: *Outputter) void {
        o.intent = 0;
        o.tree = std.ArrayList(Tag).initCapacity(alloc, 16) catch @panic("no memory");
        o.current_name = null;
        o.current_type = null;
        o.current_length = null;
        o.current_return_type = null;
        o.suffixes = std.ArrayList([]const u8).initCapacity(alloc, 64) catch @panic("no memory");
        o.enums = .empty;
        o.enums.ensureTotalCapacity(alloc, 256) catch @panic("no memory");
        o.aliases = .empty;
        o.aliases.ensureTotalCapacity(alloc, 64) catch @panic("no memory");
        o.commands = .empty;
        o.commands.ensureTotalCapacity(alloc, 64) catch @panic("no memory");
        o.core_versions = std.ArrayList(Extension).initCapacity(alloc, 8) catch @panic("no memory");
        o.instance_extensions = std.ArrayList(Extension).initCapacity(alloc, 64) catch @panic("no memory");
        o.device_extensions = std.ArrayList(Extension).initCapacity(alloc, 64) catch @panic("no memory");
        
        o.write(file_start);
        o.write("\n\n\n");
    }
    
    pub fn deinit(o: *Outputter) void {
        var enum_iterator = o.enums.iterator();
        while (enum_iterator.next()) |entry| {
            o.define_type(entry.key_ptr.*);
            var enum_info = entry.value_ptr.*;
            switch (enum_info.type) {
                .normal => o.write("enum(c_int) {\n"),
                .flag => o.write("enum(u32) {\n"),
                .flag_big => o.write("enum(u64) {\n"),
            }
            
            for (enum_info.values.items) |value| {
                o.write("    ");
                if (needs_escape(value.name)) {
                    o.write("@\"");
                }
                o.write_snake_case(value.name, false);
                if (needs_escape(value.name)) {
                    o.write("\"");
                }
                o.print(" = {},\n", .{value.value});
                alloc.free(value.name);
            }
            enum_info.values.deinit(alloc);
            
            o.write("    _,\n");
            o.write_char('}');
            o.end_of_line();
            alloc.free(entry.key_ptr.*);
        }
        o.enums.deinit(alloc);
        
        o.write("pub const Core_version = ");
        o.write("enum {\n");
        for (o.core_versions.items) |*core_version| {
            o.write("    ");
            o.write_value(core_version.name);
            o.write(",\n");
        }
        o.write("}");
        o.end_of_line();
        
        o.write("pub const Instance_extension = ");
        o.write("enum {\n");
        for (o.instance_extensions.items) |*extension| {
            o.write("    ");
            o.write_value(extension.name);
            o.write(",\n");
        }
        o.write("}");
        o.end_of_line();
        
        o.write("pub const Device_extension = ");
        o.write("enum {\n");
        for (o.device_extensions.items) |*extension| {
            o.write("    ");
            o.write_extension_name(extension.name);
            o.write(",\n");
        }
        o.write("}");
        o.end_of_line();
        
        o.write("pub const extension_commands = ");
        o.write("struct {\n");
        for (o.core_versions.items) |*extension| {
            extension.write_commands(o);
        }
        for (o.instance_extensions.items) |*extension| {
            extension.write_commands(o);
        }
        for (o.device_extensions.items) |*extension| {
            extension.write_commands(o);
        }
        o.write("}");
        o.end_of_line();
        
        o.write("pub const Global_commands = extern struct {\n");
        o.print_commands_of_type(.global);
        o.write("}");
        o.end_of_line();
        
        o.write("pub const Instance_commands = extern struct {\n");
        o.print_commands_of_type(.instance);
        o.write("}");
        o.end_of_line();
        
        o.write("pub const Device_commands = extern struct {\n");
        o.print_commands_of_type(.device);
        o.write("}");
        o.end_of_line();
        
        
        set_duplicate(&o.current_name, null);
        set_duplicate(&o.current_type, null);
        set_duplicate(&o.current_length, null);
        set_duplicate(&o.current_return_type, null);
        std.debug.assert(o.tree.items.len == 0);
        o.tree.deinit(alloc);
        
        var commands_iterator = o.commands.iterator();
        while (commands_iterator.next()) |entry| {
            alloc.free(entry.key_ptr.*);
        }
        o.commands.deinit(alloc);
        
        for (o.suffixes.items) |suffix| {
            alloc.free(suffix);
        }
        o.suffixes.deinit(alloc);
        
        var aliases_iterator = o.aliases.iterator();
        while (aliases_iterator.next()) |alias| {
            alloc.free(alias.key_ptr.*);
            alloc.free(alias.value_ptr.*);
        }
        o.aliases.deinit(alloc);
        
        for (o.core_versions.items) |*extension| {
            extension.deinit();
        }
        o.core_versions.deinit(alloc);
        for (o.instance_extensions.items) |*extension| {
            extension.deinit();
        }
        o.instance_extensions.deinit(alloc);
        for (o.device_extensions.items) |*extension| {
            extension.deinit();
        }
        o.device_extensions.deinit(alloc);
        
        o.stream.flush() catch @panic("write error");
    }
    
    fn print_commands_of_type(o: *Outputter, required_type: Command_type) void {
        var commands_iterator = o.commands.iterator();
        while (commands_iterator.next()) |entry| {
            const command = entry.value_ptr.*;
            if (command.type == required_type) {
                o.write("    ");
                o.write_command_name(entry.key_ptr.*);
                o.write(": *const ");
                o.write_command_name(entry.key_ptr.*);
                o.write(".function,\n");
            }
        }
    }
    
    pub fn open(o: *Outputter, tag: []const u8, props: *const PropMap) void {
        if (debug) {
            std.debug.print(">", .{});
            for (0..o.intent) |_| {
                std.debug.print("  ", .{});
            }
            std.debug.print("Open: {s}\n", .{tag});
            
            var props_iterator = props.iterator();
            while (props_iterator.next()) |entry| {
                std.debug.print(" ", .{});
                for (0..o.intent) |_| {
                    std.debug.print("  ", .{});
                }
                std.debug.print(">{s} = {s}\n", .{entry.key_ptr.*, entry.value_ptr.*});
            }
        }
        
        const taginfo = Tag {
            .name = tag,
            .props = props.*,
        };
        if (strings_equal(tag, "tag")) {
            const suffix = alloc.dupe(u8, props.get("name") orelse @panic("tag without name")) catch @panic("no memory");
            o.suffixes.append(alloc, suffix) catch @panic("no memory");
        } else if (is_a_type(&taginfo)) {
            o.reset_current_type();
            
            if (props.get("category")) |category| {
                if (strings_equal(category, "struct")) {
                    if (!props.contains("alias")) {
                        const name = props.get("name").?;
                        o.define_type(name);
                        o.write("extern struct {\n");
                    }
                } else if (strings_equal(category, "union")) {
                    if (!props.contains("alias")) {
                        const name = props.get("name").?;
                        o.define_type(name);
                        o.write("extern union {\n");
                    }
                } else if (strings_equal(category, "enum")) {
                    if (!props.contains("alias")) {
                        const name = props.get("name").?;
                        if (!o.enums.contains(name)) {
                            const key = alloc.dupe(u8, name) catch @panic("no memory");
                            o.enums.put(alloc, key, .{
                                .type = .normal,
                                .values = .empty,
                            }) catch @panic("no memory");
                        }
                    }
                } else if (strings_equal(category, "funcpointer")) {
                    if (!props.contains("alias")) {
                        set_duplicate(&o.current_return_type, null);
                    }
                }
            }
        } else if (strings_equal(tag, "type")) {
            if (props.get("requires")) |requires| {
                if (!strings_equal(requires, "vk_platform")) {
                    if (props.get("name")) |name| {
                        o.define_type(name);
                        o.write("*anyopaque");
                        o.end_of_line();
                    }
                }
            }
        } else if (strings_equal(tag, "enum")) {
            if (o.last_tag()) |last| {
                if (strings_equal(last.name, "enums")) {
                    if (!props.contains("alias")) {
                        const name = props.get("name").?;
                        if (strings_equal(last.props.get("type").?, "constants")) {
                            if (!strings_equal(name, "VK_TRUE") and !strings_equal(name, "VK_FALSE")) {
                                const c_type = props.get("type").?;
                                var value_str = props.get("value").?;
                                var inverted = false;
                                if (std.mem.startsWith(u8, value_str, "(~")) {
                                    value_str = value_str[2..];
                                    inverted = true;
                                } else if (std.mem.startsWith(u8, value_str, "~")) {
                                    value_str = value_str[1..];
                                    inverted = true;
                                }
                                o.write_doc_url(name);
                                o.write("pub const ");
                                o.write_command_name(name);
                                var end: usize = 0;
                                while (end < value_str.len) {
                                    if (std.ascii.isAlphabetic(value_str[end])) {
                                        break;
                                    }
                                    end += 1;
                                }
                                const num_str = value_str[0..end];
                                if (inverted) {
                                    o.write(" = ~@as(");
                                    o.write_c_type_name(c_type);
                                    o.write(", ");
                                    o.write(num_str);
                                    o.write(")");
                                } else {
                                    o.write(": ");
                                    o.write_c_type_name(c_type);
                                    o.write(" = ");
                                    o.write(num_str);
                                }
                                o.end_of_line();
                            }
                        } else {
                            const enum_name = last.props.get("name").?;
                            var value: i64 = undefined;
                            if (props.get("value")) |value_str| {
                                if (std.mem.startsWith(u8, value_str, "0x")) {
                                    value = std.fmt.parseInt(i64, value_str[2..], 16) catch @panic("invalid number");
                                } else {
                                    value = std.fmt.parseInt(i64, value_str, 10) catch @panic("invalid number");
                                }
                            } else if (props.get("bitpos")) |bitpos_str| {
                                const bitpos = std.fmt.parseInt(u6, bitpos_str, 10) catch @panic("invalid number");
                                value = @intCast(@as(u64, 1) << bitpos);
                            } else {
                                @panic("invalid enum value");
                            }
                            
                            const enum_info = o.enums.getPtr(enum_name).?;
                            enum_info.values.append(alloc, .{
                                .name = alloc.dupe(u8, o.enum_value_name(enum_name, name)) catch @panic("no memory"),
                                .value = value,
                            }) catch @panic("no memory");
                        }
                    }
                } else if (strings_equal(last.name, "require")) {
                    if (!props.contains("alias")) {
                        if (o.tag_up(2)) |parent| {
                            const name = props.get("name").?;
                            if (props.get("extends")) |enum_name| {
                                if (!o.enums.contains(enum_name)) {
                                    const key = alloc.dupe(u8, enum_name) catch @panic("no memory");
                                    o.enums.put(alloc, key, .{
                                        .type = .normal,
                                        .values = .empty,
                                    }) catch @panic("no memory");
                                }
                                
                                var value: i64 = undefined;
                                if (props.get("value")) |value_str| {
                                    value = std.fmt.parseInt(i64, value_str, 10) catch @panic("invalid number");
                                } else if (props.get("bitpos")) |bitpos_str| {
                                    const bitpos = std.fmt.parseInt(u6, bitpos_str, 10) catch @panic("invalid number");
                                    value = @intCast(@as(u64, 1) << bitpos);
                                } else if (props.get("offset")) |offset_str| {
                                    const offset = std.fmt.parseInt(i64, offset_str, 10) catch @panic("invalid number");
                                    var extension: ?i64 = null;
                                    if (props.get("extnumber")) |extnumber| {
                                        extension = std.fmt.parseInt(i64, extnumber, 10) catch @panic("invalid number");
                                    } else if (strings_equal(parent.name, "extension")) {
                                        if (parent.props.get("number")) |extension_number| {
                                            extension = std.fmt.parseInt(i64, extension_number, 10) catch @panic("invalid number");
                                        }
                                    }
                                    
                                    value = offset;
                                    if (extension) |extension_add| {
                                        value += 1000000000 + 1000 * (extension_add - 1);
                                    }
                                    if (props.get("dir")) |dir| {
                                        if (strings_equal(dir, "-")) {
                                            value = -value;
                                        }
                                    }
                                } else {
                                    @panic("invalid enum");
                                }
                                
                                const value_name = o.enum_value_name(enum_name, name);
                                const enum_info = o.enums.getPtr(enum_name).?;
                                const already_present = for (enum_info.values.items) |enum_value| {
                                    if (strings_equal(enum_value.name, value_name)) {
                                        break true;
                                    }
                                } else false;
                                if (!already_present) {
                                    enum_info.values.append(alloc, .{
                                        .name = alloc.dupe(u8, value_name) catch @panic("no memory"),
                                        .value = value,
                                    }) catch @panic("no memory");
                                }
                            } else {
                                // constant
                            }
                        }
                    }
                }
            }
        } else if (strings_equal(tag, "enums")) {
            const enum_type = props.get("type").?;
            if (strings_equal(enum_type, "enum") or strings_equal(enum_type, "bitmask")) {
                const enum_name = props.get("name").?;
                if (!o.enums.contains(enum_name)) {
                    const key = alloc.dupe(u8, enum_name) catch @panic("no memory");
                    o.enums.put(alloc, key, .{
                        .type = .normal,
                        .values = .empty,
                    }) catch @panic("no memory");
                }
            }
        } else if (strings_equal(tag, "feature")) {
            if (is_valid_api(props) and props.contains("number")) {
                const name = props.get("name").?;
                const extension = o.core_versions.addOne(alloc) catch @panic("no memory");
                o.current_extension = extension;
                extension.name = alloc.dupe(u8, name) catch @panic("no memory");
                extension.commands = std.ArrayList([]const u8).initCapacity(alloc, 16) catch @panic("no memory");
            }
        } else if (strings_equal(tag, "extension")) {
            if (is_valid_api(props)) {
                const name = props.get("name").?;
                var extension: *Extension = undefined;
                const extension_type = props.get("type").?;
                if (strings_equal(extension_type, "instance")) {
                    extension = o.instance_extensions.addOne(alloc) catch @panic("no memory");
                } else if (strings_equal(extension_type, "device")) {
                    extension = o.device_extensions.addOne(alloc) catch @panic("no memory");
                } else {
                    @panic("Wrong extension type");
                }
                o.current_extension = extension;
                extension.name = alloc.dupe(u8, name) catch @panic("no memory");
                extension.commands = std.ArrayList([]const u8).initCapacity(alloc, 16) catch @panic("no memory");
            }
        } else if (strings_equal(tag, "command")) {
            const require = o.last_tag().?;
            if (strings_equal(require.name, "require") and is_valid_api(&require.props)) {
                const extension_tag = o.tag_up(2).?;
                if (is_valid_api(&extension_tag.props)) {
                    const command_name = props.get("name").?;
                    const duped = alloc.dupe(u8, command_name) catch @panic("no memory");
                    o.current_extension.commands.append(alloc, duped) catch @panic("no memory");
                    if (o.commands.getPtr(command_name)) |command_entry| {
                        command_entry.use = true;
                    }
                }
            }
        }
        
        o.intent += 1;
        var props_map = PropMap.empty;
        var props_iterator = props.iterator();
        while (props_iterator.next()) |entry| {
            const name = alloc.dupe(u8, entry.key_ptr.*) catch @panic("no memory");
            const value = alloc.dupe(u8, entry.value_ptr.*) catch @panic("no memory");
            props_map.put(alloc, name, value) catch @panic("no memory");
        }
        const info = Tag {
            .name = alloc.dupe(u8, tag) catch @panic("no memory"),
            .props = props_map,
        };
        o.tree.append(alloc, info) catch @panic("no memory");
    }
    
    pub fn close(o: *Outputter, tag: []const u8) void {
        o.intent -= 1;
        if (debug) {
            std.debug.print(">", .{});
            for (0..o.intent) |_| {
                std.debug.print("  ", .{});
            }
            std.debug.print("Close: {s}\n", .{tag});
        }
        
        if (o.last_tag()) |last| {
            if (strings_equal(last.name, "type")) {
                if (last.props.get("category")) |category| {
                    if (is_valid_api(&last.props)) {
                        if (last.props.get("alias")) |alias| {
                            if (last.props.get("name")) |name| {
                                const key = alloc.dupe(u8, name) catch @panic("no memory");
                                const value = alloc.dupe(u8, alias) catch @panic("no memory");
                                o.aliases.put(alloc, key, value) catch @panic("no memory");
                            }
                        } else if (strings_equal(category, "struct") or strings_equal(category, "union")) {
                            if (!last.props.contains("alias")) {
                                o.write("}");
                                o.end_of_line();
                            }
                        } else if (strings_equal(category, "funcpointer")) {
                            const return_type = o.current_return_type orelse "void";
                            o.write(") callconv(.c) ");
                            if (strings_equal(return_type, "void")) {
                                o.write("void");
                            } else if (std.mem.endsWith(u8, return_type, "*")) {
                                o.write("*");
                                o.write_c_type_name(return_type[0 .. return_type.len - 1]);
                            } else if (strings_equal(return_type, "PFN_vkVoidFunction")){
                                o.write("?Void_function_fn");
                            } else {
                                o.write_c_type_name(return_type);
                            }
                            o.end_of_line();
                        } else if (o.current_name) |name| {
                            if (o.current_type) |c_type| {
                                if (strings_equal(category, "basetype")) {
                                    var skip = false;
                                    if (strings_equal(name, "VkBool32")) {
                                        skip = true;
                                    } else if (strings_equal(name, "VkFlags")) {
                                        skip = true;
                                    }
                                    if (!skip) {
                                        o.define_type(name);
                                        o.write_c_type(.definition);
                                        o.end_of_line();
                                    }
                                } else if (strings_equal(category, "bitmask")) {
                                    if (strings_equal(c_type, "VkFlags")) { // 32 bit
                                        o.define_type(name);
                                        if (last.props.get("requires")) |based_on| {
                                            o.write("Flags(");
                                            o.write_c_type_name(based_on);
                                            o.write(")");
                                            
                                            if (o.enums.getPtr(based_on)) |enum_info| {
                                                enum_info.type = .flag;
                                            } else {
                                                const key = alloc.dupe(u8, based_on) catch @panic("no memory");
                                                o.enums.put(alloc, key, .{
                                                    .type = .flag,
                                                    .values = .empty,
                                                }) catch @panic("no memory");
                                            }
                                        } else {
                                            o.write("Empty_flags(u32)");
                                        }
                                        o.end_of_line();
                                    } else if (strings_equal(c_type, "VkFlags64")) { // 64 bit
                                        o.define_type(name);
                                        if (last.props.get("bitvalues")) |based_on| {
                                            o.write("Flags(");
                                            o.write_c_type_name(based_on);
                                            o.write(")");
                                            
                                            if (o.enums.getPtr(based_on)) |enum_info| {
                                                enum_info.type = .flag_big;
                                            } else {
                                                const key = alloc.dupe(u8, based_on) catch @panic("no memory");
                                                o.enums.put(alloc, key, .{
                                                    .type = .flag_big,
                                                    .values = .empty,
                                                }) catch @panic("no memory");
                                            }
                                        } else {
                                            o.write("Empty_flags(u64)");
                                        }
                                        o.end_of_line();
                                    } else {
                                        @panic("Invalid bitmask type");
                                    }
                                } else if (strings_equal(category, "handle")) {
                                    o.define_type(name);
                                    if (strings_equal(c_type, "VK_DEFINE_HANDLE")) {
                                        o.write("*opaque {}");
                                    } else if (strings_equal(c_type, "VK_DEFINE_NON_DISPATCHABLE_HANDLE")) {
                                        o.write("u64");
                                    } else {
                                        @panic("Invalid handle type");
                                    }
                                    o.end_of_line();
                                }
                            } else if (strings_equal(category, "basetype")) {
                                o.define_type(name);
                                o.write("opaque {}");
                                o.end_of_line();
                            }
                        }
                    }
                }
            } else if (strings_equal(last.name, "member")) {
                if (is_valid_api(&last.props)) {
                    o.write("    ");
                    const name = o.current_name.?;
                    if (strings_equal(name, "sType")) {
                        o.write("_struct_type: ");
                        o.write_c_type(.field);
                        if (last.props.get("values")) |value| {
                            o.write(" = .");
                            o.write_snake_case(o.enum_value_name(o.current_type.?, value), false);
                        }
                        o.write(",\n");
                    } else if (strings_equal(name, "pNext")) {
                        o.write("next: ");
                        o.write_c_type(.field);
                        o.write(" = null,\n");
                    } else if (strings_equal(name, "flags") and if (last.props.get("optional")) |optional_val| strings_equal(optional_val, "true") else false) {
                        o.write("flags: ");
                        o.write_c_type(.field);
                        o.write(" = .empty(),\n");
                    } else {
                        var stripped = name;
                        const prefixes = [_][]const u8 {
                            "p", // pointer
                            "pp", // pointer to pointer
                            "pfn", // pointer to function
                        };
                        var append_pp = false;
                        for (prefixes) |prefix| {
                            if (name.len >= prefix.len + 1 and std.mem.startsWith(u8, name, prefix) and std.ascii.isUpper(name[prefix.len])) {
                                stripped = name[prefix.len ..];
                                if (strings_equal(prefix, "pp")) {
                                    append_pp = true;
                                }
                                break;
                            }
                        }
                        if (needs_escape(stripped)) {
                            o.write("@\"");
                        }
                        o.write_snake_case(stripped, false);
                        if (append_pp) {
                            o.write("_pp");
                        }
                        if (needs_escape(stripped)) {
                            o.write("\"");
                        }
                        o.write(": ");
                        o.write_c_type(.field);
                        o.write(",\n");
                    }
                }
            } else if (strings_equal(last.name, "proto")) {
                const command_tag = o.tag_up(2).?;
                if (strings_equal(command_tag.name, "command") and is_valid_api(&command_tag.props)) {
                    set_duplicate(&o.current_return_type, o.current_type.?);
                    const command_name = o.current_name.?;
                    o.write_doc_url(command_name);
                    o.write("pub const ");
                    o.write_command_name(command_name);
                    o.write(" = Command {\n");
                    o.write("    .name = \"");
                    o.write(command_name);
                    o.write("\",\n");
                    o.write("    .errors = error {\n");
                    if (command_tag.props.get("successcodes")) |successcodes| {
                        var tokens = std.mem.tokenizeScalar(u8, successcodes, ',');
                        while (tokens.next()) |token| {
                            if (!strings_equal(token, "VK_SUCCESS")) {
                                o.write("        ");
                                o.write_error_name(token);
                                o.write(",\n");
                            }
                        }
                    }
                    if (command_tag.props.get("errorcodes")) |errorcodes| {
                        var tokens = std.mem.tokenizeScalar(u8, errorcodes, ',');
                        while (tokens.next()) |token| {
                            o.write("        ");
                            o.write_error_name(token);
                            o.write(",\n");
                        }
                    }
                    o.write("    },\n");
                    o.write("    .function = fn(\n");
                    const name_dup = alloc.dupe(u8, command_name) catch @panic("no memory");
                    o.commands.put(alloc, name_dup, .{
                        .use = false,
                        .type = .global,
                    }) catch @panic("no memory");
                    const command = o.commands.getPtr(name_dup).?;
                    o.check_command_type = &command.type;
                }
            } else if (strings_equal(last.name, "param")) {
                if (is_valid_api(&last.props)) {
                    const command_tag = o.tag_up(2).?;
                    if (strings_equal(command_tag.name, "command") and is_valid_api(&command_tag.props)) {
                        o.write("        ");
                        o.write_value(o.current_name.?);
                        o.write(": ");
                        o.write_c_type(.argument);
                        o.write(",\n");
                        if (o.check_command_type) |command_type| {
                            defer o.check_command_type = null;
                            if (!o.current_is_pointer) {
                                const c_type = o.current_type.?;
                                if (strings_equal(c_type, "VkInstance") or strings_equal(c_type, "VkPhysicalDevice")) {
                                    command_type.* = .instance;
                                } else if (strings_equal(c_type, "VkDevice") or strings_equal(c_type, "VkQueue") or strings_equal(c_type, "VkCommandBuffer") or strings_equal(c_type, "VkExternalComputeQueueNV")) {
                                    command_type.* = .device;
                                }
                            }
                        }
                    }
                }
            } else if (strings_equal(last.name, "command")) {
                const parent = o.tag_up(2).?;
                if (strings_equal(parent.name, "commands") and is_valid_api(&last.props)) {
                    if (last.props.get("alias")) |alias| {
                        const name = last.props.get("name").?;
                        o.write_doc_url(name);
                        o.write("pub const ");
                        o.write_command_name(name);
                        o.write(" = ");
                        o.write_command_name(alias);
                        o.end_of_line();
                    } else {
                        o.write("    ) callconv(.c) ");
                        if (strings_equal(o.current_return_type.?, "PFN_vkVoidFunction")){
                            o.write("?Void_function_fn");
                        } else {
                            o.write_c_type_name(o.current_return_type.?);
                        }
                        o.write(",\n}");
                        o.end_of_line();
                    }
                }
            }
        }
        
        var info = o.tree.pop() orelse @panic("too many closing tags");
        alloc.free(info.name);
        var info_props_iterator = info.props.iterator();
        while (info_props_iterator.next()) |entry| {
            alloc.free(entry.key_ptr.*);
            alloc.free(entry.value_ptr.*);
        }
        info.props.deinit(alloc);
    }
    
    pub fn content(o: *Outputter, text: []const u8) void {
        if (debug) {
            std.debug.print(">", .{});
            for (0..o.intent) |_| {
                std.debug.print("  ", .{});
            }
            std.debug.print("Content: {s}\n", .{text});
        }
        
        if (o.last_tag()) |last| {
            if (is_a_type(last)) {
                const is_funcpointer = if (last.props.get("category")) |category| strings_equal(category, "funcpointer") else false;
                if (is_funcpointer) {
                    if (std.mem.startsWith(u8, text, "typedef ") and std.mem.endsWith(u8, text, " (VKAPI_PTR *")) {
                        set_duplicate(&o.current_return_type, text[8 .. text.len - 13]);
                    } else if (std.mem.startsWith(u8, text, ")(")) {
                        if (std.mem.endsWith(u8, text, "const")) {
                            o.current_is_const = true;
                        }
                    } else {
                        var before_comma: []const u8 = undefined;
                        if (std.mem.indexOfScalar(u8, text, ',')) |comma_index| {
                            before_comma = text[0 .. comma_index];
                        } else if (std.mem.endsWith(u8, text, ");")) {
                            before_comma = text[0 .. text.len - 2];
                        } else {
                            @panic("invalid field");
                        }
                        if (text[0] == '*') {
                            o.current_is_pointer = true;
                        }
                        const name = for (before_comma, 0..) |c, i| {
                            if (std.ascii.isAlphabetic(c)) {
                                break before_comma[i..];
                            }
                        } else @panic("no name");
                        o.write("    ");
                        o.write_value(name);
                        o.write(": ");
                        o.write_c_type(.argument);
                        o.write(", \n");
                        
                        o.reset_current_type();
                        if (std.mem.endsWith(u8, text, "const")) {
                            o.current_is_const = true;
                        }
                    }
                } else if (strings_equal(text, "const") or strings_equal(text, "struct")) {
                    o.current_is_const = true;
                } else if (strings_equal(text, "*")) {
                    o.current_is_pointer = true;
                } else if (strings_equal(text, "**")) {
                    o.current_is_pointer = true;
                    o.current_is_double_pointer = true;
                } else if (strings_equal(text, "* const*") or strings_equal(text, "* const *")) {
                    o.current_is_pointer = true;
                    o.current_is_double_pointer = true;
                    o.current_is_double_const = true;
                } else if (strings_equal(text, "[")) {
                    o.current_is_array = true;
                } else if (std.mem.startsWith(u8, text, "[") and std.mem.endsWith(u8, text, "]")) {
                    o.current_is_array = true;
                    set_duplicate(&o.current_length, text[1 .. text.len - 1]);
                }
            } else if (strings_equal(last.name, "type")) {
                if (last.props.count() == 0) {
                    if (o.tag_up(2)) |parent| {
                        if (is_a_type(parent)) {
                            set_duplicate(&o.current_type, text);
                        }
                    }
                }
            } else if (strings_equal(last.name, "name")) {
                if (last.props.count() == 0) {
                    if (o.tag_up(2)) |parent| {
                        if (is_a_type(parent)) {
                            const is_funcpointer = if (parent.props.get("category")) |category| strings_equal(category, "funcpointer") else false;
                            if (is_funcpointer) {
                                o.define_type(text);
                                o.write("*const fn(\n");
                                o.reset_current_type();
                            } else {
                                set_duplicate(&o.current_name, text);
                            }
                        }
                    }
                }
            } else if (strings_equal(last.name, "enum")) {
                if (last.props.count() == 0) {
                    if (o.tag_up(2)) |parent| {
                        if (is_a_type(parent)) {
                            if (o.current_is_array) {
                                set_duplicate(&o.current_length, text);
                            }
                        }
                    }
                }
            }
        }
    }
    
    fn comma_string_contains(haystack: []const u8, comptime needle: []const u8) bool {
        return strings_equal(haystack, needle)
            or std.mem.containsAtLeast(u8, haystack, 1, ","++needle++",")
            or std.mem.startsWith(u8, haystack, needle++",")
            or std.mem.endsWith(u8, haystack, ","++needle);
    }
    
    fn is_valid_api(props: *const PropMap) bool {
        const correct_api = "vulkan";
        if (props.get("api")) |api| {
            return comma_string_contains(api, correct_api);
        } else if (props.get("supported")) |api| {
            return comma_string_contains(api, correct_api);
        } else {
            return true;
        }
    }
    
    fn reset_current_type(o: *Outputter) void {
        set_duplicate(&o.current_name, null);
        set_duplicate(&o.current_type, null);
        o.current_is_const = false;
        o.current_is_pointer = false;
        o.current_is_double_pointer = false;
        o.current_is_double_const = false;
        o.current_is_array = false;
        set_duplicate(&o.current_length, null);
    }
    
    fn is_a_type(tag: *const Tag) bool {
        if (strings_equal(tag.name, "type")) {
            if (tag.props.contains("category")) {
                return true;
            }
        } else if (strings_equal(tag.name, "member")) {
            return true;
        } else if (strings_equal(tag.name, "proto")) {
            return true;
        } else if (strings_equal(tag.name, "param")) {
            return true;
        }
        return false;
    }
    
    fn write_doc_url(o: *Outputter, name: []const u8) void {
        o.write("// https://registry.khronos.org/vulkan/specs/latest/man/html/");
        o.write(name);
        o.write(".html#_name\n");
    }
    
    fn define_type(o: *Outputter, name: []const u8) void {
        o.write_doc_url(name);
        o.write("pub const ");
        o.write_typename(name);
        o.write(" = ");
    }
    
    fn define_value(o: *Outputter, name: []const u8) void {
        o.write_doc_url(name);
        o.write("pub const ");
        o.write_value(name);
        o.write(" = ");
    }
    
    fn end_of_line(o: *Outputter) void {
        o.write(";\n\n");
    }
    
    // VkEnumKHR, VK_ENUM_VALUE_KHR => value
    // VKStructType, VK_STRUCT_TYPE_SURFACE_KHR => surface_khr
    // VkEnumEXT, VK_ENUM_VALUE_BIT_NV => value
    // VkResult, VK_ERROR_DEVICE_LOST => device_lost
    fn enum_value_name(o: *Outputter, name: []const u8, value: []const u8) []const u8 {
        if (std.mem.eql(u8, name, "VkResult") and std.mem.startsWith(u8, value, "VK_ERROR_")) {
            return value[9..];
        }
        
        var prefix = name;
        for (o.suffixes.items) |suffix| {
            if (std.mem.endsWith(u8, name, suffix)) {
                prefix = name[0 .. name.len - suffix.len];
                break;
            }
        }
        var suffix_len: usize = 0;
        if (!strings_equal(name, "VKStructType")) {
            for (o.suffixes.items) |suffix| {
                if (std.mem.endsWith(u8, value, suffix) and value[value.len - suffix.len - 1] == '_') {
                    suffix_len = suffix.len + 1;
                    break;
                }
            }
        }
        if (std.mem.endsWith(u8, prefix, "FlagBits")) {
            prefix = prefix[0 .. prefix.len - 8];
            if (std.mem.endsWith(u8, value[0..value.len - suffix_len], "_BIT")) {
                suffix_len += 4;
            }
        }
        
        
        var index: usize = 0;
        while (true) {
            const c = std.ascii.toLower(value[index]);
            if (c == '_') {
                index += 1;
                continue;
            }
            if (prefix.len == 0) {
                break;
            }
            const should_be = std.ascii.toLower(prefix[0]);
            if (c == should_be) {
                index += 1;
                prefix = prefix[1..];
            } else {
                break;
            }
        }
        
        if (index >= value.len - suffix_len) {
            return value[index ..];
        } else {
            return value[index .. value.len - suffix_len];
        }
    }
    
    const Type_reason = enum {
        definition,
        field,
        argument,
    };
    
    fn write_c_type(o: *Outputter, reason: Type_reason) void {
        const typeinfo = o.last_tag().?;
        var multiple = false;
        var null_terminated = false;
        if (o.current_length) |length| {
            if (reason == .argument) {
                o.write("*");
                if (o.current_is_const) {
                    o.write("const ");
                }
            }
            o.write("[");
            if (std.ascii.isDigit(length[0])) {
                o.write(length);
            } else {
                o.write_command_name(length);
            }
            if (typeinfo.props.get("len")) |len| {
                if (strings_equal(len, "null-terminated")) {
                    o.write("-1:0");
                }
            }
            o.write("]");
        } else {
            if (typeinfo.props.get("len")) |len| {
                if (!strings_equal(len, "1")) {
                    multiple = true;
                    if (strings_equal(len, "null-terminated")) {
                        null_terminated = true;
                    }
                }
            }
        }
        if (typeinfo.props.get("optional")) |optional_val| {
            if (strings_equal(optional_val, "true") or std.mem.startsWith(u8, optional_val, "true,")) {
                if (o.current_is_pointer or strings_equal(o.current_type.?, "VkInstance")) {
                    o.write("?");
                }
            }
        }
        if (o.current_is_pointer) {
            if (multiple) {
                if (null_terminated) {
                    o.write("[*:0]");
                } else {
                    o.write("[*]");
                }
            } else {
                o.write("*");
            }
            if (o.current_is_const) {
                o.write("const ");
            }
        }
        if (o.current_is_double_pointer) {
            var second_multiple = false;
            var second_null_terminated = false;
            if (typeinfo.props.get("len")) |len| {
                if (std.mem.indexOfScalar(u8, len, ',')) |comma| {
                    const last = len[comma + 1 .. len.len];
                    if (!strings_equal(last, "1")) {
                        second_multiple = true;
                        if (strings_equal(last, "null-terminated")) {
                            second_null_terminated = true;
                        }
                    }
                }
            }
            if (second_multiple) {
                if (second_null_terminated) {
                    o.write("[*:0]");
                } else {
                    o.write("[*]");
                }
            } else {
                o.write("*");
            }
            if (o.current_is_double_const) {
                o.write("const ");
            }
        }
        if (o.current_is_pointer and strings_equal(o.current_type.?, "void")) {
            if (multiple) {
                o.write("u8");
            } else if (reason == .definition) {
                o.write("opaque {}");
            } else {
                o.write("anyopaque");
            }
        } else {
            o.write_c_type_name(o.current_type.?);
        }
    }
    
    fn write_c_type_name(o: *Outputter, c_type: []const u8) void {
        if (strings_equal(c_type, "int")) {
            o.write("c_int");
        } else if (strings_equal(c_type, "void")) {
            o.write("void");
        } else if (strings_equal(c_type, "char")) {
            o.write("u8");
        } else if (strings_equal(c_type, "float")) {
            o.write("f32");
        } else if (strings_equal(c_type, "double")) {
            o.write("f64");
        } else if (strings_equal(c_type, "int8_t")) {
            o.write("i8");
        } else if (strings_equal(c_type, "uint8_t")) {
            o.write("u8");
        } else if (strings_equal(c_type, "int16_t")) {
            o.write("i16");
        } else if (strings_equal(c_type, "uint16_t")) {
            o.write("u16");
        } else if (strings_equal(c_type, "uint32_t")) {
            o.write("u32");
        } else if (strings_equal(c_type, "uint64_t")) {
            o.write("u64");
        } else if (strings_equal(c_type, "int32_t")) {
            o.write("i32");
        } else if (strings_equal(c_type, "int64_t")) {
            o.write("i64");
        } else if (strings_equal(c_type, "size_t")) {
            o.write("usize");
        } else {
            o.write_typename(c_type);
        }
    }
    
    fn strip_vk(in: []const u8) []const u8 {
        if (in.len > 6 and std.ascii.eqlIgnoreCase(in[0..6], "pfn_vk")) {
            return in[6..];
        }
        if (in.len > 2 and std.ascii.eqlIgnoreCase(in[0..2], "vk")) {
            if (in.len > 3 and in[2] == '_') {
                return in[3..];
            } else {
                return in[2..];
            }
        }
        return in;
    }
    
    fn write_extension_name(o: *Outputter, name: []const u8) void {
        const without_vk = strip_vk(name);
        o.write_snake_case(without_vk, false);
    }
    
    fn write_command_name(o: *Outputter, name: []const u8) void {
        const without_vk = strip_vk(name);
        var removed_suffix: ?[]const u8 = null;
        const stripped = for (o.suffixes.items) |suffix| {
            if (std.mem.endsWith(u8, without_vk, suffix)) {
                removed_suffix = suffix;
                if (without_vk[without_vk.len - suffix.len - 1] == '_') {
                    break without_vk[0 .. without_vk.len - suffix.len - 1];
                } else {
                    break without_vk[0 .. without_vk.len - suffix.len];
                }
            }
        } else without_vk;
        if (removed_suffix) |suffix| {
            o.write_snake_case(suffix, false);
            o.write("_");
            o.write_snake_case(stripped, false);
        } else {
            o.write_snake_case(stripped, false);
        }
    }
    
    fn write_error_name(o: *Outputter, name: []const u8) void {
        const without_vk = strip_vk(name);
        const stripped = for (o.suffixes.items) |suffix| {
            if (std.mem.endsWith(u8, without_vk, suffix)) {
                if (without_vk[without_vk.len - suffix.len - 1] == '_') {
                    break without_vk[0 .. without_vk.len - suffix.len - 1];
                } else {
                    break without_vk[0 .. without_vk.len - suffix.len];
                }
            }
        } else without_vk;
        if (std.mem.startsWith(u8, stripped, "ERROR_")) {
            o.write_snake_case(stripped[6..], false);
        } else {
            o.write_snake_case(stripped, false);
        }
    }
    
    fn write_value(o: *Outputter, name: []const u8) void {
        o.write_snake_case(strip_vk(name), false);
    }
    
    fn write_typename(o: *Outputter, name: []const u8) void {
        if (o.aliases.get(name)) |alias| {
            o.write_typename(alias);
            return;
        }
        if (std.mem.startsWith(u8, name, "PFN_")) {
            o.write_typename(name[4..]);
            o.write("_fn");
            return;
        }
        const stripped = strip_vk(name);
        
        if (strings_equal(stripped, "Bool32")) {
            o.write("Bool");
        } else {
            var removed_suffix: ?[]const u8 = null;
            const suffix_len = for (o.suffixes.items) |suffix| {
                if (std.mem.endsWith(u8, stripped, suffix)) {
                    removed_suffix = suffix;
                    if (stripped[stripped.len - suffix.len - 1] == '_') {
                        break suffix.len + 1;
                    } else {
                        break suffix.len;
                    }
                }
            } else 0;
            const removed = stripped[0 .. stripped.len - suffix_len];
            const has_suffix = suffix_len > 0;
            if (has_suffix) {
                o.write_snake_case(stripped[stripped.len - suffix_len .. stripped.len], true);
                o.write_char('_');
            }
            if (std.mem.endsWith(u8, removed, "FlagBits")) {
                o.write_snake_case(removed[0 .. removed.len - 8], !has_suffix);
                o.write("_flag_option");
            } else if (std.mem.endsWith(u8, removed, "FlagBits2") or std.mem.endsWith(u8, removed, "FlagBits3") or std.mem.endsWith(u8, removed, "FlagBits4")) {
                o.write_snake_case(removed[0 .. removed.len - 9], !has_suffix);
                o.write("_flag_option_");
                o.write_char(removed[removed.len - 1]);
            } else {
                o.write_snake_case(removed, !has_suffix);
            }
        }
    }
    
    const Chartype = enum {
        lower,
        upper,
        digit,
        underscore,
        
        fn detect(c: u8) Chartype {
            return switch(c) {
                'a'...'z' => .lower,
                'A'...'Z' => .upper,
                '0'...'9' => .digit,
                '_' => .underscore,
                else => @panic("invalid character"),
            };
        }
    };
    
    // aBCde -> a_b_cde
    // aBCDe -> a_bc_de
    // aBCD  -> a_bcd
    // a3dView -> a_3d_view
    // a3dayView -> a_3_day_view
    fn write_snake_case(o: *Outputter, text: []const u8, first_upper: bool) void {
        if (std.mem.containsAtLeastScalar(u8, text, 1, '_')) {
            // Already is snake_case
            var is_first = first_upper;
            for (text) |c| {
                if (is_first) {
                    is_first = false;
                    o.write_char(std.ascii.toUpper(c));
                } else {
                    o.write_char(std.ascii.toLower(c));
                }
            }
            return;
        }
        
        var is_first = first_upper;
        var previous = Chartype.underscore;
        var hold: ?u8 = null; // we put uppercase on hold when it comes after uppercase
        // hold can mean:
        //  -  uppercase after uppercase
        //  -  letter after digit
        
        for (text) |c| {
            const ctype = Chartype.detect(c);
            if (hold) |holded| {
                if (previous == .upper) {
                    if (ctype == .lower) {
                        o.write_char('_');
                    }
                } else if (previous == .digit) {
                    if (ctype == .lower) {
                        o.write_char('_');
                    } else if (std.ascii.isUpper(holded) and ctype == .upper) {
                        o.write_char('_');
                    }
                } else {
                    unreachable;
                }
                o.write_char(std.ascii.toLower(holded));
                previous = Chartype.detect(holded);
                hold = null;
            }
            var printc: ?u8 = null;
            switch (ctype) {
                .lower => {
                    if (previous == .digit) {
                        hold = c;
                    } else {
                        printc = c;
                    }
                },
                .upper => {
                    switch (previous) {
                        .lower => {
                            o.write_char('_');
                            printc = c;
                        },
                        .upper => {
                            hold = c;
                        },
                        .digit => {
                            hold = c;
                        },
                        .underscore => {
                            printc = c;
                        },
                    }
                },
                .digit => {
                    switch (previous) {
                        .lower => {
                            o.write_char('_');
                            printc = c;
                        },
                        .upper => {
                            o.write_char('_');
                            printc = c;
                        },
                        .digit => {
                            printc = c;
                        },
                        .underscore => {
                            printc = c;
                        },
                    }
                },
                .underscore => {
                    printc = c;
                }
            }
            
            if (printc) |print_char| {
                if (is_first and first_upper) {
                    o.write_char(std.ascii.toUpper(print_char));
                } else {
                    o.write_char(std.ascii.toLower(print_char));
                }
                
                previous = ctype;
            }
            is_first = false;
        }
        if (hold) |holded| {
            o.write_char(std.ascii.toLower(holded));
        }
    }
    
    const keywords = [_][]const u8{
        "addrspace",
        "align",
        "allowzero",
        "and",
        "anyframe",
        "anytype",
        "asm",
        "break",
        "callconv",
        "catch",
        "comptime",
        "const",
        "continue",
        "defer",
        "else",
        "enum",
        "errdefer",
        "error",
        "export",
        "extern",
        "fn",
        "for",
        "if",
        "inline",
        "linksection",
        "noalias",
        "noinline",
        "nosuspend",
        "opaque",
        "or",
        "orelse",
        "packed",
        "pub",
        "resume",
        "return",
        "struct",
        "suspend",
        "switch",
        "test",
        "threadlocal",
        "try",
        "union",
        "unreachable",
        "var",
        "volatile",
        "while",
    };
    
    fn needs_escape(string: []const u8) bool {
        for (keywords) |keyword| {
            if (std.ascii.eqlIgnoreCase(string, keyword)) {
                return true;
            }
        }
        if (string.len == 0) {
            return true;
        } else if (std.ascii.isDigit(string[0])) {
            return true;
        } else {
            return false;
        }
    }
    
    fn last_tag(o: *Outputter) ?*Tag {
        return o.tag_up(1);
    }
    
    fn tag_up(o: *Outputter, count: usize) ?*Tag {
        if (o.tree.items.len >= count) {
            const index = o.tree.items.len - count;
            return &o.tree.items[index];
        } else {
            return null;
        }
    }
    
    fn set_duplicate(value: *?[]const u8, new: ?[]const u8) void {
        if (value.*) |to_free| {
            alloc.free(to_free);
        }
        if (new) |to_dupe| {
            value.* = alloc.dupe(u8, to_dupe) catch @panic("no memory");
        } else {
            value.* = null;
        }
    }
};

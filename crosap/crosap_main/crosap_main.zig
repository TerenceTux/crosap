const u = @import("util");
const builtin = @import("builtin");
const std = @import("std");
const app_activities = @import("app").activities;
const Crosap = @import("crosap").Crosap;
const crosap_api = @import("crosap_api");
const Button_state = crosap_api.Button_state;
const Button_type = crosap_api.Button_type;
const Pointer = crosap_api.Pointer;
const ui = @import("crosap").ui;
const activity = @import("crosap").activity;

const init_activity_data: []const u8 = b: {
    var data = u.List(u8).create();
    var writer = data.writer();
    var bit_writer = u.serialize.create_bit_writer(8, u.writer(u8).static(&writer));
    var exporter = u.serialize.create_exporter(u.serialize.bit_writer.static(&bit_writer));
    exporter.write(@as([]const u8, "main"));
    bit_writer.deinit();
    break:b &u.comptime_slice_to_array(data.convert_to_slice());
};

pub const Crosap_main = struct {
    cr: Crosap,
    last_update: u.Real,
    activity: activity.Dynamic_interface,
    
    pub fn init(main: *Crosap_main) void {
        u.init();
        
        u.log("Welcome to crosap.");
        switch (builtin.mode) {
            .Debug => u.log("Running in DEBUG mode. Performance will be bad!"),
            .ReleaseSafe => std.debug.print("WARNING: running in ReleaseSafe mode, which can have lower performance, because a lot of runtime checks are enabled. Consider using ReleaseFast.", .{}),
            .ReleaseFast => {},
            .ReleaseSmall => std.debug.print("WARNING: running in ReleaseSmall mode, which can have lower performance, because not all performance optimizations are applied. Consider using ReleaseFast.", .{}),
        }
        u.log("This mode is intended for developing or debugging. When you just want to run the application, use the -Drelease build flag.");
        
        u.log(.{"Built for ",@tagName(builtin.cpu.arch)," (", @sizeOf(usize)*8, " bit ",builtin.cpu.arch.endian()," endian)"});
        
        u.log_start(.{"Crosap init"});
        main.cr.init();
        u.log_end(.{"Crosap init"});
        
        u.log_start(.{"Main activity init"});
        var reader = u.Slice_reader(u8).create(init_activity_data);
        var bit_reader = u.serialize.create_bit_reader(8, u.reader(u8).static(&reader));
        main.activity = create_activity_from_bits(u.serialize.bit_reader.dynamic(&bit_reader));
        u.log_end(.{"Main activity init"});
        
        main.last_update = u.time_seconds();
    }
    
    pub fn deinit(main: *Crosap_main) void {
        u.log_start(.{"App deinit"});
        main.activity.deinit(&main.cr);
        main.activity.free();
        u.log_end(.{"App deinit"});
        
        u.log_start(.{"Crosap deinit"});
        main.cr.deinit();
        u.log_end(.{"Crosap deinit"});
        
        u.deinit();
    }
    
    pub fn update(main: *Crosap_main) void {
        u.log_start(.{"Frame update"});
        const now = u.time_seconds();
        const dtime = now.subtract(main.last_update);
        main.last_update = now;
        u.log_start(.{"Stepping ",dtime," ms"});
        const root_element = main.activity.root_element(&main.cr);
        u.log_end(.{"Stepping"});
        
        if (main.cr.new_frame()) |draw_context| {
            root_element.update(&main.cr, dtime, draw_context.area.size);
            const gen_element = root_element.get_element();
            gen_element.frame(draw_context);
            main.cr.end_frame();
        }
        u.log_end(.{});
    }
    
    pub fn button_update(main: *Crosap_main, button: Button_type, state: Button_state) void {
        u.log_start(.{"Button ",button," is now ",state});
        // TODO
        _ = main;
        u.log_end(.{"Button update handled"});
    }
    
    pub fn pointer_start(main: *Crosap_main, pointer: *const Pointer) void {
        u.log_start(.{"New pointer ",@intFromPtr(pointer)});
        pointer.log_state();
        // TODO
        _ = main;
        u.log_end(.{"New pointer handled"});
    }
    
    pub fn pointer_update(main: *Crosap_main, pointer: *const Pointer) void {
        u.log_start(.{"Pointer ",@intFromPtr(pointer)," updated"});
        pointer.log_state();
        // TODO
        _ = main;
        u.log_end(.{"Pointer update handled"});
    }
    
    pub fn pointer_scroll(main: *Crosap_main, pointer: *const Pointer, offset: u.Vec2r) void {
        u.log_start(.{"Pointer ",@intFromPtr(pointer)," scroll: ",offset});
        pointer.log_state();
        // TODO
        _ = main;
        u.log_end(.{"Pointer scroll handled"});
        
    }
    
    pub fn pointer_stop(main: *Crosap_main, pointer: *const Pointer) void {
        u.log_start(.{"Pointer ",@intFromPtr(pointer)," disappeared"});
        pointer.log_state();
        // TODO
        _ = main;
        u.log_end(.{"Pointer disappear handled"});
    }
};


pub fn create_activity_from_bits(reader: u.serialize.bit_reader.Dynamic_interface) activity.Dynamic_interface {
    var importer = u.serialize.create_importer(reader);
    const name = importer.read([]const u8);
    defer u.free_slice(name);
    const app_activity_fields = @typeInfo(app_activities).@"struct".decls;
    inline for (app_activity_fields) |field| {
        if (u.bytes_equal(field.name, name)) {
            const Activity = @field(app_activities, field.name);
            const new_activity = u.alloc_single(Activity);
            new_activity.init_from_data(reader);
            return activity.dynamic(new_activity);
        }
    }
    std.debug.panic("unknown activity {s}", .{name});
}

pub fn export_activity_to_bits(act: anytype, writer: anytype) void {
    activity.validate(act);
    var exporter = u.serialize.create_importer(writer);
    // The hard part is determining the name of this activity
    if (@TypeOf(act) == activity.Dynamic_interface) {
        const deinit_fn = act.imp.fns.deinit;
        const name: []const u8 = activity_name_map.get(deinit_fn) orelse @panic("tried to export an unknown activity");
        exporter.write(name);
    } else {
        const activity_imp = act.imp.imp;
        const name: []const u8 = name_of_activity(activity_imp) orelse @panic("tried to export an unknown activity");
        exporter.write(name);
    }
    act.export_data(writer);
}

fn name_of_activity(Activity: type) ?[]const u8 {
    const app_activity_fields = @typeInfo(app_activities).@"struct".decls;
    inline for (app_activity_fields) |field| {
        if (field.type == Activity) {
            return field.name;
        }
    }
    return null;
}

// We use the deinit function to lookup
const activity_name_map = b: {
    const Activity_map = u.Static_map(*anyopaque, []const u8);
    const app_activity_fields = @typeInfo(app_activities).@"struct".decls;
    var map_items: [app_activity_fields.len]Activity_map.KV = undefined;
    for (&map_items, app_activity_fields) |*item, field| {
        const Activity = @field(app_activities, field.name);
        item.* = .{
            .key = &Activity.deinit,
            .value = field.name,
        };
    }
    break:b Activity_map.create(map_items);
};

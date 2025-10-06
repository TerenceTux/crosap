const u = @import("util");
const builtin = @import("builtin");
const std = @import("std");
const app_activities = @import("app").activities;
const Crosap = @import("crosap").Crosap;
const crosap_api = @import("crosap_api");
const Key = crosap_api.Key;
const Pointer = crosap_api.Pointer;
const ui = @import("crosap").ui;
const activity = @import("crosap").activity;
const Dynamic_element = ui.element.Dynamic_interface;

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
    pointers: u.Map(*const Pointer, Pointer_info),
    
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
        
        main.pointers.init_with_capacity(4);
        
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
        var pointers = main.pointers.iterator_ptr();
        while (pointers.next()) |entry| {
            main.pointer_stop(entry.key);
        }
        
        u.log_start(.{"App deinit"});
        main.activity.deinit(&main.cr);
        main.activity.free();
        u.log_end(.{"App deinit"});
        
        u.log_start(.{"Crosap deinit"});
        main.cr.deinit();
        u.log_end(.{"Crosap deinit"});
        
        main.pointers.deinit();
        
        u.deinit();
    }
    
    pub fn update(main: *Crosap_main) void {
        u.log_start(.{"Check for input update"});
        var pointers = main.pointers.iterator_ptr();
        while (pointers.next()) |entry| {
            const pointer_info = entry.value;
            if (pointer_info.active) {
                if (pointer_info.click_handler) |handler| {
                    if (u.time_nanoseconds() - pointer_info.start_time >= 500_000_000) {
                        handler.long();
                        pointer_info.click_handler = null;
                    }
                }
            }
        }
        u.log_end(.{});
        
        const now = u.time_seconds();
        u.log_start(.{"Frame update"});
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
        main.cr.to_scroll.clear();
        u.log_end(.{});
    }
    
    pub fn key_update(main: *Crosap_main, key: Key, pressed: bool) void {
        u.log_start(.{"Key ",key," is now ",pressed});
        if (pressed) {
            main.cr.keyboard_state.set(key, true);
            main.activity.key_input(&main.cr, key, .press);
        } else {
            main.cr.keyboard_state.set(key, false);
            main.activity.key_input(&main.cr, key, .release);
        }
        u.log_end(.{"Button update handled"});
    }
    
    pub fn pointer_start(main: *Crosap_main, pointer: *const Pointer) void {
        u.log_start(.{"New pointer ",@intFromPtr(pointer)});
        pointer.log_state();
        const pointer_info = Pointer_info {
            .active = false,
            .position = pointer.position,
            .button_left = pointer.button_left,
            .button_right = pointer.button_right,
            .button_middle = pointer.button_middle,
            .start_time = undefined,
            .scroll_chain = .create_with_capacity(8),
            .moved = undefined,
            .click_handler = undefined,
        };
        main.pointers.put_new(pointer, pointer_info);
        u.log_end(.{"New pointer handled"});
    }
    
    pub fn pointer_update(main: *Crosap_main, pointer: *const Pointer) void {
        u.log_start(.{"Pointer ",@intFromPtr(pointer)," updated"});
        pointer.log_state();
        
        const pointer_info = main.pointers.get_ptr(pointer) orelse unreachable;
        if (pointer.button_left != pointer_info.button_left) {
            pointer_info.button_left = pointer.button_left;
            if (pointer.button_left and !pointer_info.button_right and !pointer_info.button_middle) {
                pointer_info.active = true;
                pointer_info.start_time = u.time_nanoseconds();
                pointer_info.moved = .zero;
                pointer_info.scroll_chain.clear();
                pointer_info.click_handler = null;
                const pointer_context = ui.Pointer_context {
                    .cr = &main.cr,
                    .pos = main.cr.pixel_to_position(pointer_info.position),
                    .scroll_chain = &pointer_info.scroll_chain,
                    .click_handler = &pointer_info.click_handler,
                };
                const root_element = main.activity.root_element(&main.cr);
                const element = root_element.get_element();
                element.pointer_start(pointer_context);
            } else {
                if (pointer_info.active) {
                    pointer_info.active = false;
                    if (pointer_info.click_handler) |click_handler| {
                        click_handler.normal();
                    }
                }
            }
        }
        if (pointer.button_right != pointer_info.button_right) {
            pointer_info.button_right = pointer.button_right;
            if (pointer.button_right and !pointer_info.button_left and !pointer_info.button_middle) {
                main.emit_long_click(main.cr.pixel_to_position(pointer_info.position));
            }
        }
        if (pointer.button_middle != pointer_info.button_middle) {
            pointer_info.button_middle = pointer.button_middle;
            if (pointer.button_middle and !pointer_info.button_left and !pointer_info.button_right) {
                main.emit_long_click(main.cr.pixel_to_position(pointer_info.position));
            }
        }
        
        if (!pointer.position.equal_exact(pointer_info.position)) {
            if (pointer_info.active) {
                const change = pointer_info.position.offset_to(pointer.position);
                var moved = pointer_info.moved.add(main.cr.pixel_to_position_exact(change));
                var scrolled = u.Vec2i.zero;
                
                if (moved.x.higher_or_equal(.from_int(1))) {
                    const steps = moved.x.int_floor();
                    scrolled.x = scrolled.x.add(steps);
                    moved.x = moved.x.subtract(steps.to_real());
                } else if (moved.x.lower_or_equal(.from_int(-1))) {
                    const steps = moved.x.negate().int_floor();
                    scrolled.x = scrolled.x.subtract(steps);
                    moved.x = moved.x.add(steps.to_real());
                }
                if (moved.y.higher_or_equal(.from_int(1))) {
                    const steps = moved.y.int_floor();
                    scrolled.y = scrolled.y.add(steps);
                    moved.y = moved.y.subtract(steps.to_real());
                } else if (moved.y.lower_or_equal(.from_int(-1))) {
                    const steps = moved.y.negate().int_floor();
                    scrolled.y = scrolled.y.subtract(steps);
                    moved.y = moved.y.add(steps.to_real());
                }
                
                if (!scrolled.equal(.zero)) {
                    if (pointer_info.click_handler) |click_handler| {
                        click_handler.cancel();
                        pointer_info.click_handler = null;
                    }
                    const scroll_chain_count = pointer_info.scroll_chain.count;
                    for (0..scroll_chain_count) |index| {
                        const element = pointer_info.scroll_chain.get(index).to_element();
                        var next: ?Dynamic_element = null;
                        if (index + 1 < scroll_chain_count) {
                            next = pointer_info.scroll_chain.get(index + 1).to_element();
                        }
                        const gop = main.cr.to_scroll.get_or_put(element);
                        if (index == 0) {
                            if (gop.new) {
                                gop.value.* = .{
                                    .amount = scrolled,
                                    .otherwise = next,
                                };
                            } else {
                                gop.value.amount.mut_add(scrolled);
                            }
                        } else {
                            if (gop.new) {
                                gop.value.* = .{
                                    .amount = .zero,
                                    .otherwise = next,
                                };
                            }
                        }
                    }
                }
                pointer_info.moved = moved;
            }
            pointer_info.position = pointer.position;
        }
        
        u.log_end(.{"Pointer update handled"});
    }
    
    pub fn emit_long_click(main: *Crosap_main, pos: u.Vec2i) void {
        var click_handler: ?ui.click_handler.Dynamic_interface = null;
        const pointer_context = ui.Pointer_context {
            .cr = &main.cr,
            .pos = pos,
            .scroll_chain = null,
            .click_handler = &click_handler,
        };
        const root_element = main.activity.root_element(&main.cr);
        const element = root_element.get_element();
        element.pointer_start(pointer_context);
        if (click_handler) |handler| {
            handler.long();
        }
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
        const pointer_info = main.pointers.get_ptr(pointer) orelse unreachable;
        if (pointer_info.active) {
            if (pointer_info.click_handler) |click_handler| {
                click_handler.cancel();
            }
        }
        pointer_info.scroll_chain.deinit();
        main.pointers.remove(pointer) catch unreachable;
        u.log_end(.{"Pointer disappear handled"});
    }
};


const Pointer_info = struct {
    position: u.Vec2r,
    button_left: bool,
    button_right: bool,
    button_middle: bool,
    active: bool, // when active, button_left must be pressed, but after a long press active is false
    
    scroll_chain: u.List(ui.Dynamic_element), // inner element comes first. always a valid list, but only used when active
    // only when active
    start_time: u64,
    moved: u.Vec2r, // always between (-1, -1) and (1, 1). This is the build-up offset in logical position.
    click_handler: ?ui.click_handler.Dynamic_interface, // canceled and set to null after dragging
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

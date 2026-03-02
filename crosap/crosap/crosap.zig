const builtin = @import("builtin");
const std = @import("std");
const u = @import("util");
const Switching_backend = @import("switching_backend.zig").Backend;
const Draw_frame = @import("backend").Draw_frame;
const draw = @import("draw.zig");

const crosap_api = @import("crosap_api");
pub const Key = crosap_api.Key;
pub const Pointer = crosap_api.Pointer;
pub const ui = @import("ui.zig");
pub const Draw_context = draw.Draw_context;
pub const Pointer_context = ui.Pointer_context;
pub const Create_imagemap = draw.Create_imagemap;

pub const activity = @import("activity.zig").activity;
pub const Key_event = @import("activity.zig").Key_event;
pub const Keyboard_info = @import("activity.zig").Keyboard_info;

const Dynamic_element = ui.element.Dynamic_interface;

pub const Crosap = struct {
    backend: Switching_backend,
    general: draw.General_map,
    scale: u.Int,
    should_close: bool,
    keyboard_state: std.EnumArray(Key, bool),
    to_scroll: u.Map(Dynamic_element, To_scroll_info),
    audio_buffer: u.Audio_buffer,
    audio_to_add: u.List(i16),
    elements: u.Map(Dynamic_element, Element_info),
    root_element: Dynamic_element,
    
    const To_scroll_info = struct {
        amount: u.Vec2i,
        otherwise: ?Dynamic_element,
    };
    
    pub fn init(cr: *Crosap) void {
        cr.should_close = false;
        cr.scale = .create(4);
        cr.keyboard_state = .initFill(false);
        cr.to_scroll.init_with_capacity(32);
        cr.audio_to_add.init_with_capacity(9600); // 0.1s of audio
        cr.backend.init();
        
        cr.init_imagemap(&cr.general, draw.General_map.Drawer {});
        
        cr.elements.init_with_capacity(256);
    }
    
    pub fn deinit(cr: *Crosap) void {
        cr.elements.deinit();
        
        cr.deinit_imagemap(&cr.general);
        
        cr.backend.deinit();
        cr.audio_to_add.deinit();
        cr.to_scroll.deinit();
    }
    
    pub fn new_frame(cr: *Crosap, dtime: u.Real) ?Draw_context {
        cr.update_imagemap(&cr.general);
        if (cr.backend.new_frame()) |frame_size| {
            return .{
                .area = .create(.zero, frame_size),
                .mask = .create(.zero, frame_size),
                .cr = cr,
                .dtime = dtime,
            };
        } else {
            return null;
        }
    }
    
    pub fn end_frame(cr: *Crosap) void {
        cr.backend.end_frame();
    }
    
    pub fn update(cr: *Crosap, root_element: ui.flexible_element.Dynamic_interface, dtime: u.Real) void {
        if (cr.new_frame(dtime)) |draw_context| {
            const gen_element = root_element.get_element();
            cr.elements.clear();
            cr.elements.put_new(gen_element, .{
                .size = draw_context.size(),
                .position = .zero,
                .first_child = null,
                .last_child = null,
                .next_child = null,
                .previous_child = null,
            });
            cr.root_element = gen_element;
            
            const update_context = Update_context {
                .cr = cr,
                .el = gen_element,
                .dtime = dtime,
            };
            root_element.update(update_context, draw_context.size());
            
            cr.draw_element(gen_element, draw_context);
            cr.end_frame();
        }
    }
    
    pub fn draw_element(cr: *Crosap, element: Dynamic_element, draw_context: Draw_context) void {
        if (draw_context.mask.equal(.create(.zero, .zero))) {
            // element is invisible
            return;
        }
        element.frame(draw_context);
        var possible_child = cr.elements.get_ptr(element).?.first_child;
        while (possible_child) |child| {
            const child_info = cr.elements.get_ptr(child).?;
            cr.draw_element(child, draw_context.sub(.create(child_info.position, child_info.size)));
            
            possible_child = child_info.next_child;
        }
    }
    
    pub fn pointer_start(cr: *Crosap, ctx: Pointer_context) void {
        cr.pointer_start_element(cr.root_element, ctx);
    }
    
    pub fn pointer_start_element(cr: *Crosap, element: Dynamic_element, ctx: Pointer_context) void {
        var possible_child = cr.elements.get_ptr(element).?.last_child;
        while (possible_child) |child| {
            const child_info = cr.elements.get_ptr(child).?;
            if (ctx.sub(.create(child_info.position, child_info.size))) |child_ctx| {
                cr.pointer_start_element(child, child_ctx);
            }
            
            possible_child = child_info.previous_child;
        }
        element.pointer_start(ctx);
    }
    
    pub fn get_element_size(cr: *Crosap, element: Dynamic_element) u.Vec2i {
        return cr.elements.get_ptr(element).?.size;
    }
    
    pub fn create_texture_image(cr: *Crosap, size: u.Vec2i) draw.Texture_image {
        const backend_image = cr.backend.create_texture(size);
        return .{
            .image = backend_image,
            .backend = cr.backend,
            .size = size,
        };
    }
    
    pub fn init_imagemap(cr: *Crosap, map: anytype, drawer: anytype) void {
        const Image_map = @typeInfo(@TypeOf(map)).pointer.child;
        u.log_start("Creating image map "++Image_map.name);
        const needed_size = Image_map.needed_size(cr.scale);
        u.log(.{"Needed size: ",needed_size});
        const texture = cr.create_texture_image(needed_size);
        map.init(drawer, texture, cr.scale);
        u.log_end({});
    }
    
    pub fn update_imagemap(cr: *Crosap, map: anytype) void {
        const Image_map = @typeInfo(@TypeOf(map)).pointer.child;
        if (!cr.scale.equal(map.scale)) {
            u.log_start(.{"Image map "++Image_map.name++" had scale ",map.scale," but we now use scale ",cr.scale});
            map.texture.deinit();
            const needed_size = Image_map.needed_size(cr.scale);
            u.log(.{"Needed size: ",needed_size});
            const texture = cr.create_texture_image(needed_size);
            map.texture = texture;
            map.scale = cr.scale;
            map.redraw_all();
            u.log_end(.{});
        }
    }
    
    pub fn deinit_imagemap(cr: *Crosap, map: anytype) void {
        _ = cr;
        map.texture.deinit();
    }
    
    // TODO: move to element interface
    pub fn deinit_element(cr: *Crosap, element: anytype) void {
        const general_element = ui.element.dynamic(element);
        // remove it from our administration
        general_element.deinit(cr);
    }
    
    pub fn key_is_pressed(cr: *Crosap, key: Key) bool {
        return cr.keyboard_state.get(key);
    }
    
    pub fn pixel_to_position(cr: *Crosap, pixel: u.Vec2r) u.Vec2i {
        const exact = cr.pixel_to_position_exact(pixel);
        return .create(
            exact.x.int_floor(),
            exact.y.int_floor(),
        );
    }
    
    pub fn pixel_to_position_exact(cr: *Crosap, pixel: u.Vec2r) u.Vec2r {
        return .create(
            pixel.x.divide(cr.scale.to_real()),
            pixel.y.divide(cr.scale.to_real()),
        );
    }
    
    pub fn position_to_pixel(cr: *Crosap, pos: u.Vec2i) u.Vec2i {
        return pos.scale(cr.scale);
    }
    
    pub fn audio_samples_this_frame(cr: *Crosap) void {
        return cr.audio_to_add.count;
    }
    
    pub fn audio_output(cr: *Crosap) Audio_output {
        return Audio_output {
            .store_audio = cr.audio_to_add.items_mut(),
        };
    }
    
    pub const Audio_output = struct {
        store_audio: []i16, // always even length, because it stores stereo
        
        pub fn needed_samples(output: *const Audio_output) usize {
            return @divExact(output.store_audio.len, 2);
        }
        
        pub fn add_mono_sample(output: *Audio_output, sample: i16) void {
            output.add_stereo_sample(sample, sample);
        }
        
        pub fn add_stereo_sample(output: *Audio_output, left: i16, right: i16) void {
            u.assert(output.needed_samples() >= 1);
            output.store_audio[0] +|= left;
            output.store_audio[1] +|= right;
            output.store_audio = output.store_audio[2..];
        }
        
        pub fn add_mono_audio(output: *Audio_output, audio: []const i16) void {
            u.assert(audio.len <= output.needed_samples());
            for (audio, 0..) |sample, index| {
                output.store_audio[index * 2] +|= sample;
                output.store_audio[index * 2 + 1] +|= sample;
            }
            output.store_audio = output.store_audio[audio.len * 2 ..];
        }
        
        /// audio must be stereo, so its length must be even
        pub fn add_stereo_audio(output: *Audio_output, audio: []const i16) void {
            u.assert(audio.len % 2 == 0);
            u.assert(audio.len <= output.store_audio.len);
            for (audio, output.store_audio[0..audio.len]) |sample, *store| {
                store.* +|= sample;
            }
            output.store_audio = output.store_audio[audio.len..];
        }
        
        pub fn add_mono_audio_part(output: *Audio_output, audio: []const i16) usize {
            // count in samples
            const count = @min(output.store_audio.len, output.needed_samples());
            output.add_mono_audio(audio[0..count]);
            return count;
        }
        
        /// audio must be stereo, so its length must be even
        pub fn add_stereo_audio_part(output: *Audio_output, audio: []const i16) usize {
            // amount of samples = count / 2
            const count = @min(output.store_audio.len, audio.len);
            output.add_stereo_audio(audio[0..count]);
            return count;
        }
    };
    
    pub fn new_audio_player(cr: *Crosap, audio_data: []const i16) Audio_player {
        return .{
            .cr = cr,
            .data = audio_data,
            .position = 0,
            .playing = false,
            .repeat = false,
        };
    }
};


pub const Element_info = struct {
    size: u.Vec2i,
    position: u.Vec2i, // relative in parent
    first_child: ?Dynamic_element,
    last_child: ?Dynamic_element,
    next_child: ?Dynamic_element,
    previous_child: ?Dynamic_element,
    
    pub fn rect(el_info: Element_info) u.Rect2i {
        return .create(el_info.position, el_info.size);
    }
};

pub const Update_context = struct {
    cr: *Crosap,
    el: Dynamic_element,
    dtime: u.Real,
    
    pub fn child_flexible(ctx: *const Update_context, child: ui.flexible_element.Dynamic_interface, size: u.Vec2i) void {
        const child_context = ctx.add_child(child.get_element());
        child.update(child_context, size);
        ctx.set_child_size(child.get_element(), size);
    }
    
    pub fn child_flexible_at(ctx: *const Update_context, child: ui.flexible_element.Dynamic_interface, size: u.Vec2i, pos: u.Vec2i) void {
        const child_context = ctx.add_child(child.get_element());
        child.update(child_context, size);
        ctx.set_child_size_and_pos(child.get_element(), size, pos);
    }
    
    pub fn child_x_flex(ctx: *const Update_context, child: ui.x_flex_element.Dynamic_interface, width: u.Int) u.Int {
        const child_context = ctx.add_child(child.get_element());
        const height = child.update(child_context, width);
        ctx.set_child_size(child.get_element(), .create(width, height));
        return height;
    }
    
    pub fn child_x_flex_at(ctx: *const Update_context, child: ui.x_flex_element.Dynamic_interface, width: u.Int, pos: u.Vec2i) u.Int {
        const child_context = ctx.add_child(child.get_element());
        const height = child.update(child_context, width);
        ctx.set_child_size_and_pos(child.get_element(), .create(width, height), pos);
        return height;
    }
    
    pub fn child_y_flex(ctx: *const Update_context, child: ui.y_flex_element.Dynamic_interface, height: u.Int) u.Int {
        const child_context = ctx.add_child(child.get_element());
        const width = child.update(child_context, height);
        ctx.set_child_size(child.get_element(), .create(width, height));
        return width;
    }
    
    pub fn child_y_flex_at(ctx: *const Update_context, child: ui.y_flex_element.Dynamic_interface, height: u.Int, pos: u.Vec2i) u.Int {
        const child_context = ctx.add_child(child.get_element());
        const width = child.update(child_context, height);
        ctx.set_child_size_and_pos(child.get_element(), .create(width, height), pos);
        return width;
    }
    
    pub fn child_fixed(ctx: *const Update_context, child: ui.fixed_element.Dynamic_interface) u.Vec2i {
        const child_context = ctx.add_child(child.get_element());
        const size = child.update(child_context);
        ctx.set_child_size(child.get_element(), size);
        return size;
    }
    
    pub fn child_fixed_at(ctx: *const Update_context, child: ui.fixed_element.Dynamic_interface, pos: u.Vec2i) u.Vec2i {
        const child_context = ctx.add_child(child.get_element());
        const size = child.update(child_context);
        ctx.set_child_size_and_pos(child.get_element(), size, pos);
        return size;
    }
    
    fn add_child(ctx: *const Update_context, child: Dynamic_element) Update_context {
        var our_info = ctx.cr.elements.get_mut(ctx.el).?;
        const last_child_o = our_info.last_child;
        if (last_child_o) |last_child| {
            const last_info = ctx.cr.elements.get_mut(last_child).?;
            last_info.next_child = child;
        } else {
            our_info.first_child = child;
        }
        our_info.last_child = child;
        
        ctx.cr.elements.put_new(child, .{
            .size = undefined,
            .position = undefined,
            .first_child = null,
            .last_child = null,
            .next_child = null,
            .previous_child = last_child_o,
        });
        
        return .{
            .cr = ctx.cr,
            .el = child,
            .dtime = ctx.dtime,
        };
    }
    
    fn set_child_size(ctx: *const Update_context, child: Dynamic_element, size: u.Vec2i) void {
        const child_info = ctx.cr.elements.get_mut(child).?;
        child_info.size = size;
    }
    
    pub fn set_child_pos(ctx: *const Update_context, child: Dynamic_element, pos: u.Vec2i) void {
        const child_info = ctx.cr.elements.get_mut(child).?;
        child_info.position = pos;
    }
    
    fn set_child_size_and_pos(ctx: *const Update_context, child: Dynamic_element, size: u.Vec2i, pos: u.Vec2i) void {
        const child_info = ctx.cr.elements.get_mut(child).?;
        child_info.size = size;
        child_info.position = pos;
    }
    
    pub fn get_scroll(ctx: *const Update_context) ?u.Vec2i {
        if (ctx.cr.to_scroll.get_ptr(ctx.el)) |scroll_info| {
            return scroll_info.amount;
        } else {
            return null;
        }
    }
    
    // only call if `get_scroll` did not return null
    pub fn return_scroll(ctx: *const Update_context, amount: u.Vec2i) void {
        const scroll_info = ctx.cr.to_scroll.get_ptr(ctx.el).?;
        if (scroll_info.otherwise) |to_el| {
            const to_scroll_info = ctx.cr.to_scroll.get_mut(to_el).?;
            to_scroll_info.amount.increase(amount);
        }
    }
};

pub const Audio_player = struct {
    data: []const i16,
    position: usize,
    playing: bool,
    repeat: bool,
    
    pub fn init(player: *Audio_player, audio_data: []const i16) void {
        player.data = audio_data;
        player.position = 0;
        player.playing = false;
        player.repeat = false;
    }
    
    pub fn start(player: *Audio_player) void {
        player.playing = true;
    }
    
    pub fn stop(player: *Audio_player) void {
        player.playing = false;
    }
    
    pub fn reset(player: *Audio_player) void {
        player.position = 0;
    }
    
    pub fn update(player: *Audio_player, cr: *Crosap) void {
        const data_size = @divExact(player.data.len, 2);
        if (player.position >= data_size) {
            player.position = 0;
            if (!player.repeat) {
                player.playing = false;
            }
        }
        
        if (player.playing) {
            var output = cr.audio_output();
            while (output.needed_samples() > 0) {
                const available_samples = data_size - player.position;
                const play_samples = @min(output.needed_samples(), available_samples);
                output.add_stereo_audio(player.data[player.position * 2 ..][0 .. play_samples * 2]);
                
                player.position += play_samples;
                if (player.position >= data_size) {
                    player.position = 0;
                    if (!player.repeat) {
                        player.playing = false;
                        break;
                    }
                }
            }
        }
    }
};

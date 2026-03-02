const std = @import("std");
const u = @import("util");
const crosap = @import("crosap");
const Crosap = crosap.Crosap;
const ui = crosap.ui;
const Draw_context = @import("crosap").Draw_context;
const Update_context = @import("crosap").Update_context;

const Object = struct {
    pos: u.Vec2i,
    v: u.Vec2i,
    color: u.Screen_color,
};

pub const activities = struct {
    pub const main = Main_activity;
};

const audio_data = @embedFile("audio.raw");
const audio_buffer: []const i16 = @ptrCast(@alignCast(audio_data));

const Main_activity = struct {
    root_el: Test_element,
    audio_fase: u.Real,
    audio_beep: bool,
    audio_player: crosap.Audio_player,
    
    pub fn root_element(act: *Main_activity) ui.flexible_element.Dynamic_interface {
        return ui.flexible_element.dynamic(&act.root_el);
    }
    
    pub fn init_from_data(act: *Main_activity, data: u.serialize.bit_reader.Dynamic_interface) void {
        _ = data;
        act.root_el.init(.from_byte_rgb(0, 0, 0));
        act.audio_fase = .zero;
        act.audio_beep = false;
        
        act.audio_player.init(audio_buffer);
        act.audio_player.repeat = true;
    }
    
    pub fn deinit(act: *Main_activity, cr: *Crosap) void {
        cr.deinit_element(&act.root_el);
    }
    
    pub fn free(act: *Main_activity) void {
        u.free_single(act);
    }
    
    pub fn export_data(writer: u.serialize.bit_writer.Dynamic_interface) void {
        _ = writer;
    }
    
    pub fn update(act: *Main_activity, cr: *Crosap, dtime: u.Real) crosap.Keyboard_info {
        _ = dtime;
//         var audio_output = cr.audio_output();
//         u.log(.{"Adding ",audio_output.needed_samples()," samples"});
//         while (audio_output.needed_samples() > 0) {
//             const tone = if (act.audio_beep) u.Real.from_int(900) else u.Real.from_int(1000);
//             const sin_wave = act.audio_fase.multiply(u.pi).multiply(.from_int(2)).multiply(tone).sin().divide(.from_int(4));
//             const sin_scaled = sin_wave.multiply(.from_int(32767));
//             
//             const side = act.audio_fase.multiply(u.pi).multiply(.from_int(2)).sin().add(.one).divide(.from_int(2));
//             const left = sin_scaled.multiply(u.Real.one.subtract(side)).int_round().to(i16);
//             const right = sin_scaled.multiply(side).int_round().to(i16);
//             _ = left;
//             _ = right;
//             audio_output.add_stereo_sample(30000, -30000);
//             
//             act.audio_fase.increase(u.Real.from_int(100000).inverse());
//             act.audio_fase = act.audio_fase.mod(.one);
//         }
        act.audio_player.update(cr);
        return .keyboard_needed;
    }
    
    pub fn key_input(act: *Main_activity, cr: *Crosap, key: crosap.Key, event: crosap.Key_event) void {
        if (key == .space) {
            if (event == .press) {
                act.root_el.color = u.Color.from_byte_rgb(0, 64, 0).to_screen_color();
                act.audio_player.start();
            } else if (event == .release) {
                act.root_el.color = u.Color.from_byte_rgb(0, 0, 0).to_screen_color();
                act.audio_player.stop();
            }
        }
        _ = cr;
    }
};

pub const Test_element = struct {
    pub const get_element = ui.create_flexible_element(Test_element);
    color: u.Screen_color,
    text1_scroll: ui.Y_scroll,
    text1: ui.Overflow_text,
    block2_scroll: ui.Y_scroll,
    block2: ui.Y_stack,
    text2_scroll: ui.X_scroll_fixed,
    text2: ui.Simple_text,
    text3_scroll: ui.X_scroll_fixed,
    text3: ui.Simple_text,
    scroll_center: u.Vec2i,
    auto_buildup: u.Vec2r,
    auto_velocity: u.Vec2r,
    size: u.Vec2i,
    
    const auto_slow_down = u.Real.from_int(1024);
    
    pub fn init(el: *Test_element, color: u.Color) void {
        el.color = color.to_screen_color();
        el.text1.init(
            \\Hold the space key for some music: Crystal Cave by Alex "cynicmusic" Smith edited by congusbongus - <http://opengameart.org/content/crystal-cave-mysterious-ambience-seamless-loop> - CC-BY 3.0/CC-BY-SA 3.0/GPL 3.0 - used in Supertux
            //\\Dit is een erg lange regel die opgesplitst moet worden in meerdere regels omdat het niet in dit kleine vakje past.
            //\\Woorden worden bij voorkeur niet afgebroken omdat je dan niet zou weten of het twee verschillende woorden zijn.
            //\\Toch zullen hele lange woorden zoals aansprakelijkheidswaardevaststellingsveranderingen en meervoudigepersoonlijkheidsstoornis wel tussendoor worden afgebroken.
            //\\
            //\\BEGINLETTER PANGRAM:
            //\\Alle beroemde circusartiesten deden even fantastische, gekke, heldhaftige, ingewikkelde judoachtige kunstjes, lenig maar niet onvoorzichtig; prachtig qua ritme speelden trompettisten, uniform vibreerden warme xylofoonklanken; ijskoninginnen zongen.
            //\\
            //\\Lorem ipsum dolor sit amet. Eos perspiciatis quia ab aliquam quod ut provident inventore sit quis culpa. Non necessitatibus quam aut quia natus vel internos nemo id dolore itaque eos deleniti incidunt qui dolor rerum. Et placeat impedit aut eius consequuntur eum voluptatum omnis non recusandae eaque id voluptatibus rerum ut illo quia sit alias labore? Rem sunt provident et omnis commodi eos libero galisum ut eveniet esse.
        , .left);
        el.text1_scroll.init(ui.x_flex_element.dynamic(&el.text1));
        el.text2.init("This is some text with an amazing font\nand a new line.\n\n\n\n\n\n\n\nbla\n\n\nblabla\n\n\nblablabla", .right);
        el.text2_scroll.init(ui.fixed_element.dynamic(&el.text2));
        el.text3.init("This line is pretty long, which makes you scroll quite a bit before you reach the end. These two texts are in a seperate scroll container which are stacked together.\n\nThis line is also part of it.\n\n\n\n\n\nNow\n\nyou\n\nalso\n\nhave to...\n\n\n\n\nScroll down", .left);
        el.text3_scroll.init(ui.fixed_element.dynamic(&el.text3));
        el.block2.init(&.{
            ui.x_flex_element.dynamic(&el.text2_scroll),
            ui.x_flex_element.dynamic(&el.text3_scroll),
        });
        el.block2_scroll.init(ui.x_flex_element.dynamic(&el.block2));
        el.scroll_center = .zero;
        el.auto_buildup = .zero;
        el.auto_velocity = .zero;
        el.size = .zero;
    }
    
    pub fn deinit(el: *Test_element) void {
        el.text1.deinit();
        el.text2.deinit();
        el.text3.deinit();
        el.text2_scroll.deinit();
        el.text3_scroll.deinit();
        el.block2.deinit();
        el.block2_scroll.deinit();
    }
    
    fn scroll_offset(el: *Test_element) u.Vec2i {
        return el.size.scale_down(.create(2)).subtract(el.scroll_center);
    }
    
    pub fn update(el: *Test_element, ctx: Update_context, size: u.Vec2i) void {
        el.size = size;
        ctx.child_flexible(
            ui.flexible_element.dynamic(&el.text1_scroll),
            .create(grid_size.subtract(.one), grid_size.subtract(.one)),
        );
        
        ctx.child_flexible(
            ui.flexible_element.dynamic(&el.block2_scroll),
            .create(grid_size.subtract(.one), grid_size.subtract(.one)),
        );
        
        if (ctx.get_scroll()) |scroll| {
            el.scroll_center.increase_bounded(scroll);
        } else {
            const start_velocity = el.auto_velocity;
            const velocity_length = start_velocity.length();
            if (velocity_length.higher_than(.zero)){
                const velocity_dir = start_velocity.scale_down(velocity_length);
                const stop_time = velocity_length.divide(auto_slow_down);
                var used_time = ctx.dtime;
                if (ctx.dtime.higher_or_equal(stop_time)) {
                    // we stop this frame
                    used_time = stop_time;
                    el.auto_velocity = .zero;
                } else {
                    const new_velocity = velocity_length.subtract(ctx.dtime.multiply(auto_slow_down));
                    el.auto_velocity = velocity_dir.scale(new_velocity);
                }
                const avg_changing_velocity = start_velocity.add(el.auto_velocity).scale(.from_float(0.5));
                const moved = avg_changing_velocity.scale(used_time).add(el.auto_velocity.scale(ctx.dtime.subtract(used_time)));
                el.auto_buildup.increase(moved);
                const moved_dots = el.auto_buildup.round_to_vec2i();
                el.auto_buildup.decrease(moved_dots.to_vec2r());
                el.scroll_center.increase_bounded(moved_dots);
            }
        }
        
        ctx.set_child_pos(el.text1_scroll.get_element(), el.scroll_offset().add(.create(.one, .one)));
        ctx.set_child_pos(el.block2_scroll.get_element(), el.scroll_offset().add(.create(grid_size.add(.one), .one)),);
    }
    
    const grid_size = u.Int.create(64);
    const grid_color = u.Color.from_byte_rgb(255, 255, 255).to_screen_color();
    pub fn frame(el: *Test_element, draw: Draw_context) void {
        draw.rect(draw.area, el.color);
        
        // horizontal lines
        var current_y = el.scroll_offset().y.mod(grid_size);
        while (current_y.lower_than(draw.size().y)) : (current_y = current_y.add(grid_size)) {
            draw.rect(.create(
                .create(.zero, current_y),
                .create(draw.size().x, .one),
            ), grid_color);
        }
        
        // vertical lines
        var current_x = el.scroll_offset().x.mod(grid_size);
        while (current_x.lower_than(draw.size().x)) : (current_x = current_x.add(grid_size)) {
            draw.rect(.create(
                .create(current_x, .zero),
                .create(.one, draw.size().y),
            ), grid_color);
        }
    }
    
    pub fn pointer_start(el: *Test_element, info: ui.Pointer_context) void {
        if (info.create_click_handler()) |click_handler| {
            click_handler.* = ui.click_handler.dynamic(Click_handler.create(el, info.pos));
        }
        info.add_for_scrolling(ui.element.dynamic(el));
    }
    
    const Click_handler = struct {
        el: *Test_element,
        pos: u.Vec2i,
        
        pub fn create(element: *Test_element, position: u.Vec2i) *Click_handler {
            const handler = u.alloc_single(Click_handler);
            handler.el = element;
            handler.pos = position;
            return handler;
        }
        
        pub fn normal(handler: *Click_handler) void {
            handler.el.color = u.Color.from_byte_rgb(0, 0, 96).to_screen_color();
            u.free_single(handler);
        }
        
        pub fn long(handler: *Click_handler) void {
            handler.el.color = u.Color.from_byte_rgb(64, 0, 64).to_screen_color();
            u.free_single(handler);
        }
        
        pub fn cancel(handler: *Click_handler) void {
            u.free_single(handler);
        }
    };
    
    pub fn scroll_end(el: *Test_element, cr: *Crosap, velocity: u.Vec2r) u.Vec2r {
        _ = cr;
        el.auto_buildup = .zero;
        el.auto_velocity = velocity;
        return .zero;
    }
    
    pub const scroll_step = ui.element_no_scroll_step(Test_element);
};


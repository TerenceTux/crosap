const std = @import("std");
const u = @import("util");
const crosap = @import("crosap");
const Crosap = crosap.Crosap;
const ui = crosap.ui;
const Draw_context = @import("crosap").Draw_context;

const Object = struct {
    pos: u.Vec2i,
    v: u.Vec2i,
    color: u.Screen_color,
};

pub const activities = struct {
    pub const main = Main_activity;
};

const Main_activity = struct {
    root_el: Test_element,
    
    pub fn root_element(act: *Main_activity) ui.flexible_element.Dynamic_interface {
        return ui.flexible_element.dynamic(&act.root_el);
    }
    
    pub fn init_from_data(act: *Main_activity, data: u.serialize.bit_reader.Dynamic_interface) void {
        _ = data;
        act.root_el.init(.from_byte_rgb(0, 0, 0));
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
        _ = act;
        _ = cr;
        _ = dtime;
        return .keyboard_needed;
    }
    
    pub fn draw_frame(act: *Main_activity, draw: Draw_context) void {
        _ = act;
        //draw.image(.zero, draw.cr.general.get(.test_img));
        //draw.image_align(.create(draw.size().x, .create(0)), draw.cr.general.get(.test_img), .right, .top);
        draw.image(.create(.create(4*0), .create(4*0)), draw.cr.general.get(.nfont_capital_a));
        draw.image(.create(.create(4*1), .create(4*0)), draw.cr.general.get(.nfont_capital_b));
        draw.image(.create(.create(4*2), .create(4*0)), draw.cr.general.get(.nfont_capital_c));
        draw.image(.create(.create(4*3), .create(4*0)), draw.cr.general.get(.nfont_capital_d));
        draw.image(.create(.create(4*4), .create(4*0)), draw.cr.general.get(.nfont_capital_e));
        draw.image(.create(.create(4*5), .create(4*0)), draw.cr.general.get(.nfont_capital_f));
        draw.image(.create(.create(4*6), .create(4*0)), draw.cr.general.get(.nfont_capital_g));
        draw.image(.create(.create(4*7), .create(4*0)), draw.cr.general.get(.nfont_capital_h));
        draw.image(.create(.create(4*8), .create(4*0)), draw.cr.general.get(.nfont_capital_i));
        draw.image(.create(.create(4*9), .create(4*0)), draw.cr.general.get(.nfont_capital_j));
        draw.image(.create(.create(4*10), .create(4*0)), draw.cr.general.get(.nfont_capital_k));
        draw.image(.create(.create(4*11), .create(4*0)), draw.cr.general.get(.nfont_capital_l));
        draw.image(.create(.create(4*12), .create(4*0)), draw.cr.general.get(.nfont_capital_m));
        draw.image(.create(.create(4*13), .create(4*0)), draw.cr.general.get(.nfont_capital_n));
        draw.image(.create(.create(4*14), .create(4*0)), draw.cr.general.get(.nfont_capital_o));
        draw.image(.create(.create(4*15), .create(4*0)), draw.cr.general.get(.nfont_capital_p));
        draw.image(.create(.create(4*16), .create(4*0)), draw.cr.general.get(.nfont_capital_q));
        draw.image(.create(.create(4*17), .create(4*0)), draw.cr.general.get(.nfont_capital_r));
        draw.image(.create(.create(4*18), .create(4*0)), draw.cr.general.get(.nfont_capital_s));
        draw.image(.create(.create(4*19), .create(4*0)), draw.cr.general.get(.nfont_capital_t));
        draw.image(.create(.create(4*20), .create(4*0)), draw.cr.general.get(.nfont_capital_u));
        draw.image(.create(.create(4*21), .create(4*0)), draw.cr.general.get(.nfont_capital_v));
        draw.image(.create(.create(4*22), .create(4*0)), draw.cr.general.get(.nfont_capital_w));
        draw.image(.create(.create(4*23), .create(4*0)), draw.cr.general.get(.nfont_capital_x));
        draw.image(.create(.create(4*24), .create(4*0)), draw.cr.general.get(.nfont_capital_y));
        draw.image(.create(.create(4*25), .create(4*0)), draw.cr.general.get(.nfont_capital_z));
        draw.image(.create(.create(4*0), .create(4*1)), draw.cr.general.get(.nfont_small_a));
        draw.image(.create(.create(4*1), .create(4*1)), draw.cr.general.get(.nfont_small_b));
        draw.image(.create(.create(4*2), .create(4*1)), draw.cr.general.get(.nfont_small_c));
        draw.image(.create(.create(4*3), .create(4*1)), draw.cr.general.get(.nfont_small_d));
        draw.image(.create(.create(4*4), .create(4*1)), draw.cr.general.get(.nfont_small_e));
        draw.image(.create(.create(4*5), .create(4*1)), draw.cr.general.get(.nfont_small_f));
        draw.image(.create(.create(4*6), .create(4*1)), draw.cr.general.get(.nfont_small_g));
        draw.image(.create(.create(4*7), .create(4*1)), draw.cr.general.get(.nfont_small_h));
        draw.image(.create(.create(4*8), .create(4*1)), draw.cr.general.get(.nfont_small_i));
        draw.image(.create(.create(4*9), .create(4*1)), draw.cr.general.get(.nfont_small_j));
        draw.image(.create(.create(4*10), .create(4*1)), draw.cr.general.get(.nfont_small_k));
        draw.image(.create(.create(4*11), .create(4*1)), draw.cr.general.get(.nfont_small_l));
        draw.image(.create(.create(4*12), .create(4*1)), draw.cr.general.get(.nfont_small_m));
        draw.image(.create(.create(4*13), .create(4*1)), draw.cr.general.get(.nfont_small_n));
        draw.image(.create(.create(4*14), .create(4*1)), draw.cr.general.get(.nfont_small_o));
        draw.image(.create(.create(4*15), .create(4*1)), draw.cr.general.get(.nfont_small_p));
        draw.image(.create(.create(4*16), .create(4*1)), draw.cr.general.get(.nfont_small_q));
        draw.image(.create(.create(4*17), .create(4*1)), draw.cr.general.get(.nfont_small_r));
        draw.image(.create(.create(4*18), .create(4*1)), draw.cr.general.get(.nfont_small_s));
        draw.image(.create(.create(4*19), .create(4*1)), draw.cr.general.get(.nfont_small_t));
        draw.image(.create(.create(4*20), .create(4*1)), draw.cr.general.get(.nfont_small_u));
        draw.image(.create(.create(4*21), .create(4*1)), draw.cr.general.get(.nfont_small_v));
        draw.image(.create(.create(4*22), .create(4*1)), draw.cr.general.get(.nfont_small_w));
        draw.image(.create(.create(4*23), .create(4*1)), draw.cr.general.get(.nfont_small_x));
        draw.image(.create(.create(4*24), .create(4*1)), draw.cr.general.get(.nfont_small_y));
        draw.image(.create(.create(4*25), .create(4*1)), draw.cr.general.get(.nfont_small_z));
        draw.image(.create(.create(4*0), .create(4*2)), draw.cr.general.get(.nfont_number_0));
        draw.image(.create(.create(4*1), .create(4*2)), draw.cr.general.get(.nfont_number_1));
        draw.image(.create(.create(4*2), .create(4*2)), draw.cr.general.get(.nfont_number_2));
        draw.image(.create(.create(4*3), .create(4*2)), draw.cr.general.get(.nfont_number_3));
        draw.image(.create(.create(4*4), .create(4*2)), draw.cr.general.get(.nfont_number_4));
        draw.image(.create(.create(4*5), .create(4*2)), draw.cr.general.get(.nfont_number_5));
        draw.image(.create(.create(4*6), .create(4*2)), draw.cr.general.get(.nfont_number_6));
        draw.image(.create(.create(4*7), .create(4*2)), draw.cr.general.get(.nfont_number_7));
        draw.image(.create(.create(4*8), .create(4*2)), draw.cr.general.get(.nfont_number_8));
        draw.image(.create(.create(4*9), .create(4*2)), draw.cr.general.get(.nfont_number_9));
        draw.image(.create(.create(4*0), .create(4*3)), draw.cr.general.get(.nfont_underscore));
        draw.image(.create(.create(4*1), .create(4*3)), draw.cr.general.get(.nfont_colon));
        draw.image(.create(.create(4*2), .create(4*3)), draw.cr.general.get(.nfont_space));
        draw.image(.create(.create(4*3), .create(4*3)), draw.cr.general.get(.nfont_dot));
        draw.image(.create(.create(4*4), .create(4*3)), draw.cr.general.get(.nfont_comma));
        draw.image(.create(.create(4*5), .create(4*3)), draw.cr.general.get(.nfont_semicolon));
        draw.image(.create(.create(4*6), .create(4*3)), draw.cr.general.get(.nfont_brace_open));
        draw.image(.create(.create(4*7), .create(4*3)), draw.cr.general.get(.nfont_brace_close));
        draw.image(.create(.create(4*8), .create(4*3)), draw.cr.general.get(.nfont_bracket_open));
        draw.image(.create(.create(4*9), .create(4*3)), draw.cr.general.get(.nfont_bracket_close));
        draw.image(.create(.create(4*10), .create(4*3)), draw.cr.general.get(.nfont_curly_brace_open));
        draw.image(.create(.create(4*11), .create(4*3)), draw.cr.general.get(.nfont_curly_brace_close));
        draw.image(.create(.create(4*12), .create(4*3)), draw.cr.general.get(.nfont_angle_bracket_open));
        draw.image(.create(.create(4*13), .create(4*3)), draw.cr.general.get(.nfont_angle_bracket_close));
        draw.image(.create(.create(4*14), .create(4*3)), draw.cr.general.get(.nfont_slash));
        draw.image(.create(.create(4*15), .create(4*3)), draw.cr.general.get(.nfont_backslash));
        draw.image(.create(.create(4*16), .create(4*3)), draw.cr.general.get(.nfont_vertical_bar));
        draw.image(.create(.create(4*17), .create(4*3)), draw.cr.general.get(.nfont_apostrophe));
        draw.image(.create(.create(4*18), .create(4*3)), draw.cr.general.get(.nfont_quotation_mark));
        draw.image(.create(.create(4*19), .create(4*3)), draw.cr.general.get(.nfont_dash));
        draw.image(.create(.create(4*20), .create(4*3)), draw.cr.general.get(.nfont_plus));
        draw.image(.create(.create(4*21), .create(4*3)), draw.cr.general.get(.nfont_question_mark));
        draw.image(.create(.create(4*22), .create(4*3)), draw.cr.general.get(.nfont_exclamation_mark));
        draw.image(.create(.create(4*23), .create(4*3)), draw.cr.general.get(.nfont_asterisk));
        draw.image(.create(.create(4*24), .create(4*3)), draw.cr.general.get(.nfont_caret));
        draw.image(.create(.create(4*25), .create(4*3)), draw.cr.general.get(.nfont_hash));
        draw.image(.create(.create(4*26), .create(4*3)), draw.cr.general.get(.nfont_dollar_sign));
        draw.image(.create(.create(4*27), .create(4*3)), draw.cr.general.get(.nfont_percent));
        draw.image(.create(.create(4*28), .create(4*3)), draw.cr.general.get(.nfont_ampersand));
        draw.image(.create(.create(4*29), .create(4*3)), draw.cr.general.get(.nfont_at));
        draw.image(.create(.create(4*30), .create(4*3)), draw.cr.general.get(.nfont_backtick));
        draw.image(.create(.create(4*31), .create(4*3)), draw.cr.general.get(.nfont_tilde));
        
        draw.image(.create(.create(0), .create(64)), draw.cr.general.texture.get(.create(.zero, draw.cr.general.texture.size)));
    }
    
    pub fn key_input(act: *Main_activity, cr: *Crosap, key: crosap.Key, event: crosap.Key_event) void {
        if (key == .space) {
            if (event == .press) {
                act.root_el.color = u.Color.from_byte_rgb(0, 64, 0).to_screen_color();
            } else if (event == .release) {
                act.root_el.color = u.Color.from_byte_rgb(0, 0, 0).to_screen_color();
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
    text2: ui.Simple_text,
    scroll_center: u.Vec2i,
    auto_buildup: u.Vec2r,
    auto_velocity: u.Vec2r,
    size: u.Vec2i,
    
    const auto_slow_down = u.Real.from_int(1024);
    
    pub fn init(el: *Test_element, color: u.Color) void {
        el.color = color.to_screen_color();
        el.text1.init(
            \\Dit is een erg lange regel die opgesplitst moet worden in meerdere regels omdat het niet in dit kleine vakje past.
            \\Woorden worden bij voorkeur niet afgebroken omdat je dan niet zou weten of het twee verschillende woorden zijn.
            \\Toch zullen hele lange woorden zoals aansprakelijkheidswaardevaststellingsveranderingen en meervoudigepersoonlijkheidsstoornis wel tussendoor worden afgebroken.
            \\
            \\BEGINLETTER PANGRAM:
            \\Alle beroemde circusartiesten deden even fantastische, gekke, heldhaftige, ingewikkelde judoachtige kunstjes, lenig maar niet onvoorzichtig; prachtig qua ritme speelden trompettisten, uniform vibreerden warme xylofoonklanken; ijskoninginnen zongen.
            \\
            \\Lorem ipsum dolor sit amet. Eos perspiciatis quia ab aliquam quod ut provident inventore sit quis culpa. Non necessitatibus quam aut quia natus vel internos nemo id dolore itaque eos deleniti incidunt qui dolor rerum. Et placeat impedit aut eius consequuntur eum voluptatum omnis non recusandae eaque id voluptatibus rerum ut illo quia sit alias labore? Rem sunt provident et omnis commodi eos libero galisum ut eveniet esse.
        , .left);
        el.text1_scroll.init(ui.x_flex_element.dynamic(&el.text1));
        el.text2.init("Dit is een tekst met een geweldig lettertype\nen een nieuwe regel.", .center);
        el.scroll_center = .zero;
        el.auto_buildup = .zero;
        el.auto_velocity = .zero;
        el.size = .zero;
    }
    
    pub fn deinit(el: *Test_element) void {
        el.text1.deinit();
        el.text2.deinit();
    }
    
    fn scroll_offset(el: *Test_element) u.Vec2i {
        return el.size.scale_down(.create(2)).subtract(el.scroll_center);
    }
    
    pub fn update(el: *Test_element, cr: *Crosap, dtime: u.Real, size: u.Vec2i) void {
        el.size = size;
        el.text1_scroll.update(cr, dtime, .create(
            grid_size.subtract(.one),
            grid_size.subtract(.one),
        ));
        el.text2.update(cr, dtime);
        
        if (cr.get_scroll(ui.element.dynamic(el))) |scroll| {
            el.scroll_center.mut_add_bounded(scroll);
        } else {
            const start_velocity = el.auto_velocity;
            const velocity_length = start_velocity.length();
            if (velocity_length.higher_than(.zero)){
                const velocity_dir = start_velocity.scale_down(velocity_length);
                const stop_time = velocity_length.divide(auto_slow_down);
                var used_time = dtime;
                if (dtime.higher_or_equal(stop_time)) {
                    // we stop this frame
                    used_time = stop_time;
                    el.auto_velocity = .zero;
                } else {
                    const new_velocity = velocity_length.subtract(dtime.multiply(auto_slow_down));
                    el.auto_velocity = velocity_dir.scale(new_velocity);
                }
                const avg_changing_velocity = start_velocity.add(el.auto_velocity).scale(.from_float(0.5));
                const moved = avg_changing_velocity.scale(used_time).add(el.auto_velocity.scale(dtime.subtract(used_time)));
                el.auto_buildup.mut_add(moved);
                const moved_dots = el.auto_buildup.round_to_vec2i();
                el.auto_buildup.mut_subtract(moved_dots.to_vec2r());
                el.scroll_center.mut_add_bounded(moved_dots);
            }
        }
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
        
        const text1_el = el.text1_scroll.get_element();
        const text1_rect = u.Rect2i.create(
            el.scroll_offset().add(.create(.one, .one)),
            .create(
                grid_size.subtract(.one),
                grid_size.subtract(.one),
            ),
        );
        text1_el.frame(draw.sub(text1_rect, text1_rect));
        
        const text2_el = el.text2.get_element();
        const text2_rect = u.Rect2i.create(
            el.scroll_offset().move_right(grid_size),
            el.text2.get_size(draw.cr),
        );
        text2_el.frame(draw.sub(text2_rect, text2_rect));
    }
    
    pub fn pointer_start(el: *Test_element, info: ui.Pointer_context) void {
        const text1_rect = u.Rect2i.create(
            el.scroll_offset().add(.create(.one, .one)),
            .create(
                grid_size.subtract(.one),
                grid_size.subtract(.one),
            ),
        );
        if (info.sub(text1_rect)) |child_info| {
            const text1_el = el.text1_scroll.get_element();
            text1_el.pointer_start(child_info);
        }
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
        //@panic("Test");
        return .zero;
    }
    
    pub const scroll_step = ui.element_no_scroll_step(Test_element);
};


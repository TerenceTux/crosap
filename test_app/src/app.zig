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
    scroll_offset: u.Vec2i,
    
    pub fn init(el: *Test_element, color: u.Color) void {
        el.color = color.to_screen_color();
        el.scroll_offset = .zero;
    }
    
    pub fn deinit(el: *Test_element) void {
        _ = el;
    }
    
    pub fn update(el: *Test_element, cr: *Crosap, dtime: u.Int, size: u.Vec2i) void {
        _ = el;
        _ = cr;
        _ = dtime;
        _ = size;
    }
    
    const grid_size = u.Int.create(64);
    const grid_color = u.Color.from_byte_rgb(255, 255, 255).to_screen_color();
    pub fn frame(el: *Test_element, draw: Draw_context) void {
        if (draw.cr.get_scroll(ui.element.dynamic(el))) |scroll| {
            el.scroll_offset = el.scroll_offset.add(scroll);
            u.log(.{"New scroll offset: ",el.scroll_offset});
        }
        
        draw.rect(draw.area, el.color);
        
        // horizontal lines
        var current_y = el.scroll_offset.y.mod(grid_size);
        while (current_y.lower_than(draw.size().y)) : (current_y = current_y.add(grid_size)) {
            draw.rect(.create(
                .create(.zero, current_y),
                .create(draw.size().x, .one),
            ), grid_color);
        }
        
        // vertical lines
        var current_x = el.scroll_offset.x.mod(grid_size);
        while (current_x.lower_than(draw.size().x)) : (current_x = current_x.add(grid_size)) {
            draw.rect(.create(
                .create(current_x, .zero),
                .create(.one, draw.size().y),
            ), grid_color);
        }
    }
    
    pub fn pointer_start(el: *Test_element, info: ui.Pointer_context) void {
        if (info.create_click_handler()) |click_handler| {
            click_handler.* = ui.click_handler.dynamic(Click_handler.create(el));
        }
        info.add_for_scrolling(ui.element.dynamic(el));
    }
    
    const Click_handler = struct {
        el: *Test_element,
        
        pub fn create(element: *Test_element) *Click_handler {
            const handler = u.alloc_single(Click_handler);
            handler.el = element;
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
    
    pub const scroll_end = ui.element_no_scroll_end(Test_element);
    pub const scroll_step = ui.element_no_scroll_step(Test_element);
};


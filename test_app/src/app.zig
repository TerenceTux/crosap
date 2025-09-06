const std = @import("std");
const u = @import("util");
const Crosap = @import("crosap").Crosap;
const Draw_context = @import("crosap").Draw_context;

const Object = struct {
    pos: u.Vec2i,
    v: u.Vec2i,
    color: u.Screen_color,
};

pub const App = struct {
    cr: Crosap,
    
    pub fn init(app: *App) void {
        _ = app;
    }
    
    pub fn deinit(app: *App) void {
        _ = app;
    }
    
    pub fn step(app: *App, dtime: u.Real) void {
        _ = app;
        _ = dtime;
    }
    
    pub fn draw_frame(app: *App, draw: Draw_context) void {
        //draw.image(.zero, app.cr.general.get(.test_img));
        //draw.image_align(.create(draw.size().x, .create(0)), app.cr.general.get(.test_img), .right, .top);
        draw.image(.create(.create(4*0), .create(4*0)), app.cr.general.get(.nfont_capital_a));
        draw.image(.create(.create(4*1), .create(4*0)), app.cr.general.get(.nfont_capital_b));
        draw.image(.create(.create(4*2), .create(4*0)), app.cr.general.get(.nfont_capital_c));
        draw.image(.create(.create(4*3), .create(4*0)), app.cr.general.get(.nfont_capital_d));
        draw.image(.create(.create(4*4), .create(4*0)), app.cr.general.get(.nfont_capital_e));
        draw.image(.create(.create(4*5), .create(4*0)), app.cr.general.get(.nfont_capital_f));
        draw.image(.create(.create(4*6), .create(4*0)), app.cr.general.get(.nfont_capital_g));
        draw.image(.create(.create(4*7), .create(4*0)), app.cr.general.get(.nfont_capital_h));
        draw.image(.create(.create(4*8), .create(4*0)), app.cr.general.get(.nfont_capital_i));
        draw.image(.create(.create(4*9), .create(4*0)), app.cr.general.get(.nfont_capital_j));
        draw.image(.create(.create(4*10), .create(4*0)), app.cr.general.get(.nfont_capital_k));
        draw.image(.create(.create(4*11), .create(4*0)), app.cr.general.get(.nfont_capital_l));
        draw.image(.create(.create(4*12), .create(4*0)), app.cr.general.get(.nfont_capital_m));
        draw.image(.create(.create(4*13), .create(4*0)), app.cr.general.get(.nfont_capital_n));
        draw.image(.create(.create(4*14), .create(4*0)), app.cr.general.get(.nfont_capital_o));
        draw.image(.create(.create(4*15), .create(4*0)), app.cr.general.get(.nfont_capital_p));
        draw.image(.create(.create(4*16), .create(4*0)), app.cr.general.get(.nfont_capital_q));
        draw.image(.create(.create(4*17), .create(4*0)), app.cr.general.get(.nfont_capital_r));
        draw.image(.create(.create(4*18), .create(4*0)), app.cr.general.get(.nfont_capital_s));
        draw.image(.create(.create(4*19), .create(4*0)), app.cr.general.get(.nfont_capital_t));
        draw.image(.create(.create(4*20), .create(4*0)), app.cr.general.get(.nfont_capital_u));
        draw.image(.create(.create(4*21), .create(4*0)), app.cr.general.get(.nfont_capital_v));
        draw.image(.create(.create(4*22), .create(4*0)), app.cr.general.get(.nfont_capital_w));
        draw.image(.create(.create(4*23), .create(4*0)), app.cr.general.get(.nfont_capital_x));
        draw.image(.create(.create(4*24), .create(4*0)), app.cr.general.get(.nfont_capital_y));
        draw.image(.create(.create(4*25), .create(4*0)), app.cr.general.get(.nfont_capital_z));
        draw.image(.create(.create(4*0), .create(4*1)), app.cr.general.get(.nfont_small_a));
        draw.image(.create(.create(4*1), .create(4*1)), app.cr.general.get(.nfont_small_b));
        draw.image(.create(.create(4*2), .create(4*1)), app.cr.general.get(.nfont_small_c));
        draw.image(.create(.create(4*3), .create(4*1)), app.cr.general.get(.nfont_small_d));
        draw.image(.create(.create(4*4), .create(4*1)), app.cr.general.get(.nfont_small_e));
        draw.image(.create(.create(4*5), .create(4*1)), app.cr.general.get(.nfont_small_f));
        draw.image(.create(.create(4*6), .create(4*1)), app.cr.general.get(.nfont_small_g));
        draw.image(.create(.create(4*7), .create(4*1)), app.cr.general.get(.nfont_small_h));
        draw.image(.create(.create(4*8), .create(4*1)), app.cr.general.get(.nfont_small_i));
        draw.image(.create(.create(4*9), .create(4*1)), app.cr.general.get(.nfont_small_j));
        draw.image(.create(.create(4*10), .create(4*1)), app.cr.general.get(.nfont_small_k));
        draw.image(.create(.create(4*11), .create(4*1)), app.cr.general.get(.nfont_small_l));
        draw.image(.create(.create(4*12), .create(4*1)), app.cr.general.get(.nfont_small_m));
        draw.image(.create(.create(4*13), .create(4*1)), app.cr.general.get(.nfont_small_n));
        draw.image(.create(.create(4*14), .create(4*1)), app.cr.general.get(.nfont_small_o));
        draw.image(.create(.create(4*15), .create(4*1)), app.cr.general.get(.nfont_small_p));
        draw.image(.create(.create(4*16), .create(4*1)), app.cr.general.get(.nfont_small_q));
        draw.image(.create(.create(4*17), .create(4*1)), app.cr.general.get(.nfont_small_r));
        draw.image(.create(.create(4*18), .create(4*1)), app.cr.general.get(.nfont_small_s));
        draw.image(.create(.create(4*19), .create(4*1)), app.cr.general.get(.nfont_small_t));
        draw.image(.create(.create(4*20), .create(4*1)), app.cr.general.get(.nfont_small_u));
        draw.image(.create(.create(4*21), .create(4*1)), app.cr.general.get(.nfont_small_v));
        draw.image(.create(.create(4*22), .create(4*1)), app.cr.general.get(.nfont_small_w));
        draw.image(.create(.create(4*23), .create(4*1)), app.cr.general.get(.nfont_small_x));
        draw.image(.create(.create(4*24), .create(4*1)), app.cr.general.get(.nfont_small_y));
        draw.image(.create(.create(4*25), .create(4*1)), app.cr.general.get(.nfont_small_z));
        draw.image(.create(.create(4*0), .create(4*2)), app.cr.general.get(.nfont_number_0));
        draw.image(.create(.create(4*1), .create(4*2)), app.cr.general.get(.nfont_number_1));
        draw.image(.create(.create(4*2), .create(4*2)), app.cr.general.get(.nfont_number_2));
        draw.image(.create(.create(4*3), .create(4*2)), app.cr.general.get(.nfont_number_3));
        draw.image(.create(.create(4*4), .create(4*2)), app.cr.general.get(.nfont_number_4));
        draw.image(.create(.create(4*5), .create(4*2)), app.cr.general.get(.nfont_number_5));
        draw.image(.create(.create(4*6), .create(4*2)), app.cr.general.get(.nfont_number_6));
        draw.image(.create(.create(4*7), .create(4*2)), app.cr.general.get(.nfont_number_7));
        draw.image(.create(.create(4*8), .create(4*2)), app.cr.general.get(.nfont_number_8));
        draw.image(.create(.create(4*9), .create(4*2)), app.cr.general.get(.nfont_number_9));
        draw.image(.create(.create(4*0), .create(4*3)), app.cr.general.get(.nfont_underscore));
        draw.image(.create(.create(4*1), .create(4*3)), app.cr.general.get(.nfont_colon));
        draw.image(.create(.create(4*2), .create(4*3)), app.cr.general.get(.nfont_space));
        draw.image(.create(.create(4*3), .create(4*3)), app.cr.general.get(.nfont_dot));
        draw.image(.create(.create(4*4), .create(4*3)), app.cr.general.get(.nfont_comma));
        draw.image(.create(.create(4*5), .create(4*3)), app.cr.general.get(.nfont_semicolon));
        draw.image(.create(.create(4*6), .create(4*3)), app.cr.general.get(.nfont_brace_open));
        draw.image(.create(.create(4*7), .create(4*3)), app.cr.general.get(.nfont_brace_close));
        draw.image(.create(.create(4*8), .create(4*3)), app.cr.general.get(.nfont_bracket_open));
        draw.image(.create(.create(4*9), .create(4*3)), app.cr.general.get(.nfont_bracket_close));
        draw.image(.create(.create(4*10), .create(4*3)), app.cr.general.get(.nfont_curly_brace_open));
        draw.image(.create(.create(4*11), .create(4*3)), app.cr.general.get(.nfont_curly_brace_close));
        draw.image(.create(.create(4*12), .create(4*3)), app.cr.general.get(.nfont_angle_bracket_open));
        draw.image(.create(.create(4*13), .create(4*3)), app.cr.general.get(.nfont_angle_bracket_close));
        draw.image(.create(.create(4*14), .create(4*3)), app.cr.general.get(.nfont_slash));
        draw.image(.create(.create(4*15), .create(4*3)), app.cr.general.get(.nfont_backslash));
        draw.image(.create(.create(4*16), .create(4*3)), app.cr.general.get(.nfont_vertical_bar));
        draw.image(.create(.create(4*17), .create(4*3)), app.cr.general.get(.nfont_apostrophe));
        draw.image(.create(.create(4*18), .create(4*3)), app.cr.general.get(.nfont_quotation_mark));
        draw.image(.create(.create(4*19), .create(4*3)), app.cr.general.get(.nfont_dash));
        draw.image(.create(.create(4*20), .create(4*3)), app.cr.general.get(.nfont_plus));
        draw.image(.create(.create(4*21), .create(4*3)), app.cr.general.get(.nfont_question_mark));
        draw.image(.create(.create(4*22), .create(4*3)), app.cr.general.get(.nfont_exclamation_mark));
        draw.image(.create(.create(4*23), .create(4*3)), app.cr.general.get(.nfont_asterisk));
        draw.image(.create(.create(4*24), .create(4*3)), app.cr.general.get(.nfont_caret));
        draw.image(.create(.create(4*25), .create(4*3)), app.cr.general.get(.nfont_hash));
        draw.image(.create(.create(4*26), .create(4*3)), app.cr.general.get(.nfont_dollar_sign));
        draw.image(.create(.create(4*27), .create(4*3)), app.cr.general.get(.nfont_percent));
        draw.image(.create(.create(4*28), .create(4*3)), app.cr.general.get(.nfont_ampersand));
        draw.image(.create(.create(4*29), .create(4*3)), app.cr.general.get(.nfont_at));
        draw.image(.create(.create(4*30), .create(4*3)), app.cr.general.get(.nfont_backtick));
        draw.image(.create(.create(4*31), .create(4*3)), app.cr.general.get(.nfont_tilde));
        
        draw.image(.create(.create(0), .create(64)), app.cr.general.texture.get(.create(.zero, app.cr.general.texture.size)));
    }
};

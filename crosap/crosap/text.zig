const u = @import("util");
const General_map = @import("draw.zig").General_map;
const Draw_context = @import("draw.zig").Draw_context;
const ui = @import("ui.zig");
const Crosap = @import("crosap.zig").Crosap;

const characters = struct {
    pub const capital_a = 'A';
    pub const capital_b = 'B';
    pub const capital_c = 'C';
    pub const capital_d = 'D';
    pub const capital_e = 'E';
    pub const capital_f = 'F';
    pub const capital_g = 'G';
    pub const capital_h = 'H';
    pub const capital_i = 'I';
    pub const capital_j = 'J';
    pub const capital_k = 'K';
    pub const capital_l = 'L';
    pub const capital_m = 'M';
    pub const capital_n = 'N';
    pub const capital_o = 'O';
    pub const capital_p = 'P';
    pub const capital_q = 'Q';
    pub const capital_r = 'R';
    pub const capital_s = 'S';
    pub const capital_t = 'T';
    pub const capital_u = 'U';
    pub const capital_v = 'V';
    pub const capital_w = 'W';
    pub const capital_x = 'X';
    pub const capital_y = 'Y';
    pub const capital_z = 'Z';
    pub const small_a = 'a';
    pub const small_b = 'b';
    pub const small_c = 'c';
    pub const small_d = 'd';
    pub const small_e = 'e';
    pub const small_f = 'f';
    pub const small_g = 'g';
    pub const small_h = 'h';
    pub const small_i = 'i';
    pub const small_j = 'j';
    pub const small_k = 'k';
    pub const small_l = 'l';
    pub const small_m = 'm';
    pub const small_n = 'n';
    pub const small_o = 'o';
    pub const small_p = 'p';
    pub const small_q = 'q';
    pub const small_r = 'r';
    pub const small_s = 's';
    pub const small_t = 't';
    pub const small_u = 'u';
    pub const small_v = 'v';
    pub const small_w = 'w';
    pub const small_x = 'x';
    pub const small_y = 'y';
    pub const small_z = 'z';
    pub const number_0 = '0';
    pub const number_1 = '1';
    pub const number_2 = '2';
    pub const number_3 = '3';
    pub const number_4 = '4';
    pub const number_5 = '5';
    pub const number_6 = '6';
    pub const number_7 = '7';
    pub const number_8 = '8';
    pub const number_9 = '9';
    pub const underscore = '_';
    pub const colon = ':';
    pub const space = ' ';
    pub const dot = '.';
    pub const comma = ',';
    pub const semicolon = ';';
    pub const brace_open = '(';
    pub const brace_close = ')';
    pub const bracket_open = '[';
    pub const bracket_close = ']';
    pub const curly_brace_open = '{';
    pub const curly_brace_close = '}';
    pub const angle_bracket_open = '<';
    pub const angle_bracket_close = '>';
    pub const slash = '/';
    pub const backslash = '\\';
    pub const vertical_bar = '|';
    pub const apostrophe = '\'';
    pub const quotation_mark = '?';
    pub const dash = '-';
    pub const plus = '+';
    pub const question_mark = '?';
    pub const exclamation_mark = '!';
    pub const asterisk = '*';
    pub const caret = '^';
    pub const hash = '#';
    pub const dollar_sign = '$';
    pub const percent = '%';
    pub const ampersand = '&';
    pub const at = '@';
    pub const backtick = '`';
    pub const tilde = '~';
};

const character_names = b: {
    const decls = @typeInfo(characters).@"struct".decls;
    var names: [decls.len][:0]const u8 = undefined;
    for (&names, decls) |*name, decl| {
        name.* = decl.name;
    }
    break:b names;
};


pub fn character_width(c: u8) u.Int {
    inline for (character_names) |name| {
        if (c == @field(characters, name)) {
            const char_info = @field(General_map.Drawer.images, "nfont_" ++ name);
            var char_draw = char_info.image;
            return char_draw.size().x;
        }
    }
    return .zero;
}

pub fn draw_character(draw: Draw_context, c: u8, pos: u.Vec2i) void {
    inline for (character_names) |name| {
        if (c == @field(characters, name)) {
            const char_info = @field(General_map.Drawer.images, "nfont_" ++ name);
            var char_draw = char_info.image;
            const y_offset = char_draw.height_offset();
            const sub_image = @field(General_map.Sub_image, "nfont_" ++ name);
            const image = draw.cr.general.get(sub_image);
            draw.image(pos.move_down(y_offset), image);
            return;
        }
    }
}

pub const Simple_text = struct {
    pub const get_element = ui.create_fixed_element(Simple_text);
    text: []const u8,
    x_align: ui.X_align,
    size: u.Vec2i,
    
    pub fn init(el: *Simple_text, text: []const u8, x_align: ui.X_align) void {
        el.text = text;
        el.x_align = x_align;
    }
    
    pub fn deinit(el: *Simple_text) void {
        _ = el;
    }
    
    pub fn update(el: *Simple_text, cr: *Crosap, dtime: u.Real) void {
        _ = cr;
        _ = dtime;
        var lines = u.Int.one;
        var widest = u.Int.zero;
        var current = u.Int.zero;
        for (el.text) |char| {
            if (char == '\n') {
                if (current.higher_than(widest)) {
                    widest = current;
                }
                current = .zero;
                lines.mut_add(.one);
            } else {
                const width = character_width(char);
                current.mut_add(width);
            }
        }
        if (current.higher_than(widest)) {
            widest = current;
        }
        el.size = .create(
            widest,
            lines.multiply(.create(5)),
        );
    }
    
    pub fn get_size(el: *Simple_text, cr: *Crosap) u.Vec2i {
        _ = cr;
        return el.size;
    }
    
    pub fn frame(el: *Simple_text, draw: Draw_context) void {
        var start_of_line: usize = 0;
        var current_y = u.Int.zero;
        while (start_of_line < el.text.len) {
            var line_width: u.Int = undefined;
            // we need to know the width for center or right alignment
            if (el.x_align != .left) {
                line_width = .zero;
                var current_index = start_of_line;
                while (current_index < el.text.len and el.text[current_index] != '\n') {
                    const char_width = character_width(el.text[current_index]);
                    line_width.mut_add(char_width);
                    current_index += 1;
                }
            }
            var current_x = switch (el.x_align) {
                .left => u.Int.zero,
                .center => draw.size().x.subtract(line_width).divide(.create(2)),
                .right => draw.size().x.subtract(line_width),
            };
            var current_index = start_of_line;
            while (current_index < el.text.len and el.text[current_index] != '\n') {
                const char = el.text[current_index];
                draw_character(draw, char, .create(current_x, current_y));
                current_x.mut_add(character_width(char));
                current_index += 1;
            }
            if (current_index < el.text.len and el.text[current_index] == '\n') {
                current_index += 1;
            }
            start_of_line = current_index;
            current_y.mut_add(.create(5));
        }
    }
    
    pub fn pointer_start(el: *Simple_text, info: ui.Pointer_context) void {
        _ = el;
        _ = info;
    }
    
    pub const scroll_end = ui.element_no_scroll_end(Simple_text);
    pub const scroll_step = ui.element_no_scroll_step(Simple_text);
};

pub const Overflow_text = struct {
    pub const get_element = ui.create_x_flex_element(Overflow_text);
    text: []const u8,
    x_align: ui.X_align,
    lines: u.List([]const u8), // this allocates, but that's better than recalculating the overflow
    
    pub fn init(el: *Overflow_text, text: []const u8, x_align: ui.X_align) void {
        el.text = text;
        el.x_align = x_align;
        el.lines.init_with_capacity(4);
    }
    
    pub fn deinit(el: *Overflow_text) void {
        el.lines.deinit();
    }
    
    pub fn update(el: *Overflow_text, cr: *Crosap, dtime: u.Real, width: u.Int) void {
        _ = cr;
        _ = dtime;
        const text = el.text;
        el.lines.clear();
        // Each row of the text can be splitted into words by spaces and tabs
        // Each line contains at least one word
        // When a line is broken up in a word, at most 16 characters may be transferred to the next line
        // The characters between current_index and waiting_index fit on the current line, but may be transferred to the next line
        // When waiting_index is not current_index, it is a character after a space
        var waiting_index: usize = 0; // the characters between line_start and waiting_index are certainly on the current line
        var current_index: usize = 0;
        var current_width = u.Int.zero; // width of characters between line_start and current_index
        var line_start: usize = 0;
        while (true) {
            defer current_index += 1;
            if (current_index >= text.len or text[current_index] == '\n') {
                var line_count = current_index - line_start;
                while (line_count > 0 and text[line_start + line_count - 1] == ' ') {
                    line_count -= 1;
                }
                el.lines.append(text[line_start .. line_start + line_count]);
                if (current_index >= text.len) {
                    break;
                } else {
                    current_width = .zero;
                    line_start = current_index;
                    continue;
                }
            }
            if (text[current_index] == ' ') {
                waiting_index = current_index + 1;
            } else if (current_index - waiting_index > 16) {
                waiting_index = current_index - 16;
            }
            current_width.mut_add(character_width(text[current_index]));
            if (current_width.higher_than(width)) {
                // create new line of line_start to waiting_index, but without trailing spaces
                const end = if (waiting_index == 0 or text[waiting_index - 1] == ' ') waiting_index else current_index;
                var line_count = end - line_start;
                while (line_count > 0 and text[line_start + line_count] == ' ') {
                    line_count -= 1;
                }
                el.lines.append(text[line_start .. line_start + line_count]);
                current_width = .zero;
                line_start = end;
                current_index = end - 1; // next should be end
                waiting_index = end;
            }
        }
    }
    
    pub fn get_height(el: *Overflow_text, cr: *Crosap) u.Int {
        _ = cr;
        return u.Int.create(el.lines.count).multiply(.create(5));
    }
    
    pub fn frame(el: *Overflow_text, draw: Draw_context) void {
        var current_y = u.Int.zero;
        for (el.lines.items()) |line| {
            var line_width: u.Int = undefined;
            if (el.x_align != .left) {
                line_width = .zero;
                for (line) |char| {
                    line_width.mut_add(character_width(char));
                }
            }
            var current_x = switch (el.x_align) {
                .left => u.Int.zero,
                .center => draw.size().x.subtract(line_width).divide(.create(2)),
                .right => draw.size().x.subtract(line_width),
            };
            for (line) |char| {
                draw_character(draw, char, .create(current_x, current_y));
                current_x.mut_add(character_width(char));
            }
            current_y.mut_add(.create(5));
        }
    }
    
    pub fn pointer_start(el: *Overflow_text, info: ui.Pointer_context) void {
        _ = el;
        _ = info;
    }
    
    pub const scroll_end = ui.element_no_scroll_end(Overflow_text);
    pub const scroll_step = ui.element_no_scroll_step(Overflow_text);
};

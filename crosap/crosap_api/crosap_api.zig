const u = @import("util");

pub const Button_type = enum {
    escape,
    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,
    
    tick,
    num_1,
    num_2,
    num_3,
    num_4,
    num_5,
    num_6,
    num_7,
    num_8,
    num_9,
    num_0,
    minus,
    equals,
    backspace,
    
    tab,
    q,
    w,
    e,
    r,
    t,
    y,
    u,
    i,
    o,
    p,
    square_bracket_open,
    square_bracket_close,
    backslash,
    
    a,
    s,
    d,
    f,
    g,
    h,
    j,
    k,
    l,
    semicolon,
    apostrophe,
    enter,
    
    left_shift,
    z,
    x,
    c,
    v,
    b,
    n,
    m,
    comma,
    dot,
    slash,
    right_shift,
    
    left_control,
    super,
    left_alt,
    space,
    right_alt,
    right_control,
    
    arrow_up,
    arrow_left,
    arrow_right,
    arrow_down,
    
    insert,
    delete,
    home,
    end,
    page_up,
    page_down,
};
// Other keys are ignored
// If no keyboard is connected, we will show a keyboard on screen

pub const Button_state = struct {
    value: u8,
    
    pub const up = Button_state.from_real(.zero);
    pub const down = Button_state.from_real(.one);
    
    pub fn from_real(r: u.Real) Button_state {
        const int = r.multiply(.from_int(255)).int_floor().clamp(.zero, .create(255));
        return .{.value = int.to(u8)};
    }
    
    pub fn is_pressed(state: Button_state) bool {
        return state.value >= 128;
    }
    
    pub fn debug_print(state: Button_state, stream: anytype) void {
        u.byte_writer.validate(stream);
        if (state.value == 0) {
            stream.write_slice("not pressed");
        } else if (state.value == 255) {
            stream.write_slice("fully pressed");
        } else {
            const percentage = u.Real.from_int(state.value).divide(.from_float(2.55));
            percentage.int_round().debug_print(stream);
            stream.write_slice("% pressed");
        }
    }
};

pub const Pointer = struct {
    position: u.Vec2r,
    button_left: Button_state,
    button_right: Button_state,
    button_middle: Button_state,
    
    pub fn log_state(pointer: *const Pointer) void {
        u.log_start(.{"Pointer state"});
        u.log(.{"Position: ",pointer.position});
        u.log(.{"Left button: ",pointer.button_left});
        u.log(.{"Right button: ",pointer.button_right});
        u.log(.{"Middle button: ",pointer.button_middle});
        u.log_end(.{});
    }
};


pub const Event = union(enum) {
    button_update: struct {
        button: Button_type,
        state: Button_state,
    },
    pointer_start: struct {
        pointer: *const Pointer,
    },
    pointer_update: struct {
        pointer: *const Pointer,
    },
    pointer_scroll: struct {
        pointer: *const Pointer,
        offset: u.Vec2r,
    },
    pointer_stop: struct {
        pointer: *const Pointer,
    },
    quit: struct {
        
    },
};

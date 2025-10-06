const u = @import("util");

pub const Key = enum {
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

pub const Pointer = struct {
    position: u.Vec2r,
    button_left: bool,
    button_right: bool,
    button_middle: bool,
    
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
    key_update: struct {
        key: Key,
        state: bool,
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

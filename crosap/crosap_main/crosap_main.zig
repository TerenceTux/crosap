const u = @import("util");
const App = @import("app").App;
const Crosap = @import("crosap").Crosap;
const crosap_api = @import("crosap_api");
const Button_state = crosap_api.Button_state;
const Button_type = crosap_api.Button_type;
const Pointer = crosap_api.Pointer;

pub const Crosap_main = struct {
    last_update: u.Real,
    app: App,
    // TODO: make activities
    
    pub fn init(main: *Crosap_main) void {
        u.init();
        
        u.log_start(.{"Crosap init"});
        main.cr().init();
        u.log_end(.{"Crosap init"});
        
        u.log_start(.{"App init"});
        main.app.init();
        u.log_end(.{"App init"});
        
        main.last_update = u.time_seconds();
    }
    
    pub fn deinit(main: *Crosap_main) void {
        u.log_start(.{"App deinit"});
        main.app.deinit();
        u.log_end(.{"App deinit"});
        
        u.log_start(.{"Crosap main deinit"});
        main.cr().deinit();
        u.log_end(.{"Crosap main deinit"});
        
        u.deinit();
    }
    
    pub fn cr(main: *Crosap_main) *Crosap {
        return &main.app.cr;
    }
    
    pub fn update(main: *Crosap_main) void {
        u.log_start(.{"Frame update"});
        const now = u.time_seconds();
        const dtime = now.subtract(main.last_update);
        main.last_update = now;
        u.log_start(.{"Stepping ",dtime," ms"});
        main.app.step(dtime);
        u.log_end(.{"Stepping"});
        
        if (main.cr().new_frame()) |draw_context| {
            main.app.draw_frame(draw_context);
            main.cr().end_frame();
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

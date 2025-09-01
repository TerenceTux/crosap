const std = @import("std");
const crosap_build = @import("crosap");

pub fn build(b: *std.Build) void {
    crosap_build.app(b, "src/app.zig");
}

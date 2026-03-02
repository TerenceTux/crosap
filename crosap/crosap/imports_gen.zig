const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var args = init.minimal.args.iterateAllocator(init.gpa) catch @panic("Error getting arguments");
    defer args.deinit();
    
    if (!args.skip()) {
        @panic("Expected 2 arguments");
    }
    const output_file = args.next() orelse @panic("Expected 2 arguments");
    const to_import = args.next() orelse @panic("Expected 2 arguments");
    if (args.skip()) {
        @panic("Expected 2 arguments");
    }
    
    const working_dir = std.Io.Dir.cwd();
    
    var output = working_dir.createFile(io, output_file, .{}) catch @panic("could not create output file");
    defer output.close(io);
    var write_buffer: [4096]u8 = undefined;
    var writer = output.writer(io, &write_buffer);
    
    var names = std.mem.tokenizeScalar(u8, to_import, ',');
    writer.interface.writeAll("pub const imports = struct {\n") catch @panic("write error");
    while (names.next()) |name| {
        writer.interface.print("    pub const {s} = @import(\"{s}\");\n", .{name, name}) catch @panic("write error");
    }
    writer.interface.writeAll("};\n") catch @panic("write error");
    writer.interface.flush() catch @panic("write error");
}

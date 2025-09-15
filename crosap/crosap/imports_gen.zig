const std = @import("std");


var alloc: std.mem.Allocator = undefined;

pub fn main() !void {
    var gp_allocator = std.heap.DebugAllocator(.{}).init;
    defer _ = gp_allocator.deinit();
    alloc = gp_allocator.allocator();
    
    const args = std.process.argsAlloc(alloc) catch @panic("no memory");
    defer std.process.argsFree(alloc, args);
    
    if (args.len != 3) {
        @panic("expected 2 arguments");
    }
    
    const working_dir = std.fs.cwd();
    
    var output = working_dir.createFile(args[1], .{}) catch @panic("could not create output file");
    defer output.close();
    var write_buffer: [4096]u8 = undefined;
    var writer = output.writer(&write_buffer);
    
    var names = std.mem.tokenizeScalar(u8, args[2], ',');
    writer.interface.writeAll("pub const imports = struct {\n") catch @panic("write error");
    while (names.next()) |name| {
        writer.interface.print("    pub const {s} = @import(\"{s}\");\n", .{name, name}) catch @panic("write error");
    }
    writer.interface.writeAll("};\n") catch @panic("write error");
    writer.interface.flush() catch @panic("write error");
}

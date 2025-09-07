const std = @import("std");
const lib = @import("flag_zig_lib");

fn usage(stderr_writer: anytype, args: *lib.ArgsParser, program: []const u8) !void {
    try stderr_writer.print("This simple CLi is to demonstrate how to use this library\n\n", .{});
    try stderr_writer.print("USAGE: {s} [OPTIONS]\n", .{program});
    try stderr_writer.print("OPTIONS:\n", .{});
    try args.options_print(stderr_writer);
}

pub fn main() !void {
    const stderr = std.io.getStdErr();
    const stderr_writer = stderr.writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args = lib.ArgsParser.init(allocator);
    defer args.deinit();
    const help = try args.flag_bool("help", "Show this help program");
    const size = try args.flag_size("count", 69, "Give count this this thing");
    const name = try args.flag_str("name", "Agus", "Your name");
    const prog = args.program();

    if (!try args.parse()) {
        try usage(stderr_writer, &args, prog.*.?);
        return;
    }

    if (help.*) {
        try usage(stderr_writer, &args, prog.*.?);
        return;
    }

    if (size.* != 0) {
        std.debug.print("{d}\n", .{size.*});
    }

    if (name.* != null) {
        std.debug.print("{s}\n", .{name.*.?});
    }
}

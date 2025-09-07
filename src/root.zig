const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const ParseError = error{
    OutOfMemory,
    IntegerParseFailed,
};

pub const FlagType = enum {
    bool,
    size,
    string,
};

pub const Flag = union(FlagType) {
    bool: struct { name: []const u8, description: []const u8, value: *bool },
    size: struct { name: []const u8, description: []const u8, default: ?usize, value: *usize },
    string: struct { name: []const u8, description: []const u8, default: ?[]const u8, value: *?[]const u8 },
};

pub const ArgsParser = struct {
    allocator: Allocator,
    options: ArrayList(Flag),
    args: ?[][:0]u8,
    argc_value: usize,
    program_name: ?[]const u8,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .options = ArrayList(Flag).init(allocator),
            .args = null,
            .program_name = null,
            .argc_value = 0,
        };
    }

    pub fn program(self: *Self) *?[]const u8 {
        return &self.program_name;
    }

    pub fn options_list(self: *Self) *ArrayList(Flag) {
        return &self.options;
    }

    pub fn options_print(self: *Self, writer: anytype) !void {
        for (self.options.items) |option| {
            switch (option) {
                .bool => |a| {
                    try writer.print("    -{s} {s}\n\n", .{ a.name, a.description });
                },
                .size => |a| {
                    try writer.print("    -{s} <NUMBER>\n", .{a.name});
                    try writer.print("         {s}\n", .{a.description});
                    if (a.default != null) {
                        try writer.print("         DEFAULT: {d}\n", .{a.default.?});
                    }
                    try writer.print("\n", .{});
                },
                .string => |a| {
                    try writer.print("    -{s} <STRING>\n", .{a.name});
                    try writer.print("         {s}\n", .{a.description});
                    if (a.default != null) {
                        try writer.print("         DEFAULT: {s}\n", .{a.default.?});
                    }
                    try writer.print("\n", .{});
                },
            }
        }
    }

    pub fn flag_str(self: *Self, name: []const u8, default: ?[]const u8, description: []const u8) !*const ?[]const u8 {
        const state = try self.allocator.create(?[]const u8);
        state.* = default orelse null;
        try self.options.append(Flag{ .string = .{
            .value = state,
            .name = name,
            .description = description,
            .default = default,
        } });

        return state;
    }

    pub fn flag_size(self: *Self, name: []const u8, default: ?usize, description: []const u8) !*const usize {
        const state = try self.allocator.create(usize);
        state.* = default orelse 0;
        try self.options.append(Flag{ .size = .{
            .value = state,
            .name = name,
            .description = description,
            .default = default,
        } });

        return state;
    }

    pub fn flag_bool(self: *Self, name: []const u8, description: []const u8) !*const bool {
        const state = try self.allocator.create(bool);
        state.* = false;
        try self.options.append(Flag{ .bool = .{
            .value = state,
            .name = name,
            .description = description,
        } });

        return state;
    }

    pub fn argc(self: *Self) *usize {
        return &self.argc_value;
    }

    pub fn parse(self: *Self) ParseError!bool {
        self.*.args = std.process.argsAlloc(self.allocator) catch {
            return ParseError.OutOfMemory;
        };
        self.*.argc_value = self.*.args.?.len;
        self.program_name = std.fs.path.basename(self.args.?[0]);

        if (self.argc_value > 1) {
            var index: usize = 1;
            while (index < self.argc_value) {
                const arg = self.args.?[index];

                if (std.mem.startsWith(u8, arg, "-")) {
                    for (self.options.items) |option| {
                        switch (option) {
                            .bool => |a| {
                                if (std.mem.eql(u8, arg[1..], a.name)) {
                                    a.value.* = true;
                                }
                            },
                            .size => |a| {
                                if (std.mem.eql(u8, arg[1..], a.name) and index + 1 <= self.argc_value) {
                                    const number = std.fmt.parseInt(u8, self.args.?[index + 1], 10) catch {
                                        return ParseError.IntegerParseFailed;
                                    };
                                    a.value.* = @intCast(number);
                                    index += 1;
                                }
                            },
                            .string => |a| {
                                if (std.mem.eql(u8, arg[1..], a.name) and index + 1 <= self.argc_value) {
                                    const next_arg = self.args.?[index + 1];
                                    if (std.mem.startsWith(u8, next_arg, "\"") and std.mem.endsWith(u8, next_arg, "\"")) {
                                        a.value.* = std.mem.trim(u8, next_arg, "\"");
                                    } else {
                                        a.value.* = next_arg;
                                    }
                                    index += 1;
                                }
                            },
                        }
                    }
                }
                index += 1;
            }
        }
        return self.argc_value > 1;
    }

    pub fn deinit(self: *Self) void {
        std.process.argsFree(self.allocator, self.args.?);
        for (self.options.items) |option| {
            switch (option) {
                .bool => |a| {
                    self.allocator.destroy(a.value);
                },
                .size => |b| {
                    self.allocator.destroy(b.value);
                },
                .string => |b| {
                    if (b.value.* != null) {
                        self.allocator.destroy(b.value);
                    }
                },
            }
        }
        self.options.deinit();
    }
};

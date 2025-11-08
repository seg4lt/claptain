const std = @import("std");

pub fn parse(comptime T: type, option: ParseOptions) ParseError!T {
    var iterator = std.process.args();
    return try parseWithIterator(T, option, &iterator);
}

pub fn parseWithIterator(comptime T: type, option: ParseOptions, args_iter: anytype) ParseError!T {
    if (!@hasDecl(@TypeOf(args_iter.*), "next")) @compileError("args_iter must have next() decl");
    if (@typeInfo(T) != .@"struct") @compileError("type passed to parse must be of type struct.");
    const program_name = args_iter.next();
    _ = program_name;

    var buf: [1024]u8 = undefined;
    var stderr_state = std.fs.File.stderr().writer(&buf);
    const self = ClaptainParser{
        .writer = if (option.override_writer) |writer| writer else &stderr_state.interface,
        .option = option,
    };
    defer self.writer.flush() catch {};

    const fields = std.meta.fields(T);
    const num_fields = fields.len;
    var fields_seen: [num_fields]bool = .{false} ** num_fields;

    var result: T = undefined;

    // Mark all optional and fields with default value as seen, also set default value if exist
    inline for (fields, 0..) |field, i| {
        const is_optional = @typeInfo(field.type) == .optional;
        const has_default = field.default_value_ptr != null;

        if (is_optional or has_default) {
            defer fields_seen[i] = true;
            if (field.default_value_ptr) |ptr| {
                @field(result, field.name) = @as(*const field.type, @ptrCast(@alignCast(ptr))).*;
            }
        }
        if (is_optional and !has_default) {
            // when we do ` = undefined;`, I was seeing false instead of null, maybe because of how zig handles uninitialized memory?
            @field(result, field.name) = null;
        }
    }
    // std.debug.print("🚀 fields_seen: {any}\n", .{fields_seen});

    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, option.usage_flag)) {
            self.printUsage(T) catch {};
            return ParseError.UsageRequested;
        }
        // std.debug.print("🚀 args value on args_iter.next(): {s}\n", .{arg});
        try self.parseFieldValue(T, &result, &fields_seen, arg);

        // std.debug.print("🚀 after parse, field_seen {any}\n", .{fields_seen});
        // std.debug.print("🚀 after parse, result = {any}\n", .{result});
    }

    // Verify all required arguments are provided
    var missing_arg = false;
    inline for (fields, 0..) |field, i| {
        if (!fields_seen[i]) {
            // std.debug.print("🚀 this is missing?? {s}\n", .{field.name});
            missing_arg = true;
            try self.print("required argument '{s}' missing\n", .{field.name});
        }
    }
    if (missing_arg) {
        self.printUsage(T) catch {};
        return ParseError.RequiredArgsNotProvided;
    }
    // std.debug.print("🚀 return result {any}\n", .{result});

    return result;
}

pub const ParseError = error{
    UsageRequested,
    PrintFailed,
    InvalidArgument,
    RequiredArgsNotProvided,
};

pub const ParseOptions = struct {
    usage_flag: []const u8 = "--help",
    allow_invalid: bool = false,
    override_writer: ?*std.Io.Writer = null,

    pub fn withWriter(self: ParseOptions, writer: *std.Io.Writer) ParseOptions {
        var options = self;
        options.override_writer = writer;
        return options;
    }
};

const ClaptainParser = struct {
    writer: *std.Io.Writer,
    option: ParseOptions,

    fn parseFieldValue(self: *const @This(), comptime T: type, result: *T, fields_seen: []bool, arg: []const u8) ParseError!void {
        const index_of_equal = std.mem.indexOf(u8, arg, "=");
        const field_identifier = if (index_of_equal) |idx| arg[0..idx] else arg;

        // std.debug.print("🚀 field_identifier: {s}\n", .{field_identifier});

        if (!std.mem.startsWith(u8, field_identifier, "--") and !self.option.allow_invalid) {
            try self.print("options should start with `--` found `{s}`", .{field_identifier});
            return ParseError.InvalidArgument;
        }

        const field_name = field_identifier[2..];
        var field_found = false;

        // std.debug.print("🚀 field_name: {s}\n", .{field_name});

        inline for (std.meta.fields(T), 0..) |field, i| {
            if (std.mem.eql(u8, field.name, field_name)) {
                defer fields_seen[i] = true;
                field_found = true;

                const actual_type = if (@typeInfo(field.type) == .optional) @typeInfo(field.type).optional.child else field.type;

                // std.debug.print("🚀 FOUND!! field_name, with field.name: {s}\n", .{field.name});

                switch (@typeInfo(actual_type)) {
                    .pointer => |ptr| {
                        const is_u8_slice = ptr.size == .slice and ptr.child == u8;
                        if (!is_u8_slice) @compileError("only []u8 pointer type is supported for string fields.");

                        if (index_of_equal == null) {
                            try self.print("Missing value for argument '{s}'\n", .{field_name});
                            self.printUsage(T) catch {};
                            return ParseError.InvalidArgument;
                        }
                        const initial_value = arg[index_of_equal.? + 1 ..];
                        if (std.mem.startsWith(u8, initial_value, "\"") and std.mem.endsWith(u8, initial_value, "\"")) {
                            @field(result, field.name) = initial_value[1 .. initial_value.len - 1];
                        } else {
                            @field(result, field.name) = initial_value;
                        }
                    },
                    .@"enum" => |enum_info| {
                        if (index_of_equal == null) {
                            try self.print("Missing value for argument '{s}'\n", .{field_name});
                            self.printUsage(T) catch {};
                            return ParseError.InvalidArgument;
                        }
                        const value_str = arg[index_of_equal.? + 1 ..];
                        var matched = false;
                        inline for (enum_info.fields) |enum_field| {
                            if (std.mem.eql(u8, enum_field.name, value_str)) {
                                @field(result, field.name) = @enumFromInt(enum_field.value);
                                matched = true;
                                break;
                            }
                        }
                        if (!matched) {
                            try self.print("Invalid value '{s}' for argument '{s}'\n", .{ value_str, field_name });
                            self.printUsage(T) catch {};
                            return ParseError.InvalidArgument;
                        }
                    },
                    .bool => {
                        // std.debug.print("🚀 up to bool: iddex_of_eql = {any}\n", .{index_of_equal});
                        if (index_of_equal == null) {
                            // std.debug.print("🚀 no =, so bool = true \n", .{});
                            @field(result, field.name) = true;
                            // std.debug.print("🚀 result now {any} \n", .{result});
                            return;
                        }
                        const value_str = arg[index_of_equal.? + 1 ..];
                        if (std.mem.eql(u8, value_str, "true")) {
                            @field(result, field.name) = true;
                        } else if (std.mem.eql(u8, value_str, "false")) {
                            @field(result, field.name) = false;
                        } else {
                            try self.print("invalid boolean value '{s}' for argument '{s}'\n", .{ value_str, field_name });
                            self.printUsage(T) catch {};
                            return ParseError.InvalidArgument;
                        }
                    },
                    else => |tag| std.debug.panic("not implemented: {s}\n", .{@tagName(tag)}),
                }
                break;
            }
        }

        if (!field_found) {
            if (self.option.allow_invalid) return;
            try self.print("unknown argument '{s}'\n", .{field_name});
            return ParseError.InvalidArgument;
        }
    }

    fn printUsage(self: *const @This(), comptime T: type) !void {
        var args = std.process.args();
        const exe_name = args.next().?; // exe name should always exist

        try self.print("usage: {s} [OPTIONS]\n\nOPTIONS:\n", .{std.fs.path.basename(exe_name)});
        try self.flush();

        try self.printUsageForStructType(T);

        try self.flush();
    }

    fn printUsageForStructType(self: *const @This(), comptime T: type) ParseError!void {
        inline for (std.meta.fields(T)) |field| {
            const actual_type = if (@typeInfo(field.type) == .optional)
                @typeInfo(field.type).optional.child
            else
                field.type;

            const is_optional = @typeInfo(field.type) == .optional;
            const has_default = field.default_value_ptr != null;
            const is_required = !is_optional and !has_default;

            switch (@typeInfo(actual_type)) {
                .pointer => |ptr| {
                    const is_u8_slice = ptr.size == .slice and ptr.child == u8;
                    if (!is_u8_slice) @compileError("only []u8 pointer type is supported for string fields.");

                    try self.print("\t", .{});
                    try self.print("--{s}=<string>", .{field.name});
                    try self.printAdditionalUsageInfo(has_default, is_required, field);
                    try self.print("\n", .{});
                },
                .bool => {
                    try self.print("\t", .{});
                    try self.print("--{s} or --{s}=true|false", .{ field.name, field.name });
                    try self.printAdditionalUsageInfo(has_default, is_required, field);
                    try self.print("\n", .{});
                },
                .@"enum" => |enum_info| {
                    try self.print("\t", .{});
                    try self.print("--{s}=", .{field.name});
                    inline for (enum_info.fields, 0..) |enum_field, i| {
                        try self.print("{s}", .{enum_field.name});
                        if (i < enum_info.fields.len - 1) {
                            try self.print("|", .{});
                        }
                    }
                    try self.printAdditionalUsageInfo(has_default, is_required, field);
                    try self.print("\n", .{});
                },
                .int => {
                    try self.print("\t", .{});
                    try self.print("--{s}=<int>", .{field.name});
                    try self.printAdditionalUsageInfo(has_default, is_required, field);
                    try self.print("\n", .{});
                },
                .float => {
                    try self.print("\t", .{});
                    try self.print("--{s}=<float>", .{field.name});
                    try self.printAdditionalUsageInfo(has_default, is_required, field);
                    try self.print("\n", .{});
                },
                else => |tag| std.debug.panic("not implemented: {s}\n", .{@tagName(tag)}),
            }
        }
        try self.flush();
    }

    fn printAdditionalUsageInfo(self: *const @This(), has_default: bool, is_required: bool, field: std.builtin.Type.StructField) ParseError!void {
        try self.print("\t(required={any})", .{is_required});
        if (has_default) {
            const is_optional = @typeInfo(field.type) == .optional;
            const actual_type = if (is_optional) @typeInfo(field.type).optional.child else field.type;

            const value = @as(*const field.type, @ptrCast(@alignCast(field.default_value_ptr.?))).*;
            switch (@typeInfo(actual_type)) {
                .@"enum" => switch (is_optional) {
                    false => try self.print("\t(default: \"{s}\")", .{@tagName(value)}),
                    true => try self.print("\t(default: \"{s}\")", .{@tagName(value.?)}),
                },
                .bool, .int, .float => switch (is_optional) {
                    false => try self.print("\t(default: {any})", .{value}),
                    true => try self.print("\t(default: {any})", .{value.?}),
                },
                else => switch (is_optional) {
                    false => try self.print("\t(default: \"{s}\")", .{value}),
                    true => try self.print("\t(default: \"{s}\")", .{value.?}),
                },
            }
        }
    }
    fn print(s: *const @This(), comptime fmt: []const u8, args: anytype) ParseError!void {
        s.writer.print(fmt, args) catch return ParseError.PrintFailed;
    }

    fn flush(s: *const @This()) ParseError!void {
        s.writer.flush() catch return ParseError.PrintFailed;
    }
};

// pub fn structPrinter(value: anytype) void {
//     const T = @TypeOf(value);
//     inline for (std.meta.fields(T)) |field| {
//         switch (@typeInfo(field.type)) {
//             .pointer => |ptr| {
//                 if (ptr.size == .slice and ptr.child == u8) {
//                     std.log.debug("{s:>20} = `{s}`", .{ field.name, @field(value, field.name) });
//                     continue;
//                 }
//                 structPrinter(@field(value, field.name).*);
//             },
//             else => std.log.debug("{s:>20} = `{any}`", .{ field.name, @field(value, field.name) }),
//         }
//     }
// }

test {
    const testing = std.testing;
    _ = testing.refAllDeclsRecursive(@This());
    _ = testing.refAllDeclsRecursive(@import("./tests/bool_test.zig"));
    _ = testing.refAllDeclsRecursive(@import("./tests/string_test.zig"));
    _ = testing.refAllDeclsRecursive(@import("./tests/enum_test.zig"));
}

const std = @import("std");

pub fn parse(comptime T: type, option: ParseOptions) ParseError!T {
    if (@typeInfo(T) != .@"struct") @compileError("type passed to parse must be of type struct.");

    var buf: [1024]u8 = undefined;
    var stderr_state = std.fs.File.stderr().writer(&buf);
    const self = ClaptainParser{
        .writer = &stderr_state.interface,
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
            const ptr = field.default_value_ptr orelse continue;
            @field(result, field.name) = @as(*const field.type, @ptrCast(@alignCast(ptr))).*;
        }
    }

    var args = std.process.args();
    _ = args.next(); // skip exe name

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, option.usage_flag)) {
            self.printUsage(T) catch {};
            std.process.exit(option.exit_status_code);
        }
        try self.parseFieldValue(T, &result, &fields_seen, arg);
    }

    // Verify all required arguments are provided
    var missing_arg = false;
    inline for (fields, 0..) |field, i| {
        if (!fields_seen[i]) {
            missing_arg = true;
            try self.print("required argument '{s}' missing\n", .{field.name});
        }
    }
    if (missing_arg) {
        self.printUsage(T) catch {};
        std.process.exit(option.exit_status_code);
    }

    return result;
}

pub const ParseError = error{
    PrintFailed,
    InvalidArgument,
    RequiredArgsNotProvided,
};

const ParseOptions = struct {
    usage_flag: []const u8 = "--help",
    allow_invalid: bool = true,
    exit_status_code: u8 = 1,
};

const ClaptainParser = struct {
    writer: *std.Io.Writer,
    option: ParseOptions,

    fn parseFieldValue(self: *const @This(), comptime T: type, result: *T, fields_seen: []bool, arg: []const u8) ParseError!void {
        const index_of_equal = std.mem.indexOf(u8, arg, "=");
        const field_identifier = if (index_of_equal) |idx| arg[0..idx] else arg;

        if (!std.mem.startsWith(u8, field_identifier, "--") and !self.option.allow_invalid) {
            try self.print("options should start with `--` found `{s}`", .{field_identifier});
            return ParseError.InvalidArgument;
        }

        const field_name = field_identifier[2..];
        var field_found = false;

        inline for (std.meta.fields(T), 0..) |field, i| {
            if (std.mem.eql(u8, field.name, field_name)) {
                field_found = true;
                defer if (field_found) {
                    fields_seen[i] = true;
                };

                switch (@typeInfo(field.type)) {
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
                        if (index_of_equal == null) {
                            @field(result, field.name) = true;
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
                else => |tag| std.debug.panic("not implemented: {s}\n", .{@tagName(tag)}),
            }
        }
        try self.flush();
    }

    fn printAdditionalUsageInfo(self: *const @This(), has_default: bool, is_required: bool, field: std.builtin.Type.StructField) ParseError!void {
        try self.print("\t(required={any})", .{is_required});
        if (has_default) {
            const value = @as(*const field.type, @ptrCast(@alignCast(field.default_value_ptr.?))).*;
            switch (@typeInfo(field.type)) {
                .@"enum" => try self.print("\t(default: \"{s}\")", .{@tagName(value)}),
                .bool => try self.print("\t(default: \"{any}\")", .{value}),
                .optional => {
                    // TODO(seg4lt) - can we just recursively call printAdditionalUsageInfo here?
                    // types are screwed, need to experiment further
                    if (value) |unwrapped| {
                        const child_type = @typeInfo(field.type).optional.child;
                        switch (@typeInfo(child_type)) {
                            .@"enum" => try self.print("\t(default: \"{s}\")", .{@tagName(unwrapped)}),
                            .bool => try self.print("\t(default: \"{any}\")", .{unwrapped}),
                            else => try self.print("\t(default: \"{s}\")", .{unwrapped}),
                        }
                    }
                },
                else => try self.print("\t(default: \"{s}\")", .{value}),
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

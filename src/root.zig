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

    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, option.usage_flag)) {
            try self.printUsage(T);
            return ParseError.UsageRequested;
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
        try self.printUsage(T);
        return ParseError.RequiredArgsNotProvided;
    }

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
                defer fields_seen[i] = true;
                field_found = true;

                const actual_type = if (@typeInfo(field.type) == .optional) @typeInfo(field.type).optional.child else field.type;

                switch (@typeInfo(actual_type)) {
                    .pointer => |ptr| {
                        const is_u8_slice = ptr.size == .slice and ptr.child == u8;
                        if (!is_u8_slice) @compileError("only []u8 pointer type is supported for string fields.");

                        if (index_of_equal == null) {
                            try self.print("Missing value for argument '{s}'\n", .{field_name});
                            try self.printUsage(T);
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
                            try self.print("missing value for argument '{s}'\n", .{field_name});
                            try self.printUsage(T);
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
                            try self.print("invalid value '{s}' for argument '{s}'\n", .{ value_str, field_name });
                            try self.printUsage(T);
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
                    .int, .float => {
                        if (index_of_equal == null) {
                            try self.print("Missing value for argument '{s}'\n", .{field_name});
                            try self.printUsage(T);
                            return ParseError.InvalidArgument;
                        }
                        const value_str = arg[index_of_equal.? + 1 ..];
                        const value = switch (@typeInfo(actual_type)) {
                            .int => std.fmt.parseInt(actual_type, value_str, 10),
                            .float => std.fmt.parseFloat(actual_type, value_str),
                            else => std.debug.panic("** bug ** only int and float type should come here... ", .{}),
                        } catch {
                            try self.print("Invalid number value '{s}' for argument '{s}'\n", .{ value_str, field_name });
                            try self.printUsage(T);
                            return ParseError.InvalidArgument;
                        };
                        @field(result, field.name) = value;
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
        const PRINT_BUF_LENGTH = 120;
        const PRINT_ARGS_INFO_LENGTH = 50;
        var print_line_buf: [PRINT_BUF_LENGTH]u8 = .{' '} ** PRINT_BUF_LENGTH;
        const print_args_info_buf = print_line_buf[0..PRINT_ARGS_INFO_LENGTH];
        const print_additional_info_buf = print_line_buf[PRINT_ARGS_INFO_LENGTH..];

        inline for (std.meta.fields(T)) |field| {
            print_line_buf = .{' '} ** PRINT_BUF_LENGTH;

            const is_optional = @typeInfo(field.type) == .optional;
            const actual_type = if (is_optional) @typeInfo(field.type).optional.child else field.type;
            const has_default = field.default_value_ptr != null;
            const is_required = !is_optional and !has_default;

            switch (@typeInfo(actual_type)) {
                .pointer => |ptr| {
                    const is_u8_slice = ptr.size == .slice and ptr.child == u8;
                    if (!is_u8_slice) @compileError("only []u8 pointer type is supported for string fields.");

                    try self.bufPrint(print_args_info_buf, "--{s}=<str>", .{field.name});
                    try self.printAdditionalUsageInfo(print_additional_info_buf, has_default, is_required, field);
                },
                .bool => {
                    try self.bufPrint(print_args_info_buf, "--{s}=true|false", .{field.name});
                    try self.printAdditionalUsageInfo(print_additional_info_buf, has_default, is_required, field);
                },
                .@"enum" => |enum_info| {
                    try self.bufPrint(print_args_info_buf, "--{s}=", .{field.name});
                    var pos = field.name.len + 3; // 3 == len of "--" + "="
                    inline for (enum_info.fields, 0..) |enum_field, i| {
                        try self.bufPrint(print_args_info_buf[pos..], "{s}", .{enum_field.name});
                        pos += enum_field.name.len;
                        if (i < enum_info.fields.len - 1) {
                            try self.bufPrint(print_args_info_buf[pos..], "|", .{});
                            pos += 1;
                        }
                    }
                    try self.printAdditionalUsageInfo(print_additional_info_buf, has_default, is_required, field);
                },
                .int => {
                    try self.bufPrint(print_args_info_buf, "--{s}=<int>", .{field.name});
                    try self.printAdditionalUsageInfo(print_additional_info_buf, has_default, is_required, field);
                },
                .float => {
                    try self.bufPrint(print_args_info_buf, "--{s}=<float>", .{field.name});
                    try self.printAdditionalUsageInfo(print_additional_info_buf, has_default, is_required, field);
                },
                else => |tag| std.debug.panic("not implemented: {s}\n", .{@tagName(tag)}),
            }
            try self.print("{s}\n", .{print_line_buf});
            try self.flush();
        }
        try self.flush();
    }

    fn printAdditionalUsageInfo(self: *const @This(), buf: []u8, has_default: bool, is_required: bool, field: std.builtin.Type.StructField) ParseError!void {
        const REQUIRED_PRINT_BUF_LENGTH = 20;
        const required_print_buf = buf[0..REQUIRED_PRINT_BUF_LENGTH];
        try self.bufPrint(required_print_buf, "({s})", .{if (is_required) "required" else "optional"});

        if (!has_default) return;

        const remaining_buf = buf[REQUIRED_PRINT_BUF_LENGTH..];

        const is_optional = @typeInfo(field.type) == .optional;
        const actual_type = if (is_optional) @typeInfo(field.type).optional.child else field.type;

        const value = @as(*const field.type, @ptrCast(@alignCast(field.default_value_ptr.?))).*;
        switch (@typeInfo(actual_type)) {
            .@"enum" => switch (is_optional) {
                false => try self.bufPrint(remaining_buf, "(default: \"{s}\")", .{@tagName(value)}),
                true => try self.bufPrint(remaining_buf, "(default: \"{s}\")", .{@tagName(value.?)}),
            },
            .bool, .int, .float => switch (is_optional) {
                false => try self.bufPrint(remaining_buf, "(default: {any})", .{value}),
                true => try self.bufPrint(remaining_buf, "(default: {any})", .{value.?}),
            },
            else => switch (is_optional) {
                false => try self.bufPrint(remaining_buf, "(default: \"{s}\")", .{value}),
                true => try self.bufPrint(remaining_buf, "(default: \"{s}\")", .{value.?}),
            },
        }
    }

    fn bufPrint(self: *const @This(), buf: []u8, comptime fmt: []const u8, args: anytype) ParseError!void {
        _ = self;
        _ = std.fmt.bufPrint(buf, fmt, args) catch return ParseError.PrintFailed;
    }

    fn print(s: *const @This(), comptime fmt: []const u8, args: anytype) ParseError!void {
        s.writer.print(fmt, args) catch return ParseError.PrintFailed;
    }

    fn flush(s: *const @This()) ParseError!void {
        s.writer.flush() catch return ParseError.PrintFailed;
    }
};

test {
    const testing = std.testing;
    _ = testing.refAllDeclsRecursive(@This());
    _ = testing.refAllDeclsRecursive(@import("./tests/bool_test.zig"));
    _ = testing.refAllDeclsRecursive(@import("./tests/string_test.zig"));
    _ = testing.refAllDeclsRecursive(@import("./tests/enum_test.zig"));
    _ = testing.refAllDeclsRecursive(@import("./tests/int_test.zig"));
    _ = testing.refAllDeclsRecursive(@import("./tests/float_test.zig"));
}

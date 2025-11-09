const std = @import("std");

pub const ParseOptions = struct {
    usage_flag: []const u8 = "--help",
    allow_invalid: bool = false,
    override_writer: ?*std.Io.Writer = null,
};

pub const ParseError = error{
    UsageRequested,
    PrintFailed,
    InvalidArgument,
    RequiredArgsNotProvided,
};

pub fn Metadata(comptime T: type) type {
    if (@typeInfo(T) != .@"struct") @compileError("only struct is supported");

    const fields = @typeInfo(T).@"struct".fields;
    var struct_fields: [fields.len]std.builtin.Type.StructField = undefined;

    const default_value: ?ArgInfo = null;
    for (fields, &struct_fields) |f, *sf| {
        sf.* = .{
            .name = f.name,
            .type = ?ArgInfo,
            .default_value_ptr = @as(*const anyopaque, @ptrCast(&default_value)),
            .is_comptime = false,
            .alignment = @alignOf(?ArgInfo),
        };
    }
    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .backing_integer = null,
            .fields = &struct_fields,
            .decls = &.{},
            .is_tuple = false,
        },
    });
}

pub const ArgInfo = struct {
    short: ?[]const u8 = null,
    long: ?[]const u8 = null,
};

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
            // `= undefined` doesn't initialize value, so need to set to null explicitly
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
            const field_name = blk: {
                if (ClaptainParser.getArgInfo(T, field.name)) |arg_info| {
                    const long_name = if (arg_info.long) |ln| ln else field.name;
                    break :blk long_name;
                }
                break :blk field.name;
            };
            try self.print("required argument '{s}' missing\n", .{field_name});
        }
    }
    if (missing_arg) {
        try self.printUsage(T);
        return ParseError.RequiredArgsNotProvided;
    }

    return result;
}

const ClaptainParser = struct {
    writer: *std.Io.Writer,
    option: ParseOptions,

    const ArgLength = enum(u8) {
        short = 1,
        long = 2,
    };

    fn isShortOrLongArg(field_identifier: []const u8) ParseError!ArgLength {
        const startsWith = std.mem.startsWith;
        if (startsWith(u8, field_identifier, "--")) return .long;
        if (startsWith(u8, field_identifier, "-")) return .short;
        return ParseError.InvalidArgument;
    }

    fn parseFieldValue(self: *const @This(), comptime S: type, result: *S, fields_seen: []bool, arg: []const u8) ParseError!void {
        const index_of_equal = std.mem.indexOf(u8, arg, "=");
        const field_identifier = if (index_of_equal) |idx| arg[0..idx] else arg;

        const arg_length = isShortOrLongArg(field_identifier) catch |err| {
            if (!self.option.allow_invalid) {
                try self.print("options should start with `--` or `-` found `{s}`", .{field_identifier});
                return err;
            }
            return;
        };

        const arg_field_name = field_identifier[@intFromEnum(arg_length)..];
        var field_found = false;

        inline for (std.meta.fields(S), 0..) |field, i| {
            const arg_info = try getFieldNameFromMetadata(S, arg_length, arg_field_name);
            const interested_field_name = if (arg_info) |f| f else arg_field_name;

            if (try self.matchAndSetFieldValue(S, result, field, interested_field_name, arg, arg_field_name, index_of_equal)) {
                fields_seen[i] = true;
                field_found = true;
                break;
            }
        }

        if (!field_found) {
            if (self.option.allow_invalid) return;
            try self.print("unknown argument '{s}'\n", .{arg_field_name});
            return ParseError.InvalidArgument;
        }
    }

    fn matchAndSetFieldValue(
        self: *const @This(),
        comptime S: type,
        result: *S,
        field: std.builtin.Type.StructField,
        interested_field_name: []const u8, // actual field name to match against
        arg: []const u8, // full arg string e.g -s=value
        arg_field_name: []const u8, // user provided arg name - which can be different as it can be overridden
        index_of_equal: ?usize,
    ) ParseError!bool {
        if (!std.mem.eql(u8, interested_field_name, field.name)) return false;

        const actual_type = if (@typeInfo(field.type) == .optional) @typeInfo(field.type).optional.child else field.type;

        switch (@typeInfo(actual_type)) {
            .pointer => |ptr| {
                const is_u8_slice = ptr.size == .slice and ptr.child == u8;
                if (!is_u8_slice) @compileError("only []u8 pointer type is supported for string fields.");

                if (index_of_equal == null) {
                    try self.print("missing value for argument '{s}'\n", .{arg_field_name});
                    try self.printUsage(S);
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
                    try self.print("missing value for argument '{s}'\n", .{arg_field_name});
                    try self.printUsage(S);
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
                    try self.print("invalid value '{s}' for argument '{s}'\n", .{ value_str, interested_field_name });
                    try self.printUsage(S);
                    return ParseError.InvalidArgument;
                }
            },
            .bool => {
                if (index_of_equal == null) {
                    @field(result, field.name) = true;
                    return true;
                }
                const value_str = arg[index_of_equal.? + 1 ..];
                if (std.mem.eql(u8, value_str, "true")) {
                    @field(result, field.name) = true;
                } else if (std.mem.eql(u8, value_str, "false")) {
                    @field(result, field.name) = false;
                } else {
                    try self.print("invalid boolean value '{s}' for argument '{s}'\n", .{ value_str, interested_field_name });
                    try self.printUsage(S);
                    return ParseError.InvalidArgument;
                }
            },
            .int, .float => {
                if (index_of_equal == null) {
                    try self.print("missing value for argument '{s}'\n", .{arg_field_name});
                    try self.printUsage(S);
                    return ParseError.InvalidArgument;
                }
                const value_str = arg[index_of_equal.? + 1 ..];
                const value = switch (@typeInfo(actual_type)) {
                    .int => std.fmt.parseInt(actual_type, value_str, 10),
                    .float => std.fmt.parseFloat(actual_type, value_str),
                    else => |tag| @compileError(tag ++ " ** bug ** this should not happen at all"),
                } catch {
                    try self.print("invalid number value '{s}' for argument '{s}'\n", .{ value_str, arg_field_name });
                    try self.printUsage(S);
                    return ParseError.InvalidArgument;
                };
                @field(result, field.name) = value;
            },
            else => |tag| @compileError(tag ++ " not supported"),
        }
        return true;
    }

    const CLAPTAIN_METADATA_FIELD_NAME = "__claptain_metadata";

    fn getFieldNameFromMetadata(comptime S: type, arg_length: ArgLength, arg_name: []const u8) ParseError!?[]const u8 {
        if (!@hasDecl(S, CLAPTAIN_METADATA_FIELD_NAME)) return null;

        const meta = @field(S, CLAPTAIN_METADATA_FIELD_NAME);
        inline for (@typeInfo(@TypeOf(meta)).@"struct".fields) |meta_field_info| {
            const current_field_name = meta_field_info.name;
            const meta_field: ?ArgInfo = @field(meta, current_field_name);

            if (meta_field) |mf| {
                if (arg_length == .long) {
                    if (mf.long) |long_name| {
                        if (std.mem.eql(u8, long_name, arg_name)) {
                            return current_field_name;
                        }
                        return ParseError.InvalidArgument;
                    }
                }
                if (arg_length == .short) {
                    if (mf.short) |short_name| {
                        if (std.mem.eql(u8, short_name, arg_name)) {
                            return current_field_name;
                        }
                        return ParseError.InvalidArgument;
                    }
                }
            }
        }
        return null;
    }

    fn getArgInfo(comptime S: type, comptime field_name: []const u8) ?ArgInfo {
        if (!@hasDecl(S, CLAPTAIN_METADATA_FIELD_NAME)) return null;
        const meta = @field(S, CLAPTAIN_METADATA_FIELD_NAME);
        if (!@hasField(@TypeOf(meta), field_name)) return null;
        return @field(meta, field_name);
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

                    const print_count = try self.printArgInfo(T, field.name, print_args_info_buf);
                    _ = try self.bufPrint(print_args_info_buf[print_count..], "string", .{});
                    try self.printAdditionalUsageInfo(print_additional_info_buf, has_default, is_required, field);
                },
                .bool => {
                    const print_count = try self.printArgInfo(T, field.name, print_args_info_buf);
                    _ = try self.bufPrint(print_args_info_buf[print_count..], "true|false", .{});
                    try self.printAdditionalUsageInfo(print_additional_info_buf, has_default, is_required, field);
                },
                .@"enum" => |enum_info| {
                    const print_count = try self.printArgInfo(T, field.name, print_args_info_buf);
                    var pos = print_count;
                    inline for (enum_info.fields, 0..) |enum_field, i| {
                        _ = try self.bufPrint(print_args_info_buf[pos..], "{s}", .{enum_field.name});
                        pos += enum_field.name.len;
                        if (i < enum_info.fields.len - 1) {
                            _ = try self.bufPrint(print_args_info_buf[pos..], "|", .{});
                            pos += 1;
                        }
                    }
                    try self.printAdditionalUsageInfo(print_additional_info_buf, has_default, is_required, field);
                },
                .int => {
                    const print_count = try self.printArgInfo(T, field.name, print_args_info_buf);
                    _ = try self.bufPrint(print_args_info_buf[print_count..], "int", .{});
                    try self.printAdditionalUsageInfo(print_additional_info_buf, has_default, is_required, field);
                },
                .float => {
                    const print_count = try self.printArgInfo(T, field.name, print_args_info_buf);
                    _ = try self.bufPrint(print_args_info_buf[print_count..], "float", .{});
                    try self.printAdditionalUsageInfo(print_additional_info_buf, has_default, is_required, field);
                },
                else => |tag| @compileError(tag ++ " not supported yet"),
            }
            try self.print("{s}\n", .{print_line_buf});
            try self.flush();
        }
        try self.flush();
    }

    fn printArgInfo(self: *const @This(), comptime S: type, comptime field_name: []const u8, buf: []u8) ParseError!usize {
        if (getArgInfo(S, field_name)) |arg_info| {
            const long_name = if (arg_info.long) |ln| ln else field_name;
            if (arg_info.long != null and arg_info.short != null) {
                return self.bufPrint(buf, "--{s}, -{s}=", .{ arg_info.long.?, arg_info.short.? });
            }
            if (arg_info.long != null) {
                return self.bufPrint(buf, "--{s}=", .{long_name});
            }
            if (arg_info.short) |short_name| {
                return self.bufPrint(buf, "--{s}, -{s}=", .{ long_name, short_name });
            }
        }
        return self.bufPrint(buf, "--{s}=", .{field_name});
    }

    fn printAdditionalUsageInfo(self: *const @This(), buf: []u8, has_default: bool, is_required: bool, field: std.builtin.Type.StructField) ParseError!void {
        const REQUIRED_PRINT_BUF_LENGTH = 20;
        const required_print_buf = buf[0..REQUIRED_PRINT_BUF_LENGTH];
        _ = try self.bufPrint(required_print_buf, "({s})", .{if (is_required) "required" else "optional"});

        if (!has_default) return;

        const remaining_buf = buf[REQUIRED_PRINT_BUF_LENGTH..];

        const is_optional = @typeInfo(field.type) == .optional;
        const actual_type = if (is_optional) @typeInfo(field.type).optional.child else field.type;

        const value = @as(*const field.type, @ptrCast(@alignCast(field.default_value_ptr.?))).*;
        _ = switch (@typeInfo(actual_type)) {
            .@"enum" => switch (is_optional) {
                false => try self.bufPrint(remaining_buf, "(default: \"{s}\")", .{@tagName(value)}),
                true => try self.bufPrint(remaining_buf, "(default: \"{s}\")", .{@tagName(value.?)}),
            },
            .bool, .int, .float => try self.bufPrint(remaining_buf, "(default: {any})", .{value}),
            else => switch (is_optional) {
                false => try self.bufPrint(remaining_buf, "(default: \"{s}\")", .{value}),
                true => try self.bufPrint(remaining_buf, "(default: \"{s}\")", .{value.?}),
            },
        };
    }

    fn bufPrint(self: *const @This(), buf: []u8, comptime fmt: []const u8, args: anytype) ParseError!usize {
        _ = self;
        const slice = std.fmt.bufPrint(buf, fmt, args) catch return ParseError.PrintFailed;
        return slice.len;
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
    _ = testing.refAllDeclsRecursive(@import("./tests/metadata_test.zig"));
    _ = testing.refAllDeclsRecursive(@import("./tests/multi_arg_test.zig"));
}

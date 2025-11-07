const std = @import("std");

pub fn parse(comptime T: type, option: ParseOptions) ParseError!T {
    if (@typeInfo(T) != .@"struct") @compileError("type passed to parse must be of type struct.");

    var buf: [1024]u8 = undefined;
    var stderr_state = std.fs.File.stderr().writer(&buf);
    const self = ClaptainParser{
        .writer = &stderr_state.interface,
        .option = option,
    };

    const fields = std.meta.fields(T);
    const num_fields = fields.len;
    var fields_seen: [num_fields]bool = .{false} ** num_fields;

    var result: T = undefined;

    inline for (fields, 0..) |field, i| {
        const is_optional = @typeInfo(field.type) == .optional;
        const has_default = field.default_value_ptr != null;

        if (is_optional or has_default) {
            defer fields_seen[i] = true;
            const ptr = field.default_value_ptr orelse continue;
            @field(result, field.name) = @as(*const field.type, @ptrCast(@alignCast(ptr))).*;
        }
    }

    inline for (fields, 0..) |field, i| {
        if (!fields_seen[i]) {
            try self.print("Required argument '{s}' missing\n", .{field.name});
            self.printUsage(T) catch std.process.exit(option.exit_status_code);
        }
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

    fn print(s: *const @This(), comptime fmt: []const u8, args: anytype) ParseError!void {
        s.writer.print(fmt, args) catch return ParseError.PrintFailed;
    }

    fn flush(s: *const @This()) ParseError!void {
        s.writer.flush() catch return ParseError.PrintFailed;
    }

    fn printUsage(self: *const @This(), comptime T: type) !void {
        var args = std.process.args();
        const exe_name = args.next().?; // exe name should always exist

        try self.print("Usage: {s} [OPTIONS]\n\nOptions:\n", .{std.fs.path.basename(exe_name)});
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
                    if (!is_u8_slice) continue;

                    try self.print("\t", .{});
                    try self.print("--{s}=<string>", .{field.name});

                    try self.printAdditionalUsageInfo(has_default, is_required, field);

                    try self.print("\n", .{});
                },
                .bool => {
                    try self.print("\t", .{});
                    try self.print("--{s} or --{s}=<bool>", .{ field.name, field.name });

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
        if (has_default) {
            const value = @as(*const field.type, @ptrCast(@alignCast(field.default_value_ptr.?))).*;
            switch (@typeInfo(field.type)) {
                .@"enum" => try self.print("\t(default: \"{s}\")", .{@tagName(value)}),
                else => try self.print("\t(default: \"{any}\")", .{value}),
            }
        } else if (is_required) {
            try self.print("\t(required)", .{});
        }
    }
};

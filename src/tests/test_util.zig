const std = @import("std");
const parseWithIterator = @import("../root.zig").parseWithIterator;
const ParseOptions = @import("../root.zig").ParseOptions;
const ParseError = @import("../root.zig").ParseError;

pub fn TestCase(comptime T: type) type {
    return struct {
        args_str: []const u8,
        field_name: []const u8,
        expected_value: T, // this is only used when expected_error is null
        expected_error: ?ParseError,
    };
}

pub fn runTest(comptime A: type, comptime V: type, comptime tc: TestCase(V)) !void {
    if (!@hasField(A, tc.field_name)) {
        return error.InvalidFieldName;
    }
    var writer_state = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer writer_state.deinit();
    const writer = &writer_state.writer;

    var iter = std.mem.tokenizeAny(u8, tc.args_str, " ");
    const result = parseWithIterator(A, .{
        .override_writer = writer,
    }, &iter);

    if (tc.expected_error) |expected_err| {
        std.testing.expectError(expected_err, result) catch |err| {
            std.debug.print("\nFailed: Expected error {}, got different error or success\n", .{expected_err});
            std.debug.print("Output: {s}\n", .{writer_state.written()});
            return err;
        };
        return;
    }
    const value = result catch |err| {
        std.debug.print("\nFailed: Unexpected error {}\n", .{err});
        std.debug.print("Output: {s}\n", .{writer_state.written()});
        return err;
    };

    const field = @field(value, tc.field_name);
    const is_optional = @typeInfo(@TypeOf(field)) == .optional;
    const actual_type = if (is_optional) @typeInfo(@TypeOf(field)).optional.child else @TypeOf(field);
    const expected = tc.expected_value;

    switch (@typeInfo(actual_type)) {
        .pointer => |ptr| {
            if (!(ptr.size == .slice and ptr.child == u8)) std.debug.panic("not supported yet!!");

            if (is_optional) {
                if (expected == null) {
                    std.testing.expect(field == null) catch |err| {
                        std.debug.print("\nFailed: Expected {s}=null, got={any}\n", .{
                            tc.field_name,
                            field,
                        });
                        return err;
                    };
                    return;
                }

                std.testing.expectEqualSlices(ptr.child, expected.?, field.?) catch |err| {
                    std.debug.print("\nFailed: Expected {s}={s}, got={s}\n", .{
                        tc.field_name,
                        expected.?,
                        field.?,
                    });
                    return err;
                };
                return;
            }

            std.testing.expectEqualSlices(ptr.child, expected, field) catch |err| {
                std.debug.print("\nFailed: Expected {s}={s}, got={s}\n", .{
                    tc.field_name,
                    expected,
                    field,
                });
                return err;
            };
        },
        .bool, .@"enum" => {
            std.testing.expect(field == expected) catch |err| {
                std.debug.print("\nFailed: Expected {s}={any}, got={any}\n", .{
                    tc.field_name,
                    expected,
                    field,
                });
                return err;
            };
        },
        else => |tag| std.debug.panic("not supported : {s}", .{@tagName(tag)}),
    }
}

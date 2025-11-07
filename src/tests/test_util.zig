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

    const expected = tc.expected_value;
    std.testing.expect(@field(value, tc.field_name) == expected) catch |err| {
        std.debug.print("\nFailed: Expected {s}={any}, got={any}\n", .{
            tc.field_name,
            expected,
            @field(value, tc.field_name),
        });
        return err;
    };
}

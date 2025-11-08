const std = @import("std");
const root = @import("../root.zig");
const test_util = @import("./test_util.zig");

const runTest = test_util.runTest;
const TestCase = test_util.TestCase;
const parseWithIterator = root.parseWithIterator;
const ParseOptions = root.ParseOptions;
const ParseError = root.ParseError;

// TODO(seg4lt): Maybe runTest should return the parsed struct, so we can verify all data at once?
pub const MultiArgsBasic = struct {
    name: []const u8,
    count: i32,
    verbose: bool = false,

    test "multi args - name field with all args provided" {
        try runTest(@This(), []const u8, .{
            .args_str = "claptain --name=test --count=42 --verbose",
            .field_name = "name",
            .expected_value = "test",
            .expected_error = null,
        });
    }

    test "multi args - count field with all args provided" {
        try runTest(@This(), i32, .{
            .args_str = "claptain --name=test --count=42 --verbose",
            .field_name = "count",
            .expected_value = 42,
            .expected_error = null,
        });
    }

    test "multi args - verbose field with all args provided" {
        try runTest(@This(), bool, .{
            .args_str = "claptain --name=test --count=42 --verbose",
            .field_name = "verbose",
            .expected_value = true,
            .expected_error = null,
        });
    }

    test "multi args - args in different order" {
        try runTest(@This(), []const u8, .{
            .args_str = "claptain --count=99 --verbose --name=world",
            .field_name = "name",
            .expected_value = "world",
            .expected_error = null,
        });
    }

    test "multi args - missing required arg should error" {
        try runTest(@This(), []const u8, .{
            .args_str = "claptain --name=test",
            .field_name = "name",
            .expected_value = "",
            .expected_error = ParseError.RequiredArgsNotProvided,
        });
    }
};

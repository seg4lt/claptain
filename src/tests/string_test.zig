const std = @import("std");
const root = @import("../root.zig");
const test_util = @import("./test_util.zig");

const runTest = test_util.runTest;
const TestCase = test_util.TestCase;
const parseWithIterator = root.parseWithIterator;
const ParseOptions = root.ParseOptions;
const ParseError = root.ParseError;

pub const StringNoDefault = struct {
    const ARG_TYPE = []const u8;
    str: ARG_TYPE,

    test "opt str with default - flag without value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --str",
            .field_name = "str",
            .expected_value = "",
            .expected_error = ParseError.InvalidArgument,
        });
    }
    test "opt str with default - explicit value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --str=hello",
            .field_name = "str",
            .expected_value = "hello",
            .expected_error = null,
        });
    }

    test "opt str with default - missing argument should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain",
            .field_name = "str",
            .expected_value = "",
            .expected_error = ParseError.RequiredArgsNotProvided,
        });
    }
};

pub const StringWithDefault = struct {
    const ARG_TYPE = []const u8;
    str: ARG_TYPE = "default_value",

    test "opt str with default - flag without value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --str",
            .field_name = "str",
            .expected_value = "",
            .expected_error = ParseError.InvalidArgument,
        });
    }
    test "opt str with default - explicit value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --str=hello",
            .field_name = "str",
            .expected_value = "hello",
            .expected_error = null,
        });
    }

    test "opt str with default - missing argument should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain",
            .field_name = "str",
            .expected_value = "default_value",
            .expected_error = null,
        });
    }
};

pub const OptStringNoDefault = struct {
    const ARG_TYPE = ?[]const u8;
    str: ARG_TYPE,

    test "opt str - flag without value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --str",
            .field_name = "str",
            .expected_value = "",
            .expected_error = ParseError.InvalidArgument,
        });
    }
    test "opt str - explicit value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --str=hello",
            .field_name = "str",
            .expected_value = "hello",
            .expected_error = null,
        });
    }

    test "opt str - missing argument should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain",
            .field_name = "str",
            .expected_value = null,
            .expected_error = null,
        });
    }
};
pub const OptStringWithDefault = struct {
    const ARG_TYPE = ?[]const u8;
    str: ARG_TYPE = "default_value",

    test "opt str with default - flag without value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --str",
            .field_name = "str",
            .expected_value = "",
            .expected_error = ParseError.InvalidArgument,
        });
    }
    test "opt str with default - explicit value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --str=hello",
            .field_name = "str",
            .expected_value = "hello",
            .expected_error = null,
        });
    }

    test "opt str with default - missing argument should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain",
            .field_name = "str",
            .expected_value = "default_value",
            .expected_error = null,
        });
    }
};

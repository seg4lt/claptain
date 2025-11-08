const std = @import("std");
const root = @import("../root.zig");
const test_util = @import("./test_util.zig");

const runTest = test_util.runTest;
const TestCase = test_util.TestCase;
const parseWithIterator = root.parseWithIterator;
const ParseOptions = root.ParseOptions;
const ParseError = root.ParseError;

pub const FloatNoDefault = struct {
    const ARG_TYPE = f64;
    num: ARG_TYPE,

    test "float - valid positive value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=3.14",
            .field_name = "num",
            .expected_value = 3.14,
            .expected_error = null,
        });
    }

    test "float - valid negative value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=-2.71",
            .field_name = "num",
            .expected_value = -2.71,
            .expected_error = null,
        });
    }

    test "float - valid zero value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=0.0",
            .field_name = "num",
            .expected_value = 0.0,
            .expected_error = null,
        });
    }

    test "float - valid integer notation" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=42",
            .field_name = "num",
            .expected_value = 42.0,
            .expected_error = null,
        });
    }

    test "float - flag without value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num",
            .field_name = "num",
            .expected_value = 0.0,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "float - invalid value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=notanumber",
            .field_name = "num",
            .expected_value = 0.0,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "float - missing argument should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain",
            .field_name = "num",
            .expected_value = 0.0,
            .expected_error = ParseError.RequiredArgsNotProvided,
        });
    }
};

pub const FloatWithDefault = struct {
    const ARG_TYPE = f64;
    num: ARG_TYPE = 3.14,

    test "float with default - valid positive value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=2.71",
            .field_name = "num",
            .expected_value = 2.71,
            .expected_error = null,
        });
    }

    test "float with default - valid negative value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=-1.41",
            .field_name = "num",
            .expected_value = -1.41,
            .expected_error = null,
        });
    }

    test "float with default - valid zero value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=0.0",
            .field_name = "num",
            .expected_value = 0.0,
            .expected_error = null,
        });
    }

    test "float with default - valid integer notation" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=100",
            .field_name = "num",
            .expected_value = 100.0,
            .expected_error = null,
        });
    }

    test "float with default - flag without value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num",
            .field_name = "num",
            .expected_value = 3.14,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "float with default - invalid value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=abc",
            .field_name = "num",
            .expected_value = 3.14,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "float with default - missing argument should get default value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain",
            .field_name = "num",
            .expected_value = 3.14,
            .expected_error = null,
        });
    }
};

pub const OptFloatNoDefault = struct {
    const ARG_TYPE = ?f64;
    num: ARG_TYPE,

    test "opt float no default - valid positive value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=1.618",
            .field_name = "num",
            .expected_value = 1.618,
            .expected_error = null,
        });
    }

    test "opt float no default - valid negative value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=-9.81",
            .field_name = "num",
            .expected_value = -9.81,
            .expected_error = null,
        });
    }

    test "opt float no default - valid zero value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=0.0",
            .field_name = "num",
            .expected_value = 0.0,
            .expected_error = null,
        });
    }

    test "opt float no default - valid integer notation" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=5",
            .field_name = "num",
            .expected_value = 5.0,
            .expected_error = null,
        });
    }

    test "opt float no default - flag without value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num",
            .field_name = "num",
            .expected_value = null,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "opt float no default - invalid value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=invalid",
            .field_name = "num",
            .expected_value = null,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "opt float no default - missing argument is null" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain",
            .field_name = "num",
            .expected_value = null,
            .expected_error = null,
        });
    }
};

pub const OptFloatWithDefault = struct {
    const ARG_TYPE = ?f64;
    num: ARG_TYPE = 2.71,

    test "opt float with default - valid positive value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=6.28",
            .field_name = "num",
            .expected_value = 6.28,
            .expected_error = null,
        });
    }

    test "opt float with default - valid negative value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=-0.5",
            .field_name = "num",
            .expected_value = -0.5,
            .expected_error = null,
        });
    }

    test "opt float with default - valid zero value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=0.0",
            .field_name = "num",
            .expected_value = 0.0,
            .expected_error = null,
        });
    }

    test "opt float with default - valid integer notation" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=10",
            .field_name = "num",
            .expected_value = 10.0,
            .expected_error = null,
        });
    }

    test "opt float with default - flag without value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num",
            .field_name = "num",
            .expected_value = 2.71,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "opt float with default - invalid value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=xyz",
            .field_name = "num",
            .expected_value = 2.71,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "opt float with default - missing argument should get default value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain",
            .field_name = "num",
            .expected_value = 2.71,
            .expected_error = null,
        });
    }
};
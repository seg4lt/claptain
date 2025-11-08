const std = @import("std");
const root = @import("../root.zig");
const test_util = @import("./test_util.zig");

const runTest = test_util.runTest;
const TestCase = test_util.TestCase;
const parseWithIterator = root.parseWithIterator;
const ParseOptions = root.ParseOptions;
const ParseError = root.ParseError;

pub const IntNoDefault = struct {
    const ARG_TYPE = i32;
    num: ARG_TYPE,

    test "int - valid positive value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=42",
            .field_name = "num",
            .expected_value = 42,
            .expected_error = null,
        });
    }

    test "int - valid negative value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=-100",
            .field_name = "num",
            .expected_value = -100,
            .expected_error = null,
        });
    }

    test "int - valid zero value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=0",
            .field_name = "num",
            .expected_value = 0,
            .expected_error = null,
        });
    }

    test "int - flag without value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num",
            .field_name = "num",
            .expected_value = 0,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "int - invalid value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=notanumber",
            .field_name = "num",
            .expected_value = 0,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "int - missing argument should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain",
            .field_name = "num",
            .expected_value = 0,
            .expected_error = ParseError.RequiredArgsNotProvided,
        });
    }
};

pub const IntWithDefault = struct {
    const ARG_TYPE = i32;
    num: ARG_TYPE = 42,

    test "int with default - valid positive value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=100",
            .field_name = "num",
            .expected_value = 100,
            .expected_error = null,
        });
    }

    test "int with default - valid negative value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=-50",
            .field_name = "num",
            .expected_value = -50,
            .expected_error = null,
        });
    }

    test "int with default - valid zero value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=0",
            .field_name = "num",
            .expected_value = 0,
            .expected_error = null,
        });
    }

    test "int with default - flag without value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num",
            .field_name = "num",
            .expected_value = 42,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "int with default - invalid value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=abc",
            .field_name = "num",
            .expected_value = 42,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "int with default - missing argument should get default value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain",
            .field_name = "num",
            .expected_value = 42,
            .expected_error = null,
        });
    }
};

pub const OptIntNoDefault = struct {
    const ARG_TYPE = ?i32;
    num: ARG_TYPE,

    test "opt int no default - valid positive value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=123",
            .field_name = "num",
            .expected_value = 123,
            .expected_error = null,
        });
    }

    test "opt int no default - valid negative value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=-99",
            .field_name = "num",
            .expected_value = -99,
            .expected_error = null,
        });
    }

    test "opt int no default - valid zero value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=0",
            .field_name = "num",
            .expected_value = 0,
            .expected_error = null,
        });
    }

    test "opt int no default - flag without value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num",
            .field_name = "num",
            .expected_value = null,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "opt int no default - invalid value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=invalid",
            .field_name = "num",
            .expected_value = null,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "opt int no default - missing argument is null" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain",
            .field_name = "num",
            .expected_value = null,
            .expected_error = null,
        });
    }
};

pub const OptIntWithDefault = struct {
    const ARG_TYPE = ?i32;
    num: ARG_TYPE = 7,

    test "opt int with default - valid positive value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=200",
            .field_name = "num",
            .expected_value = 200,
            .expected_error = null,
        });
    }

    test "opt int with default - valid negative value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=-25",
            .field_name = "num",
            .expected_value = -25,
            .expected_error = null,
        });
    }

    test "opt int with default - valid zero value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=0",
            .field_name = "num",
            .expected_value = 0,
            .expected_error = null,
        });
    }

    test "opt int with default - flag without value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num",
            .field_name = "num",
            .expected_value = 7,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "opt int with default - invalid value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=xyz",
            .field_name = "num",
            .expected_value = 7,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "opt int with default - missing argument should get default value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain",
            .field_name = "num",
            .expected_value = 7,
            .expected_error = null,
        });
    }
};

pub const UnsignedIntWithDefault = struct {
    const ARG_TYPE = u32;
    num: ARG_TYPE,

    test "opt unsigned int - valid positive value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=200",
            .field_name = "num",
            .expected_value = 200,
            .expected_error = null,
        });
    }
    test "opt unsigned int - invalid positive value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --num=-200",
            .field_name = "num",
            .expected_value = 0,
            .expected_error = ParseError.InvalidArgument,
        });
    }
};

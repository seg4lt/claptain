const std = @import("std");
const root = @import("../root.zig");
const test_util = @import("./test_util.zig");

const runTest = test_util.runTest;
const TestCase = test_util.TestCase;
const parseWithIterator = root.parseWithIterator;
const ParseOptions = root.ParseOptions;
const ParseError = root.ParseError;

const Color = enum { red, green, blue };

pub const EnumNoDefault = struct {
    const ARG_TYPE = Color;
    color: ARG_TYPE,

    test "enum - valid value red" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --color=red",
            .field_name = "color",
            .expected_value = .red,
            .expected_error = null,
        });
    }

    test "enum - valid value green" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --color=green",
            .field_name = "color",
            .expected_value = .green,
            .expected_error = null,
        });
    }

    test "enum - valid value blue" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --color=blue",
            .field_name = "color",
            .expected_value = .blue,
            .expected_error = null,
        });
    }

    test "enum - flag without value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --color",
            .field_name = "color",
            .expected_value = .red,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "enum - invalid value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --color=yellow",
            .field_name = "color",
            .expected_value = .red,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "enum - missing argument should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain",
            .field_name = "color",
            .expected_value = .red,
            .expected_error = ParseError.RequiredArgsNotProvided,
        });
    }
};

pub const EnumWithDefault = struct {
    const ARG_TYPE = Color;
    color: ARG_TYPE = .green,

    test "enum with default - valid value red" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --color=red",
            .field_name = "color",
            .expected_value = .red,
            .expected_error = null,
        });
    }

    test "enum with default - valid value blue" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --color=blue",
            .field_name = "color",
            .expected_value = .blue,
            .expected_error = null,
        });
    }

    test "enum with default - flag without value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --color",
            .field_name = "color",
            .expected_value = .green,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "enum with default - invalid value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --color=purple",
            .field_name = "color",
            .expected_value = .green,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "enum with default - missing argument should get default value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain",
            .field_name = "color",
            .expected_value = .green,
            .expected_error = null,
        });
    }
};

pub const OptEnumNoDefault = struct {
    const ARG_TYPE = ?Color;
    color: ARG_TYPE,

    test "opt enum no default - valid value red" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --color=red",
            .field_name = "color",
            .expected_value = .red,
            .expected_error = null,
        });
    }

    test "opt enum no default - valid value green" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --color=green",
            .field_name = "color",
            .expected_value = .green,
            .expected_error = null,
        });
    }

    test "opt enum no default - valid value blue" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --color=blue",
            .field_name = "color",
            .expected_value = .blue,
            .expected_error = null,
        });
    }

    test "opt enum no default - flag without value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --color",
            .field_name = "color",
            .expected_value = null,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "opt enum no default - invalid value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --color=orange",
            .field_name = "color",
            .expected_value = null,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "opt enum no default - missing argument is null" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain",
            .field_name = "color",
            .expected_value = null,
            .expected_error = null,
        });
    }
};

pub const OptEnumWithDefault = struct {
    const ARG_TYPE = ?Color;
    color: ARG_TYPE = .blue,

    test "opt enum with default - valid value red" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --color=red",
            .field_name = "color",
            .expected_value = .red,
            .expected_error = null,
        });
    }

    test "opt enum with default - valid value green" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --color=green",
            .field_name = "color",
            .expected_value = .green,
            .expected_error = null,
        });
    }

    test "opt enum with default - flag without value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --color",
            .field_name = "color",
            .expected_value = .blue,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "opt enum with default - invalid value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --color=pink",
            .field_name = "color",
            .expected_value = .blue,
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "opt enum with default - missing argument should get default value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain",
            .field_name = "color",
            .expected_value = .blue,
            .expected_error = null,
        });
    }
};
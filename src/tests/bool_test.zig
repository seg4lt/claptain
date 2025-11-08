const std = @import("std");
const root = @import("../root.zig");
const test_util = @import("./test_util.zig");

const runTest = test_util.runTest;
const TestCase = test_util.TestCase;
const parseWithIterator = root.parseWithIterator;
const ParseOptions = root.ParseOptions;
const ParseError = root.ParseError;

pub const BoolRequiredNoDefault = struct {
    const ARG_TYPE = bool;
    bool_required: ARG_TYPE,

    test "bool - flag without value (defaults to true)" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --bool_required",
            .field_name = "bool_required",
            .expected_value = true,
            .expected_error = null,
        });
    }
    test "bool - explicit true" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --bool_required=true",
            .field_name = "bool_required",
            .expected_value = true,
            .expected_error = null,
        });
    }
    test "bool - explicit false" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --bool_required=false",
            .field_name = "bool_required",
            .expected_value = false,
            .expected_error = null,
        });
    }

    test "bool - missing argument should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain",
            .field_name = "bool_required",
            .expected_value = false,
            .expected_error = ParseError.RequiredArgsNotProvided,
        });
    }

    test "bool - invalid value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --bool_required=invalid",
            .field_name = "bool_required",
            .expected_value = false,
            .expected_error = ParseError.InvalidArgument,
        });
    }
};

pub const BoolRequiredWithDefault = struct {
    bool_with_default: bool = true,

    test "bool with default - flag without value (defaults to true)" {
        try runTest(@This(), bool, .{
            .args_str = "claptain --bool_with_default",
            .field_name = "bool_with_default",
            .expected_value = true,
            .expected_error = null,
        });
    }
    test "bool with default - explicit true" {
        try runTest(@This(), bool, .{
            .args_str = "claptain --bool_with_default=true",
            .field_name = "bool_with_default",
            .expected_value = true,
            .expected_error = null,
        });
    }
    test "bool with default - explicit false" {
        try runTest(@This(), bool, .{
            .args_str = "claptain --bool_with_default=false",
            .field_name = "bool_with_default",
            .expected_value = false,
            .expected_error = null,
        });
    }

    test "bool with default - missing argument should get default value" {
        try runTest(@This(), bool, .{
            .args_str = "claptain",
            .field_name = "bool_with_default",
            .expected_value = true,
            .expected_error = null,
        });
    }

    test "bool with default - invalid value should error" {
        try runTest(@This(), bool, .{
            .args_str = "claptain --bool_with_default=invalid",
            .field_name = "bool_with_default",
            .expected_value = false,
            .expected_error = ParseError.InvalidArgument,
        });
    }
};


pub const OptBoolRequiredNoDefault = struct {
    opt_bool: ?bool,

    test "opt bool no default - flag without value (defaults to true)" {
        try runTest(@This(), ?bool, .{
            .args_str = "claptain --opt_bool",
            .field_name = "opt_bool",
            .expected_value = true,
            .expected_error = null,
        });
    }
    test "opt bool no default - explicit true" {
        try runTest(@This(), ?bool, .{
            .args_str = "claptain --opt_bool=true",
            .field_name = "opt_bool",
            .expected_value = true,
            .expected_error = null,
        });
    }
    test "opt bool no default - explicit false" {
        try runTest(@This(), ?bool, .{
            .args_str = "claptain --opt_bool=false",
            .field_name = "opt_bool",
            .expected_value = false,
            .expected_error = null,
        });
    }

    test "opt bool no default - missing argument is null" {
        try runTest(@This(), ?bool, .{
            .args_str = "claptain",
            .field_name = "opt_bool",
            .expected_value = null,
            .expected_error = null,
        });
    }

    test "opt bool no default - invalid value should error" {
        try runTest(@This(), ?bool, .{
            .args_str = "claptain --opt_bool=invalid",
            .field_name = "opt_bool",
            .expected_value = false,
            .expected_error = ParseError.InvalidArgument,
        });
    }
};

pub const OptBoolRequiredWithDefault = struct {
    opt_bool_default: ?bool = true,

    test "?bool with default - flag without value (defaults to true)" {
        try runTest(@This(), ?bool, .{
            .args_str = "claptain --opt_bool_default",
            .field_name = "opt_bool_default",
            .expected_value = true,
            .expected_error = null,
        });
    }
    test "?bool with default - explicit true" {
        try runTest(@This(), ?bool, .{
            .args_str = "claptain --opt_bool_default=true",
            .field_name = "opt_bool_default",
            .expected_value = true,
            .expected_error = null,
        });
    }
    test "?bool with default - explicit false" {
        try runTest(@This(), ?bool, .{
            .args_str = "claptain --opt_bool_default=false",
            .field_name = "opt_bool_default",
            .expected_value = false,
            .expected_error = null,
        });
    }

    test "?bool with default - missing argument should get default value" {
        try runTest(@This(), ?bool, .{
            .args_str = "claptain",
            .field_name = "opt_bool_default",
            .expected_value = true,
            .expected_error = null,
        });
    }

    test "?bool with default - invalid value should error" {
        try runTest(@This(), ?bool, .{
            .args_str = "claptain --opt_bool_default=invalid",
            .field_name = "opt_bool_default",
            .expected_value = false,
            .expected_error = ParseError.InvalidArgument,
        });
    }
};

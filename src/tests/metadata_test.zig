const std = @import("std");
const root = @import("../root.zig");
const test_util = @import("./test_util.zig");

const runTest = test_util.runTest;
const TestCase = test_util.TestCase;
const parseWithIterator = root.parseWithIterator;
const ParseOptions = root.ParseOptions;
const ParseError = root.ParseError;

pub const MetadataShortName = struct {
    const ARG_TYPE = []const u8;
    verbose: ARG_TYPE,

    pub const __claptain_metadata: root.Metadata(@This()) = .{
        .verbose = .{
            .short = "v",
        },
    };

    test "metadata - short name with value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain -v=hello",
            .field_name = "verbose",
            .expected_value = "hello",
            .expected_error = null,
        });
    }

    test "metadata - long name still works" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --verbose=world",
            .field_name = "verbose",
            .expected_value = "world",
            .expected_error = null,
        });
    }

    test "metadata - short name without value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain -v",
            .field_name = "verbose",
            .expected_value = "",
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "metadata - missing argument should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain",
            .field_name = "verbose",
            .expected_value = "",
            .expected_error = ParseError.RequiredArgsNotProvided,
        });
    }
};

pub const MetadataLongNameOverride = struct {
    const ARG_TYPE = []const u8;
    src_path: ARG_TYPE,

    pub const __claptain_metadata: root.Metadata(@This()) = .{
        .src_path = .{
            .long = "srcPath",
        },
    };

    test "metadata - long name override with value" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --srcPath=/path/to/file",
            .field_name = "src_path",
            .expected_value = "/path/to/file",
            .expected_error = null,
        });
    }

    test "metadata - original field name should fail when overridden" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --src_path=/path/to/file",
            .field_name = "src_path",
            .expected_value = "",
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "metadata - long name override without value should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain --srcPath",
            .field_name = "src_path",
            .expected_value = "",
            .expected_error = ParseError.InvalidArgument,
        });
    }

    test "metadata - missing argument should error" {
        try runTest(@This(), ARG_TYPE, .{
            .args_str = "claptain",
            .field_name = "src_path",
            .expected_value = "",
            .expected_error = ParseError.RequiredArgsNotProvided,
        });
    }
};

pub const MultipleFieldsWithShortNames = struct {
    input_file: []const u8,
    output_file: ?[]const u8 = null,
    verbose: bool = false,

    pub const __claptain_metadata: root.Metadata(@This()) = .{
        .input_file = .{
            .short = "i",
        },
        .output_file = .{
            .short = "o",
        },
        .verbose = .{
            .short = "v",
        },
    };

    test "metadata - multiple short names should all work independently" {
        var writer_state = std.Io.Writer.Allocating.init(std.testing.allocator);
        defer writer_state.deinit();
        const writer = &writer_state.writer;

        var iter = std.mem.tokenizeAny(u8, "claptain -i=input.txt -v", " ");
        const result = try parseWithIterator(@This(), .{
            .override_writer = writer,
        }, &iter);

        try std.testing.expectEqualSlices(u8, "input.txt", result.input_file);
        try std.testing.expect(result.verbose == true);
        try std.testing.expect(result.output_file == null);
    }

    test "metadata - different short name should work after another" {
        var writer_state = std.Io.Writer.Allocating.init(std.testing.allocator);
        defer writer_state.deinit();
        const writer = &writer_state.writer;

        var iter = std.mem.tokenizeAny(u8, "claptain -i=in.txt -o=out.txt -v", " ");
        const result = try parseWithIterator(@This(), .{
            .override_writer = writer,
        }, &iter);

        try std.testing.expectEqualSlices(u8, "in.txt", result.input_file);
        try std.testing.expectEqualSlices(u8, "out.txt", result.output_file.?);
        try std.testing.expect(result.verbose == true);
    }
};
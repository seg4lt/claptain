const std = @import("std");
const claptain = @import("claptain");

const CliArgs = struct {
    base_path: []const u8 = "asdf",
    run: bool = true,
    tag: enum { foo, bar } = .foo,
    src_path: []const u8,
};

pub fn main() !void {
    const args = try claptain.parse(CliArgs, .{});
    std.log.debug("--`{s}`--", .{args.base_path});
}
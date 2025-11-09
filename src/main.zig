const std = @import("std");
const claptain = @import("claptain");

const CliArgs = struct {
    src_path: []const u8,
    happy: ?bool = null,

    pub const __claptain_metadata: claptain.Metadata(@This()) = .{
        .src_path = .{
            .short = "s",
            .long = "srcPath",
        },
        .happy = .{
            .description = "Enable happy mode for processing",
        },
    };
};

pub fn main() !void {
    const args = try claptain.parse(CliArgs, .{});
    structPrinter(args);
}

fn structPrinter(value: anytype) void {
    const T = @TypeOf(value);
    inline for (std.meta.fields(T)) |field| {
        switch (@typeInfo(field.type)) {
            .pointer => |ptr| {
                if (ptr.size == .slice and ptr.child == u8) {
                    std.log.debug("{s:>20} = `{s}`", .{ field.name, @field(value, field.name) });
                    continue;
                }
                structPrinter(@field(value, field.name).*);
            },
            else => std.log.debug("{s:>20} = `{any}`", .{ field.name, @field(value, field.name) }),
        }
    }
}

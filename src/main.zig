const std = @import("std");
const claptain = @import("claptain");

const CliArgs = struct {
    const_u8_required: []const u8,
    const_u8_default: []const u8 = "const_u8_default",
    opt_const_u8_default: ?[]const u8 = "opt_const_u8_default",
    opt_const_u8: ?[]const u8,
    
    bool_required: bool,
    bool_default: bool = false,
    opt_bool: ?bool,
    opt_bool_default: ?bool = true,
    
    enum_required: enum { foo, bar },
    enum_default: enum { foo, bar } = .bar,
    opt_enum: ?enum { foo, bar },
    opt_enum_default: ?enum { foo, bar } = .foo,
    
    int_required: i32,
    int_default: i32 = 42,
    opt_int: ?i32,
    opt_int_default: ?i32 = 7,
    
    float_required: f64,
    float_default: f64 = 3.14,
    opt_float: ?f64,
    opt_float_default: ?f64 = 2.71,
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

# claptain

A simple command line argument parser for Zig.

## Example

### Minimal

```zig
const std = @import("std");
const claptain = @import("claptain");

const CliArgs = struct {
    base_path: []const u8,
    debug: bool = true,
};

pub fn main() !void {
    const args = claptain.parse(CliArgs, .{}) catch {
        std.process.exit(1);
    };
    std.debug.print("base path: {s}\n", .{args.base_path});
    std.debug.print("debug: {any}\n", .{args.debug});
}
```

### With additional metadata

```zig
const std = @import("std");
const claptain = @import("claptain");

const CliArgs = struct {
    src_path: []const u8,
    happy: ?bool = null,

    // optional - if you want to override the default flag names
    //            or do add short flag name
    pub const __claptain_metadata: claptain.Metadata(@This()) = .{
        // the field name matches the field name you have for your Arg struct
        .src_path = .{
            .short = "s",      // optional - you can add this if you want to have a short flag
            .long = "srcPath", // optional - if you want to override your long flag name
        },
        // you can see override for happy (.happy) is also optional
        // override only if you want to change the default behavior
    };
};

pub fn main() !void {
    const args = try claptain.parse(CliArgs, .{});
    // ...
}
```

## Installation

1. Add claptain as a dependency in your `build.zig.zon`:

```bash
zig fetch --save "git+https://github.com/seg4lt/claptain"
```

2. In your `build.zig`, add the `claptain` module as a dependency to your program:

```zig
const claptain = b.dependency("claptain", .{
    .target = target,
    .optimize = optimize,
});

// Option 1: Add import for your module
exe.root_module.addImport("claptain", claptain.module("claptain"));

// Option 2: Add import while creating the root module
const exe = b.addExecutable(.{
    .name = "<your_program_name>",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            // ADD THIS LINE
            .{ .name = "claptain", .module = claptain.module("claptain") },
        },
    }),
});

```

## TODO

- [ ] Add option to maybe not print at all?
- [ ] Add capture for last part of args e.g. `myprog [options] <remianing>`. e.g. `grep -rni "pattern_to_search" "dir_to_search" "another_dir_to_search"`
- [ ] Support for descriptive help messages
- [ ] Maybe add a option to use kebab case on options, so you don't need to override if you want kebab case?
- [ ] Support for args that can accept array of things
- [ ] Chain commands for bool type e.g. `grep -rni`
- [ ] Support for subcommands

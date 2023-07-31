const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "jitterentropy-zig",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    const jent_module = b.addModule("jent", .{
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .source_file = .{ .path = "src/main.zig" },
    });
    try b.modules.put(b.dupe("jent"), jent_module);

    // +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Examples
    // +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    const exe = b.addExecutable(.{
        .name = "jent-example",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "example/main.zig" },
        .target = target,
    });
    exe.addModule("jent", jent_module);
    b.installArtifact(exe);

    const exe2 = b.addExecutable(.{
        .name = "random",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "example/random.zig" },
        .target = target,
    });
    exe2.addModule("jent", jent_module);
    b.installArtifact(exe2);

    // +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // Tests
    // +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    const hashtime = b.addExecutable(.{
        .name = "hashtime",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "tests/recording_userspace/hashtime.zig" },
        .target = target,
    });
    hashtime.addModule("jent", jent_module);
    b.installArtifact(hashtime);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_main_tests = b.addRunArtifact(main_tests);

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build test`
    // This will evaluate the `test` step rather than the default, which is "install".
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}

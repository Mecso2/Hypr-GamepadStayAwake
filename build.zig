const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{.preferred_optimize_mode=.ReleaseSafe});



    const lib = b.addSharedLibrary(.{
        .name = "hypr-gamepadstayawake",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true
    });
    {
        const cache_dir:[]const u8 = b.cache_root.path orelse ".";
        {
            const obj_path=std.fmt.allocPrintZ(b.allocator, "{s}/a.o", .{cache_dir}) catch @panic("OOM");
            defer b.allocator.free(obj_path);
            lib.addObjectFile(.{.path=obj_path});
        }
        {
            const obj_path=std.fmt.allocPrintZ(b.allocator, "-o{s}/a.o", .{cache_dir}) catch @panic("OOM");
            defer b.allocator.free(obj_path);
            lib.step.dependOn(&b.addSystemCommand(&[_][]const u8{"/bin/g++", "src/a.cpp", obj_path, "-c", "-O3"}).step);
        }
    }
    lib.linkSystemLibrary("SDL2");
    
    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

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

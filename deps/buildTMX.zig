const std = @import("std");

pub fn build(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const tmx = b.addStaticLibrary(.{
        .name = "tmx",
        .target = target,
        .optimize = optimize,
    });

    tmx.linkLibC();
    tmx.linkSystemLibrary("xml2");
    tmx.addCSourceFiles(.{
        .root = b.path("deps/tmx/src"),
        .files = &.{
            "tmx.c",
            "tmx_err.c",
            "tmx_hash.c",
            "tmx_mem.c",
            "tmx_utils.c",
            "tmx_xml.c",
        },
    });

    return tmx;
}

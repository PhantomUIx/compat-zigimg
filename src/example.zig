const std = @import("std");
const builtin = @import("builtin");
const options = @import("options");
const phantom = @import("phantom");
const vizops = @import("vizops");

pub const phantomOptions = struct {
    pub const imageFormats = struct {
        pub const zigimg = @import("phantom.compat.zigimg").painting.image.formats.zigimg;
    };
};

const alloc = if (builtin.link_libc) std.heap.c_allocator else if (builtin.os.tag == .uefi) std.os.uefi.pool_allocator else std.heap.page_allocator;

const displayBackendType: phantom.display.BackendType = @enumFromInt(@intFromEnum(options.display_backend));
const displayBackend = phantom.display.Backend(displayBackendType);

const sceneBackendType: phantom.scene.BackendType = @enumFromInt(@intFromEnum(options.scene_backend));
const sceneBackend = phantom.scene.Backend(sceneBackendType);

pub fn main() !void {
    const format = try phantom.painting.image.formats.zigimg.create(alloc);
    defer format.deinit();

    std.debug.print("{}\n", .{format});

    const image = try format.readBuffer(@embedFile("example.gif"));
    defer image.deinit();

    for (0..image.info().seqCount) |i| {
        const fb = try image.buffer(i);
        defer fb.deinit();
    }

    std.debug.print("{}\n{}\n", .{ image, image.info() });
}

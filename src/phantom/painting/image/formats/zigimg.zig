const std = @import("std");
const Allocator = std.mem.Allocator;
const phantom = @import("phantom");
const hasFileSystem = @hasDecl(std.os.system, "fd_t");
const Base = @import("zigimg/base.zig");
const zigimg = @import("zigimg");
const Self = @This();

base: phantom.painting.image.Format,
allocator: Allocator,

pub fn create(alloc: Allocator) Allocator.Error!*phantom.painting.image.Format {
    const self = try alloc.create(Self);
    errdefer alloc.destroy(self);

    self.* = .{
        .base = .{
            .ptr = self,
            .vtable = &(comptime blk: {
                var vtable: phantom.painting.image.Format.VTable = .{
                    .create = createImage,
                    .readBuffer = readBuffer,
                    .writeBuffer = writeBuffer,
                    .deinit = deinit,
                };

                if (hasFileSystem) {
                    vtable.readFile = readFile;
                    vtable.writeFile = writeFile;
                }
                break :blk vtable;
            }),
        },
        .allocator = alloc,
    };
    return &self.base;
}

fn createImage(ctx: *anyopaque, info: phantom.painting.image.Base.Info) anyerror!*phantom.painting.image.Base {
    _ = ctx;
    _ = info;
    return error.NotImplemented;
}

fn readBuffer(ctx: *anyopaque, buf: []const u8) anyerror!*phantom.painting.image.Base {
    const self: *Self = @ptrCast(@alignCast(ctx));

    var img = try zigimg.Image.fromMemory(self.allocator, buf);
    errdefer img.deinit();

    return &(try Base.create(img)).base;
}

fn writeBuffer(ctx: *anyopaque, base: *phantom.painting.image.Base, buf: []u8) anyerror!usize {
    _ = ctx;
    _ = base;
    _ = buf;
    return error.Unimplemented;
}

fn readFile(ctx: *anyopaque, file: std.fs.File) anyerror!*phantom.painting.image.Base {
    const self: *Self = @ptrCast(@alignCast(ctx));

    var img = try zigimg.Image.fromFile(self.allocator, @constCast(&file));
    errdefer img.deinit();

    return &(try Base.create(img)).base;
}

fn writeFile(ctx: *anyopaque, base: *phantom.painting.image.Base, file: std.fs.File) anyerror!usize {
    _ = ctx;
    _ = base;
    _ = file;
    return error.Unimplemented;
}

fn deinit(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    self.allocator.destroy(self);
}

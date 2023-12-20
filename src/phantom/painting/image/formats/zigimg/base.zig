const std = @import("std");
const Allocator = std.mem.Allocator;
const phantom = @import("phantom");
const zigimg = @import("zigimg");
const Fb = @import("../../../fb/zigimg-pixel-storage.zig");
const Self = @This();

base: phantom.painting.image.Base,
value: zigimg.Image,

pub fn create(value: zigimg.Image) Allocator.Error!*Self {
    const self = try value.allocator.create(Self);
    errdefer value.allocator.destroy(self);

    self.* = .{
        .base = .{
            .ptr = self,
            .vtable = &.{
                .buffer = buffer,
                .info = info,
                .deinit = deinit,
            },
        },
        .value = value,
    };
    return self;
}

fn buffer(ctx: *anyopaque, i: usize) anyerror!*phantom.painting.fb.Base {
    const self: *Self = @ptrCast(@alignCast(ctx));

    if (!self.value.isAnimation()) {
        if (i > 0) return error.OutOfBounds;
        return try Fb.create(self.value.allocator, self.value.width, self.value.height, self.value.pixels);
    }

    if (i > self.value.animation.frames.items.len) return error.OutOfBounds;
    return try Fb.create(self.value.allocator, self.value.width, self.value.height, self.value.animation.frames.items[i].pixels);
}

fn info(ctx: *anyopaque) phantom.painting.image.Base.Info {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return .{
        .res = .{ .value = .{ self.value.width, self.value.height } },
        .colorspace = .sRGB,
        .colorFormat = .{ .rgba = @splat(8) },
        .seqCount = @max(self.value.animation.frames.items.len, 1),
    };
}

fn deinit(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));

    self.value.deinit();
    self.value.allocator.destroy(self);
}

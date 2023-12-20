const std = @import("std");
const Allocator = std.mem.Allocator;
const phantom = @import("phantom");
const zigimg = @import("zigimg");
const vizops = @import("vizops");
const Self = @This();

base: phantom.painting.fb.Base,
width: usize,
height: usize,
value: zigimg.color.PixelStorage,

fn dupePixelStorage(alloc: Allocator, store: zigimg.color.PixelStorage) !zigimg.color.PixelStorage {
    inline for (comptime std.meta.fields(zigimg.PixelFormat)) |field| {
        const tag: zigimg.PixelFormat = @enumFromInt(field.value);
        if (store == tag) {
            const value = @field(store, field.name);
            const T = @TypeOf(value);
            if (@typeInfo(T) == .Pointer) {
                return @unionInit(zigimg.color.PixelStorage, field.name, try alloc.dupe(std.meta.Child(@TypeOf(value)), value));
            } else if (@typeInfo(T) == .Void) {
                return .invalid;
            } else {
                return @unionInit(zigimg.color.PixelStorage, field.name, .{
                    .indices = try alloc.dupe(std.meta.Child(@TypeOf(value.indices)), value.indices),
                    .palette = try alloc.dupe(std.meta.Child(@TypeOf(value.palette)), value.palette),
                });
            }
        }
    }
    return .invalid;
}

pub fn create(alloc: Allocator, width: usize, height: usize, value: zigimg.color.PixelStorage) !*phantom.painting.fb.Base {
    const self = try alloc.create(Self);
    errdefer alloc.destroy(self);

    self.* = .{
        .base = .{
            .allocator = alloc,
            .ptr = self,
            .vtable = &.{
                .info = info,
                .addr = addr,
                .deinit = deinit,
                .dupe = dupe,
                .read = read,
                .blt = null,
            },
        },
        .width = width,
        .height = height,
        .value = try dupePixelStorage(alloc, value),
    };
    return &self.base;
}

fn info(ctx: *anyopaque) phantom.painting.fb.Base.Info {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return .{
        .res = .{ .value = .{ self.width, self.height } },
        .colorspace = .sRGB,
        .colorFormat = .{ .rgba = @splat(8) },
    };
}

fn addr(_: *anyopaque) anyerror!*anyopaque {
    return error.NoBuffer;
}

fn deinit(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    self.value.deinit(self.base.allocator);
    self.base.allocator.destroy(self);
}

fn dupe(ctx: *anyopaque) anyerror!*phantom.painting.fb.Base {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return try create(self.base.allocator, self.width, self.height, self.value);
}

fn read(ctx: *anyopaque, i: usize, buf: []u8) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(ctx));

    var iter = zigimg.color.PixelStorageIterator.init(&self.value);
    iter.current_index = i / self.value.len();

    var x: usize = 0;
    const end = buf.len / self.value.len();
    while (x < end) : (x += 1) {
        const index = x * self.value.len();
        const value = (iter.next() orelse return error.OutOfBounds).toRgba32();

        if (index < buf.len) buf[index] = value.r;
        if ((index + 1) < buf.len) buf[index + 1] = value.g;
        if ((index + 2) < buf.len) buf[index + 2] = value.b;
        if ((index + 3) < buf.len) buf[index + 3] = value.a;
    }
}

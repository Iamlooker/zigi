const std = @import("std");
const rl = @import("raylib");

pub const Sprite = struct {
    texture: rl.Texture2D,
    fps: f32,
    frames: []rl.Rectangle,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        texture: rl.Texture2D,
        fps: f32,
        start: f32,
        count: usize,
        size: f32,
    ) !Self {
        var sprite: Sprite = .{
            .fps = fps,
            .texture = texture,
            .frames = try allocator.alloc(rl.Rectangle, count),
        };
        for (0..count) |i| {
            const iF: f32 = @floatFromInt(i);
            sprite.frames[i] = .init((iF + start) * size, 0, size, size);
        }
        return sprite;
    }

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.frames);
    }

    pub fn draw(
        self: Self,
        dest: rl.Rectangle,
        origin: rl.Vector2,
        tint: rl.Color,
    ) void {
        if (self.frames.len < 1) return;
        const len: f32 = @floatFromInt(self.frames.len);
        const index = @rem(rl.getTime() * self.fps, len);
        const source = self.frames[@intFromFloat(index)];
        rl.drawTexturePro(self.texture, source, dest, origin, 0, tint);
    }
};

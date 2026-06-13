const std = @import("stdlib");
const rl = @import("raylib");

pub const Sprite = struct {
    texture: rl.Texture2D,
    fps: f32,
    frames: []rl.Rectangle,

    const Self = @This();

    pub fn draw(
        self: Self,
        dest: rl.Rectangle,
        origin: rl.Vector2,
        tint: rl.Color,
    ) void {
        const len: f32 = @floatFromInt(self.frames.len);
        const index = @rem(rl.getTime() * self.fps, len);
        const source = self.frames[@intFromFloat(index)];
        rl.drawTexturePro(self.texture, source, dest, origin, 0, tint);
    }
};
